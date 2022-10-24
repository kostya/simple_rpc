require "../src/simple_rpc"

port = (ARGV[0]? || 9000).to_i
client = SimpleRpc::Client.new("127.0.0.1", port)

p client.request!(Float64, :sum, 3, 5.5)
# => 8.5
