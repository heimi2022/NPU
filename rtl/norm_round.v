module norm_round #(
    //parameter SW        = 1   ,
    parameter EW        = 10  ,
    parameter MW        = 19  ,
    parameter EW_OUT    = 8   ,
    parameter MW_OUT    = 9   ,
    parameter BW_INT    = 8
    //parameter BW_STATUS = 3
)(
    clk   ,
    rst_n ,
    mode  ,
    a     ,
    z     ,
    int_part   ,
    frac  ,
    quat_int
);

    localparam                  BW         = /*BW_STATUS+SW+*/EW+MW;
    localparam        [EW-1:0]  BIAS       = 2 ** (EW - 1) - 1;
    localparam signed [EW-1:0]  BIAS_NEG   = -BIAS;

    input                       clk   ;
    input                       rst_n ;
    input      [4:0]            mode  ;
    input      [BW-1:0]         a     ;
    output /*reg*/ [EW_OUT+MW_OUT-1:0]         z     ;
    output     [EW_OUT+MW_OUT-1:0] frac ;
    output     [MW_OUT-1:0] int_part;
    output     [BW_INT-1:0] quat_int    ;

    //input  [2:0]            mode;

    wire                    a_s             ;
    wire [EW-1:0]           a_e             ;
    wire [MW-1:0]           a_m             ;
    wire                    a_e_is_zero     ;
    wire                    a_m_is_zero     ;
    wire                    a_e_is_max      ;
    wire [$clog2(MW)-1:0]   a_m_cls         ;
    wire                    z_s             ;
    wire [MW-1:0]           z_m             ;
    wire [EW-1:0]           z_e0            ;
    wire [EW-1:0]           z_e             ;
    wire [EW_OUT+MW_OUT-1:0]     z_d             ;
    wire [EW_OUT+MW_OUT-1:0]     z_o             ;
    wire                    a_is_zero       ;
 
    wire [MW-1:0]           a_m_sfl         ;
  
    assign {/*a_s,*/ a_e, a_m} = a;

   // assign z_s = a_s;

    wire [$clog2(MW)-1:0] a_m_cls_w;

    
    DW_lsd #(MW  )  // s1 + m
    u_cls(
        .a          (a_m[MW-1:0]        ), 
        .enc        (a_m_cls_w          ), 
        .dec()
    );
    assign a_m_cls =/* (~|a_m[MW-1:0]) ? 'd0 : */{a_m_cls_w};

     
    assign a_m_sfl = a_m <<< a_m_cls  ; 
    assign z_m = {a_m_sfl[MW-1:MW-2], a_m_sfl[MW-3:0]};
    assign z_e0 = a_e - {{(EW-$clog2(MW)){1'b0}}, a_m_cls} ;
    
    assign z_e  = z_e0;
    
  

    wire zero_flag = ~|a_m[MW-2:0];
    
    
    //assign z_d    = zero_flag ? 'd0 : {z_e[EW-1],z_e[EW_OUT-2:0], z_m[MW-1:MW-MW_OUT]};
    
    reg [EW_OUT-1:0] z_e_round;
    reg [MW_OUT-1:0] z_m_round;

    wire [MW-MW_OUT-1:0] z_m_pre_round = z_m[MW-MW_OUT-1:0];
    wire [MW_OUT-2:0] z_m_slice = z_m[MW-2:MW-MW_OUT];

    always @(*) begin
        if(z_m_pre_round[MW-MW_OUT-1]==1'b0) begin
            z_e_round = {z_e[EW-1],z_e[EW_OUT-2:0]};
            z_m_round = z_m[MW-1:MW-MW_OUT];
        end
        else if (|z_m_pre_round[MW-MW_OUT-2:0]!=0)begin
            //if(z_m[MW-1]&&(&z_m_slice)==1'b1)begin
            //    z_e_round = {z_e[EW-1],z_e[EW_OUT-2:0]};
            //    z_m_round = {1'b1,{(MW-1){1'b0}}};
            //end 
            if((~z_m[MW-1])&&(&z_m_slice)==1'b1) begin
                z_e_round = {z_e[EW-1],z_e[EW_OUT-2:0]}+'d1;
                z_m_round = {1'b0,1'b1,{(MW_OUT-2){1'b0}}};
            end
            else begin
                z_e_round = {z_e[EW-1],z_e[EW_OUT-2:0]};
                z_m_round = z_m[MW-1:MW-MW_OUT]+'d1;
            end
        end
        else begin
            if (z_m[MW-MW_OUT]==1'b0)begin
                z_e_round = {z_e[EW-1],z_e[EW_OUT-2:0]};
                z_m_round = z_m[MW-1:MW-MW_OUT];
            end 

            else begin
                //if(z_m[MW-1]&&(&z_m_slice)==1'b1)begin
                //    z_e_round = {z_e[EW-1],z_e[EW_OUT-2:0]};
                //    z_m_round = {1'b1,{(MW-1){1'b0}}};
                //end 
                if((~z_m[MW-1])&&(&z_m_slice)==1'b1) begin
                    z_e_round = {z_e[EW-1],z_e[EW_OUT-2:0]}+'d1;
                    z_m_round = {1'b0,1'b1,{(MW_OUT-2){1'b0}}};
                end
                else begin
                    z_e_round = {z_e[EW-1],z_e[EW_OUT-2:0]};
                    z_m_round = z_m[MW-1:MW-MW_OUT]+'d1;
                end
            end 
        end 
    end


   assign z_d = ~a_m[MW-1]&& zero_flag ? 'd0 : {z_e_round,z_m_round}; 


     assign z = z_d;

    wire [2*MW -1:0] tmp  = z[EW_OUT+MW_OUT-1] ? {{(MW+1){z_m[MW-1]}},z_m[MW-1:1]} >> ~z[MW_OUT+3:MW_OUT]
                                               : {{(MW){z_m[MW-1]}},z_m[MW-1:0]} << z[MW_OUT+3:MW_OUT]  ;

    //wire below1 = z[EW_OUT+MW_OUT-1] || zero_flag ;

    assign int_part  = /*zero_flag ? 'd0 :*/ {z_m[MW-1],tmp[MW+MW_OUT-2:MW]}   ;  
    assign frac      = /*zero_flag ? 'd0 :*/ {8'h01,1'b0,tmp[MW-1:MW-MW_OUT+1]} ;//e=1 ,m


    //how to round
    assign quat_int = int_part[BW_INT -1:0] + {{(BW_INT-1){1'b0}},tmp[MW-1]} ;


endmodule
