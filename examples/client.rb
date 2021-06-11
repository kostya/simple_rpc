# gem install msgpack-rpc
require 'msgpack/rpc'

client = MessagePack::RPC::Client.new('127.0.0.1', 9000)
p client.call(:sum, 3, 5.5) # => 8.5
p client.call(:greeting, "Vasya") # => {"rand"=>0.47593728045415334, "msg"=>"Hello from Crystal Vasya"}
