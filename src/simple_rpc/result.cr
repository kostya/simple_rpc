struct SimpleRpc::Result(T)
  getter error, value

  def initialize(@error : Errors? = nil, @value : T | Nil = nil)
  end

  def ok?
    @error.nil?
  end

  def error!
    @error.not_nil!
  end

  def message!
    if e = @error
      "#{e.class}: #{e.message}"
    else
      ""
    end
  end

  def value!
    @value.not_nil!
  end
end
