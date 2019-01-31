require "../src/simple_rpc"

class MyHandler
  include SimpleRpc::Proto
  
  def methodName(int : Int32, float : Float64, string : String, hash : Hash(Int32, Float64)) : NamedTuple(value: Float64)
    v = int + float + string.to_f + (hash[5]? || -1.0)

    {value: v}
  end
end

PORT = (ARGV[0]? || 18800).to_i
MyHandler::Server.new("127.0.0.1", PORT).run
