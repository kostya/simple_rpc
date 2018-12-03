abstract class SimpleRpc::Client
  abstract def request(klass : T.class, name, *args) forall T

  def write_request(io, action, args)
    {0_i8, 0_u32, action, args}.to_msgpack(io)
    io.flush
  end

  def write_request(action, args)
    {0_i8, 0_u32, action, args}.to_msgpack
  end
end
