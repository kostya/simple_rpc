module SimpleRpc
  VERSION = "1.4.0"

  REQUEST  = 0_i8
  NOTIFY   = 2_i8
  RESPONSE = 1_i8

  REQUEST_SIZE  = 4
  NOTIFY_SIZE   = 3
  RESPONSE_SIZE = 4

  DEFAULT_MSG_ID = 0_u32
end

require "./simple_rpc/*"
