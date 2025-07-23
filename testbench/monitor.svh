`ifndef MONITOR_SVH
`define MONITOR_SVH

class monitor #(int TDATA_WIDTH=`M_AXIS_TDATA_WIDTH, int TRANS_DELAY=`M_AXIS_TRANS_DELAY);
    virtual axis_if #(TDATA_WIDTH) axis;
    mailbox #(packet_t)            mbx;
    event                          receive_ev;
    event                          finish_ev;

    function new(ref mailbox #(packet_t) mbx, ref event receive_ev, ref event finish_ev);
        this.mbx        = mbx;
        this.receive_ev = receive_ev;
        this.finish_ev  = finish_ev;
    endfunction

    function void init();
        this.axis.tready = 1'b1;
    endfunction

    task run();
        bit      stimulus_done = 1'b0;
        packet_t packet;
        
        packet.id   = 0;
        packet.data = '{};

        fork
            forever begin
                // if (stimulus_done) begin
                //     break;
                // end

                // $display("[Monitor] (%0dns) M_axis_valid=%b M_axis_tready=%b", unsigned'($time), this.axis.cb.tvalid, this.axis.cb.tready);
                if (this.axis.cb.tvalid && this.axis.cb.tready) begin
                    for (int b=0; b<TDATA_WIDTH/8; b++) begin
                        if (this.axis.cb.tkeep[b]) begin
                            packet.data.push_back(this.axis.cb.tdata[8*b +: 8]);
                        end
                    end

                    // $display("[Monitor] (%0dns) M_axis_tlast=%b", unsigned'($time), this.axis.cb.tlast);
                    if (this.axis.cb.tlast) begin
                        ->this.receive_ev;
                        // foreach (packet.data[i]) $display("%h", packet.data[i]);
                        // this.mbx.put(packet);
                        packet.id++;
                        packet.data = '{};
                    end
                end

                @(this.axis.cb);
            end
            // begin
            //     wait(this.finish_ev.triggered);
            //     stimulus_done = 1'b1;
            // end
        join

    endtask
endclass

`endif
