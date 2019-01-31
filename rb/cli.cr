require "../src/simple_rpc"

PORT = (ARGV[0]? || 18800).to_i
client = SimpleRpc::Client.new("127.0.0.1", PORT)
result = client.request!(NamedTuple(value: Float64), :methodName, 1, 1.5, "2.7", {5 => 15.8})
p result
