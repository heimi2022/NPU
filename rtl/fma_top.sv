module fma_top#(
    parameter BW_EXP   = 8   ,
    parameter BW_MAN   = 9   ,
    parameter BW_FP    = 17  ,
    parameter BW_INT   = 8   ,
    parameter BW_ALIGN = 9   ,
    parameter VALUE_MN = 64  ,
    parameter M        = 8   ,
    parameter N        = 8   ,
    parameter K        = 16 
)(
    input                        clk                                ,
    input                        rst_n                              ,
    input                        state_select                       , //0:decode 1:prefill

    input                        start_residual                     , //pulse,from PE
    input                        start_post_attn_norm_sqrt          , //pulse,from PE
    input                        start1_norm1                       ,
    input                        start1_sum_norm1                   ,
    input                        start2_norm1                       ,
    input                        start1_RoPE                        ,
    input                        start2_RoPE                        ,

    input       [VALUE_MN*BW_FP -1:0]  O_proj                       , //8*4 pipeline,from PE
    input       [VALUE_MN*BW_FP -1:0]  Z0                           , //8*4 from SRAM,512b
    input       [VALUE_MN*BW_FP -1:0]  W_post_attn_norm             , //1*4 or 1*32 from SRAM,64*8b
    input       [M*K*BW_FP      -1:0]  Input_norm1                  , //8*16 ,from SRAM
    input       [K*BW_FP        -1:0]  W_norm1                      , //prefill 1*16     
    input       [VALUE_MN*BW_FP -1:0]  QK_proj                      , 
    input       [VALUE_MN*BW_FP -1:0]  W_cos                        , 
    input       [VALUE_MN*BW_FP -1:0]  W_sin                        , 
    input       [VALUE_MN*BW_FP -1:0]  buffer_post_attn_norm_in     , //from SRAM,512b

    output      [M*K     *BW_FP   -1:0]  buffer_norm1_out           , //to SRAM,512b
    output      [VALUE_MN*BW_FP   -1:0]  buffer_post_attn_norm_out  , //to SRAM,512b
    output                               rms_result_valid           ,
    output                               scaled_x_valid             ,
    output      [VALUE_MN*2*BW_FP -1:0]  buffer_RoPE                ,
    output                               busy_RoPE                  ,
    output                               busy_post_attn_norm                    
);

    //localparam BW_ALIGN = BW_MAN ; 
    wire                           busy_norm1  ;
    wire  [VALUE_MN *5       -1:0] mode_post_attn_norm  ;
    wire  [M*K      *5       -1:0] mode_norm1  ;    
    wire  [VALUE_MN *2*5     -1:0] mode_RoPE   ;
    wire  [M*K      *BW_FP   -1:0] a_norm1,b_norm1,c_norm1;
    wire  [VALUE_MN *BW_FP   -1:0] a_post_attn_norm,b_post_attn_norm,c_post_attn_norm;
    wire  [VALUE_MN *2*BW_FP -1:0] a_RoPE ,b_RoPE ,c_RoPE ;

    reg   [128*5     -1:0] mode        ;
    reg   [128*BW_FP -1:0] a,b,c       ;
    reg   [128*BW_MAN-1:0] align       ;
    wire  [128*BW_MAN-1:0] int_part    ;
    wire  [128*BW_INT-1:0] quat_int    ;
    wire  [128*BW_FP -1:0] frac        ;
    wire  [128*BW_EXP-1:0] scale       ;
    wire  [128*BW_FP -1:0] FMA_out     ;



    post_attn_norm_ctrl #(
        .BW_MAN   (BW_MAN   ) ,
        .BW_EXP   (BW_EXP   ) ,
        .BW_FP    (BW_FP    ) ,
        .BW_INT   (BW_INT   ) ,
        .VALUE_MN (VALUE_MN )
    )post_attn_norm_ctrl(
        //input
        .clk                            (clk                        ),
        .rst_n                          (rst_n                      ),
        .start_residual                 (start_residual             ),
        .start_post_attn_norm_sqrt      (start_post_attn_norm_sqrt  ),
        .state_select                   (state_select        ),

        .O_proj                         (O_proj              ),
        .Z0                             (Z0                  ),
        .W_post_attn_norm               (W_post_attn_norm    ),
        .FMA_out                        (FMA_out[0+:VALUE_MN*BW_FP]) ,

        //output
        .busy                           (busy_post_attn_norm),
        .mode_post_attn_norm            (mode_post_attn_norm),
        .a_post_attn_norm               (a_post_attn_norm   ),
        .b_post_attn_norm               (b_post_attn_norm   ),
        .c_post_attn_norm               (c_post_attn_norm   ),
        .buffer_norm_out                (buffer_post_attn_norm_out),
        .rms_result_valid               (rms_result_valid       ),
        .scaled_x_valid                 (scaled_x_valid         ),
        .buffer_norm_in                 (buffer_post_attn_norm_in)
    );

    // norm1_ctrl #(
    //     .BW_MAN   (BW_MAN   ) ,
    //     .BW_EXP   (BW_EXP   ) ,
    //     .BW_FP    (BW_FP    ) ,
    //     .BW_INT   (BW_INT   ) ,
    //     .M        (M        ) ,
    //     .K        (K        ) 
    // )u_norm1_ctrl(
    //     //input
    //     .clk                (clk                 ) ,
    //     .rst_n              (rst_n               ) ,
    //     .start1             (start1_norm1        ) ,
    //     .start1_sum         (start1_sum_norm1    ) ,
    //     .start2             (start2_norm1        ) ,
    //     .state_decode       (state_decode        ) ,
    //     .state_prefill      (state_prefill       ) ,

    //     .Input              (Input_norm1         ) ,
    //     .W_norm1            (W_norm1             ) ,
    //     .FMA_out            (FMA_out[0+:M*K*BW_FP]) ,

    //     //output
    //     .busy_norm1         (busy_norm1         ) ,
    //     .mode_post_attn_norm         (mode_norm1         ) ,
    //     .a_post_attn_norm            (a_norm1            ) ,
    //     .b_post_attn_norm            (b_norm1            ) ,
    //     .c_post_attn_norm            (c_norm1            ) ,
    //     .buffer_norm        (buffer_norm1_out   )
    // );
    assign busy_norm1 = 1'b0 ;


    RoPE_ctrl #(
        .BW_MAN   (BW_MAN   ) ,
        .BW_EXP   (BW_EXP   ) ,
        .BW_FP    (BW_FP    ) ,
        .BW_INT   (BW_INT   ) ,
        .VALUE_MN (VALUE_MN )
    )u_RoPE_ctrl(
        //input
        .clk                (clk                 ) ,
        .rst_n              (rst_n               ) ,
        .start1             (start1_RoPE         ) ,
        .start2             (start2_RoPE         ) ,
        .QK_proj            (QK_proj             ) ,
        .W_cos              (W_cos               ) ,
        .W_sin              (W_sin               ) ,
        .FMA_out            (FMA_out[0+:VALUE_MN*2*BW_FP]) ,

        //output
        .busy_RoPE          (busy_RoPE          ) ,
        .mode_RoPE          (mode_RoPE          ) ,
        .a_RoPE             (a_RoPE             ) ,
        .b_RoPE             (b_RoPE             ) ,
        .c_RoPE             (c_RoPE             ) ,
        .buffer_RoPE        (buffer_RoPE        )
    );    

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mode    <= 'b0 ;
            a       <= 'b0 ;
            b       <= 'b0 ;
            c       <= 'b0 ;
            align   <= 'b0 ;
        end 
        else begin
            case ({busy_post_attn_norm,busy_norm1,busy_RoPE})
                3'b001: begin
                    mode    <= {{((128-2*VALUE_MN)*5    ){1'b0}},mode_RoPE };
                    a       <= {{((128-2*VALUE_MN)*BW_FP){1'b0}},a_RoPE    };
                    b       <= {{((128-2*VALUE_MN)*BW_FP){1'b0}},b_RoPE    };
                    c       <= {{((128-2*VALUE_MN)*BW_FP){1'b0}},c_RoPE    };
                    align   <= 'b0 ;
                end
                3'b010: begin
                    mode    <= {{((128-M*K)*5    ){1'b0}},mode_norm1};
                    a       <= {{((128-M*K)*BW_FP){1'b0}},a_norm1   };
                    b       <= {{((128-M*K)*BW_FP){1'b0}},b_norm1   };
                    c       <= {{((128-M*K)*BW_FP){1'b0}},c_norm1   };
                    align   <= 'b0 ;
                end
                3'b100: begin
                    mode    <= {{((128-VALUE_MN)*5    ){1'b0}},mode_post_attn_norm};
                    a       <= {{((128-VALUE_MN)*BW_FP){1'b0}},a_post_attn_norm   };
                    b       <= {{((128-VALUE_MN)*BW_FP){1'b0}},b_post_attn_norm   };
                    c       <= {{((128-VALUE_MN)*BW_FP){1'b0}},c_post_attn_norm   };
                    align   <= 'b0 ;
                end
                default: begin
                    mode    <= 'b0 ;
                    a       <= 'b0 ;
                    b       <= 'b0 ;
                    c       <= 'b0 ;
                    align   <= 'b0 ;
                end
            endcase
        end
    end

    genvar i;
    generate for (i=0;i<128;i=i+1) begin: FMA_ARRAY
        FMA_cal_top #(
            .BW_ALIGN  (BW_ALIGN   ) ,
            .BW_EXP_IN (BW_EXP     ) ,
            .BW_MAN_IN (BW_MAN     ) ,
            .BW_INT    (BW_INT     )
        )u_FMA_top(
            .clk      (clk                           ) ,
            .rst_n    (rst_n                         ) ,
            .mode     (mode[5*i+:5]                  ) ,
            .a        (a[BW_FP*i+:BW_FP]             ) ,
            .b        (b[BW_FP*i+:BW_FP]             ) ,
            .c        (c[BW_FP*i+:BW_FP]             ) ,
            .align    (align[BW_MAN*i+:BW_MAN]       ) ,
            .z_norm   (FMA_out[BW_FP*i+:BW_FP]       ) ,
            .int_part (int_part[BW_MAN*i+:BW_MAN]    ) ,
            .quat_int (quat_int[BW_INT*i+:BW_INT]    ) ,
            .frac     (frac[BW_MAN*i+:BW_MAN]        ) ,
            .scale    (scale[BW_EXP*i+:BW_EXP]       ) 
        );
    end
    endgenerate


endmodule
