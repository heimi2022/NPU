module DW02_mult(A,B,TC,PRODUCT);
parameter	integer A_width = 8;
parameter	integer B_width = 8;
   
input	[A_width-1:0]	A;
input	[B_width-1:0]	B;
input			TC;
output	[A_width+B_width-1:0]	PRODUCT;

wire	[A_width+B_width-1:0]	PRODUCT;

wire	[A_width-1:0]	temp_a;
wire	[B_width-1:0]	temp_b;
wire	[A_width+B_width-2:0]	long_temp1,long_temp2;


//取 绝对值
assign	temp_a = (A[A_width-1])? (~A + 1'b1) : A;
assign	temp_b = (B[B_width-1])? (~B + 1'b1) : B;

assign	long_temp1 = temp_a * temp_b;
assign	long_temp2 = ~(long_temp1 - 1'b1);
 
// (1) 异常检测 (2) 判断是否启用有符号模式 (3) 有符号乘法的正负处理
assign	PRODUCT = ((^(A ^ A) !== 1'b0) || (^(B ^ B) !== 1'b0) || (^(TC ^ TC) !== 1'b0) ) ? {A_width+B_width{1'bX}} :
		  (TC)? (((A[A_width-1] ^ B[B_width-1]) && (|long_temp1))?
			 {1'b1,long_temp2} : {1'b0,long_temp1})
		     : A * B;

endmodule
