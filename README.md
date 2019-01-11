# simple_rpc

Remote Procedure Call Server and Client for Crystal. Designed to be reliable and stable (catch every possible protocall errors). Compatible with msgpack-rpc protocall.

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

class MyRpc 
  include SimpleRpc::Proto

  def bla(x : Int32, y : String) : Float64
    x * y.to_f
  end
end

spawn do
  MyRpc::Server.new("127.0.0.1", 9000).run
end

sleep 0.1
client = MyRpc::Client.new("127.0.0.1", 9000)
result = client.bla(3, "5.5")

if result.ok?
  p result.value! + 1 # => 17.5
else
  p result.message!
end
```

#### When client code have no access to server proto, you can call raw requests:
```crystal
require "simple_rpc"

client = SimpleRpc::Client.new("127.0.0.1", 9000)
result = client.request(Float64, :bla, 3, "5.5") # no raises if error

if result.ok?
  p result.value! # => 16.5
else
  p result.message!
end
```

#### When you dont want to check errors, and ok with raise on problem:
```crystal
require "simple_rpc"

client = SimpleRpc::Client.new("127.0.0.1", 9000)
result = client.request!(Float64, :bla, 3, "5.5") # here can raise SimpleRpc::Errors
p result # => 16.5
```

#### If you want to exchange complex data types, you should include MessagePack::Serializable
```crystal
require "simple_rpc"

record Result, a : Int32, b : String { include MessagePack::Serializable }

class MyData
  include MessagePack::Serializable

  property a : Int32
  property b : String
  property c : Hash(String, String)?

  @[MessagePack::Field(ignore: true)]
  property d : Int32?
end

class MyRpc 
  include SimpleRpc::Proto

  def complex(data : MyData) : Result
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
