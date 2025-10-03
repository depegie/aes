package tb_pkg;
    real CLK_PERIOD = 5;

    typedef struct {
        int         id;
        logic       user;
        logic [7:0] data [$];
    } packet_t;

endpackage
