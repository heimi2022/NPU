module norm1_ctrl#(
    parameter BW_EXP   = 8   ,
    parameter BW_MAN   = 9   ,
    parameter BW_FP    = 17  ,
    parameter BW_INT   = 8   ,
    parameter M        = 8   ,
    parameter K        = 16 
)(
    input                         clk                 ,
    input                         rst_n               ,
    input                         state_prefill       ,
    input                         state_decode        ,
    input                         start1              , //pulse
    input                         start1_sum          ,
    input                         start2              ,

    input       [M*K*BW_FP -1:0]  Input               , //8*16 ,from SRAM
    input       [K*BW_FP   -1:0]  W_norm1             , //prefill 1*16
    input       [M*K*BW_FP -1:0]  FMA_out             , 
    
    output                        busy_norm1          ,
    output  reg [M*K*5     -1:0]  mode_norm1          ,
    output  reg [M*K*BW_FP -1:0]  a_norm1             ,
    output  reg [M*K*BW_FP -1:0]  b_norm1             ,
    output  reg [M*K*BW_FP -1:0]  c_norm1             ,
    output  reg [M*K*BW_FP -1:0]  buffer_norm    //to PE


);

    localparam CYCLE1 = 5'd18 ;
    localparam CYCLE2 = 5'd5  ;
    localparam CYCLE3 = 5'd3  ;

    reg [4:0] cnt ;
    reg [BW_FP          -1:0] psum_norm    [0:M-1]   ;
    reg [BW_FP          -1:0] alpha        [0:M-1]   ;

    reg busy1 , busy2, busy3 ;
    assign busy_norm1 = busy1 || busy2 || busy3 ;

    integer i ;

    //state ctrl
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt   <= 'b0; 
            busy1 <= 'b0;
            busy2 <= 'b0;
            busy3 <= 'b0;
        end else begin
            if(start1) begin
                busy1 <= 1'b1;
                cnt   <=  'b0;
            end else if(start1_sum) begin
                busy2 <= 1'b1;
                cnt   <= 'b0 ;
            end else if(start2) begin
                busy3 <= 1'b1;
                cnt   <= 'b0 ;
            end 
            
            else if(busy1) begin
                if(cnt == CYCLE1) begin
                    cnt   <= 'b0;
                    busy1 <= 'b0;
                end
                else cnt <= cnt + 1;
            end else if(busy2) begin
                if(cnt == CYCLE2) begin
                    cnt   <= 'b0;
                    busy2 <= 'b0;
                end
                else cnt <= cnt + 1;
            end else if(busy3) begin
                if(cnt == CYCLE3) begin
                    cnt   <= 'b0;
                    busy3 <= 'b0;
                end
                else cnt <= cnt + 1;
            end

        end
    end


//state choose for start1
// prefill   
//  .  .   1       2       3       4       5       6       7       8       9      10      11      12      13      14      15      16    
//     +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +
// clk |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
//     +   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+

//     |       |square | mul   |add1   |       |add2   |       |add3   |       |add4   |       |add5   |       |       |       |       |
//     |       | x^2   | w*x   |8* 16-8|       |8*(8-4)|       |8*(4-2)|       |8*(2-1)|       |8*(2-1)|       |       |       |       |
//     |Input  |Input  |Input  |       |Input  |       |Input  |       |Input  |       |Input  |       |       |       |       |       |
//     |       |       |       |normI  |       |       |       |       |       |       |       |       |psum   |       |       |       |


// decode   
//  .  .   1       2       3       4       5       6       7       8       9      10      11      12      13      14      15      16      17
//     +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+
// clk |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
//     +   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+

