module SimpleRpc
  VERSION = "0.11.1"

  REQUEST  = 0_i8
  NOTIFY   = 2_i8
  RESPONSE = 1_i8
end

require "./simple_rpc/*"
