// Self-checking testbench: unmapped AHB transfers must get the two-cycle
// ERROR response, must not start an APB transfer and must not leak Prdata.

module Bridge_Error_Response_tb;

localparam IDLE=2'b00, NONSEQ=2'b10;
localparam OKAY=2'b00, ERROR=2'b01;

reg Hclk, Hresetn, Hwrite;
reg [1:0] Htrans;
reg [31:0] Haddr, Hwdata;
wire [31:0] Prdata;
wire Penable, Pwrite, Hreadyout;
wire [1:0] Hresp;
wire [2:0] Pselx;
wire [31:0] Paddr, Pwdata, Hrdata;

// Single-slave bus: HREADY fed back from the bridge.
Bridge_Top dut(.Hclk(Hclk), .Hresetn(Hresetn), .Hwrite(Hwrite), .Hreadyin(Hreadyout),
	       .Hreadyout(Hreadyout), .Hwdata(Hwdata), .Haddr(Haddr), .Htrans(Htrans),
	       .Prdata(Prdata), .Penable(Penable), .Pwrite(Pwrite), .Pselx(Pselx),
	       .Paddr(Paddr), .Pwdata(Pwdata), .Hresp(Hresp), .Hrdata(Hrdata));

// APB slave model: small register file whose read-data bus holds the last
// value read when no slave is selected (worst case for stale data).
reg [31:0] mem [0:15];
reg [31:0] prdata_q;
integer apb_writes, apb_selects;
assign Prdata = (|Pselx && ~Pwrite) ? mem[Paddr[5:2]] : prdata_q;

always @(posedge Hclk)
 begin
  if (|Pselx)
   apb_selects = apb_selects + 1;
  if (|Pselx && Penable && Pwrite)
   begin
    mem[Paddr[5:2]] <= Pwdata;
    apb_writes = apb_writes + 1;
   end
  if (|Pselx && Penable && ~Pwrite)
   prdata_q <= mem[Paddr[5:2]];
 end

initial Hclk = 0;
always #5 Hclk = ~Hclk;

integer failures;
integer i;

task check(input cond, input [8*64-1:0] msg);
 begin
  if (!cond)
   begin
    failures = failures + 1;
    $display("FAIL: %0s", msg);
   end
 end
endtask

reg [31:0] rd;
reg [1:0] resp;
reg [1:0] resp_trace [0:7];
reg ready_trace [0:7];
integer ncycles;

// One AHB single transfer. Data-phase HRESP/HREADY sampled every cycle at negedge.
task ahb_single(input w, input [31:0] a, input [31:0] wd);
 begin
  @(negedge Hclk);
  Htrans = NONSEQ; Haddr = a; Hwrite = w;
  while (!Hreadyout) @(negedge Hclk);
  @(negedge Hclk);
  Htrans = IDLE; Hwdata = wd;
  ncycles = 0;
  while (!Hreadyout && ncycles < 7)
   begin
    resp_trace[ncycles] = Hresp; ready_trace[ncycles] = Hreadyout;
    ncycles = ncycles + 1;
    @(negedge Hclk);
   end
  resp_trace[ncycles] = Hresp; ready_trace[ncycles] = Hreadyout;
  ncycles = ncycles + 1;
  rd = Hrdata; resp = Hresp;
 end
endtask

// Data phase must end with exactly ERROR/HREADY=0 then ERROR/HREADY=1.
task check_error_response(input [8*32-1:0] what);
 begin
  check(ncycles >= 2, {what, ": data phase shorter than 2 cycles"});
  if (ncycles >= 2)
   begin
    check(resp_trace[ncycles-2] == ERROR && ready_trace[ncycles-2] == 0,
          {what, ": 1st ERROR cycle missing"});
    check(resp_trace[ncycles-1] == ERROR && ready_trace[ncycles-1] == 1,
          {what, ": 2nd ERROR cycle missing"});
   end
  for (i = 0; i < ncycles-2; i = i + 1)
   check(resp_trace[i] == OKAY, {what, ": wait state not OKAY"});
 end
