module motion_cntrl(strt_cnv, chnnl, IR_in_en, IR_mid_en, IR_out_en, LEDs, lft, rht,
		    go, cnv_cmplt, A2D_res, clk, rst_n);

output reg strt_cnv, 
       IR_in_en,
       IR_mid_en,
       IR_out_en;
output reg [2:0] chnnl;
output reg [7:0] LEDs;
output reg [10:0] lft,
                  rht;

input clk,
      rst_n,
      go,
      cnv_cmplt;
input [11:0] A2D_res;

typedef enum reg [3:0] {IDLE, STTL, INNER_R, MID_R, OUTER_R, SHRT_WAIT, INNER_L,
                        MID_L, OUTER_L, INTG, ITERM, PTERM, MRT_R1, MRT_R2,
                        MRT_L1, MRT_L2} state_t;

state_t state,
	nxt_state;

localparam DUTY_CYCLE = 8'h8C;
localparam CON_PTERM = 14'h3680;
localparam CON_ITERM = 12'h500;

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

reg [11:0] lft_reg,
           rht_reg,
           Fwd;

// ALU internal signals
// Inputs for possible sources
reg [15:0] Accum;
reg [15:0] Pcomp;
reg [11:0] Icomp;
reg [11:0] Error;
reg [11:0] Intgrl;
reg [13:0] Pterm;
reg [11:0] Iterm;
// Source select inputs
reg [2:0] src0sel;
reg [2:0] src1sel;
reg multiply; // Flag for multiplication of sources
reg sub; // Flag for subtraction of sources
reg mult2; // Flag for multiplying src0 by 2
reg mult4; // Flag for multiplying src0 by 4
reg saturate; // Flag for saturating the adder result

reg [15:0] dst; // Final result of ALU

reg dst2Accum,
    dst2Err,
    dst2Int,
    dst2Icmp,
    dst2Pcmp,
    dst2lft,
    dst2rht,
    clr_Accum;
// The following wires feed the flip flops that output the value specified by the name preceded by next_
wire [2:0] next_src0sel;
wire [2:0] next_src1sel;
wire  [7:0] next_PWM_cnt;
wire next_PWM_sig;
wire [15:0] next_Accum;
wire [11:0] next_Error;
wire [11:0] next_Intgrl;
wire [11:0] next_Icomp;
wire [15:0] next_Pcomp;
wire [11:0] next_lft_reg;
wire [11:0] next_rht_reg;
wire [1:0] next_int_dec;
wire next_w_cnt;
wire [11:0] next_Fwd;
wire [2:0]  next_chnnl;
wire next_sub;
wire next_multiply;
wire next_mult2;
wire next_mult4;
wire next_saturate;
wire [12:0] next_timer;
// Instantiate ALU module
alu THE_ALU(.Accum(Accum),.Pcomp(Pcomp),.Icomp(Icomp),
.Pterm(Pterm),.Iterm(Iterm),.Fwd(Fwd),.A2D_res(A2D_res),
.Error(Error),.Intgrl(Intgrl),.src0sel(src0sel),
.src1sel(src1sel),.multiply(multiply),.sub(sub),.mult2(mult2),
.mult4(mult4),.saturate(saturate),.dst(dst));


reg [7:0] PWM_cnt;
reg PWM_en,
    PWM_clr,
    PWM_sig;

reg [12:0] timer;
reg timer_en,
    timer_clr;

reg [1:0] int_dec;
reg inc_dec,
    int_dec_clr;

reg w_cnt,
    w_en,
    w_clr;

reg clr_c;

reg sel_A2D,
    sel_Int,
    sel_Icomp,
    sel_Pcomp,
    sel_Pterm;

reg sel_Accum,
    sel_Iterm,
    sel_Err,
    sel_ErrDiv,
    sel_Fwd;


// sourceselect0 ff
assign next_src0sel = sel_A2D ? A2D2Src0:
			sel_Int ?  Intgrl2Src0 :
			sel_Icomp ? Icomp2Src0 :
			sel_Pcomp ? Pcomp2Src0 :
			sel_Pterm ? Pterm2Src0 : src0sel;

always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		src0sel <= A2D2Src0;
	else
		src0sel <= next_src0sel;
end

assign next_src1sel = sel_Accum ? Accum2Src1 : 
			sel_Iterm ? Iterm2Src1 : 
			sel_Err	? Err2Src1 : 
			sel_ErrDiv ? ErrDiv22Src1 :
			sel_Fwd ? Fwd2Src1 : src1sel;


// sourceselect1 ff
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		src1sel <= Accum2Src1;
	else
		src1sel <= next_src1sel;
end



// state machine
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		state <= IDLE;
	else 
		state <= nxt_state;
end
    

