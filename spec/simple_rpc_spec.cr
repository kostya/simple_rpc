require "./spec_helper"
require "http/client"

describe SimpleRpc do
  {% for prefix in ["", "PER_"] %}
  context "{{prefix.id}}CLIENT" do
    it "ok" do
      res = {{prefix.id}}CLIENT.bla("3.5", 9.6)
      res.ok?.should eq true
      res.value!.should eq 33.6
    end

    it "ok raw request" do
      res = {{prefix.id}}CLIENT.request(Float64, :bla, "3.5", 9.6)
      res.ok?.should eq true
      res.value!.should eq 33.6
    end

    it "error raw request" do
      res = {{prefix.id}}CLIENT.request(String, :bla, "3.5", 9.6)
      res.ok?.should eq false
      res.message!.should eq "SimpleRpc::TypeCastError: Receive unexpected result type, expected String"
      res.value.should eq nil
    end

    it "ok no_args" do
      res = {{prefix.id}}CLIENT.no_args
      res.ok?.should eq true
      res.value.should eq 0
    end

    it "ok complex" do
      res = {{prefix.id}}CLIENT.complex(3)
      res.ok?.should eq true
      res.value!.x.should eq "3"
      res.value!.y.should eq({"_0_" => 0, "_1_" => 1, "_2_" => 2})
    end

    it "ok with_default_value" do
      res = {{prefix.id}}CLIENT.with_default_value(2)
      res.value!.should eq 3

      res = {{prefix.id}}CLIENT.with_default_value
      res.value!.should eq 2
    end

    it "ok with named_args" do
      res = {{prefix.id}}CLIENT.named_args(a: 1, b: "10")
      res.ok?.should eq true
      res.value!.should eq "1 - \"10\" - nil - nil"

      res = {{prefix.id}}CLIENT.named_args(a: 1, c: 2.5)
      res.ok?.should eq true
      res.value!.should eq "1 - nil - 2.5 - nil"
    end

    it "ok with big input args" do
      strings = (0..5).map { |i| (0..60000 + i).map(&.chr).join }
      res = {{prefix.id}}CLIENT.bin_input_args(strings, 2.5)
      res.ok?.should eq true
      res.value!.should eq "488953775.0"
    end

    it "ok with big result" do
      res = {{prefix.id}}CLIENT.big_result(10_000)
      res.ok?.should eq true
      res.value!.size.should eq 10_000
      res.value!["__----9999------"].should eq "asfasdflkqwflqwe9999"
    end

    it "exception" do
      res = {{prefix.id}}CLIENT.bla("O_o", 9.6)
      res.message!.should eq "SimpleRpc::RuntimeError: Exception in task execution: Invalid Float64: O_o"
      res.value.should eq nil
    end

    it "next request after exception should be ok (was a bug)" do
      res = {{prefix.id}}CLIENT.bla("O_o", 9.6)
      res.message!.should eq "SimpleRpc::RuntimeError: Exception in task execution: Invalid Float64: O_o"
      res.value.should eq nil

      res = {{prefix.id}}CLIENT.bla("3.5", 9.6)
      res.ok?.should eq true
      res.value!.should eq 33.6
    end

    it "no server" do
      res = {{prefix.id}}CLIENT_BAD.bla("O_o", 9.6)
      res.message!.should eq "SimpleRpc::CannotConnectError: Errno: Error connecting to '127.0.0.1:9999': Connection refused"
      res.value.should eq nil
    end

    it "unknown method" do
      res = {{prefix.id}}CLIENT2.zip
      res.message!.should eq "SimpleRpc::RuntimeError: method 'zip' not found"
      res.value.should eq nil
    end

    it "bad params" do
      res = {{prefix.id}}CLIENT2.bla(1.3, "2.5")
      res.message!.should eq "SimpleRpc::RuntimeError: bad arguments, expected [x : String, y : Float64], but got something else"
      res.value.should eq nil
    end

    it "ok sleep" do
      t = Time.now
      res = {{prefix.id}}CLIENT.sleepi(0.1)
      res.ok?.should eq true
      res.value.should eq 1
      (Time.now - t).to_f.should be < 0.2
      (Time.now - t).to_f.should be >= 0.1
    end

    it "sleep timeout" do
      t = Time.now
      res = {{prefix.id}}CLIENT_TIMEOUT.sleepi(0.5)
      res.message!.should eq "SimpleRpc::CommandTimeoutError: Command timed out"
      res.value.should eq nil
      (Time.now - t).to_f.should be < 0.25
      (Time.now - t).to_f.should be >= 0.2
    end

    it "ok raw result" do
      res = {{prefix.id}}CLIENT.request(Tuple(Int32, String, Float64), :raw_result)
      res.ok?.should eq true
      res.value.should eq({1, "bla", 6.5})
    end

    it "ok stream result" do
      res = {{prefix.id}}CLIENT.request(Tuple(Int32, String, Float64), :stream_result)
      res.ok?.should eq true
      res.value.should eq({1, "bla", 6.5})
    end

    context "invariants" do
      it "int" do
        res = {{prefix.id}}CLIENT.request(MessagePack::Type, :invariants, 0)
        res.ok?.should eq true
        v = res.value!
        v.as(Int64).should eq 1
      end

      it "string" do
        res = {{prefix.id}}CLIENT.request(MessagePack::Type, :invariants, 1)
        res.ok?.should eq true
        v = res.value!
        v.as(String).should eq "1"
      end

      it "float" do
        res = {{prefix.id}}CLIENT.request(MessagePack::Type, :invariants, 2)
        res.ok?.should eq true
        v = res.value!
        v.as(Float64).should eq 5.5
      end

      it "array" do
        res = {{prefix.id}}CLIENT.request(MessagePack::Type, :invariants, 3)
        res.ok?.should eq true
        v = res.value!
        v.as(Array(MessagePack::Type)).should eq [0, 1, 2]
      end

      it "bool" do
        res = {{prefix.id}}CLIENT.request(MessagePack::Type, :invariants, 4)
        res.ok?.should eq true
        v = res.value!
        v.as(Bool).should eq false
      end
    end

    context "unions" do
      it "int" do
        res = {{prefix.id}}CLIENT.request(Int32, :unions, 0)
        res.ok?.should eq true
        res.value!.should eq 1

        res = {{prefix.id}}CLIENT.request(Int32, :unions, "0")
        res.ok?.should eq true
        res.value!.should eq 1

        res = {{prefix.id}}CLIENT.request(Int32, :unions, 1.2)
        res.message!.should eq "SimpleRpc::RuntimeError: bad arguments, expected [x : Int32 | String], but got something else"
      end

      it "string" do
        res = {{prefix.id}}CLIENT.request(String, :unions, 1)
        res.ok?.should eq true
        res.value!.should eq "1"

        res = {{prefix.id}}CLIENT.request(String, :unions, "1")
        res.ok?.should eq true
        res.value!.should eq "1"
      end

      it "float" do
        res = {{prefix.id}}CLIENT.request(Float64, :unions, 2)
        res.ok?.should eq true
        res.value!.should eq 5.5

        res = {{prefix.id}}CLIENT.request(Float64, :unions, "2")
        res.ok?.should eq true
        res.value!.should eq 5.5
      end

      it "array" do
        res = {{prefix.id}}CLIENT.request(Array(Int32), :unions, 3)
        res.ok?.should eq true
        res.value!.should eq [1, 2, 3]

        res = {{prefix.id}}CLIENT.request(Array(Int32), :unions, "3")
        res.ok?.should eq true
        res.value!.should eq [1, 2, 3]
      end

      it "bool" do
        res = {{prefix.id}}CLIENT.request(Bool, :unions, 4)
        res.ok?.should eq true
        res.value!.should eq false

        res = {{prefix.id}}CLIENT.request(Bool, :unions, "4")
        res.ok?.should eq true
        res.value!.should eq false
      end
    end

    it "sequence of requests" do
      f = 0.0

      connects = [] of IO?

      100.times do |i|
        res = {{prefix.id}}CLIENT.bla("#{i}.1", 2.5)
        if res.ok?
          f += res.value.not_nil!
        end

        connects << {{prefix.id}}CLIENT.@socket
      end

      f.should eq 12400.0

      {% if prefix == "PER_" %}
        connects.uniq.should eq [nil]
      {% else %}
        connects.uniq.size.should eq 1
        connects.uniq.should_not eq [nil]
      {% end %}
    end

    it "reconnecting after close" do
      res = {{prefix.id}}CLIENT.bla("2", 2.5)
      res.value!.should eq 5.0

      {{prefix.id}}CLIENT.close

      res = {{prefix.id}}CLIENT.bla("3", 2.5)
      res.value!.should eq 7.5
    end

    it "raw request, wrong arguments types" do
      res = {{prefix.id}}CLIENT.request(Float64, :bla, 3.5, 1.1)
      res.ok?.should eq false
      res.message!.should eq "SimpleRpc::RuntimeError: bad arguments, expected [x : String, y : Float64], but got something else"

      # after this, should be ok request
      res = {{prefix.id}}CLIENT.bla("3.5", 9.6)
      res.ok?.should eq true
      res.value!.should eq 33.6
    end

    it "raw request, wrong arguments types" do
      res = {{prefix.id}}CLIENT.request(Float64, :bla, "3.5", "zopa")
      res.ok?.should eq false
      res.message!.should eq "SimpleRpc::RuntimeError: bad arguments, expected [x : String, y : Float64], but got something else"

      # after this, should be ok request
      res = {{prefix.id}}CLIENT.bla("3.5", 9.6)
      res.ok?.should eq true
      res.value!.should eq 33.6
    end

    it "raw request, wrong arguments count" do
      res = {{prefix.id}}CLIENT.request(Float64, :bla, "3.5")
      res.ok?.should eq false
      res.message!.should eq "SimpleRpc::RuntimeError: bad arguments, expected [x : String, y : Float64], but got 1 args"

      # after this, should be ok request
      res = {{prefix.id}}CLIENT.bla("3.5", 9.6)
      res.ok?.should eq true
      res.value!.should eq 33.6
    end

    it "raw request, wrong arguments count" do
      res = {{prefix.id}}CLIENT.request(Float64, :bla, "3.5", 10, 11, 12)
      res.ok?.should eq false
      res.message!.should eq "SimpleRpc::RuntimeError: bad arguments, expected [x : String, y : Float64], but got 4 args"

      # after this, should be ok request
      res = {{prefix.id}}CLIENT.bla("3.5", 9.6)
      res.ok?.should eq true
      res.value!.should eq 33.6
    end

    it "http/client trying connect to server" do
      expect_raises(Exception) do
        HTTP::Client.get("http://127.0.0.1:8888/bla")
      end

      # after request usual request just work
      res = {{prefix.id}}CLIENT.bla("3.5", 9.6)
      res.ok?.should eq true
      res.value!.should eq 33.6
    end

    it "raw socket_client trying connect to server" do
      sock = TCPSocket.new("127.0.0.1", 8888)
      sock.write_byte(193.to_u8) # unsupported by msgpack symbol

      # after request usual request just work
      res = {{prefix.id}}CLIENT.bla("3.5", 9.6)
      res.ok?.should eq true
      res.value!.should eq 33.6
    end

    it "connection to bad server" do
      res = {{prefix.id}}CLIENT3.request(Float64, :bla, "3.5", 9.6)
      res.ok?.should eq false
      res.message!.should start_with("SimpleRpc::ProtocallError: Unexpected byte '193' at 0")
    end

    it "Notify messages also works" do
      SpecProto.notify_count = 0
      SpecProto.notify_count.should eq 0

      sock = TCPSocket.new("127.0.0.1", 8888)
      {2_i8, "notif", [5]}.to_msgpack(sock)
      sock.flush

      sleep 0.001
      SpecProto.notify_count.should eq 5

      sock = TCPSocket.new("127.0.0.1", 8888)
      {2_i8, "notif", [10]}.to_msgpack(sock)
      sock.flush

      sleep 0.001
      SpecProto.notify_count.should eq 15
    end

    it "Notify with client" do
      SpecProto.notify_count = 0
      SpecProto.notify_count.should eq 0

      {{prefix.id}}CLIENT.notify!("notif", 5)

      sleep 0.001
      SpecProto.notify_count.should eq 5

      {{prefix.id}}CLIENT.notify!("notif", 15)

      sleep 0.001
      SpecProto.notify_count.should eq 20
    end

    it "sequence of requests with notify" do
      SpecProto.notify_count = 0
      SpecProto.notify_count.should eq 0

      f = 0.0

      100.times do |i|
        res = {{prefix.id}}CLIENT.bla("#{i}.1", 2.5)
        if res.ok?
          f += res.value.not_nil!
        end

        {{prefix.id}}CLIENT.notify!("notif", i)
      end

      f.should eq 12400.0
      sleep 0.001
      SpecProto.notify_count.should eq 4950
    end
  end
  {% end %}

  it "ok work with FAKE CLIENT and FAKE SERVER" do
    res = IOCLIENT.bla("3.5", 9.6)
    res.ok?.should eq true
    res.value!.should eq 33.6

    res = IOCLIENT.request(Float64, :bla, "3.5", 9.6)
    res.ok?.should eq true
    res.value!.should eq 33.6
  end
end
