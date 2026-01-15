`include "aes_defines.svh"

module aes_columns_mixer (
    input                          Encrypt,
    input  [`AES_BLOCK_SIZE-1 : 0] Input_block,
    output [`AES_BLOCK_SIZE-1 : 0] Output_block
);

logic [`AES_BLOCK_SIZE-1 : 0] enc_block;
logic [`AES_BLOCK_SIZE-1 : 0] dec_block;

assign Output_block = Encrypt ? enc_block : dec_block;

assign enc_block[`AES_1ST_WORD] = gmul_enc_matrix(Input_block[`AES_1ST_WORD]);
assign enc_block[`AES_2ND_WORD] = gmul_enc_matrix(Input_block[`AES_2ND_WORD]);
assign enc_block[`AES_3RD_WORD] = gmul_enc_matrix(Input_block[`AES_3RD_WORD]);
assign enc_block[`AES_4TH_WORD] = gmul_enc_matrix(Input_block[`AES_4TH_WORD]);

assign dec_block[`AES_1ST_WORD] = gmul_dec_matrix(Input_block[`AES_1ST_WORD]);
assign dec_block[`AES_2ND_WORD] = gmul_dec_matrix(Input_block[`AES_2ND_WORD]);
assign dec_block[`AES_3RD_WORD] = gmul_dec_matrix(Input_block[`AES_3RD_WORD]);
assign dec_block[`AES_4TH_WORD] = gmul_dec_matrix(Input_block[`AES_4TH_WORD]);

function automatic logic [7 : 0] x_times(input logic [7 : 0] b);
    return b[7] ? (b<<1 ^ 8'h1b) : b<<1;
endfunction

function automatic logic [7 : 0] gmul_02(input logic [7 : 0] b);
    return x_times(b);
endfunction

function automatic logic [7 : 0] gmul_03(input logic [7 : 0] b);
    return x_times(b) ^ b;
endfunction

function automatic logic [7 : 0] gmul_09(input logic [7 : 0] b);
    return x_times(x_times(x_times(b))) ^ b;
endfunction

function automatic logic [7 : 0] gmul_0B(input logic [7 : 0] b);
    return x_times(x_times(x_times(b))) ^ x_times(b) ^ b;
endfunction

function automatic logic [7 : 0] gmul_0D(input logic [7 : 0] b);
    return x_times(x_times(x_times(b))) ^ x_times(x_times(b)) ^ b;
endfunction

function automatic logic [7 : 0] gmul_0E(input logic [7 : 0] b);
    return x_times(x_times(x_times(b))) ^ x_times(x_times(b)) ^ x_times(b);
endfunction

function automatic logic [`AES_WORD_SIZE-1 : 0] gmul_enc_matrix(logic [`AES_WORD_SIZE-1 : 0] w);
    return {
        gmul_03(w[7 : 0]) ^         w[15 : 8]  ^         w[23 : 16]  ^ gmul_02(w[31 : 24]),
                w[7 : 0]  ^         w[15 : 8]  ^ gmul_02(w[23 : 16]) ^ gmul_03(w[31 : 24]),
                w[7 : 0]  ^ gmul_02(w[15 : 8]) ^ gmul_03(w[23 : 16]) ^         w[31 : 24] ,
        gmul_02(w[7 : 0]) ^ gmul_03(w[15 : 8]) ^         w[23 : 16]  ^         w[31 : 24] 
    };
endfunction
    
function automatic logic [`AES_WORD_SIZE-1 : 0] gmul_dec_matrix(logic [`AES_WORD_SIZE-1 : 0] w);
    return {
        gmul_0B(w[7 : 0]) ^ gmul_0D(w[15 : 8]) ^ gmul_09(w[23 : 16]) ^ gmul_0E(w[31 : 24]),
        gmul_0D(w[7 : 0]) ^ gmul_09(w[15 : 8]) ^ gmul_0E(w[23 : 16]) ^ gmul_0B(w[31 : 24]),
        gmul_09(w[7 : 0]) ^ gmul_0E(w[15 : 8]) ^ gmul_0B(w[23 : 16]) ^ gmul_0D(w[31 : 24]),
        gmul_0E(w[7 : 0]) ^ gmul_0B(w[15 : 8]) ^ gmul_0D(w[23 : 16]) ^ gmul_09(w[31 : 24])
    };
endfunction

endmodule
