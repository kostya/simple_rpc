struct SimpleRpc::Response
  getter error, raw

  def initialize(@error : Error, @raw : Bytes? = nil)
  end
end
