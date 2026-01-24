`timescale 1ns/1ps
`define clk_period 20

module tb_fma_top;

    parameter                       BW_EXP      =   8                   ;
    parameter                       BW_MAN      =   9                   ;
    parameter                       BW_FP       =   17                  ;
    parameter                       BW_INT      =   8                   ;
    parameter                       BW_ALIGN    =   9                   ;
    parameter                       VALUE_MN    =   64                  ;
    parameter                       M           =   8                   ;
    parameter                       N           =   8                   ;
    parameter                       K           =   16                  ;

    localparam                      HEAD_DIM    =   64                  ;
    localparam                      HIDDEN_SIZE =   2048                ;

// instance signals
    reg                             clk                                 ;
    reg                             rst_n                               ;
    reg                             state_select                        ; //0:decode 1:prefill
    reg                             start_residual                      ; //pulse,from PE
    reg                             start_post_attn_norm_sqrt           ; //pulse,from PE
    reg                             start1_norm1                        ;
    reg                             start1_sum_norm1                    ;
    reg                             start2_norm1                        ;
    reg                             start1_RoPE                         ;
    reg                             start2_RoPE                         ;
    reg     [VALUE_MN*BW_FP -1:0]   O_proj                              ; //8*4 pipeline,from PE
    reg     [VALUE_MN*BW_FP -1:0]   Z0                                  ; //8*4 from SRAM,512b
    reg     [VALUE_MN*BW_FP -1:0]   W_post_attn_norm                    ; //1*4 or 1*32 from SRAM,64*8b
    reg     [M*K*BW_FP      -1:0]   Input_norm1                         ; //8*16 ,from SRAM
    reg     [K*BW_FP        -1:0]   W_norm1                             ; //prefill 1*16     
    reg     [VALUE_MN*BW_FP -1:0]   QK_proj                             ; 
    reg     [VALUE_MN*BW_FP -1:0]   W_cos                               ; 
    reg     [VALUE_MN*BW_FP -1:0]   W_sin                               ; 
    reg     [VALUE_MN*BW_FP -1:0]   buffer_post_attn_norm_in            ; //from SRAM,512b
    wire    [M*K     *BW_FP   -1:0] buffer_norm1_out                    ; //to SRAM,512b
    wire    [VALUE_MN*2*BW_FP   -1:0] buffer_post_attn_norm_out           ; //to SRAM,512b
    wire                            rms_result_valid                    ; // post_attn_norm
    wire                            scaled_x_valid                      ; // post_attn_norm
    wire    [VALUE_MN*2*BW_FP -1:0] buffer_RoPE                         ;
    wire                            busy_RoPE                           ;
    wire                            busy_post_attn_norm                 ;

// general tb signals
    integer                         i,j                                 ;
    reg                             rope_start                          ;
    reg                             post_attn_norm_start                ;
    reg     [6:0]                   seq_len                             ;

// rope
    reg     [BW_FP - 1:0]           sin                     [0:4095]    ; 
    reg     [BW_FP - 1:0]           cos                     [0:4095]    ;
    reg     [BW_FP - 1:0]           k_origin                [0:4095]    ; 
    reg     [BW_FP - 1:0]           q_origin                [0:4095]    ;

    real                            q_FMA_dec               [0:4095]    ;
    real                            k_FMA_dec               [0:4095]    ; 

    reg     [2:0]                   rope_head_dim_cnt                   ;
    reg                             busy_RoPE_r                         ;
    wire                            busy_RoPE_fall                      ;
    reg                             RoPE_stage1                         ;
    reg                             RoPE_stage2                         ;
    reg                             RoPE_result_check                   ;

// post_attn_norm
    reg     [BW_FP - 1:0]           l0_input                [0:131071]  ; 
    reg     [BW_FP - 1:0]           l0_O_proj               [0:131071]  ;
    reg     [BW_FP - 1:0]           post_attn_norm_weight   [0:2047]    ; 

    reg                             busy_post_attn_norm_r               ;
    wire                            busy_post_attn_norm_fall            ;
    reg     [7:0]                   post_attn_norm_hidden_size_cnt      ;
    reg                             post_attn_norm_ready                ;
    reg     [BW_FP - 1:0]           scaled_x                [0:16383]   ; // 8 * 2048 = 16384

    real                            post_attn_norm_result   [0:131071]  ; // 8 * 2048 = 16384

    reg     [3:0]                   post_attn_norm_seq_cnt              ; // seq 计数器  +1 表示 进8

