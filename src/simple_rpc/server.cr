class SimpleRpc::Server
  @server : HTTP::Server?

  def initialize(@host : String, @port : Int32)
  end

  record RawMsgpack, data : Bytes
  record IOMsgpack, io : IO

  def run
    @server = server = HTTP::Server.new do |context|
      context.response.headers["Content-Type"] = "application/msgpack"
      body = context.request.body.try(&.gets_to_end)
      if body
        begin
          raw = Base64.decode(body)
          handle_http(context.request.path, raw, context.response)
        rescue Base64::Error
          pack(context.response, SimpleRpc::Error::ERROR_UNPACK_REQUEST, "not base64")
        end
      else
        pack(context.response, SimpleRpc::Error::ERROR_UNPACK_REQUEST, "not start with args=")
      end
    end
    server.bind_tcp @host, @port
    server.listen
  end

  def pack(response, err, msg, res = nil)
    err.to_msgpack(response)
    msg.to_msgpack(response)

    case res
    when IOMsgpack
      IO.copy(res.io, response)
    when RawMsgpack
      response.write(res.data)
    else
      res.to_msgpack(response)
    end
  end

  def handle_http(path, raw, response)
  end

  def close
    @server.try(&.close) rescue nil
  end
end
