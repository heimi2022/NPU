module DW_lsd (a, dec, enc);

parameter a_width = 8;

localparam addr_width = ((a_width>65536)?((a_width>16777216)?((a_width>268435456)?((a_width>536870912)?30:29):((a_width>67108864)?((a_width>134217728)?28:27):((a_width>33554432)?26:25))):((a_width>1048576)?((a_width>4194304)?((a_width>8388608)?24:23):((a_width>2097152)?22:21)):((a_width>262144)?((a_width>524288)?20:19):((a_width>131072)?18:17)))):((a_width>256)?((a_width>4096)?((a_width>16384)?((a_width>32768)?16:15):((a_width>8192)?14:13)):((a_width>1024)?((a_width>2048)?12:11):((a_width>512)?10:9))):((a_width>16)?((a_width>64)?((a_width>128)?8:7):((a_width>32)?6:5)):((a_width>4)?((a_width>8)?4:3):((a_width>2)?2:1)))));

input     [a_width-1:0] a;
output    [a_width-1:0] dec;
output [addr_width-1:0] enc;

// include modeling functions
// `include "DW_lsd_function.inc"

// calculate outputs
assign enc = DWF_lsd_enc (a);
assign dec = DWF_lsd (a);


function [addr_width-1:0] DWF_lsd_enc;


  input  [a_width-1:0] A;
  reg [addr_width-1:0] temp;
  reg done;
  integer i;

  begin
    done = 0;
    temp = a_width-1;   // default
    for (i=a_width-2; (done == 0) && (i >= 0); i=i-1) begin
      if ((A[i+1] === 1'bx) || (A[i] === 1'bx)) begin
        temp = {addr_width{1'bx}};
        done = 1;  // return "x" if "x" found first
      end
      else if (A[i+1] !== A[i]) begin
        temp = a_width - i - 2;
        done = 1;  // return first non-sign position
      end
    end
  
    DWF_lsd_enc = temp;

  end
endfunction // DWF_lsd_enc



function [a_width-1:0] DWF_lsd;

  input  [a_width-1:0] A;
  reg [addr_width-1:0] temp_enc;
  reg    [a_width-1:0] temp_dec;

  begin
    temp_enc = DWF_lsd_enc (A);
    temp_dec = {a_width{1'b0}};

    if (^temp_enc === 1'bx)
      temp_dec = {a_width{1'bx}};
    else
      temp_dec[a_width - temp_enc - 1] = 1'b1;

    DWF_lsd = temp_dec;
  end
endfunction // DWF_lsd
endmodule