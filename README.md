# simple_rpc

Remote Procedure Call Server and Client for Crystal. Designed to be reliable and stable (catch every possible protocall errors).

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

p result.error # => SimpleRpc::Error::OK
p result.value # => 16.5
```

#### When client code have no access to server proto, you can call raw requests:
```crystal
require "simple_rpc"
class MyRpc 
  include SimpleRpc::Proto
end

client = MyRpc::Client.new("127.0.0.1", 9000)
result = client.request(Float64, :bla, 3, "5.5")

p result.error # => SimpleRpc::Error::OK
p result.value # => 16.5
```
