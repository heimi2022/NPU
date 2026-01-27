//to 0-31 FMA_cal_top
module post_attn_norm_ctrl#(
    parameter BW_EXP   = 8   ,
    parameter BW_MAN   = 9   ,
    parameter BW_FP    = 17  ,
    parameter BW_INT   = 8   ,
    parameter VALUE_MN = 64
)(
    input                               clk                         ,
    input                               rst_n                       ,
    input                               state_select                , //0:decode 1:prefill
    input                               start_post_attn_norm_residual, //pulse
    input                               start_post_attn_norm_sqrt   ,

    input       [VALUE_MN*BW_FP -1:0]   O_proj                      , //8*8 or 1*64
    input       [VALUE_MN*BW_FP -1:0]   Z0                          , //8*8 or 1*64
    input       [VALUE_MN*BW_FP -1:0]   W_post_attn_norm            , //1*8(prefill) or 1*64(decode)
    input       [VALUE_MN*BW_FP -1:0]   FMA_out                     , 
    input       [VALUE_MN*BW_MAN -1:0]  int_part                    ,

    output                              busy                        ,
    output  reg [VALUE_MN*5     -1:0]   mode_post_attn_norm         ,
    output  reg [VALUE_MN*BW_FP -1:0]   a_post_attn_norm            ,
    output  reg [VALUE_MN*BW_FP -1:0]   b_post_attn_norm            ,
    output  reg [VALUE_MN*BW_FP -1:0]   c_post_attn_norm            ,

    output  reg [VALUE_MN*2*BW_FP -1:0] buffer_norm_out             , 
    output  reg                         rms_result_valid            ,
    output  reg                         scaled_x_valid              ,
    //store x*weight (this state) or final norm(last state)
    input       [VALUE_MN*BW_FP -1:0]   buffer_norm_in  

);
    localparam M = 8;
    localparam N = 8;
    localparam CYCLE1 = 5'd20 ;
    localparam CYCLE2 = 5'd3  ;
    reg [4:0] cnt ;
    reg [VALUE_MN*BW_FP -1:0] residual_out ;
    reg [BW_FP          -1:0] psum_norm     [0:M-1];
    reg [BW_FP          -1:0] alpha         [0:M-1];
    reg [BW_EXP         -1:0] alpha_exp     [0:M-1];

    reg rms_result_output_flag ;    

    reg busy1,busy2 ;
    assign busy = busy1 || busy2 ;

    integer i ;

    //state ctrl
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt   <= 'b0; 
            busy1 <= 'b0;
            busy2 <= 'b0;
        end 
        else begin
            if(start_post_attn_norm_residual) begin
                busy1 <= 1'b1;
                cnt   <=  'b0;
            end 
            else if(start_post_attn_norm_sqrt) begin
                busy2 <= 1'b1;
                cnt   <= 'b0 ;
            end 
            else if(busy1) begin
                if(cnt >= CYCLE1) begin
                    cnt   <= 'b0;
                    busy1 <= 'b0;
                end
                else 
                cnt <= cnt + 1;
            end 
            else if(busy2) begin
                if(cnt >= CYCLE2) begin
                    cnt   <= 'b0;
                    busy2 <= 'b0;
                end
                else 
                cnt <= cnt + 1;
            end
        end
    end

//state choose
// prefill   
//  .  .   1       2       3       4       5       6       7       8       9      10      11      12      13      14      15      16    
//     +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +
// clk |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
//     +   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+

//     |       |add    |       |square | mul   |add1   |       |add2   |       |add3   |       |add4   |       |       |       |       |       |mul    |
//     |       |residua|       | x^2   | w*x   |8*(8-4)|       |8*(4-2)|       |8*(2-1)|       |2-1    |       |       |       |       |       |*alpha |
//     |Input  |       |Input  |Input  |Input  |       |Input  |       |Input  |       |Input  |       |       |       |       |       |Input  |       |
//     |       |       |       |       |       |norm1  |       |       |       |       |       |       |psum   |       |       |       |       |       |norm1  |


// decode   
//  .  .   1       2       3       4       5       6       7       8       9      10      11      12      13      14      15      16      17
//     +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+
// clk |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
//     +   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+

