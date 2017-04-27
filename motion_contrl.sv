module motion_contrl(start_conv,IR_in_en,IR_mid_en,IR_out_en,
chnnl,LEDs,lft,rht,clk,rst_n,go,cnv_cmplt,A2D_res);

// Input signals
input clk, rst_n;
input go, cnv_cmplt;
input [11:0] A2D_res;

// Output signals
output reg start_conv, IR_in_en, IR_mid_en, IR_out_en;
output reg [2:0] chnnl;
output reg [7:0] LEDs;
output reg [10:0] lft;
output reg [10:0] rht;

reg [2:0] nxt_chnnl;
reg [1:0] nxt_int_dec;
reg [1:0] int_dec;

// ALU internal signals
// Inputs for possible sources
reg [15:0] Accum;
reg [15:0] Pcomp;
reg [11:0] Icomp;
reg [13:0] Pterm;
reg [11:0] Iterm;
reg [11:0] Fwd;
reg [11:0] Error;
reg [11:0] Intgrl;
// Source select inputs
reg [2:0] src0sel;
reg [2:0] src1sel;
reg multiply; // Flag for multiplication of sources
reg sub; // Flag for subtraction of sources
reg mult2; // Flag for multiplying src0 by 2
reg mult4; // Flag for multiplying src0 by 4
reg saturate; // Flag for saturating the adder result

reg [15:0] dst; // Final result of ALU

// State number signals
typedef enum reg [3:0] {IDLE,PWM_EN_WAIT,A2D_CONV,ALU_CALC,
  WAIT_32,CALC_INT, CALC_ICOMP_1,CALC_ICOMP_2,CALC_PCOMP_1,
  CALC_PCOMP_2,CALC_ACCUM1,CALC_RHT,CALC_ACCUM2,CALC_LFT} state_t;
state_t state, nxt_state;

// Instantiate ALU module
alu THE_ALU(.Accum(Accum),.Pcomp(Pcomp),.Icomp(Icomp),
.Pterm(Pterm),.Iterm(Iterm),.Fwd(Fwd),.A2D_res(A2D_res),
.Error(Error),.Intgrl(Intgrl),.src0sel(src0sel),
.src1sel(src1sel),.multiply(multiply),.sub(sub),.mult2(mult2),
.mult4(mult4),.saturate(saturate),.dst(dst));

// Instantiate timer
reg en_tmr;
reg [12:0] timer;
motion_timer THE_TIMER(timer, en_tmr, clk);

/////////// infer state flops ///////////////
always_ff @(posedge clk, negedge rst_n)
 if (!rst_n) begin
  state <= IDLE;
  chnnl <= 0;
  int_dec <= 0;
 end
 else begin
  state <= nxt_state;
  chnnl <= nxt_chnnl;
  int_dec <= nxt_int_dec;
 end

always_ff @(posedge clk, negedge rst_n)
 if (!rst_n)
  Fwd <= 12'h000;
 else if (~go) // if go deasserted Fwd knocked down so
  Fwd <= 12'b000; // we accelerate from zero on next start.
 else if ((state == CALC_INT) & ~&Fwd[10:8]) // 43.75% full speed
  Fwd <= Fwd + 1'b1;

always_ff @(posedge clk, negedge rst_n)
 if (!rst_n) begin
  rht <= 12'h000;
  lft <= 12'h000;
 end
 else if (!go) begin
  rht <= 12'h000;
  lft <= 12'h000;
 end
 else if (state == CALC_RHT)
  rht <= dst[11:0];
 else if (state == CALC_LFT)
  lft <= dst[11:0];

always_comb
  LEDs = Error[11:4];

