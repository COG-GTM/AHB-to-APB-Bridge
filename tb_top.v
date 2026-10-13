// AHB to APB Bridge | Testbench Top
//
// Wires AHB_Master (stimulus) -> Bridge_Top (DUT) -> APB_Interface
// (peripheral model), runs one single write and one single read, and
// checks the resulting APB transfers. Ends with $fatal on any mismatch.
//
// Run: iverilog -o /tmp/all.out *.v && vvp /tmp/all.out


module tb_top;

reg Hclk, Hresetn;

wire Hwrite, Hreadyin, Hreadyout;
wire [1:0] Htrans, Hresp;
wire [31:0] Hwdata, Haddr, Hrdata;

wire Penable, Pwrite;
wire [2:0] Pselx;
wire [31:0] Paddr, Pwdata, Prdata;

wire Pwriteout, Penableout;
wire [2:0] Pselxout;
wire [31:0] Paddrout, Pwdataout;

localparam [31:0] WRITE_ADDR = 32'h8000_0001;
localparam [31:0] WRITE_DATA = 32'h0000_00A3;
localparam [31:0] READ_ADDR  = 32'h8000_00A2;
localparam [2:0]  PSEL0      = 3'b001;

integer errors, writes, reads;

/////////////////////////////////////////////////////////////// MODULE INSTANTIATIONS

AHB_Master AHBMaster (.Hclk(Hclk), .Hresetn(Hresetn), .Hresp(Hresp), .Hrdata(Hrdata),
                      .Hwrite(Hwrite), .Hreadyin(Hreadyin), .Hreadyout(Hreadyout),
                      .Htrans(Htrans), .Hwdata(Hwdata), .Haddr(Haddr));

Bridge_Top Bridge (.Hclk(Hclk), .Hresetn(Hresetn), .Hwrite(Hwrite), .Hreadyin(Hreadyin),
                   .Hreadyout(Hreadyout), .Hwdata(Hwdata), .Haddr(Haddr), .Htrans(Htrans),
                   .Prdata(Prdata), .Penable(Penable), .Pwrite(Pwrite), .Pselx(Pselx),
                   .Paddr(Paddr), .Pwdata(Pwdata), .Hresp(Hresp), .Hrdata(Hrdata));

APB_Interface APBPeripheral (.Pwrite(Pwrite), .Pselx(Pselx), .Penable(Penable),
                             .Paddr(Paddr), .Pwdata(Pwdata), .Pwriteout(Pwriteout),
                             .Pselxout(Pselxout), .Penableout(Penableout),
                             .Paddrout(Paddrout), .Pwdataout(Pwdataout), .Prdata(Prdata));

/////////////////////////////////////////////////////////////// CLOCK

initial Hclk = 0;
always #5 Hclk = ~Hclk;

/////////////////////////////////////////////////////////////// CHECKS

task check(input cond, input [8*48-1:0] msg);
 begin
  if (!cond)
   begin
    errors = errors + 1;
    $display("FAIL @%0t: %0s", $time, msg);
   end
 end
endtask

// Outputs are stable mid-cycle: the bridge updates on posedge and the
// master drives its signals #2 after posedge.
reg setup_seen;
reg [2:0] setup_selx;
reg [31:0] setup_addr, setup_wdata;
reg setup_write;

always @(negedge Hclk)
 if (Hresetn)
  begin
   check(Pwriteout === Pwrite && Penableout === Penable && Pselxout === Pselx &&
         Paddrout === Paddr && Pwdataout === Pwdata, "APB_Interface pass-through mismatch");
   check(Hresp === 2'b00, "Hresp not OKAY");
   check(Hrdata === Prdata, "Hrdata does not mirror Prdata");

   if (Penable)
    begin
     check(setup_seen, "access phase without setup phase");
     check(Pselx === setup_selx && Paddr === setup_addr && Pwrite === setup_write,
           "control changed between setup and access");
     if (Pwrite)
      begin
       writes = writes + 1;
       check(Pwdata === setup_wdata, "Pwdata changed between setup and access");
       check(Pselx === PSEL0, "write: wrong Pselx");
       check(Paddr === WRITE_ADDR, "write: wrong Paddr");
       check(Pwdata === WRITE_DATA, "write: wrong Pwdata");
       check(Prdata === 32'd0, "write: Prdata not 0");
      end
     else
      begin
       reads = reads + 1;
       check(Pselx === PSEL0, "read: wrong Pselx");
       check(Paddr === READ_ADDR, "read: wrong Paddr");
       check(Prdata < 32'd256, "read: Prdata out of model range");
       $display("READ  Paddr=%h Prdata=%h Hrdata=%h", Paddr, Prdata, Hrdata);
      end
     setup_seen = 0;
    end
   else
    begin
     check(Prdata === 32'd0, "Prdata not 0 outside read access");
     setup_seen  = (Pselx != 3'b000);
     setup_selx  = Pselx;
     setup_addr  = Paddr;
     setup_wdata = Pwdata;
     setup_write = Pwrite;
    end
  end

/////////////////////////////////////////////////////////////// STIMULUS

initial
 begin
  errors = 0; writes = 0; reads = 0; setup_seen = 0;
  Hresetn = 0;
  AHBMaster.Hwrite   = 0;
  AHBMaster.Hreadyin = 1;
  AHBMaster.Htrans   = 2'b00;
  AHBMaster.Haddr    = 0;
  AHBMaster.Hwdata   = 0;

  repeat (2) @(posedge Hclk);
  #1 Hresetn = 1;

  AHBMaster.single_write;
  repeat (3) @(posedge Hclk);
  AHBMaster.single_read;
  repeat (3) @(posedge Hclk);

  check(writes == 1, "expected exactly 1 APB write");
  check(reads == 1, "expected exactly 1 APB read");

  if (errors == 0)
   begin
    $display("PASS: %0d APB write, %0d APB read", writes, reads);
    $finish;
   end
  else
   $fatal(1, "%0d check(s) failed", errors);
 end

initial
 begin
  #1000;
  $fatal(1, "timeout");
 end

endmodule
