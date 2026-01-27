module find_silu_coe#(
    parameter BW_EXP   = 8   ,
    parameter BW_MAN   = 9   ,
    parameter BW_FP    = 17  
)(     
    input       [BW_FP -1:0]  x           , 
    output      [BW_FP -1:0]  coe_a       ,
    output      [BW_FP -1:0]  coe_b       ,
    output      [BW_FP -1:0]  coe_c       

);


    wire [BW_EXP -1:0] a_e; 
    wire [BW_MAN -1:0] a_m;
    wire               a_s;

    assign {a_e,a_s,a_m} = x;

    wire [4:0] in_seg;



    // -16.0  to -1
    localparam coe_a0 = 17'h1f317; 
    localparam coe_b0 = 17'h1fd68; 
    localparam coe_c0 = 17'h0014c;

    // -1 to 1
    localparam coe_a1 = 17'h1fef1; 
    localparam coe_b1 = 17'h00280; 
    localparam coe_c1 = 17'h1e4a1;


    // 1 to 8
    localparam coe_a2 = 17'h1f77d; 
    localparam coe_b2 = 17'h0048f; 
    localparam coe_c2 = 17'h00128; 


 

     // <= -16
    //assign in_seg[0] = a_s && ($signed(a_e)>=6);

     // -16 to -1
    assign in_seg[1] = a_s && (a_e=='d2||a_e=='d3||a_e=='d4||a_e=='d5);

    // -1 to 1
    assign in_seg[2] = a_e[BW_EXP-1] || (a_e=='d1||a_e==0) ;

    // 1 to 8
    assign in_seg[3] = (!a_s) && (a_e=='d2||a_e=='d3||a_e=='d4);

    // >= 8
    assign in_seg[4] = (!a_s) && ($signed(a_e)>=5);


    assign coe_a = in_seg[1] ? coe_a0 : 
                   in_seg[2] ? coe_a1 : 
                   in_seg[3] ? coe_a2 : 0 ;

    assign coe_c = in_seg[1] ? coe_c0 : 
                   in_seg[2] ? coe_c1 : 
                   in_seg[3] ? coe_c2 : 0 ;

    assign coe_b = in_seg[1] ? coe_b0 : 
                   in_seg[2] ? coe_b1 : 
                   in_seg[3] ? coe_b2 : 
                   in_seg[4] ? 17'h00480 :0 ;





endmodule
