require "http/server"
require "msgpack"

module SimpleRpc::Proto
  macro included
    class Client < SimpleRpc::Client; end
    class Server < SimpleRpc::Server; end

    macro finished
      def self.handle_request(ctx : SimpleRpc::Server::Ctx)
        \{% begin %}
        case ctx.method
        \{% for m in @type.methods %}
          \{% if m.visibility.stringify == ":public" %}
            when "\{{m.name}}"
              args_need_count = \{{ m.args.size.id }}
              if ctx.args_count != args_need_count
                ctx.skip_values(ctx.args_count)
                return ctx.write_error("bad arguments, expected #{ \{{m.args.stringify}} }, but got #{ctx.args_count} args")
              end

              \{% if m.args.size > 0 %}
                c = 0
                begin
                  \{% for arg in m.args %}
                    \{% if arg.restriction %}
                      c += 1
                      value_unpacker = MessagePack::TokensUnpacker.new(ctx.unpacker.read_value_tokens)
                      \%_var_\{{arg.id} = \{{ arg.restriction }}.new(value_unpacker)
                    \{% else %}
                      \{% raise "argument '#{arg}' in method '#{m.name}' must have a type restriction" %}
                    \{% end %}
                  \{% end %}
                rescue MessagePack::Error
                  ctx.skip_values(ctx.args_count - c)
                  return ctx.write_error("bad arguments, expected #{ \{{m.args.stringify}} }, but got something else")
                end
              \{% end %}

              res = begin
                \{{@type}}.new.\{{m.name}}(\{% for arg in m.args %} \%_var_\{{arg.id}, \{% end %})
              rescue ex
                return ctx.write_error("Exception in task execution: #{ex.message}")
              end

              return ctx.write_result(res)
          \{% end %}
        \{% end %}
        end
        \{% end %}
      end

      class Server
        def handle_request(ctx)
          \{{@type}}.handle_request(ctx)
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
