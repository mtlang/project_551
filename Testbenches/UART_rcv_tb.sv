module UART_rcv_tb();

// stimulus signals ******************************************************************
logic clk, 		// system clock
      rst_n,		// async reset
      RX,       	// Serial data input
      rx_rdy,		// asserted when a whole byte is received
      rx_rdy_clr;	// Asserted to clear rx_rdy	

logic [7:0] rx_data; 	// byte received
  
// ***********************************************************************************

// instantiate UART_rcv
UART_rcv iDUT(.clk(clk), .rst_n(rst_n), .RX(RX), .rx_rdy(rx_rdy),
	      .rx_rdy_clr(rx_rdy_clr), .rx_data(rx_data));

logic [8:0] tx_data;

int i;

initial begin
clk = 0;		  // initialize clk
rst_n = 0;		  // async rst asserted
RX = 1;			  // RX is high when IDLE

@(posedge clk); 	  // wait for 1 clock cycle
@(negedge clk) rst_n = 1; // deassert async rst

// iterate through all possible values of tx_data and check data with rx_data(output)
for (tx_data = 0; tx_data < 127; tx_data = tx_data + 1) begin

	@(negedge clk) 
	RX = 0;				// Pull RX low, start of transaction 
	repeat(2604) @(posedge clk) ; 	// wait 2604 clocks
	
	// 8 bit transmission (MSB to LSB)
	for (i = 0; i < 8; i = i + 1) begin
	@(negedge clk) ;
	RX = tx_data[i];		// transmit LSB to MSB
	repeat(2604) @(posedge clk) ;   // wait 2604 clocks   
	end

	@(negedge clk)
	RX = 1;				// stop bit asseration
	repeat(2604) @(posedge clk);    // wait 2604 clocks	
	
	// self check
	#1;
	
	if (rx_rdy) begin
		if (rx_data != tx_data[7:0]) begin
			$display("tx_data not received properly. Suppose to be %h but it is %h", tx_data[7:0], rx_data);
			$stop;
		end
	end
	
	// arbitary wait, RX should be high until next transaction starts
	repeat(20) @(posedge clk);
end
// test bench completed
$display("No errors");
$stop;
end

// clock generation
always
#5 clk = ~clk;


endmodule
