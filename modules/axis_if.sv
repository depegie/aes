interface axis_if #(
    parameter int TDATA_WIDTH=32
)(
    input bit clk,
    input bit rst
);
    logic                       tvalid;
    logic                       tready;
    logic   [TDATA_WIDTH-1 : 0] tdata;
    logic [TDATA_WIDTH/8-1 : 0] tkeep;
    logic                       tlast;

    modport master (
        input tready,
        output tvalid, tdata, tkeep, tlast
    );

    modport slave (
        input tvalid, tdata, tkeep, tlast, 
        output tready
    );

    clocking cb @(posedge clk);
        inout tvalid, tready, tdata, tkeep, tlast;
    endclocking

endinterface
