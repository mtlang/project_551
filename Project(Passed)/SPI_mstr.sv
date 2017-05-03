module SPI_mstr(rd_data, done, SS_n, MOSI, SCLK, wrt, cmd, MISO, clk, rst_n);

// states
typedef enum reg [1:0]{IDLE, START, BACK_PORCH} state_t;

state_t state, nxt_state;

output [15:0] rd_data;			// data packet from slave
output  reg done,				// transaction complete
       	   SS_n,				// slave select 1 bit
           MOSI, 				// MASTER OUTPUT SLAVE INPUT
           SCLK;				// operating clk for transaction driven by master
       
input wrt,				// signal to load cmd to shift reg
      clk,				// System clock
      rst_n,				// async reset
      MISO;				// MASTER INPUT SLAVE OUTPUT

input [15:0] cmd;			// cmd to be loaded to shift register and sent to SLAVE
wire [15:0] next_shift_reg;
reg [15:0] shift_reg;			// 16 bit shift register for SPI master
reg shift;				// shift register should shift two system clocks after the rise of SCLK
wire [4:0] next_counter;
wire [5:0] next_cycles;
reg inc_dcount;
reg clr_dcnt;
reg [4:0] counter; 			// 5 bit counter for mod 5 (32 divison)
reg [5:0]  cycles; 			// counts how many shifts have occured
reg [1:0] dcount;

reg enable,				// enable the counter
    clr_cnt;				// clear both counter and cycles

reg SCLK_FF1, SCLK_FF2, SCLK_FF3;
reg sendMOSI, h_SS_n;

reg wrt_again;

always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		dcount <= 2'b00;
	else if (inc_dcount)
		dcount <= dcount + 1'b1;
	else if (clr_dcnt)
		dcount <= 2'b00;
	else 
		dcount <= dcount;
end

// sequential state logic
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		state <= IDLE;		// default state is IDLE
	else
		state <= nxt_state;
end

// Main shift register
assign next_shift_reg = wrt||wrt_again ? cmd : 
			shift ? {shift_reg[14:0], MISO} : shift_reg;

always@(posedge clk or negedge rst_n) begin
	if(~rst_n)
		shift_reg <= 16'h0000;
	else 
		shift_reg <= next_shift_reg;	// when shift is asserted shift MSB out and put MISO in LSB
end


// sequential counter for mod 32 division and cycle to keep track of how many bits has been shifted
assign next_counter = clr_cnt ? 5'b11110 : 
		      (enable && counter == 5'b11111) ? 5'b00000: 
		      enable ? (counter + 5'b00001) : counter;

assign next_cycles = clr_cnt ? 6'b000000 : 
		     (enable && counter == 5'b11111) ? (cycles + 6'b000001) : cycles;

always@(posedge clk or negedge rst_n) begin
 if(~rst_n)
	counter <= 5'b00000;
 else 
	counter <= next_counter;// increment counter to get SCLK 
//might need reset logic in these 

end

always@(posedge clk or negedge rst_n) begin
 if(!rst_n)
	cycles <= 6'b000000;
 else
	cycles <= next_cycles; // increment counter to get SCLK

end


// sequential logic for SCLK for edge detection and when to assert various signals
always@(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
      SCLK_FF1 <= 1;
      SCLK_FF2 <= 1;
      SCLK_FF3 <= 1;
end
   else begin
      SCLK_FF1 <= SCLK;
      SCLK_FF2 <= SCLK_FF1;
      SCLK_FF3 <= SCLK_FF2;
end
	
end

assign sendMOSI = (SCLK_FF1 & SCLK_FF1) & ~SCLK_FF3;	// Send MOSI to slave if SCLK is 0,1,1 in the past 3 cycles (in that sequence) so 2 clks after SCLK went high
assign h_SS_n = SCLK_FF1 & SCLK_FF2;			// set SS_n high during last state if past SCLK was 1,1 (means two cycle has passed and can send SS_n high
assign SCLK = enable ? counter[4] : 1;			// SCLK is based of 4th bit of counter when enable is high, otherwise it is high
assign shift = (SCLK_FF1 & ~SCLK_FF2) ? 1 : 0;		// shift occurs at rising edge of SCLK same as was 0, 1.
assign rd_data = done ? shift_reg : rd_data;
assign MOSI = sendMOSI ? shift_reg[15] : MOSI;


// combinational logic
always_comb begin
// default values
done = 1'b0;
SS_n = 1'b1;
nxt_state = IDLE;
clr_cnt = 1'b0;
enable = 1'b0;
inc_dcount = 1'b0;
clr_dcnt = 1'b0;
wrt_again = 0;


case (state)
IDLE: begin
  if (wrt) begin			// initiate MASTER SPI WRITE
      SS_n = 1'b0;
      nxt_state = START;
      clr_cnt = 1'b1;			// clears count and cycle so process starts smoothly
      clr_dcnt = 1'b1;
  end
end

START: begin
SS_n = 1'b0;				// SS_n is pulled low for whole SPI transaction
  if (sendMOSI) begin
      enable = 1'b1;
      nxt_state = START;
  end else if (cycles == 6'b010001) begin		// if cycle is 17, then transaction is complete proceed to last state where it makes sure SCLK is high before SS_n is high
      nxt_state = BACK_PORCH;
  end
  else begin
      enable = 1'b1;
      nxt_state = START;
  end
end

BACK_PORCH: begin
  if (h_SS_n && dcount == 1) begin			// When SCLK has been high for 2 consecutive clock cycles then it will pull up SS_n and flag device that transfer is complete
	done = 1'b1;
  end 
  else if (dcount != 1) begin
      inc_dcount = 1'b1;
      SS_n = 1'b0;
      nxt_state = START;
      clr_cnt = 1;
      wrt_again = 1;
end
  else begin
      SS_n = 1'b0;
      nxt_state = BACK_PORCH;
  end
end

default:  // default state
  nxt_state = IDLE;
endcase

end
endmodule