// FSM
    reg     [4:0]                   state, next_state                   ;
    // state
    localparam [4:0] 
        IDLE                        =   5'd0    ,
        ROPE_STAGE1                 =   5'd1    ,
        ROPE_STAGE2                 =   5'd2    ,
        ROPE_RESULT_SAVE            =   5'd3    ,
        POST_ATTN_NORM_RESIDUAL     =   5'd4    ,
        POST_ATTN_NORM_SQRT         =   5'd5    ,
        POST_ATTN_NORM_RESULT_SAVE  =   5'd6    ,
        STOP                        =   5'd31   ;

/******************** inst_fma_top *********************************/ 
    fma_top #(
        .BW_EXP  (BW_EXP  ),
        .BW_MAN  (BW_MAN  ),
        .BW_FP   (BW_FP   ),
        .BW_INT  (BW_INT  ),
        .BW_ALIGN(BW_ALIGN),
        .VALUE_MN(VALUE_MN),
        .M       (M       ),
        .N       (N       ),
        .K       (K       )
    )inst_fma_top(
        .clk                        (clk                        ),
        .rst_n                      (rst_n                      ),
        .state_select               (state_select               ), // post_attn_norm:0:decode 1:prefill
        .start_residual             (start_residual             ), // post_attn_norm:pulse,from PE
        .start_post_attn_norm_sqrt  (start_post_attn_norm_sqrt  ), // post_attn_norm:pulse,from PE
        .start1_norm1               (start1_norm1               ),
        .start1_sum_norm1           (start1_sum_norm1           ),
        .start2_norm1               (start2_norm1               ),
        .start1_RoPE                (start1_RoPE                ),  // rope input
        .start2_RoPE                (start2_RoPE                ),  // rope input
        .O_proj                     (O_proj                     ),  // post_attn_norm input
        .Z0                         (Z0                         ),  // post_attn_norm input
        .W_post_attn_norm           (W_post_attn_norm           ),  // post_attn_norm input
        .Input_norm1                (Input_norm1                ),
        .W_norm1                    (W_norm1                    ),
        .QK_proj                    (QK_proj                    ),  // rope input
        .W_cos                      (W_cos                      ),  // rope input 
        .W_sin                      (W_sin                      ),  // rope input
        .buffer_post_attn_norm_in   (buffer_post_attn_norm_in   ),  // post_attn_norm sram 
        .buffer_norm1_out           (buffer_norm1_out           ),
        .buffer_post_attn_norm_out  (buffer_post_attn_norm_out  ),  // post_attn_norm sram
        .rms_result_valid           (rms_result_valid           ),
        .scaled_x_valid             (scaled_x_valid             ),
        .buffer_RoPE                (buffer_RoPE                ),  // rope output
        .busy_RoPE                  (busy_RoPE                  ),  // rope busy
        .busy_post_attn_norm        (busy_post_attn_norm        )   // post_attn_norm busy    
    );

