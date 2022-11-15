# Sometimes you need to proxy requests to multiple servers, for load balancing
# This class exactly for this
# it change server for every request (by round robin method)
# and doesn't matter what client connection is, persistent or not.
# It also marks dead servers, and reshedule request to another server.
# Perfomance when proxing to 3 servers down from 154 Krps to 71 Krps
#
# proxy = SimpleRpc::ServerProxy.new("127.0.0.1", 9000)
# proxy.set_ports([9001, 9002, 9003])
# proxy.check_dead_ports_in = 5.seconds
# proxy.run

class SimpleRpc::ServerProxy < SimpleRpc::Server
  # Set proxing ports
  # this method can be called at any time, not exactly at beginning of the run
  def set_ports(ports : Array(Int32))
    @ports = ports.sort

    @alive_ports.each do |port|
      mark_port_dead(port) unless ports.includes?(port)
    end

    @ports.each do |port|
      add_alive_port(port, new_client(port)) unless @clients[port]?
    end
  end

  property check_dead_ports_in = 30.seconds
  property print_stats_in = 60.seconds
  @ports = Array(Int32).new
  @clients = Hash(Int32, SimpleRpc::Client).new
  @alive_ports = Array(Int32).new
  @alive_ports_current = 0

  protected def before_run
    if check_dead_ports_in.to_f > 0
      spawn do
        loop do
          break unless @server
          sleep check_dead_ports_in
          check_dead_ports
        end
      end
    end

    if print_stats_in.to_f > 0
      spawn do
        loop do
          break unless @server
          sleep print_stats_in
          loggin "Stat [#{@ports.size}, #{@alive_ports.size}], All ports: #{@ports}, Alive ports: #{@alive_ports}"
        end
      end
    end
  end

  protected def new_client(port)
    SimpleRpc::Client.new(@host, port, mode: :pool, connect_timeout: 1.0)
  end

  protected def add_alive_port(port, client)
    @clients[port] = client
    @alive_ports << port
  end

  protected def mark_port_dead(port)
    @clients.delete(port)
    @alive_ports.delete(port)
  end

  protected def get_next_client
    @alive_ports_current = 0 if @alive_ports_current >= @alive_ports.size
    port = @alive_ports[@alive_ports_current]
    client = @clients[port]
    @alive_ports_current += 1
    {client, port}
  end

  protected def loggin(msg)
    puts "[#{Time.local}] -- Proxy(#{@port}): #{msg}"
  end

  protected def handle_request(ctx : Context)
    # special method added by proxy
    case ctx.method
    when "__simple_rpc_proxy_ports__"
      return ctx.write_result({@ports, @alive_ports})
    end

    handle_cxt ctx
  end

  protected def handle_cxt(ctx : Context, reschedule_count = 0)
    return ctx.write_error("Proxy: No alive ports") if @alive_ports.size == 0
    return ctx.write_error("Proxy: All ports busy") if reschedule_count > @ports.size

    client, port = get_next_client
    begin
      return req(client, ctx)
    rescue SimpleRpc::ConnectionLostError # reconnecting here, if needed
      return req(client, ctx)
    end

    # unreachable actually
    false
  rescue SimpleRpc::ConnectionError
    mark_port_dead(port)
    loggin "Dead connection #{port}, reschedule"
    return handle_cxt(ctx, reschedule_count + 1)
  rescue SimpleRpc::CommandTimeoutError
    loggin "Timeout #{port}, reschedule"
    return handle_cxt(ctx, reschedule_count + 1)
  end

  protected def req(client, ctx)
    client.with_connection do |connection|
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

    true
  end

  protected def check_dead_ports
    return if @alive_ports.size == @ports.size

    dead_ports = @ports - @alive_ports
    dead_ports.each do |port|
      client = new_client(port)
      result = client.request(Bool, SimpleRpc::INTERNAL_PING_METHOD)
      if result.ok? && result.value == true
        loggin("Alive #{port}")
        add_alive_port(port, client)
      else
        client.close
      end
    end
  end
end
