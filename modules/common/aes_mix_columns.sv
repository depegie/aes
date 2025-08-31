`include "aes_defines.svh"

module aes_mix_columns (
    input  [`AES_BLOCK_SIZE-1 : 0] block,
    output [`AES_BLOCK_SIZE-1 : 0] new_block
);
    assign new_block[`AES_1ST_WORD] = gmul_by_matrix(block[`AES_1ST_WORD]);
    assign new_block[`AES_2ND_WORD] = gmul_by_matrix(block[`AES_2ND_WORD]);
    assign new_block[`AES_3RD_WORD] = gmul_by_matrix(block[`AES_3RD_WORD]);
    assign new_block[`AES_4TH_WORD] = gmul_by_matrix(block[`AES_4TH_WORD]);

    function logic [7 : 0] gmul_by_2(input logic [7 : 0] b);
        return b[7] ? (b<<1 ^ 8'h1b) : b<<1;
    endfunction

    function logic [7 : 0] gmul_by_3(input logic [7 : 0] b);
        return gmul_by_2(b) ^ b;
    endfunction

    function logic [`AES_WORD_SIZE-1 : 0] gmul_by_matrix(input logic [`AES_WORD_SIZE-1 : 0] w);
        return {
            gmul_by_3(w[7 : 0]) ^           w[15 : 8]  ^           w[23 : 16]  ^ gmul_by_2(w[31 : 24]),
                      w[7 : 0]  ^           w[15 : 8]  ^ gmul_by_2(w[23 : 16]) ^ gmul_by_3(w[31 : 24]),
                      w[7 : 0]  ^ gmul_by_2(w[15 : 8]) ^ gmul_by_3(w[23 : 16]) ^           w[31 : 24],
            gmul_by_2(w[7 : 0]) ^ gmul_by_3(w[15 : 8]) ^           w[23 : 16]  ^           w[31 : 24]
        };
    endfunction

endmodule
