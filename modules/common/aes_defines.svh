`ifndef AES_DEFINES_SVH
`define AES_DEFINES_SVH

`define AES_128_NUMBER_OF_ROUNDS                10
`define AES_256_NUMBER_OF_ROUNDS                14

`define AES_BLOCK_SIZE                         128
`define AES_128_KEY_LENGTH                     128
`define AES_256_KEY_LENGTH                     256

`define AES_WORD_SIZE                           32
`define AES_1ST_WORD                          31:0
`define AES_2ND_WORD                         63:32
`define AES_3RD_WORD                         95:64
`define AES_4TH_WORD                        127:96
`define AES_8TH_WORD                       255:224

`define AES_RCON_01                   32'h00000001
`define AES_RCON_02                   32'h00000002
`define AES_RCON_03                   32'h00000004
`define AES_RCON_04                   32'h00000008
`define AES_RCON_05                   32'h00000010
`define AES_RCON_06                   32'h00000020
`define AES_RCON_07                   32'h00000040
`define AES_RCON_08                   32'h00000080
`define AES_RCON_09                   32'h0000001b
`define AES_RCON_10                   32'h00000036

`endif
