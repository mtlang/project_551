module motor_cntrl_tb;
reg [10:0] lft;
reg [10:0] rht;

wire fwd_lft, rev_lft, fwd_rht, rev_rht;

motor_cntrl iDUT(.fwd_lft(fwd_lft), .rev_lft(rev_lft), .fwd_rht(fwd_rht), 
	 .rev_rht(rev_rht), .lft(lft), .rht(rht));

initial begin
// Test Brake Mode
lft = 11'h000;
rht = 11'h000;
#50000;
// Test Forward Mode (should be about 50/50)
lft = 11'h200;
rht = 11'h200;
#50000;
// Test Reverse Mode (should be about 50/50)
lft = 11'h600;
rht = 11'h600;
#50000;
// Test Extreme Forward Speeds w/ different left and right
lft = 11'h001;
rht = 11'h3FF;
#50000;
lft = 11'h3FF;
rht = 11'h001;
#50000;
// Test Extreme Reverse Speeds w/ different left and right
lft = 11'h401;
rht = 11'h7FF;
#50000;
lft = 11'h7FF;
rht = 11'h401;
#50000;
// Test Brake Mode (as non-initial condition)
lft = 11'h000;
rht = 11'h000;
#50000;
end

endmodule