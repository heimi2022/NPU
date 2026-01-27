module ffn_mul_ctrl#(
    parameter BW_EXP   = 8   ,
    parameter BW_MAN   = 9   ,
    parameter BW_FP    = 17  ,
    parameter BW_INT   = 8   ,
    parameter VALUE_MN = 64     
)(
    input                               clk                 ,
    input                               rst_n               ,
    input                               start_ffn_mul       , 

    input       [VALUE_MN*BW_FP -1:0]   U_proj              ,
    input       [VALUE_MN*BW_FP -1:0]   silu_in             ,
    input       [VALUE_MN*BW_FP -1:0]   FMA_out             ,     

    output  reg                         busy_ffn_mul        ,
    output  reg [VALUE_MN*5     -1:0]   mode_ffn_mul        ,
    output  reg [VALUE_MN*BW_FP -1:0]   a_ffn_mul           ,
    output  reg [VALUE_MN*BW_FP -1:0]   b_ffn_mul           ,

    output  reg [VALUE_MN*BW_FP -1:0]   ffn_mul_out         ,
    output  reg                         ffn_mul_out_valid
);

    localparam CYCLE1 = 2'd2;
    reg [1:0] cnt ;

    //state ctrl
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt             <= 1'b0; 
            busy_ffn_mul    <= 1'b0;
        end else begin
            if(start_ffn_mul) begin
                busy_ffn_mul    <= 1'b1;
                cnt             <=  1'b0;
            end 
            else if(busy_ffn_mul) begin
                if(cnt >= CYCLE1) begin
                    cnt   <= 1'b0;
                    busy_ffn_mul <= 1'b0;
                end
                else cnt <= cnt + 1'b1;
            end         
        end
    end

//  .  .   1       2       3       4   
//     +---+   +---+   +---+   +---+   
// clk |   |   |   |   |   |   |   |   
//     +   +---+   +---+   +---+   +---

// mode|       |  MUL  |       |     
// op  |       |       |       |     
// IN  | INPUT |       |       |           
// OUT |       |       | OUT   |           

    assign mode_ffn_mul = (cnt==1'b0) ? {VALUE_MN{5'b00010}} : 1'b0; //MUL
    assign a_ffn_mul    = (cnt==1'b0) ? U_proj  : 1'b0;
    assign b_ffn_mul    = (cnt==1'b0) ? silu_in : 1'b0;

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ffn_mul_out <= 0 ;
            ffn_mul_out_valid <= 1'b0;
        end else begin
            if(cnt==2'd2) begin
                ffn_mul_out <= FMA_out ;
                ffn_mul_out_valid <= 1'b1;
            end
            else begin
                ffn_mul_out_valid <= 1'b0;
            end
        end
    end

endmodule
