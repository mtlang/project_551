module motor_cntrl(fwd_lft,rev_lft,fwd_rht,rev_rht,lft,rht);
input [10:0] lft;
input [10:0] rht;

output reg fwd_lft, rev_lft, fwd_rht, rev_rht;

reg clk, lft_rst_n, rht_rst_n;
reg [9:0] lft_sig;
reg [9:0] rht_sig;
wire pwm_lft, pwm_rht;

reg [1:0] lft_mode;
reg [1:0] rht_mode;
localparam BRAKE = 2'b0;
localparam FWD = 2'b01;
localparam REV = 2'b10;

// Instantiate PWM modules
pwm lft_pwm(.duty(lft_sig), .clk(clk), .rst_n(lft_rst_n), .PWM_sig(pwm_lft));
pwm rht_pwm(.duty(rht_sig), .clk(clk), .rst_n(rht_rst_n), .PWM_sig(pwm_rht));

// Shared logic
initial begin
clk = 0;
end

always #5 clk = ~clk;

// Left logic
always @ ( lft ) begin

// Determine mode
if (lft[10]) lft_mode = REV;
else if (lft[10:0] == 11'h000) lft_mode = BRAKE;
else lft_mode = FWD;

// Cycle reset
lft_rst_n = 0;
#2 lft_rst_n = 1;
end

// Right logic
always @ (rht) begin

// Determine mode
if (rht[10]) rht_mode = REV;
else if (rht[10:0] == 11'h000) rht_mode = BRAKE;
else rht_mode = FWD;

// Cycle reset
rht_rst_n = 0;
#2 rht_rst_n = 1;
end

always @ (*) begin
// Continuous assignment of inputs and outputs

// Left
// Brake mode logic
if (lft_mode == BRAKE) begin
fwd_lft = 1'b1;
rev_lft = 1'b1;
end 
// FWD mode logic
else if (lft_mode == FWD) begin
lft_sig = lft[9:0];
fwd_lft = pwm_lft;
rev_lft = 1'b0;
end
// REV mode logic
else begin
lft_sig = (~lft[9:0]) + 1'b1;
fwd_lft = 1'b0;
rev_lft = pwm_lft;
end

// Right
// Brake mode logic
if (rht_mode == BRAKE) begin
fwd_rht = 1'b1;
rev_rht = 1'b1;
end 
// FWD mode logic
else if (rht_mode == FWD) begin
rht_sig = rht[9:0];
fwd_rht = pwm_rht;
rev_rht = 1'b0;
end
// REV mode logic
else begin
rht_sig = (~rht[9:0]) + 1'b1;
fwd_rht = 1'b0;
rev_rht = pwm_rht;
end

end
endmodule
