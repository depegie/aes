`include "aes_defines.svh"

module aes_mix_columns (
    input  [`AES_BLOCK_SIZE-1 : 0] block,
    output [`AES_BLOCK_SIZE-1 : 0] new_block
);
    assign new_block[`AES_1ST_WORD] = gmul_matrix(block[`AES_1ST_WORD]);
    assign new_block[`AES_2ND_WORD] = gmul_matrix(block[`AES_2ND_WORD]);
    assign new_block[`AES_3RD_WORD] = gmul_matrix(block[`AES_3RD_WORD]);
    assign new_block[`AES_4TH_WORD] = gmul_matrix(block[`AES_4TH_WORD]);

    function automatic logic [`AES_WORD_SIZE-1 : 0] gmul_matrix(logic [`AES_WORD_SIZE-1 : 0] w);
        logic [7 : 0] b0 = w[7 : 0];
        logic [7 : 0] b1 = w[15 : 8];
        logic [7 : 0] b2 = w[23 : 16];
        logic [7 : 0] b3 = w[31 : 24];
        
        return {
            `AES_GMUL_03(b0) ^ `AES_GMUL_01(b1) ^ `AES_GMUL_01(b2) ^ `AES_GMUL_02(b3),
            `AES_GMUL_01(b0) ^ `AES_GMUL_01(b1) ^ `AES_GMUL_02(b2) ^ `AES_GMUL_03(b3),
            `AES_GMUL_01(b0) ^ `AES_GMUL_02(b1) ^ `AES_GMUL_03(b2) ^ `AES_GMUL_01(b3),
            `AES_GMUL_02(b0) ^ `AES_GMUL_03(b1) ^ `AES_GMUL_01(b2) ^ `AES_GMUL_01(b3)
        };
    endfunction

endmodule
