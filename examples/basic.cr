require "../src/simple_rpc"

# Example run server and client.

class MyRpc
  # When including SimpleRpc::Proto, all public instance methods inside class,
  # would be exposed to external rpc call.
  # Each method should define type for each argument, and also return type.
  # (Types of arguments should supports MessagePack::Serializable).
  # Instance of this class created on server for each call.
  include SimpleRpc::Proto

  def bla(x : Int32, y : String) : Float64
    x * y.to_f
  end
end

spawn do
  # running RPC server on 9000 port in background fiber
  MyRpc::Server.new("127.0.0.1", 9000).run
end

# wait until server up
sleep 0.1

# create rpc client
client = MyRpc::Client.new("127.0.0.1", 9000)
result = client.bla!(3, "5.5")
p result # => 16.5

sleep
