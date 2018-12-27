require "spec"
require "../src/simple_rpc"

record Bla, x : String, y : Hash(String, Int32) { include MessagePack::Serializable }

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

class SpecProto
  include SimpleRpc::Proto

  def bla(x : String, y : Float64) : Float64
    x.to_f * y
  end

  def complex(a : Int32) : Bla
    h = Hash(String, Int32).new
    a.times do |i|
      h["_#{i}_"] = i
    end

    Bla.new(a.to_s, h)
  end

  def sleepi(v : Float64) : Int32
    sleep(v)
    1
  end

  def no_args : Int32
    0
  end

  def with_default_value(x : Int32 = 1) : Int32
    x + 1
  end

  def raw_result : SimpleRpc::Context::RawMsgpack
    SimpleRpc::Context::RawMsgpack.new({1, "bla", 6.5}.to_msgpack)
  end

  def stream_result : SimpleRpc::Context::IOMsgpack
    bytes = {1, "bla", 6.5}.to_msgpack
    io = IO::Memory.new(bytes)
    SimpleRpc::Context::IOMsgpack.new(io)
  end

  def bin_input_args(x : Array(String), y : Float64) : String
    w = 0_u64

    x.each do |s|
      s.each_byte { |b| w += b }
    end

    (w * y).to_s
  end

  def big_result(x : Int32) : Hash(String, String)
    h = {} of String => String
    x.times do |i|
      h["__----#{i}------"] = "asfasdflkqwflqwe#{i}"
    end
    h
  end

  def invariants(x : Int32) : MessagePack::Type
    case x
    when 0
      1_i64
    when 1
      "1"
    when 2
      5.5
    when 3
      Array.new(3) { |i| i.to_i64.as(MessagePack::Type) }
    else
      false
    end.as(MessagePack::Type)
  end

  def unions(x : Int32 | String) : Int32 | String | Float64 | Array(Int32) | Bool
    case x.to_i
    when 0
      1
    when 1
      "1"
    when 2
      5.5
    when 3
      [1, 2, 3]
    else
      false
    end
  end

  class_property notify_count = 0

  def notify(x : Int32) : Nil
    @@notify_count += x
    nil
  end
end

class SpecProto2
  include SimpleRpc::Proto

  def bla(x : Float64, y : String) : Float64
    x * y.to_f
  end

  def zip : Nil
  end
end

spawn do
  SpecProto::Server.new("127.0.0.1", 8888, false).run
end

def bad_server_handle(client)
  Tuple(Int8, UInt32, String, Array(MessagePack::Type)).from_msgpack(client)
  client.write_byte(193_u8) # write illegal msgpack value
  client.flush
end

spawn do
  bad_server = TCPServer.new("127.0.0.1", 8889)
  loop do
    cli = bad_server.accept
    spawn bad_server_handle(cli)
  end
end

sleep 0.1

CLIENT         = SpecProto::Client.new("127.0.0.1", 8888)
CLIENT_TIMEOUT = SpecProto::Client.new("127.0.0.1", 8888, command_timeout: 0.2)
CLIENT_BAD     = SpecProto::Client.new("127.0.0.1", 9999)
CLIENT2        = SpecProto2::Client.new("127.0.0.1", 8888)
CLIENT3        = SpecProto2::Client.new("127.0.0.1", 8889)

PER_CLIENT         = SpecProto::Client.new("127.0.0.1", 8888, mode: SimpleRpc::Client::Mode::ConnectPerRequest)
PER_CLIENT_TIMEOUT = SpecProto::Client.new("127.0.0.1", 8888, command_timeout: 0.2, mode: SimpleRpc::Client::Mode::ConnectPerRequest)
PER_CLIENT_BAD     = SpecProto::Client.new("127.0.0.1", 9999, mode: SimpleRpc::Client::Mode::ConnectPerRequest)
PER_CLIENT2        = SpecProto2::Client.new("127.0.0.1", 8888, mode: SimpleRpc::Client::Mode::ConnectPerRequest)
PER_CLIENT3        = SpecProto2::Client.new("127.0.0.1", 8889, mode: SimpleRpc::Client::Mode::ConnectPerRequest)

PIP1 = IO::Stapled.new(*IO.pipe)
PIP2 = IO::Stapled.new(*IO.pipe)

# FAKE server
fake_server = SpecProto::Server.new("127.0.0.1", 8888, false)
spawn do
  fake_server.handle(PIP1, PIP2)
end
IOCLIENT = SpecProto::Client.new("127.0.0.1", 8888)
IOCLIENT.fake_io_r = PIP2
IOCLIENT.fake_io_w = PIP1
