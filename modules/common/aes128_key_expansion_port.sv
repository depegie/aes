`include "aes_defines.svh"

module aes128_key_expansion_port (
    input  [int'($ceil($clog2(`AES128_ROUNDS_NUM)))-1 : 0] round_num, // 1 - 10 
    input                         [`AES128_KEY_SIZE-1 : 0] key,
    output                        [`AES128_KEY_SIZE-1 : 0] new_key
);
    reg [`AES_WORD_SIZE-1 : 0] rcon[`AES128_RCON_NUM] = '{
        `AES_RCON_01,
        `AES_RCON_02,
        `AES_RCON_03,
        `AES_RCON_04,
        `AES_RCON_05,
        `AES_RCON_06,
        `AES_RCON_07,
        `AES_RCON_08,
        `AES_RCON_09,
        `AES_RCON_10
    };
    wire [`AES_WORD_SIZE-1 : 0] after_rotword;
    wire [`AES_WORD_SIZE-1 : 0] after_subword;
    wire [`AES_WORD_SIZE-1 : 0] after_rcon;

    assign after_rotword = (key[`AES_4TH_WORD] >> 8) | (key[`AES_4TH_WORD] << `AES_WORD_SIZE-8);

    generate
        for (genvar i=0; i<`AES_WORD_SIZE/8; i++)
            aes_sbox aes_sbox_inst(after_rotword[8*i +: 8], after_subword[8*i +: 8]);
    endgenerate

    assign after_rcon = (|round_num) ? after_subword ^ rcon[round_num-1] : 32'h0;

    assign new_key[`AES_1ST_WORD] = (|round_num) ? key[`AES_1ST_WORD] ^ after_rcon             : 32'h0;
    assign new_key[`AES_2ND_WORD] = (|round_num) ? key[`AES_2ND_WORD] ^ new_key[`AES_1ST_WORD] : 32'h0;
    assign new_key[`AES_3RD_WORD] = (|round_num) ? key[`AES_3RD_WORD] ^ new_key[`AES_2ND_WORD] : 32'h0;
    assign new_key[`AES_4TH_WORD] = (|round_num) ? key[`AES_4TH_WORD] ^ new_key[`AES_3RD_WORD] : 32'h0;
    
endmodule
