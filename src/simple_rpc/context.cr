record SimpleRpc::Context, msgid : UInt32, method : String, args_count : UInt32, unpacker : MessagePack::IOUnpacker, io : IO do
  record RawMsgpack, data : Bytes
  record IOMsgpack, io : IO

  def skip_values(n)
    n.times { unpacker.skip_value }
  end

  def write_result(res)
    case res
    when RawMsgpack
      packer = MessagePack::Packer.new(io)
      packer.write_array_start(4_u8)
      packer.write(1_u8)
      packer.write(msgid)
      packer.write(nil)
      io.write(res.data)
    when IOMsgpack
      packer = MessagePack::Packer.new(io)
      packer.write_array_start(4_u8)
      packer.write(1_u8)
      packer.write(msgid)
      packer.write(nil)
      IO.copy(res.io, io)
    else
      {1_u8, msgid, nil, res}.to_msgpack(io)
    end

    io.flush
    true
  end

  def write_error(msg)
    {1_u8, msgid, msg, nil}.to_msgpack(io)
    io.flush
    true
  end
end
