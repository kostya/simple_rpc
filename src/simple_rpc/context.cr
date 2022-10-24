require "log"

record SimpleRpc::Context, msgid : UInt32, method : String,
  node : MessagePack::Node, io : IO, notify : Bool, logger : Log? = nil, created_at : Time = Time.local do
  record RawMsgpack, data : Bytes
  record IOMsgpack, io : IO
  record RawSocketResponse

  def write_default_response
    packer = MessagePack::Packer.new(io)
    packer.write_array_start(SimpleRpc::RESPONSE_SIZE)
    packer.write(SimpleRpc::RESPONSE)
    packer.write(msgid)
    packer.write(nil)
  end

  def write_result(res)
    return true if notify

    case res
    when RawMsgpack
      write_default_response
      io.write(res.data)
    when IOMsgpack
      write_default_response
      IO.copy(res.io, io)
    when RawSocketResponse
      # do nothing
      # just flush
    else
      write_default_response
      res.to_msgpack(io)
    end

    io.flush

    if l = @logger
      l.info { "SimpleRpc: #{method} (in #{Time.local - created_at})" }
    end

    true
  end

  def write_error(msg)
    return true if notify

    {SimpleRpc::RESPONSE, msgid, msg, nil}.to_msgpack(io)
    io.flush

    if l = @logger
      l.error { "SimpleRpc: #{method}: #{msg} (in #{Time.local - created_at})" }
    end

    true
  end
end
