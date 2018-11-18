require "../src/simple_rpc"
require "kemal"

Kemal.config.logger = Kemal::NullLogHandler.new
Kemal.config.port = 8099

get "/" do |env|
  if a = env.params.query["a"]?
    (a.to_i + 1).to_s
  else
    "0"
  end
end

spawn do
  Kemal.run
end

sleep 0.5

t = Time.now
s = 0
1000.times do |i|
  response = HTTP::Client.get "http://127.0.0.1:8099/?a=#{i}"
  if response.status_code == 200
    s += response.body.to_i
  end
end

p s
p Time.now - t
