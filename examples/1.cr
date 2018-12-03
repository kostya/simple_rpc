require "../src/simple_rpc"

class MyRpc 
  include SimpleRpc::Proto

  def bla(x : Int32, y : String) : Float64
    x * y.to_f
  end
end

spawn do
  MyRpc::SocketServer.new("127.0.0.1", 9000).run
end

sleep 0.1
client = MyRpc::SocketClient.new("127.0.0.1", 9000)
result = client.bla(3, "5.5")

p result.error # => SimpleRpc::Error::OK
p result.value # => 16.5