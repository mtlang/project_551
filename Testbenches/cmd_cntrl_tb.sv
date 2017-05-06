module cmd_cntrl_tb();

localparam PERIOD = 22'd1000;
// stimulus and wires for dut
logic clk,			// system clock
      rst_n,			// Active low async reset
      OK2Move,			// Low if there's an obstacle and has to stop
      ID_vld,			// Indicates station ID is valid [BARCODE]
      cmd_rdy,			// indicates command is ready [UART]
      BC,			// Serial data for BC
      send_bc;			// for BC mimic

logic [7:0] cmd,		// Command received  [UART]
	    ID,			// Station ID [barcode]
	    send_cmd,		// TX CMD
	    barcode_ID;		// ID received from barcode reader

logic clr_cmd_rdy,		// Clears cmd_rdy [UART]
     in_transit,		// Froms enable to proximity sensor
     go,			// Tells motion controller to move forward [motion_cntrl]
     buzz,			// To piezo buzzer
     buzz_n,			// Inversion of buzz
     clr_ID_vld;		// clr_ID_vld [barcode]

logic serial_data,		// data from TX to RX
     start_UART,		// begin transmission for UART
     trans_done,
     bc_done;
     
// instatiation of modules connected to cmd_cntrl
// test module (cmd_cntrl)
cmd_cntrl iDUT(.cmd(cmd), .cmd_rdy(cmd_rdy), .clr_cmd_rdy(clr_cmd_rdy), .in_transit(in_transit), 
	  .OK2Move(OK2Move), .go(go), .buzz(buzz), .buzz_n(buzz_n), .ID(ID), .ID_vld(ID_vld), 
          .clr_ID_vld(clr_ID_vld), .clk(clk), .rst_n(rst_n));

// UART modules (TX & RX)
uart_tx transfer(.clk(clk),.rst_n(rst_n),.tx(serial_data),.strt_tx(start_UART),
		 .tx_data(send_cmd),.tx_done(trans_done));

UART_rcv receive(.rx_rdy(cmd_rdy), .rx_data(cmd), .clk(clk),
	         .rst_n(rst_n), .RX(serial_data), .rx_rdy_clr(clr_cmd_rdy));

// Barcode modules (BC & BCmimic)
barcode bc_reader(.ID_vld(ID_vld), .ID(ID), .BC(BC),
		  .clr_ID_vld(clr_ID_vld), .clk(clk), .rst_n(rst_n));

barcode_mimic bc_mimic(.clk(clk),.rst_n(rst_n),.period(PERIOD),.send(send_bc),
		       .station_ID(barcode_ID),.BC_done(bc_done),.BC(BC));

// begin test
initial begin
clk = 0;			// initalize clock
rst_n = 0;			// assert reset
OK2Move = 1;			// device is okay to move

send_cmd = 8'h42;		// sending go 2'b01 and 6'b000010 as station ID
barcode_ID = 8'h06;		// barcode is valid, but not correct station ID

///////////////////////////////////////////////////////////////////////////////
// Send CMD via UART
@(negedge clk)
rst_n = 1;			// deassert reset
start_UART = 1;			// assert UART start signal
@(negedge clk)
start_UART = 0;			// deassert UART start signal

fork				// error if it fails to transmit via UART TX
	begin: timeout	
		repeat(70000) @(posedge clk);
		$display("ERROR: timed out while waiting for UART transmission");
		$stop;
	end
	begin			// waits of cmd_rdy to go high
		@(posedge trans_done);
		disable timeout;
	end
join
////////////////////////////////////////////////////////////////////////////////
// Read barcode that is not the right station ID
@(negedge clk)
send_bc = 1;			 //assert signal to start barcode
@(negedge clk)
send_bc = 0;			 //deassert signal to start barcode

fork
	begin: timeout1		//error if it fails to read barcode
		repeat(70000) @(posedge clk);
		$display("ERROR: timed out while waiting for barcode reading");
		$stop;
	end
	begin
		@(posedge ID_vld);	//waits for ID_vld to go high
		disable timeout1;
	end
join

////////////////////////////////////////////////////////////////////////////
// test if it will stay in go state when cmd is go (sending same UART CMD)
@(negedge clk)
send_cmd = 8'h40;
@(negedge clk)
start_UART = 1;
@(negedge clk)
start_UART = 0;

