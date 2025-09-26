`include "aes_defines.svh"

module aes_sub_bytes (
    input  [`AES_BLOCK_SIZE-1 : 0] Input_block,
    output [`AES_BLOCK_SIZE-1 : 0] Output_block
);

generate
    for (genvar i=0; i<`AES_BLOCK_SIZE/8; i++) begin
        aes_sbox aes_sbox_inst (
            .Input_byte  (  Input_block[8*i +: 8] ),
            .Output_byte ( Output_block[8*i +: 8] )
        );
    end
endgenerate
    
endmodule
