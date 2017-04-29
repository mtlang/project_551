module alu(Accum,Pcomp,Icomp,Pterm,Iterm,Fwd,A2D_res,
Error,Intgrl,src0sel,src1sel,multiply,sub,mult2,
mult4,saturate,dst);

// Inputs for possible sources
input [15:0] Accum;
input [15:0] Pcomp;
input [11:0] Icomp;
input [13:0] Pterm;
input [11:0] Iterm;
input [11:0] Fwd;
input [11:0] A2D_res;
input [11:0] Error;
input [11:0] Intgrl;

// Source select inputs
input [2:0] src0sel;
input [2:0] src1sel;

input multiply; // Flag for multiplication of sources
input sub; // Flag for subtraction of sources
input mult2; // Flag for multiplying src0 by 2
input mult4; // Flag for multiplying src0 by 4
input saturate; // Flag for saturating the adder result

wire [15:0] pre_src0, pre_src1; // Selected sources unmodified
wire [15:0] scaled_src0; // Src0, possibly scaled
wire [15:0] src0, src1; // Src0 and Src1, as they are fed into the adder
wire [15:0] sum, sum_sat; // Result of adder, then possibly saturated
wire [14:0] msrc0, msrc1; // Src0 and Src1, as they are fed into the multiplier 
wire [29:0] big_prod; // Full 30-bit result
wire [14:0] prod_sat; // Saturated result of multiplier

output [15:0] dst; // Final result of ALU

// Descriptive names for select signals
localparam A2D2Src0 = 3'b000;
localparam Intgrl2Src0 = 3'b001;
localparam Icomp2Src0 = 3'b010;
localparam Pcomp2Src0 = 3'b011;
localparam Pterm2Src0 = 3'b100;

localparam Accum2Src1 = 3'b000;
localparam Iterm2Src1 = 3'b001;
localparam Err2Src1 = 3'b010;
localparam ErrDiv22Src1 = 3'b011;
localparam Fwd2Src1 = 3'b100;

// Descriptive names for 1 and 0
localparam YES = 1'b1;
localparam NO = 1'b0;

// Select sources
assign pre_src0 = (src0sel==A2D2Src0)	?	{4'b0000,A2D_res}:
   		  (src0sel==Intgrl2Src0)?	{{4{Intgrl[11]}},Intgrl}:
   		  (src0sel==Icomp2Src0)	? 	{{4{Icomp[11]}},Icomp}:
		  (src0sel==Pcomp2Src0)	? 	Pcomp:
   		  (src0sel==Pterm2Src0)	? 	{2'b00,Pterm}:
   						16'h0000;
assign pre_src1 = (src1sel==Accum2Src1)	?	Accum:
   		  (src1sel==Iterm2Src1) ?	{4'b0000,Iterm}:
   		  (src1sel==Err2Src1)	? 	{{4{Error[11]}},Error}:
		  (src1sel==ErrDiv22Src1)? 	{{8{Error[11]}},Error[11:4]}:
   		  (src1sel==Fwd2Src1)	? 	{4'b0000,Fwd}:
   						16'h0000;

// Scale src0 if needed
assign scaled_src0 = 	(mult2==YES)	?	{pre_src0[14:0],1'b0}:
			(mult4==YES)	?	{pre_src0[13:0],2'b00}:
						pre_src0;

// Invert src0 if needed
assign src0 = 	(sub==YES)	?	(~scaled_src0) + 1'b1:
					scaled_src0;

// Src1 is unmodified
assign src1 = pre_src1;

// Add sources
assign sum = src0 + src1;

// Saturate sum if needed
assign sum_sat = 	(saturate==YES && sum[15]==1'b0 && sum>16'h07FF)	?	16'h07FF:
			(saturate==YES && sum[15]==1'b1 && sum<16'hF800)	?	16'hF800:
											sum;
// Shorten sources for multiplication
assign msrc0 = src0[14:0];
assign msrc1 = src1[14:0];

// Multiply sources
assign big_prod = msrc0 * msrc1;

// Saturate product of sources
assign prod_sat = 	(big_prod[29]==YES && big_prod[28:26]!=3'b111)	?	16'hC000:
			(big_prod[29]==NO && big_prod[28:26]!=3'b000)	?	16'h3FFF:
										big_prod[27:12];

// Assign final output based on multiply flag
assign dst = 	(multiply==YES)	?	prod_sat:
					sum_sat;

endmodule