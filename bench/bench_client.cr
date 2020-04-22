require "../src/simple_rpc"

class Bench
  include SimpleRpc::Proto
end

CONCURRENCY = (ARGV[0]? || 10).to_i
REQUESTS    = (ARGV[1]? || 1000).to_i
mode = case (ARGV[2]? || "0")
       when "0"
         SimpleRpc::Client::Mode::Single
       when "1"
         SimpleRpc::Client::Mode::ConnectPerRequest
       else
         SimpleRpc::Client::Mode::Pool
       end

puts "Running in #{mode}, requests: #{REQUESTS}, concurrency: #{CONCURRENCY}"

ch = Channel(Bool).new

n = 0
s = 0.0
t = Time.local
c = 0
e = 0

CLIENT = Bench::Client.new("127.0.0.1", 9003, mode: SimpleRpc::Client::Mode::Pool, pool_size: CONCURRENCY + 1)
CONCURRENCY.times do
  spawn do
    client = if mode == SimpleRpc::Client::Mode::Pool
               CLIENT
             else
               Bench::Client.new("127.0.0.1", 9003, mode: mode, pool_size: CONCURRENCY + 1)
             end
    (REQUESTS // CONCURRENCY).times do
      n += 1
      res = client.request(Float64, :doit, 1 / n.to_f)
      if res.ok?
        s += res.value!
        c += 1
      else
        e += 1
        raise res.message!
      end
    end
    ch.send(true)
  end
end

CONCURRENCY.times { ch.receive }
puts "result: #{s}, reqs_to_run: #{CONCURRENCY * (REQUESTS // CONCURRENCY)}, reqs_ok: #{c}, reqs_fails: #{e}"
p Time.local - t