always_comb begin
 ///// default outputs //////
 if (!rst_n) begin
 nxt_state = IDLE;
 start_conv = 0;
 IR_in_en = 0;
 IR_mid_en = 0;
 IR_out_en = 0;
 nxt_chnnl = 0;
 nxt_int_dec = 0;

 Accum = 0;
 Pcomp = 0;
 Icomp = 0;
 Pterm = 14'h3680;
 Iterm = 12'h500;
 Error = 0;
 Intgrl = 0;
 src0sel = 0;
 src1sel = 0;
 multiply = 0; 
 sub = 0; 
 mult2 = 0;
 mult4 = 0;
 saturate = 0;

 en_tmr = 0;
 end

 // State logic
 case (state)
  IDLE : if (go) begin
   nxt_state = PWM_EN_WAIT;
   nxt_chnnl = 0;
   IR_in_en = 1;
   IR_mid_en = 0;
   IR_out_en = 0;
   en_tmr = 1;
  end
  else en_tmr = 0;
  
  PWM_EN_WAIT : begin
   if (timer == 4096) begin
    nxt_state = A2D_CONV;
    start_conv = 1;
   end
   else en_tmr = 1;
  end 

  A2D_CONV : begin
   if (cnv_cmplt) begin
    nxt_state = ALU_CALC;
    en_tmr = 0;
    start_conv = 0;
   end
  end

  ALU_CALC : begin
   if (chnnl == 0 && timer == 0) begin
    en_tmr = 1;
    src0sel = 0;
    src1sel = 0;
    Accum = A2D_res;
   end 
   if (chnnl == 2 && timer == 0) begin
    en_tmr = 1;
    multiply = 0;
    sub = 0;
    mult2 = 1;
    mult4 = 0;
    saturate = 0;
   end
   if (chnnl == 4 && timer == 0) begin
    en_tmr = 1;
    multiply = 0;
    sub = 0;
    mult2 = 0;
    mult4 = 1;
    saturate = 0;
   end
   if (chnnl == 1 && timer == 0) begin
    en_tmr = 1;
    multiply = 0;
    sub = 1;
    mult2 = 0;
    mult4 = 0;
    saturate = 0;
   end
   if (chnnl == 3 && timer == 0) begin
    en_tmr = 1;
    multiply = 0;
    sub = 1;
    mult2 = 1;
    mult4 = 0;
    saturate = 0;
   end
   if (chnnl == 5 && timer == 0) begin
    en_tmr = 1;
    multiply = 0;
    sub = 1;
    mult2 = 0;
    mult4 = 1;
    saturate = 1;
   end
   if (chnnl % 2 == 0 && timer == 2) begin
    if (chnnl != 0) Accum = dst;
    nxt_chnnl = chnnl + 1;    
    en_tmr = 0;
    nxt_state = WAIT_32;
   end
   if (chnnl == 1 && timer == 2) begin
    en_tmr = 0;
    Accum = dst;
    IR_mid_en = 1;
    IR_in_en = 0;
    nxt_chnnl = chnnl + 1;
    nxt_state = PWM_EN_WAIT;
   end
   if (chnnl == 3 && timer == 2) begin
    en_tmr = 0;
    Accum = dst;
    IR_mid_en = 0;
    IR_out_en = 1;
    nxt_chnnl = chnnl + 1;
    nxt_state = PWM_EN_WAIT;
   end
   if (chnnl == 5 && timer == 2) begin
    en_tmr = 0;
    Error = dst;
    nxt_state = CALC_INT;
   end
  end

  WAIT_32 : begin
   if (timer == 32) begin
    start_conv = 1;
    nxt_state = A2D_CONV; 
   end
   else en_tmr = 1;
  end
   
  // Complete each calculation in order   
  CALC_INT : begin
    src1sel = 3;
    src0sel = 1;
    multiply = 0;
    sub = 0;
    mult2 = 0;
    mult4 = 0;
    saturate = 1;
    nxt_int_dec = int_dec + 1;
    if (int_dec == 4) Intgrl = dst;
    nxt_state = CALC_ICOMP_1;
  end

  CALC_ICOMP_1 : begin
    src1sel = 1;
    src0sel = 1;
    multiply = 1;
    sub = 0;
    mult2 = 0;
    mult4 = 0;
    saturate = 1;
    nxt_state = CALC_ICOMP_2;
  end

  CALC_ICOMP_2 : begin
    Icomp = dst;
    nxt_state = CALC_PCOMP_1;
  end

  CALC_PCOMP_1 : begin
    src1sel = 2;
    src0sel = 4;
    multiply = 1;
    sub = 0;
    mult2 = 0;
    mult4 = 0;
    saturate = 0;
    nxt_state = CALC_PCOMP_2;
  end

  CALC_PCOMP_2 : begin
    Pcomp = dst;
    nxt_state = CALC_ACCUM1;
  end

  CALC_ACCUM1 : begin
    src1sel = 4;
    src0sel = 3;
    multiply = 0;
    sub = 1;
    mult2 = 0;
    mult4 = 0;
    saturate = 0;
    Accum = dst;
    nxt_state = CALC_RHT;
  end

  CALC_RHT : begin
    src1sel = 0;
    src0sel = 2;
    multiply = 0;
    sub = 1;
    mult2 = 0;
    mult4 = 0;
    saturate = 1;
    nxt_state = CALC_ACCUM2;
  end

  CALC_ACCUM2 : begin
    src1sel = 4;
    src0sel = 3;
    multiply = 0;
    sub = 0;
    mult2 = 0;
    mult4 = 0;
    saturate = 0;
    Accum = dst;
    nxt_state = CALC_LFT;
  end

  // default case = CALC_LFT
  default : begin
    src1sel = 0;
    src0sel = 2;
    multiply = 0;
    sub = 0;
    mult2 = 0;
    mult4 = 0;
    saturate = 1;
    nxt_state = IDLE;
  end

 endcase

end
endmodule


// Timer module
// timer is the output
// timer will be 0 when not enabled
// when enabled, timer will count up each positive clock edge
module motion_timer(timer, en_tmr, clk);
input en_tmr, clk;
output reg [12:0] timer;

always @ (posedge clk, negedge en_tmr) begin
  if (!en_tmr) timer <= 0;
  else timer <= timer + 1;
end

endmodule
