`include "aes_defines.svh"

module aes128_key_expansion_param #(
    parameter int ROUND_NUM = 1
)(
    input  [`AES128_KEY_SIZE-1 : 0] key,
    output [`AES128_KEY_SIZE-1 : 0] new_key
);
    wire [`AES_WORD_SIZE-1 : 0] rcon;
    generate
        case (ROUND_NUM)
            1:  assign rcon = `AES_RCON_01;
            2:  assign rcon = `AES_RCON_02;
            3:  assign rcon = `AES_RCON_03;
            4:  assign rcon = `AES_RCON_04;
            5:  assign rcon = `AES_RCON_05;
            6:  assign rcon = `AES_RCON_06;
            7:  assign rcon = `AES_RCON_07;
            8:  assign rcon = `AES_RCON_08;
            9:  assign rcon = `AES_RCON_09;
            10: assign rcon = `AES_RCON_10;
        endcase
    endgenerate

    wire [`AES_WORD_SIZE-1 : 0] after_rotword;
    wire [`AES_WORD_SIZE-1 : 0] after_subword;
    wire [`AES_WORD_SIZE-1 : 0] after_rcon;

    assign after_rotword = (key[`AES_4TH_WORD] >> 8) | (key[`AES_4TH_WORD] << `AES_WORD_SIZE-8);

    generate
        for (genvar i=0; i<`AES_WORD_SIZE/8; i++)
            aes_sbox aes_sbox_inst(after_rotword[8*i +: 8], after_subword[8*i +: 8]);
    endgenerate

    assign after_rcon = after_subword ^ rcon;

    assign new_key[`AES_1ST_WORD] = key[`AES_1ST_WORD] ^ after_rcon;
    assign new_key[`AES_2ND_WORD] = key[`AES_2ND_WORD] ^ new_key[`AES_1ST_WORD];
    assign new_key[`AES_3RD_WORD] = key[`AES_3RD_WORD] ^ new_key[`AES_2ND_WORD];
    assign new_key[`AES_4TH_WORD] = key[`AES_4TH_WORD] ^ new_key[`AES_3RD_WORD];

endmodule
