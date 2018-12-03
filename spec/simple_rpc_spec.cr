require "./spec_helper"

describe SimpleRpc do
  {% for prefix in %w{HTTP_ SOCKET_} %}
  context "{{prefix.id}}CLIENT" do
    it "ok" do
      res = {{prefix.id}}CLIENT.bla("3.5", 9.6)
      res.error.should eq SimpleRpc::Error::OK
      res.value.should eq 33.6
    end

    it "ok raw request" do
      res = {{prefix.id}}CLIENT.request(Float64, :bla, "3.5", 9.6)
      res.error.should eq SimpleRpc::Error::OK
      res.value.should eq 33.6
    end

    it "error raw request" do
      res = {{prefix.id}}CLIENT.request(String, :bla, "3.5", 9.6)
      res.error.should eq SimpleRpc::Error::ERROR_UNPACK_RESPONSE
      res.message.should eq "failed to unpack server response (result not matched with type String)"
      res.value.should eq nil
    end

    it "ok no_args" do
      res = {{prefix.id}}CLIENT.no_args
      res.error.should eq SimpleRpc::Error::OK
      res.value.should eq 0
    end

    it "ok complex" do
      res = {{prefix.id}}CLIENT.complex(3)
      res.error.should eq SimpleRpc::Error::OK
      res.value.not_nil!.x.should eq "3"
      res.value.not_nil!.y.should eq({"_0_" => 0, "_1_" => 1, "_2_" => 2})
    end

    it "ok with_default_value" do
      res = {{prefix.id}}CLIENT.with_default_value(2)
      res.value.not_nil!.should eq 3

      res = {{prefix.id}}CLIENT.with_default_value
      res.value.not_nil!.should eq 2
    end

    it "ok with big input args" do
      strings = (0..5).map { |i| (0..60000 + i).map(&.chr).join }
      res = {{prefix.id}}CLIENT.bin_input_args(strings, 2.5)
      res.error.should eq SimpleRpc::Error::OK
      res.value.should eq "488953775.0"
    end

    it "ok with big result" do
      res = {{prefix.id}}CLIENT.big_result(10_000)
      res.error.should eq SimpleRpc::Error::OK
      res.value.not_nil!.size.should eq 10_000
      res.value.not_nil!["__----9999------"].should eq "asfasdflkqwflqwe9999"
    end

    it "exception" do
      res = {{prefix.id}}CLIENT.bla("O_o", 9.6)
      res.error.should eq SimpleRpc::Error::TASK_EXCEPTION
      res.message.not_nil!.should start_with "Invalid Float64: O_o"
      res.value.should eq nil
    end

    it "no server" do
      res = {{prefix.id}}CLIENT_BAD.bla("O_o", 9.6)
      res.error.should eq SimpleRpc::Error::CONNECTION_ERROR
      res.message.should eq "Error connecting to '127.0.0.1:9999': Connection refused"
      res.value.should eq nil
    end

    it "unknown method" do
      res = {{prefix.id}}CLIENT2.zip
      res.error.should eq SimpleRpc::Error::UNKNOWN_METHOD
      res.message.not_nil!.should start_with "zip"
      res.value.should eq nil
    end

    it "bad params" do
      res = {{prefix.id}}CLIENT2.bla(1.3, "2.5")
      res.error.should eq SimpleRpc::Error::ERROR_UNPACK_REQUEST
      res.message.not_nil!.should start_with "bad arguments, expected [x : String, y : Float64], but got something else"
      res.value.should eq nil
    end

    it "ok sleep" do
      t = Time.now
      res = {{prefix.id}}CLIENT.sleepi(0.1)
      res.error.should eq SimpleRpc::Error::OK
      res.value.should eq 1
      (Time.now - t).to_f.should be < 0.2
      (Time.now - t).to_f.should be >= 0.1
    end

    it "sleep timeout" do
      t = Time.now
      res = {{prefix.id}}CLIENT_TIMEOUT.sleepi(0.5)
      res.error.should eq SimpleRpc::Error::TIMEOUT
      res.value.should eq nil
      (Time.now - t).to_f.should be < 0.25
      (Time.now - t).to_f.should be >= 0.2
    end

    it "ok raw result" do
      res = {{prefix.id}}CLIENT.request(Tuple(Int32, String, Float64), :raw_result)
      res.error.should eq SimpleRpc::Error::OK
      res.value.should eq({1, "bla", 6.5})
    end

    it "ok stream result" do
      res = {{prefix.id}}CLIENT.request(Tuple(Int32, String, Float64), :stream_result)
      res.error.should eq SimpleRpc::Error::OK
      res.value.should eq({1, "bla", 6.5})
    end
  end
  {% end %}
end
