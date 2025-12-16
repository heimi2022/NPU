`timescale 1ns/1ns

`define clk_period 20

module AXI4_master_tb;


    // 输入信号
    reg    [32 - 1 : 0]         w_target_slave_base_addr_i  ;   
    reg    [16 - 1 : 0]         w_total_byte_num_i          ;   
    reg                         w_start_i                   ;   
    reg    [32 - 1 : 0]         w_data_i                    ;   
    reg                         w_data_valid_i              ;   
    // 输出信号
    wire                        w_busy_o                    ;   
    wire    [32 - 1 : 0]        w_sram_addr_o               ;   
    wire                        w_sram_data_request_o       ;   
    wire                        w_error_o                   ;   
    // axi read control interface
    // 输入信号
    reg    [32 - 1 : 0]         r_target_slave_base_addr_i  ;   
    reg    [16 - 1 : 0]         r_total_byte_num_i          ;   
    reg                         r_start_i                   ;   
    // 输出信号
    wire                        r_busy_o                    ;   
    wire    [32 - 1 : 0]        r_sram_addr_o               ;   
    wire                        r_sram_data_valid_o         ;   
    wire    [32 - 1 : 0]        r_sram_data_o               ;   
    wire                        r_error_o                   ;

always @(posedge clk_ddrmc or negedge axi_rstn) begin
    if(!axi_rstn)
        w_data_i <= 1'd0;
    else begin
        if(w_sram_data_request_o)
            w_data_i <= w_sram_addr_o;
        else
            w_data_i <= w_data_i;
    end
end

always @(posedge clk_ddrmc or negedge axi_rstn) begin
    if(!axi_rstn)
        w_data_valid_i <= 1'd0;
    else begin
        if(w_sram_data_request_o)
            w_data_valid_i <= 1'b1;
        else
            w_data_valid_i <= 1'b0;
    end
end

initial begin
    w_target_slave_base_addr_i = 32'h0000_0000;
    w_total_byte_num_i         = 16'd0;
    w_start_i                  = 1'b0;
    r_target_slave_base_addr_i = 32'h0000_0000;
    r_total_byte_num_i         = 16'd0;
    r_start_i                  = 1'b0;
    #(simulation_cycle * 10) ;
    w_target_slave_base_addr_i = 32'h0000_0000;
    w_total_byte_num_i         = 16'd4096;
    w_start_i                  = 1'b1;
    #(simulation_cycle) ;
    w_start_i                  = 1'b0;
    #20us ;
    $finish;
end

AXI4_master # (
    .TRAN_BYTE_NUM_WIDTH(16),   // 传输总字节数位宽
    .SRAM_ADDR_WIDTH    (32),   // sram 目标基地址位宽
    .M_AXI_ID_WIDTH	    (14),
    .M_AXI_ADDR_WIDTH	(32),
    .M_AXI_DATA_WIDTH	(32),
    .M_AXI_AWUSER_WIDTH	(0),
    .M_AXI_ARUSER_WIDTH	(0),
    .M_AXI_WUSER_WIDTH	(0),
    .M_AXI_RUSER_WIDTH	(0),
    .M_AXI_BUSER_WIDTH	(0)             
)u_AXI4_master(
// 时钟复位
    .clk  (clk_ddrmc    ),
    .rst_n(axi_rstn     ),
// axi write control interface

    .w_target_slave_base_addr_i(w_target_slave_base_addr_i),  
    .w_total_byte_num_i        (w_total_byte_num_i        ),  
    .w_start_i                 (w_start_i                 ),  
    .w_data_i                  (w_data_i                  ),  
    .w_data_valid_i            (w_data_valid_i            ),  

    .w_busy_o             (w_busy_o             ),  
    .w_sram_addr_o        (w_sram_addr_o        ),  
    .w_sram_data_request_o(w_sram_data_request_o),  
    .w_error_o            (w_error_o            ),  
// axi read control interface

    .r_target_slave_base_addr_i(r_target_slave_base_addr_i),  
    .r_total_byte_num_i        (r_total_byte_num_i        ),  
    .r_start_i                 (r_start_i                 ),  

    .r_busy_o           (r_busy_o           ),   
    .r_sram_addr_o      (r_sram_addr_o      ),   
    .r_sram_data_valid_o(r_sram_data_valid_o),   
    .r_sram_data_o      (r_sram_data_o      ),   
    .r_error_o          (r_error_o          ),
// AXI4 Master Interface
    // AW 信号
    .m_axi_awid   (AWID_port7        ),
    .m_axi_awaddr (AWADDR_port7[31:0]),
    .m_axi_awlen  (AWLEN_port7       ),
    .m_axi_awsize (AWSIZE_port7      ),
    .m_axi_awburst(AWBURST_port7     ),
    .m_axi_awlock (                  ),
    .m_axi_awcache(                  ),
    .m_axi_awprot (                  ),
    .m_axi_awqos  (                  ),
    .m_axi_awuser (                  ),
    .m_axi_awvalid(AWVALID_port7     ),
    .m_axi_awready(AWREADY_port7     ),
    // W 信号
    .m_axi_wdata (WDATA_port7   ),
    .m_axi_wstrb (WSTRB_port7   ),
    .m_axi_wlast (WLAST_port7   ),
    .m_axi_wuser (              ),
    .m_axi_wvalid(WVALID_port7  ),
    .m_axi_wready(WREADY_port7  ),
    // B 信号
    .m_axi_bid   (BID_port7     ),
    .m_axi_bresp (BRESP_port7   ),
    .m_axi_buser (              ),
    .m_axi_bvalid(BVALID_port7  ),
    .m_axi_bready(BREADY_port7  ),
    // AR 信号
    .m_axi_arid   (ARID_port7        ),
    .m_axi_araddr (ARADDR_port7[31:0]),
    .m_axi_arlen  (ARLEN_port7       ),
    .m_axi_arsize (ARSIZE_port7      ),
    .m_axi_arburst(ARBURST_port7     ),
    .m_axi_arlock (                  ),
    .m_axi_arcache(                  ),
    .m_axi_arprot (                  ),
    .m_axi_arqos  (                  ),
    .m_axi_aruser (                  ),
    .m_axi_arvalid(ARVALID_port7     ),
    .m_axi_arready(ARREADY_port7     ),
    // R 信号
    .m_axi_rid   (RID_port7     ),
    .m_axi_rdata (RDATA_port7   ),
    .m_axi_rresp (RRESP_port7   ),
    .m_axi_rlast (RLAST_port7   ),
    .m_axi_ruser (              ),
    .m_axi_rvalid(RVALID_port7  ),
    .m_axi_rready(RREADY_port7  ) 
);





endmodule



