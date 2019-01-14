require "socket"
require "msgpack"

class SimpleRpc::Client
  getter socket : TCPSocket?

  enum Mode
    # Connect on every request, after request done close connection.
    # Number of concurrent requests limited by system (number of allowed connections).
    # Expected to be slow, because spend extra time on create connection to server,
    # but if you have not thousand requests per second, this is perfect
    ConnectPerRequest

    # Create persistent connection to server within a fiber.
    # Much faster than ConnectPerRequest, when you need to run millions
    # sequential requests within a fiber.
    # But if you need concurrent clients, you should create new client
    # for every fiber
    Persistent
  end

  def initialize(@host : String,
                 @port : Int32,
                 @command_timeout : Float64? = nil,
                 @connect_timeout : Float64? = nil,
                 @mode : Mode = Mode::Persistent)
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

  private def raw_request(method, args, msgid = 0_u32)
    # instantinate connection
    socket
    writer

    # write request to server
    if @mode.persistent?
      begin
        write_request(method, args, msgid)
      rescue SimpleRpc::ConnectionError
        # connection already closed here, in catch_connection_errors
        # retry it again with new connection
        write_request(method, args, msgid)
      end
    else
      write_request(method, args, msgid)
    end

    # read request from server
    res = catch_connection_errors do
      begin
        unpacker = MessagePack::IOUnpacker.new(socket)
        msg = read_msg_id(unpacker)
        unless msgid == msg
          close
          raise SimpleRpc::ProtocallError.new("unexpected msgid: expected #{msgid}, but got #{msg}")
        end

        yield(MessagePack::NodeUnpacker.new(unpacker.read_node))
      rescue ex : MessagePack::TypeCastError | MessagePack::UnexpectedByteError
        close
        raise SimpleRpc::ProtocallError.new(ex.message)
      end
    end

    res
  ensure
    close if @mode.connect_per_request?
  end

  private def raw_notify(method, args)
    # instantinate connection
    socket
    writer

    # write request to server
    if @mode.persistent?
      begin
        write_request(method, args, 0_u32, true)
      rescue SimpleRpc::ConnectionError
        # connection already closed here, in catch_connection_errors
        # retry it again with new connection
        write_request(method, args, 0_u32, true)
      end
    else
      write_request(method, args, 0_u32, true)
    end
  ensure
    close if @mode.connect_per_request?
  end

  private def write_request(method, args, msgid, notify = false)
    catch_connection_errors do
      write_header(writer, method, msgid, notify) do |packer|
        args.to_msgpack(packer)
      end
    end
  end

  private def write_header(io, method, msgid = 0_u32, notify = false)
    packer = MessagePack::Packer.new(io)
    if notify
      packer.write_array_start(3_u8)
      packer.write(2_i8)
      packer.write(method)
      yield packer
    else
      packer.write_array_start(4_u8)
      packer.write(0_i8)
      packer.write(msgid)
      packer.write(method)
      yield packer
    end
    io.flush
  end

  private def read_msg_id(unpacker) : UInt32
    size = unpacker.read_array_size
    unpacker.finish_token!

    raise MessagePack::TypeCastError.new("Unexpected result array size, should 4, not #{size}") unless size == 4

    id = Int8.new(unpacker)
    raise MessagePack::TypeCastError.new("Unexpected message result sign #{id}") unless id == 1_i8

    msgid = UInt32.new(unpacker)

    msg = Union(String | Nil).new(unpacker)
    if msg
      Nil.new(unpacker) # skip empty result
      raise SimpleRpc::RuntimeError.new(msg)
    end

    msgid
  end

  private def catch_connection_errors
    yield
  rescue ex : Errno | IO::Error | MessagePack::EofError
    close
    raise SimpleRpc::ConnectionLostError.new("#{ex.class}: #{ex.message}")
  rescue ex : IO::Timeout
    close
    raise SimpleRpc::CommandTimeoutError.new("Command timed out")
  end

  def socket
    @socket ||= connect
  end

  def writer
    socket
  end

  private def connect
    _socket = TCPSocket.new @host, @port, connect_timeout: @connect_timeout
    if t = @command_timeout
      _socket.read_timeout = t
      _socket.write_timeout = t
    end
    _socket.read_buffering = true
    _socket.sync = false
    _socket
  rescue ex : IO::Timeout | Errno | Socket::Error
    raise SimpleRpc::CannotConnectError.new("#{ex.class}: #{ex.message}")
  end

  def close
    @socket.try(&.close) rescue nil
    @socket = nil
  end
end
