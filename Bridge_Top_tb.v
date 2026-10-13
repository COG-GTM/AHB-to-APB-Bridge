// AHB to APB Bridge | Self-checking testbench
//
// Connects AHB_Master -> Bridge_Top -> APB_Interface, runs
// AHB_Master.single_write followed by AHB_Master.single_read and checks
// the resulting APB transfers and the read data returned on AHB.
//
// Run: iverilog -o /tmp/all.out *.v && vvp /tmp/all.out   (+vcd to dump waves)


module Bridge_Top_tb;

reg Hclk,Hresetn;

wire Hwrite,Hreadyin,Hreadyout;
wire [1:0] Htrans,Hresp;
wire [31:0] Hwdata,Haddr,Hrdata;

wire Penable,Pwrite;
wire [2:0] Pselx;
wire [31:0] Paddr,Pwdata,Prdata;

wire Pwriteout,Penableout;
wire [2:0] Pselxout;
wire [31:0] Paddrout,Pwdataout;

localparam [31:0] WRITE_ADDR=32'h8000_0001;
localparam [31:0] WRITE_DATA=32'h0000_00A3;
localparam [31:0] READ_ADDR =32'h8000_00A2;
localparam [2:0]  PSEL0     =3'b001;

AHB_Master Master (.Hclk(Hclk),.Hresetn(Hresetn),.Hresp(Hresp),.Hrdata(Hrdata),
                   .Hwrite(Hwrite),.Hreadyin(Hreadyin),.Hreadyout(Hreadyout),
                   .Htrans(Htrans),.Hwdata(Hwdata),.Haddr(Haddr));

Bridge_Top Bridge (.Hclk(Hclk),.Hresetn(Hresetn),.Hwrite(Hwrite),.Hreadyin(Hreadyin),
                   .Hreadyout(Hreadyout),.Hwdata(Hwdata),.Haddr(Haddr),.Htrans(Htrans),
                   .Prdata(Prdata),.Penable(Penable),.Pwrite(Pwrite),.Pselx(Pselx),
                   .Paddr(Paddr),.Pwdata(Pwdata),.Hresp(Hresp),.Hrdata(Hrdata));

APB_Interface Slave (.Pwrite(Pwrite),.Pselx(Pselx),.Penable(Penable),.Paddr(Paddr),
                     .Pwdata(Pwdata),.Pwriteout(Pwriteout),.Pselxout(Pselxout),
                     .Penableout(Penableout),.Paddrout(Paddrout),.Pwdataout(Pwdataout),
                     .Prdata(Prdata));

initial Hclk=0;
always #5 Hclk=~Hclk;

integer errors=0;
integer writes=0;
integer reads=0;
reg [31:0] apb_rdata;

task check(input cond, input [8*48-1:0] msg);
 begin
  if (!cond)
   begin
    errors=errors+1;
    $display("FAIL @%0t: %0s", $time, msg);
   end
 end
endtask

// APB monitor: sample each access phase (Penable HIGH) away from the active edge.
always @(negedge Hclk)
 if (Hresetn && Penable)
  begin
   check(Pselx==PSEL0, "Pselx selects peripheral 0");
   if (Pwrite)
    begin
     writes=writes+1;
     check(Paddr==WRITE_ADDR, "APB write address");
     check(Pwdata==WRITE_DATA, "APB write data");
     $display("APB write: Paddr=%h Pwdata=%h", Paddr, Pwdata);
    end
   else
    begin
     reads=reads+1;
     apb_rdata=Prdata;
     check(Paddr==READ_ADDR, "APB read address");
     $display("APB read:  Paddr=%h Prdata=%h", Paddr, Prdata);
    end
  end

initial
 begin
  if ($test$plusargs("vcd"))
   begin
    $dumpfile("Bridge_Top_tb.vcd");
    $dumpvars(0, Bridge_Top_tb);
   end

  Hresetn=0;
  repeat (2) @(negedge Hclk);
  Hresetn=1;

  Master.single_write;
  check(Master.last_resp==2'b00, "write Hresp OKAY");

  // Idle cycles so the APB write completes before the read address phase;
  // back-to-back write->read is not exercised here.
  repeat (2) @(posedge Hclk);

  Master.single_read;
  check(Master.last_resp==2'b00, "read Hresp OKAY");
  check(Master.read_data===apb_rdata, "Hrdata returns APB Prdata");
  $display("AHB read:  Hrdata=%h", Master.read_data);

  repeat (4) @(posedge Hclk);
  check(writes==1, "exactly one APB write access");
  check(reads==1, "exactly one APB read access");

  if (errors)
   $fatal(1, "Bridge_Top_tb FAILED: %0d error(s)", errors);
  $display("Bridge_Top_tb PASSED");
  $finish;
 end

initial
 begin
  #2000;
  $fatal(1, "Bridge_Top_tb timed out");
 end

endmodule
