module RoPE_ctrl#(
    parameter BW_EXP   = 8   ,
    parameter BW_MAN   = 9   ,
    parameter BW_FP    = 17  ,
    parameter BW_INT   = 8   ,
    parameter VALUE_MN = 64 
)(
    input                                clk                 ,
    input                                rst_n               ,
    input                                start1              , //pulse 1
    input                                start2              , //pulse 9
    input       [VALUE_MN*BW_FP   -1:0]  QK_proj             , //8*4 or 1*32
    input       [VALUE_MN*BW_FP   -1:0]  W_cos               , //8*4 or 1*32
    input       [VALUE_MN*BW_FP   -1:0]  W_sin               , //8*4 or 1*32
    input       [VALUE_MN*2*BW_FP -1:0]  FMA_out             ,

    output                               busy_RoPE           ,
    output  reg [VALUE_MN*2*5     -1:0]  mode_RoPE           ,
    output  reg [VALUE_MN*2*BW_FP -1:0]  a_RoPE              ,
    output  reg [VALUE_MN*2*BW_FP -1:0]  b_RoPE              ,
    output  reg [VALUE_MN*2*BW_FP -1:0]  c_RoPE              ,
    output  reg [VALUE_MN*2*BW_FP -1:0]  buffer_RoPE         
);

    localparam CYCLE1 = 3'd2  ;
    localparam CYCLE2 = 3'd6  ;
    localparam M      = 8     ;
    localparam N      = 8     ;

    reg [2          :0]  cnt             ;
    reg [VALUE_MN*2*BW_FP -1:0]  buffer_RoPE_tmp ;

    reg busy1 , busy2 ;
    assign busy_RoPE = busy1 || busy2 ;

    integer i;

    //state ctrl
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt   <= 'b0; 
            busy1 <= 'b0;
            busy2 <= 'b0;
        end else begin
            if(start1) begin
                busy1 <= 1'b1;
                cnt   <=  'b0;
            end else if(start2) begin
                busy2 <= 1'b1;
                cnt   <= 'b0 ;
            end else if(busy1) begin
                if(cnt >= CYCLE1) begin
                    cnt   <= 'b0;
                    busy1 <= 'b0;
                end
                else cnt <= cnt + 1;
            end else if(busy2) begin
                if(cnt >= CYCLE2) begin
                    cnt   <= 'b0;
                    busy2 <= 'b0;
                end
                else cnt <= cnt + 1;
            end
        end
    end


//state choose
// prefill/decode
//  .  .   1       2       3       4       5       6       7       8       9      10      11      12      13      14      15      16    
//     +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +
// clk |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
//     +   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+

