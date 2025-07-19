`ifndef DRIVER_SVH
`define DRIVER_SVH

import tb_pkg::*;

class driver;
    virtual axis_if     axis;
    mailbox #(packet_t) mbx;
    event               finish_ev;

    function new(ref mailbox #(packet_t) mbx, ref event finish_ev);
        this.mbx       = mbx;
        this.finish_ev = finish_ev;
    endfunction

    function void init();
        this.axis.tvalid = 1'b0;
        this.axis.tdata = 'h0;
        this.axis.tkeep = 'b0;
        this.axis.tlast = 1'b0;
    endfunction

    task run();
        bit         stimulus_done = 1'b0;
        int         bytes_in_trans_num = 0;
        logic [7:0] pkt_byte = 8'h0;
        packet_t    packet;
        $display("Driver %t", $time);


        fork
            forever begin
                if (stimulus_done) begin
                    break;
                end

                this.mbx.get(packet);
                
                @(this.axis.cb);

                while (packet.data.size() > 0) begin
                    this.axis.tdata = 'h0;
                    this.axis.tkeep = 'b0;

                    if (packet.data.size() >= `TDATA_WIDTH/8) begin
                        bytes_in_trans_num = `TDATA_WIDTH/8;
                    end
                    else begin
                        bytes_in_trans_num = packet.data.size();
                    end

                    if (packet.data.size() <= `TDATA_WIDTH/8) begin
                        this.axis.tlast = 1'b1;
                    end
                    else begin
                        this.axis.tlast = 1'b0;
                    end

                    for (int i=0; i<bytes_in_trans_num; i++) begin
                        pkt_byte = packet.data.pop_front();

                        this.axis.tkeep[i] = 1'b1;
                        this.axis.tdata[8*i +: 8] = pkt_byte;
                    end

                    this.axis.tvalid = 1'b1;
                    @(this.axis.cb);
                    while (!this.axis.cb.tready) begin
                        @(this.axis.cb);
                    end
                end

                this.axis.tvalid = 1'b0;
            end
            
            begin
                wait(finish_ev.triggered);
                stimulus_done = 1'b1;
            end

        join

        $display("%d", this.mbx.num());

        $display("Driver finish");

    endtask

endclass

`endif
