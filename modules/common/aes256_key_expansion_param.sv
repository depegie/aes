`include "aes_defines.svh"

module aes256_key_expansion_param #(
    parameter int ROUND_NUMBER = 0
)(
    input  [`AES_256_KEY_LENGTH-1 : 0] Input_key,
    output     [`AES_BLOCK_SIZE-1 : 0] Output_key
);
    generate
        if (ROUND_NUMBER % 2 == 0) begin
            wire [`AES_WORD_SIZE-1 : 0] rcon;
            wire [`AES_WORD_SIZE-1 : 0] after_rotword;
            wire [`AES_WORD_SIZE-1 : 0] after_subword;
            wire [`AES_WORD_SIZE-1 : 0] after_rcon;

            case (ROUND_NUMBER)
                2:  assign rcon = `AES_RCON_01;
                4:  assign rcon = `AES_RCON_02;
                6:  assign rcon = `AES_RCON_03;
                8:  assign rcon = `AES_RCON_04;
                10: assign rcon = `AES_RCON_05;
                12: assign rcon = `AES_RCON_06;
                14: assign rcon = `AES_RCON_07;
            endcase

            assign after_rotword = (Input_key[`AES_8TH_WORD] >> 8) | (Input_key[`AES_8TH_WORD] << `AES_WORD_SIZE-8);
            
            for (genvar i=0; i<`AES_WORD_SIZE/8; i++)
                aes_sbox aes_sbox_inst(after_rotword[8*i +: 8], after_subword[8*i +: 8]);

            assign after_rcon = after_subword ^ rcon;

            assign Output_key[`AES_1ST_WORD] = Input_key[`AES_1ST_WORD] ^ after_rcon;
            assign Output_key[`AES_2ND_WORD] = Input_key[`AES_2ND_WORD] ^ Output_key[`AES_1ST_WORD];
            assign Output_key[`AES_3RD_WORD] = Input_key[`AES_3RD_WORD] ^ Output_key[`AES_2ND_WORD];
            assign Output_key[`AES_4TH_WORD] = Input_key[`AES_4TH_WORD] ^ Output_key[`AES_3RD_WORD];
        end
        else begin
            wire [`AES_WORD_SIZE-1 : 0] before_subword;
            wire [`AES_WORD_SIZE-1 : 0] after_subword;

            assign before_subword = Input_key[`AES_8TH_WORD];

            for (genvar i=0; i<`AES_BLOCK_SIZE/`AES_WORD_SIZE; i++)
                aes_sbox aes_sbox_inst(before_subword[8*i +: 8], after_subword[8*i +: 8]);

            assign Output_key[`AES_1ST_WORD] = Input_key[`AES_1ST_WORD] ^ after_subword;
            assign Output_key[`AES_2ND_WORD] = Input_key[`AES_2ND_WORD] ^ Output_key[`AES_1ST_WORD];
            assign Output_key[`AES_3RD_WORD] = Input_key[`AES_3RD_WORD] ^ Output_key[`AES_2ND_WORD];
            assign Output_key[`AES_4TH_WORD] = Input_key[`AES_4TH_WORD] ^ Output_key[`AES_3RD_WORD];
        end
    endgenerate

endmodule
