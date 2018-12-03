struct SimpleRpc::Result(T)
  getter error, message, value

  def initialize(@error : Error, @message : String? = nil, @value : T | Nil = nil)
  end

  def self.from(io : IO)
    tuple = Tuple(Int8, UInt32, String?, T?).from_msgpack(io)

    resp_id = tuple[0]
    unless resp_id == 1_i8
      return Result(T).new(Error::ERROR_UNPACK_RESPONSE, message: "not 1 response")
    end

    msgid = tuple[1] # not used
    msg = tuple[2]
    res = tuple[3]

    err = if !msg
            SimpleRpc::Error::OK
          else
            if i = msg.index('|')
              err_id = msg[0...i].to_i
              msg = msg[i + 1..-1]
              SimpleRpc::Error.from_value?(err_id) || SimpleRpc::Error::UNKNOWN_ERROR
            else
              SimpleRpc::Error::UNKNOWN_ERROR
            end
          end

    Result(T).new(err, msg, res)
  rescue MessagePack::Error
    Result(T).new(Error::ERROR_UNPACK_RESPONSE, message: "failed to unpack server response (result not matched with type #{T.inspect})")
  rescue IO::Timeout
    Result(T).new(Error::TIMEOUT, message: "timeouted")
  rescue ex
    Result(T).new(Error::ERROR_UNPACK_RESPONSE, message: "unknown error #{ex.message}")
  end
end
