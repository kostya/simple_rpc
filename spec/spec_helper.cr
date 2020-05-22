require "spec"
require "../src/simple_rpc"

L = Log.for("specs")
L.backend = Log::IOBackend.new(File.open("spec.log", "a"))

HOST     = "127.0.0.1"
PORT     = 8888
TCPPORT  = 8889
UNIXSOCK = "./tmp_spec_simple_rpc.sock"

record Bla, x : String, y : Hash(String, Int32) { include MessagePack::Serializable }

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

  def sleepi(v : Float64, x : Int32) : Int32
    sleep(v)
    x
  end

  def no_args : Int32
    0
  end

  def with_default_value(x : String = "1") : Int32
    x.to_i + 1
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

  def notif(x : Int32) : Nil
    @@notify_count += x
    nil
  end

  def named_args(a : Int32, b : String? = nil, c : Float64? = nil, d : Int32? = nil) : String
    "#{a.inspect} - #{b.inspect} - #{c.inspect} - #{d.inspect}"
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
  SpecProto::Server.new(HOST, PORT, logger: L).run
end

spawn do
  File.delete(UNIXSOCK) rescue nil
  SpecProto::Server.new(unixsocket: UNIXSOCK, logger: L).run
end

def bad_server_handle(client)
  Tuple(Int8, UInt32, String, Array(MessagePack::Type)).from_msgpack(client)
  client.write_byte(193_u8) # write illegal msgpack value
  client.flush
end

spawn do
  bad_server = TCPServer.new(HOST, TCPPORT)
  loop do
    cli = bad_server.accept
    spawn bad_server_handle(cli)
  end
end

sleep 0.1
