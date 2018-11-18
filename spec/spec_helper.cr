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

  def no_args : Int32
    0
  end
end

spawn do
  SpecProto::Server.new("127.0.0.1", 8888).run
end

sleep 0.1
CLIENT     = SpecProto::Client.new("127.0.0.1", 8888)
CLIENT_BAD = SpecProto::Client.new("127.0.0.1", 8889)
