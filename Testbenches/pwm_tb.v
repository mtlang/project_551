module pwm_tb;

reg [9:0] duty; // duty cycle
reg clk, rst_n; // clock and reset

wire PWM_sig_out; // output

pwm iDUT(.duty(duty),.clk(clk),.rst_n(rst_n),
.PWM_sig(PWM_sig_out));

// continuously update clock
initial begin
  clk = 0;
  forever #2 clk = ~clk;
end

initial begin
// reset
rst_n = 0;
// start with 50/50 duty cycle
duty = 10'h1FF;
#1
rst_n = 1;
#12000
// reset
rst_n = 0;
#1
rst_n = 1;
// test extreme duty cycles
duty = 10'hFFE;
#12000
rst_n = 0;
#1 rst_n = 1;
duty = 10'h001;
end

endmodule