module alu_tb;

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

reg [15:0] dst;

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

alu iDUT(.Accum(Accum),.Pcomp(Pcomp),.Icomp(Icomp),.Pterm(Pterm),
.Iterm(Iterm),.Fwd(Fwd),.A2D_res(A2D_res), .Error(Error),
.Intgrl(Intgrl),.src0sel(src0sel),.src1sel(src1sel),.multiply(multiply),
.sub(sub),.mult2(mult2),.mult4(mult4),.saturate(saturate),.dst(dst));

initial begin
  src0sel = Pcomp2Src0;
  Pcomp = 16'h0022;
  src1sel = Accum2Src1;
  Accum = 16'h0033;
  mult2 = NO;
  mult4 = NO;
  sub = NO;
  saturate = NO;
  multiply = NO;
  #50;
end

endmodule