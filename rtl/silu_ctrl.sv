module silu_ctrl#(
    parameter BW_EXP   = 8   ,
    parameter BW_MAN   = 9   ,
    parameter BW_FP    = 17  ,
    parameter BW_INT   = 8   ,
    parameter VALUE_MN = 64
)(
    input                        clk                 ,
    input                        rst_n               ,
    input                        state_prefill       ,
    input                        state_decode        ,
    input                        start_silu          , //pulse

    input       [VALUE_MN*BW_FP -1:0]  G_proj              , //8*8 or 1*64
    input       [8*BW_FP        -1:0]  FMA_out             ,     

    output  reg                        busy_silu           ,
    output  reg [8*5            -1:0]  mode_silu           ,
    output  reg [8*BW_FP        -1:0]  a_silu              ,
    output  reg [8*BW_FP        -1:0]  b_silu              ,
    output  reg [8*BW_FP        -1:0]  c_silu              ,

    output  reg [VALUE_MN*BW_FP -1:0]  buffer_silu_out         

);


    localparam CYCLE1 = 5'd18 ;
    reg [4:0] cnt ;


    //state ctrl
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt   <= 'b0; 
            busy_silu <= 'b0;
        end else begin
            if(start_silu) begin
                busy_silu <= 1'b1;
                cnt   <=  'b0;
            end 
            
            else if(busy_silu) begin
                if(cnt == CYCLE1) begin
                    cnt   <= 'b0;
                    busy_silu <= 'b0;
                end
                else cnt <= cnt + 1;
            end         
        end
    end


    integer i;
    genvar j;

    wire [8*BW_FP -1] coe_a ;
    wire [8*BW_FP -1] coe_b ;
    wire [8*BW_FP -1] coe_c ;


    generate 
        for (j=0;j<8;j=j+1) begin : silu_coe
            find_silu_coe #(
                .BW_EXP(BW_EXP),
                .BW_MAN(BW_MAN),
                .BW_FP (BW_FP)
            )u_find_silu_coe(
                .x     (b_silu[i*BW_FP+:BW_FP] ) ,
                .coe_a (coe_a[i*BW_FP+:BW_FP]  ) ,
                .coe_b (coe_b[i*BW_FP+:BW_FP]  ) ,
                .coe_c (coe_c[i*BW_FP+:BW_FP]  ) 
            );                  
        end
    endgenerate


//  .  .   1       2       3       4       5       6       7       8       9      10      11      12      13      14      15      16    
//     +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +
// clk |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
//     +   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+

// mode|       | FMA   | FMA   | FMA   | FMA   | FMA   | FMA   | FMA   | FMA   | FMA   | FMA   | FMA   | FMA   | FMA   | FMA   | FMA   | FMA   | 
// op  |       | 1_1   | 2_1   | 1_2   | 2_2   | 3_1   | 4_1   | 3_2   | 4_2   | 5_1   | 6_1   | 5_2   | 6_2   | 7_1   | 8_1   | 7_2   | 8_2   |
// IN  | IN1   | IN2   | IN1   | IN2   | IN3   | IN4   | IN3   | IN4   | IN5   | IN6   | IN5   | IN6   | IN7   | IN8   | IN7   | IN8   |       |       
// OUT |       |       |       |       |OUT1   |OUT2   |       |       |OUT3   |OUT4   |       |       |OUT5   |OUT6   |       |       |OUT7   |OUT8   |


    always@(*) begin
        case(cnt)
            1: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = coe_a ;
                b_silu    = G_proj[0 +:8*BW_FP] ;
                c_silu    = coe_b ;
            end

            2: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = coe_a ;
                b_silu    = G_proj[8*BW_FP +:8*BW_FP] ;
                c_silu    = coe_b ;
            end
            
            3: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = FMA_out ;
                b_silu    = G_proj[0 +:8*BW_FP] ;
                c_silu    = coe_c ;
            end

            4: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = FMA_out ;
                b_silu    = G_proj[8*BW_FP +:8*BW_FP] ;
                c_silu    = coe_c ;
            end

            5: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = coe_a ;
                b_silu    = G_proj[16*BW_FP +:8*BW_FP] ;
                c_silu    = coe_b ;
            end

            6: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = coe_a ;
                b_silu    = G_proj[24*BW_FP +:8*BW_FP] ;
                c_silu    = coe_b ;
            end
            
            7: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = FMA_out ;
                b_silu    = G_proj[16*BW_FP +:8*BW_FP] ;
                c_silu    = coe_c ;
            end

            8: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = FMA_out ;
                b_silu    = G_proj[24*BW_FP +:8*BW_FP] ;
                c_silu    = coe_c ;
            end

            9: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = coe_a ;
                b_silu    = G_proj[32*BW_FP +:8*BW_FP] ;
                c_silu    = coe_b ;
            end

            10: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = coe_a ;
                b_silu    = G_proj[40*BW_FP +:8*BW_FP] ;
                c_silu    = coe_b ;
            end
            
            11: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = FMA_out ;
                b_silu    = G_proj[32*BW_FP +:8*BW_FP] ;
                c_silu    = coe_c ;
            end

            12: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = FMA_out ;
                b_silu    = G_proj[40*BW_FP +:8*BW_FP] ;
                c_silu    = coe_c ;
            end

            13: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = coe_a ;
                b_silu    = G_proj[48*BW_FP +:8*BW_FP] ;
                c_silu    = coe_b ;
            end

            14: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = coe_a ;
                b_silu    = G_proj[56*BW_FP +:8*BW_FP] ;
                c_silu    = coe_b ;
            end
            
            15: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = FMA_out ;
                b_silu    = G_proj[48*BW_FP +:8*BW_FP] ;
                c_silu    = coe_c ;
            end

            16: begin
                mode_silu = {8{5'b00100}}; 
                a_silu    = FMA_out ;
                b_silu    = G_proj[58*BW_FP +:8*BW_FP] ;
                c_silu    = coe_c ;
            end

            default: begin
                mode_silu = 0 ; 
                a_silu    = 0 ;
                b_silu    = 0 ;
                c_silu    = 0 ;
            end

        endcase
    end


    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            buffer_silu_out <= 0;
        end else begin
            case(cnt)
                5 : buffer_silu_out[0       +:8*BW_FP] <= FMA_out;
                6 : buffer_silu_out[8 *BW_FP+:8*BW_FP] <= FMA_out;
                9 : buffer_silu_out[16*BW_FP+:8*BW_FP] <= FMA_out;
                10: buffer_silu_out[24*BW_FP+:8*BW_FP] <= FMA_out;
                13: buffer_silu_out[32*BW_FP+:8*BW_FP] <= FMA_out;
                14: buffer_silu_out[40*BW_FP+:8*BW_FP] <= FMA_out;
                17: buffer_silu_out[48*BW_FP+:8*BW_FP] <= FMA_out;
                18: buffer_silu_out[56*BW_FP+:8*BW_FP] <= FMA_out;
                default: buffer_silu_out <= buffer_silu_out ;
            endcase
        end
    end
    
endmodule
