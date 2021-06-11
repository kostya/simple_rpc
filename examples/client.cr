require "../src/simple_rpc"

client = SimpleRpc::Client.new("127.0.0.1", 9000)

result = client.request!(Float64, :sum, 3, 5.5) # here can raise SimpleRpc::Errors
p result                                        # => 8.5

result = client.request!(MessagePack::Any, :greeting, "Vasya") # here can raise SimpleRpc::Errors
p result.as_h                                                  # => {"rand" => 0.7839463879734746, "msg" => "Hello from Crystal Vasya"}
