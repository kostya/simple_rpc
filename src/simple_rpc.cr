module SimpleRpc
  VERSION = "1.9.0"

  REQUEST  = 0_i8
  NOTIFY   = 2_i8
  RESPONSE = 1_i8

  REQUEST_SIZE  = 4
  NOTIFY_SIZE   = 3
  RESPONSE_SIZE = 4

  INTERNAL_PING_METHOD = "__simple_rpc_ping__"

  DEFAULT_MSG_ID = 0_u32
end

require "./simple_rpc/*"
