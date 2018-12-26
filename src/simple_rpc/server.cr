require "socket"

class SimpleRpc::Server
  @server : TCPServer?

  def initialize(@host : String, @port : Int32)
  end

  private def request(reader_io, writer_io)
    case ctx = read_context(reader_io, writer_io)
    when Context
      handle_request(ctx) || ctx.write_error("method '#{ctx.method}' not found")
    when String
      writer_io.puts("Unsupport protocall: #{ctx}")
      writer_io.flush
      nil
    end
  end

  private def read_context(reader_io, writer_io) : Context | String
    unpacker = MessagePack::IOUnpacker.new(reader_io)
    token = unpacker.read_token

    return "expected array" unless token.is_a?(MessagePack::Token::ArrayT)
    size = token.size

    # size = 3, notify message
    # size = 4, request

    if size == 3 || size == 4
      token = unpacker.read_token
      id = case token
           when MessagePack::Token::IntT
             token.value.to_i8
           else
             return "unexpected message header #{token.inspect}"
           end

      if size == 4
        return "unexpected message request sign #{id}" unless id == 0_i8
      else
        return "unexpected message notify sign #{id}" unless id == 2_i8
      end

      msgid = if size == 4
                token = unpacker.read_token
                case token
                when MessagePack::Token::IntT
                  token.value.to_u32
                else
                  return "unexpected message msgid #{token.inspect}"
                end
              else
                0_u32
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

      Context.new(msgid, method, args_count, unpacker, writer_io, size == 3)
    else
      "unexpected array size #{size}"
    end
  end

  def handle(reader_io, writer_io)
    reader_io.read_buffering = true if reader_io.responds_to?(:read_buffering)
    writer_io.sync = false if writer_io.responds_to?(:sync=)

    loop do
      break unless request(reader_io, writer_io)
    end
  rescue ex : Errno | IO::Error | Socket::Error | MessagePack::EofError | MessagePack::UnexpectedByteError
    # on any socket errors, just silently close connection
    # TODO: maybe need to log it

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

  protected def handle_request(ctx : Context)
  end

  def close
    @server.try(&.close) rescue nil
    @server = nil
  end
end
