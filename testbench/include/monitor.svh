`ifndef MONITOR_SVH
`define MONITOR_SVH

import tb_pkg::*;

class monitor #(int TDATA_WIDTH, int TRANS_DELAY);
    virtual axis_if #(TDATA_WIDTH) axis;
    mailbox #(packet_t)            mbx;
    event                          receive_ev;
    event                          finish_ev;

    function new(ref mailbox #(packet_t) mbx,
                 ref event receive_ev,
                 ref event finish_ev);

        this.mbx        = mbx;
        this.receive_ev = receive_ev;
        this.finish_ev  = finish_ev;
    endfunction

    function void init();
        if (TRANS_DELAY > 0) this.axis.tready = 1'b0;
        else                 this.axis.tready = 1'b1;
    endfunction

    task run();
        packet_t packet;
        
        packet.id   = 0;
        packet.data = '{};

        fork
            forever begin
                @(this.axis.cb);
                if (this.axis.cb.tvalid) begin
                    if (TRANS_DELAY > 0) begin
                        repeat (TRANS_DELAY-1) @(this.axis.cb);
                        this.axis.tready = 1'b1;
                        
                        @(this.axis.cb);
                    end
                    
                    for (int b=0; b<TDATA_WIDTH/8; b++) begin
                        if (this.axis.cb.tkeep[b]) begin
                            packet.data.push_back(this.axis.cb.tdata[8*b +: 8]);
                        end
                    end

                    if (this.axis.cb.tlast) begin
                        ->this.receive_ev;
                        this.mbx.put(packet);
                        
                        $write("[Monitor]    Time: %8dns, id: %3d, data: ", unsigned'($time), packet.id);
                        foreach (packet.data[i]) $write("%2h", packet.data[i]);
                        $write("\n");
                        
                        packet.id++;
                        packet.data = '{};
                    end
                    if (TRANS_DELAY > 0) this.axis.tready = 1'b0;
                end
            end
            begin
                wait(this.finish_ev.triggered);
            end
        join_any
        disable fork;

    endtask
endclass

`endif
