struct SimpleRpc::Result(T)
  getter error, message, value

  def initialize(@error : Error, @message : String? = nil, @value : T | Nil = nil)
  end

  def self.from(io : IO)
    err, msg = begin
      {Error.from_msgpack(io), String?.from_msgpack(io)}
    rescue MessagePack::Error
      return Result(T).new(Error::ERROR_UNPACK_RESPONSE, message: "failed to unpack server response")
    end

    res = begin
      T?.from_msgpack(io)
    rescue ex : MessagePack::Error
      return Result(T).new(Error::ERROR_UNPACK_RESPONSE, message: "failed to unpack server response (result not matched with type #{T.inspect})")
    end

    Result(T).new(err, msg, res)
  end
end
