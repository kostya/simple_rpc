require "./spec_helper"

describe SimpleRpc do
  it "ok" do
    res = CLIENT.bla("3.5", 9.6)
    res.error.should eq SimpleRpc::Error::OK
    res.value.should eq 33.6
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

  it "ok sleep" do
    t = Time.now
    res = CLIENT.sleepi(0.1)
    res.error.should eq SimpleRpc::Error::OK
    res.value.should eq nil
    (Time.now - t).to_f.should be < 0.2
    (Time.now - t).to_f.should be >= 0.1
  end

  it "exception" do
    res = CLIENT.bla("O_o", 9.6)
    res.error.should eq SimpleRpc::Error::TASK_EXCEPTION
    res.message.should eq "Invalid Float64: O_o"
    res.value.should eq nil
  end

  it "no server" do
    res = CLIENT_BAD.bla("O_o", 9.6)
    res.error.should eq SimpleRpc::Error::HTTP_EXCEPTION
    res.message.should eq nil
    res.value.should eq nil
  end
end
