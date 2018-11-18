require "base64"
require "http/client"

class SimpleRpc::RawClient
  def initialize(@host : String, @port : Int32, @timeout : Int32? = nil, @connect_timeout : Int32? = nil)
  end

  HEADERS = HTTP::Headers{"Content-type" => "application/x-www-form-urlencoded"}

  def request(action, args_array)
    body = "args=#{Base64.urlsafe_encode(args_array.to_msgpack, padding: false)}"
    resp = raw_request("/rpc_#{action}", body)
  end

  def raw_request(action, body)
    with_client do |client|
      client.post(action, body: body, headers: HEADERS) do |response|
        if response.status_code == 200
          return Response.new(Error::OK, response.body_io.gets_to_end.to_slice)
        else
          return Response.new(Error::HTTP_BAD_STATUS)
        end
      end

      Response.new(Error::HTTP_UNKNOWN_ERROR)
    end
  end

  # TODO: catch timeouts
  # TODO: catch connection errors
  private def with_client
    client = HTTP::Client.new @host, @port
    if t = @timeout
      client.read_timeout = t
    end

    if ct = @connect_timeout
      client.connect_timeout = ct
    end

    yield client
  rescue ex
    Response.new(Error::HTTP_EXCEPTION)
  ensure
    client.try(&.close) rescue nil
  end
end
