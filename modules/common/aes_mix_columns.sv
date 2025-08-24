`include "aes_defines.svh"

module aes_mix_columns (
    input  [`AES_BLOCK_SIZE-1 : 0] state,
    output [`AES_BLOCK_SIZE-1 : 0] new_state
);
    assign new_state[`AES_1ST_WORD] = mul_by_matrix(state[`AES_1ST_WORD]);
    assign new_state[`AES_2ND_WORD] = mul_by_matrix(state[`AES_2ND_WORD]);
    assign new_state[`AES_3RD_WORD] = mul_by_matrix(state[`AES_3RD_WORD]);
    assign new_state[`AES_4TH_WORD] = mul_by_matrix(state[`AES_4TH_WORD]);

    function logic [7 : 0] mul2(input logic [7 : 0] b);
        return (b << 1) ^ (8'h1b & {8{b[7]}});
    endfunction

    function logic [7 : 0] mul3(input logic [7 : 0] b);
        return mul2(b) ^ b;
    endfunction

    function logic [`AES_WORD_SIZE-1 : 0] mul_by_matrix(input logic [`AES_WORD_SIZE-1 : 0] w);
        return {
            mul3(w[7 : 0]) ^      w[15 : 8]  ^      w[23 : 16]  ^ mul2(w[31 : 24]),
                 w[7 : 0]  ^      w[15 : 8]  ^ mul2(w[23 : 16]) ^ mul3(w[31 : 24]),
                 w[7 : 0]  ^ mul2(w[15 : 8]) ^ mul3(w[23 : 16]) ^      w[31 : 24],
            mul2(w[7 : 0]) ^ mul3(w[15 : 8]) ^      w[23 : 16]  ^      w[31 : 24]
        };
    endfunction

endmodule
