require "./spec_helper"

describe SimpleRpc do
  it "ok" do
    res = CLIENT.bla("3.5", 9.6)
    res.error.should eq SimpleRpc::Error::OK
    res.value.should eq 33.6
  end

  it "ok raw request" do
    res = CLIENT.request(Float64, :bla, "3.5", 9.6)
    res.error.should eq SimpleRpc::Error::OK
    res.value.should eq 33.6
  end

  it "error raw request" do
    res = CLIENT.request(String, :bla, "3.5", 9.6)
    res.error.should eq SimpleRpc::Error::ERROR_UNPACK_RESPONSE
    res.message.should eq "failed to unpack server response (result not matched with type String)"
    res.value.should eq nil
  end

  it "ok no_args" do
    res = CLIENT.no_args
    res.error.should eq SimpleRpc::Error::OK
    res.value.should eq 0
  end

  it "ok complex" do
    res = CLIENT.complex(3)
    res.error.should eq SimpleRpc::Error::OK
    res.value.not_nil!.x.should eq "3"
    res.value.not_nil!.y.should eq({"_0_" => 0, "_1_" => 1, "_2_" => 2})
  end

  it "ok with_default_value" do
    res = CLIENT.with_default_value(2)
    res.value.not_nil!.should eq 3

    res = CLIENT.with_default_value
    res.value.not_nil!.should eq 2
  end

  it "ok with big input args" do
    strings = (0..5).map { |i| (0..60000 + i).map(&.chr).join }
    res = CLIENT.bin_input_args(strings, 2.5)
    res.error.should eq SimpleRpc::Error::OK
    res.value.should eq "488953775.0"
  end

  it "ok with big result" do
    res = CLIENT.big_result(10_000)
    res.error.should eq SimpleRpc::Error::OK
    res.value.not_nil!.size.should eq 10_000
    res.value.not_nil!["__----9999------"].should eq "asfasdflkqwflqwe9999"
  end

  it "exception" do
    res = CLIENT.bla("O_o", 9.6)
    res.error.should eq SimpleRpc::Error::TASK_EXCEPTION
    res.message.not_nil!.should start_with "Invalid Float64: O_o"
    res.value.should eq nil
  end

  it "no server" do
    res = CLIENT_BAD.bla("O_o", 9.6)
    res.error.should eq SimpleRpc::Error::HTTP_EXCEPTION
    res.message.should eq nil
    res.value.should eq nil
  end

  it "unknown method" do
    res = CLIENT2.zip
    res.error.should eq SimpleRpc::Error::UNKNOWN_METHOD
    res.message.not_nil!.should start_with "unknown method 'zip'"
    res.value.should eq nil
  end

  it "bad params" do
    res = CLIENT2.bla(1.3, "2.5")
    res.error.should eq SimpleRpc::Error::ERROR_UNPACK_REQUEST
    res.message.not_nil!.should start_with "msgpack not matched with Tuple(String, Float64)"
    res.value.should eq nil
  end

  it "ok sleep" do
    t = Time.now
    res = CLIENT.sleepi(0.1)
    res.error.should eq SimpleRpc::Error::OK
    res.value.should eq 1
    (Time.now - t).to_f.should be < 0.2
    (Time.now - t).to_f.should be >= 0.1
  end

  it "sleep timeout" do
    t = Time.now
    res = CLIENT_TIMEOUT.sleepi(0.5)
    res.error.should eq SimpleRpc::Error::TIMEOUT
    res.value.should eq nil
    (Time.now - t).to_f.should be < 0.25
    (Time.now - t).to_f.should be >= 0.2
  end

  it "ok raw result" do
    res = CLIENT.request(Tuple(Int32, String, Float64), :raw_result)
    res.error.should eq SimpleRpc::Error::OK
    res.value.should eq({1, "bla", 6.5})
  end

  it "ok stream result" do
    res = CLIENT.request(Tuple(Int32, String, Float64), :stream_result)
    res.error.should eq SimpleRpc::Error::OK
    res.value.should eq({1, "bla", 6.5})
  end
end
