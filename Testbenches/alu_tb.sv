module alu_tb;

// Inputs
reg [15:0] Accum;
reg [15:0] Pcomp;
reg [11:0] Icomp;
reg [13:0] Pterm;
reg [11:0] Iterm;
reg [11:0] Fwd;
reg [11:0] A2D_res;
reg [11:0] Error;
reg [11:0] Intgrl;
reg [2:0] src0sel;
reg [2:0] src1sel;
reg multiply;
reg sub;
reg mult2;
reg mult4;
reg saturate;

// Output
reg [15:0] dst;

// Parameters for readability
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

localparam YES = 1'b1;
localparam NO = 1'b0;

// Instantiate DUT
alu iDUT(.Accum(Accum),.Pcomp(Pcomp),.Icomp(Icomp),.Pterm(Pterm),
.Iterm(Iterm),.Fwd(Fwd),.A2D_res(A2D_res), .Error(Error),
.Intgrl(Intgrl),.src0sel(src0sel),.src1sel(src1sel),.multiply(multiply),
.sub(sub),.mult2(mult2),.mult4(mult4),.saturate(saturate),.dst(dst));

initial begin
// Simple case: add 11 and 22  
  src0sel = A2D2Src0;
  A2D_res = 12'h011;
  src1sel = Accum2Src1;
  Accum = 16'h0022;
  mult2 = NO;
  mult4 = NO;
  sub = NO;
  saturate = NO;
  multiply = NO;
  #25;
// Test other souces with simple addition
  src0sel = Intgrl2Src0;
  Intgrl = 12'h022;
  src1sel = Iterm2Src1;
  Iterm = 12'h022;
  #25;

  src0sel = Icomp2Src0;
  Icomp = 12'h022;
  src1sel = Err2Src1;
  Error = 12'h033;
  #25;

  src0sel = Pcomp2Src0;
  Pcomp = 16'h0033;
  src1sel = ErrDiv22Src1;
  Error = 12'h330;
  #25;
  
  src0sel = Pterm2Src0;
  Pterm = 14'h0044;
  src1sel = Fwd2Src1;
  Fwd = 12'h033;
  #25;
// Test src0 scaling
  Pterm = 14'h0011;
  Fwd = 12'h000;
  mult2 = YES;
  #25;

  mult2 = NO;
  mult4 = YES;
  #25;
// Test subtraction
  Pterm = 14'h0011;
  Fwd = 12'h022;
  sub = YES;
  mult4 = NO;
  #25;
// Test addition saturation
  src0sel = Icomp2Src0;
  Icomp = 12'h000;
  src1sel = Accum2Src1;
  Accum = 16'h7FFF;
  sub = NO;
  saturate = YES;
  #25;

  Icomp = 12'h000;
  Accum = 16'h8000;
  #25;
// Test multiplication (answer should be 51)
  Icomp = 12'h242;
  Accum = 16'h0242;
  multiply = YES;
  #25;

// Test multiplication with saturation
  src0sel = Pcomp2Src0;
  Pcomp = 16'h7FFF;
  Accum = 16'h7FFF;
  #25

  Pcomp = 16'hF000;
  Accum = 16'h8000;
  #25
end

endmodule