//     |       |add    |       |square | mul   |add1   |       |add2   |       |add3   |       |add4   |       |add5   |       |add6   |       |add7   |mul    |
//     |       |residua|       | x^2   | w*x   |8*(8-4)|       |8*(4-2)|       |8*(2-1)|       |8-4    |       |4-2    |       |2-1    |       |2-1    |*alpha |
//     |Input  |       |Input  |Input  |Input  |       |Input  |       |Input  |       |Input  |       |Input  |       |Input  |       |Input  |Input  |
//     |       |       |       |       |       |norm1  |       |       |       |       |       |       |       |       |       |       |       |       |psum   |norm1  |


    always@(*) begin
        if(busy1) begin
            case({cnt})
                {5'd0}:begin  //0: INPUT RESIDUAL ADD
                    for(i=0;i<M;i=i+1) begin
                        mode_post_attn_norm[N*i*5+:N*5]       = {N{5'b01000}};
                        a_post_attn_norm[N*i*BW_FP+:N*BW_FP]  = O_proj[N*i*BW_FP+:N*BW_FP] ;
                        c_post_attn_norm[N*i*BW_FP+:N*BW_FP]  = Z0[N*i*BW_FP+:N*BW_FP] ;
                    end
                end

                {5'd2}:begin  //2:INPUT SQUARE
                    for(i=0;i<M;i=i+1) begin
                        mode_post_attn_norm[N*i*5+:N*5]       = {N{5'b00010}};
                        a_post_attn_norm[N*i*BW_FP+:N*BW_FP]  = FMA_out[N*i*BW_FP+:N*BW_FP] ;
                        b_post_attn_norm[N*i*BW_FP+:N*BW_FP]  = FMA_out[N*i*BW_FP+:N*BW_FP] ;
                    end
                end

                {5'd3}:begin  //3:INPUT MUL WEIGHT
                    for(i=0;i<M;i=i+1) begin
                        mode_post_attn_norm[N*i*5+:N*5]       = {N{5'b00010}};
                        a_post_attn_norm[N*i*BW_FP+:N*BW_FP]  = residual_out[N*i*BW_FP+:N*BW_FP] ;
                        b_post_attn_norm[N*i*BW_FP+:N*BW_FP]  = state_select ? W_post_attn_norm[N*BW_FP-1:0] : W_post_attn_norm[N*i*BW_FP+:N*BW_FP]  ;
                    end
                end

                {5'd4}:begin  //4: INPUT of ADD1 8*(8-4)
                    for(i=0;i<M;i=i+1) begin
                        mode_post_attn_norm[(N*i+N/2)*5 +:(N/2)*5]    = {(N/2){5'b01000}};
                        a_post_attn_norm[(N*i+N/2)*BW_FP+:(N/2)*BW_FP]= {FMA_out[(N*i+7)*BW_FP+:BW_FP] ,FMA_out[(N*i+5)*BW_FP+:BW_FP],
                                                                FMA_out[(N*i+3)*BW_FP+:BW_FP] ,FMA_out[(N*i+1)*BW_FP+:BW_FP] } ;
                        c_post_attn_norm[(N*i+N/2)*BW_FP+:(N/2)*BW_FP]= {FMA_out[(N*i+6)*BW_FP+:BW_FP] ,FMA_out[(N*i+4)*BW_FP+:BW_FP],
                                                                FMA_out[(N*i+2)*BW_FP+:BW_FP] ,FMA_out[(N*i+0)*BW_FP+:BW_FP] } ;
                    end
                end

                {5'd6}:begin  //6: INPUT of ADD2 8*(4-2) N=8
                    for(i=0;i<M;i=i+1) begin
                        mode_post_attn_norm[(N*i+3*N/4)*5 +:(N/4)*5]      = {(N/4){5'b01000}};
                        a_post_attn_norm[(N*i+3*N/4)*BW_FP+:(N/4)*BW_FP]  = {FMA_out[(N*i+7)*BW_FP+:BW_FP] ,FMA_out[(N*i+5)*BW_FP+:BW_FP]} ;
                        c_post_attn_norm[(N*i+3*N/4)*BW_FP+:(N/4)*BW_FP]  = {FMA_out[(N*i+6)*BW_FP+:BW_FP] ,FMA_out[(N*i+4)*BW_FP+:BW_FP]} ;
                    end
                end

                {5'd8}:begin  //8: INPUT of ADD3 8*(2-1) 
                    for(i=0;i<M;i=i+1) begin
                        mode_post_attn_norm[(N*i+7*N/8)*5 +:(N/8)*5]      = {(N/8){5'b01000}};
                        a_post_attn_norm[(N*i+7*N/8)*BW_FP+:(N/8)*BW_FP]  = FMA_out[(N*i+7)*BW_FP+:BW_FP] ;
                        c_post_attn_norm[(N*i+7*N/8)*BW_FP+:(N/8)*BW_FP]  = FMA_out[(N*i+6)*BW_FP+:BW_FP] ;
                    end
                end

                {5'd10}:begin  //10: INPUT of ADD4 8*(2-1) or 8-4
                    if(state_select) begin
                        for(i=0;i<M;i=i+1) begin
                            mode_post_attn_norm[(N*i+7)*5 +:5]      = {5'b01000};
                            a_post_attn_norm[(N*i+7)*BW_FP+:BW_FP]  = FMA_out[(N*i+7)*BW_FP+:BW_FP] ;
                            c_post_attn_norm[(N*i+7)*BW_FP+:BW_FP]  = psum_norm[i]                  ;
                        end
                    end else begin
                        for(i=0;i<4;i=i+1) begin
                            mode_post_attn_norm[(16*i+15)*5 +:5]      = {5'b01000};
                            a_post_attn_norm[(16*i+15)*BW_FP+:BW_FP]  = FMA_out[(16*i+15)*BW_FP+:BW_FP] ;
                            c_post_attn_norm[(16*i+15)*BW_FP+:BW_FP]  = FMA_out[(16*i+7 )*BW_FP+:BW_FP] ;
                        end
                    end
                end
                {5'd12}:begin  //12: INPUT of ADD5 4-2
                    if(!state_select) begin  //decode
                        mode_post_attn_norm[31*5 +:5]      = {5'b01000};
                        a_post_attn_norm[31*BW_FP+:BW_FP]  = FMA_out[31*BW_FP+:BW_FP] ;
                        c_post_attn_norm[31*BW_FP+:BW_FP]  = FMA_out[15*BW_FP+:BW_FP] ;
                        mode_post_attn_norm[63*5 +:5]      = {5'b01000};
                        a_post_attn_norm[63*BW_FP+:BW_FP]  = FMA_out[63*BW_FP+:BW_FP] ;
                        c_post_attn_norm[63*BW_FP+:BW_FP]  = FMA_out[47*BW_FP+:BW_FP] ;                            
                    end
                    else begin
                        a_post_attn_norm = 'b0;
                        b_post_attn_norm = 'b0;
                        c_post_attn_norm = 'b0;
                        mode_post_attn_norm = 'b0;
                    end
                end
                {5'd14}:begin  //14: INPUT of ADD6 2-1
                    if(!state_select) begin
                        mode_post_attn_norm[63*5 +:5]      = {5'b01000};
                        a_post_attn_norm[63*BW_FP+:BW_FP]  = FMA_out[63*BW_FP+:BW_FP] ;
                        c_post_attn_norm[63*BW_FP+:BW_FP]  = FMA_out[31*BW_FP+:BW_FP] ;                            
                    end
                    else begin
                        a_post_attn_norm = 'b0;
                        b_post_attn_norm = 'b0;
                        c_post_attn_norm = 'b0;
                        mode_post_attn_norm = 'b0;
                    end
                end
                {5'd16}:begin  //16: INPUT of ADD6 2-1
                    if(!state_select) begin
                        mode_post_attn_norm[63*5 +:5]      = {5'b01000};
                        a_post_attn_norm[63*BW_FP+:BW_FP]  = FMA_out[63*BW_FP+:BW_FP] ;
                        c_post_attn_norm[63*BW_FP+:BW_FP]  = psum_norm[0] ;
                    end
                    else begin
                        a_post_attn_norm = 'b0;
                        b_post_attn_norm = 'b0;
                        c_post_attn_norm = 'b0;
                        mode_post_attn_norm = 'b0;
                    end
                end
                {5'd17}:begin  //17: INPUT of mul alpha 
                    for(i=0;i<M;i=i+1) begin
                        mode_post_attn_norm[N*i*5+:N*5]       = {N{5'b00010}}   ;
                        a_post_attn_norm[N*i*BW_FP+:N*BW_FP]  = state_select ? {N{alpha[i]}} : {N{alpha[0]}} ;
                        b_post_attn_norm[N*i*BW_FP+:N*BW_FP]  = buffer_norm_in[N*i*BW_FP+:N*BW_FP] ;
                    end
                end
                default: begin
                    a_post_attn_norm = 'b0;
                    b_post_attn_norm = 'b0;
                    c_post_attn_norm = 'b0;
                    mode_post_attn_norm = 'b0;
                end
            endcase
        end

//  .  .   1       2       3       4       5       6       7       8       9      10      11      12      13      14      15      16    
//     +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +
// clk |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
//     +   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+

// mode|       |  SUB  |       | FMA   |       |       |       |       |       |       |       |       |       |       |       |
// op  |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |
// IN  | INPUT |       | INPUT |       |       |       |       |       |       |       |       |       |       |       |       |       
// OUT |       |       |       |       |alpha  |       |       |       |       |       |       |       |       |       |       |       
        else if(busy2) begin
            case({cnt})
                {5'd0}:begin 
                    for(i=0;i<M;i=i+1) begin
                        mode_post_attn_norm[N*i*5+:5]       = 5'b00001;
                        a_post_attn_norm[N*i*BW_FP+:BW_FP]  = {8'd7,psum_norm[i][BW_FP-1:BW_MAN],1'b0} ;
                        c_post_attn_norm[N*i*BW_FP+:BW_FP]  = psum_norm[i][BW_MAN] ? 
                                                            ((psum_norm[i][BW_MAN-1:0] == 9'b010000000) ? 17'h00a88 :17'h008f0)
                                                            :17'h00a80 ; //7.5/8.5/8
                    end
                end
                {5'd1}:begin
                    for(i=0;i<M;i=i+1) begin
                        mode_post_attn_norm[N*i*5+:5]       = 5'b00100; 
                        a_post_attn_norm[N*i*BW_FP+:BW_FP]  = psum_norm[i][BW_MAN] ? 
                                                              {(psum_norm[i][BW_MAN-1:0] == 9'b010000000) ? 17'h00480 : 
                                                               (psum_norm[i][BW_MAN-1:0] < 9'h0b4) ? 17'h0073c : 17'h00518 }
                                                              : {(psum_norm[i][BW_MAN-1:0] < 9'h0b4) ? 17'h00976 : 17'h0075c} ;

                        b_post_attn_norm[N*i*BW_FP+:BW_FP]  = {8'd0,psum_norm[i][BW_MAN-1:0]};

                        c_post_attn_norm[N*i*BW_FP+:BW_FP]  = psum_norm[i][BW_MAN] ? 
                                                              {(psum_norm[i][BW_MAN-1:0] == 9'b010000000) ? 17'd0 :
                                                               (psum_norm[i][BW_MAN-1:0] < 9'h0b4) ? 17'h006b0 : 17'h00694 }
                                                              : {(psum_norm[i][BW_MAN-1:0] < 9'h0b4) ? 17'h006f8 : 17'h06d1} ;
                    end
                end
                default: begin
                    a_post_attn_norm = 'b0;
                    b_post_attn_norm = 'b0;
                    c_post_attn_norm = 'b0;
                    mode_post_attn_norm = 'b0;
                end
            endcase
        end
        else begin
            a_post_attn_norm = 'b0;
            b_post_attn_norm = 'b0;
            c_post_attn_norm = 'b0;
            mode_post_attn_norm = 'b0;
        end
    end

    //store 
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            residual_out    <= 'b0 ;
            buffer_norm_out <= 'b0 ;
            scaled_x_valid  <= 1'b0 ;
            rms_result_valid    <= 1'b0 ;
            rms_result_output_flag <= 1'b0 ;
            for(i=0;i<M;i=i+1) begin
                psum_norm[i]    <= 'b0;
                alpha[i]        <= 'b0;
                alpha_exp[i]    <= 'b0;
            end 
        end
        else if({busy1,cnt} == {1'b1,5'd2} ) begin
            residual_out <= FMA_out ;
        end
        else if({busy1,cnt} == {1'b1,5'd5}) begin   // 输出分子乘权重
            buffer_norm_out[VALUE_MN*2*BW_FP -1:VALUE_MN*BW_FP] <= FMA_out;
            scaled_x_valid <= 1'b1 ;
        end
        else if({busy1,cnt} == {1'b1,5'd6} ) begin
            scaled_x_valid <= 1'b0 ;
        end
        else if({busy1,cnt} == {1'b1,5'd12} ) begin
            if(state_select) begin
                for(i=0;i<M;i=i+1) begin
                    psum_norm[i] <= FMA_out[(N*i+7)*BW_FP+:BW_FP] ;
                end 
            end
        end
        else if({busy1,cnt} == {1'b1,5'd18} ) begin
            if(!state_select) begin
                psum_norm[0] <= FMA_out[63*BW_FP+:BW_FP] ;
            end
        end
        else if({busy1,cnt} == {1'b1,5'd19} ) begin
            if(!rms_result_output_flag) begin
                buffer_norm_out[VALUE_MN*BW_FP -1:0] <= FMA_out;
                rms_result_output_flag <= 1'b1 ;
            end
            else begin
                buffer_norm_out[VALUE_MN*2*BW_FP -1:VALUE_MN*BW_FP] <= FMA_out;
                rms_result_valid <= 1'b1 ;
                rms_result_output_flag <= 1'b0 ;
            end
        end
        else if({busy1,cnt} == {1'b1,5'd20} ) begin
            rms_result_valid <= 1'b0 ;
        end

        else if({busy2,cnt} == {1'b1,5'd2} ) begin 
            for(i=0;i<8;i=i+1) begin
                psum_norm[i] <= 'b0 ;
                alpha_exp[i] <= int_part[N*i*BW_MAN +:(BW_MAN-1)];
            end 
        end         

        else if({busy2,cnt} == {1'b1,5'd3} ) begin 
            for(i=0;i<M;i=i+1) begin
                alpha[i] <=  {alpha_exp[i],FMA_out[N*i*BW_FP+:BW_MAN]};
            end 
        end
    end

endmodule