// mode|       |  MUL  |       |       |       |       |       |       |       |       |       |       |       |       |       |
// op  |       |*co/si |       |       |       |       |       |       |       |       |       |       |       |       |       |
// IN  | INPUT |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       
// OUT |       |       |RoPEtmp|       |       |       |       |       |       |       |       |       |       |       |       |      
// cnt |    0  |   1   |   2       3       4       5       6       7       8       9      10      11      12      13      14      15 

    always@(*) begin
        if(busy1) begin
            case({cnt})
                {3'd0}:begin  
                    for(i=0;i<M;i=i+1) begin
                        mode_RoPE[N*i*5+:N*5]       = {N{5'b00010}};
                        a_RoPE[N*i*BW_FP+:N*BW_FP]  = W_cos[N*i*BW_FP+:N*BW_FP] ;
                        b_RoPE[N*i*BW_FP+:N*BW_FP]  = QK_proj[N*i*BW_FP+:N*BW_FP] ;
                    end

                    for(i=0;i<M;i=i+1) begin
                        mode_RoPE[N*(i+M)*5+:N*5]       = {N{5'b00010}};
                        a_RoPE[N*(i+M)*BW_FP+:N*BW_FP]  = W_sin[N*i*BW_FP+:N*BW_FP] ;
                        b_RoPE[N*(i+M)*BW_FP+:N*BW_FP]  = QK_proj[N*i*BW_FP+:N*BW_FP] ;
                    end
                end

                default: begin
                    a_RoPE = 'b0;
                    b_RoPE = 'b0;
                    c_RoPE = 'b0;
                    mode_RoPE = 'b0;
                end
            endcase
        end 

// prefill/decode
//  .  .   1       2       3       4       5       6       7       8       9      10      11      12      13      14      15      16    
//     +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +
// clk |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
//     +   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+

// mode|       |  MUL  |ADD MUL|  ADD  |       |       |       |       |       |       |       |       |       |       |       |
// op  |       |*co/si | *(-1) |       |       |       |       |       |       |       |       |       |       |       |       |
// IN  | INPUT | INPUT | INPUT |       |       |       |       |       |       |       |       |       |       |       |       |       
// OUT |       |       |       |       |RoPEtmp|       |       |       |       |       |       |       |       |       |       |        

        else if(busy2) begin
            case({cnt})
                {3'd0}:begin  
                    for(i=0;i<M;i=i+1) begin
                        mode_RoPE[N*i*5+:N*5]       = {N{5'b00010}};
                        a_RoPE[N*i*BW_FP+:N*BW_FP]  = W_cos[N*i*BW_FP+:N*BW_FP] ;
                        b_RoPE[N*i*BW_FP+:N*BW_FP]  = QK_proj[N*i*BW_FP+:N*BW_FP] ;
                    end

                    for(i=0;i<M;i=i+1) begin
                        mode_RoPE[N*(i+M)*5+:N*5]       = {N{5'b00010}};
                        a_RoPE[N*(i+M)*BW_FP+:N*BW_FP]  = W_sin[N*i*BW_FP+:N*BW_FP] ;
                        b_RoPE[N*(i+M)*BW_FP+:N*BW_FP]  = QK_proj[N*i*BW_FP+:N*BW_FP] ;
                    end
                end

                {3'd2}:begin  
                    for(i=0;i<M;i=i+1) begin
                        mode_RoPE[N*i*5+:N*5]       = {N{5'b00010}};
                        a_RoPE[N*i*BW_FP+:N*BW_FP]  = {N{17'h00580}} ;    // -1
                        b_RoPE[N*i*BW_FP+:N*BW_FP]  = FMA_out[N*(i+M)*BW_FP+:N*BW_FP] ; // Q1.2 sin
                    end

                    for(i=0;i<M;i=i+1) begin
                        mode_RoPE[N*(i+M)*5+:N*5]       = {N{5'b01000}};
                        a_RoPE[N*(i+M)*BW_FP+:N*BW_FP]  = buffer_RoPE_tmp[N*(i+M)*BW_FP+:N*BW_FP] ;  // Q1.1 sin
                        c_RoPE[N*(i+M)*BW_FP+:N*BW_FP]  = FMA_out[N*i*BW_FP+:N*BW_FP] ;   // Q1.2 cos
                    end
                end



                {3'd4}:begin  
                    for(i=0;i<M;i=i+1) begin
                        mode_RoPE[N*i*5+:N*5]       = {N{5'b01000}};
                        a_RoPE[N*i*BW_FP+:N*BW_FP]  = buffer_RoPE_tmp[N*i*BW_FP+:N*BW_FP]  ;
                        c_RoPE[N*i*BW_FP+:N*BW_FP]  = FMA_out[N*i*BW_FP+:N*BW_FP] ;
                    end
                end
                default: begin
                    a_RoPE = 'b0;
                    b_RoPE = 'b0;
                    c_RoPE = 'b0;
                    mode_RoPE = 'b0;
                end

            endcase
        end
        else begin
            a_RoPE = 'b0;
            b_RoPE = 'b0;
            c_RoPE = 'b0;
            mode_RoPE = 'b0;
        end
    end

    //store 
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            buffer_RoPE_tmp <= 'b0 ;
            buffer_RoPE     <= 'b0 ;
        end
        else if({busy1,cnt} == {1'b1,3'd2} ) begin
            buffer_RoPE_tmp <= FMA_out ;
        end
        else if({busy2,cnt} == {1'b1,3'd6} ) begin
            buffer_RoPE  <= FMA_out ;
        end
    end

// debug
    wire [N*BW_FP - 1 : 0] debug_b0 = b_RoPE[0*N*BW_FP+:N*BW_FP];
    wire [N*BW_FP - 1 : 0] debug_b1 = b_RoPE[1*N*BW_FP+:N*BW_FP];
    wire [N*BW_FP - 1 : 0] debug_b2 = b_RoPE[2*N*BW_FP+:N*BW_FP];
    wire [N*BW_FP - 1 : 0] debug_b3 = b_RoPE[3*N*BW_FP+:N*BW_FP];
    wire [N*BW_FP - 1 : 0] debug_b4 = b_RoPE[4*N*BW_FP+:N*BW_FP];
    wire [N*BW_FP - 1 : 0] debug_b5 = b_RoPE[5*N*BW_FP+:N*BW_FP];
    wire [N*BW_FP - 1 : 0] debug_b6 = b_RoPE[6*N*BW_FP+:N*BW_FP];
    wire [N*BW_FP - 1 : 0] debug_b7 = b_RoPE[7*N*BW_FP+:N*BW_FP];   
    wire [N*BW_FP - 1 : 0] debug_b8 = b_RoPE[8*N*BW_FP+:N*BW_FP];
    wire [N*BW_FP - 1 : 0] debug_b9 = b_RoPE[9*N*BW_FP+:N*BW_FP];
    wire [N*BW_FP - 1 : 0] debug_b10= b_RoPE[10*N*BW_FP+:N*BW_FP];
    wire [N*BW_FP - 1 : 0] debug_b11= b_RoPE[11*N*BW_FP+:N*BW_FP];  
    wire [N*BW_FP - 1 : 0] debug_b12= b_RoPE[12*N*BW_FP+:N*BW_FP];
    wire [N*BW_FP - 1 : 0] debug_b13= b_RoPE[13*N*BW_FP+:N*BW_FP];
    wire [N*BW_FP - 1 : 0] debug_b14= b_RoPE[14*N*BW_FP+:N*BW_FP];
    wire [N*BW_FP - 1 : 0] debug_b15= b_RoPE[15*N*BW_FP+:N*BW_FP];

endmodule
