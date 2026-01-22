module FMA_cal_top#(
  parameter BW_ALIGN     = 9  ,
  parameter BW_EXP_IN    = 8  ,
  parameter BW_MAN_IN    = 9  ,
  parameter BW_INT       = 8  
)(
  clk   ,
  rst_n ,
  mode  ,
  a     ,
  b     ,
  c     ,
  align ,
  //z     ,
  z_norm,
  int_part   ,
  frac  ,
  quat_int,
  scale
);

    localparam  BW_EXP_OUT = BW_EXP_IN     + 2        ; //10
    localparam  BW_MAN_OUT = 2*BW_MAN_IN   + 1        ; //19 [18:0]
    localparam  BW_OUT     = BW_EXP_OUT + BW_MAN_OUT  ;
    localparam  BW_IN      = BW_EXP_IN  + BW_MAN_IN   ;

    input                       clk   ;
    input                       rst_n ;
    input  [4:0]                mode  ;
    //input  [BW_IN    -1 :0]     sub   ; 
    output [BW_IN     -1 :0]     z_norm;
    output [BW_MAN_IN -1 :0]     int_part   ;
    output [BW_IN     -1 :0]     frac  ; 
    output [BW_INT    -1 :0]     quat_int   ;  
    output [BW_EXP_IN -1 :0]     scale  ;

    input  [BW_IN    -1 :0] a     ;
    input  [BW_IN    -1 :0] b     ;
    input  [BW_IN    -1 :0] c     ;
    input  [BW_ALIGN -1 :0] align ;
    wire   [BW_OUT   -1 :0] z     ;

    //wire  [BW_IN    -1 :0] z_norm;
    


  //  FMA_ctrl #(
  //    .BW_ALIGN (BW_ALIGN    ),
  //    .BW_EXP   (BW_EXP_IN   ),
  //    .BW_MAN   (BW_MAN_IN   ),
  //    .BW_INT   (BW_INT      )
  //  )u_FMA_ctrl(
  //    .clk    (clk    ) ,
  //    .rst_n  (rst_n  ) ,
  //    .state  (state  ) ,
  //    .z      (z_norm ) ,
  //    .sub    (sub    ) ,
  //    .a      (a      ) ,
  //    .b      (b      ) ,
  //    .c      (c      ) ,
  //    .align  (align  )
  //  );

    FMA_cal #(
      .BW_ALIGN   (BW_ALIGN    ),
      .BW_EXP     (BW_EXP_IN   ),
      .BW_MAN     (BW_MAN_IN   ),
      .BW_EXP_OUT (BW_EXP_OUT  ),
      .BW_MAN_OUT (BW_MAN_OUT  ) 
    )u_FMA_calculate(
      .clk    (clk    ) ,
      .rst_n  (rst_n  ) ,
      .mode   (mode   ) ,
      .a      (a      ) ,
      .b      (b      ) ,
      .c      (c      ) ,
      .align  (align  ) ,
      .scale  (scale  ) ,
      .z      (z      ) 
    );

    norm_round #(
      .EW     (BW_EXP_OUT ) ,
      .MW     (BW_MAN_OUT ) ,
      .EW_OUT (BW_EXP_IN  ) ,
      .MW_OUT (BW_MAN_IN  ) ,
      .BW_INT (BW_INT     )
    )u_norm_round(
      .clk         (clk       ) ,
      .rst_n       (rst_n     ) ,
      .mode        (mode      ) ,
      .a           (z         ) ,
      .z           (z_norm    ) ,
      .int_part    (int_part  ) ,
      .frac        (frac      ) ,
      .quat_int    (quat_int  ) 
    );
    

endmodule
