class SimpleRpc::Server
  def initialize(@host : String, @port : Int32)
  end

  def run
    server = HTTP::Server.new do |context|
      context.response.headers["Content-Type"] = "application/msgpack"
      body = context.request.body.try(&.gets_to_end)
      if body
        begin
          raw = Base64.decode(body)
          handle_http(context.request.path, raw, context.response)
        rescue Base64::Error
          {SimpleRpc::Error::ERROR_UNPACK_REQUEST, "not base64", nil}.to_msgpack(context.response)
        end
      else
        {SimpleRpc::Error::ERROR_UNPACK_REQUEST, "not start with args=", nil}.to_msgpack(context.response)
      end
    end
    server.bind_tcp @host, @port
    server.listen
  end

  def handle_http(path, raw, response)
  end
end
