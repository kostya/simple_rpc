require "socket"
require "msgpack"
require "pool/connection"

class SimpleRpc::Client
  enum Mode
    # Create new connection for every request, after request done close connection.
    # Quite slow (because spend time to create connection), but concurrency unlimited (only by OS).
    # Good for slow requests.
    # [default]
    ConnectPerRequest

    # Create persistent pool of connections.
    # Much faster, but concurrency limited by pool_size (default = 20).
    # Good for millions of very fast requests.
    # Every request have one autoreconnection attempt (because connection in pool can be outdated).
    Pool

    # Single persistent connection.
    # Same as pool of size 1, you should manage concurrency by yourself.
    # Every request have one autoreconnection attempt (because persistent connection can be outdated).
    Single
  end

  getter pool : ConnectionPool(Connection)?
  getter single : Connection?
  getter mode

  getter host, port, unixsocket, command_timeout, connect_timeout

  def initialize(@host : String = "127.0.0.1",
                 @port : Int32 = 9999,
                 @unixsocket : String? = nil,
                 @command_timeout : Float64? = nil,
                 @connect_timeout : Float64? = nil,
                 @mode : Mode = Mode::ConnectPerRequest,
                 pool_size = 20,
                 pool_timeout = 5.0)
    if @mode == Mode::Pool
      @pool = ConnectionPool(Connection).new(capacity: pool_size, timeout: pool_timeout) { create_connection }
    end
  end

  # Execute request, raise error if error
  # First argument is a return type, then method and args
  #
  #   example:
  #     res = SimpleRpc::Client.request!(type, method, *args) # => type
  #     res = SimpleRpc::Client.request!(Float64, :bla, 1, "2.5") # => Float64
  #
  # raises only SimpleRpc::Errors
  #   SimpleRpc::ProtocallError       - when problem in client-server interaction
  #   SimpleRpc::TypeCastError        - when return type not casted to requested
  #   SimpleRpc::RuntimeError         - when task crashed on server
  #   SimpleRpc::CannotConnectError   - when client cant connect to server
  #   SimpleRpc::CommandTimeoutError  - when client wait too long for answer from server
  #   SimpleRpc::ConnectionLostError  - when client lost connection to server
  #   SimpleRpc::PoolTimeoutError     - when no free connections in pool

  def request!(klass : T.class, name, *args) forall T
    raw_request(name, Tuple.new(*args)) do |unpacker|
      begin
        klass.new(unpacker)
      rescue ex : MessagePack::TypeCastError
        raise SimpleRpc::TypeCastError.new("Receive unexpected result type, expected #{klass.inspect}")
      end
    end
  end

  # Execute request, not raising errors
  # First argument is a return type, then method and args
  #
  #   example:
  #     res = SimpleRpc::Client.request(type, method, *args) # => SimpleRpc::Result(Float64)
  #     res = SimpleRpc::Client.request(Float64, :bla, 1, "2.5") # => SimpleRpc::Result(Float64)
  #
  #     if res.ok?
  #       p res.value! # => Float64
  #     else
  #       p res.error! # => SimpleRpc::Errors
  #     end
  #
  def request(klass : T.class, name, *args) forall T
    res = request!(klass, name, *args)
    SimpleRpc::Result(T).new(nil, res)
  rescue ex : SimpleRpc::Errors
    SimpleRpc::Result(T).new(ex)
  end

  def notify!(name, *args)
    raw_notify(name, args)
  end

  def raw_request(method, args, msgid = SimpleRpc::DEFAULT_MSG_ID)
    connection = get_connection

    # establish connection if needed
    connection.socket

    # write request to server
    if @mode.connect_per_request?
      write_request(connection, method, args, msgid)
    else
      begin
        write_request(connection, method, args, msgid)
      rescue SimpleRpc::ConnectionError
        # reconnecting here, if needed
        write_request(connection, method, args, msgid)
      end
    end

    # read request from server
    res = connection.catch_connection_errors do
      begin
        unpacker = MessagePack::IOUnpacker.new(connection.socket)
        msg = read_msg_id(unpacker)
        unless msgid == msg
          connection.close
          raise SimpleRpc::ProtocallError.new("unexpected msgid: expected #{msgid}, but got #{msg}")
        end

        yield(MessagePack::NodeUnpacker.new(unpacker.read_node))
      rescue ex : MessagePack::TypeCastError | MessagePack::UnexpectedByteError
        connection.close
        raise SimpleRpc::ProtocallError.new(ex.message)
      end
    end

    res
  ensure
    if conn = connection
      release_connection(conn)
    end
  end

  private def create_connection
    Connection.new(@host, @port, @unixsocket, @command_timeout, @connect_timeout)
  end

  private def pool!
    @pool.not_nil!
  end

  private def get_connection
    case @mode
    when Mode::Pool
      _pool = pool!
      begin
        _pool.checkout
      rescue IO::TimeoutError
        # not free connection in the pool
        raise PoolTimeoutError.new("No free connection (used #{_pool.size} of #{_pool.capacity}) after timeout of #{_pool.timeout}s")
      end
    when Mode::Single
      @single ||= create_connection
    else
      create_connection
    end
  end

  private def release_connection(conn)
    case @mode
    when Mode::ConnectPerRequest
      conn.close
    when Mode::Pool
      pool!.checkin(conn)
    else
      # skip
    end
  end

  private def raw_notify(method, args)
    connection = get_connection

    # establish connection if needed
    connection.socket

    # write request to server
    if @mode.connect_per_request?
      write_request(connection, method, args, SimpleRpc::DEFAULT_MSG_ID, true)
    else
      begin
        write_request(connection, method, args, SimpleRpc::DEFAULT_MSG_ID, true)
      rescue SimpleRpc::ConnectionError
        # reconnecting here, if needed
        write_request(connection, method, args, SimpleRpc::DEFAULT_MSG_ID, true)
      end
    end

    nil
  ensure
    if conn = connection
      release_connection(conn)
    end
  end

  private def write_request(conn, method, args, msgid, notify = false)
    conn.catch_connection_errors do
      write_header(conn, method, msgid, notify) do |packer|
        args.to_msgpack(packer)
      end
    end
  end

  private def write_header(conn, method, msgid = SimpleRpc::DEFAULT_MSG_ID, notify = false)
    sock = conn.socket
    packer = MessagePack::Packer.new(sock)
    if notify
      packer.write_array_start(SimpleRpc::NOTIFY_SIZE)
      packer.write(SimpleRpc::NOTIFY)
      packer.write(method)
      yield packer
    else
      packer.write_array_start(SimpleRpc::REQUEST_SIZE)
      packer.write(SimpleRpc::REQUEST)
      packer.write(msgid)
      packer.write(method)
      yield packer
    end
    sock.flush
    true
  end

  private def read_msg_id(unpacker) : UInt32
    size = unpacker.read_array_size
    unpacker.finish_token!

    unless size == SimpleRpc::RESPONSE_SIZE
      raise MessagePack::TypeCastError.new("Unexpected result array size, should #{SimpleRpc::RESPONSE_SIZE}, not #{size}")
    end

    id = Int8.new(unpacker)

    unless id == SimpleRpc::RESPONSE
      raise MessagePack::TypeCastError.new("Unexpected message result sign #{id}")
    end

    msgid = UInt32.new(unpacker)

    msg = Union(String | Nil).new(unpacker)
    if msg
      unpacker.skip_value # skip empty result
      raise SimpleRpc::RuntimeError.new(msg)
    end

    msgid
  end

  def close
    case @mode
    when Mode::Pool
      pool!.@pool.each(&.close)
    when Mode::Single
      @single.try(&.close)
      @single = nil
    else
      # skip
    end
  end

  private class Connection
    getter socket : TCPSocket | UNIXSocket | Nil

    def initialize(@host : String = "127.0.0.1",
                   @port : Int32 = 9999,
                   @unixsocket : String? = nil,
                   @command_timeout : Float64? = nil,
                   @connect_timeout : Float64? = nil)
    end

    def socket
      @socket ||= connect
    end

    private def connect
      _socket = if us = @unixsocket
                  UNIXSocket.new(us)
                else
                  TCPSocket.new @host, @port, connect_timeout: @connect_timeout
                end

      if t = @command_timeout
        _socket.read_timeout = t
        _socket.write_timeout = t
      end
      _socket.read_buffering = true
      _socket.sync = false
      _socket
    rescue ex : IO::TimeoutError | Socket::Error | IO::Error
      raise SimpleRpc::CannotConnectError.new("#{ex.class}: #{ex.message}")
    end

    def catch_connection_errors
      yield
    rescue ex : IO::TimeoutError
      close
      raise SimpleRpc::CommandTimeoutError.new("Command timed out")
    rescue ex : Socket::Error | IO::Error | MessagePack::EofError # Errno
      close
      raise SimpleRpc::ConnectionLostError.new("#{ex.class}: #{ex.message}")
    end

    def connected?
      @socket != nil
    end

    def close
      @socket.try(&.close) rescue nil
      @socket = nil
    end
  end
end
