`include "aes_defines.svh"

module aes_add_round_key (
    input  [`AES_BLOCK_SIZE-1 : 0] state,
    input  [`AES_BLOCK_SIZE-1 : 0] key,
    output [`AES_BLOCK_SIZE-1 : 0] new_state
);
    assign new_state = state ^ key;
    
endmodule
