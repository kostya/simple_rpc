class SimpleRpc::Client
  def initialize(@host : String, @port : Int32)
    @raw_client = SimpleRpc::RawClient.new(@host, @port)
  end
end