fork				// error if it fails to transmit via UART TX
	begin: timeout2	
		repeat(70000) @(posedge clk);
		$display("ERROR: timed out while waiting for UART transmission");
		$stop;
	end
	begin			// waits of cmd_rdy to go high
		@(posedge trans_done);
		disable timeout2;
	end
join
//////////////////////////////////////////////////////////////////////////////////////
// test if it will stay in go state when cmd is not go or stop (sending same UART CMD)
@(negedge clk)
send_cmd = 8'hC0;
@(negedge clk)
start_UART = 1;
@(negedge clk)
start_UART = 0;

fork				// error if it fails to transmit via UART TX
	begin: timeout3	
		repeat(70000) @(posedge clk);
		$display("ERROR: timed out while waiting for UART transmission");
		$stop;
	end
	begin			// waits of cmd_rdy to go high
		@(posedge trans_done);
		disable timeout3;
	end
join
////////////////////////////////////////////////////////////////////////////////////
// Set dest_ID and test barcode after
@(negedge clk)
send_cmd = 8'h42;
@(negedge clk)
start_UART = 1;
@(negedge clk)
start_UART = 0;

fork				// error if it fails to transmit via UART TX
	begin: timeout4	
		repeat(70000) @(posedge clk);
		$display("ERROR: timed out while waiting for UART transmission");
		$stop;
	end
	begin			// waits of cmd_rdy to go high
		@(posedge trans_done);
		disable timeout4;
	end
join

////////////////////////////////////////////////////////////////////////////////////
// Various barcode test
@(negedge clk)
barcode_ID = 8'h0F;
@(negedge clk)
send_bc = 1;			 //assert signal to start barcode
@(negedge clk)
send_bc = 0;			 //deassert signal to start barcode

fork
	begin: timeout5		//error if it fails to read barcode
		repeat(70000) @(posedge clk);
		$display("ERROR: timed out while waiting for barcode reading");
		$stop;
	end
	begin
		@(posedge ID_vld);	//waits for ID_vld to go high
		disable timeout5;
	end
join

# 100; // wait 100 cycles to imitate delay before next barcode
@(negedge clk)
barcode_ID = 8'h00;
@(negedge clk)
send_bc = 1;			 //assert signal to start barcode
@(negedge clk)
send_bc = 0;			 //deassert signal to start barcode

fork
	begin: timeout6		//error if it fails to read barcode
		repeat(70000) @(posedge clk);
		$display("ERROR: timed out while waiting for barcode reading");
		$stop;
	end
	begin
		@(posedge ID_vld);	//waits for ID_vld to go high
		disable timeout6;
	end
join
# 100; // wait 100 cycles to imitate delay before next barcode

@(negedge clk)
barcode_ID = 8'h0A;
@(negedge clk)
send_bc = 1;			 //assert signal to start barcode
@(negedge clk)
send_bc = 0;			 //deassert signal to start barcode

fork
	begin: timeout7		//error if it fails to read barcode
		repeat(70000) @(posedge clk);
		$display("ERROR: timed out while waiting for barcode reading");
		$stop;
	end
	begin
		@(posedge ID_vld);	//waits for ID_vld to go high
		disable timeout7;
	end
join
# 100; // wait 100 cycles to imitate delay before next barcode
/////////////////////////////////////////////////////////////////////////////
// BUZZ test Should show 4 full periods
@(negedge clk)
OK2Move = 0;
repeat(12500*4)@(posedge clk); // test duty cycle
@(negedge clk)
OK2Move = 1;
/////////////////////////////////////////////////////////////////////////////
// Correct station ID (should go to stop state)
@(negedge clk)
barcode_ID = 8'h02;
@(negedge clk)
send_bc = 1;			 //assert signal to start barcode
@(negedge clk)
send_bc = 0;			 //deassert signal to start barcode

fork
	begin: timeout8		//error if it fails to read barcode
		repeat(70000) @(posedge clk);
		$display("ERROR: timed out while waiting for barcode reading");
		$stop;
	end
	begin
		@(posedge ID_vld);	//waits for ID_vld to go high
		disable timeout8;
	end
join

#100000; 	// wait to check ending state is in STOP
$stop;
end

// clk generation
always
#5 clk = ~clk;

endmodule