/********************read and convert data*********************************/ 
    // rope
    // raw std BF16 storage
    reg [15:0]  sin_raw                     [0:4095]    ; 
    reg [15:0]  cos_raw                     [0:4095]    ;
    reg [15:0]  k_origin_raw                [0:4095]    ; 
    reg [15:0]  q_origin_raw                [0:4095]    ;
    reg [15:0]  k_rope_raw                  [0:4095]    ; 
    reg [15:0]  q_rope_raw                  [0:4095]    ;

    // std BF16 to Real storage
    real        sin_dec                     [0:4095]    ;
    real        cos_dec                     [0:4095]    ;
    real        k_origin_dec                [0:4095]    ;
    real        q_origin_dec                [0:4095]    ;
    real        k_rope_dec                  [0:4095]    ;
    real        q_rope_dec                  [0:4095]    ;

    // post_attn_norm
    reg [15:0]  l0_input_raw                [0:131071]  ;   // 64*2048=131072
    reg [15:0]  l0_O_proj_raw               [0:131071]  ;
    reg [15:0]  attn_residual_result_raw    [0:131071]  ; 
    reg [15:0]  post_attn_norm_result_raw   [0:131071]  ;
    reg [15:0]  post_attn_norm_weight_raw   [0:2047]    ; 

    // std BF16 to Real storage
    real        l0_input_dec                [0:131071]  ;   // 64*2048=131072
    real        l0_O_proj_dec               [0:131071]  ;
    real        attn_residual_result_dec    [0:131071]  ; 
    real        post_attn_norm_result_golden   [0:131071]  ;
    real        post_attn_norm_weight_dec   [0:2047]    ; 

    // $readmemb :loads a text file with binary values into a memory array
    initial begin
    // rope
        $readmemb("./rope_data/sin.txt", sin_raw);
        $readmemb("./rope_data/cos.txt", cos_raw);
        $readmemb("./rope_data/k_origin.txt", k_origin_raw);
        $readmemb("./rope_data/q_origin.txt", q_origin_raw);
        $readmemb("./rope_data/k_rope.txt", k_rope_raw);
        $readmemb("./rope_data/q_rope.txt", q_rope_raw);

        // Convert std BF16 to Real
        for (i = 0; i < 4096; i = i + 1) begin
            sin_dec[i]      = std_bf16_to_dec(sin_raw[i]);
            cos_dec[i]      = std_bf16_to_dec(cos_raw[i]);
            k_origin_dec[i] = std_bf16_to_dec(k_origin_raw[i]);
            q_origin_dec[i] = std_bf16_to_dec(q_origin_raw[i]);
            k_rope_dec[i]   = std_bf16_to_dec(k_rope_raw[i]);
            q_rope_dec[i]   = std_bf16_to_dec(q_rope_raw[i]);
        end

        // Convert dec to BF16
        for (i = 0; i < 4096; i = i + 1) begin
            sin[i]      = dec_to_bf16(sin_dec[i]);
            cos[i]      = dec_to_bf16(cos_dec[i]);
            k_origin[i] = dec_to_bf16(k_origin_dec[i]);
            q_origin[i] = dec_to_bf16(q_origin_dec[i]);
        end

    // post_attn_norm
        $readmemb("./layernorm_data/layer0_input_bf16.txt", l0_input_raw );
        $readmemb("./layernorm_data/layer0_attn_result_bf16.txt", l0_O_proj_raw );
        $readmemb("./layernorm_data/layer0_attn_residual_result_bf16.txt", attn_residual_result_raw);
        $readmemb("./layernorm_data/layer0_post_attention_layernorm_result_bf16.txt", post_attn_norm_result_raw );
        $readmemb("./layernorm_data/layer0_post_attention_layernorm_weight_bf16.txt", post_attn_norm_weight_raw );

        // Convert std BF16 to Real
        for (i = 0; i < 131072; i = i + 1) begin
            l0_input_dec[i]              = std_bf16_to_dec(l0_input_raw[i]);
            l0_O_proj_dec[i]             = std_bf16_to_dec(l0_O_proj_raw[i]);
            attn_residual_result_dec[i]  = std_bf16_to_dec(attn_residual_result_raw[i]);
            post_attn_norm_result_golden[i] = std_bf16_to_dec(post_attn_norm_result_raw[i]);
        end

        for (i = 0; i < 2048; i = i + 1) begin
            post_attn_norm_weight_dec[i] = std_bf16_to_dec(post_attn_norm_weight_raw[i]);
        end

        // Convert dec to BF16
        for (i = 0; i < 131072; i = i + 1) begin
            l0_input[i]  = dec_to_bf16(l0_input_dec[i]);
            l0_O_proj[i] = dec_to_bf16(l0_O_proj_dec[i]);
        end

        for (i = 0; i < 2048; i = i + 1) begin
            post_attn_norm_weight[i] = dec_to_bf16(post_attn_norm_weight_dec[i]);
        end
    end

