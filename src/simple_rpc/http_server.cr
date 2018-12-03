require "./server"

class SimpleRpc::HttpServer < SimpleRpc::Server
  @server : HTTP::Server?

  def initialize(@host : String, @port : Int32)
  end

  def run
    @server = server = HTTP::Server.new do |context|
      if body = context.request.body
        path = context.request.path
        if path == "/rpc.msgpack"
          req = load_request(body)
          case req
          when Request
            ctx = Context.new(req, context.response)
            unless handle_request(ctx)
              ctx.write_error(ReqError.new(SimpleRpc::Error::UNKNOWN_METHOD, req.method))
            end
          when ReqError
            Context.write_error(context.response, req)
          end
        else
          Context.write_error(context.response, ReqError.new(SimpleRpc::Error::UNKNOWN_METHOD, "wrong path #{path}"))
        end
      else
        Context.write_error(context.response, ReqError.new(SimpleRpc::Error::ERROR_UNPACK_REQUEST, "no body"))
      end
    end
    server.bind_tcp @host, @port
    server.listen
  end

  protected def handle_request(ctx : ContextHandler)
  end

  def close
    @server.try(&.close) rescue nil
  end
end
