require "msgpack"

module SimpleRpc::Proto
  macro included
    class Client < SimpleRpc::Client; end
    class Server < SimpleRpc::Server; end

    @simple_rpc_context : SimpleRpc::Context?

    protected def simple_rpc_context=(ctx)
      @simple_rpc_context = ctx
    end

    protected def simple_rpc_context
      @simple_rpc_context.not_nil!
    end

    macro finished
      def self.handle_request(ctx : SimpleRpc::Context)
        \{% begin %}
        case ctx.method
        \{% for m in @type.methods %}
          \{% if m.visibility.stringify == ":public" %}
            when "\{{m.name}}"
              args_need_count = \{{ m.args.size.id }}
              if ctx.args_count != args_need_count
                ctx.skip_values(ctx.args_count)
                return ctx.write_error(\\%Q[bad arguments, expected \{{m.args.id}}, but got #{ctx.args_count} args])
              end

              \{% if m.args.size > 0 %}
                \{% for arg in m.args %}
                  \%unpacker_\{{arg.id} = MessagePack::NodeUnpacker.new(ctx.unpacker.read_node)
                \{% end %}

                \{% for arg in m.args %}
                  \{% if arg.restriction %}
                    \%_var_\{{arg.id} =
                      begin
                        Union(\{{ arg.restriction }}).new(\%unpacker_\{{arg.id})
                      rescue MessagePack::TypeCastError
                        token = \%unpacker_\{{arg.id}.@node.tokens.first
                        return ctx.write_error(\\%Q[bad arguments, expected \{{m.args.id}}, but got \{{arg.name}}: #{MessagePack::Token.to_s(token)}])
                      end
                  \{% else %}
                    \{% raise "argument '#{arg}' in method '#{m.name}' must have a type restriction" %}
                  \{% end %}
                \{% end %}
              \{% end %}

              res = begin
                obj = \{{@type}}.new
                obj.simple_rpc_context = ctx
                obj.\{{m.name}}(\{% for arg in m.args %} \%_var_\{{arg.id}, \{% end %})
              rescue ex
                return ctx.write_error("Exception in task execution: #{ex.message}")
              end

              return ctx.write_result(res)
          \{% end %}
        \{% end %}
        else
          # skip
        end
        \{% end %}
      end

      class Server
        def handle_request(ctx : SimpleRpc::Context)
          \{{@type}}.handle_request(ctx)
        end
      end

      class Client
        \{% for m in @type.methods %}
          \{% if m.visibility.stringify == ":public" %}
            \{% if !m.return_type %} \{% raise "method '#{m.name}' must have a return type" %} \{% end %}
            \{% args_list = m.args.join(", ").id %}
            \{% args = m.args.map { |a| a.name }.join(", ").id %}
            def \{{m.name}}(\{{args_list}})
              request(\{{m.return_type.id}}, \{{m.name.stringify}}, \{{args.id}})
            end

            def \{{m.name}}!(\{{args_list}})
              request!(\{{m.return_type.id}}, \{{m.name.stringify}}, \{{args.id}})
            end
          \{% end %}
        \{% end %}
      end
    end
  end
end