endtask

integer w0, s0;

initial
 begin
  failures = 0; apb_writes = 0; apb_selects = 0; prdata_q = 0;
  for (i = 0; i < 16; i = i + 1) mem[i] = 0;
  Hresetn = 0; Hwrite = 0; Htrans = IDLE; Haddr = 0; Hwdata = 0;
  repeat (3) @(posedge Hclk);
  @(negedge Hclk) Hresetn = 1;

  // 1. Mapped write + read still work with OKAY.
  ahb_single(1, 32'h8000_0010, 32'hDEAD_BEEF);
  check(resp == OKAY, "mapped write: HRESP not OKAY");
  repeat (3) @(negedge Hclk);
  check(mem[4] == 32'hDEAD_BEEF, "mapped write: data not written to APB slave");
  ahb_single(0, 32'h8000_0010, 0);
  check(resp == OKAY, "mapped read: HRESP not OKAY");
  check(rd == 32'hDEAD_BEEF, "mapped read: wrong HRDATA");

  // 2. Unmapped write: ERROR, no APB activity.
  repeat (2) @(negedge Hclk);
  w0 = apb_writes; s0 = apb_selects;
  ahb_single(1, 32'h8C00_0000, 32'h1234_5678);
  check_error_response("unmapped write");
  repeat (4) @(negedge Hclk);
  check(apb_selects == s0, "unmapped write: PSELx asserted");
  check(apb_writes == w0, "unmapped write: APB write happened");

  // 3. Unmapped read: ERROR, no stale Prdata (bus still holds 0xDEADBEEF).
  s0 = apb_selects;
  ahb_single(0, 32'h8C00_0000, 0);
  check_error_response("unmapped read");
  check(rd == 0, "unmapped read: stale Prdata leaked on HRDATA");
  repeat (4) @(negedge Hclk);
  check(apb_selects == s0, "unmapped read: PSELx asserted");

  // 4. Below the window too.
  ahb_single(0, 32'h7FFF_FFFC, 0);
  check_error_response("unmapped low read");

  // 5. Unmapped access right after a mapped write: write lands, then ERROR.
  ahb_single(1, 32'h8400_0020, 32'hCAFE_F00D);
  ahb_single(1, 32'h9000_0000, 32'h0BAD_0BAD);
  check_error_response("unmapped write after write");
  repeat (4) @(negedge Hclk);
  check(mem[8] == 32'hCAFE_F00D, "write before unmapped access lost");

  // 6. Next transfer issued in the 2nd ERROR cycle is accepted and served.
  @(negedge Hclk);
  Htrans = NONSEQ; Haddr = 32'hFFFF_0000; Hwrite = 1;
  while (!Hreadyout) @(negedge Hclk);
  @(negedge Hclk);
  Htrans = IDLE;
  while (!(Hresp == ERROR && Hreadyout)) @(negedge Hclk);
  Htrans = NONSEQ; Haddr = 32'h8800_0010; Hwrite = 0;
  @(negedge Hclk);
  Htrans = IDLE;
  while (!Hreadyout) @(negedge Hclk);
  check(Hresp == OKAY, "read after ERROR: HRESP not OKAY");
  check(Hrdata == 32'hDEAD_BEEF, "read after ERROR: wrong HRDATA");

  // 7. IDLE cycles get zero-wait OKAY.
  repeat (4) @(negedge Hclk);
  check(Hresp == OKAY && Hreadyout, "idle bus: not OKAY/ready");

  if (failures == 0)
   $display("PASS: Bridge_Error_Response_tb");
  else
   $fatal(1, "FAILED: Bridge_Error_Response_tb (%0d checks)", failures);
  $finish;
 end

initial
 begin
  #20000;
  $fatal(1, "FAIL: timeout");
  $finish;
 end

endmodule
