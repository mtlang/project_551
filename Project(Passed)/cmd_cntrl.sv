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
wire en;

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
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		dest_ID <= 6'h00;		// default dest_ID
	else if (latch_ID)			
		dest_ID <= cmd[5:0];		// latch station ID when high
	else
		dest_ID <= dest_ID;		// otherwise stay the same
end

////////////////////////////////////////////////////////////////////////////
// In transit flop
///////////////////////////////////////////////////////////////////////////
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		in_transit <= 1'b0;		// default to 0
	else if (clr_in_transit)
		in_transit <= 1'b0;
	else if (set_in_transit)			
		in_transit <= 1'b1;		// set
	else
		in_transit <= in_transit;	// otherwise stay the same
end
///////////////////////////////////////////////////////////////////////////
// Wait 1 clock (counter)
///////////////////////////////////////////////////////////////////////////
always@(posedge clk or negedge rst_n) begin
	if (~rst_n)
		cnt <= 1'b0;
	else if (cnt == 1)
		cnt <= 1'b0;
	else if (inc)
		cnt <= cnt + 1;
	else
		cnt <= cnt;
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
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    buzz_cnt <= 14'h0000; // default count, 0
  end
  else if (buzz_cnt == 12500) // Don't just let it overflow.
	buzz_cnt <= 14'h0000;
  else if (en)  // Increase when enabled
    buzz_cnt <= buzz_cnt + 1'b1;
  else 
	buzz_cnt <= buzz_cnt;
end

always @(posedge clk) begin
  if (buzz_cnt <= 12500/2) // 50% duty
    buzz <= 1'b1;
  else
    buzz <= 1'b0;
end

assign buzz_n = ~buzz;
assign go = in_transit & OK2Move;
assign en = in_transit & ~OK2Move;

endmodule