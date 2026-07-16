// AHB to APB Bridge | Self-checking testbench
//
// Wires the synthesizable Bridge_Top DUT to the AHB_Master stimulus
// generator and the APB_Interface peripheral model, drives a single
// write followed by a single read, and checks the resulting APB
// transactions against the AMBA APB protocol expectations.

`timescale 1ns/1ps

module Bridge_Top_tb;

  // AHB side signals (master <-> bridge)
  wire        Hclk;
  wire        Hresetn;
  wire        Hwrite;
  wire        Hreadyin;
  wire [1:0]  Htrans;
  wire [31:0] Hwdata;
  wire [31:0] Haddr;
  wire        Hreadyout;
  wire [1:0]  Hresp;
  wire [31:0] Hrdata;

  // APB side signals (bridge <-> peripheral)
  wire        Penable;
  wire        Pwrite;
  wire [2:0]  Pselx;
  wire [31:0] Paddr;
  wire [31:0] Pwdata;
  wire [31:0] Prdata;

  // Peripheral pass-through outputs (observation only)
  wire        Pwriteout;
  wire        Penableout;
  wire [2:0]  Pselxout;
  wire [31:0] Paddrout;
  wire [31:0] Pwdataout;

  // Clock / reset generation
  reg clk;
  reg resetn;
  assign Hclk    = clk;
  assign Hresetn = resetn;

  initial clk = 1'b0;
  always #5 clk = ~clk;   // 100 MHz

  // Device Under Test: the synthesizable bridge
  Bridge_Top DUT (
    .Hclk(Hclk), .Hresetn(Hresetn), .Hwrite(Hwrite), .Hreadyin(Hreadyin),
    .Hreadyout(Hreadyout), .Hwdata(Hwdata), .Haddr(Haddr), .Htrans(Htrans),
    .Prdata(Prdata), .Penable(Penable), .Pwrite(Pwrite), .Pselx(Pselx),
    .Paddr(Paddr), .Pwdata(Pwdata), .Hresp(Hresp), .Hrdata(Hrdata)
  );

  // AHB master stimulus generator (provides single_write / single_read tasks)
  AHB_Master MASTER (
    .Hclk(Hclk), .Hresetn(Hresetn), .Hresp(Hresp), .Hrdata(Hrdata),
    .Hwrite(Hwrite), .Hreadyin(Hreadyin), .Hreadyout(Hreadyout),
    .Htrans(Htrans), .Hwdata(Hwdata), .Haddr(Haddr)
  );

  // APB peripheral model
  APB_Interface PERIPH (
    .Pwrite(Pwrite), .Pselx(Pselx), .Penable(Penable), .Paddr(Paddr),
    .Pwdata(Pwdata), .Pwriteout(Pwriteout), .Pselxout(Pselxout),
    .Penableout(Penableout), .Paddrout(Paddrout), .Pwdataout(Pwdataout),
    .Prdata(Prdata)
  );

  // ---------------------------------------------------------------------
  // Transaction monitor: sample APB bus on the access phase (Penable high)
  // ---------------------------------------------------------------------
  integer errors      = 0;
  integer write_seen  = 0;
  integer read_seen   = 0;

  // Expected values driven by AHB_Master.single_write / single_read
  localparam [31:0] EXP_WDATA     = 32'h0000_00A3;
  localparam [2:0]  EXP_PSEL      = 3'b001;         // peripheral 0 (addr < 0x8400_0000)
  localparam [31:0] PADDR_LO      = 32'h8000_0000;
  localparam [31:0] PADDR_HI      = 32'h8400_0000;

  task check;
    input        cond;
    input [8*64-1:0] msg;
    begin
      if (!cond) begin
        errors = errors + 1;
        $display("[FAIL] %0t : %0s", $time, msg);
      end else begin
        $display("[PASS] %0t : %0s", $time, msg);
      end
    end
  endtask

  // Capture APB access phases (Penable asserted). Sampling on negedge keeps
  // us clear of the sequential update edge.
  always @(negedge Hclk) begin
    if (Hresetn && Penable) begin
      if (Pwrite) begin
        write_seen = write_seen + 1;
        check(Pselx == EXP_PSEL,
              "WRITE: Pselx decodes to peripheral 0");
        check(Paddr >= PADDR_LO && Paddr < PADDR_HI,
              "WRITE: Paddr within peripheral-0 range");
        check(Pwdata == EXP_WDATA,
              "WRITE: Pwdata equals data driven on AHB");
      end else begin
        read_seen = read_seen + 1;
        check(Pselx == EXP_PSEL,
              "READ: Pselx decodes to peripheral 0");
        check(Paddr >= PADDR_LO && Paddr < PADDR_HI,
              "READ: Paddr within peripheral-0 range");
        check(Hrdata == Prdata,
              "READ: Hrdata mirrors peripheral Prdata");
      end
    end
  end

  // ---------------------------------------------------------------------
  // Stimulus
  // ---------------------------------------------------------------------
  initial begin
    $dumpfile("build/bridge_tb.vcd");
    $dumpvars(0, Bridge_Top_tb);

    // Reset
    resetn = 1'b0;
    @(negedge Hclk);
    @(negedge Hclk);
    resetn = 1'b1;

    // Drive one write then one read using the master's tasks
    MASTER.single_write();
    MASTER.single_read();

    // Let the pipeline drain
    repeat (6) @(posedge Hclk);

    // Final self-check summary
    check(write_seen > 0, "A write access phase was observed on APB");
    check(read_seen  > 0, "A read access phase was observed on APB");

    if (errors == 0)
      $display("\n==== TESTBENCH PASSED (%0d write, %0d read access phases) ====",
               write_seen, read_seen);
    else
      $display("\n==== TESTBENCH FAILED with %0d error(s) ====", errors);

    $finish;
  end

  // Safety timeout
  initial begin
    #10000;
    $display("[FAIL] Timeout: simulation did not finish");
    $finish;
  end

endmodule
