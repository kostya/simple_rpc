require "socket"
require "msgpack"
require "log"

class SimpleRpc::Server
  @server : TCPServer | UNIXServer | Nil

  def initialize(@host : String = "127.0.0.1", @port : Int32 = 9999, @unixsocket : String? = nil, @logger : Log? = nil, @close_connection_after_request = false)
  end

  private def read_context(io) : Context
    unpacker = MessagePack::IOUnpacker.new(io)
    size = unpacker.read_array_size
    unpacker.finish_token!

    request = (size == SimpleRpc::REQUEST_SIZE)
    unless request || size == SimpleRpc::NOTIFY_SIZE
      raise MessagePack::TypeCastError.new("Unexpected request array size, should be #{SimpleRpc::REQUEST_SIZE} or #{SimpleRpc::NOTIFY_SIZE}, not #{size}")
    end

    id = Int8.new(unpacker)

    if request
      raise MessagePack::TypeCastError.new("Unexpected message request sign #{id}") unless id == SimpleRpc::REQUEST
    else
      raise MessagePack::TypeCastError.new("Unexpected message notify sign #{id}") unless id == SimpleRpc::NOTIFY
    end

    msgid = request ? UInt32.new(unpacker) : SimpleRpc::DEFAULT_MSG_ID
    method = String.new(unpacker)

    args_count = unpacker.read_array_size
    unpacker.finish_token!

    Context.new(msgid, method, args_count, unpacker, io, !request, @logger)
  end

  def handle(io)
    io.read_buffering = true if io.responds_to?(:read_buffering)
    io.sync = false if io.responds_to?(:sync=)

    loop do
      ctx = read_context(io)
      handle_request(ctx) || ctx.write_error("method '#{ctx.method}' not found")
      break if @close_connection_after_request
    end
  rescue ex : IO::Error | Socket::Error | MessagePack::TypeCastError | MessagePack::UnexpectedByteError
    if l = @logger
      l.error { "SimpleRpc: protocall ERROR #{ex.message}" }
    end
  rescue ex : MessagePack::EofError
  ensure
    io.close rescue nil
  end

  def run
    @server = server = if us = @unixsocket
                         UNIXServer.new(us)
                       else
                         TCPServer.new @host, @port
                       end

    loop do
      client = begin
        server.accept
      rescue Socket::Error
        close
        return
      end
      spawn handle(client)
    end
  end

  protected def handle_request(ctx : Context)
  end

  def close
    @server.try(&.close) rescue nil
    @server = nil
  end
end
