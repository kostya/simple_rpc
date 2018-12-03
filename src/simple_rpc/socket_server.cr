require "socket"
require "./server"

class SimpleRpc::SocketServer < SimpleRpc::Server
  @server : TCPServer?

  def initialize(@host : String, @port : Int32)
  end

  private def _request(client)
    req = load_request(client)
    case req
    when Request
      ctx = Context.new(req, client)
      unless handle_request(ctx)
        return ctx.write_error(ReqError.new(SimpleRpc::Error::UNKNOWN_METHOD, req.method))
      end
    when ReqError
      return Context.write_error(client, req)
    when Eof
      return
    end

    Context.write_error(client, ReqError.new(SimpleRpc::Error::UNKNOWN_ERROR, ""))
  end

  # TODO: think about flushing
  private def handle(client)
    client.sync = false
    while !client.closed?
      break unless _request(client)
    end
  end

  def run
    @server = server = TCPServer.new @host, @port
    loop { spawn handle(server.accept) }
  end

  protected def handle_request(ctx : Context)
  end

  def close
    @server.try(&.close) rescue nil
  end
end
