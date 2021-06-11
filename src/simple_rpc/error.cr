module SimpleRpc
  class Errors < Exception; end # common class for all SimpleRpc errors

  class CommandTimeoutError < Errors; end # when client wait too long for answer from server

  class ConnectionError < Errors; end # common class for all connection errors

  class ConnectionLostError < ConnectionError; end # when client lost connection to server

  class CannotConnectError < ConnectionError; end # when client cant connect to server

  class PoolTimeoutError < ConnectionError; end # when no free connections in pool

  class RuntimeError < Errors; end # when task crashed on server

  class ProtocallError < Errors; end # when problem in client-server interaction

  class TypeCastError < Errors; end # when return type not casted to requested
end
