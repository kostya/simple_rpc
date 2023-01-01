require "socket"
require "msgpack"
require "openssl"
require "log"

abstract class SimpleRpc::Server
  @server : TCPServer | UNIXServer | Nil

  def initialize(@host : String = "127.0.0.1", @port : Int32 = 9999, @unixsocket : String? = nil, @ssl_context : OpenSSL::SSL::Context::Server? = nil,
                 @logger : Log? = nil, @close_connection_after_request = false)
    after_initialize
    add_wrappers
  end

  protected def after_initialize
  end

  protected def add_wrappers
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

    io_with_args = IO::Memory.new
    MessagePack::Copy.new(io, io_with_args).copy_object
    io_with_args.rewind

    Context.new(msgid, method, io_with_args, io, !request, @logger)
  end

  protected def handle(io)
    io.read_buffering = true if io.responds_to?(:read_buffering)
    io.sync = false if io.responds_to?(:sync=)

    if ssl_context = @ssl_context
      io = OpenSSL::SSL::Socket::Server.new(io, ssl_context)
    end

    loop do
      ctx = read_context(io)
      ctx.read_args_count
      handle_request(ctx)
      break if @close_connection_after_request
    end
  rescue ex : IO::Error | Socket::Error | MessagePack::TypeCastError | MessagePack::UnexpectedByteError | OpenSSL::Error
    if l = @logger
      l.error { "SimpleRpc: protocol ERROR #{ex.message}" }
    end
  rescue ex : MessagePack::EofError
  ensure
    io.close rescue nil
  end

  def _handle(client)
    handle(client)
  end

  protected def before_run
  end

  def run
    @server = server = if us = @unixsocket
                         UNIXServer.new(us)
                       else
                         TCPServer.new @host, @port
                       end

    before_run
    loop do
      if client = server.accept?
        spawn _handle(client)
      else
        close
        break
      end
    end
  end

  abstract def method_find(method : String) : (SimpleRpc::Context ->)?

  protected def handle_request(ctx : Context)
    if result = method_find ctx.method
      result.call(ctx)
    else
      ctx.write_error("method '#{ctx.method}' not found")
    end
  end

  def close
    @server.try(&.close) rescue nil
    @server = nil
  end
end
