record SimpleRpc::Context, msgid : UInt32, method : String, args_count : UInt32,
  unpacker : MessagePack::IOUnpacker, io : IO, notify : Bool do
  record RawMsgpack, data : Bytes
  record IOMsgpack, io : IO

  def skip_values(n)
    n.times { unpacker.skip_value }
  end

  def write_result(res)
    return true if notify

    case res
    when RawMsgpack
      packer = MessagePack::Packer.new(io)
      packer.write_array_start(SimpleRpc::RESPONSE_SIZE)
      packer.write(SimpleRpc::RESPONSE)
      packer.write(msgid)
      packer.write(nil)
      io.write(res.data)
    when IOMsgpack
      packer = MessagePack::Packer.new(io)
      packer.write_array_start(SimpleRpc::RESPONSE_SIZE)
      packer.write(SimpleRpc::RESPONSE)
      packer.write(msgid)
      packer.write(nil)
      IO.copy(res.io, io)
    else
      {SimpleRpc::RESPONSE, msgid, nil, res}.to_msgpack(io)
    end

    io.flush
    true
  end

  def write_error(msg)
    return true if notify

    {SimpleRpc::RESPONSE, msgid, msg, nil}.to_msgpack(io)
    io.flush
    true
  end
end
