require 'msgpack/rpc'

class MyHandler
  def methodName2(arg1, arg2, arg3)
    puts "received"
    return "return result #{arg1.inspect} #{arg2.inspect} #{arg3.inspect}."
  end
end

server = MessagePack::RPC::Server.new
server.listen('127.0.0.1', 18800, MyHandler.new)
server.run
