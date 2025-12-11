`timescale 1 ns / 1 ps

module AXI4_master #
(
    parameter integer   TRAN_BYTE_NUM_WIDTH             = 16                    ,   // 传输总字节数位宽
    parameter integer   SRAM_ADDR_WIDTH                 = 32                    ,   // sram 目标基地址位宽
    parameter integer   M_AXI_ID_WIDTH	                = 1                     ,
    parameter integer   M_AXI_ADDR_WIDTH	            = 32                    ,
    parameter integer   M_AXI_DATA_WIDTH	            = 32                    ,
    parameter integer   M_AXI_AWUSER_WIDTH	            = 0                     ,
    parameter integer   M_AXI_ARUSER_WIDTH	            = 0                     ,
    parameter integer   M_AXI_WUSER_WIDTH	            = 0                     ,
    parameter integer   M_AXI_RUSER_WIDTH	            = 0                     ,
    parameter integer   M_AXI_BUSER_WIDTH	            = 0                                  
)(
// 时钟复位
    input   wire                                    clk                         ,
    input   wire                                    rst_n                       ,
// axi write control interface
    // 输入信号
    input   wire    [M_AXI_ADDR_WIDTH - 1 : 0]      w_target_slave_base_addr_i  ,   // 写基地址输入
    input   wire    [TRAN_BYTE_NUM_WIDTH - 1 : 0]   w_total_byte_num_i          ,   // 写传输总字节数输入
    input   wire                                    w_start_i                   ,   // 写启动信号输入
    input   wire    [M_AXI_DATA_WIDTH - 1 : 0]      w_data_i                    ,   // 写数据输入
    input   wire                                    w_data_valid_i              ,   // 写数据有效信号输入
    // 输出信号
    output  wire                                    w_busy_o                    ,   // AXI 写忙信号输出
    output  wire    [SRAM_ADDR_WIDTH - 1 : 0]       w_sram_addr_o               ,   // sram 地址输出
    output  wire                                    w_sram_data_request_o       ,   // sram 数据请求输出
    output  wire                                    w_error_o                   ,   // Asserts when ERROR is detected
// axi read control interface
    // 输入信号
    input   wire    [M_AXI_ADDR_WIDTH - 1 : 0]      r_target_slave_base_addr_i  ,   // 基地址输入
    input   wire    [TRAN_BYTE_NUM_WIDTH - 1 : 0]   r_total_byte_num_i          ,   // 传输总字节数输入
    input   wire                                    r_start_i                   ,   // 读启动信号输入
    // 输出信号
    output  wire                                    r_busy_o                    ,   // AXI 总线空闲 1有效
    output  wire    [SRAM_ADDR_WIDTH - 1 : 0]       r_sram_addr_o               ,   // sram 地址输出
    output  wire                                    r_sram_data_valid_o         ,   // sram 数据请求输出
    output  wire    [M_AXI_DATA_WIDTH - 1 : 0]      r_sram_data_o               ,   // sram 数据输出
    output  wire                                    r_error_o                   ,
// AXI4 Master Interface
    // AW 信号
    output  wire    [M_AXI_ID_WIDTH-1 : 0]          m_axi_awid                  ,
    output  wire    [M_AXI_ADDR_WIDTH-1 : 0]        m_axi_awaddr                ,
    output  wire    [7 : 0]                         m_axi_awlen                 ,
    output  wire    [2 : 0]                         m_axi_awsize                ,
    output  wire    [1 : 0]                         m_axi_awburst               ,
    output  wire                                    m_axi_awlock                ,
    output  wire    [3 : 0]                         m_axi_awcache               ,
    output  wire    [2 : 0]                         m_axi_awprot                ,
    output  wire    [3 : 0]                         m_axi_awqos                 ,
    output  wire    [M_AXI_AWUSER_WIDTH-1 : 0]      m_axi_awuser                ,
    output  wire                                    m_axi_awvalid               ,
    input   wire                                    m_axi_awready               ,
    // W 信号
    output  wire    [M_AXI_DATA_WIDTH-1 : 0]        m_axi_wdata                 ,
    output  wire    [M_AXI_DATA_WIDTH/8-1 : 0]      m_axi_wstrb                 ,
    output  wire                                    m_axi_wlast                 ,
    output  wire    [M_AXI_WUSER_WIDTH-1 : 0]       m_axi_wuser                 ,
    output  wire                                    m_axi_wvalid                ,
    input   wire                                    m_axi_wready                ,
    // B 信号
    input   wire    [M_AXI_ID_WIDTH-1 : 0]          m_axi_bid                   ,
    input   wire    [1 : 0]                         m_axi_bresp                 ,
    input   wire    [M_AXI_BUSER_WIDTH-1 : 0]       m_axi_buser                 ,
    input   wire                                    m_axi_bvalid                ,
    output  wire                                    m_axi_bready                ,
    // AR 信号
    output  wire    [M_AXI_ID_WIDTH-1 : 0]          m_axi_arid                  ,
    output  wire    [M_AXI_ADDR_WIDTH-1 : 0]        m_axi_araddr                ,
    output  wire    [7 : 0]                         m_axi_arlen                 ,
    output  wire    [2 : 0]                         m_axi_arsize                ,
    output  wire    [1 : 0]                         m_axi_arburst               ,
    output  wire                                    m_axi_arlock                ,
    output  wire    [3 : 0]                         m_axi_arcache               ,
    output  wire    [2 : 0]                         m_axi_arprot                ,
    output  wire    [3 : 0]                         m_axi_arqos                 ,
    output  wire    [M_AXI_ARUSER_WIDTH-1 : 0]      m_axi_aruser                ,
    output  wire                                    m_axi_arvalid               ,
    input   wire                                    m_axi_arready               ,
    // R 信号
    input   wire    [M_AXI_ID_WIDTH-1 : 0]          m_axi_rid                   ,
    input   wire    [M_AXI_DATA_WIDTH-1 : 0]        m_axi_rdata                 ,
    input   wire    [1 : 0]                         m_axi_rresp                 ,
    input   wire                                    m_axi_rlast                 ,
    input   wire    [M_AXI_RUSER_WIDTH-1 : 0]       m_axi_ruser                 ,
    input   wire                                    m_axi_rvalid                ,
    output  wire                                    m_axi_rready                 
);


    AXI4_write_ctrl #(
        .AXI_ID_WIDTH	                (M_AXI_ID_WIDTH             ),
        .AXI_ADDR_WIDTH	                (M_AXI_ADDR_WIDTH           ),
        .AXI_DATA_WIDTH	                (M_AXI_DATA_WIDTH           ),
        .AXI_AWUSER_WIDTH	            (M_AXI_AWUSER_WIDTH         ),
        .AXI_WUSER_WIDTH	            (M_AXI_WUSER_WIDTH          ),
        .AXI_BUSER_WIDTH	            (M_AXI_BUSER_WIDTH          ),
        .TRAN_BYTE_NUM_WIDTH            (TRAN_BYTE_NUM_WIDTH        ),  // 传输总字节数位宽
        .SRAM_ADDR_WIDTH                (SRAM_ADDR_WIDTH            )   // sram 目标基地址位宽
    )u_AXI4_write_ctrl(
        // 时钟复位
        .clk                            (clk                        ),
        .rst_n                          (rst_n                      ),
        // 外部输入信号
        .w_target_slave_base_addr_i     (w_target_slave_base_addr_i ),   // 写基地址输入
        .w_total_byte_num_i             (w_total_byte_num_i         ),   // 写传输总字节数输入
        .w_start_i                      (w_start_i                  ),   // 写启动信号输入
        .w_data_i                       (w_data_i                   ),   // 写数据输入
        .w_data_valid_i                 (w_data_valid_i             ),   // 写数据有效信号输入
        // 输出信号
        .w_busy_o                       (w_busy_o                   ),   // AXI 写忙信号输出
        .w_sram_addr_o                  (w_sram_addr_o              ),   // sram 地址输出
        .w_sram_data_request_o          (w_sram_data_request_o      ),   // sram 数据请求输出
        .w_error_o                      (w_error_o                  ),   // Asserts when ERROR is detected
        // AW 信号
        .M_AXI_AWID                     (m_axi_awid                 ),
        .M_AXI_AWADDR                   (m_axi_awaddr               ),
        .M_AXI_AWLEN                    (m_axi_awlen                ),
        .M_AXI_AWSIZE                   (m_axi_awsize               ),
        .M_AXI_AWBURST                  (m_axi_awburst              ),
        .M_AXI_AWLOCK                   (m_axi_awlock               ),
        .M_AXI_AWCACHE                  (m_axi_awcache              ),
        .M_AXI_AWPROT                   (m_axi_awprot               ),
        .M_AXI_AWQOS                    (m_axi_awqos                ),
        .M_AXI_AWUSER                   (m_axi_awuser               ),
        .M_AXI_AWVALID                  (m_axi_awvalid              ),
        .M_AXI_AWREADY                  (m_axi_awready              ),
        // W 信号
        .M_AXI_WDATA                    (m_axi_wdata                ),
        .M_AXI_WSTRB                    (m_axi_wstrb                ),
        .M_AXI_WLAST                    (m_axi_wlast                ),
        .M_AXI_WUSER                    (m_axi_wuser                ),
        .M_AXI_WVALID                   (m_axi_wvalid               ),
        .M_AXI_WREADY                   (m_axi_wready               ),
        // B 信号
        .M_AXI_BID                      (m_axi_bid                  ),
        .M_AXI_BRESP                    (m_axi_bresp                ),
        .M_AXI_BUSER                    (m_axi_buser                ),
        .M_AXI_BVALID                   (m_axi_bvalid               ),
        .M_AXI_BREADY                   (m_axi_bready               ) 
    );


    AXI4_read_ctrl #(
        .AXI_ID_WIDTH	                (M_AXI_ID_WIDTH             ),
        .AXI_ADDR_WIDTH	                (M_AXI_ADDR_WIDTH           ),
        .AXI_DATA_WIDTH	                (M_AXI_DATA_WIDTH           ),
        .AXI_ARUSER_WIDTH	            (M_AXI_ARUSER_WIDTH         ),
        .AXI_RUSER_WIDTH	            (M_AXI_RUSER_WIDTH          ),
        .TRAN_BYTE_NUM_WIDTH            (TRAN_BYTE_NUM_WIDTH        ),   // 传输总字节数位宽
        .SRAM_ADDR_WIDTH                (SRAM_ADDR_WIDTH            )    // sram 目标基地址位宽
    )u_AXI4_read_ctrl(
        // 时钟复位
        .clk                            (clk                        ),
        .rst_n                          (rst_n                      ),
        // 输入信号
        .r_target_slave_base_addr_i     (r_target_slave_base_addr_i ),   // 基地址输入
        .r_total_byte_num_i             (r_total_byte_num_i         ),   // 传输总字节数输入
        .r_start_i                      (r_start_i                  ),   // 读启动信号输入
        // 输出信号
        .r_busy_o                       (r_busy_o                   ),   // AXI 总线空闲 1有效
        .r_sram_addr_o                  (r_sram_addr_o              ),   // sram 地址输出
        .r_sram_data_valid_o            (r_sram_data_valid_o        ),   // sram 数据请求输出
        .r_sram_data_o                  (r_sram_data_o              ),   // sram 数据输出
        .r_error_o                      (r_error_o                  ),
        // AR 信号
        .M_AXI_ARID                     (m_axi_arid                 ),
        .M_AXI_ARADDR                   (m_axi_araddr               ),
        .M_AXI_ARLEN                    (m_axi_arlen                ),
        .M_AXI_ARSIZE                   (m_axi_arsize               ),
        .M_AXI_ARBURST                  (m_axi_arburst              ),
        .M_AXI_ARLOCK                   (m_axi_arlock               ),
        .M_AXI_ARCACHE                  (m_axi_arcache              ),
        .M_AXI_ARPROT                   (m_axi_arprot               ),
        .M_AXI_ARQOS                    (m_axi_arqos                ),
        .M_AXI_ARUSER                   (m_axi_aruser               ),
        .M_AXI_ARVALID                  (m_axi_arvalid              ),
        .M_AXI_ARREADY                  (m_axi_arready              ),
        // R 信号
        .M_AXI_RID                      (m_axi_rid                  ),
        .M_AXI_RDATA                    (m_axi_rdata                ),
        .M_AXI_RRESP                    (m_axi_rresp                ),
        .M_AXI_RLAST                    (m_axi_rlast                ),
        .M_AXI_RUSER                    (m_axi_ruser                ),
        .M_AXI_RVALID                   (m_axi_rvalid               ),
        .M_AXI_RREADY                   (m_axi_rready               )
    );


endmodule