//     |       |square | mul   |add1   |       |add2   |       |add3   |       |add4   |       |add5   |       |       |       |       |
//     |       | x^2   | w*x   |8* 16-8|       |8*(8-4)|       |8*(4-2)|       |8*(2-1)|       |8*(2-1)|       |       |       |       |
//     |Input  |Input  |Input  |       |Input  |       |Input  |       |Input  |       |Input  |       |       |       |       |       |
//     |       |       |       |normI  |       |       |       |       |       |       |       |       |psum   |       |       |       |


    always@(*) begin

        if(busy1) begin
            case({cnt})
                {5'd1}:begin  //1:INPUT SQUARE 8*16
                    mode_norm1 = {N*K{5'b00010}}   ;
                    a_norm1    = Input ;
                    b_norm1    = Input ;
                end

                {5'd2}:begin  //2:INPUT MUL WEIGHT 8*16
                    mode_norm1 = {N*K{5'b00010}}   ;
                    a_norm1    = Input ;
                    for(i=0;i<M;i=i+1) begin
                        b_norm2[K*i*BW_FP+:K*BW_FP]  = state_prefill ? W_norm1[K*BW_FP-1:0] : 'b0  ;
                    end
                end

                {5'd3}:begin  //3: INPUT of ADD1 8*(16-8)  K=16
                    for(i=0;i<M;i=i+1) begin
                        mode_norm1[(K*i+8)*5 +:8*5]    = {8{5'b01000}};
                        a_norm1[(K*i+8)*BW_FP+:8*BW_FP]= {FMA_out[(K*i+15)*BW_FP+:BW_FP] ,FMA_out[(K*i+13)*BW_FP+:BW_FP],
                                                          FMA_out[(K*i+11)*BW_FP+:BW_FP] ,FMA_out[(K*i+9 )*BW_FP+:BW_FP],
                                                          FMA_out[(K*i+7 )*BW_FP+:BW_FP] ,FMA_out[(K*i+5 )*BW_FP+:BW_FP],
                                                          FMA_out[(K*i+3 )*BW_FP+:BW_FP] ,FMA_out[(K*i+1 )*BW_FP+:BW_FP] } ;
                        c_norm1[(K*i+8)*BW_FP+:8*BW_FP]= {FMA_out[(K*i+14)*BW_FP+:BW_FP] ,FMA_out[(K*i+12)*BW_FP+:BW_FP],
                                                          FMA_out[(K*i+10)*BW_FP+:BW_FP] ,FMA_out[(K*i+8 )*BW_FP+:BW_FP],
                                                          FMA_out[(K*i+6 )*BW_FP+:BW_FP] ,FMA_out[(K*i+4 )*BW_FP+:BW_FP],
                                                          FMA_out[(K*i+2 )*BW_FP+:BW_FP] ,FMA_out[(K*i+0 )*BW_FP+:BW_FP] } ;
                    end
                end

                {5'd5}:begin  //5: INPUT of ADD2 8*(8-4)
                    for(i=0;i<M;i=i+1) begin
                        mode_norm1[(K*i+12)*5 +:4*5]    = {4{5'b01000}};
                        a_norm1[(K*i+12)*BW_FP+:4*BW_FP]= {FMA_out[(K*i+15)*BW_FP+:BW_FP] ,FMA_out[(K*i+13)*BW_FP+:BW_FP],
                                                           FMA_out[(K*i+11)*BW_FP+:BW_FP] ,FMA_out[(K*i+9 )*BW_FP+:BW_FP]  } ;
                        c_norm1[(K*i+12)*BW_FP+:4*BW_FP]= {FMA_out[(K*i+14)*BW_FP+:BW_FP] ,FMA_out[(K*i+12)*BW_FP+:BW_FP],
                                                           FMA_out[(K*i+10)*BW_FP+:BW_FP] ,FMA_out[(K*i+8 )*BW_FP+:BW_FP] } ;
                    end
                end



                {5'd7}:begin  //7: INPUT of ADD3 8*(4-2) 
                    for(i=0;i<M;i=i+1) begin
                        mode_norm1[(K*i+14)*5 +:2*5]      = {2{5'b01000}};
                        a_norm1[(K*i+14)*BW_FP+:2*BW_FP]  = {FMA_out[(K*i+15)*BW_FP+:BW_FP] ,FMA_out[(K*i+13)*BW_FP+:BW_FP]} ;
                        c_norm1[(K*i+14)*BW_FP+:2*BW_FP]  = {FMA_out[(K*i+14)*BW_FP+:BW_FP] ,FMA_out[(K*i+12)*BW_FP+:BW_FP]} ;
                    end
                end

                {5'd9}:begin  //9: INPUT of ADD4 8*(2-1) 
                    for(i=0;i<M;i=i+1) begin
                        mode_norm1[(K*i+15)*5 +:1*5]      = {5'b01000};
                        a_norm1[(K*i+15)*BW_FP+:1*BW_FP]  = FMA_out[(K*i+15)*BW_FP+:BW_FP] ;
                        c_norm1[(K*i+15)*BW_FP+:1*BW_FP]  = FMA_out[(K*i+14)*BW_FP+:BW_FP] ;
                    end
                end

                {5'd11}:begin  //11: INPUT of ADD5 8*(2-1) prefill
                    if(state_prefill) begin
                        for(i=0;i<M;i=i+1) begin
                        mode_norm1[(K*i+15)*5 +:1*5]      = {5'b01000};
                        a_norm1[(K*i+15)*BW_FP+:1*BW_FP]  = FMA_out[(K*i+15)*BW_FP+:BW_FP] ;
                        c_norm1[(K*i+15)*BW_FP+:1*BW_FP]  = psum_norm[i] ;
                        end
                    end else if(state_decode) begin
                        //TODO
                    end
                end

              //  {5'd13}:begin  
              //          if(state_decode) begin
              //          end
                //  end

              //  {5'd15}:begin  
              //          if(state_decode) begin
              //          end
                //  end


              //  {5'd17}:begin 
              //          if(state_decode) begin
              //          end else
                //  end


                

                default: begin
                    a_norm2 = 'b0;
                    b_norm2 = 'b0;
                    c_norm2 = 'b0;
                    mode_norm2 = 'b0;
                end
            endcase


//  .  .   1       2       3       4       5       6       7       8       9      10      11      12      13      14      15      16    
//     +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +
// clk |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
//     +   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+

// mode|       |  SUB  |       | FMA   |       |       |       |       |       |       |       |       |       |       |       |
// op  |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |
// IN  | INPUT |       | INPUT |       |       |       |       |       |       |       |       |       |       |       |       |       
// OUT |       |       |       |       |alpha  |       |       |       |       |       |       |       |       |       |       |       


        end else if(busy2) begin
            case({cnt})

                {5'd1}:begin 
                    if(state_prefill) begin 
                        for(i=1;i<M;i=i+1) begin
                            mode_norm2[K*i*5+:5]       = 5'b00001;
                            a_norm2[K*i*BW_FP+:BW_FP]  = {8'd7,psum_norm[i][BW_FP-1:BW_MAN],1'b0} ;
                            c_norm2[K*i*BW_FP+:BW_FP]  = psum_norm[i][BW_MAN] ? 17'h008f0 ; 17'h00a88 ; //7.5/8.5
                        end
                    end
                    mode_norm2[0+:5]   = 5'b00001;
                    a_norm2[0+:BW_FP]  = {8'd7,psum_norm[0][BW_FP-1:BW_MAN],1'b0} ;
                    c_norm2[0+:BW_FP]  = psum_norm[0][BW_MAN] ? 17'h008f0 ; 17'h00a88 ; //7.5/8.5
                end

                {5'd3}:begin  
                    if(state_prefill) begin
                        for(i=1;i<M;i=i+1) begin
                            mode_norm2[K*i*5+:5]       = 5'b00100; 
                            a_norm2[K*i*BW_FP+:BW_FP]  = psum_norm[i][BW_MAN] ?  17'h0076a : 17'h006a5 ;
                            b_norm2[K*i*BW_FP+:BW_FP]  = {8'd0,psum_norm[i][BW_MAN-1:0]}        ;
                            c_norm2[K*i*BW_FP+:BW_FP]  = psum_norm[i][BW_MAN] ?  17'h0072c : 17'h006b5 ; 
                        end
                    end
                    mode_norm2[0+:5]   = 5'b00100; 
                    a_norm2[0+:BW_FP]  = psum_norm[0][BW_MAN] ?  17'h0076a : 17'h006a5 ;
                    b_norm2[0+:BW_FP]  = {8'd0,psum_norm[0][BW_MAN-1:0]}        ;
                    c_norm2[0+:BW_FP]  = psum_norm[0][BW_MAN] ?  17'h0072c : 17'h006b5 ; 

                end


                default: begin
                    a_norm2 = 'b0;
                    b_norm2 = 'b0;
                    c_norm2 = 'b0;
                    mode_norm2 = 'b0;
                end
            endcase
        end

//  .  .   1       2       3       4       5       6       7       8       9      10      11      12      13      14      15      16    
//     +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +
// clk |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
//     +   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+

// mode|       |  MUL  |       |       |       |       |       |       |       |       |       |       |       |       |       |
// op  |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |
// IN  | INPUT |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       
// OUT |       |       |normII |       |       |       |       |       |       |       |       |       |       |       |       |       



        end else if(busy3) begin
            case({cnt})

                {5'd1}:begin  //prefill 8*8
                    if(state_prefill) begin
                        mode_norm1 = {{(64*5){1'b0}},{(N*M){5'b00010}}}     ;
                        a_norm1    = {{(64*17){1'b0}},Input[M*N*BW_FP-1:0]} ;
                        b_norm1    = {{(64*17){1'b0}},{8{alpha[7]}},{8{alpha[6]}},{8{alpha[5]}},{8{alpha[4]}},
                                                  {8{alpha[3]}},{8{alpha[2]}},{8{alpha[1]}},{8{alpha[0]}} } ;
                    end
                end

                default: begin
                    a_norm2 = 'b0;
                    b_norm2 = 'b0;
                    mode_norm2 = 'b0;
                end
            endcase
        end
        
    end



    //store 
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            buffer_norm  <= 'b0 ;
            for(i=0;i<M;i=i+1) begin
                psum_norm[i]    <= 'b0 ;
            end 
        end

       
        else if({busy1,cnt} == {1'b1,5'd13} ) begin
            if(state_prefill) begin
                for(i=0;i<M;i=i+1) begin
                    psum_norm[i] <= FMA_out[(K*i+15)*BW_FP+:BW_FP] ;
                end 
            end
        end 

        else if({busy1,cnt} == {1'b1,5'd4} || {busy3,cnt} == {1'b1,5'd3}  ) begin
            buffer_norm <= FMA_out;
        end

        else if({busy2,cnt} == {1'b1,5'd3} ) begin 
            for(i=0;i<8;i=i+1) begin
                psum_norm[i] <= 'b0 ;
            end 
        end         

        else if({busy2,cnt} == {1'b1,5'd5} ) begin 
            for(i=0;i<M;i=i+1) begin
                alpha[i] <=  FMA_out[K*i*BW_FP+:BW_FP];
            end 
        end  


    end

endmodule