/******************** RoPE ****************************/ 
    // negedge edge detect
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) 
            busy_RoPE_r <= 1'b0;
        else 
            busy_RoPE_r <= busy_RoPE;
    end
    assign busy_RoPE_fall = busy_RoPE_r && !busy_RoPE;

/************************** post_attn_norm ****************************/ 
    // negedge edge detect
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) 
            busy_post_attn_norm_r <= 1'b0;
        else 
            busy_post_attn_norm_r <= busy_post_attn_norm;
    end
    assign busy_post_attn_norm_fall = busy_post_attn_norm_r && !busy_post_attn_norm;


    // TODO  
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            state_select <= 1'b1;
        else
            state_select <= 1'b1;
    end

    // 模拟sram 存储 rms 分子
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for (i = 0; i < 16384; i = i + 1) begin
                scaled_x[i] <= 1'b0 ;
            end
        end
        else if (scaled_x_valid) begin
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    scaled_x[HIDDEN_SIZE*i + j + post_attn_norm_hidden_size_cnt*N] <= buffer_post_attn_norm_out[N*(i+M)*BW_FP + j*BW_FP +: BW_FP] ;
                end
            end
            if(post_attn_norm_seq_cnt == 1'd0 && post_attn_norm_hidden_size_cnt == 1'd1) begin
                for(i = 0; i < M; i = i + 1) begin
                    for (j = 0; j < N; j = j + 1) begin
                        $display("scaled_x[%0d]: %h", HIDDEN_SIZE*i + j + (post_attn_norm_hidden_size_cnt-1)*N, scaled_x[HIDDEN_SIZE*i + j + (post_attn_norm_hidden_size_cnt-1)*N]);
                    end
                end
            end
        end
    end

    // 模拟sram 存储 rms 结果
    always @(posedge clk or negedge rst_n) begin
        if (rms_result_valid) begin
            if(post_attn_norm_seq_cnt == 1'd1 && post_attn_norm_hidden_size_cnt == 1'd1) begin
                for (i = 0; i < M; i = i + 1) begin
                    for (j = 0; j < N; j = j + 1) begin
                        post_attn_norm_result[HIDDEN_SIZE*i + j + (post_attn_norm_hidden_size_cnt-1'd1)*N] = bf16_to_dec(buffer_post_attn_norm_out[N*i*BW_FP + j*BW_FP +: BW_FP]) ;
                        $display("post_attn_norm_result_golden[%0d]: %f", HIDDEN_SIZE*i + j + (post_attn_norm_hidden_size_cnt-1'd1)*N, post_attn_norm_result_golden[HIDDEN_SIZE*i + j + (post_attn_norm_hidden_size_cnt-1'd1)*N]);
                        $display("post_attn_norm_result[%0d]: %f", HIDDEN_SIZE*i + j + (post_attn_norm_hidden_size_cnt-1'd1)*N, post_attn_norm_result[HIDDEN_SIZE*i + j + (post_attn_norm_hidden_size_cnt-1'd1)*N]);
                    end
                end
            end
        end
    end

