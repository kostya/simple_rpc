require "http/server"
require "msgpack"

module SimpleRpc::Proto
  macro included
    class Client < SimpleRpc::RawClient
    end

    macro finished
      class Server < SimpleRpc::Server
        def handle_http(path, body_io, response)
          \{% begin %}
          case path
          \{% for m in @type.methods %}
            \{% if m.visibility.stringify == ":public" %}
              when "/rpc_\{{m.name}}"
                \{% if m.args.size > 0 %}
                  tuple = Tuple(\{{ m.args.map do |arg|
                                  if arg.restriction
                                    arg.restriction
                                  else
                                    raise "argument '#{arg}' in method '#{m.name}' must have a type restriction"
                                  end
                                end.join(", ").id
                                }})

                  req = begin
                    tuple.from_msgpack(body_io)
                  rescue MessagePack::Error
                    pack(response, SimpleRpc::Error::ERROR_UNPACK_REQUEST, "msgpack not matched with #{tuple.inspect}")
                    return
                  end
                \{% else %}
                  req = Tuple.new
                \{% end %}

                proto = \{{@type}}.new
                res = begin
                  proto.\{{m.name}}(*req)
                rescue ex
                  pack(response, SimpleRpc::Error::TASK_EXCEPTION, ex.message)
                  return
                end

                pack(response, SimpleRpc::Error::OK, nil, res)
            \{% end %}
          \{% end %}

          else
            unless additional_http(path, body_io, response)
              pack(response, SimpleRpc::Error::UNKNOWN_METHOD, "unknown method '#{path[5..-1]}'")
            end
          end
          \{% end %}
        end
      end

      class Client
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
    end
  end
end
