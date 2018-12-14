require "../src/simple_rpc"

class MyRpc 
  include SimpleRpc::Proto

  def bla(x : Int32, y : String) : Float64
    x * y.to_f
  end
end

spawn do
  MyRpc::Server.new("127.0.0.1", 9000).run
end

sleep 0.1
client = MyRpc::Client.new("127.0.0.1", 9000)
result = client.bla(3, "5.5")

if result.ok?
  p result.value! + 1 # => 17.5
else
  p result.message!
end
