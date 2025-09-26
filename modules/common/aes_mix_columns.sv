`include "aes_defines.svh"

module aes_mix_columns (
    input  [`AES_BLOCK_SIZE-1 : 0] Input_block,
    output [`AES_BLOCK_SIZE-1 : 0] Output_block
);

assign Output_block[`AES_1ST_WORD] = gmul_matrix(Input_block[`AES_1ST_WORD]);
assign Output_block[`AES_2ND_WORD] = gmul_matrix(Input_block[`AES_2ND_WORD]);
assign Output_block[`AES_3RD_WORD] = gmul_matrix(Input_block[`AES_3RD_WORD]);
assign Output_block[`AES_4TH_WORD] = gmul_matrix(Input_block[`AES_4TH_WORD]);

function automatic logic [7 : 0] gmul_01(input logic [7 : 0] b);
    return b;
endfunction

function automatic logic [7 : 0] gmul_02(input logic [7 : 0] b);
    return b[7] ? (b<<1 ^ 8'h1b) : b<<1;
endfunction

function automatic logic [7 : 0] gmul_03(input logic [7 : 0] b);
    return gmul_02(b) ^ b;
endfunction

function automatic logic [`AES_WORD_SIZE-1 : 0] gmul_matrix(logic [`AES_WORD_SIZE-1 : 0] w);
    return {
        gmul_03(w[7 : 0]) ^ gmul_01(w[15 : 8]) ^ gmul_01(w[23 : 16]) ^ gmul_02(w[31 : 24]),
        gmul_01(w[7 : 0]) ^ gmul_01(w[15 : 8]) ^ gmul_02(w[23 : 16]) ^ gmul_03(w[31 : 24]),
        gmul_01(w[7 : 0]) ^ gmul_02(w[15 : 8]) ^ gmul_03(w[23 : 16]) ^ gmul_01(w[31 : 24]),
        gmul_02(w[7 : 0]) ^ gmul_03(w[15 : 8]) ^ gmul_01(w[23 : 16]) ^ gmul_01(w[31 : 24])
    };
endfunction

endmodule
