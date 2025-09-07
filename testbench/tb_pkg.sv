package tb_pkg;
    int CLK_PERIOD = 5;

    typedef struct {
        int         id;
        logic       user;
        logic [7:0] data [$];
    } packet_t;

endpackage
