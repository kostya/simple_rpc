require "socket"

class SimpleRpc::Server
  @server : TCPServer?

  def initialize(@host : String, @port : Int32)
  end

  record RawMsgpack, data : Bytes
  record IOMsgpack, io : IO

  record Ctx, msgid : UInt32, method : String, args_count : UInt32, unpacker : MessagePack::IOUnpacker, io : IO do
    def skip_values(n)
      n.times do
        unpacker.skip_value
      end
      # rescue MessagePack::UnpackException
      # not catching this, becase in exception connection would be just closed
    end

    def write_result(res)
      case res
      when RawMsgpack
        packer = MessagePack::Packer.new(io)
        packer.write_array_start(4_u8)
        packer.write(1_u8)
        packer.write(msgid)
        packer.write(nil)
        io.write(res.data)
      when IOMsgpack
        packer = MessagePack::Packer.new(io)
        packer.write_array_start(4_u8)
        packer.write(1_u8)
        packer.write(msgid)
        packer.write(nil)
        IO.copy(res.io, io)
      else
        {1_u8, msgid, nil, res}.to_msgpack(io)
      end

      io.flush
      true
    end

    def write_error(msg)
      {1_u8, msgid, msg, nil}.to_msgpack(io)
      io.flush
      true
    end
  end

  private def _request(reader_io, writer_io)
    self.class.catch_socket_errors do
      # any socket errors catched in handle, with just close connection

      case ctx = read_context(reader_io, writer_io)
      when Ctx
        handle_request(ctx) || ctx.write_error("method '#{ctx.method}' not found")
      when Nil
        # eof
        nil
      when String
        # error in protocall
        # likely impossible branch, in normal client-server interaction
        {1_u8, 0_u32, ctx, nil}.to_msgpack(writer_io)
        writer_io.flush
        nil
      end
    end
  end

  private def read_context(reader_io, writer_io) : Ctx | String | Nil
    unpacker = MessagePack::IOUnpacker.new(reader_io)
    token = unpacker.read_token

    return "expected array token" unless token.is_a?(MessagePack::Token::ArrayT)
    size = token.size

    case size
    when 3
      return "unsupported notify message"
    when 4
      token = unpacker.read_token
      id = case token
           when MessagePack::Token::IntT
             token.value.to_i8
           else
             return "unexpected message header #{token.inspect}"
           end
      return "unexpected message request sign #{id}" unless id == 0_i8

      token = unpacker.read_token
      msgid = case token
              when MessagePack::Token::IntT
                token.value.to_u32
              else
                return "unexpected message msgid #{token.inspect}"
              end

      token = unpacker.read_token
      method = case token
               when MessagePack::Token::StringT
                 token.value
               else
                 return "expected method as string, but got #{token.inspect}"
               end

      token = unpacker.read_token
      args_count = case token
                   when MessagePack::Token::ArrayT
                     token.size
                   else
                     return "expected array as args, but got #{token.inspect}"
                   end

      Ctx.new(msgid, method, args_count, unpacker, writer_io)
    else
      "unexpected array size #{size}"
    end
  rescue ex : MessagePack::UnexpectedByteError
    # still possible to read bad messages from socket
    ex.message || "unpack exception"
  end

  def self.catch_socket_errors
    yield
  rescue ex : Errno | IO::Error
    raise SimpleRpc::ConnectionLostError.new("#{ex.class}: #{ex.message}")
  end

  def handle(reader_io, writer_io)
    reader_io.read_buffering = true if reader_io.responds_to?(:read_buffering)
    writer_io.sync = false if writer_io.responds_to?(:sync=)
    while !reader_io.closed? && !writer_io.closed?
      break unless _request(reader_io, writer_io)
    end
  rescue MessagePack::EofError
  ensure
    reader_io.close rescue nil
    if writer_io != reader_io
      writer_io.close rescue nil
    end
  end

  def run
    @server = server = TCPServer.new @host, @port
    loop do
      client = server.accept
      spawn handle(client, client)
    end
  end

  protected def handle_request(ctx : Ctx)
  end

  def close
    @server.try(&.close) rescue nil
  end
end
