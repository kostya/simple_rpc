require "socket"

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
    # sequential requests within a fiber
    Persistent
  end

  def initialize(@host : String,
                 @port : Int32,
                 @command_timeout : Float64? = nil,
                 @connect_timeout : Float64? = nil,
                 @mode : Mode = Mode::Persistent)
  end

  def request!(klass : T.class, name, *args) forall T
    raw_request(klass, name, Tuple.new(*args))
  end

  def request(klass : T.class, name, *args) forall T
    res = raw_request(klass, name, Tuple.new(*args))
    SimpleRpc::Result(T).new(nil, res)
  rescue ex : SimpleRpc::Errors
    SimpleRpc::Result(T).new(ex)
  end

  private def raw_request(klass : T.class, method, args, msgid = 0_u32) forall T
    # instantinate sockets
    socket
    writer

    # write request to server
    with_reconnect(@mode.persistent?) do
      self.class.catch_socket_errors do
        write(writer, method, msgid, notify: false) do |packer|
          args.to_msgpack(packer)
        end
      end
    end

    # read request from server
    self.class.catch_socket_errors do
      unpacker = MessagePack::IOUnpacker.new(socket)
      _msgid = read_msg_id(unpacker)

      raise SimpleRpc::ProtocallError.new("unexpected msgid: expected #{msgid}, but got #{_msgid}") unless msgid == _msgid

      begin
        klass.new(unpacker)
      rescue MessagePack::Error
        raise SimpleRpc::ProtocallError.new("unexpected type of result type, expected #{klass.inspect}")
      end
    end
  ensure
    close if @mode.connect_per_request?
  end

  private def write(io, method, msgid = 0_u32, notify = false)
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

  def read_msg_id(unpacker) : String | UInt32
    token = unpacker.next_token
    raise SimpleRpc::ProtocallError.new("unexpected result type: #{token.type}") unless token.type.array?
    size = token.size
    raise SimpleRpc::ProtocallError.new("unexpected result array size #{size}") unless size == 4

    token = unpacker.next_token
    id = case token.type
         when .int?
           token.int_value.to_i8
         when .uint?
           token.uint_value.to_i8
         else
           raise SimpleRpc::ProtocallError.new("unexpected message header #{token.type}")
         end
    raise SimpleRpc::ProtocallError.new("unexpected message response sign #{id}") unless id == 1_i8

    token = unpacker.next_token
    msgid = case token.type
            when .int?
              token.int_value.to_u32
            when .uint?
              token.uint_value.to_u32
            else
              raise SimpleRpc::ProtocallError.new("unexpected message msgid #{token.type}")
            end

    token = unpacker.next_token
    case token.type
    when .null?
    when .string?
      msg = token.string_value
      unpacker.next_token # skip nil result
      raise SimpleRpc::RuntimeError.new(msg)
    else
      raise SimpleRpc::ProtocallError.new("unexpected message error #{token.type}")
    end

    msgid
  rescue ex : MessagePack::UnpackException
    # still possible invalid symbol in msgpack, or just wrong server like http
    # so need to catch it
    raise SimpleRpc::ProtocallError.new(ex.message)
  end

  def self.catch_socket_errors
    yield
  rescue ex : Errno | IO::Error
    raise SimpleRpc::ConnectionLostError.new("#{ex.class}: #{ex.message}")
  rescue ex : IO::Timeout
    raise SimpleRpc::CommandTimeoutError.new("Command timed out")
  end

  private def with_reconnect(reconnect = true)
    yield
  rescue ex : SimpleRpc::ConnectionError
    if reconnect
      close
      yield
    else
      raise ex
    end
  rescue SimpleRpc::CommandTimeoutError
    # not retrying this
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
    socket = TCPSocket.new @host, @port, connect_timeout: @connect_timeout
    if t = @command_timeout
      socket.read_timeout = t
      socket.write_timeout = t
    end
    socket.read_buffering = true
    socket.sync = false
    socket
  rescue ex : IO::Timeout | Errno | Socket::Error
    raise SimpleRpc::CannotConnectError.new("#{ex.class}: #{ex.message}")
  end

  def close
    @socket.try(&.close) rescue nil
    @socket = nil
  end
end
