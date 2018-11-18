require "http/server"
require "msgpack"

module SimpleRpc::Proto
  macro included
    def self.handle_http(path, raw, response)
      \{% begin %}
      case path

      # todo; select only public methods
      \{% for m in @type.methods %}
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
              tuple.from_msgpack(raw)
            rescue MessagePack::Error
              {SimpleRpc::Error::ERROR_UNPACK_REQUEST, "msgpack not matched with #{tuple.inspect}", nil}.to_msgpack(response)
              return
            end
          \{% else %}
            req = Tuple.new
          \{% end %}

          proto = self.new
          res = begin
            proto.\{{m.name}}(*req)
          rescue ex
            {SimpleRpc::Error::TASK_EXCEPTION, ex.message, nil}.to_msgpack(response)
            return
          end

          {SimpleRpc::Error::OK, nil, res}.to_msgpack(response)
      \{% end %}

      else
        {SimpleRpc::Error::UNKNOWN_METHOD, path, nil}.to_msgpack(response)
      end
      \{% end %}
    end

    class Server < SimpleRpc::Server
      def handle_http(path, raw, response)
        {{@type}}.handle_http(path, raw, response)
      end
    end

    macro finished
      class Client < SimpleRpc::Client
        # todo; select only public methods
        \{% for m in @type.methods %}
          \{% if !m.return_type %}
            \{% raise "method '#{m.name}' must have a return type" %}
          \{% end %}

          \{% args_list = m.args.join(", ").id %}
          \{% args = m.args.map { |a| a.name }.join(", ").id %}

          def \{{m.name}}(\{{args_list}}) : SimpleRpc::Result(\{{m.return_type.id}})
            resp = @raw_client.request(\{{m.name.stringify}}, Tuple.new(\{{args.id}}))
            SimpleRpc::Result(\{{m.return_type.id}}).from(resp)
          end
        \{% end %}
      end
    end
  end
end
