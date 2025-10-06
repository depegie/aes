interface axis_if #(
    parameter int TDATA_WIDTH=64
)(
    input logic clk
);
    logic                       tvalid;
    logic                       tready;
    logic   [TDATA_WIDTH-1 : 0] tdata;
    logic [TDATA_WIDTH/8-1 : 0] tkeep;
    logic                       tlast;
    logic                       tuser;

    modport master (
        input tready,
        output tvalid, tdata, tkeep, tlast, tuser
    );

    modport slave (
        input tvalid, tdata, tkeep, tlast, tuser,
        output tready
    );

    clocking cb @(posedge clk);
        inout tvalid, tready, tdata, tkeep, tlast, tuser;
    endclocking

endinterface
