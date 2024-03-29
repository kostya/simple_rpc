# simple_rpc

[![Build Status](https://github.com/kostya/simple_rpc/actions/workflows/ci.yml/badge.svg)](https://github.com/kostya/simple_rpc/actions/workflows/ci.yml?query=branch%3Amaster+event%3Apush)

RPC Server and Client for Crystal. Implements [msgpack-rpc](https://github.com/msgpack-rpc/msgpack-rpc/blob/master/spec.md) protocol. Designed to be reliable and stable (catch every possible protocol/socket errors). It also quite fast: benchmark performs at 160Krps for single server process and single clients process (in pool mode).

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  simple_rpc:
    github: kostya/simple_rpc
```

## Usage


## Server example

To create RPC server from your class/struct, just `include SimpleRpc::Proto`, it adds `MyRpc::Server` class and also expose all public methods to the external rpc calls. Each method should define type for each argument and also return type. Types of arguments should supports `MessagePack::Serializable` (by default it supported by most common language types, including Unions). Instance of `MyRpc` created for each rpc call, so you should not use instance variables for between-request interaction.

```crystal
require "simple_rpc"

struct MyRpc
  include SimpleRpc::Proto

  def sum(x1 : Int32, x2 : Float64) : Float64
    x1 + x2
  end

  record Greeting, rand : Float64, msg : String { include MessagePack::Serializable }

  def greeting(name : String) : Greeting
    Greeting.new(rand, "Hello from Crystal #{name}")
  end
end

puts "Server listen on 9000 port"
MyRpc::Server.new("127.0.0.1", 9000).run
```

## Client example

Client simple method to use is: `.request!(return_type, method_name, *args)`. This call can raise [SimpleRpc::Errors](https://github.com/kostya/simple_rpc/blob/master/src/simple_rpc/error.cr). If you not care about return type use can use `MessagePack::Any` (in example below, you also can use `Greeting` record instead if you share that declaration). If you dont want to raise on errors you can use similar method `request` and process result manually.

```crystal
require "simple_rpc"

client = SimpleRpc::Client.new("127.0.0.1", 9000)

p client.request!(Float64, :sum, 3, 5.5)
# => 8.5
p client.request!(MessagePack::Any, :greeting, "Vasya")
# => {"rand" => 0.7839463879734746, "msg" => "Hello from Crystal Vasya"}
```

#### MsgpackRPC is multi-language RPC, so you can call it, for example, from Ruby
```ruby
# gem install msgpack-rpc
require 'msgpack/rpc'

client = MessagePack::RPC::Client.new('127.0.0.1', 9000)
p client.call(:sum, 3, 5.5)
# => 8.5
p client.call(:greeting, "Vasya")
# => {"rand"=>0.47593728045415334, "msg"=>"Hello from Crystal Vasya"}
```

## Client modes

`SimpleRpc::Client` can work in multiple modes, you can choose it by argument `mode`:
    
  - `:connect_per_request`
    Create new connection for every request, after request done close connection. Quite slow (because spend time to create connection), but concurrency unlimited (only by OS). Good for slow requests. Used by default.
  
  - `:pool`
    Create persistent pool of connections. Much faster, but concurrency limited by pool_size (default = 20). Good for millions of very fast requests. Every request have one autoreconnection attempt (because connection in pool can be outdated).

  - `:single` 
    Single persistent connection. Same as pool of size 1, you should manage concurrency by yourself. Every request have one autoreconnection attempt (because persistent connection can be outdated).

Example of client, which can handle 50 concurrent requests, and can be used in multifiber environment:

```crystal
client = SimpleRpc::Client.new("127.0.0.1", 9000, mode: :pool, pool_size: 50, pool_timeout: 1.0)
```
