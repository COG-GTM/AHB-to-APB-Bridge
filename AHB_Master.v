// AHB to APG Bridge | Maven Silicon
//
//
//
// AHB Master
// Date:14-06-2022
//
// By-Prajwal Kumar Sahu


module AHB_Master(Hclk,Hresetn,Hresp,Hrdata,Hwrite,Hreadyin,Hreadyout,Htrans,Hwdata,Haddr);

input Hclk,Hresetn,Hreadyout;
input [1:0]Hresp;
input [31:0] Hrdata;
output reg Hwrite,Hreadyin;
output reg [1:0] Htrans;
output reg [31:0] Hwdata,Haddr;

// Result of the last completed transfer, for the testbench to check.
reg [31:0] read_data;
reg [1:0]  last_resp;

initial
 begin
  Hwrite=0;
  Htrans=2'b00;
  Hreadyin=1;
  Haddr=0;
  Hwdata=0;
  read_data=0;
  last_resp=2'b00;
 end

// A transfer phase ends on the first rising edge that samples Hreadyout HIGH.
task wait_ready;
 begin
  @(posedge Hclk);
  while (!Hreadyout)
   @(posedge Hclk);
 end
endtask

task single_write;
 begin
  wait (Hresetn);
  @(posedge Hclk)
  #2;
   begin
    Hwrite=1;
    Htrans=2'b10;
    Hreadyin=1;
    Haddr=32'h8000_0001;
   end

  wait_ready;
  #2;
   begin
    Htrans=2'b00;
    Hwdata=8'hA3;
   end

  wait_ready;
  last_resp=Hresp;
 end
endtask


task single_read;
 begin
  wait (Hresetn);
  @(posedge Hclk)
  #2;
   begin
    Hwrite=0;
    Htrans=2'b10;
    Hreadyin=1;
    Haddr=32'h8000_00A2;
   end

  wait_ready;
  #2;
   begin
    Htrans=2'b00;
   end

  wait_ready;
  read_data=Hrdata;
  last_resp=Hresp;
 end
endtask


endmodule
