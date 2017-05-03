module alu(Accum, Pcomp, Icomp, Pterm, Iterm, Fwd, A2D_res, Error, Intgrl, src0sel, src1sel, 
	   multiply, sub, mult2, mult4, saturate, dst);

/************************************************************************************************************
* ALU for line reader. Preforms addition, subtraction, division by 2 and 4, 15x5 multiplication, and        *
* saturated versions addition, subtraction and multiplication. Various inputs are fed to the ALU from line  *
* reader. The inputs are selected with two mux. The inputs are mapped to either source 1 or 2 to preform    *
* the specified PI operation.                                                                               *
*                                                                                                           *
* In the long run, this module will be used to allow the machine to adjust and follow a white line and      *
* correct itself if necessary.                                                                              *
************************************************************************************************************/

localparam Accum2Src1 = 3'b000;
localparam Iterm2Src1 = 3'b001;
localparam Err2Src1 = 3'b010;
localparam ErrDiv22Src1 = 3'b011;
localparam Fwd2Src1 = 3'b100;

localparam A2D2Src0 = 3'b000;
localparam Intgrl2Src0 = 3'b001;
localparam Icomp2Src0 = 3'b010;
localparam Pcomp2Src0 = 3'b011;
localparam Pterm2Src0 = 3'b100;


// Inputs from the line reader/machine used in PI calculations
input [15:0] Accum, Pcomp;
input [13:0] Pterm;
input [11:0] Icomp, Iterm, Fwd, A2D_res, Error, Intgrl;

input [2:0] src0sel, src1sel;							// select signals for choosing sources
input multiply, sub, mult2, mult4, saturate;					// contorl signals for ALU

// internal wires used to hold src0 and src1 at various stages. Also used to hold ALU results.
wire signed [15:0] pre_src1, pre_src0, scaled_src0, src0;
wire signed [15:0] sum, mul_sat;
wire signed [11:0] sum_sat;
wire signed [14:0] rip_src1, rip_src0;
wire signed [29:0] mul_30 ;

output [15:0] dst;								// output of ALU

// assigning source1 according to the specifications (see Exercise04 pdf)
assign pre_src1 = (src1sel==Accum2Src1)   ? Accum :
	            (src1sel==Iterm2Src1)   ? {4'b0000,Iterm} :
	            (src1sel==Err2Src1)     ? {{4{Error[11]}},Error} :
	            (src1sel==ErrDiv22Src1) ? {{8{Error[11]}},Error[11:4]}:
	            (src1sel==Fwd2Src1)     ? {4'b0000,Fwd} :
					       16'h0000;

// assigning source0 according to the specifications (see Exercise04 pdf)
assign pre_src0 = (src0sel==A2D2Src0)    ? {4'b0000,A2D_res} :
	          (src0sel==Intgrl2Src0) ? {{4{Intgrl[11]}},Intgrl}:
	          (src0sel==Icomp2Src0)  ? {{4{Icomp[11]}},Icomp} :
	          (src0sel==Pcomp2Src0)  ? Pcomp:
	          (src0sel==Pterm2Src0)  ? {2'b00,Pterm} :
					   16'h0000;
// determines if source 0 should be multipled by 2, 4, or 1 (aka stays the same)
assign scaled_src0 = (mult2) ?	{pre_src0[14:0],1'b0} :
		     (mult4) ?  {pre_src0[13:0],2'b00} :
				 pre_src0;
// determines if source 0 should be complemented for subtraction later on
assign src0 = (sub) ? ~scaled_src0 :
		       scaled_src0;
// addition operation of ALU. If sub is specified then will have to add a 1 to complete 2's complement. 
assign sum = (sub) ? (pre_src1 + src0 + 1'b1) :
		     (pre_src1 + src0) ;
// determines if the sum should be saturated
assign sum_sat = (~sum[15] && sum > 16'h07FF) ? 16'h07FF :
		 (sum[15] && sum < 16'hF800 ) ? 16'hF800:
				  sum[11:0]; 
// ripping bits from source 1 and 0 to use for 15x15 multiplication
assign rip_src1 = pre_src1[14:0];
assign rip_src0 = src0[14:0];
// signed multiplication value without saturation
assign mul_30 = rip_src1*rip_src0;

// determines if the multiplication should be saturated
assign mul_sat = (mul_30[29]) ? ((&mul_30[28:26]) ? mul_30[27:12] : 16'hC000) : // if negative, sat to 0xC000
		                 ((|mul_30[28:26]) ? 16'h3FFF : mul_30[27:12]) ; // if positive, sat to 0x3FFF

// determines output based on control signals from saturate and multiply
assign dst = (multiply) ? mul_sat :
	     ((saturate) ? {{4{sum_sat[11]}}, sum_sat} : sum ) ;


endmodule
