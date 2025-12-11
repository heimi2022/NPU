`timescale 1ns/1ns

`define clk_period 20

module AXI4_master_tb;

	
AXI4_master # (
    .C_M00_AXI_TARGET_SLAVE_BASE_ADDR   (),
    .C_M00_AXI_BURST_LEN	            (),
    .C_M00_AXI_ID_WIDTH	                (),
    .C_M00_AXI_ADDR_WIDTH	            (),
    .C_M00_AXI_DATA_WIDTH	            (),
    .C_M00_AXI_AWUSER_WIDTH	            (),
    .C_M00_AXI_ARUSER_WIDTH	            (),
    .C_M00_AXI_WUSER_WIDTH	            (),
    .C_M00_AXI_RUSER_WIDTH	            (),
    .C_M00_AXI_BUSER_WIDTH	            ()             
)u_AXI4_master(
    .m00_axi_init_axi_txn(),
    .m00_axi_txn_done    (),
    .m00_axi_error       (),
    .m00_axi_aclk        (),
    .m00_axi_aresetn     (),
    .m00_axi_awid        (),
    .m00_axi_awaddr      (),
    .m00_axi_awlen       (),
    .m00_axi_awsize      (),
    .m00_axi_awburst     (),
    .m00_axi_awlock      (),
    .m00_axi_awcache     (),
    .m00_axi_awprot      (),
    .m00_axi_awqos       (),
    .m00_axi_awuser      (),
    .m00_axi_awvalid     (),
    .m00_axi_awready     (),
    .m00_axi_wdata       (),
    .m00_axi_wstrb       (),
    .m00_axi_wlast       (),
    .m00_axi_wuser       (),
    .m00_axi_wvalid      (),
    .m00_axi_wready      (),
    .m00_axi_bid         (),
    .m00_axi_bresp       (),
    .m00_axi_buser       (),
    .m00_axi_bvalid      (),
    .m00_axi_bready      (),
    .m00_axi_arid        (),
    .m00_axi_araddr      (),
    .m00_axi_arlen       (),
    .m00_axi_arsize      (),
    .m00_axi_arburst     (),
    .m00_axi_arlock      (),
    .m00_axi_arcache     (),
    .m00_axi_arprot      (),
    .m00_axi_arqos       (),
    .m00_axi_aruser      (),
    .m00_axi_arvalid     (),
    .m00_axi_arready     (),
    .m00_axi_rid         (),
    .m00_axi_rdata       (),
    .m00_axi_rresp       (),
    .m00_axi_rlast       (),
    .m00_axi_ruser       (),
    .m00_axi_rvalid      (),
    .m00_axi_rready      () 
);
	
endmodule

`ifdef DDRMC_PORT7_EN

    .ACLK_port7                     (ACLK_port7                                 ), // input 
    .ARESETn_port7                  (ARESETn_port7                              ), // input 

    .AWURGENT_port7                 (AWURGENT_port7                             ), // input 
    .ARURGENT_port7                 (ARURGENT_port7                             ), // input 
    .awqos_urgent_port7             (awqos_urgent_port7[3:0]                    ), // input 
    .arqos_urgent_port7             (arqos_urgent_port7[3:0]                    ), // input 
    .CSYSREQ_port7                  (CSYSREQ_port7                              ), // input 
    .CSYSACK_port7                  (CSYSACK_port7                              ), // output
    .CACTIVE_port7                  (CACTIVE_port7                              ), // output

    .AWID_port7                     (AWID_port7[`AXI7_ID_WIDTH-1:0]             ), // input 
    .AWUSER_port7                   (4'h0                                       ), // input yang_new_add
    .AWADDR_port7                   (AWADDR_port7[`AXI7_ADDR_WIDTH-1:0]         ), // input 
    .AWLEN_port7                    (AWLEN_port7[7:0]                           ), // input 
    .AWSIZE_port7                   (AWSIZE_port7[2:0]                          ), // input 
    .AWBURST_port7                  (AWBURST_port7[1:0]                         ), // input 
    .AWQOS_port7                    (AWQOS_port7[3:0]                           ), // input 
    .AWVALID_port7                  (AWVALID_port7                              ), // input 
    .AWLOCK_port7                   (1'b0                                       ), // input yang_new_add
    .AWREADY_port7                  (AWREADY_port7                              ), // output

    .WDATA_port7                    (WDATA_port7[`AXI7_DATA_WIDTH-1:0]          ), // input 
    .WSTRB_port7                    (WSTRB_port7[`AXI7_STRB_WIDTH-1:0]          ), // input 
    .WLAST_port7                    (WLAST_port7                                ), // input 
    .WVALID_port7                   (WVALID_port7                               ), // input 
    .WREADY_port7                   (WREADY_port7                               ), // output

    .BID_port7                      (BID_port7[`AXI7_ID_WIDTH-1:0]              ), // output
    .BUSER_port7                    (                                           ), // output yang_new_add
    .BRESP_port7                    (BRESP_port7[1:0]                           ), // output
    .BREADY_port7                   (BREADY_port7                               ), // input 
    .BVALID_port7                   (BVALID_port7                               ), // output

    .ARID_port7                     (ARID_port7[`AXI7_ID_WIDTH-1:0]             ), // input 
    .ARUSER_port7                   (4'h0                                       ), // input yang_new_add
    .ARADDR_port7                   (ARADDR_port7[`AXI7_ADDR_WIDTH-1:0]         ), // input 
    .ARLEN_port7                    (ARLEN_port7[7:0]                           ), // input 
    .ARSIZE_port7                   (ARSIZE_port7[2:0]                          ), // input 
    .ARBURST_port7                  (ARBURST_port7[1:0]                         ), // input 
    .ARQOS_port7                    (ARQOS_port7[3:0]                           ), // input 
    .ARVALID_port7                  (ARVALID_port7                              ), // input 
    .ARLOCK_port7                   (1'b0                                       ), // input yang_new_add
    .ARREADY_port7                  (ARREADY_port7                              ), // output

    .RID_port7                      (RID_port7[`AXI7_ID_WIDTH-1:0]              ), // output
    .RUSER_port7                    (                                           ), // output yang_new_add
    .RDATA_port7                    (RDATA_port7[`AXI7_DATA_WIDTH-1:0]          ), // output
    .RRESP_port7                    (RRESP_port7[1:0]                           ), // output
    .RLAST_port7                    (RLAST_port7                                ), // output
    .RREADY_port7                   (RREADY_port7                               ), // input 
    .RVALID_port7                   (RVALID_port7                               ), // output

`endif