// 8-bit PWM counter
assign next_PWM_cnt = (PWM_clr||PWM_cnt == 8'hF0) ? 8'h00 : 
			PWM_en ? ( PWM_cnt + 1'b1) : PWM_cnt;

always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		PWM_cnt <= 8'h00;
	else 
		PWM_cnt <= next_PWM_cnt;
end

// PWM generator w/ duty cycle of 8'h8C
assign next_PWM_sig = (PWM_cnt <= DUTY_CYCLE) ? 1'b1 : 1'b0;

always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		PWM_sig <= 1'b0;
	else
		PWM_sig <= next_PWM_sig;
end

// counter for cycles
assign next_timer = (timer_clr|| timer == 13'h1000) ? 13'h0000 :
			timer_en ? timer + 1'b1: timer;

always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		timer <= 13'h0000;
	else
		timer <= next_timer;
end

// flop for Accum
assign next_Accum = clr_Accum ? 16'h0000 : 
			dst2Accum ? dst[15:0] : Accum; 
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		Accum <= 16'h0000;
	else
		Accum <= next_Accum;
end

// flop for Error
assign next_Error = dst2Err ? dst[11:0] : Error;

always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		Error <= 12'h000;
	else
		Error <= next_Error;
end

// flop for Intgrl
assign next_Intgrl = dst2Int ? dst[11:0] : Intgrl;
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		Intgrl <= 12'h000;
	else
		Intgrl <= next_Intgrl;
end

// flop for Icmp
assign next_Icomp = dst2Icmp ? dst[11:0] : Icomp;
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		Icomp <= 12'h000;
	else
		Icomp <= next_Icomp;
end

// flop for Pcmp
assign next_Pcomp = dst2Pcmp ? dst[15:0] : Pcomp;
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		Pcomp <= 16'h0000;
	else
		Pcomp <= next_Pcomp;
end

// flop for lft
assign next_lft_reg = !go ? 12'h000 : 
			dst2lft ? dst[11:0] : lft_reg;
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		lft_reg <= 12'h000;
	else
		lft_reg <= next_lft_reg;
end

// flop for rht
assign next_rht_reg = !go ? 12'h000 : 
			dst2rht ? dst[11:0] : rht_reg;
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		rht_reg <= 12'h000;
	else
		rht_reg <= next_rht_reg;
end

// counter for intgrl to prevent intgrl to "run away"
assign next_int_dec = int_dec_clr ? 2'b00 :
			inc_dec ? int_dec + 1'b1 : int_dec;
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		int_dec <= 2'b00;
	else 
		int_dec <= next_int_dec;
end

// counter for multiplication (wait 2 cycles)
assign next_w_cnt = (w_clr || w_cnt == 1'b1) ? 1'b0 : 
			w_en ? w_cnt + 1'b1 : w_cnt;
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		w_cnt <= 1'b0;
	else 
		w_cnt <= next_w_cnt;
end

// ff for Fwd
assign next_Fwd = ~go ? 12'h000 : 
		   (dst2Int & ~&Fwd[10:8]) ? Fwd + 1'b1 : Fwd;
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		Fwd <= 12'h000;
	else 
		Fwd <= next_Fwd;
end

// chnnl reads from 1,0, 4, 2, 3, 7
// chnnl ff
reg set_c1,
    set_c0,
    set_c4,
    set_c2,
    set_c3,
    set_c7;
    

assign next_chnnl = (clr_c|set_c0) ? 3'h0 : 
			set_c1 ? 3'h1 :
			set_c2 ? 3'h2 :
			set_c3 ? 3'h3 :
			set_c4 ? 3'h4 :
			set_c7 ? 3'h7 : chnnl;

always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		chnnl <= 3'h0;
	else
		chnnl <= next_chnnl;
end

//////////////////////////////////////////////////
// ALU controls (ff)

// sub
reg clr_sub,
    set_sub;
assign next_sub = clr_sub ? 1'b0 :
		  set_sub ? 1'b1 : sub;
always@(posedge clk, negedge rst_n) begin
	if (~rst_n)
		sub <= 1'b0;
	else 
		sub <= next_sub;
	
end
// multiply
reg clr_mul,
    set_mul;

assign next_multiply = clr_mul ? 1'b0 : 
			set_mul ? 1'b1 : multiply;
always@(posedge clk, negedge rst_n) begin
	if (~rst_n)
		multiply <= 1'b0;
	else 
		multiply <= next_multiply;
	
end

// mult2
reg clr_mul2,
    set_mul2;
assign next_mult2 = clr_mul2 ? 1'b0 :
		    set_mul2 ? 1'b1 : mult2;
always@(posedge clk, negedge rst_n) begin
	if (~rst_n)
		mult2 <= 1'b0;
	else 
		mult2 <= next_mult2;
	
end

// mult4
reg clr_mul4,
    set_mul4;
assign next_mult4 = clr_mul4 ? 1'b0 :
		    set_mul4 ? 1'b1 : mult4;
always@(posedge clk, negedge rst_n ) begin
	if (~rst_n)
		mult4 <= 1'b0;
	else 
		mult4 <= next_mult4;
	
end

// saturate
reg clr_sat,
    set_sat;
assign next_saturate = clr_sat ? 1'b0 : 
			set_sat ? 1'b1 : saturate;
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		saturate <= 1'b0;
	else
		saturate <= next_saturate;
end

assign Pterm = CON_PTERM;
assign Iterm = CON_ITERM;
assign lft = lft_reg[11:1];
assign rht = rht_reg[11:1];
assign LEDs = Error[11:4];
// combinational logic and state transitions
always_comb begin
////////////////////////////////////////////
// default outputs
clr_c = 0; set_c0 = 0; set_c1 = 0; set_c4 = 0; set_c2 = 0; set_c3 = 0; set_c7 = 0;
timer_en = 0; timer_clr = 0;
strt_cnv = 0;
IR_in_en = 0; IR_mid_en = 0; IR_out_en = 0;
dst2Accum = 0; dst2Err = 0; dst2Int = 0; dst2Icmp = 0; dst2Pcmp = 0; dst2lft = 0; dst2rht = 0;
PWM_clr = 0; PWM_en = 0;
inc_dec = 0; int_dec_clr = 0;
w_clr = 0; w_en = 0;
clr_Accum = 0;
sel_A2D = 0; sel_Int = 0; sel_Icomp = 0; sel_Pcomp = 0; sel_Pterm = 0;
sel_Accum = 0; sel_Iterm = 0; sel_Err = 0; sel_ErrDiv = 0; sel_Fwd = 0;
clr_mul4 = 0; set_mul4 = 0;
clr_mul2 = 0; set_mul2 = 0;
clr_sub = 0; set_sub = 0;
clr_mul = 0; set_mul = 0;
clr_sat = 0; set_sat = 0;

nxt_state = IDLE;

case(state)
IDLE: begin
	if (go) begin
	  PWM_clr = 1;
	  clr_Accum = 1;
	  timer_clr = 1;
	  nxt_state = STTL;
	  set_c1 = 1;			// read from INNER_RHT
	end
end
STTL: begin

	nxt_state = STTL;
	PWM_en = 1;
	timer_en = 1;
	// PWM sig to enable 
	if (chnnl == 1)
		IR_in_en = PWM_sig;
	if (chnnl == 4)
		IR_mid_en = PWM_sig;
	if (chnnl == 3)
		IR_out_en = PWM_sig;
	// done waiting for 4096 clocks
	if (timer == 13'h1000) begin
		// start A2D conversion
		strt_cnv = 1;
		// transition to different state depending on chnnl
		if (chnnl == 1 ) begin
			sel_Accum = 1;		// src1 set to accum
			sel_A2D = 1;		// src0 set to A2D
			nxt_state = INNER_R;
		end
		if (chnnl == 4 ) begin
			sel_Accum = 1;		// src1 set to Accum
			sel_A2D = 1;		// will be added with A2Dres
			set_mul2 = 1;		// A2Dres will be multipled by 2 first
			clr_sub = 1;
			nxt_state = MID_R;
		end
		if (chnnl == 3 ) begin
			sel_Accum = 1;		// src1 set to Accum
			sel_A2D = 1;		// src0 set to A2Dres
			set_mul4 = 1;		// A2D will be multipled by 4 first
			clr_mul2 = 1;
			clr_sub = 1;
			nxt_state = OUTER_R;
		end
	end
end
INNER_R: begin
	PWM_en = 1;
	IR_in_en = PWM_sig;
	if (cnv_cmplt) begin
		set_c0 = 1;	// next read is from INNER_LFT
		dst2Accum = 1;	// result of Accum[0] + A2D goes to Accum
		nxt_state = SHRT_WAIT;
	end
	else
		nxt_state = INNER_R;
end
MID_R: begin
	PWM_en = 1;
	IR_mid_en = PWM_sig;
	if (cnv_cmplt) begin
		set_c2 = 1;	// next mid  chnnl is 2 (mid_lft)
		dst2Accum = 1; // result of Accum + A2D*2 is sent to accum
		nxt_state = SHRT_WAIT;
	end
	else
		nxt_state = MID_R;
end
OUTER_R: begin
	PWM_en = 1;
	IR_out_en = PWM_sig;
	if (cnv_cmplt) begin
		set_c7 = 1;   // next outer chnnl is 7 (out_lft)
		dst2Accum = 1;
		nxt_state = SHRT_WAIT;
	end
	else
		nxt_state = OUTER_R;
end
SHRT_WAIT: begin
	PWM_en = 1;
	nxt_state = SHRT_WAIT;
	timer_en = 1;
	// PWM sig to enable 
	if (chnnl == 0)
		IR_in_en = PWM_sig;
	if (chnnl == 2)
		IR_mid_en = PWM_sig;
	if (chnnl == 7)
		IR_out_en = PWM_sig;

	if (timer == 32) begin
		strt_cnv = 1;
		if (chnnl == 0) begin
			sel_Accum = 1;	// src1 is Accum
			sel_A2D = 1;	// src0 is A2D res
			set_sub = 1;	// sub the values
			nxt_state = INNER_L;
		end
		if (chnnl == 2) begin
			sel_Accum = 1;	// src1 is Accum
			sel_A2D = 1;	// src0 is A2D res
			set_sub = 1;	// sub the values
			set_mul2 = 1;   // mul A2D res by 2 before sub			
			nxt_state = MID_L;
		end
		if (chnnl == 7) begin
			sel_Accum = 1;	// src1 is Accum
			sel_A2D = 1;	// src0 is A2D res
			set_sub = 1;	// sub the values
			set_mul4 = 1;   // mul A2D res by 4 before sub	
			set_sat = 1;
			nxt_state = OUTER_L;
		end
	end
end
INNER_L: begin
	PWM_en = 1;
	IR_in_en = PWM_sig;
	if (cnv_cmplt) begin
		set_c4 = 1; 	 // next sensor to read is c4 (mid_rht)
		dst2Accum = 1;	// store value is accum
		nxt_state = STTL;
	end
	else
		nxt_state = INNER_L;
end
MID_L: begin
	PWM_en = 1;
	IR_mid_en = PWM_sig;
	if (cnv_cmplt) begin
		set_c3 = 1;      // next sensor to read is c3 (out_rht)
		dst2Accum = 1;	// dst to Accum
		nxt_state = STTL;
	end
	else
		nxt_state = MID_L;
end
OUTER_L: begin
	PWM_en = 1;
	IR_out_en = PWM_sig;
	if (cnv_cmplt) begin
		clr_c = 1;	// done reading channels so clear it
		dst2Err = 1;	// dst to Error
		nxt_state = INTG;
		// select source for next operation
		sel_ErrDiv = 1;
		sel_Int = 1;
		set_sat = 1;
		clr_sub = 1;
		clr_mul4 = 1;
	end
	else
		nxt_state = OUTER_L;
end
INTG: begin
	// increase int_dec (prevents intgrl from running away)
	inc_dec = 1;
	// only change intgrl after it has been evaluated 4 times
	if (int_dec == 3) begin
		dst2Int = 1;
		int_dec_clr = 1;
	end
	
	nxt_state = ITERM;
	// select sources and operation
	sel_Iterm = 1;
	sel_Int = 1;
	set_mul = 1;	
	clr_sat = 1;
end
ITERM: begin
	// stay in this state until 2 cycles have passed
	nxt_state = ITERM;
	// enable wait counter (2 cycles)
	w_en = 1;
	// only proceed to next state after 2 cycles
	if (w_cnt == 1) begin
		dst2Icmp = 1;
		w_clr = 1;
		nxt_state = PTERM;
		// select sources and operations
		sel_Err = 1;
		sel_Pterm = 1;
		set_mul = 1;
	end
end
PTERM: begin
	// stay in this state until 2 cycles have passed
	nxt_state = PTERM;
	// enable wait counter (2 cycles)
	w_en = 1;
	// only proceed to next state after 2 cycles
	if (w_cnt == 1) begin
		dst2Pcmp = 1;
		w_clr = 1;
		nxt_state = MRT_R1;
		// select source and operations
		sel_Fwd = 1;
		sel_Pcomp = 1;
		clr_mul = 1;
		set_sub = 1;
	end	
end
MRT_R1: begin
	nxt_state = MRT_R2;
	dst2Accum = 1;
	// select sources and operations
	sel_Accum = 1;
	sel_Icomp = 1;
	set_sub = 1;
	set_sat = 1;
end
MRT_R2: begin
	nxt_state = MRT_L1;
	// source and control for MRT_L1
	clr_sat = 1;
	clr_sub = 1;
	sel_Fwd = 1;
	sel_Pcomp = 1;
	dst2rht = 1;
end
MRT_L1: begin
	nxt_state = MRT_L2;
	dst2Accum = 1;
	// select sources and control for MRT_L2
	sel_Accum = 1;
	sel_Icomp = 1;	
	clr_sub = 1;
	set_sat = 1;	
end
MRT_L2: begin
	dst2lft = 1;
	clr_sat = 1;
end

endcase
end

endmodule
