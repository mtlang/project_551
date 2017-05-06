module A2D_tb();

logic clk,
      rst_n,
      strt_cnv;

logic [2:0] chnnl;

wire a2d_SS_n,
     SCLK,
     MOSI,
     MISO,
     cnv_cmplt;

wire [11:0] result; 

// instan
A2D_intf iDUT(.clk(clk),.rst_n(rst_n),.strt_cnv(strt_cnv),
	      .cnv_cmplt(cnv_cmplt),.chnnl(chnnl),.res(result),
	      .a2d_SS_n(a2d_SS_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO));
// instan
ADC128S sim_ADC(.clk(clk),.rst_n(rst_n),.SS_n(a2d_SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI));


initial begin
clk = 0;
rst_n = 0;

@(negedge clk);
rst_n = 1;
chnnl = 0;
strt_cnv = 1;
@(negedge clk);
strt_cnv = 0;
repeat(2000) @(posedge clk);
$stop; 
end

// clock generation
always
#5 clk = ~clk;
endmodule
