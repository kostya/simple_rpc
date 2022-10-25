require "../src/simple_rpc"

port = (ARGV[0]? || 9003).to_i
proxy = SimpleRpc::ServerProxy.new("127.0.0.1", port)
proxy.set_ports [9004, 9005, 9006]
puts "Listen on #{port}"
proxy.run
