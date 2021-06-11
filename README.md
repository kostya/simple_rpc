# simple_rpc

[![Build Status](https://travis-ci.org/kostya/simple_rpc.svg?branch=master)](http://travis-ci.org/kostya/simple_rpc)

Remote Procedure Call Server and Client for Crystal. Implements msgpack-rpc protocall. Designed to be reliable and stable (catch every possible protocall/socket errors). It also quite fast: benchmark performs at 200Krps for single server process and single clients process.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  simple_rpc:
    github: kostya/simple_rpc
```

## Usage


#### Server example

To create RPC server from your class/struct, just `include SimpleRpc::Proto`, it would expose all public methods to the external rpc calls and creates MyRpc::Server class. Each method should define type for each argument and also return type. Types of arguments should supports MessagePack::Serializable (by default it supported by most common language types, including Unions). Instance of MyRpc created for each rpc call, so you should not use instance variables for between-request interaction.

```crystal
require "simple_rpc"

struct MyRpc
  include SimpleRpc::Proto

  def my_method(x : Int32, y : String) : Float64
    x * y.to_f
  end
end

MyRpc::Server.new("127.0.0.1", 9000).run
```

#### Client example
```crystal
require "simple_rpc"

client = SimpleRpc::Client.new("127.0.0.1", 9000)
result = client.request!(Float64, :my_method, 3, "5.5") # here can raise SimpleRpc::Errors
p result # => 16.5
```

#### MsgpackRPC is multilanguage RPC, so you can call it, for example, from Ruby
```ruby
# gem install msgpack-rpc
require 'msgpack/rpc'

client = MessagePack::RPC::Client.new('127.0.0.1', 9000)
result = client.call(:my_method, 3, "5.5")
p result # => 16.5
```

## Client modes

SimpleRpc::Client can work in multiple modes, which is passed as argument `mode` to client:

    * :connect_per_request - Create new connection for every request, after request done close connection. Quite slow (because spend time to create connection), but concurrency unlimited (only by OS). Good for slow requests. Used by default.

    * :pool - Create persistent pool of connections. Much faster, but concurrency limited by pool_size (default = 20). Good for millions of very fast requests. Every request have one autoreconnection attempt (because connection in pool can be outdated).

    * :single - Single persistent connection. Same as pool of size 1, you should manage concurrency by yourself. Every request have one autoreconnection attempt (because persistent connection can be outdated).

Example of client, which can handle 50 concurrent requests:

```crystal
client = SimpleRpc::Client.new("127.0.0.1", 9000, mode: pool, pool_size: 50, pool_timeout = 1.0)
```
