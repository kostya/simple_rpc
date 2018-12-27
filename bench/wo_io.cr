require "../src/simple_rpc"

class SimpleRpc::Client
  property fake_io_r : IO?
  property fake_io_w : IO?

  def socket
    @fake_io_r || previous_def
  end

  def writer
    @fake_io_w || previous_def
  end
end

class Bench
  include SimpleRpc::Proto

  def jop(a : Float64) : Float64
    a * 1.33 + 1.8
  end
end

N = (ARGV[0]? || 1000).to_i
MODE = (ARGV[1]? == "1") ? SimpleRpc::Client::Mode::ConnectPerRequest : SimpleRpc::Client::Mode::Persistent
p "running in mode #{MODE}, for #{N}"

PIP1 = IO::Stapled.new(*IO.pipe)
PIP2 = IO::Stapled.new(*IO.pipe)

# FAKE server
fake_server = Bench::Server.new("127.0.0.1", 9003, false)
spawn do
  fake_server.handle(PIP1, PIP2)
end
IOCLIENT = Bench::Client.new("127.0.0.1", 9003, mode: MODE)
IOCLIENT.fake_io_r = PIP2
IOCLIENT.fake_io_w = PIP1

sleep 0.5

t = Time.now
s = 0.0
N.times do |i|
  res = IOCLIENT.jop(i.to_f)
  if res.ok?
    s += res.value!
  else
    raise res.message!
  end
end

p s
p Time.now - t

