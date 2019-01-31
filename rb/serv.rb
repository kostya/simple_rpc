require 'msgpack/rpc'

class MyHandler
  def methodName(int, float, string, hash)
    v = int + float + string.to_f + (hash[5] || -1.0)

    {value: v}
  end
end

PORT = (ARGV[0] || 18800).to_i
server = MessagePack::RPC::Server.new
server.listen('127.0.0.1', PORT, MyHandler.new)
server.run
