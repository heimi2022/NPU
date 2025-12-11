`timescale 1 ns / 1 ps

module AXI4_ctrl #(
    parameter         AXI_BASE_ADDR_WIDTH	            = 32'h40000000  ,
    parameter integer AXI_ID_WIDTH	                    = 1             ,
    parameter integer AXI_ADDR_WIDTH	                = 32            ,
    parameter integer AXI_DATA_WIDTH	                = 32            ,
    parameter integer AXI_STRB_WIDTH	                = 4             ,    // AXI_DATA_WIDTH/8
    parameter integer AXI_AWUSER_WIDTH	                = 0             ,
    parameter integer AXI_ARUSER_WIDTH	                = 0             ,
    parameter integer AXI_WUSER_WIDTH	                = 0             ,
    parameter integer AXI_RUSER_WIDTH	                = 0             ,
    parameter integer AXI_BUSER_WIDTH	                = 0             ,
    parameter integer TRAN_BYTE_NUM_WIDTH               = 16             
)(
    // Users to add ports here

    // User ports ends
    // Do not modify the ports beyond this line

    // Initiate AXI transactions

    // Asserts when transaction is complete
    output wire  TXN_DONE,
    // Asserts when ERROR is detected
    output reg  ERROR,
// 时钟复位
    input                                   clk,
    input                                   rst_n,

// 外部输入信号
    input   [AXI_BASE_ADDR_WIDTH - 1 : 0]   axi_target_slave_base_addr_i  ,   // 基地址输入
    input   [TRAN_BYTE_NUM_WIDTH - 1 : 0]   axi_total_byte_num_i          ,   // 传输总字节数输入

    input   [AXI_DATA_WIDTH - 1 : 0]        w_data_i                    ,   // 写数据输入
    input                                   w_start_i                   ,   // 写启动信号输入

    input                                   r_start_i                   ,   // 写启动信号输入

// 输出信号
    output  reg                             axi_ready_o                 ,   // AXI 总线空闲 1有效

// AW 信号
    // 写ID
    output wire [AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
    // 写地址
    output wire [AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
    // 突发写长度，表示突发传输的总数据量，实际传输次数为 AWLEN + 1
    output wire [7 : 0] M_AXI_AWLEN,
    // 突发写大小，每个突发传输数据的字节数
    output wire [2 : 0] M_AXI_AWSIZE,
    // 突发写类型 00/01/10/11 对应 FIXED/INCR/WRAP/RESERVED
    output wire [1 : 0] M_AXI_AWBURST,
    // 总线锁信号
    output wire  M_AXI_AWLOCK,
    // Cache 类型
    output wire [3 : 0] M_AXI_AWCACHE,
    // 保护类型，该信号指示事务的特权级及安全等级
    output wire [2 : 0] M_AXI_AWPROT,
    // 质量服务QoS
    output wire [3 : 0] M_AXI_AWQOS,
    // 用户自定义信号
    output wire [AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
    // 写地址有效, 该信号表明地址和相关的控制信号是有效的
    output wire  M_AXI_AWVALID,
    // 写地址就绪, 该信号表明从设备已经准备好接收地址和相关的控制信号
    input wire  M_AXI_AWREADY,

// W 信号
    // Master Interface Write Data.
    output wire [AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
    // 数据掩码,字节为单位
    output wire [AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
    // Write last. This signal indicates the last transfer in a write burst.
    output wire  M_AXI_WLAST,
    // Optional User-defined signal in the write data channel.
    output wire [AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
    // Write valid. This signal indicates that valid write
    // data and strobes are available
    output wire  M_AXI_WVALID,
    // Write ready. This signal indicates that the slave
    // can accept the write data.
    input wire  M_AXI_WREADY,
// B 信号
    input wire [AXI_ID_WIDTH-1 : 0] M_AXI_BID,
    // Write response. This signal indicates the status of the write transaction.
    input wire [1 : 0] M_AXI_BRESP,
    // Optional User-defined signal in the write response channel
    input wire [AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
    // Write response valid. This signal indicates that the
    // channel is signaling a valid write response.
    input wire  M_AXI_BVALID,
    // Response ready. This signal indicates that the master
    // can accept a write response.
    output wire  M_AXI_BREADY,
// AR 信号
    output wire [AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
    // Read address. This signal indicates the initial
    // address of a read burst transaction.
    output wire [AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
    // Burst length. The burst length gives the exact number of transfers in a burst
    output wire [7 : 0] M_AXI_ARLEN,
    // Burst size. This signal indicates the size of each transfer in the burst
    output wire [2 : 0] M_AXI_ARSIZE,
    // Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
    output wire [1 : 0] M_AXI_ARBURST,
    // Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
    output wire  M_AXI_ARLOCK,
    // Memory type. This signal indicates how transactions
    // are required to progress through a system.
    output wire [3 : 0] M_AXI_ARCACHE,
    // Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
    output wire [2 : 0] M_AXI_ARPROT,
    // Quality of Service, QoS identifier sent for each read transaction
    output wire [3 : 0] M_AXI_ARQOS,
    // Optional User-defined signal in the read address channel.
    output wire [AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
    // Write address valid. This signal indicates that
    // the channel is signaling valid read address and control information
    output wire  M_AXI_ARVALID,
    // Read address ready. This signal indicates that
    // the slave is ready to accept an address and associated control signals
    input wire  M_AXI_ARREADY,
    // Read ID tag. This signal is the identification tag
// R 信号
    input wire [AXI_ID_WIDTH-1 : 0] M_AXI_RID,
    // Master Read Data
    input wire [AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
    // Read response. This signal indicates the status of the read transfer
    input wire [1 : 0] M_AXI_RRESP,
    // Read last. This signal indicates the last transfer in a read burst
    input wire  M_AXI_RLAST,
    // Optional User-defined signal in the read address channel.
    input wire [AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
    // Read valid. This signal indicates that the channel
    // is signaling the required read data.
    input wire  M_AXI_RVALID,
    // Read ready. This signal indicates that the master can
    // accept the read data and response information.
    output wire  M_AXI_RREADY
);

    // 计算所需的最小位宽
    function integer clogb2 (input integer bit_depth); 
        begin   
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)    
                bit_depth = bit_depth >> 1;
        end   
    endfunction

    // 一次突发传输最多传多少字节
    localparam integer MAX_TRANSACTIONS_BYTE_NUM = 256 * AXI_STRB_WIDTH;

    // 传输一个数据的字节数位宽
    localparam integer STRB_LOG2 = clogb2(AXI_STRB_WIDTH-1);

// AXI 状态机
    reg         [1:0]   mst_exec_state          ;
    parameter   [1:0]   IDLE            = 2'b00 , 
                        WRITE           = 2'b01 , 
                        READ            = 2'b10 , 
                        INIT_COMPARE    = 2'b11 ; 


// AXI4LITE signals
    //AXI4 internal temp signals
    reg     [AXI_ADDR_WIDTH-1 : 0]      axi_awaddr; // 地址偏移量
    reg  	                            axi_awvalid;
    reg     [AXI_DATA_WIDTH-1 : 0]      axi_wdata;
    reg  	                            axi_wlast;
    reg  	                            axi_wvalid;
    reg  	                            axi_bready;
    reg     [AXI_ADDR_WIDTH-1 : 0] 	    axi_araddr;
    reg  	                            axi_arvalid;
    reg  	                            axi_rready;
    // write beat count in a burst
    reg     [C_TRANSACTIONS_NUM : 0] 	write_index;
    // read beat count in a burst
    reg     [C_TRANSACTIONS_NUM : 0] 	read_index;
    // size of AXI_BURST_LEN length burst in bytes
    wire    [8 +  STRB_LOG2: 0] 	burst_size_bytes;
    // The burst counters are used to track the number of burst transfers of AXI_BURST_LEN burst length needed to transfer 2^C_MASTER_LENGTH bytes of data.
    reg     [C_NO_BURSTS_REQ : 0] 	    write_burst_counter;
    reg     [C_NO_BURSTS_REQ : 0] 	    read_burst_counter;
    reg  	                            start_single_burst_write;
    reg  	                            start_single_burst_read;
    reg  	                            writes_done;
    reg  	                            reads_done;
    reg  	                            error_reg;
    reg  	                            compare_done;
    reg  	                            read_mismatch;
    reg  	                            burst_write_active;
    reg  	                            burst_read_active;
    reg     [AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
    // Interface response error flags
    wire  	write_resp_error;
    wire  	read_resp_error;
    wire  	wnext;
    wire  	rnext;


// I/O Connections assignments

//I/O Connections. Write Address (AW)
    assign M_AXI_AWID = 'b0;
    assign M_AXI_AWADDR	= axi_target_slave_base_addr_i + axi_awaddr;
    //
    assign M_AXI_AWLEN = AXI_BURST_LEN - 1;
    // 传输的一个数据的字节数
    assign M_AXI_AWSIZE	= clogb2((AXI_DATA_WIDTH/8)-1);
    //INCR burst
    assign M_AXI_AWBURST = 2'b01;
    assign M_AXI_AWLOCK	= 1'b0;

    //not intermediate cache. 
    assign M_AXI_AWCACHE = 4'b0010;
    assign M_AXI_AWPROT	= 3'h0;
    assign M_AXI_AWQOS	= 4'h0;
    assign M_AXI_AWUSER	= 'b1;
    assign M_AXI_AWVALID = axi_awvalid;
    
//Write Data(W)
    assign M_AXI_WDATA	= axi_wdata;
    //All bursts are complete and aligned in this example
    assign M_AXI_WSTRB	= {(AXI_DATA_WIDTH/8){1'b1}};
    assign M_AXI_WLAST	= axi_wlast;
    assign M_AXI_WUSER	= 'b0;
    assign M_AXI_WVALID	= axi_wvalid;
//Write Response (B)
    assign M_AXI_BREADY	= axi_bready;
//Read Address (AR)
    assign M_AXI_ARID	= 'b0;
    assign M_AXI_ARADDR	= axi_target_slave_base_addr_i + axi_araddr;
    //Burst LENgth is number of transaction beats, minus 1
    assign M_AXI_ARLEN	= axi_burst_len;
    //Size should be AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
    assign M_AXI_ARSIZE	= clogb2((AXI_DATA_WIDTH/8)-1);
    //INCR burst type is usually used, except for keyhole bursts
    assign M_AXI_ARBURST	= 2'b01;
    assign M_AXI_ARLOCK	= 1'b0;
    //Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache. 
    assign M_AXI_ARCACHE	= 4'b0010;
    assign M_AXI_ARPROT	= 3'h0;
    assign M_AXI_ARQOS	= 4'h0;
    assign M_AXI_ARUSER	= 'b1;
    assign M_AXI_ARVALID	= axi_arvalid;
//Read and Read Response (R)
    assign M_AXI_RREADY	= axi_rready;
    //Example design I/O
    assign TXN_DONE	= compare_done;
    //Burst size in bytes

// 数据字节数预处理
    wire [TRAN_BYTE_NUM_WIDTH : 0] total_byte_num;
    assign total_byte_num = (axi_total_byte_num_i[STRB_LOG2 - 1 : 0] > 0) ? 
                            {axi_total_byte_num_i[TRAN_BYTE_NUM_WIDTH - 1:STRB_LOG2] + 1'b1,{(STRB_LOG2){1'b0}}} : 
                            axi_total_byte_num_i;

    wire strb_en;
    assign strb_en = (axi_total_byte_num_i[STRB_LOG2 - 1 : 0] > 0) ? 1'b1 : 1'b0;

    wire [AXI_STRB_WIDTH - 1 : 0] last_wstrb;
    assign last_wstrb = (axi_total_byte_num_i[STRB_LOG2 - 1 : 0] > 0) ? (1 << axi_total_byte_num_i[STRB_LOG2 - 1 : 0]) -1:0;


    reg [TRAN_BYTE_NUM_WIDTH - 1 : 0] byte_remain_num;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            byte_remain_num <= 1'b0;
        else begin
            if(w_start_i || r_start_i)
                byte_remain_num <= total_byte_num;
            else if(wnext)
                byte_remain_num <= byte_remain_num - (AXI_DATA_WIDTH/8);
            else
                byte_remain_num <= byte_remain_num;
        end
    end
//--------------------
//Write Address Channel
//--------------------
    reg [7:0] axi_burst_len;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            axi_burst_len <= 1'b0;
        end
        else begin
            
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_awvalid <= 1'b0;
        end
        else begin
            if (~axi_awvalid && start_single_burst_write)begin    
                axi_awvalid <= 1'b1;
            end 
            else if (M_AXI_AWREADY && axi_awvalid)begin    
                axi_awvalid <= 1'b0;
            end 
            else  
                axi_awvalid <= axi_awvalid; 
        end
    end   
           
           
// Next address after AWREADY indicates previous address acceptance    
    always @(posedge clk or negedge rst_n)begin   
        if (!rst_n) begin    
            axi_awaddr <= 1'b0;  
        end 
        else begin
            if(w_start_i)
                axi_awaddr <= 1'b0;  
            else if (M_AXI_AWREADY && axi_awvalid)
                axi_awaddr <= axi_awaddr + burst_size_bytes;    
            else  
                axi_awaddr <= axi_awaddr;
        end
    end   


//--------------------
//Write Data Channel
//--------------------

// 写数据通道会持续尝试通过接口发送写数据。
// 被从机接受的数据量取决于 AXI 从设备和 AXI 互联（Interconnect）的设置，例如互联中是否启用了 FIFO 等。
// 注意：写数据通道与写地址通道之间没有明确的时序关系。
// 写数据（W）通道有自己独立的节流（throttling）标志，与 AW 通道分开。
// 两个通道之间的同步必须由用户自行确定。
// 最简单但性能最低的方法是：每次只发起一个写地址和一个写数据突发（burst）。
// 在本示例中，通过使用相同的地址递增方式和突发大小来保持它们同步。
// 然后在用户逻辑中，通过门限计数器来监控 AW 和 W 通道的事务，确保两个通道都不会相互领先太多。
// 当前向的推进（forward movement）发生在写数据通道同时满足 valid 和 ready 时。

    assign wnext = M_AXI_WREADY & axi_wvalid;
        
// WVALID logic, similar to the axi_awvalid always block above
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n == 0)
            axi_wvalid <= 1'b0;
        else begin
            if(init_txn_pulse == 1'b1) 
                axi_wvalid <= 1'b0;
            else if (~axi_wvalid && M_AXI_AWREADY && axi_awvalid)
                axi_wvalid <= 1'b1;
            else if (wnext && axi_wlast)
                axi_wvalid <= 1'b0;   
            else
                axi_wvalid <= axi_wvalid;
        end
    end
        
        
//WLAST generation on the MSB of a counter underflow    
// WVALID logic, similar to the axi_awvalid always block above
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n == 0) begin
            axi_wlast <= 1'b0;
        end
        else begin
            if(init_txn_pulse == 1'b1)
                axi_wlast <= 1'b0;
            else if (((write_index == AXI_BURST_LEN-2 && AXI_BURST_LEN >= 2) && wnext) || (AXI_BURST_LEN == 1 ))
                axi_wlast <= 1'b1;
            else if (wnext)
                axi_wlast <= 1'b0;
            else
                axi_wlast <= axi_wlast;
        end
    end


    // 一次突发，数据传输计数器
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n == 0) begin
            write_index <= 0;   
        end
        else begin
            if(init_txn_pulse == 1'b1 || start_single_burst_write == 1'b1)
                write_index <= 0;
            else if (wnext && (write_index != AXI_BURST_LEN-1))
                write_index <= write_index + 1;  
            else
                write_index <= write_index;
        end
    end   
        
    // 写数据生成器，后面替换
    always @(posedge clk or negedge rst_n) begin 
        if(rst_n == 0)
            axi_wdata <= 'b1;
        else begin
            if(init_txn_pulse == 1'b1)
                axi_wdata <= 'b1;
            else if (wnext)    
                axi_wdata <= axi_wdata + 1;
            else
                axi_wdata <= axi_wdata;
        end
    end

//----------------------------
//Write Response (B) Channel
//----------------------------

// 写响应通道用于反馈写操作已经提交到存储器。
// 当所有写数据和写地址都到达并被从设备接受后，BREADY 将被触发。
// 写请求的发起（即未完成写地址的数量）由写地址传输开始，
// 并由 BREADY/BRESP 信号完成。
// 尽管拉低（negate）BREADY 最终会抑制 AWREADY 信号，
// 但不推荐用这种方式来节流整个数据通道。
// BRESP 的第 1 位用于指示互联或从设备在整个写突发（burst）期间是否发生错误。
// 本示例会将该错误记录到 ERROR 输出中。

    always @(posedge clk or negedge rst_n) begin    
        if (rst_n == 0) begin
            axi_bready <= 1'b0;  
        end
        else begin
            if(init_txn_pulse == 1'b1)
                axi_bready <= 1'b0;
            else if ((((write_index == AXI_BURST_LEN-2 && AXI_BURST_LEN >= 2) && wnext) || (AXI_BURST_LEN == 1 ))&& ~axi_bready) 
                axi_bready <= 1'b1;  
            else if (axi_bready && M_AXI_BVALID) 
                axi_bready <= 1'b0;  
            else   
                axi_bready <= axi_bready;
        end
    end

    // always @(posedge clk or negedge rst_n) begin    
    //     if (rst_n == 0) begin
    //         axi_bready <= 1'b0;  
    //     end
    //     else begin
    //         if(init_txn_pulse == 1'b1)
    //             axi_bready <= 1'b0;
    //         else if (M_AXI_BVALID && ~axi_bready) begin
    //             axi_bready <= 1'b1;  
    //         end  
    //         // deassert after one clock cycle
    //         else if (axi_bready) begin
    //             axi_bready <= 1'b0;  
    //         end  
    //         // retain the previous value
    //         else   
    //             axi_bready <= axi_bready;
    //     end
    // end


//Flag any write response errors
    assign write_resp_error = axi_bready & M_AXI_BVALID & M_AXI_BRESP[1]; 


//----------------------------
//Read Address Channel
//----------------------------

//The Read Address Channel (AW) provides a similar function to the
//Write Address channel- to provide the tranfer qualifiers for the burst.

//In this example, the read address increments in the same
//manner as the write address channel.

    always @(posedge clk or negedge rst_n) begin 
        if (rst_n == 0) begin  
            axi_arvalid <= 1'b0;
        end
        else begin
            if(init_txn_pulse)
                axi_arvalid <= 1'b0;
            else if (~axi_arvalid && start_single_burst_read) begin  
                axi_arvalid <= 1'b1;
            end    
            else if (M_AXI_ARREADY && axi_arvalid)begin  
                axi_arvalid <= 1'b0;
            end
            else
                axi_arvalid <= axi_arvalid;
            end
    end   


// Next address after ARREADY indicates previous address acceptance  
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n == 0)begin  
            axi_araddr <= 'b0;
        end
        else begin
            if(init_txn_pulse)
                axi_araddr <= 1'b0;
            else if (M_AXI_ARREADY && axi_arvalid)
                axi_araddr <= axi_araddr + burst_size_bytes;  
            else
                axi_araddr <= axi_araddr;
        end
    end   


//--------------------------------
//Read Data (and Response) Channel
//--------------------------------

    // Forward movement occurs when the channel is valid and ready   
    assign rnext = M_AXI_RVALID && axi_rready;


// Burst length counter. Uses extra counter register bit to indicate    
// terminal count to reduce decode logic    
    always @(posedge clk or negedge rst_n) begin    
        if (rst_n == 0) begin
            read_index <= 0;
        end
        else begin
            if(init_txn_pulse == 1'b1 || start_single_burst_read)
                read_index <= 1'd0;
            else if (rnext && (read_index != AXI_BURST_LEN-1))
                read_index <= read_index + 1;
            else   
                read_index <= read_index;
        end
    end


/*         
    The Read Data channel returns the results of the read request

    In this example the data checker is always able to accept
    more data, so no need to throttle the RREADY signal
    */
    always @(posedge clk or negedge rst_n) begin    
        if (rst_n == 0) begin
            axi_rready <= 1'b0;  
        end
        else begin
            if(init_txn_pulse)
                axi_rready <= 1'b0;
            else if(M_AXI_ARREADY && axi_arvalid && !axi_rready)
                axi_rready <= 1'b1;
            else if(M_AXI_RVALID && M_AXI_RLAST && axi_rready)
                axi_rready <= 1'b0;
            else
                axi_rready <= axi_rready;
        end
    end 

    // always @(posedge clk) begin    
    //     if (rst_n == 0 || init_txn_pulse == 1'b1 ) begin
    //         axi_rready <= 1'b0;  
    //     end  
    //     // accept/acknowledge rdata/rresp with axi_rready by the master
    //     // when M_AXI_RVALID is asserted by slave
    //     else if (M_AXI_RVALID) begin
    //         if (M_AXI_RLAST && axi_rready) begin
    //             axi_rready <= 1'b0;   
    //         end
    //         else begin
    //             axi_rready <= 1'b1;  
    //         end
    //     end
    //     // retain the previous value  
    // end 

//Check received read data against data generator
    always @(posedge clk or negedge rst_n) begin    
        if (rst_n == 0) begin
            read_mismatch <= 1'b0;
        end
        else begin
            if(init_txn_pulse)
                read_mismatch <= 1'b0;
            else if (rnext && (M_AXI_RDATA != expected_rdata))
                read_mismatch <= 1'b1;
            else   
                read_mismatch <= 1'b0; 
        end
    end      
           
//Flag any read response errors
    assign read_resp_error = axi_rready & M_AXI_RVALID & M_AXI_RRESP[1];  


//----------------------------------------
//Example design read check data generator
//-----------------------------------------

//Generate expected read data to check against actual read data

    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0 || init_txn_pulse == 1'b1)
            expected_rdata <= 'b1;
        else begin
            if(init_txn_pulse == 1'b1)
                expected_rdata <= 'b1;
            else if (M_AXI_RVALID && axi_rready)   
                expected_rdata <= expected_rdata + 1;
            else       
                expected_rdata <= expected_rdata;  
        end
    end         


//----------------------------------
//Example design error register
//----------------------------------

//Register and hold any data mismatches, or read/write interface errors 

    always @(posedge clk or negedge rst_n) begin 
        if (rst_n == 0) begin  
            error_reg <= 1'b0;
        end
        else begin
            if(init_txn_pulse)
                error_reg <= 1'b0;
            else if (read_mismatch || write_resp_error || read_resp_error)  
                error_reg <= 1'b1;
            else
                error_reg <= error_reg;
        end
    end   


//--------------------------------
//Example design throttling
//--------------------------------

// For maximum port throughput, this user example code will try to allow
// each channel to run as independently and as quickly as possible.

// However, there are times when the flow of data needs to be throtted by
// the user application. This example application requires that data is
// not read before it is written and that the write channels do not
// advance beyond an arbitrary threshold (say to prevent an 
// overrun of the current read address by the write address).

// From AXI4 Specification, 13.13.1: "If a master requires ordering between 
// read and write transactions, it must ensure that a response is received 
// for the previous transaction before issuing the next transaction."

// This example accomplishes this user application throttling through:
// -Reads wait for writes to fully complete
// -Address writes wait when not read + issued transaction counts pass 
// a parameterized threshold
// -Writes wait when a not read + active data burst count pass 
// a parameterized threshold

    // write_burst_counter counter keeps track with the number of burst transaction initiated
    // against the number of burst transactions the master needs to initiate
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            write_burst_counter <= 'b0;
        end
        else begin
            if(init_txn_pulse)
                write_burst_counter <= 1'b0;
            else if (M_AXI_AWREADY && axi_awvalid) begin
                if (write_burst_counter[C_NO_BURSTS_REQ] == 1'b0)
                    write_burst_counter <= write_burst_counter + 1'b1;   
            end
            else
                write_burst_counter <= write_burst_counter;   
        end

    end
    
    // read_burst_counter counter keeps track with the number of burst transaction initiated    
    // against the number of burst transactions the master needs to initiate
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            read_burst_counter <= 'b0;
        end
        else begin
            if(init_txn_pulse)
                read_burst_counter <= 1'b0;
            else if (M_AXI_ARREADY && axi_arvalid) begin
                if (read_burst_counter[C_NO_BURSTS_REQ] == 1'b0) 
                    read_burst_counter <= read_burst_counter + 1'b1;
            end
            else
                read_burst_counter <= read_burst_counter;
        end

    end
    
    
    //implement master command interface state machine
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n)begin
            mst_exec_state <= IDLE;   
            start_single_burst_write <= 1'b0;
            start_single_burst_read <= 1'b0;
            compare_done <= 1'b0;
            ERROR <= 1'b0;   
            axi_ready_o <= 1'b0;
        end
        else begin
            // state transition
            case (mst_exec_state)
                IDLE: begin
                    if (w_start_i) begin
                        mst_exec_state  <= WRITE; 
                        ERROR <= 1'b0;
                        compare_done <= 1'b0;
                        axi_ready_o    <= 1'b0;
                    end  
                    else begin
                        mst_exec_state  <= IDLE;
                        axi_ready_o     <= 1'b1;
                    end  
                end
                WRITE: begin
                    // 该状态负责输出 start_single_write 脉冲，用于启动一次写事务。
                    // 在 burst_write_active 信号被拉高之前，会持续发起写事务。
                    // 写控制器
                    if (writes_done) begin
                        mst_exec_state <= IDLE;
                    end  
                    else begin
                        mst_exec_state  <= WRITE; 
                        if (~axi_awvalid && ~start_single_burst_write && ~burst_write_active) begin
                            start_single_burst_write <= 1'b1;
                        end
                        else begin
                            start_single_burst_write <= 1'b0; //Negate to generate a pulse
                        end
                    end  
                end
                INIT_READ: begin
                    if (reads_done)begin
                        mst_exec_state <= INIT_COMPARE;
                    end  
                    else begin
                        mst_exec_state  <= INIT_READ;  
            
                        if (~axi_arvalid && ~burst_read_active && ~start_single_burst_read) begin
                            start_single_burst_read <= 1'b1;
                        end
                        else begin
                            start_single_burst_read <= 1'b0; //Negate to generate a pulse
                        end
                    end  
                end
                INIT_COMPARE:
                // This state is responsible to issue the state of comparison
                // of written data with the read data. If no error flags are set,   
                // compare_done signal will be asseted to indicate success.
                //if (~error_reg)   
                begin  
                    ERROR <= error_reg;
                    mst_exec_state <= IDLE;  
                    compare_done <= 1'b1;
                end    
                default :
                begin  
                    mst_exec_state  <= IDLE; 
                end    
            endcase    
        end
    end //MASTER_EXECUTION_PROC   
    
    
    // burst_write_active signal is asserted when there is a burst write transaction
    // is initiated by the assertion of start_single_burst_write. burst_write_active
    // signal remains asserted until the burst write is accepted by the slave
    always @(posedge clk or negedge rst_n)begin
        if (rst_n == 0)
            burst_write_active <= 1'b0;
        else begin
            if(init_txn_pulse)
                burst_write_active <= 1'b0;
            else if (start_single_burst_write)
                burst_write_active <= 1'b1;
            else if (M_AXI_BVALID && axi_bready)
                burst_write_active <= 0;  
        end
    end
    
    // Check for last write completion.
    
    // This logic is to qualify the last write count with the final write
    // response. This demonstrates how to confirm that a write has been
    // committed.
    
    // 从机 响应 WLAST 信号后，writes_done 信号被置位，表示写事务完成。
    always @(posedge clk or negedge rst_n)begin
        if(rst_n == 0)
            writes_done <= 1'b0;
        else begin
            if(init_txn_pulse == 1'b1)
                writes_done <= 1'b0;
            else if(M_AXI_BVALID && (write_burst_counter[C_NO_BURSTS_REQ]) && axi_bready)
                writes_done <= 1'b1;
            else
                writes_done <= writes_done;
        end
    end
    
    // burst_read_active signal is asserted when there is a burst write transaction
    // is initiated by the assertion of start_single_burst_write. start_single_burst_read
    // signal remains asserted until the burst read is accepted by the master
    always @(posedge clk or negedge rst_n)begin
        if (rst_n == 0)
            burst_read_active <= 1'b0;
        else begin
            if(init_txn_pulse)
                burst_read_active <= 1'b0;
            else if (start_single_burst_read)
                burst_read_active <= 1'b1;
            else if (M_AXI_RVALID && axi_rready && M_AXI_RLAST)
                burst_read_active <= 0;   
        end
    end
    
    
    // Check for last read completion.
    
    // This logic is to qualify the last read count with the final read
    // response. This demonstrates how to confirm that a read has been
    // committed.
    
    always @(posedge clk or negedge rst_n)  begin
        if (rst_n == 0)
            reads_done <= 1'b0;
        else begin
            if(init_txn_pulse)
                reads_done <= 1'b0;
            else if (M_AXI_RVALID && axi_rready && (read_index == AXI_BURST_LEN-1) && (read_burst_counter[C_NO_BURSTS_REQ]))
                reads_done <= 1'b1;
            else
                reads_done <= reads_done; 
        end
    end

// Add user logic here

// User logic ends

endmodule
