require "../src/simple_rpc"

client = SimpleRpc::Client.new("127.0.0.1", 9000)

p client.request!(Float64, :sum, 3, 5.5)
# => 8.5
p client.request!(MessagePack::Any, :greeting, "Vasya")
# => {"rand" => 0.7839463879734746, "msg" => "Hello from Crystal Vasya"}
