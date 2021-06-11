require "../src/simple_rpc"

client = SimpleRpc::Client.new("127.0.0.1", 9000)

p client.request!(Float64, :sum, 3, 5.5)                       # => 8.5
p client.request!(MessagePack::Any, :authorize, "Vasya", 1234) # => {"rand" => 0.7839463879734746, "msg" => "Hello from Crystal Vasya"}
p client.request!(MessagePack::Any, :authorize, "-", 1)        # => {"rand" => 0.7839463879734746, "msg" => "Hello from Crystal Vasya"}
