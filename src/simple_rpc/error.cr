module SimpleRpc
  enum Error
    OK                    # +
    HTTP_UNKNOWN_ERROR    # +
    HTTP_BAD_STATUS       # +
    ERROR_UNPACK_REQUEST  # +
    ERROR_UNPACK_RESPONSE # +

    HTTP_EXCEPTION
    TIMEOUT
    CONNECT_TIMEOUT

    UNKNOWN_METHOD # +
    TASK_EXCEPTION # +
  end
end
