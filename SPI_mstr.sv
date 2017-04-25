module SPI_mstr(rd_data, done, SS_n, MOSI, SCLK, wrt, cmd, MISO, clk, rst_n);

// states
typedef enum reg [1:0]{IDLE, START, BACK_PORCH} state_t;

state_t state, nxt_state;

output [15:0] rd_data;			// data packet from slave
output  done,				// transaction complete
       	   SS_n,				// slave select 1 bit
           MOSI, 				// MASTER OUTPUT SLAVE INPUT
           SCLK;				// operating clk for transaction driven by master
       
input wrt,				// signal to load cmd to shift reg
      clk,				// System clock
      rst_n,				// async reset
      MISO;				// MASTER INPUT SLAVE OUTPUT

input [15:0] cmd;			// cmd to be loaded to shift register and sent to SLAVE

reg [15:0] shift_reg;			// 16 bit shift register for SPI master
reg shift;				// shift register should shift two system clocks after the rise of SCLK

reg [4:0] counter; 			// 5 bit counter for mod 5 (32 divison)
reg [5:0]  cycles; 			// counts how many shifts have occured

reg enable,				// enable the counter
    clr_cnt;				// clear both counter and cycles

reg SCLK_FF1, SCLK_FF2, SCLK_FF3;
reg sendMOSI, h_SS_n;


// sequential state logic
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		state <= IDLE;		// default state is IDLE
	else
		state <= nxt_state;
end

// Main shift register
always@(posedge clk) begin
	if(wrt)
		shift_reg <= cmd;		// load cmd into shift reg to begin transaction
	else if (shift)
		shift_reg <= {shift_reg[14:0], MISO};	// when shift is asserted shift MSB out and put MISO in LSB
end

// sequential counter for mod 32 division and cycle to keep track of how many bits has been shifted
always@(posedge clk) begin
 if (clr_cnt) begin
	counter <= 5'b11110;			// offset to have SCLK be high 2 clk cycles after SS_n has been pulled low
	cycles <= 6'b0000000;
 end
 else if (enable && counter == 5'b11111) begin	// reset counter when limit is reached (16 low and 16 high)
	counter <= 5'b00000;
	cycles <= cycles + 1;			// increment cycles so we know how many bits have been shifted
 end
 else if (enable)
	counter <= counter + 1;			// increment counter to get SCLK

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
done = 0;
SS_n = 1;
nxt_state = IDLE;
clr_cnt = 0;
enable = 0;


case (state)
IDLE: begin
  if (wrt) begin			// initiate MASTER SPI WRITE
      SS_n = 0;
      nxt_state = START;
      clr_cnt = 1;			// clears count and cycle so process starts smoothly
  end
end

START: begin
SS_n = 0;				// SS_n is pulled low for whole SPI transaction
  if (sendMOSI) begin
      enable = 1;
      nxt_state = START;
  end else if (cycles == 17)		// if cycle is 17, then transaction is complete proceed to last state where it makes sure SCLK is high before SS_n is high
      nxt_state = BACK_PORCH;
  else begin
      enable = 1;
      nxt_state = START;
  end
end

BACK_PORCH: begin
  if (h_SS_n) begin			// When SCLK has been high for 2 consecutive clock cycles then it will pull up SS_n and flag device that transfer is complete
      done = 1;
  end else begin
      SS_n = 0;
      nxt_state = BACK_PORCH;
end
end

default:  // default state
  nxt_state = IDLE;
endcase

end
endmodule
