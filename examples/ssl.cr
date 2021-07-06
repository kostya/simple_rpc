require "../src/simple_rpc"

struct SslRpc
  include SimpleRpc::Proto

  def sum(x1 : Int32, x2 : Float64) : Float64
    x1 + x2
  end
end

spawn do
  server_context = OpenSSL::SSL::Context::Server.new
  server_context.certificate_chain = File.join("spec", ".fixtures", "openssl.crt")
  server_context.private_key = File.join("spec", ".fixtures", "openssl.key")

  puts "Server listen on 9000 port"
  SslRpc::Server.new("127.0.0.1", 9000, ssl_context: server_context).run
end

sleep 0

client_context = OpenSSL::SSL::Context::Client.new
client_context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
client = SimpleRpc::Client.new("127.0.0.1", 9000, ssl_context: client_context)

p client.request!(Float64, :sum, 1, 2.0)
