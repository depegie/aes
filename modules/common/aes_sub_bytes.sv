`include "aes_defines.svh"

module aes_sub_bytes (
    input  [`AES_BLOCK_SIZE-1 : 0] state,
    output [`AES_BLOCK_SIZE-1 : 0] new_state
);
    generate
        for (genvar i=0; i<16; i++) begin
            aes_sbox aes_sbox_inst (
                .i_byte (     state[8*i +: 8] ),
                .o_byte ( new_state[8*i +: 8] )
            );
        end
    endgenerate
    
endmodule
