`include "aes_defines.svh"

module aes_inv_sub_bytes (
    input                          enc,
    input  [`AES_BLOCK_SIZE-1 : 0] block,
    output [`AES_BLOCK_SIZE-1 : 0] new_block
);
    wire [`AES_BLOCK_SIZE-1 : 0] enc_block;
    wire [`AES_BLOCK_SIZE-1 : 0] dec_block;

    assign new_block = enc ? enc_block : dec_block;

    generate
        for (genvar i=0; i<`AES_BLOCK_SIZE/8; i++) begin
            aes_sbox aes_sbox_inst (
                .input_byte  (     block[8*i +: 8] ),
                .output_byte ( enc_block[8*i +: 8] )
            );

            aes_inv_sbox aes_inv_sbox_inst (
                .input_byte  (     block[8*i +: 8] ),
                .output_byte ( dec_block[8*i +: 8] )
            );
        end
    endgenerate
    
endmodule
