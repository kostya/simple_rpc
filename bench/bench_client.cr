require "../src/simple_rpc"

class Bench
  include SimpleRpc::Proto
end

CONCURRENCY = (ARGV[0]? || 10).to_i
REQUESTS    = (ARGV[1]? || 1000).to_i
mode = (ARGV[2]? == "1") ? SimpleRpc::Client::Mode::ConnectPerRequest : SimpleRpc::Client::Mode::Persistent

puts "Running in #{mode}, requests: #{REQUESTS}, concurrency: #{CONCURRENCY}"

ch = Channel(Bool).new

n = 0
s = 0.0
t = Time.now

CONCURRENCY.times do
  spawn do
    client = Bench::Client.new("127.0.0.1", 9003, mode: mode)
    (REQUESTS / CONCURRENCY).times do
      n += 1
      res = client.request(Float64, :doit, 1 / n.to_f)
      if res.ok?
        s += res.value!
      else
        raise res.message!
      end
    end
    ch.send(true)
  end
end

CONCURRENCY.times { ch.receive }
p s
p Time.now - t
