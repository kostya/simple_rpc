class SimpleRpc::Server
  @server : HTTP::Server?

  def initialize(@host : String, @port : Int32)
  end

  record RawMsgpack, data : Bytes
  record IOMsgpack, io : IO

  def run
    @server = server = HTTP::Server.new do |context|
      # context.response.headers["Content-Type"] = "application/msgpack"
      if body = context.request.body
        handle_http(context.request.path, body, context.response)
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

  def handle_http(path, body_io, response)
  end

  def additional_http(path, body_io, response)
    false
  end

  def close
    @server.try(&.close) rescue nil
  end
end
