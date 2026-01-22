//in this version, exp and man of fp has been encoded
//z = (ab+c) >>> align
//c-a : QK-max
//a+c :sum
module FMA_cal#(
  parameter BW_ALIGN    = 9  ,
  parameter BW_EXP      = 8  ,
  parameter BW_MAN      = 9  ,
  parameter BW_PSUM_INT = 20  ,
  parameter BW_EXP_OUT  = 10 ,
  parameter BW_MAN_OUT  = 17  
)(
  clk   ,
  rst_n ,
  mode  ,
  a     ,        // sign1 exp9 man8
  b     ,
  c     ,
  align ,
  scale ,
  z
);

localparam BW_MUL = /*BW_MAN > BW_INT ? */BW_MAN; //: BW_INT ;
localparam BW_ADD_SUB = 2*BW_MUL > BW_PSUM_INT ? 2*BW_MUL : BW_PSUM_INT ;

input                             clk   ;
input                             rst_n ;
input   [4:0]                     mode  ;
input   [BW_MAN + BW_EXP   -1 :0] a     ;
input   [BW_MAN + BW_EXP   -1 :0] b     ;
input   [BW_MAN + BW_EXP   -1 :0] c     ;
input   [BW_ALIGN          -1 :0] align ;
output  reg [2*BW_MUL + BW_EXP +2 :0] z     ;
output  [BW_EXP -1:0] scale  ;




//state1 : a*b

//EX1:  unpack
wire [BW_MAN  -1:0] a_man = a[BW_MAN  -1:0] ;
wire [BW_MAN  -1:0] b_man = b[BW_MAN  -1:0] ;
wire [BW_MAN  -1:0] c_man = c[BW_MAN  -1:0] ;

wire [BW_EXP  -1:0] a_exp = a[BW_EXP+BW_MAN-1 :BW_MAN] ;
wire [BW_EXP  -1:0] b_exp = b[BW_EXP+BW_MAN-1 :BW_MAN] ;
wire [BW_EXP  -1:0] c_exp = c[BW_EXP+BW_MAN-1 :BW_MAN] ;

//EX2-3: path1 is mult

wire mul_flag =  mode[2] || mode[1] ;
wire [BW_MUL  -1:0] mul_a = a_man & {(BW_MUL){mul_flag}} ;// {{(BW_MUL-BW_MAN){a[BW_MAN-1]}}, a[BW_MAN  -1:0]} ;
wire [BW_MUL  -1:0] mul_b = b_man & {(BW_MUL){mul_flag}} ;// {{(BW_MUL-BW_MAN){b[BW_MAN-1]}}, b[BW_MAN  -1:0]} ;

wire [2*BW_MUL -1: 0] mul_out ;

