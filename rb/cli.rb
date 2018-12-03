require 'msgpack/rpc'

client = MessagePack::RPC::Client.new('127.0.0.1', 18800)

result = client.call(:methodName, 1, "2", {3 => 4})
p result
