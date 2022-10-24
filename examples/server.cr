require "../src/simple_rpc"

struct MyRpc
  include SimpleRpc::Proto

  def sum(x1 : Int32, x2 : Float64) : Float64
    puts "Got sum request #{x1}, #{x2}"
    x1 + x2
  end

  record Greeting, rand : Float64, msg : String { include MessagePack::Serializable }

  def greeting(name : String) : Greeting
    Greeting.new(rand, "Hello from Crystal #{name}")
  end
end

port = (ARGV[0]? || 9000).to_i
puts "Server listen on #{port} port"
MyRpc::Server.new("127.0.0.1", port).run
