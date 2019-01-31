require 'msgpack/rpc'

PORT = (ARGV[0] || 18800).to_i
client = MessagePack::RPC::Client.new('127.0.0.1', PORT)
result = client.call(:methodName, 1, 1.5, "2.7", {5 => 15.8})
p result
