require "../src/simple_rpc"

class MyRpc
  include SimpleRpc::Proto

  def bla(x : Int32, y : String) : Float64
    x * y.to_f
  end

  class Client
    def jo
      res = bla(2, "4.3")
      if res.ok?
        res.value! + 1
      else
        0.0
      end
    end
  end
end

spawn do
  MyRpc::Server.new("127.0.0.1", 9000).run
end

sleep 0.1
client = MyRpc::Client.new("127.0.0.1", 9000)
p client.jo
