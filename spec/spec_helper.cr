require "spec"
require "../src/simple_rpc"

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

  def raw_result : SimpleRpc::HttpServer::RawMsgpack
    SimpleRpc::HttpServer::RawMsgpack.new({1, "bla", 6.5}.to_msgpack)
  end

  def stream_result : SimpleRpc::HttpServer::IOMsgpack
    bytes = {1, "bla", 6.5}.to_msgpack
    io = IO::Memory.new(bytes)
    SimpleRpc::HttpServer::IOMsgpack.new(io)
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
  SpecProto::HttpServer.new("127.0.0.1", 8888).run
end

spawn do
  SpecProto::SocketServer.new("127.0.0.1", 8889).run
end

sleep 0.1
HTTP_CLIENT         = SpecProto::HttpClient.new("127.0.0.1", 8888)
HTTP_CLIENT_TIMEOUT = SpecProto::HttpClient.new("127.0.0.1", 8888, timeout: 0.2)
HTTP_CLIENT_BAD     = SpecProto::HttpClient.new("127.0.0.1", 9999)
HTTP_CLIENT2        = SpecProto2::HttpClient.new("127.0.0.1", 8888)

SOCKET_CLIENT         = SpecProto::SocketClient.new("127.0.0.1", 8889)
SOCKET_CLIENT_TIMEOUT = SpecProto::SocketClient.new("127.0.0.1", 8889, timeout: 0.2)
SOCKET_CLIENT_BAD     = SpecProto::SocketClient.new("127.0.0.1", 9999)
SOCKET_CLIENT2        = SpecProto2::SocketClient.new("127.0.0.1", 8889)
