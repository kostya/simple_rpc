require "../src/simple_rpc"

class Bench
  include SimpleRpc::Proto

  def doit(a : Float64) : Float64
    a * 1.5 + 2.33
  end
end

port = (ARGV[0]? || 9003).to_i
p "Listen on #{port}"
Bench::Server.new("127.0.0.1", port).run
