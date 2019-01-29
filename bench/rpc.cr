require "../src/simple_rpc"

class Bench
  include SimpleRpc::Proto

  def inc(a : Int32) : Int32
    a + 1
  end
end

spawn do
  Bench::Server.new("127.0.0.1", 9002).run
end

sleep 0.5
N = (ARGV[0]? || 1000).to_i
mode = case (ARGV[1]? || "0")
       when "0"
         SimpleRpc::Client::Mode::Single
       when "1"
         SimpleRpc::Client::Mode::ConnectPerRequest
       else
         SimpleRpc::Client::Mode::Pool
       end
p "running in mode #{mode}, for #{N}"

client = Bench::Client.new("127.0.0.1", 9002, mode: mode)
t = Time.now
s = 0
N.times do |i|
  res = client.inc(i)
  if res.ok?
    s += res.value!
  else
    raise res.message!
  end
end

p s
p Time.now - t
