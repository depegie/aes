`include "aes_defines.svh"

module aes_shift_rows (
    input  [`AES_BLOCK_SIZE-1 : 0] block,
    output [`AES_BLOCK_SIZE-1 : 0] new_block
);
    assign new_block = {
        block[8*11 +: 8], block[8* 6 +: 8], block[8* 1 +: 8], block[8*12 +: 8],
        block[8* 7 +: 8], block[8* 2 +: 8], block[8*13 +: 8], block[8* 8 +: 8],
        block[8* 3 +: 8], block[8*14 +: 8], block[8* 9 +: 8], block[8* 4 +: 8],
        block[8*15 +: 8], block[8*10 +: 8], block[8* 5 +: 8], block[8* 0 +: 8]
    };

endmodule
