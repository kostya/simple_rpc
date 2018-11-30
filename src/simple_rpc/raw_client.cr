require "base64"
require "http/client"

class SimpleRpc::RawClient
  def initialize(@host : String, @port : Int32, @timeout : Float64? = nil, @connect_timeout : Float64? = nil)
  end

  def request(klass : T.class, name, *args) forall T
    res, msg = send_request(name, Tuple.new(*args)) do |io|
      return SimpleRpc::Result(T).from(io)
    end
    SimpleRpc::Result(T).new(res, msg)
  end

  def send_request(action, args_array)
    resp = raw_request("/rpc_#{action}", args_array.to_msgpack) do |io|
      yield io
    end
  end

  def raw_request(action, body)
    with_client do |client|
      client.post(action, body: body) do |response|
        if response.status_code == 200
          yield(response.body_io)
        else
          return {Error::HTTP_BAD_STATUS, "Http status #{response.status_code}"}
        end
      end

      {Error::HTTP_UNKNOWN_ERROR, nil}
    end
  end

  private def with_client
    client = HTTP::Client.new @host, @port
    if t = @timeout
      client.read_timeout = t
    end

    if ct = @connect_timeout
      client.connect_timeout = ct
    end

    yield client
    {Error::OK, nil}
  rescue IO::Timeout
    {Error::TIMEOUT, "Timeouted (#{@timeout}, #{@connect_timeout})"}
  rescue ex
    {Error::HTTP_EXCEPTION, ex.message}
  ensure
    client.try(&.close) rescue nil
  end
end
