`timescale 1 ns / 1 ps

module AXI4_read_ctrl #(
    parameter integer AXI_ID_WIDTH	                    = 1             ,
    parameter integer AXI_ADDR_WIDTH	                = 32            ,
    parameter integer AXI_DATA_WIDTH	                = 32            ,
    parameter integer AXI_ARUSER_WIDTH	                = 0             ,
    parameter integer AXI_RUSER_WIDTH	                = 0             ,
    parameter integer TRAN_BYTE_NUM_WIDTH               = 16            ,   // 传输总字节数位宽
    parameter integer SRAM_ADDR_WIDTH                   = 32                // sram 目标基地址位宽
)(
// 时钟复位
    input                                           clk                         ,
    input                                           rst_n                       ,
// 输入信号
    input           [AXI_ADDR_WIDTH - 1 : 0]        r_target_slave_base_addr_i  ,   // 基地址输入
    input           [TRAN_BYTE_NUM_WIDTH - 1 : 0]   r_total_byte_num_i          ,   // 传输总字节数输入
    input                                           r_start_i                   ,   // 读启动信号输入
// 输出信号
    output  reg                                     r_busy_o                    ,   // AXI 总线空闲 1有效
    output  reg     [SRAM_ADDR_WIDTH - 1 : 0]       r_sram_addr_o               ,   // sram 地址输出
    output  reg                                     r_sram_data_valid_o         ,   // sram 数据请求输出
    output  wire    [AXI_DATA_WIDTH - 1 : 0]        r_sram_data_o               ,   // sram 数据输出
    output  reg                                     r_error_o                   ,   // Asserts when ERROR is detected   
// AR 信号
    output  wire    [AXI_ID_WIDTH - 1 : 0]          M_AXI_ARID                  ,
    output  wire    [AXI_ADDR_WIDTH - 1 : 0]        M_AXI_ARADDR                ,
    output  wire    [7 : 0]                         M_AXI_ARLEN                 ,
    output  wire    [2 : 0]                         M_AXI_ARSIZE                ,
    output  wire    [1 : 0]                         M_AXI_ARBURST               ,
    output  wire                                    M_AXI_ARLOCK                ,
    output  wire    [3 : 0]                         M_AXI_ARCACHE               ,
    output  wire    [2 : 0]                         M_AXI_ARPROT                ,
    output  wire    [3 : 0]                         M_AXI_ARQOS                 ,
    output  wire    [AXI_ARUSER_WIDTH - 1 : 0]      M_AXI_ARUSER                ,
    output  wire                                    M_AXI_ARVALID               ,
    input   wire                                    M_AXI_ARREADY               ,
// R 信号
    input   wire    [AXI_ID_WIDTH - 1 : 0]          M_AXI_RID                   ,
    input   wire    [AXI_DATA_WIDTH - 1 : 0]        M_AXI_RDATA                 ,
    input   wire    [1 : 0]                         M_AXI_RRESP                 ,
    input   wire                                    M_AXI_RLAST                 ,
    input   wire    [AXI_RUSER_WIDTH - 1 : 0]       M_AXI_RUSER                 ,
    input   wire                                    M_AXI_RVALID                ,
    output  wire                                    M_AXI_RREADY                
);

    // 计算所需的最小位宽
    function integer clogb2 (input integer bit_depth); 
        begin   
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)    
                bit_depth = bit_depth >> 1;
        end   
    endfunction

    localparam integer AXI_STRB_WIDTH = AXI_DATA_WIDTH/8;
    // 一次突发传输最多传多少字节
    localparam integer MAX_TRANSACTIONS_BYTE_NUM = 256 * AXI_STRB_WIDTH;

    // 传输一个数据的字节数位宽
    localparam integer STRB_LOG2 = clogb2(AXI_STRB_WIDTH-1);


// AXI4LITE signals
    reg     [AXI_ADDR_WIDTH-1 : 0] 	        axi_araddr              ;
    reg  	                                axi_arvalid             ;
    reg     [7 : 0]                         axi_arlen               ;
    reg  	                                axi_rready              ;

    reg  	                                start_single_burst_read ;
    reg  	                                burst_read_active       ;
    
    wire  	                                read_resp_error         ;        // Interface response error flags
    wire  	                                rnext                   ;

    reg    [AXI_DATA_WIDTH - 1 : 0]        axi_rdata                ;


// I/O Connections assignments

//Read Address (AR)
    assign M_AXI_ARID	    = 'b0;
    assign M_AXI_ARADDR	    = r_target_slave_base_addr_i + axi_araddr;
    assign M_AXI_ARLEN	    = axi_arlen;
    assign M_AXI_ARSIZE	    = STRB_LOG2;
    assign M_AXI_ARBURST	= 2'b01;
    assign M_AXI_ARLOCK	    = 1'b0;
    assign M_AXI_ARCACHE	= 4'b0010;
    assign M_AXI_ARPROT	    = 3'h0;
    assign M_AXI_ARQOS	    = 4'h0;
    assign M_AXI_ARUSER	    = 'b1;
    assign M_AXI_ARVALID	= axi_arvalid;
//Read and Read Response (R)
    assign M_AXI_RREADY	= axi_rready;

// 数据字节数预处理
    wire strb_en;
    assign strb_en = (r_total_byte_num_i[STRB_LOG2 - 1 : 0] > 0) ? 1'b1 : 1'b0;

    wire [AXI_DATA_WIDTH - 1 : 0] last_wstrb;
    assign last_wstrb = (r_total_byte_num_i[STRB_LOG2 - 1 : 0] > 0) ? (1 << (r_total_byte_num_i[STRB_LOG2 - 1 : 0]<<3)) -1:0;


    // 计算 剩余待传输字节数
    reg [TRAN_BYTE_NUM_WIDTH - 1 : 0] byte_remain_num;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            byte_remain_num <= 1'b0;
        else begin
            if(r_start_i)
                byte_remain_num <= r_total_byte_num_i;  
            else if (M_AXI_ARREADY && axi_arvalid) begin
                if(byte_remain_num >= MAX_TRANSACTIONS_BYTE_NUM)
                    byte_remain_num <= byte_remain_num - MAX_TRANSACTIONS_BYTE_NUM;
                else
                    byte_remain_num <= 0;
            end
            else
                byte_remain_num <= byte_remain_num;
        end
    end


//----------------------------
//Read Address Channel
//----------------------------

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            axi_arlen <= 1'b0;
        else begin
            if(start_single_burst_read) begin
                if(byte_remain_num >= MAX_TRANSACTIONS_BYTE_NUM)
                    axi_arlen <= 8'd255;
                else begin
                    if(strb_en)
                        axi_arlen <= (byte_remain_num >> STRB_LOG2);
                    else
                        axi_arlen <= (byte_remain_num >> STRB_LOG2) - 1;
                end
            end
            else
                axi_arlen <= axi_arlen;
        end
    end

    always @(posedge clk or negedge rst_n) begin 
        if (!rst_n)
            axi_arvalid <= 1'b0;
        else begin
            if (~axi_arvalid && start_single_burst_read)
                axi_arvalid <= 1'b1;
            else if (M_AXI_ARREADY && axi_arvalid)
                axi_arvalid <= 1'b0;
            else
                axi_arvalid <= axi_arvalid;
            end
    end   


    // Next address after ARREADY indicates previous address acceptance  
    always @(posedge clk or negedge rst_n) begin 
        if (!rst_n)
            axi_araddr <= 'b0;
        else begin
            if(r_start_i)
                axi_araddr <= 1'b0;
            else if (M_AXI_ARREADY && axi_arvalid)
                axi_araddr <= axi_araddr + MAX_TRANSACTIONS_BYTE_NUM;  
            else
                axi_araddr <= axi_araddr;
        end
    end   


//--------------------------------
//Read Data (and Response) Channel
//--------------------------------

    // Forward movement occurs when the channel is valid and ready   
    assign rnext = M_AXI_RVALID && axi_rready;

    // read data channel ready signal generation
    always @(posedge clk or negedge rst_n) begin    
        if (!rst_n) begin
            axi_rready <= 1'b0;  
        end
        else begin
            if(r_start_i)
                axi_rready <= 1'b0;
            else if(M_AXI_ARREADY && axi_arvalid && !axi_rready)
                axi_rready <= 1'b1;
            else if(M_AXI_RVALID && M_AXI_RLAST && axi_rready)
                axi_rready <= 1'b0;
            else
                axi_rready <= axi_rready;
        end
    end 
           
    //Flag any read response errors
    assign read_resp_error = axi_rready & M_AXI_RVALID & M_AXI_RRESP[1];  


//--------------------------------
// sram 输出
//--------------------------------

    // sram 地址输出
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            r_sram_addr_o <= 'b0;
        else begin
            if(r_start_i)
                r_sram_addr_o <= 'b0;
            else if (r_sram_data_valid_o) begin
                r_sram_addr_o <= r_sram_addr_o + 1'b1;
            end
            else
                r_sram_addr_o <= r_sram_addr_o;
        end
    end

    // sram 数据输出
    assign r_sram_data_o = axi_rdata;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            axi_rdata <= 1'd0;
        else begin
            if (rnext) begin
                if(M_AXI_RLAST && (byte_remain_num == 0) && strb_en)
                    axi_rdata <= M_AXI_RDATA & last_wstrb;
                else
                    axi_rdata <= M_AXI_RDATA;
            end
            else
                axi_rdata <= axi_rdata;
        end
    end


    // sram 数据有效输出
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            r_sram_data_valid_o <= 1'b0;
        else begin
            if(rnext)
                r_sram_data_valid_o <= 1'b1;
            else
                r_sram_data_valid_o <= 1'b0;
        end
    end

//----------------------------------
// error register
//----------------------------------
    always @(posedge clk or negedge rst_n) begin 
        if (!rst_n) 
            r_error_o <= 1'b0;
        else begin
            if(r_start_i)
                r_error_o <= 1'b0;
            else if (read_resp_error)  
                r_error_o <= 1'b1;
            else
                r_error_o <= r_error_o;
        end
    end   



    
    //implement master command interface state machine
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n)
            start_single_burst_read <= 1'b0;
        else begin
            if (r_busy_o)begin
                if (~axi_arvalid && ~burst_read_active && ~start_single_burst_read)
                    start_single_burst_read <= 1'b1;
                else
                    start_single_burst_read <= 1'b0; 
            end  
            else 
                start_single_burst_read <= 1'b0;
        end
    end
    


    
    // burst_read_active signal is asserted when there is a burst write transaction
    // is initiated by the assertion of start_single_burst_write. start_single_burst_read
    // signal remains asserted until the burst read is accepted by the master
    always @(posedge clk or negedge rst_n)begin
        if (!rst_n)
            burst_read_active <= 1'b0;
        else begin
            if(r_start_i)
                burst_read_active <= 1'b0;
            else if (start_single_burst_read)
                burst_read_active <= 1'b1;
            else if (M_AXI_RVALID && axi_rready && M_AXI_RLAST)
                burst_read_active <= 0;   
        end
    end
    
    
    always @(posedge clk or negedge rst_n)  begin
        if (!rst_n)
            r_busy_o <= 1'b0;
        else begin
            if(r_start_i)
                r_busy_o <= 1'b1;
            else if (M_AXI_RVALID && axi_rready && M_AXI_RLAST && (byte_remain_num == 0))
                r_busy_o <= 1'b0;
            else
                r_busy_o <= r_busy_o; 
        end
    end


endmodule
