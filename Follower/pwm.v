module pwm(duty,clk,rst_n,PWM_sig);

input [9:0] duty; // duty cycle
input clk,rst_n; // clock and asynch active-low reset

output reg PWM_sig; // PWM output

wire next_PWM_sig; // feeds the PWM_sig flip flop
reg [9:0] cnt; // internal counter
reg set; // internal signal to set output
reg reset; // internal signal to reset output

// internal counter 
always @(posedge clk, negedge rst_n) begin
    if (~rst_n)
        cnt <= 10'h000;
    else
        cnt <= cnt + 1'b1;
end

// combinational logic for set and reset signals
always @(*) begin
  if (cnt == 10'h3FF)   
    set = 1'b1;
  else if (cnt == duty) 
    reset = 1'b1;
  else  begin           
    set = 1'b0;
     reset = 1'b0;
  end
end

// sequential logic for PWM signal
assign next_PWM_sig = set ? 1'b1 :
              reset ? 1'b0 : PWM_sig;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    PWM_sig <= 1'b0;
  else 
    PWM_sig <= next_PWM_sig;
end
endmodule
