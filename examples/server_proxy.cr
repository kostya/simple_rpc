require "../src/simple_rpc"

port = (ARGV[0]? || 9000).to_i
proxy = SimpleRpc::ServerProxy.new("127.0.0.1", port)
proxy.ports = [9001, 9002]

puts "Server Proxy listen on #{port} port, and mapping: #{proxy.ports}"
proxy.run
