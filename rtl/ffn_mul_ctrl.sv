module ffn_mul_ctrl#(
    parameter BW_EXP   = 8   ,
    parameter BW_MAN   = 9   ,
    parameter BW_FP    = 17  ,
    parameter BW_INT   = 8   ,
    parameter VALUE_MK = 128
)(
    input                        clk                 ,
    input                        rst_n               ,
    input                        state_prefill       ,
    input                        state_decode        ,
    input                        start_ffn_mul       , //pulse

    input       [VALUE_MK*BW_FP -1:0]  U_proj              , //8*16 OR ?
    input       [VALUE_MK*BW_FP -1:0]  silu_in             , //8*16 OR ?
    input       [VALUE_MK*BW_FP -1:0]  FMA_out             ,     

    output  reg                        busy_ffn_mul        ,
    output  reg [VALUE_MK*5     -1:0]  mode_ffn_mul        ,
    output  reg [VALUE_MK*BW_FP -1:0]  a_ffn_mul           ,
    output  reg [VALUE_MK*BW_FP -1:0]  b_ffn_mul           ,

    output  reg [VALUE_MK*BW_FP -1:0]  buffer_mul_out         

);

    localparam CYCLE1 = 2'd3 ;
    reg [1:0] cnt ;



    integer i ;

    //state ctrl
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt   <= 'b0; 
            busy_ffn_mul <= 'b0;
        end else begin
            if(start_ffn_mul) begin
                busy_ffn_mul <= 1'b1;
                cnt   <=  'b0;
            end 
            
            else if(busy_ffn_mul) begin
                if(cnt == CYCLE1) begin
                    cnt   <= 'b0;
                    busy_ffn_mul <= 'b0;
                end
                else cnt <= cnt + 1;
            end         
        end
    end

//  .  .   1       2       3       4       5       6       7       8       9      10      11      12      13      14      15      16    
//     +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +
// clk |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
//     +   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+

// mode|       |  MUL  |       |       |       |       |       |       |       |       |       |       |       |       |       |
// op  |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |
// IN  | INPUT |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       
// OUT |       |       | OUT   |       |       |       |       |       |       |       |       |       |       |       |       |       


    assign a_ffn_mul = (cnt==1) ? U_proj  : 0;
    assign b_ffn_mul = (cnt==1) ? silu_in : 0;

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            buffer_mul_out <= 0 ;
        end else begin
            if(cnt==3) buffer_mul_out <= FMA_out ;
        end

    end



endmodule
