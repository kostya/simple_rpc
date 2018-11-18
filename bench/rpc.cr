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

client = Bench::Client.new("127.0.0.1", 9002)
t = Time.now
s = 0
1000.times do |i|
  res = client.inc(i)
  if (res.error == SimpleRpc::Error::OK) && (v = res.value)
    s += v
  end
end

p s
p Time.now - t
