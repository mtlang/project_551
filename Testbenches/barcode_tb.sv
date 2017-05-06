module barcode_tb();

logic [21:0] period;
logic [7:0] station_ID, ID, BC;
logic send, clk, rst_n, clr_ID_vld, ID_vld, BC_done;

// instantate barcode mimic
barcode_mimic mimic_DUT(.clk(clk),.rst_n(rst_n),.period(period),.send(send),.station_ID(station_ID),.BC_done(BC_done),.BC(BC));
// instantate barcode reader
barcode barcode_DUT(.ID_vld(ID_vld), .ID(ID), .BC(BC), .clr_ID_vld(clr_ID_vld), .clk(clk),.rst_n(rst_n));

initial begin

clk = 0;		// initialize clock
rst_n = 1;		// deassert async reset
clr_ID_vld = 0;		// clear signal from digicore is disasserted

@(negedge clk);		// wait for negedge clk, and assert async reset
rst_n = 0;	
@(negedge clk);		// deassert async reset
rst_n = 1;

@(negedge clk);		// set station ID and period
station_ID = 8'h36;
period = 1000;
send = 1;		// start reading (asserted for 1 clock)
@(negedge clk);
send = 0;

repeat(10000) @(posedge clk);	// wait for transaction to complete

@(negedge clk);		// assert clear ID from digicore for 1 clock cycle
clr_ID_vld = 1;

@(negedge clk);		// desassert clear ID and change station ID
clr_ID_vld = 0;	
station_ID = 8'h80;	// ID not valid, so ID_vld should be low after transcation
send = 1;		// start reading (asserted for 1 clock)
@(negedge clk);
send = 0;

repeat(10000) @(posedge clk);	// wait for transcation to complete (ID_vld should be low)

@(negedge clk);		// clear ID from digicore
clr_ID_vld = 1;

@(negedge clk);		// Test with another station ID that is valid
clr_ID_vld = 0;
station_ID = 8'h3A;
send = 1;		// start reading (last transcation)
@(negedge clk);
send = 0;

repeat(10000) @(posedge clk); // wait for transcation to complete

$stop;

end

// clock generation
always
#5 clk = ~clk;

endmodule