/******************** FSM ****************************/ 

    // update state
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) 
            state <= IDLE;
        else 
            state <= next_state;
    end

    // next state logic
    always @(*) begin
        case(state)
            IDLE: begin
                if(rope_start)
                    next_state = ROPE_STAGE1;
                else if(post_attn_norm_start)
                    next_state = POST_ATTN_NORM_RESIDUAL;
                else
                    next_state = IDLE;
            end
            ROPE_STAGE1:   
                next_state = busy_RoPE_fall ? ROPE_STAGE2 : ROPE_STAGE1 ;
            ROPE_STAGE2: 
                next_state = busy_RoPE_fall ? ROPE_RESULT_SAVE : ROPE_STAGE2 ;
            ROPE_RESULT_SAVE:
                next_state = STOP ;
            POST_ATTN_NORM_RESIDUAL : begin  
                if(busy_post_attn_norm_fall) begin
                    if(post_attn_norm_hidden_size_cnt == 8'd255)
                        next_state = POST_ATTN_NORM_SQRT ;
                    else
                        next_state = POST_ATTN_NORM_RESIDUAL ;
                end
                else
                    next_state = POST_ATTN_NORM_RESIDUAL ;
            end
            POST_ATTN_NORM_SQRT :
                next_state = busy_post_attn_norm_fall ? POST_ATTN_NORM_RESIDUAL : POST_ATTN_NORM_SQRT ;
            POST_ATTN_NORM_RESULT_SAVE :
                next_state = STOP ;
            STOP:    next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // rope fsm control
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            // RoPE init
            start1_RoPE <= 1'b0;
            start2_RoPE <= 1'b0;
            QK_proj     <= 1'b0;
            W_cos       <= 1'b0;
            W_sin       <= 1'b0;
            rope_head_dim_cnt <= 1'b0;
            RoPE_stage1 <= 1'd0;
            RoPE_stage2 <= 1'd0;
        end 
        else begin
            case(state)
                IDLE: begin
                    // RoPE
                    start1_RoPE <= 1'b0;
                    start2_RoPE <= 1'b0;
                    QK_proj     <= 1'b0;
                    W_cos       <= 1'b0;
                    W_sin       <= 1'b0;
                    rope_head_dim_cnt <= 1'b0;
                    RoPE_stage1 <= 1'd0;
                    RoPE_stage2 <= 1'd0;
                end
            // RoPE
                ROPE_STAGE1 : begin
                    if(!RoPE_stage1) begin
                        RoPE_stage1 <= 1'b1;
                        RoPE_stage2 <= 1'b0;

                        start1_RoPE <= 1'b1;
                        for(i = 0; i < M ; i = i + 1) begin
                            for(j = 0; j < N; j = j + 1) begin
                                QK_proj[N*i*BW_FP + j*BW_FP +: BW_FP] <= q_origin[HEAD_DIM*i + j + rope_head_dim_cnt*N];
                                W_cos[N*i*BW_FP + j*BW_FP +: BW_FP]   <= cos[HEAD_DIM*i + j + rope_head_dim_cnt*N];
                                W_sin[N*i*BW_FP + j*BW_FP +: BW_FP]   <= sin[HEAD_DIM*i + j + rope_head_dim_cnt*N];
                            end
                        end
                    end
                    else begin
                        start1_RoPE <= 1'b0;
                    end
                end
                ROPE_STAGE2 : begin
                    if(!RoPE_stage2) begin
                        RoPE_stage1 <= 1'b0;
                        RoPE_stage2 <= 1'b1;

                        start2_RoPE <= 1'b1;
                        for(i = 0; i < M ; i = i + 1) begin
                            for(j = 0; j < N; j = j + 1) begin
                                QK_proj[N*i*BW_FP + j*BW_FP +: BW_FP] <= q_origin[HEAD_DIM*i + j + rope_head_dim_cnt*N + 4* N];
                                W_cos[N*i*BW_FP + j*BW_FP +: BW_FP]   <= cos[HEAD_DIM*i + j + rope_head_dim_cnt*N + 4* N];
                                W_sin[N*i*BW_FP + j*BW_FP +: BW_FP]   <= sin[HEAD_DIM*i + j + rope_head_dim_cnt*N + 4* N];
                            end
                        end
                    end
                    else begin
                        start2_RoPE <= 1'b0;
                    end
                end
                ROPE_RESULT_SAVE: begin
                    for(i = 0; i < M ; i = i + 1) begin
                        for(j = 0; j < N; j = j + 1) begin
                            q_FMA_dec[HEAD_DIM*i + j + rope_head_dim_cnt*N] = bf16_to_dec(buffer_RoPE[N*i*BW_FP + j*BW_FP +: BW_FP]);
                            $display("q_FMA_dec[%0d]: %f", HEAD_DIM*i + j + rope_head_dim_cnt*N, q_FMA_dec[HEAD_DIM*i + j + rope_head_dim_cnt*N]);
                            $display("q_rope_dec[%0d]: %f", HEAD_DIM*i + j + rope_head_dim_cnt*N, q_rope_dec[HEAD_DIM*i + j + rope_head_dim_cnt*N]);
                            q_FMA_dec[HEAD_DIM*i + j + rope_head_dim_cnt*N + 4* N] = bf16_to_dec(buffer_RoPE[N*(i+M)*BW_FP + j*BW_FP +: BW_FP]);
                        end
                    end
                end
                default : begin
                    // RoPE
                    start1_RoPE <= 1'b0;
                    start2_RoPE <= 1'b0;
                    QK_proj     <= 1'b0;
                    W_cos       <= 1'b0;
                    W_sin       <= 1'b0;
                    rope_head_dim_cnt <= 1'b0;
                    RoPE_stage1 <= 1'd0;
                    RoPE_stage2 <= 1'd0;
                    RoPE_result_check <= 1'd0;
                end
            endcase
        end
    end

    // post_attn_norm fsm control
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            post_attn_norm_hidden_size_cnt <= 1'b0;
            start_residual <= 1'b0;
            start_post_attn_norm_sqrt <= 1'b0;
            post_attn_norm_ready <= 1'b0;
            O_proj <= 1'b0;
            Z0 <= 1'b0;
            buffer_post_attn_norm_in <= 1'b0;
            W_post_attn_norm <= 1'b0;
            post_attn_norm_seq_cnt <= 1'b0;
        end 
        else begin
            case(state)
                IDLE: begin
                    post_attn_norm_hidden_size_cnt <= 1'b0;
                    start_residual <= 1'b0;
                    start_post_attn_norm_sqrt <= 1'b0;
                    post_attn_norm_ready <= 1'b0;
                    O_proj <= 1'b0;
                    Z0 <= 1'b0;
                    buffer_post_attn_norm_in <= 1'b0;
                    W_post_attn_norm <= 1'b0;
                    post_attn_norm_seq_cnt <= 1'b0;
                end
                POST_ATTN_NORM_RESIDUAL : begin
                    if(!post_attn_norm_ready) begin
                        start_residual <= 1'b1;
                        post_attn_norm_ready <= 1'b1;
                        for(i = 0; i < M ; i = i + 1) begin
                            for(j = 0; j < N; j = j + 1) begin
                                O_proj[N*i*BW_FP + j*BW_FP +: BW_FP] <= l0_O_proj[HIDDEN_SIZE*(i + post_attn_norm_seq_cnt * 8) + j + post_attn_norm_hidden_size_cnt*N];
                                Z0[N*i*BW_FP + j*BW_FP +: BW_FP] <= l0_input[HIDDEN_SIZE*(i + post_attn_norm_seq_cnt * 8) + j + post_attn_norm_hidden_size_cnt*N];
                            end
                        end
                        for(j = 0; j < N; j = j + 1) begin
                            W_post_attn_norm[j*BW_FP +: BW_FP] <= post_attn_norm_weight[j + post_attn_norm_hidden_size_cnt*N];
                        end
                        if(post_attn_norm_seq_cnt == 8'd0) begin
                            for(i = 0; i < M ; i = i + 1) begin
                                for(j = 0; j < N; j = j + 1) begin
                                    buffer_post_attn_norm_in[N*i*BW_FP + j*BW_FP +: BW_FP] <= 1'b0;
                                end
                            end
                        end
                        else begin
                            for(i = 0; i < M ; i = i + 1) begin
                                for(j = 0; j < N; j = j + 1) begin
                                    buffer_post_attn_norm_in[N*i*BW_FP + j*BW_FP +: BW_FP] <= scaled_x[HIDDEN_SIZE*i+ j + post_attn_norm_hidden_size_cnt*N];
                                end
                            end
                        end
                    end
                    else if(busy_post_attn_norm_fall) begin
                        post_attn_norm_ready <= 1'd0;
                        post_attn_norm_hidden_size_cnt <= post_attn_norm_hidden_size_cnt + 1'd1;
                        if(post_attn_norm_hidden_size_cnt == 8'd255) begin
                            post_attn_norm_seq_cnt <= post_attn_norm_seq_cnt + 1'd1;
                        end
                    end
                    else begin
                        start_residual <= 1'b0;
                    end
                end
                POST_ATTN_NORM_SQRT: begin
                    if(!post_attn_norm_ready) begin
                        start_post_attn_norm_sqrt <= 1'b1;
                        post_attn_norm_ready <= 1'b1;
                    end
                    else if(busy_post_attn_norm_fall) begin
                        post_attn_norm_ready <= 1'd0;
                    end
                    else begin
                        start_post_attn_norm_sqrt <= 1'b0;
                    end
                end
                default : begin

                end
            endcase
        end
    end

/******************** test ****************************/ 
    reg [16:0] dec_to_bf16_test;
    real test_value_1;
    real test_value_2;
    real test_value_3;
    initial begin
        // dec_to_bf16_test = dec_to_bf16(5);
        // $display("dec_to_bf16_test: %b", dec_to_bf16_test);
        test_value_1 = bf16_to_dec(17'h1f769);
        $display("test_value1: %f", test_value_1);
        test_value_2 = bf16_to_dec(17'h1f483);
        $display("test_value2: %f", test_value_2);
        test_value_3 = ffp_to_dec(29'hfe75500);
        $display("test_value3: %f", test_value_3);
    end

/******************** initial ****************************/ 
	initial begin
		rst_n = 1'b0;
        rope_start = 1'b0;
        post_attn_norm_start = 1'b0;
        seq_len = 7'd16;
		#(`clk_period*5 + 1);
        rst_n = 1'b1;
		#(`clk_period);
        rope_start = 1'b0;
        post_attn_norm_start = 1'b1;
        #(`clk_period);
        rope_start = 1'b0;
        post_attn_norm_start = 1'b0;
        #(`clk_period*20000);
		$finish;		
	end
	
    // clock generation
	initial clk= 1;
	always#(`clk_period/2) clk = ~clk;

    initial begin
        $fsdbDumpfile("tb_fma_top.fsdb");
        $fsdbDumpvars(0, tb_fma_top);
        $fsdbDumpMDA();
    end
    
/******************* BF16 convert function **********************************/
    function real two_pow;
        input integer e;    
        integer i;
        real r;
        begin
            r = 1.0;
            if (e >= 0) begin
                for (i = 0; i < e; i = i + 1) r = r * 2.0;
            end else begin
                for (i = 0; i < -e; i = i + 1) r = r / 2.0;
            end
            two_pow = r;
        end
    endfunction

    // Convert standard bfloat16 to decimal real number
    function real std_bf16_to_dec;
        input [15:0] bf; // 16-bit BF16 code
        // locals
        int    sign_bit;
        int    exp8;
        int    mant7;
        int    bias;
        real   sign;
        real   mant_frac;
        real   value;
        begin
            bias = 127; // bfloat16 uses bias 127
            sign_bit = bf[15];
            exp8 = bf[14:7];
            mant7 = bf[6:0];

            sign = (sign_bit == 1) ? -1.0 : 1.0;

            if (exp8 == 8'h00) begin
                // zero or subnormal
                if (mant7 == 0) begin
                    // +0 or -0
                    value = 0.0 * sign; // keep signed zero if simulator supports it
                end else begin
                    // subnormal: value = sign * 2^(1-bias) * (mant / 2^7)
                    mant_frac = (real'(mant7)) / (2.0 ** 7); // mant7/2^7
                    value = sign * two_pow(1 - bias) * mant_frac;
                end
            end else if (exp8 == 8'hFF) begin
                // infinity or NaN
                if (mant7 == 0) begin
                    // infinity
                    // 1.0/0.0 typically yields +Inf in simulators
                    value = sign * (1.0 / 0.0);
                end else begin
                    // NaN
                    value = 0.0 / 0.0; // yields NaN in most simulators
                end
            end else begin
                // normalized: value = sign * 2^(exp-bias) * (1 + mant/2^7)
                mant_frac = 1.0 + (real'(mant7)) / (2.0 ** 7);
                value = sign * two_pow(exp8 - bias) * mant_frac;
            end

            std_bf16_to_dec = value;
        end
    endfunction

    // Function to convert decimal value to BF16 format
    function [BW_FP-1:0] dec_to_bf16;  //{exp+2 ,comp {sign 1 m}}
        input real value;
        reg sign;
        integer exp_val;
        reg [7:0] exp_biased;
        reg [7:0] man_val;
        reg [8:0] man_twos;
        real abs_val, fraction;
        begin
            // Handle zero
            if (value == 0.0) begin
                dec_to_bf16 = {9'b0, 9'b0};
                return;
            end
            
            // Extract sign
            sign = (value < 0);
            abs_val = (value < 0) ? -value : value;
            
            // Calculate exponent
            exp_val = 0;
            if (abs_val >= 1.0) begin
                while (abs_val >= 2.0) begin
                    abs_val = abs_val / 2.0;
                    exp_val = exp_val + 1;
                end
            end else begin
                while (abs_val < 1.0) begin
                    abs_val = abs_val * 2.0;
                    exp_val = exp_val - 1;
                end
            end
            
            // Convert to biased exponent (subtract bias as requested)
            exp_biased = exp_val + 2;  // Note: subtracting bias as per your requirement
            
            // Calculate mantissa (fraction part)
            fraction = abs_val ;//- 1.0; // Remove the implicit 1
            man_val = $rtoi(fraction * 128.0); // Scale to 8-bit fraction
            
            // Convert to 9-bit two's complement
            if (sign) begin
                man_twos = ~{1'b0, man_val} + 1;
            end else begin
                man_twos = {1'b0, man_val};
            end
            
            // Pack into BF16 format: [17:9] = exponent, [8:0] = mantissa
            dec_to_bf16 = {exp_biased, man_twos};
        end
    endfunction


  function real bf16_to_dec;
      input [BW_FP - 1:0] bf16_val;
      reg sign;
      real exp_val,exp_abs;
      reg [7:0] man_val;
      real fraction, result;
      begin
          // Extract components
          if (bf16_val[16]) begin
              // Negative: convert from two's complement
              exp_abs = $itor((~bf16_val[16:9] + 1) & 8'hFF) ;
              exp_val = -exp_abs ;
          end else begin
              // Positive
              exp_abs = $itor(bf16_val[16:9]) ;
              exp_val = exp_abs ;
          end
          //exp_val = $signed(bf16_val[16:9]);// + BIAS; // Add back bias
        
          man_val = bf16_val[7:0];
          sign = bf16_val[8]; // Sign bit is MSB of mantissa field
          
          // Handle zero
          if (bf16_val == 0) begin
              bf16_to_dec = 0.0;
              return;
          end
  
          if (sign) begin
              // Negative: convert from two's complement
              fraction = $itor((~{sign, man_val} + 1) & 9'h1FF) / 512.0;
          end else begin
              // Positive
              fraction = $itor(man_val) / 512.0;
          end

          result = (/*1.0 +*/ fraction) * (2.0 ** exp_val);
          bf16_to_dec = sign ? -result : result;
      end
  endfunction


  function real ffp_to_dec;
      input [28:0] bf16_val;
      reg sign;
      real exp_val,exp_abs;
      reg [17:0] man_val;
      real fraction, result;
      begin
          // Extract components
          if (bf16_val[28]) begin
              // Negative: convert from two's complement
              exp_abs = $itor((~bf16_val[28:19] + 1) & 10'h1FF) ;
              exp_val = -exp_abs ;
          end else begin
              // Positive
              exp_abs = $itor(bf16_val[28:19]) ;
              exp_val = exp_abs ;
          end
                  
          man_val = bf16_val[17:0];
          sign = bf16_val[18]; 

          // Handle zero
          if (bf16_val == 0) begin
              ffp_to_dec = 0.0;
              return;
          end
  
          if (sign) begin
              // Negative: convert from two's complement
              fraction = $itor((~{sign, man_val} + 1) & 19'h7FFFF) / (2**19);
          end else begin
              // Positive
              fraction = $itor(man_val) / (2**19);
          end

          result = (/*1.0 +*/ fraction) * (2.0 ** exp_val);
          ffp_to_dec = sign ? -result : result;
      end
  endfunction
endmodule
