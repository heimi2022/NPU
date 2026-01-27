module ffn_residual_ctrl#(
    parameter BW_EXP   = 8   ,
    parameter BW_MAN   = 9   ,
    parameter BW_FP    = 17  ,
    parameter BW_INT   = 8   ,
    parameter VALUE_MN = 64
)(
    input                               clk                     ,
    input                               rst_n                   ,
    input                               start_ffn_residual      , //pulse

    input       [VALUE_MN*BW_FP -1:0]   D_proj                  , //8*8 OR ?
    input       [VALUE_MN*BW_FP -1:0]   attn_residual_out       , //8*8 OR ?
    input       [VALUE_MN*BW_FP -1:0]   FMA_out                 ,     

    output  reg                         busy_ffn_residual       ,
    output  reg [VALUE_MN*5     -1:0]   mode_ffn_residual       ,
    output  reg [VALUE_MN*BW_FP -1:0]   a_ffn_residual          ,
    output  reg [VALUE_MN*BW_FP -1:0]   c_ffn_residual          ,

    output  reg [VALUE_MN*BW_FP -1:0]   ffn_residual_out        ,
    output  reg                         ffn_residual_out_valid   
);

    localparam CYCLE1 = 2'd2 ;
    reg [1:0] cnt ;

    //state ctrl
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt   <= 1'b0; 
            busy_ffn_residual <= 1'b0;
        end 
        else begin
            if(start_ffn_residual) begin
                busy_ffn_residual <= 1'b1;
                cnt   <=  1'b0;
            end 
            else if(busy_ffn_residual) begin
                if(cnt >= CYCLE1) begin
                    cnt   <= 1'b0;
                    busy_ffn_residual <= 1'b0;
                end
                else 
                    cnt <= cnt + 1'b1;
            end         
        end
    end

//  .  .   1       2       3       4   
//     +---+   +---+   +---+   +---+   
// clk |   |   |   |   |   |   |   |   
//     +   +---+   +---+   +---+   +---

// mode|       |  ADD  |       |     
// op  |       |       |       |     
// IN  | INPUT |       |       |     
// OUT |       |       | OUT   |     


    assign a_ffn_residual       = (cnt==1'b0) ? D_proj  : 1'b0;
    assign c_ffn_residual       = (cnt==1'b0) ? attn_residual_out : 1'b0;
    assign mode_ffn_residual    = (cnt==1'b0) ? {VALUE_MN{5'b01000}} : 1'b0; //ADD

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ffn_residual_out <= 0 ;
            ffn_residual_out_valid <= 1'b0;
        end 
        else begin
            if(cnt == 2'd2) begin
                ffn_residual_out <= FMA_out ;
                ffn_residual_out_valid <= 1'b1;
            end
            else 
                ffn_residual_out_valid <= 1'b0;
        end
    end
    
endmodule
