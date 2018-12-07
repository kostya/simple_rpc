module SimpleRpc
  class Errors < Exception; end

  class CommandTimeoutError < Errors; end

  class ConnectionError < Errors; end

  class ConnectionLostError < ConnectionError; end

  class CannotConnectError < ConnectionError; end

  class RuntimeError < Errors; end

  class ProtocallError < RuntimeError; end
end
