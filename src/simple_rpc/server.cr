require "socket"

class SimpleRpc::Server
  @server : TCPServer?

  def initialize(@host : String, @port : Int32, @debug = false, @close_connection_after_request = false)
  end

  private def read_context(reader_io, writer_io) : Context
    unpacker = MessagePack::IOUnpacker.new(reader_io)
    size = unpacker.read_array_size
    unpacker.finish_token!

    request = (size == 4)
    unless request || size == 3
      raise MessagePack::TypeCastError.new("Unexpected request array size, should be 3 or 4, not #{size}")
    end

    id = Int8.new(unpacker)

    if request
      raise MessagePack::TypeCastError.new("Unexpected message request sign #{id}") unless id == 0_i8
    else
      raise MessagePack::TypeCastError.new("Unexpected message notify sign #{id}") unless id == 2_i8
    end

    msgid = request ? UInt32.new(unpacker) : 0_u32
    method = String.new(unpacker)

    args_count = unpacker.read_array_size
    unpacker.finish_token!

    Context.new(msgid, method, args_count, unpacker, writer_io, !request)
  end

  def handle(reader_io, writer_io)
    reader_io.read_buffering = true if reader_io.responds_to?(:read_buffering)
    writer_io.sync = false if writer_io.responds_to?(:sync=)

    loop do
      ctx = read_context(reader_io, writer_io)
      handle_request(ctx) || ctx.write_error("method '#{ctx.method}' not found")
      break if @close_connection_after_request
    end
  rescue ex : Errno | IO::Error | Socket::Error | MessagePack::TypeCastError | MessagePack::UnexpectedByteError
    debug(ex.message)
  rescue ex : MessagePack::EofError
  ensure
    reader_io.close rescue nil
    if writer_io != reader_io
      writer_io.close rescue nil
    end
  end

  private def debug(msg)
    puts(msg) if @debug
  end

  def run
    @server = server = TCPServer.new @host, @port
    loop do
      client = begin
        server.accept
      rescue IO::Error
        close
        return
      end
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
