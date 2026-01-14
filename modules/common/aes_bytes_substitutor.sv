`include "aes_defines.svh"

module aes_bytes_substitutor (
    input                          Encrypt,
    input  [`AES_BLOCK_SIZE-1 : 0] Input_block,
    output [`AES_BLOCK_SIZE-1 : 0] Output_block
);

logic [`AES_BLOCK_SIZE-1 : 0] enc_block;
logic [`AES_BLOCK_SIZE-1 : 0] dec_block;

assign Output_block = Encrypt ? enc_block : dec_block;

generate
    for (genvar i=0; i<`AES_BLOCK_SIZE/8; i++) begin
        aes_sbox aes_sbox_inst (
            .Input_byte  ( Input_block[8*i +: 8] ),
            .Output_byte (   enc_block[8*i +: 8] )
        );

        aes_inv_sbox aes_inv_sbox_inst (
            .Input_byte  ( Input_block[8*i +: 8] ),
            .Output_byte (   dec_block[8*i +: 8] )
        );
    end
endgenerate
    
endmodule
