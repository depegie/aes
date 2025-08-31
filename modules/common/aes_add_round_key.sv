`include "aes_defines.svh"

module aes_add_round_key (
    input  [`AES_BLOCK_SIZE-1 : 0] block,
    input  [`AES_BLOCK_SIZE-1 : 0] key,
    output [`AES_BLOCK_SIZE-1 : 0] new_block
);
    assign new_block = block ^ key;
    
endmodule
