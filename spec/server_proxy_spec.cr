require "./spec_helper"

class SimpleRpc::Server
  @cons = [] of IO

  def _handle(client)
    @cons << client
    handle(client)
    @cons.delete(client)
  end

  def close
    @server.try(&.close) rescue nil
    @cons.each &.close
    @server = nil
  end
end

class ProxyProto1
  include SimpleRpc::Proto

  def inc(x : Int32) : Tuple(Int32, Int32)
    {1, x + 1}
  end
end

class ProxyProto2
  include SimpleRpc::Proto

  def inc(x : Int32) : Tuple(Int32, Int32)
    {2, x + 1}
  end
end

class ProxyProto3
  include SimpleRpc::Proto

  def inc(x : Int32) : Tuple(Int32, Int32)
    {3, x + 1}
  end
end

def create_proxy_server
  servers = (0..2).map do |port|
    case port % 3
    when 0
      ProxyProto1::Server.new("127.0.0.1", 44333 + port)
    when 1
      ProxyProto2::Server.new("127.0.0.1", 44333 + port)
    else
      ProxyProto3::Server.new("127.0.0.1", 44333 + port)
    end
  end
  proxy = SimpleRpc::ServerProxy.new("127.0.0.1", 44330)
  proxy.ports = [44333, 44334, 44335]
  {servers, proxy}
end

def with_run_proxy_server(servers, proxy, start_after = 0)
  servers.each do |server|
    spawn { sleep start_after; server.run }
  end
  spawn { sleep start_after; proxy.run }
  sleep 0.1
  yield(proxy)
ensure
  proxy.close
  servers.each &.close
  sleep 0.1
end

context "ServerProxy" do
  [SimpleRpc::Client::Mode::ConnectPerRequest, SimpleRpc::Client::Mode::Single, SimpleRpc::Client::Mode::Pool].each do |clmode|
    describe "client #{clmode}" do
      it "ok" do
        servers, proxy = create_proxy_server
        with_run_proxy_server(servers, proxy) do
          client = SimpleRpc::Client.new("127.0.0.1", 44330, mode: clmode)
          port, result = client.request!(Tuple(Int32, Int32), :inc, 1)
          result.should eq 2
        end
      end

      it "many reqs" do
        servers, proxy = create_proxy_server
        with_run_proxy_server(servers, proxy) do
          ports = [] of Int32
          r = 0
          10.times do |i|
            client = SimpleRpc::Client.new("127.0.0.1", 44330, mode: clmode)
            port, result = client.request!(Tuple(Int32, Int32), :inc, i)
            ports << port
            r += result
          end

          ports.uniq.sort.should eq [1, 2, 3]
          r.should eq 55
        end
      end

      it "use all servers" do
        servers, proxy = create_proxy_server
        with_run_proxy_server(servers, proxy) do
          client = SimpleRpc::Client.new("127.0.0.1", 44330, mode: clmode)
          ports = [] of Int32

          3.times do
            port, result = client.request!(Tuple(Int32, Int32), :inc, 1)
            result.should eq 2

            ports << port
          end

          ports.sort.should eq [1, 2, 3]
        end
      end

      it "when 1 server die" do
        servers, proxy = create_proxy_server
        with_run_proxy_server(servers, proxy) do
          client = SimpleRpc::Client.new("127.0.0.1", 44330, mode: clmode)
          ports = [] of Int32

          3.times do
            port, result = client.request!(Tuple(Int32, Int32), :inc, 1)
            result.should eq 2

            ports << port
          end

          ports.sort.should eq [1, 2, 3]

          # 1 die
          ports.clear
          servers[0].close
          sleep 0.1

          3.times do
            port, result = client.request!(Tuple(Int32, Int32), :inc, 1)
            result.should eq 2

            ports << port
          end

          ports.size.should eq 3
          ports.uniq.sort.should eq [2, 3]
        end
      end

      it "when all servers die" do
        servers, proxy = create_proxy_server
        with_run_proxy_server(servers, proxy) do
          client = SimpleRpc::Client.new("127.0.0.1", 44330, mode: clmode)
          ports = [] of Int32

          3.times do
            port, result = client.request!(Tuple(Int32, Int32), :inc, 1)
            result.should eq 2

            ports << port
          end

          ports.sort.should eq [1, 2, 3]

          # 1 die
          ports.clear
          servers[0].close
          servers[1].close
          sleep 0.1

          3.times do
            port, result = client.request!(Tuple(Int32, Int32), :inc, 1)
            result.should eq 2

            ports << port
          end

          ports.size.should eq 3
          ports.uniq.sort.should eq [3]

          ports.clear
          servers[2].close

          sleep 0.1

          expect_raises(SimpleRpc::RuntimeError, "All ports dead") do
            client.request!(Tuple(Int32, Int32), :inc, 1)
          end
        end
      end
    end
  end
end
