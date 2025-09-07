`ifndef AES_DEFINES_SVH
`define AES_DEFINES_SVH

`define AES128_ROUNDS_NUM   10
`define AES256_ROUNDS_NUM   14

`define AES_BLOCK_SIZE      128
`define AES128_KEY_SIZE     128
`define AES256_KEY_SIZE     256

`define AES_WORD_SIZE       `AES_BLOCK_SIZE/4
`define AES_1ST_WORD        31:0
`define AES_2ND_WORD        63:32
`define AES_3RD_WORD        95:64
`define AES_4TH_WORD        127:96

`define AES128_RCON_NUM     10
`define AES256_RCON_NUM     7
`define AES_RCON_01         32'h00000001
`define AES_RCON_02         32'h00000002
`define AES_RCON_03         32'h00000004
`define AES_RCON_04         32'h00000008
`define AES_RCON_05         32'h00000010
`define AES_RCON_06         32'h00000020
`define AES_RCON_07         32'h00000040
`define AES_RCON_08         32'h00000080
`define AES_RCON_09         32'h0000001b
`define AES_RCON_10         32'h00000036

`define AES_GMUL_01(b) b
`define AES_GMUL_02(b) (b[7] ? (b<<1 ^ 8'h1b) : b<<1)
`define AES_GMUL_03(b) (`AES_GMUL_02(b) ^ b)
`define AES_GMUL_09(b) (`AES_GMUL_02(`AES_GMUL_02(`AES_GMUL_02(b))) ^ b)
`define AES_GMUL_0B(b) (`AES_GMUL_02(`AES_GMUL_02(`AES_GMUL_02(b))) ^ `AES_GMUL_02(b) ^ b)
`define AES_GMUL_0D(b) (`AES_GMUL_02(`AES_GMUL_02(`AES_GMUL_02(b))) ^ `AES_GMUL_02(`AES_GMUL_02(b)) ^ b)
`define AES_GMUL_0E(b) (`AES_GMUL_02(`AES_GMUL_02(`AES_GMUL_02(b))) ^ `AES_GMUL_02(`AES_GMUL_02(b)) ^ `AES_GMUL_02(b))

`endif
