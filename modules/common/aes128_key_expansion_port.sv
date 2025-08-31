`include "aes_defines.svh"

module aes128_key_expansion_port (
    input  [int'($ceil($clog2(`AES128_ROUNDS_NUM)))-1 : 0] round_num,
    input                         [`AES128_KEY_SIZE-1 : 0] key,
    output                        [`AES128_KEY_SIZE-1 : 0] new_key
);
    reg  [`AES_WORD_SIZE-1 : 0] rcon;
    wire [`AES_WORD_SIZE-1 : 0] after_rotword;
    wire [`AES_WORD_SIZE-1 : 0] after_subword;
    wire [`AES_WORD_SIZE-1 : 0] after_rcon;

    always_comb
        case (round_num)
            1:       rcon = `AES_RCON_01;
            2:       rcon = `AES_RCON_02;
            3:       rcon = `AES_RCON_03;
            4:       rcon = `AES_RCON_04;
            5:       rcon = `AES_RCON_05;
            6:       rcon = `AES_RCON_06;
            7:       rcon = `AES_RCON_07;
            8:       rcon = `AES_RCON_08;
            9:       rcon = `AES_RCON_09;
            10:      rcon = `AES_RCON_10;
            default: rcon = 32'h0;
        endcase

    assign after_rotword = (key[`AES_4TH_WORD] >> 8) | (key[`AES_4TH_WORD] << `AES_WORD_SIZE-8);

    generate
        for (genvar i=0; i<`AES_WORD_SIZE/8; i++)
            aes_sbox aes_sbox_inst(after_rotword[8*i +: 8], after_subword[8*i +: 8]);
    endgenerate

    assign after_rcon = after_subword ^ rcon;

    assign new_key[`AES_1ST_WORD] = key[`AES_1ST_WORD] ^ after_rcon;
    assign new_key[`AES_2ND_WORD] = key[`AES_2ND_WORD] ^ new_key[`AES_1ST_WORD];
    assign new_key[`AES_3RD_WORD] = key[`AES_3RD_WORD] ^ new_key[`AES_2ND_WORD];
    assign new_key[`AES_4TH_WORD] = key[`AES_4TH_WORD] ^ new_key[`AES_3RD_WORD];
    
endmodule
