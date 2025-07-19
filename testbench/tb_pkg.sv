package tb_pkg;
    `define TDATA_WIDTH 'd32
    `define CLK_PERIOD  'd5

    typedef struct {
        int         id;
        logic [7:0] data [$];
    } packet_t;

endpackage
