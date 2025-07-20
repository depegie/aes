package tb_pkg;
    `define CLK_PERIOD 'd5

    `define S_AXIS_TDATA_WIDTH 'd32
    `define M_AXIS_TDATA_WIDTH 'd32

    `define S_AXIS_DELAY 'd0
    `define M_AXIS_DELAY 'd0

    typedef struct {
        int         id;
        logic [7:0] data [$];
    } packet_t;

endpackage
