require "./spec_helper"
require "http/client"

{% if flag?(:darwin) %}
  TIME_ERROR      = 0.155 # macos has quite big time error
  BIG_TIME_ERROR  = TIME_ERROR * 2
  ZERO_TIME_ERROR = 0.08
{% else %}
  TIME_ERROR      = 0.05
  BIG_TIME_ERROR  = TIME_ERROR * 2
  ZERO_TIME_ERROR = 0.03
{% end %}

describe SimpleRpc do
  [SimpleRpc::Client::Mode::ConnectPerRequest, SimpleRpc::Client::Mode::Pool, SimpleRpc::Client::Mode::Single].each do |clmode|
    [SpecProto::Client.new(HOST, PORT, mode: clmode), SpecProto::Client.new(unixsocket: UNIXSOCK, mode: clmode), SpecProto::Client.new(HOST, PORT_SSL, mode: clmode, ssl_context: CLIENT_SSL_CTX)].each do |client|
      context "CLIENT(#{client.unixsocket ? "UNIX" : "TCP"}:#{clmode})" do
        it "ok" do
          res = client.bla("3.5", 9.6)
          res.ok?.should eq true
          res.value!.should eq 33.6
        end

        it "ok without wrapper" do
          res = client.bla!("3.5", 9.6)
          res.should eq 33.6
        end

        it "ok raw request" do
          res = client.request(Float64, :bla, "3.5", 9.6)
          res.ok?.should eq true
          res.value!.should eq 33.6
        end

        it "error raw request" do
          res = client.request(String, :bla, "3.5", 9.6)
          res.ok?.should eq false
          res.message!.should eq "SimpleRpc::TypeCastError: Receive unexpected result type, expected String"
          res.value.should eq nil
        end

        it "ok raw request!" do
          res = client.request!(Float64, :bla, "3.5", 9.6)
          res.should eq 33.6
        end

        it "ok raw_result with outsize args" do
          unpacker = client.raw_request(:bla) { |packer| {"3.5", 9.6}.to_msgpack(packer) }
          res = Float64.new(unpacker)
          res.should eq 33.6
        end

        it "ok raw_result with outsize args2" do
          unpacker = client.raw_request(:bla) { |packer| packer.write_array_start(2); packer.write("3.5"); packer.write(9.6) }
          res = Float64.new(unpacker)
          res.should eq 33.6
        end

        it "error raw request" do
          expect_raises(SimpleRpc::TypeCastError, "Receive unexpected result type, expected String") do
            client.request!(String, :bla, "3.5", 9.6)
          end
        end

        it "ok no_args" do
          res = client.no_args
          res.ok?.should eq true
          res.value.should eq 0
        end

        it "ok complex" do
          res = client.complex(3)
          res.ok?.should eq true
          res.value!.x.should eq "3"
          res.value!.y.should eq({"_0_" => 0, "_1_" => 1, "_2_" => 2})
        end

        it "ok with_default_value" do
          res = client.with_default_value("2")
          res.value!.should eq 3

          res = client.with_default_value
          res.value!.should eq 2
        end

        it "ok with named_args" do
          res = client.named_args(a: 1, b: "10")
          res.ok?.should eq true
          res.value!.should eq "1 - \"10\" - nil - nil"

          res = client.named_args(a: 1, c: 2.5)
          res.ok?.should eq true
          res.value!.should eq "1 - nil - 2.5 - nil"
        end

        it "ok with big input args" do
          strings = (0..5).map { |i| (0..60000 + i).map(&.unsafe_chr).join }
          res = client.bin_input_args(strings, 2.5)
          res.ok?.should eq true
          res.value!.should eq "488953775.0"
        end

        it "ok with big result" do
          res = client.big_result(10_000)
          res.ok?.should eq true
          res.value!.size.should eq 10_000
          res.value!["__----9999------"].should eq "asfasdflkqwflqwe9999"
        end

        it "exception" do
          res = client.bla("O_o", 9.6)
          res.message!.should contain "SimpleRpc::RuntimeError: RuntimeError in bla[x : String, y : Float64]: 'Invalid Float64: \"O_o\"'"
          res.value.should eq nil
        end

        it "exception without wrapper" do
          expect_raises(SimpleRpc::RuntimeError, "RuntimeError in bla[x : String, y : Float64]: 'Invalid Float64: \"O_o\"'") do
            client.bla!("O_o", 9.6)
          end
        end

        it "next request after exception should be ok (was a bug)" do
          res = client.bla("O_o", 9.6)
          res.message!.should contain "SimpleRpc::RuntimeError: RuntimeError in bla[x : String, y : Float64]: 'Invalid Float64: \"O_o\"'"
          res.value.should eq nil

          res = client.bla("3.5", 9.6)
          res.ok?.should eq true
          res.value!.should eq 33.6
        end

        it "no server" do
          client_bad = SpecProto::Client.new(HOST, PORT + 10000, mode: clmode)
          res = client_bad.bla("O_o", 9.6)
          res.message!.should eq "SimpleRpc::CannotConnectError: Socket::ConnectError: Error connecting to '#{HOST}:#{PORT + 10000}': Connection refused"
          res.value.should eq nil
        end

        it "unknown method" do
          client2 = SpecProto2::Client.new(HOST, PORT, mode: clmode)
          res = client2.zip
          res.message!.should eq "SimpleRpc::RuntimeError: method 'zip' not found"
          res.value.should eq nil
        end

        it "unknown method and next ok request" do
          client2 = SimpleRpc::Client.new(HOST, PORT, mode: clmode)
          res = client2.request(Nil, :zip, 1, 2, 3)
          res.message!.should eq "SimpleRpc::RuntimeError: method 'zip' not found"
          res.value.should eq nil

          res = client2.request(Int32, :no_args)
          res.ok?.should eq true
          res.value.should eq 0
        end

        it "bad params" do
          client2 = SpecProto2::Client.new(HOST, PORT, mode: clmode)
          res = client2.bla(1.3, "2.5")
          res.message!.should eq "SimpleRpc::RuntimeError: ArgumentError in bla[x : String, y : Float64]: bad argument x: 'Unexpected token FloatT(1.3) expected StringT or BytesT at 1' (at FloatT(1.3))"
          res.value.should eq nil
        end

        it "ok sleep" do
          should_spend(0.1, TIME_ERROR) do
            res = client.sleepi(0.1, 1)
            res.ok?.should eq true
            res.value.should eq 1
          end
        end

        it "sleep timeout" do
          client_t = SpecProto::Client.new(HOST, PORT, mode: clmode, command_timeout: 0.2)

          should_spend(0.2, TIME_ERROR) do
            res = client_t.sleepi(0.5, 2)
            res.message!.should eq "SimpleRpc::CommandTimeoutError: Command timed out"
            res.value.should eq nil
          end
        end

        it "ok raw result" do
          res = client.request(Tuple(Int32, String, Float64), :raw_result)
          res.ok?.should eq true
          res.value.should eq({1, "bla", 6.5})
        end

        it "ok stream result" do
          res = client.request(Tuple(Int32, String, Float64), :stream_result)
          res.ok?.should eq true
          res.value.should eq({1, "bla", 6.5})
        end

        it "ok raw socket result" do
          res = client.request(Tuple(Int32, String, Float64), :raw_socket_result)
          res.ok?.should eq true
          res.value.should eq({1, "bla", 7.5})
        end

        context "invariants" do
          it "int" do
            res = client.request(MessagePack::Type, :invariants, 0)
            res.ok?.should eq true
            v = res.value!
            v.as(Int).should eq 1
          end

          it "string" do
            res = client.request(MessagePack::Type, :invariants, 1)
            res.ok?.should eq true
            v = res.value!
            v.as(String).should eq "1"
          end

          it "float" do
            res = client.request(MessagePack::Type, :invariants, 2)
            res.ok?.should eq true
            v = res.value!
            v.as(Float64).should eq 5.5
          end

          it "array" do
            res = client.request(MessagePack::Type, :invariants, 3)
            res.ok?.should eq true
            v = res.value!
            v.as(Array(MessagePack::Type)).should eq [0, 1, 2]
          end

          it "bool" do
            res = client.request(MessagePack::Type, :invariants, 4)
            res.ok?.should eq true
            v = res.value!
            v.as(Bool).should eq false
          end
        end

        context "unions" do
          it "int" do
            res = client.request(Int32, :unions, 0)
            res.ok?.should eq true
            res.value!.should eq 1

            res = client.request(Int32, :unions, "0")
            res.ok?.should eq true
            res.value!.should eq 1

            res = client.request(Int32, :unions, 1.2)
            res.message!.should eq "SimpleRpc::RuntimeError: ArgumentError in unions[x : Int32 | String]: bad argument x: 'Couldn't parse data as {Int32, String} at 1' (at FloatT(1.2))"
          end

          it "string" do
            res = client.request(String, :unions, 1)
            res.ok?.should eq true
            res.value!.should eq "1"

            res = client.request(String, :unions, "1")
            res.ok?.should eq true
            res.value!.should eq "1"

            res = client.request(Int32, :unions, 1.2)
            res.message!.should eq "SimpleRpc::RuntimeError: ArgumentError in unions[x : Int32 | String]: bad argument x: 'Couldn't parse data as {Int32, String} at 1' (at FloatT(1.2))"
          end

          it "float" do
            res = client.request(Float64, :unions, 2)
            res.ok?.should eq true
            res.value!.should eq 5.5

            res = client.request(Float64, :unions, "2")
            res.ok?.should eq true
            res.value!.should eq 5.5

            res = client.request(Int32, :unions, 1.2)
            res.message!.should eq "SimpleRpc::RuntimeError: ArgumentError in unions[x : Int32 | String]: bad argument x: 'Couldn't parse data as {Int32, String} at 1' (at FloatT(1.2))"
          end

          it "array" do
            res = client.request(Array(Int32), :unions, 3)
            res.ok?.should eq true
            res.value!.should eq [1, 2, 3]

            res = client.request(Array(Int32), :unions, "3")
            res.ok?.should eq true
            res.value!.should eq [1, 2, 3]

            res = client.request(Int32, :unions, 1.2)
            res.message!.should eq "SimpleRpc::RuntimeError: ArgumentError in unions[x : Int32 | String]: bad argument x: 'Couldn't parse data as {Int32, String} at 1' (at FloatT(1.2))"
          end

          it "bool" do
            res = client.request(Bool, :unions, 4)
            res.ok?.should eq true
            res.value!.should eq false

            res = client.request(Bool, :unions, "4")
            res.ok?.should eq true
            res.value!.should eq false

            res = client.request(Int32, :unions, 1.2)
            res.message!.should eq "SimpleRpc::RuntimeError: ArgumentError in unions[x : Int32 | String]: bad argument x: 'Couldn't parse data as {Int32, String} at 1' (at FloatT(1.2))"
          end
        end

        it "sequence of requests" do
          f = 0.0

          connects = [] of IO?

          100.times do |i|
            res = client.bla("#{i}.1", 2.5)
            if res.ok?
              f += res.value.not_nil!
            end

            connects << client.@single.try(&.socket)
          end

          f.should eq 12400.0

          if clmode == SimpleRpc::Client::Mode::Single
            connects.uniq.size.should eq 1
            connects.uniq.should_not eq [nil]
          else
            connects.uniq.should eq [nil]
          end
        end

        it "reconnecting after close" do
          res = client.bla("2", 2.5)
          res.value!.should eq 5.0

          client.close

          res = client.bla("3", 2.5)
          res.value!.should eq 7.5
        end

        it "raw request, wrong arguments types" do
          res = client.request(Float64, :bla, 3.5, 1.1)
          res.ok?.should eq false
          res.message!.should eq "SimpleRpc::RuntimeError: ArgumentError in bla[x : String, y : Float64]: bad argument x: 'Unexpected token FloatT(3.5) expected StringT or BytesT at 1' (at FloatT(3.5))"

          # after this, should be ok request
          res = client.bla("3.5", 9.6)
          res.ok?.should eq true
          res.value!.should eq 33.6
        end

        it "raw request, wrong arguments types" do
          res = client.request(Float64, :bla, "3.5", "zopa")
          res.ok?.should eq false
          res.message!.should eq "SimpleRpc::RuntimeError: ArgumentError in bla[x : String, y : Float64]: bad argument y: 'Unexpected token StringT(\"zopa\") expected IntT or FloatT at 5' (at StringT(\"zopa\"))"

          # after this, should be ok request
          res = client.bla("3.5", 9.6)
          res.ok?.should eq true
          res.value!.should eq 33.6
        end

        it "raw request, wrong arguments count" do
          res = client.request(Float64, :bla, "3.5")
          res.ok?.should eq false
          res.message!.should eq "SimpleRpc::RuntimeError: ArgumentError in bla[x : String, y : Float64]: bad arguments count: expected 2, but got 1"

          # after this, should be ok request
          res = client.bla("3.5", 9.6)
          res.ok?.should eq true
          res.value!.should eq 33.6
        end

        it "raw request, wrong arguments count" do
          res = client.request(Float64, :bla, "3.5", 10, 11, 12)
          res.ok?.should eq false
          res.message!.should eq "SimpleRpc::RuntimeError: ArgumentError in bla[x : String, y : Float64]: bad arguments count: expected 2, but got 4"

          # after this, should be ok request
          res = client.bla("3.5", 9.6)
          res.ok?.should eq true
          res.value!.should eq 33.6
        end

        it "http/client trying connect to server" do
          expect_raises(Exception) do
            HTTP::Client.get("http://#{HOST}:#{PORT}/bla")
          end

          # after request usual request just work
          res = client.bla("3.5", 9.6)
          res.ok?.should eq true
          res.value!.should eq 33.6
        end

        it "raw socket_client trying connect to server" do
          sock = TCPSocket.new(HOST, PORT)
          sock.write_byte(193.to_u8) # unsupported by msgpack symbol

          # after request usual request just work
          res = client.bla("3.5", 9.6)
          res.ok?.should eq true
          res.value!.should eq 33.6
        end

        it "connection to bad server" do
          client3 = SimpleRpc::Client.new(HOST, TCPPORT, mode: clmode)
          res = client3.request(Float64, :bla, "3.5", 9.6)
          res.ok?.should eq false
          res.message!.should start_with("SimpleRpc::ProtocallError: Unexpected byte '193' at 0")
        end

        it "Notify messages also works" do
          SpecProto.notify_count = 0
          SpecProto.notify_count.should eq 0

          sock = TCPSocket.new(HOST, PORT)
          {2_i8, "notif", [5]}.to_msgpack(sock)
          sock.flush

          sleep 0.05
          SpecProto.notify_count.should eq 5

          sock = TCPSocket.new(HOST, PORT)
          {2_i8, "notif", [10]}.to_msgpack(sock)
          sock.flush

          sleep 0.05
          SpecProto.notify_count.should eq 15
        end

        it "Notify with client" do
          SpecProto.notify_count = 0
          SpecProto.notify_count.should eq 0

          client.notify!("notif", 5)

          sleep 0.05
          SpecProto.notify_count.should eq 5

          client.notify!("notif", 15)

          sleep 0.05
          SpecProto.notify_count.should eq 20
        end

        it "sequence of requests with notify" do
          SpecProto.notify_count = 0
          SpecProto.notify_count.should eq 0

          f = 0.0

          100.times do |i|
            res = client.bla("#{i}.1", 2.5)
            if res.ok?
              f += res.value.not_nil!
            end

            client.notify!("notif", i)
          end

          f.should eq 12400.0
          sleep 0.05
          SpecProto.notify_count.should eq 4950
        end

        context "concurrent requests" do
          it "work" do
            n = 10
            m = 10
            ch = Channel(Int32).new

            n.times do |i|
              spawn do
                cl = if clmode == SimpleRpc::Client::Mode::Single
                       SpecProto::Client.new(HOST, PORT, mode: SimpleRpc::Client::Mode::Single)
                     else
                       client
                     end

                m.times do |j|
                  v1 = i * 10000 + j
                  v = cl.request!(Int32, :sleepi, 0.1 + rand(0.1), v1)
                  if v == v1
                    ch.send(v)
                  else
                    raise "unexpected value #{v1} -> #{v}"
                  end
                end
              end
            end

            t = Time.local
            (n * m).times { ch.receive }
            dt = (Time.local - t).to_f

            dt.should be >= (0.1 * m)
            dt.should be < ((0.1 + TIME_ERROR + 0.03) * m)
          end
        end
      end
    end
  end

  [SimpleRpc::Client::Mode::ConnectPerRequest, SimpleRpc::Client::Mode::Pool, SimpleRpc::Client::Mode::Single].each do |clmode|
    [{host: HOST, port: PORT_BAD, mode: clmode, unixsocket: nil}, {unixsocket: UNIXSOCK_BAD, host: "", port: 1, mode: clmode}].each do |client_opts|
      context "CLIENT(#{client_opts[:unixsocket] ? "UNIX" : "TCP"}:#{clmode})" do
        context "create connection" do
          it "raise when no connection, immediately" do
            client = SpecProto::Client.new(**client_opts)
            should_spend(0.0, ZERO_TIME_ERROR) do
              res = client.bla("3.5", 9.6)
              res.ok?.should eq false
              res.message!.should contain "SimpleRpc::CannotConnectError"
            end

            client.last_used_connection.try(&.connection_recreate_attempt).should eq 0
          end

          it "raise when no connection, but with reconnectings" do
            opts = client_opts.merge(create_connection_retries: 3, create_connection_retry_interval: 0.2)

            client = SpecProto::Client.new(**opts)
            should_spend(0.6, BIG_TIME_ERROR) do
              res = client.bla("3.5", 9.6)
              res.ok?.should eq false
              res.message!.should contain "SimpleRpc::CannotConnectError"
            end

            client.last_used_connection.try(&.connection_recreate_attempt).should eq 3
          end
        end
      end
    end
  end

  [SimpleRpc::Client::Mode::ConnectPerRequest, SimpleRpc::Client::Mode::Pool, SimpleRpc::Client::Mode::Single].each do |clmode|
    context "mode:#{clmode}" do
      it "MIX SSL and no" do
        cl_ok = SimpleRpc::Client.new(HOST, PORT, mode: clmode)
        cl_err = SimpleRpc::Client.new(HOST, PORT_SSL, mode: clmode)

        cl_ssl_ok = SimpleRpc::Client.new(HOST, PORT_SSL, ssl_context: CLIENT_SSL_CTX, mode: clmode)
        cl_ssl_err = SimpleRpc::Client.new(HOST, PORT, ssl_context: CLIENT_SSL_CTX, mode: clmode)

        cl_ok.request!(Float64, :bla, "2.0", 1.5).should eq 3.0
        cl_ssl_ok.request!(Float64, :bla, "2.0", 1.5).should eq 3.0

        expect_raises(SimpleRpc::ConnectionLostError, "IO::Error: Error reading socket") do
          cl_err.request!(Float64, :bla, "2.0", 1.5)
        end

        expect_raises(SimpleRpc::CannotConnectError, "OpenSSL::SSL::Error: SSL_connect") do
          cl_ssl_err.request!(Float64, :bla, "2.0", 1.5)
        end

        cl_ok.request!(Float64, :bla, "2.0", 1.5).should eq 3.0
        cl_ssl_ok.request!(Float64, :bla, "2.0", 1.5).should eq 3.0
      end
    end
  end

  [SimpleRpc::Client::Mode::ConnectPerRequest, SimpleRpc::Client::Mode::Pool, SimpleRpc::Client::Mode::Single].each do |clmode|
    [{ {host: HOST, port: PORT2, mode: clmode, unixsocket: nil}, SpecProto::Server.new(HOST, PORT2, logger: L) },
     { {unixsocket: UNIXSOCK2, host: "", port: 1, mode: clmode}, SpecProto::Server.new(unixsocket: UNIXSOCK2, logger: L) },
    ].each do |(client_opts, server)|
      context "CLIENT(#{client_opts[:unixsocket] ? "UNIX" : "TCP"}:#{clmode})" do
        it "connected after some reconnections" do
          opts = client_opts.merge(create_connection_retries: 3, create_connection_retry_interval: 0.2)
          with_run_server(server, 0.4) do |server|
            client = SpecProto::Client.new(**opts)
            should_spend(0.4, BIG_TIME_ERROR) do
              res = client.bla("3.5", 9.6)
              res.ok?.should eq true
            end

            client.last_used_connection.try(&.connection_recreate_attempt).should eq 2

            should_spend(0.0, ZERO_TIME_ERROR) do
              res = client.bla("3.5", 9.6)
              res.ok?.should eq true
            end

            client = SpecProto::Client.new(**opts)
            should_spend(0.0, ZERO_TIME_ERROR) do
              res = client.bla("3.5", 9.6)
              res.ok?.should eq true
            end
          end
        end
      end
    end
  end
end
