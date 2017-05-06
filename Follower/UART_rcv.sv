module uart_rcv(rx_rdy, rx_data, clk, rst_n, RX, clr_rx_rdy);

typedef enum reg [1:0] {IDLE, START, RECEIVING} state_t;	// state names
state_t state,		// current state
	nxt_state;	// next state

localparam BAUD = 2604;	// clk cycle per baud cycle [duration = BAUD*10 = 26,040 clks]

output reg rx_rdy;	// Asserted when a whole byte is received. Deasserted with rx_rdy_clr|| new byte
output reg [7:0] rx_data;	// Byte received

input clk,		// 50MHz system clock
      rst_n,		// Active low async reset
      RX,		// Serial data input
      clr_rx_rdy;	// Asserted to clear rx_rdy

reg RX_FF1, RX_FF2;	// flop for falling edge detection

reg falling_edge_rx,	// 1 if RX is falling, 0 otherwise
     start,		// 1 to start receving, 0 otherwise
     done,		// 1 if all 10 bits received, 0 otherwise 
     shift;		// shift occurs at 1/2 baud, then every 1 baud after for 9 cycles

reg [11:0] baud_cnt;	// baud counter for when to sample
reg [9:0] shift_reg;	// RX data is shifted into this reg
reg [4:0] cycle_cnt;	// keeps track of cycles, done after 10 cycles
reg inc_cycle;
wire next_rx_rdy;
wire [11:0] next_baud_cnt;
wire [9:0] next_shift_reg;
wire [4:0] next_cycle_cnt;
// rx_rdy FF 
assign next_rx_rdy = (clr_rx_rdy | start) ? 1'b0 : 
			done ? 1'b1 : rx_rdy;
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		rx_rdy <= 1'b0;
	else if (clr_rx_rdy | start | done)
		rx_rdy <= next_rx_rdy;
end


// state machine
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		state <= IDLE;
	else
		state <= nxt_state;
end

// edge detection on RX_line

always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		RX_FF1 <= 1'b1;		// preset of ff
	else
		RX_FF1 <= RX;
end

always@(posedge clk or negedge rst_n) begin
	if (~rst_n)// preset of ff
		RX_FF2 <= 1'b1;
	else
		RX_FF2 <= RX_FF1;
	
end


// baud counter for sampling
assign next_baud_cnt = ( baud_cnt == BAUD||start||shift) ? 12'h000 : baud_cnt + 1'b1;
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		baud_cnt <= 12'h000;		
	else
		baud_cnt <= next_baud_cnt;
end

// shift reg for received data
assign next_shift_reg = start ? 10'h000 : 
			shift ? {RX, shift_reg[9:1]} : shift_reg;
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		shift_reg <= 10'h000; // default
	else
		shift_reg <= next_shift_reg;
end

// cycle count for bits recevied
assign next_cycle_cnt = start ? 5'h00 : 
			shift|inc_cycle ? cycle_cnt + 1'b1 : cycle_cnt;
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		cycle_cnt <= 5'h00;
	else
		cycle_cnt <= next_cycle_cnt;
end

assign falling_edge_rx = ~RX_FF1 & RX_FF2;	// falling detector for RX
assign rx_data = done ? shift_reg[8:1]: rx_data; // swaps only when done is asserted

// comb logic for state transactions
always_comb begin
//////////////////////////
// default //
/////////////////////////
start = 1'b0;
shift = 1'b0;
done = 1'b0;
inc_cycle = 0;
nxt_state = IDLE;

// begin case
case(state)
IDLE: begin
	if(falling_edge_rx) begin	// RX line pulled down to start transcation
		start = 1'b1;
		nxt_state = START;
	end
		
end

START: begin
	if (baud_cnt == BAUD/2) begin	// waits for 1/2 baud before samping first RX
		shift = 1'b1;
		nxt_state = RECEIVING;
	end
	else 
		nxt_state = START;
end

RECEIVING: begin
	if (cycle_cnt <= 9) begin	// when cycle count is 10, then UART receving is done
		nxt_state = RECEIVING;

		if (baud_cnt == BAUD) // if baud count is reached, then sample does it 9 times
			shift = 1'b1;
		
	end
	else if (baud_cnt == BAUD/2 && cycle_cnt == 11) begin
	done = 1'b1;			
	nxt_state = IDLE;	
	end
	else if (baud_cnt == BAUD && cycle_cnt == 10) begin
	inc_cycle = 1;
	nxt_state = RECEIVING;
	end
	else
		nxt_state = RECEIVING;

end
		
default: 				// default state is IDLE in case when it goes to unknown state
nxt_state = IDLE;

endcase

end

endmodule
