`include "aes_defines.svh"

module aes_shift_rows (
    input  [`AES_BLOCK_SIZE-1 : 0] state,
    output [`AES_BLOCK_SIZE-1 : 0] new_state
);
    assign new_state = {
        state[8*11 +: 8], state[8* 6 +: 8], state[8* 1 +: 8], state[8*12 +: 8],
        state[8* 7 +: 8], state[8* 2 +: 8], state[8*13 +: 8], state[8* 8 +: 8],
        state[8* 3 +: 8], state[8*14 +: 8], state[8* 9 +: 8], state[8* 4 +: 8],
        state[8*15 +: 8], state[8*10 +: 8], state[8* 5 +: 8], state[8* 0 +: 8]
    };

endmodule
