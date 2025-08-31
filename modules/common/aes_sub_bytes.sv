`include "aes_defines.svh"

module aes_sub_bytes (
    input  [`AES_BLOCK_SIZE-1 : 0] block,
    output [`AES_BLOCK_SIZE-1 : 0] new_block
);
    generate
        for (genvar i=0; i<`AES_BLOCK_SIZE/8; i++) begin
            aes_sbox aes_sbox_inst(block[8*i +: 8], new_block[8*i +: 8]);
        end
    endgenerate
    
endmodule
