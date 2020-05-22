# simple_rpc

[![Build Status](https://travis-ci.org/kostya/simple_rpc.svg?branch=master)](http://travis-ci.org/kostya/simple_rpc)

Remote Procedure Call Server and Client for Crystal. Implements msgpack-rpc protocall. Designed to be reliable and stable (catch every possible protocall/socket errors). It also quite performant: benchmark shows ~ 200K rps in pool mode (single server core, single client core).

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  simple_rpc:
    github: kostya/simple_rpc
```

## Usage

```crystal
require "simple_rpc"

# Example run server and client.

class MyRpc
  # When including SimpleRpc::Proto, all public instance methods inside class,
  # would be exposed to external rpc call.
  # Each method should define type for each argument, and also return type.
  # (Types of arguments should supports MessagePack::Serializable).
  # Instance of this class created on server for each call.
  include SimpleRpc::Proto

  def bla(x : Int32, y : String) : Float64
    x * y.to_f
  end
end

spawn do
  # running RPC server on 9000 port in background fiber
  MyRpc::Server.new("127.0.0.1", 9000).run
end

# wait until server up
sleep 0.1

# create rpc client
client = MyRpc::Client.new("127.0.0.1", 9000)
result = client.bla!(3, "5.5") # here can raise SimpleRpc::Errors
p result # => 16.5
```

#### When client code have no access to server proto, you can call raw requests:
```crystal
require "simple_rpc"

client = SimpleRpc::Client.new("127.0.0.1", 9000)
result = client.request!(Float64, :bla, 3, "5.5") # here can raise SimpleRpc::Errors
p result # => 16.5
```

#### When you dont want to raises on problems, you can check result by yourself:
```crystal
require "simple_rpc"

client = SimpleRpc::Client.new("127.0.0.1", 9000)
result = client.request(Float64, :bla, 3, "5.5") # no raise on error
if result.ok?
  p result.value! # => 16.5
else
  p result.message!
end
```

#### If you dont know what return type is, use MessagePack::Any:
```crystal
require "simple_rpc"

client = SimpleRpc::Client.new("127.0.0.1", 9000)
result = client.request!(MessagePack::Any, :bla, 3, "5.5")
p result.as_f + 1 # => 17.5
```

#### If you want to exchange complex data types, you should include MessagePack::Serializable to your data
```crystal
require "simple_rpc"

record MyResult, a : Int32, b : String { include MessagePack::Serializable }

class MyRequest
  include MessagePack::Serializable

  property a : Int32
  property b : Hash(String, String)?

  @[MessagePack::Field(ignore: true)]
  property c : Int32?
end

class MyRpc 
  include SimpleRpc::Proto

  def doit(req : MyRequest) : MyResult
    # ...
  end
end
```

#### Example calling from Ruby, with gem msgpack-rpc
```ruby
require 'msgpack/rpc'

client = MessagePack::RPC::Client.new('127.0.0.1', 9000)
result = client.call(:bla, 3, "5.5")
p result # => 16.5
```
