struct SimpleRpc::Result(T)
  getter error, message, value

  def initialize(@error : Error, @message : String? = nil, @value : T | Nil = nil)
  end

  def self.from(resp : Response)
    if resp.error == Error::OK
      res = Tuple(Error, String?, T?).from_msgpack(resp.raw.not_nil!)
      Result(T).new(res[0], message: res[1], value: res[2])
    else
      Result(T).new(resp.error)
    end
  rescue ex : MessagePack::Error
    msg = if r = resp.raw
            String.new(r)
          end
    Result(T).new(Error::ERROR_UNPACK_RESPONSE, message: msg)
  end
end
