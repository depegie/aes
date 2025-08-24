`include "aes_defines.svh"

module aes128_key_expansion_param #(
    parameter int ROUND_NUM = 0
)(
    input  [`AES128_KEY_SIZE-1 : 0] key,
    output [`AES128_KEY_SIZE-1 : 0] new_key
);
    generate
        case (ROUND_NUM)
            1:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_01;
            2:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_02;
            3:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_03;
            4:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_04;
            5:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_05;
            6:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_06;
            7:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_07;
            8:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_08;
            9:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_09;
            10: localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_10;
        endcase
    endgenerate

    wire [`AES_WORD_SIZE-1 : 0] after_rotword;
    wire [`AES_WORD_SIZE-1 : 0] after_subword;
    wire [`AES_WORD_SIZE-1 : 0] after_rcon;

    assign after_rotword = (key[`AES_4TH_WORD] << 8) | (key[`AES_4TH_WORD] >> `AES_WORD_SIZE-8);

    generate
        for (genvar i=0; i<`AES_BLOCK_SIZE/`AES_WORD_SIZE; i++)
            aes_sbox aes_sbox_inst(after_rotword[8*i +: 8], after_subword[8*i +: 8]);
    endgenerate

    assign after_rcon = after_subword ^ RCON;

    assign new_key[`AES_1ST_WORD] = key[`AES_1ST_WORD] ^ after_rcon;
    assign new_key[`AES_2ND_WORD] = key[`AES_2ND_WORD] ^ new_key[`AES_1ST_WORD];
    assign new_key[`AES_3RD_WORD] = key[`AES_3RD_WORD] ^ new_key[`AES_2ND_WORD];
    assign new_key[`AES_4TH_WORD] = key[`AES_4TH_WORD] ^ new_key[`AES_3RD_WORD];

endmodule
