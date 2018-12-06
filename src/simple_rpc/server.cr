class SimpleRpc::Server
  record RawMsgpack, data : Bytes
  record IOMsgpack, io : IO

  record ReqError, error : Error, msg : String
  record Request, unpacker : MessagePack::Unpacker, method : String, msgid : UInt32, args_size : Int32
  record Notify, from_io : IO, method : String
  record Eof

  alias ReqType = Request | ReqError | Eof # | Notify

  record Context, req : Request, to_io : IO do
    # TODO: disable sync?
    def write_result(res)
      case res
      when RawMsgpack
        packer = MessagePack::Packer.new(to_io)
        packer.write_array_start(4)
        packer.write(1_u8)
        packer.write(req.msgid)
        packer.write(nil)
        to_io.write(res.data)
      when IOMsgpack
        packer = MessagePack::Packer.new(to_io)
        packer.write_array_start(4)
        packer.write(1_u8)
        packer.write(req.msgid)
        packer.write(nil)
        IO.copy(res.io, to_io)
      else
        {1_u8, req.msgid, nil, res}.to_msgpack(to_io)
      end

      to_io.flush

      true
    rescue
      # skip all write errors
    end

    # TODO: disable sync?
    def self.write_error(io, err : ReqError, msgid = 0_u32)
      {1_u8, msgid, "#{err.error.value}|#{err.msg}", nil}.to_msgpack(io)
      io.flush

      true
    rescue
      # skip all write errors
    end

    def write_error(err : ReqError)
      Context.write_error(to_io, err, req.msgid)
    end

    def write_error(err : Error, msg : String)
      Context.write_error(to_io, ReqError.new(err, msg), req.msgid)
    end
  end

  protected def load_request(from_io) : ReqType
    unpacker = MessagePack::Unpacker.new(from_io)
    token = unpacker.prefetch_token
    return Eof.new if token.type == MessagePack::Token::Type::Eof
    return ReqError.new(SimpleRpc::Error::ERROR_UNPACK_REQUEST, "expected array as request") unless token.type == MessagePack::Token::Type::Array

    size = token.size
    token.used = true

    case size
    # when 3
    #   req_type = unpacker.read_int
    #   if req_type == 2
    #     method = unpacker.read_string
    #     Notify.new(from_io, method)
    #   else
    #     return ReqError.new("notify req_type should eq 2")
    #   end
    when 4
      req_type = Int8.new(unpacker)
      if req_type == 0_i8
        msgid = UInt32.new(unpacker)
        method = unpacker.read_string
        args_size = unpacker.read_array_size
        Request.new(unpacker, method, msgid, args_size)
      else
        return ReqError.new(SimpleRpc::Error::ERROR_UNPACK_REQUEST, "request req_type should eq 0")
      end
    else
      return ReqError.new(SimpleRpc::Error::ERROR_UNPACK_REQUEST, "expected array with size 4, but not #{size}")
    end
  rescue ex : MessagePack::Error
    ReqError.new(SimpleRpc::Error::ERROR_UNPACK_REQUEST, "load msgpack request #{ex.message}")
  rescue IO::Timeout
    ReqError.new(SimpleRpc::Error::TIMEOUT, "timeouted read request")
  rescue
    ReqError.new(SimpleRpc::Error::ERROR_UNPACK_REQUEST, "protocall error: load request")
  end
end