DW02_mult #(
  .A_width( BW_MUL )  ,
  .B_width( BW_MUL )  
)u_systolic_mult(
  .A        (mul_a  ) ,
  .B        (mul_b  ) ,
  .TC       (1'b1   ) ,
  .PRODUCT  (mul_out  )
);

wire [2*BW_MUL -1: 0] mul_z = mode[0] ? {~a_man + 1'b1,{(2*BW_MUL-BW_MAN){1'b0}}} :
                              mul_flag ? mul_out : 
                              mode[3] ? {a_man,{(2*BW_MUL-BW_MAN){1'b0}}} : 'd0;


wire [BW_EXP :0] z_exp    ;

DW01_add #(
  .width (BW_EXP+1 )
)u_exp_add(
  .A    ({a_exp[BW_EXP-1],a_exp}) ,  
  .B    ({b_exp[BW_EXP-1],b_exp}) ,
  .CI   (1'b0),
  .SUM  (z_exp                ) ,
  .CO   ()
);

//EX2: e add
wire [BW_EXP :0] sum_exp  = mul_flag ? z_exp :
                            (mode[0] || mode[3]) ? {a_exp[BW_EXP-1],a_exp} 
                                                   : 'd0  ;

//EX3: e sub
wire             exp_flag = $signed(sum_exp) > $signed(c_exp) ;   
wire [BW_EXP :0] large_e  = exp_flag ? sum_exp : {c_exp[BW_EXP-1], c_exp};
wire [BW_EXP :0] small_e  = exp_flag ? {c_exp[BW_EXP-1], c_exp} : sum_exp;


wire [BW_EXP :0] sub_e_in0 = /*(state == SOFTMAX_SUB) ? {b_exp[BW_EXP-1],b_exp} : */
                             (mode[2] || mode[0] || mode[3]) ? large_e :
                              mode[4] ? {{(BW_EXP-3){1'b0}},4'b1000}
                                                    : 'd0 ;

wire [BW_EXP :0] sub_e_in1 = /*(state == SOFTMAX_SUB) ? {a_exp[BW_EXP-1],a_exp} : */
                             (mode[2] || mode[0] || mode[3]) ? small_e :
                              mode[4] ? {a_exp[BW_EXP-1],a_exp} 
                                                    :  'd0 ;

wire [BW_EXP :0] sub_e  ;

DW01_sub #(BW_EXP+1 )u_sub_e(
  .A    (sub_e_in0  ) ,
  .B    (sub_e_in1  ) ,
  .CI   (1'b0       ) ,
  .DIFF (sub_e      ) ,
  .CO   ()
);

assign scale = sub_e[BW_EXP -1:0] ;  

//EX4: align output : (AX+B)>>>Y
wire [BW_EXP+1 :0] align_add0 = mode[2] ?  {large_e[BW_EXP],large_e} :
                                mode[4] ?  {c_exp[BW_EXP-1],c_exp[BW_EXP-1],c_exp} : 'b0 ;
wire [BW_EXP+1 :0] align_add1 = mode[2] ?  { align[BW_MAN-1],align}  : 
                                mode[4] ? /* {{(BW_EXP-1){1'b0}},3'b110}*/{sub_e[BW_EXP],sub_e} :'b0;
wire [BW_EXP+1 :0] align_e;
DW01_add #(
  .width (BW_EXP+2 )
)u_exp_add2(
  .A    (align_add0 ) ,  
  .B    (align_add1 ) ,
  .CI   (1'b0       ) ,
  .SUM  (align_e    ) ,
  .CO   (           )
);

//wire [BW_EXP+1 :0] align_e    = {large_e[BW_EXP],large_e} +{ align[BW_MAN-1],align};

//EX4: MUX and align m
wire [2*BW_MUL -1: 0] large_m = /*(state == SOFTMAX_SUB) ? {~b_man + 1'b1,{(2*BW_MUL-BW_MAN){1'b0}}} :*/
                                 (mode[2] || mode[0] || mode[3]) ? 
                                {exp_flag ? mul_z :  {c_man,{(2*BW_MUL-BW_MAN){1'b0}}} } : 'b0 ;
wire [2*BW_MUL -1: 0] small_m = /*(state == SOFTMAX_SUB) ? {a_man,{(2*BW_MUL-BW_MAN){1'b0}}} : */
                                (mode[2] || mode[0] || mode[3]) ? 
                                {exp_flag ? {c_man,{(2*BW_MUL-BW_MAN){1'b0}}}  : mul_z } : 'b0 ;

wire [2*BW_MUL -1: 0] add_m   = $signed(small_m) >>> sub_e ;


//EX5:add/sub small-large/small+large
wire [2*BW_MUL :0] sum_m ;
DW01_add #(
  .width (2*BW_MUL+1 )
)u_man_add(
  .A    ({add_m[2*BW_MUL-1],add_m}      ) ,  
  .B    ({large_m[2*BW_MUL-1],large_m}  ) ,
  .CI   (1'b0),
  .SUM  (sum_m                          ) ,
  .CO   ()
);


//EX_final : output mux
wire [BW_EXP+1 :0] z_e = (mode[0] || mode[3]) ? large_e + 'd1 : 
                         mode[1] ? {sum_exp[BW_EXP],sum_exp}   :
                         mode[2] ? (align_e + 'd1) :  
                         mode[4] ? align_e: 'd0       ;
wire [2*BW_MUL :0] z_m = /*(state == SOFTMAX_SUB) ? {sum_m[2*BW_MUL-1:0],{(1){1'b0}}}:*/
                         mode[1] ? {mul_z,1'b0}  : 
                        (mode[2] || mode[0] || mode[3]) ? sum_m  : 
                         mode[4] ? {c_man,{(BW_MUL+1){1'b0}} }: 'd0 ;


always @(posedge clk or negedge rst_n)begin 
  if(!rst_n) z <= 'd0;
  else z <= {z_e,z_m} ;
end


endmodule
