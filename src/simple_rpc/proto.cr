require "msgpack"

module SimpleRpc::Proto
  macro included
    SIMPLE_RPC_HASH = Hash(String, (SimpleRpc::Context ->) ).new    
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
      def self.add_wrappers
        \{% for m in @type.methods %}
          \{% if m.visibility.stringify == ":public" %}
            \{{@type}}::SIMPLE_RPC_HASH["\{{m.name}}"] = ->(ctx : SimpleRpc::Context) { __simple_rpc_wrapper_\{{m.name}}(ctx) }
          \{% end %}
        \{% end %}
        SIMPLE_RPC_HASH[SimpleRpc::INTERNAL_PING_METHOD] = ->(ctx : SimpleRpc::Context) { ctx.write_result(true) }
      end

      \{% for m in @type.methods %}
        \{% if m.visibility.stringify == ":public" %}
          def self.__simple_rpc_wrapper_\{{m.name}}(ctx : SimpleRpc::Context)
            args_need_count = \{{ m.args.size.id }}
            if ctx.args_count != args_need_count
              return ctx.write_error(\\%Q[ArgumentError in \{{m.name}}\{{m.args.id}}: bad arguments count: expected #{args_need_count}, but got #{ctx.args_count}])
            end

            \{% if m.args.size > 0 %}
              \{% for arg in m.args %}
                \{% if arg.restriction %}
                  \%_var_\{{arg.id} =
                    begin
                      Union(\{{ arg.restriction }}).new(ctx.unpacker)
                    rescue ex : MessagePack::TypeCastError
                      token = ctx.unpacker.@lexer.@token
                      return ctx.write_error(\\%Q[ArgumentError in \{{m.name}}\{{m.args.id}}: bad argument \{{arg.name}}: '#{ex.message}' (at #{MessagePack::Token.to_s(token)})])
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
              if ENV["SIMPLE_RPC_BACKTRACE"]? == "1"
                msg = \\%Q[RuntimeError in #{ctx.method}\{{m.args.id}}: '#{ex.message}' [#{ex.backtrace.join(", ")}]]
              else
                msg = \\%Q[RuntimeError in #{ctx.method}\{{m.args.id}}: '#{ex.message}' (run server with env SIMPLE_RPC_BACKTRACE=1 to see backtrace)]
              end
              return ctx.write_error(msg)
            end

            return ctx.write_result(res)
          end
        \{% end %}
      \{% end %}

      class Server
        def add_wrappers
          \{{@type}}.add_wrappers
        end

        def method_find(method : String) : (SimpleRpc::Context ->)?
          \{{@type}}::SIMPLE_RPC_HASH[method]?
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
