require "../src/simple_rpc"

# Example ping pong:
#   run two processes:
#      crystal examples/ping_pong.cr -- 9000
#      crystal examples/ping_pong.cr -- 9001 9000

class MyRpc
  include SimpleRpc::Proto

  def ping(port : Int32, x : Int32) : Nil
    puts "got #{x} from 127.0.0.1:#{port}"

    sleep 0.5
    MyRpc::Client.new("127.0.0.1", port).ping(PORT, x + 1)
    nil
  end
end

PORT = (ARGV[0]? || 9000).to_i
server = MyRpc::Server.new("127.0.0.1", PORT)
spawn { server.run }
puts "Server on #{PORT} started"

if ping_port = ARGV[1]?
  sleep 1
  MyRpc::Client.new("127.0.0.1", ping_port.to_i).ping(PORT, 0)
end

sleep
