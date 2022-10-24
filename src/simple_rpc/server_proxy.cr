# Sometimes you need to proxy requests to multiple servers, for load balancing
# This class exactly for this
# it change server for every request (by round robin method)
# and doesn't matter what client connection is, persistent or not.
# It also marks dead servers, and reshedule request to another server.
# Perfomance when proxing to 3 servers down from 154 Krps to 71 Krps
#
# proxy = SimpleRpc::ServerProxy.new("127.0.0.1", 9000)
# proxy.ports = [9001, 9002, 9003]
# proxy.run

class SimpleRpc::ServerProxy < SimpleRpc::Server
  property ports : Array(Int32)?

  @clients = Hash(Int32, SimpleRpc::Client).new
  @alive_ports = Array(Int32).new
  @alive_ports_current = 0
  @original_ports_size = 0

  def run
    ports.not_nil!.each do |port|
      @clients[port] = SimpleRpc::Client.new(@host, port, mode: :pool)
      @alive_ports << port
    end
    @original_ports_size = ports.not_nil!.size
    @alive_ports_current = rand(@alive_ports.size)
    super
  end

  def get_next_client
    @alive_ports_current = 0 if @alive_ports_current >= @alive_ports.size
    port = @alive_ports[@alive_ports_current]
    client = @clients[port]
    @alive_ports_current += 1
    {client, port}
  end

  protected def handle_request(ctx : Context, reschedule_count = 0)
    if @alive_ports.size == 0
      return ctx.write_error("All ports dead")
    end

    if reschedule_count > @original_ports_size
      return ctx.write_error("All ports busy or dead")
    end

    client, port = get_next_client

    result = :ok

    client.with_connection do |connection|
      v = begin
        begin
          req(client, ctx, connection)
        rescue SimpleRpc::ConnectionError
          # reconnecting here, if needed
          req(client, ctx, connection)
        end

        return true
      rescue SimpleRpc::ConnectionError
        result = :dead_connection
      rescue SimpleRpc::CommandTimeoutError
        result = :timeout
      end
    end

    case result
    when :dead_connection
      @clients.delete(port)
      @alive_ports.delete(port)
      @logger.try &.error { "Dead connection #{port}, reschedule" }
      return handle_request(ctx, reschedule_count + 1)
    when :timeout
      return handle_request(ctx, reschedule_count + 1)
    end

    # unreachable actually
    false
  end

  def req(client, ctx, connection)
    connection.catch_connection_errors do
      client.write_header(connection, ctx.method, ctx.msgid, ctx.notify) do |packer|
        MessagePack::Copy.new(ctx.io_with_args.rewind, connection.socket).copy_object # copy array of arguments
      end

      unless ctx.notify
        MessagePack::Copy.new(connection.socket, ctx.io).copy_object # copy body
      end

      ctx.io.flush
    end
  end
end
