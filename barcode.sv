/**************************************************************************** 
* Barcode Reader: ECE 551 HW 4                                              *
* 									    *
* Inputs:                                                                   *
* BC - Serial data from IR sensor.					    *
* clr_ID_vld - Asserted by digital core to bring low ID_vld.                *
* 									    *
* Outputs:                                                                  *
* ID_vld - Asserted when 8-bit station ID has been read and upper 2-bits    *
* are 2'b00. If upper 2-bits are not 2'b00, then it is invalid.             *
* ID - 8-bit ID assembled by the unit, and given to digital core.           *
*									    *
****************************************************************************/
// Test
module barcode(ID_vld, ID, BC, clr_ID_vld, clk, rst_n);

typedef enum reg [2:0] {IDLE, PERIOD, WAIT, SAMPLE, VALIDATION} state_t;
state_t cur_state, nxt_state;

output reg ID_vld;		// Asserted when 8-bit station ID has been read and upper 2-bits are 2'b00
output reg [7:0] ID;  		// 8-bit ID assembled by the unit, and given to digital core. 

input clk,			// System clock
      rst_n,			// Async low reset
      BC,			// Serial data from IR sensor (low when over black, high otherwise)
      clr_ID_vld;		// Asserted by digital core to bring low ID_vld

reg BC_FF1, BC_FF2;		// BC FF's used for edge detection

reg [21:0] half_period_cnt, 	// Counter for half of period, after start bit
	   sample_cnt;		// counter for when to sample, will count to half_period_cnt

reg [3:0] cycle_cnt;

wire BC_falling_edge;		// Falling edge of BC
reg  start,			// Asserted to begin decoding barcode
     per_count,			// 1 if it is still counting 1/2 period, 0 otherwise
     sample,			// Used for when to sample + shift
     clr_samp,			// Clear sample counter
     clr_cyc,			// Clear cycle counter
     i_sample_cnt,		// Increment sample count
     ID_set,			// If true, then set ID vld
     ID_clear;			// If true, then deassert ID vld


// state machine
always@(posedge clk or negedge rst_n) begin
	if(~rst_n)
		cur_state <= IDLE;
	else
		cur_state <= nxt_state;
end

// ff for ID_vld
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		ID_vld <= 1'b0;
	else if (ID_set)
		ID_vld <= 1'b1;
	else if (ID_clear)
		ID_vld <= 1'b0;
	else
		ID_vld <= ID_vld;
end

// falling edge detection of BC (assume BC is high, aka BC is over non-black surface)
always@(posedge clk or negedge rst_n) begin
if(~rst_n) begin
		// preset FF as BC will be high normally
		BC_FF1 <= 1'b1;
		BC_FF2 <= 1'b1;
	end
	else begin
		// FF in series used for edge detection
		BC_FF1 <= BC;
		BC_FF2 <= BC_FF1;
	end
end

// counter for 1/2 period
always@(posedge clk or negedge rst_n) begin
	if(~rst_n)
		// reset to 0 when async rst is low
		half_period_cnt <= 1'b0;	
	else if (start)
		// reset to 0 when barcode reader starts
		half_period_cnt <= 1'b0;
	else if (per_count)
		// count half period for transcation
		half_period_cnt <= half_period_cnt + 1'b1;
	else
		// holds period to use for remaining 8 falling edges
		half_period_cnt <= half_period_cnt;
end

// shift register for ID
always@(posedge clk or negedge rst_n) begin
	if(~rst_n)
		// reset to 0
		ID <= 1'b0;
	else if (sample)
		// samples at 1/2 period after falling edge of BC (MSB first)
		// shift BC into lower bit, after 8 MSB or incoming data will be at MSB
		ID <= {ID[6:0], BC};
	else
		ID <= ID;
end

// when to sample counter
always@(posedge clk or negedge rst_n) begin
	if(~rst_n)
		// rest to 0
		sample_cnt <= 1'b0;
	else if (clr_sampl)
		// clears sample
		sample_nt <= 1'b0;
	else if (i_sample_cnt)
		// only increment when sample count i_sample_cnt is high
		sample_cnt <= sample_cnt + 1'b1;
	else
		sample_cnt <= sample_cnt; 
end

// cycle count after obtaining 1/2 period
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		cycle_cnt <= 1'b0;
	else if (clr_cyc)
		cycle_cnt <= 1'b0;
	else if (BC_falling_edge)
		cycle_cnt <= cycle_cnt + 1'b1;
	else
		cycle_cnt <= cycle_cnt;
end

// BC falling edge detection
assign BC_falling_edge = BC_FF2 & ~BC_FF1; 

always_comb begin
//////////////////////
// Default outputs //
////////////////////
start = 0;
per_count = 0;
sample = 0;
clr_samp = 0;
clr_cyc = 0;
i_sample_cnt = 0;
nxt_state = IDLE;
ID_set = 0;
ID_clear = 0;

case(cur_state)
IDLE: begin
	if (BC_falling_edge) begin
		nxt_state = PERIOD;
		start = 1;
	end
end

PERIOD: begin		// counting 1/2 period for reader
	if(~BC) begin
	  per_count = 1;
	  nxt_state = PERIOD;
	end
	else begin
	  clr_samp = 1;		// clear sample count [reg used to compare to period]
	  clr_cyc = 1;		// clear cycle count [reg used to keep track of cycles for sampling]
	  nxt_state = WAIT;
	end
end

WAIT: begin
	if (cycle_cnt == 8)
	   nxt_state = VALIDATION;
	else if (~BC_falling_edge)
	   nxt_state = WAIT;
	else
	   nxt_state = SAMPLE;
end

SAMPLE: begin		// sampling 8 times
	if (cycle_cnt <= 8) begin
		i_sample_cnt = 1;
		nxt_state = SAMPLE;

		if (half_period_cnt == sample_cnt) begin
			clr_samp = 1;
			sample = 1;
			nxt_state = WAIT;
		end
	end
	else
		nxt_state = VALIDATION;
end

VALIDATION: begin	// validation state
	if (clr_ID_vld) begin
		nxt_state = IDLE;
		ID_clear = 1;
	end
	else if (ID[7:6] == 2'b00 && half_period_cnt == sample_cnt) begin    	// ID_vld will stay high until clr_ID_vld
		ID_set = 1;	
		nxt_state = VALIDATION;
	end
	else if (ID[7:6] == 2'b00) begin
		nxt_state = VALIDATION;
		i_sample_cnt = 1; // inc sample count
	end
	else 
		nxt_state = IDLE;
	// note: if not valid, then will go back to IDLE state
end

default: nxt_state = IDLE;


endcase

end

endmodule 