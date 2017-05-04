module cmd_cntrl(clr_cmd_rdy, in_transit, go, buzz, buzz_n, clr_ID_vld,
		 clk, rst_n, cmd, cmd_rdy, OK2Move, ID, ID_vld);
////////////////////////////////////////////////////////////////////////////
// State type and declaration
///////////////////////////////////////////////////////////////////////////
typedef enum reg {STOP, GO} state_t;

localparam GO_CMD = 2'b01;
localparam STOP_CMD = 2'b00;

state_t state,
	nxt_state;
////////////////////////////////////////////////////////////////////////////
// Output and input to command and control interface
////////////////////////////////////////////////////////////////////////////
output clr_cmd_rdy,	// Clears cmd_rdy
       in_transit,	// Forms enable to proximity sensor
       go,		// Tells motino controller to move forward
       buzz,		// To piezo buzzer
       buzz_n,		// Inversion of buzz
       clr_ID_vld;	// Clears ID_vld

input clk,		// System clock
      rst_n,		// Active low async reset
      cmd_rdy,		// Indicates command is ready
      OK2Move,		// Low if there's an obstacle and has to stop
      ID_vld;		// Indicates station ID is valid 

input [7:0] cmd, 	// command received
            ID;		// Station ID
///////////////////////////////////////////////////////////////////////////
// registers & wires
//////////////////////////////////////////////////////////////////////////
wire en, next_cnt, next_in_transit, next_buzz;
wire [13:0] next_buzz_cnt;
wire [5:0] next_dest_ID;
reg cnt;
reg [5:0] dest_ID;
reg unsigned [13:0] buzz_cnt;

reg buzz,		// ******************************
    buzz_n,		// ** Mentioned in above block **
    in_transit,		// ** Mentioned in above block **
    clr_cmd_rdy,	// ** Mentioned in above block **
    clr_ID_vld,		// ******************************\
    set_in_transit,	// If true, then set in_transit
    clr_in_transit,	// If true, then clear in_transit
    latch_ID,		// If true, then latch ID
    inc;		// If true, then inc cnt for 1 cycle
//////////////////////////////////////////////////////////////////////////
// State machine
/////////////////////////////////////////////////////////////////////////
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		state <= STOP;
	else
		state <= nxt_state;
end
/////////////////////////////////////////////////////////////////////////
// Latch dest ID
/////////////////////////////////////////////////////////////////////////
assign next_dest_ID = latch_ID ? cmd[5:0] : dest_ID;


always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		dest_ID <= 6'h00;		// default dest_ID
		// latch station ID when high
	else
		dest_ID <= next_dest_ID;		// otherwise stay the same
end

////////////////////////////////////////////////////////////////////////////
// In transit flop
///////////////////////////////////////////////////////////////////////////
assign next_in_transit = clr_in_transit ? 1'b0 : 
								 set_in_transit ? 1'b1 : in_transit;

always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		in_transit <= 1'b0;		// default to 0
		// set
	else
		in_transit <= next_in_transit;	// otherwise stay the same
end
///////////////////////////////////////////////////////////////////////////
// Wait 1 clock (counter)
///////////////////////////////////////////////////////////////////////////
assign next_cnt = cnt ? 1'b0 :
						inc ? (cnt + 1'b1) : cnt;

always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		cnt <= 1'b0;
	else 
		cnt <= next_cnt;
end
///////////////////////////////////////////////////////////////////////////
// Combinational logic for state machine
///////////////////////////////////////////////////////////////////////////
always_comb begin
//////////////////////////////////////////////////////////////////////////
// Default outputs:
/////////////////////////////////////////////////////////////////////////
clr_cmd_rdy = 0;
clr_ID_vld = 0;
set_in_transit = 0;
clr_in_transit = 0;
latch_ID = 0;
inc = 0;
nxt_state = STOP;

case(state)
STOP: begin
	if (cmd_rdy && cmd[7:6] == GO_CMD) begin
		clr_cmd_rdy = 1;
		set_in_transit = 1;
		latch_ID = 1;
		nxt_state = GO;
	end
end

GO: begin
	nxt_state = GO;		// Takes care of otherwise arrows
	
	// CMD is go so relatch ID and keep going
	if (cmd_rdy && cmd[7:6] == GO_CMD) begin
		clr_cmd_rdy = 1;
		latch_ID = 1;
	end
	// ID is valid, but ID is not dest_ID so keep going
	if (ID_vld && ID != dest_ID) begin
		inc = 1;
		if (cnt == 1)
			clr_ID_vld = 1;
	end
	// CMD is stop, so stop and clear in transit flop
	if (cmd_rdy && cmd[7:6] == STOP_CMD) begin
		clr_cmd_rdy = 1;
		clr_in_transit = 1;
		nxt_state = STOP;
	end
	// ID is valid and ID is dest ID, so STOP and clear in transit flop
	if (ID_vld && ID == dest_ID) begin
		clr_ID_vld = 1;
		clr_in_transit = 1;
		nxt_state = STOP;
	end

end

endcase

end

////////////////////////////////////////////////////////////////////////////
// BUZZER
////////////////////////////////////////////////////////////////////////////
assign next_buzz = (en & (buzz_cnt <= 12500/2)) ? 1'b1 :
							en ? 1'b0 : buzz;

assign next_buzz_cnt = (en & (buzz_cnt == 12500)) ? 14'h0000 : 
								en ? (buzz_cnt + 1'b1) : buzz_cnt;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    buzz <= 1'b0; // default output, 0
  else 
	 buzz <= next_buzz;
end


always @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    buzz_cnt <= 14'h0000; // default output, 0
  else 
	 buzz_cnt <= next_buzz_cnt;
end

assign buzz_n = ~buzz;
assign go = in_transit & OK2Move;
assign en = in_transit & ~OK2Move;

endmodule