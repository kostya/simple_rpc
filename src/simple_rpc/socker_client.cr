require "./client"
require "socket"

class SimpleRpc::SocketClient < SimpleRpc::Client
  def initialize(@host : String, @port : Int32, @timeout : Float64? = nil, @connect_timeout : Float64? = nil)
  end

  def request(klass : T.class, name, *args) forall T
    res, msg = raw_request(name, Tuple.new(*args)) do |io|
      return SimpleRpc::Result(T).from(io)
    end
    SimpleRpc::Result(T).new(res, msg)
  end

  private def raw_request(action, args)
    with_client do |client|
      write_request(client, action, args)
      client.flush
      yield client
    end
  end

  private def with_client
    client = TCPSocket.new @host, @port, connect_timeout: @connect_timeout
    if t = @timeout
      client.read_timeout = t
    end
    client.sync = false

    yield client
    {Error::OK, nil}
  rescue IO::Timeout
    {Error::TIMEOUT, "Timeouted (#{@timeout}, #{@connect_timeout})"}
  rescue ex
    {Error::CONNECTION_ERROR, ex.message}
  ensure
    client.try(&.close) rescue nil
  end
end
