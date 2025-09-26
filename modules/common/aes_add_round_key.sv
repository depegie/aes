`include "aes_defines.svh"

module aes_add_round_key (
    input  [`AES_BLOCK_SIZE-1 : 0] Input_block,
    input  [`AES_BLOCK_SIZE-1 : 0] Round_key,
    output [`AES_BLOCK_SIZE-1 : 0] Output_block
);

assign Output_block = Input_block ^ Round_key;
    
endmodule
