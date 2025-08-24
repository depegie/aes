package tb_pkg;
    `define AES128_ECB_ITER
    `define AES128_ECB_COMB
    `define AES128_ECB_PIPE
    `define AES256_ECB_PIPE
    `define AES256_CTR_PIPE

    `define S_AXIS_TDATA_WIDTH 'd32
    `define M_AXIS_TDATA_WIDTH 'd32

    `define S_AXIS_TRANS_DELAY 'd0
    `define M_AXIS_TRANS_DELAY 'd0

    typedef struct {
        int         id;
        logic [7:0] data [$];
    } packet_t;

endpackage
