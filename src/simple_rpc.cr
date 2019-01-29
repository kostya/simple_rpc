module SimpleRpc
  VERSION = "0.10.0"

  REQUEST  = 0_i8
  NOTIFY   = 2_i8
  RESPONSE = 1_i8
end

require "./simple_rpc/*"
