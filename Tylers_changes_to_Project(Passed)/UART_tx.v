module uart_tx(clk,rst_n,tx,strt_tx,tx_data,tx_done);

input clk,rst_n;		// clock and active low reset
input strt_tx;			// strt_tx tells TX section to transmit tx_data
input [7:0] tx_data;	// byte to transmit
output tx, tx_done;		// tx_done asserted when transmission complete

reg state,nxt_state;	// I can name that tune in two states
reg [8:0] shift_reg;	// 1-bit wider to store start bit
reg [3:0] bit_cnt;		// bit counter
reg [11:0] baud_cnt;	// baud rate counter (50MHz/19200) = div of 2604
reg tx_done;			// tx_done will be a set/reset flop

reg load, trnsmttng;		// assigned in state machine

wire shift;
wire [3:0] next_bit_cnt;
wire [11:0] next_baud_cnt;
wire [8:0] next_shift_reg;
wire next_tx_done;
localparam IDLE = 1'b0;
localparam TX = 1'b1;

////////////////////////////
// Infer state flop next //
//////////////////////////
always @(posedge clk or negedge rst_n)
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;


/////////////////////////
// Infer bit_cnt next //
///////////////////////
assign next_bit_cnt = load ? 4'h0 : 
			shift ? bit_cnt + 1'b1 : bit_cnt;


always @(posedge clk or negedge rst_n) begin

  if (!rst_n)
    bit_cnt <= 4'b0000;
  else
    bit_cnt <= next_bit_cnt;
end
//////////////////////////
// Infer baud_cnt next //
////////////////////////
//
assign next_baud_cnt = (load || shift) ? 12'h5D3 : 
			 trnsmttng ?  baud_cnt + 1'b1 : baud_cnt;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    baud_cnt <= 12'h5D3;		// (4095 - 2604) = 0x5D3
  else
    baud_cnt <= next_baud_cnt;	  // only burn power incrementing if tranmitting
end
////////////////////////////////
// Infer shift register next //
//////////////////////////////
assign next_shift_reg = load ? {tx_data,1'b0} : 
			shift ? {1'b1,shift_reg[8:1]} : shift_reg;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    shift_reg <= 9'h1FF;		// reset to idle state being transmitted
  else
    shift_reg <= next_shift_reg;	  // LSB shifted out and idle state shifted in 
end
///////////////////////////////////////////////
// Easiest to make tx_done a set/reset flop //
/////////////////////////////////////////////
assign next_tx_done = strt_tx ? 1'b0 :
		      (bit_cnt==4'b1011) ? 1'b1 : tx_done;
 
always @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    tx_done <= 1'b0;
  else 
    tx_done <= next_tx_done;
end
//////////////////////////////////////////////
// Now for hard part...State machine logic //
////////////////////////////////////////////
always @(state,strt_tx,shift,bit_cnt)
  begin
    //////////////////////////////////////
    // Default assign all output of SM //
    ////////////////////////////////////
    load         = 1'b0;
    trnsmttng = 1'b0;
    nxt_state    = IDLE;	// always a good idea to default to IDLE state
    
    case (state)
      IDLE : begin
        if (strt_tx)
          begin
            nxt_state = TX;
            load =1'b1;
          end
        else nxt_state = IDLE;
      end
      default : begin		// this is TX state
        if (bit_cnt==4'b1011)
          nxt_state = IDLE;
        else
          nxt_state = TX;
        trnsmttng = 1'b1;
      end
    endcase
  end

////////////////////////////////////
// Continuous assignement follow //
//////////////////////////////////
assign shift = &baud_cnt;
assign tx = shift_reg[0];		// LSB of shift register is TX

endmodule

