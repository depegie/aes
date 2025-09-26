`include "aes_defines.svh"

module aes256_key_expansion_port (
    input        [int'($ceil($clog2(`AES256_NUMBER_OF_ROUNDS)))-1 : 0] Round_number,
    input                                   [`AES256_KEY_LENGTH-1 : 0] Input_key,
    output logic                               [`AES_BLOCK_SIZE-1 : 0] Output_key
);

logic [`AES_WORD_SIZE-1 : 0] rcon;

logic [`AES_WORD_SIZE-1 : 0] before_rotword;
logic [`AES_WORD_SIZE-1 : 0] before_subword;
logic [`AES_WORD_SIZE-1 : 0] before_rcon;

logic [`AES_WORD_SIZE-1 : 0] after_rotword;
logic [`AES_WORD_SIZE-1 : 0] after_subword;
logic [`AES_WORD_SIZE-1 : 0] after_rcon;

always_comb begin
    if (Round_number % 2 == 0) begin
        before_rotword = Input_key[`AES_8TH_WORD];
        before_subword = after_rotword;
        before_rcon    = after_subword;

        Output_key[`AES_1ST_WORD] = Input_key[`AES_1ST_WORD] ^ after_rcon;
        Output_key[`AES_2ND_WORD] = Input_key[`AES_2ND_WORD] ^ Output_key[`AES_1ST_WORD];
        Output_key[`AES_3RD_WORD] = Input_key[`AES_3RD_WORD] ^ Output_key[`AES_2ND_WORD];
        Output_key[`AES_4TH_WORD] = Input_key[`AES_4TH_WORD] ^ Output_key[`AES_3RD_WORD];
    end
    else begin
        before_rotword = 0;
        before_subword = Input_key[`AES_8TH_WORD];
        before_rcon = 0;

        Output_key[`AES_1ST_WORD] = Input_key[`AES_1ST_WORD] ^ after_subword;
        Output_key[`AES_2ND_WORD] = Input_key[`AES_2ND_WORD] ^ Output_key[`AES_1ST_WORD];
        Output_key[`AES_3RD_WORD] = Input_key[`AES_3RD_WORD] ^ Output_key[`AES_2ND_WORD];
        Output_key[`AES_4TH_WORD] = Input_key[`AES_4TH_WORD] ^ Output_key[`AES_3RD_WORD];
    end
end

always_comb
    case (Round_number)
        2:       rcon = `AES_RCON_01;
        4:       rcon = `AES_RCON_02;
        6:       rcon = `AES_RCON_03;
        8:       rcon = `AES_RCON_04;
        10:      rcon = `AES_RCON_05;
        12:      rcon = `AES_RCON_06;
        14:      rcon = `AES_RCON_07;
        default: rcon = 32'h0;
    endcase

assign after_rotword = (before_rotword >> 8) | (before_rotword << `AES_WORD_SIZE-8);

generate
    for (genvar i=0; i<`AES_WORD_SIZE/8; i++)
        aes_sbox aes_sbox_inst (
            .Input_byte  ( before_subword[8*i +: 8] ),  
            .Output_byte (  after_subword[8*i +: 8] ) 
        );
endgenerate

assign after_rcon = before_rcon ^ rcon;

endmodule
