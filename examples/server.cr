require "../src/simple_rpc"

struct MyRpc
  include SimpleRpc::Proto

  def sum(x1 : Int32, x2 : Float64) : Float64
    x1 + x2
  end

  record Accepted, url : String, salt : Float64 { include MessagePack::Serializable }
  record Rejected, error : String { include MessagePack::Serializable }

  def authorize(name : String, password : Int32) : Accepted | Rejected
    (name == "Vasya" && password == 1234) ? Accepted.new("http://...", rand) : Rejected.new("Not allowed")
  end
end

puts "Server listen on 9000 port"
MyRpc::Server.new("127.0.0.1", 9000).run
