`include "aes_defines.svh"

module aes256_key_expansion_param #(
    parameter int ROUND_NUM = 0
)(
    input  [`AES256_KEY_SIZE/2-1 : 0] prev_halfkey,
    input  [`AES256_KEY_SIZE/2-1 : 0] halfkey,
    output [`AES256_KEY_SIZE/2-1 : 0] new_halfkey
);
    localparam bit ROUND_NUM_EVEN = (ROUND_NUM % 2) ? 1'b1 : 1'b0;

    generate
        if (ROUND_NUM_EVEN) begin
            generate
                case (ROUND_NUM/2)
                    1:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_01;
                    2:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_02;
                    3:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_03;
                    4:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_04;
                    5:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_05;
                    6:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_06;
                    7:  localparam bit [`AES_WORD_SIZE-1 : 0] RCON = `AES_RCON_07;
                endcase
            endgenerate

            wire [`AES_WORD_SIZE-1 : 0] after_rotword;
            wire [`AES_WORD_SIZE-1 : 0] after_subword;
            wire [`AES_WORD_SIZE-1 : 0] after_rcon;

            assign after_rotword = (halfkey[`AES_4TH_WORD] >> 8) | (halfkey[`AES_4TH_WORD] << `AES_WORD_SIZE-8);
            
            generate
                for (genvar i=0; i<`AES_WORD_SIZE/8; i++)
                    aes_sbox aes_sbox_inst(after_rotword[8*i +: 8], after_subword[8*i +: 8]);
            endgenerate

            assign after_rcon = after_subword ^ RCON;

            assign new_halfkey[`AES_1ST_WORD] = prev_halfkey[`AES_1ST_WORD] ^ after_rcon;
            assign new_halfkey[`AES_2ND_WORD] = prev_halfkey[`AES_2ND_WORD] ^ new_halfkey[`AES_1ST_WORD];
            assign new_halfkey[`AES_3RD_WORD] = prev_halfkey[`AES_3RD_WORD] ^ new_halfkey[`AES_2ND_WORD];
            assign new_halfkey[`AES_4TH_WORD] = prev_halfkey[`AES_4TH_WORD] ^ new_halfkey[`AES_3RD_WORD];
        end
        else begin
            wire [`AES_WORD_SIZE-1 : 0] before_subword;
            wire [`AES_WORD_SIZE-1 : 0] after_subword;

            assign before_subword = halfkey[`AES_4TH_WORD];

            generate
                for (genvar i=0; i<`AES_BLOCK_SIZE/`AES_WORD_SIZE; i++)
                    aes_sbox aes_sbox_inst(before_subword[8*i +: 8], after_subword[8*i +: 8]);
            endgenerate

            assign new_halfkey[`AES_1ST_WORD] = prev_halfkey[`AES_1ST_WORD] ^ after_subword;
            assign new_halfkey[`AES_2ND_WORD] = prev_halfkey[`AES_2ND_WORD] ^ new_halfkey[`AES_1ST_WORD];
            assign new_halfkey[`AES_3RD_WORD] = prev_halfkey[`AES_3RD_WORD] ^ new_halfkey[`AES_2ND_WORD];
            assign new_halfkey[`AES_4TH_WORD] = prev_halfkey[`AES_4TH_WORD] ^ new_halfkey[`AES_3RD_WORD];
        end
    endgenerate

endmodule
