module motion_contrl_tb;
// Inputs
reg clk, rst_n, go, cnv_cmplt;
reg [11:0] A2D_res;

// Outputs
wire start_conv, IR_in_en, IR_mid_en, IR_out_en;
wire [2:0] chnnl;
wire [7:0] LEDs;
wire [10:0] lft;
wire [10:0] rht;

// Instantiate motion controller
motion_contrl iDUT(.start_conv(start_conv),.IR_in_en(IR_in_en),
.IR_mid_en(IR_mid_en),.IR_out_en(IR_out_en),
.chnnl(chnnl),.LEDs(LEDs),.lft(lft),.rht(rht),.clk(clk),
.rst_n(rst_n),.go(go),.cnv_cmplt(cnv_cmplt),.A2D_res(A2D_res));

initial begin
// Run through a cycle
clk = 0;
rst_n = 0;
go = 0;
cnv_cmplt = 0;
A2D_res = 0;
#500;
go = 1;
#500;
go = 0;
#500;
rst_n = 1;
#500;
go = 1;
#30000;
cnv_cmplt = 1;
go = 0;


end

always #2 clk = ~clk;

endmodule
