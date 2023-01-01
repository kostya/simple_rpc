require "log"

class SimpleRpc::Context
  record RawMsgpack, data : Bytes
  record IOMsgpack, io : IO
  record RawSocketResponse

  property method : String
  getter unpacker : MessagePack::IOUnpacker
  getter args_count : UInt32

  getter msgid : UInt32
  getter io_with_args : IO::Memory
  getter io : IO
  getter notify : Bool
  @logger : Log?
  @created_at : Time

  def initialize(@msgid, @method, @io_with_args, @io, @notify, @logger = nil, @created_at = Time.local)
    @unpacker = MessagePack::IOUnpacker.new(@io_with_args.rewind)
    @args_count = 0
  end

  def read_args_count
    @args_count = @unpacker.read_array_size
    @unpacker.finish_token!
  end

  def write_default_response
    packer = MessagePack::Packer.new(@io)
    packer.write_array_start(SimpleRpc::RESPONSE_SIZE)
    packer.write(SimpleRpc::RESPONSE)
    packer.write(@msgid)
    packer.write(nil)
  end

  def write_result(res)
    return if @notify

    case res
    when RawMsgpack
      write_default_response
      @io.write(res.data)
    when IOMsgpack
      write_default_response
      IO.copy(res.io, @io)
    when RawSocketResponse
      # do nothing
      # just flush
    else
      write_default_response
      res.to_msgpack(@io)
    end

    @io.flush

    if l = @logger
      l.info { "SimpleRpc: #{method} (in #{Time.local - @created_at})" }
    end

    nil
  end

  def write_error(msg)
    return if @notify

    {SimpleRpc::RESPONSE, @msgid, msg, nil}.to_msgpack(@io)
    @io.flush

    if l = @logger
      l.error { "SimpleRpc: #{method}: #{msg} (in #{Time.local - @created_at})" }
    end

    nil
  end
end
