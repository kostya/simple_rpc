require "http/server"
require "msgpack"

module SimpleRpc::Proto
  macro included
    class HttpClient < SimpleRpc::HttpClient; end
    class HttpServer < SimpleRpc::HttpServer; end
    class SocketServer < SimpleRpc::SocketServer; end
    class SocketClient < SimpleRpc::SocketClient; end

    macro finished
      def self.handle_request(ctx : SimpleRpc::Server::Context)
        \{% begin %}
        case ctx.req.method
        \{% for m in @type.methods %}
          \{% if m.visibility.stringify == ":public" %}
            when "\{{m.name}}"
              args_size = \{{ m.args.size.id }}
              return ctx.write_error(SimpleRpc::Error::ERROR_UNPACK_REQUEST, "expected #{args_size} args, but got #{ctx.req.args_size}") if ctx.req.args_size != args_size

              \{% if m.args.size > 0 %}
                req = begin
                  Tuple.new(\{{ m.args.map do |arg|
                                  if arg.restriction
                                    "#{arg.restriction}.new(ctx.req.unpacker)"
                                  else
                                    raise "argument '#{arg}' in method '#{m.name}' must have a type restriction"
                                  end
                                end.join(", ").id
                                }})
                rescue MessagePack::Error
                  return ctx.write_error(SimpleRpc::Error::ERROR_UNPACK_REQUEST, "bad arguments, expected \{{m.args}}, but got something else")
                rescue ex
                  return ctx.write_error(SimpleRpc::Error::ERROR_UNPACK_REQUEST, "failed to read from io '#{ex.message}'")
                end
              \{% else %}
                req = Tuple.new
              \{% end %}

              proto = \{{@type}}.new
              res = begin
                proto.\{{m.name}}(*req)
              rescue ex
                return ctx.write_error(SimpleRpc::Error::TASK_EXCEPTION, ex.message || "unknown error in task execution")
              end

              return ctx.write_result(res)
          \{% end %}
        \{% end %}
        end
        \{% end %}
      end

      class HttpServer
        def handle_request(ctx)
          \{{@type}}.handle_request(ctx)
        end
      end

      class SocketServer
        def handle_request(ctx)
          \{{@type}}.handle_request(ctx)
        end
      end

      module ClientExt
        \{% for m in @type.methods %}
          \{% if m.visibility.stringify == ":public" %}
            \{% if !m.return_type %}
              \{% raise "method '#{m.name}' must have a return type" %}
            \{% end %}

            \{% args_list = m.args.join(", ").id %}
            \{% args = m.args.map { |a| a.name }.join(", ").id %}

            def \{{m.name}}(\{{args_list}})
              request(\{{m.return_type.id}}, \{{m.name.stringify}}, \{{args.id}})
            end
          \{% end %}
        \{% end %}
      end

      class SocketClient
        include ClientExt
      end

      class HttpClient
        include ClientExt
      end
    end
  end
end
