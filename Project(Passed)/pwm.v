module pwm(duty,clk,rst_n,PWM_sig);

input [9:0] duty; // duty cycle
input clk,rst_n; // clock and asynch active-low reset

output reg PWM_sig; // PWM output


reg [9:0] cnt; // internal counter
reg set; // internal signal to set output
reg reset; // internal signal to reset output

// internal counter 
always @(posedge clk, negedge rst_n) begin
	if (~rst_n)
		cnt <= 10'h000;
	else
		cnt <= cnt + 1;
end

// combinational logic for set and reset signals
always @(*) begin
  if (cnt == 10'h3FF) 	
    set = 1;
  else if (cnt == duty) 
    reset = 1;
  else	begin			
    set = 0;
	 reset = 0;
  end
end

// sequential logic for PWM signal
always @(posedge clk or negedge rst_n) begin
  if (!rst_n)	begin	
    PWM_sig <= 0;
  end else if (set == 1) begin
    PWM_sig <= 1;
  end else if (reset == 1) begin
    PWM_sig <= 0;
  end else begin		
    PWM_sig <= PWM_sig;
  end
end

endmodule
