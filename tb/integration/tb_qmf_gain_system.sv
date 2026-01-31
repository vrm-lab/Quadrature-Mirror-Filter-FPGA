`timescale 1ns/1ps

/**
 * Testbench: QMF Analysis → Dual Gain → QMF Synthesis (AXI-Stream)
 *
 * Signal Flow:
 *
 *   AXI-Stream Source
 *          |
 *          v
 *     QMF Analysis
 *        |      |
 *        |      +--> High Band → Gain High
 *        |
 *        +--> Low Band  → Gain Low
 *                 |
 *                 v
 *           QMF Synthesis
 *                 |
 *                 v
 *           AXI-Stream Sink
 *
 * Purpose:
 * - Validate functional correctness of a full subband DSP chain
 * - Verify AXI-Stream handshake robustness (no deadlock)
 * - Demonstrate clean AXI-Lite configuration with explicit decoding
 *
 * Scope:
 * - RTL simulation only
 * - Fixed-point signal behavior
 * - Deterministic latency propagation
 *
 * Non-goals:
 * - No performance benchmarking
 * - No software / driver validation
 * - Not a reusable verification framework
 *
 * Design Style:
 * - Explicit wires only (no implicit connections)
 * - No shared AXI-Lite buses without decoding
 * - Deadlock-safe backpressure handling
 */

module tb_qmf_gain_system;

    // =====================================================================
    // 1. PARAMETERS
    // =====================================================================
    parameter integer NTAPS      = 8;
    parameter integer ADDRW      = 12;
    parameter integer GAIN_FBITS = 12;

    // =====================================================================
    // 2. GLOBAL CLOCK & RESET
    // =====================================================================
    reg clk;
    reg rstn;

    always #5 clk = ~clk; // 100 MHz

    // =====================================================================
    // 3. AXI-STREAM SIGNALS (EXPLICIT WIRES)
    // =====================================================================

    // Source → Analysis
    reg  [31:0] src_tdata;
    reg         src_tvalid;
    reg         src_tlast;
    wire        src_tready;

    // Analysis → Gain (Low)
    wire [31:0] ana_low_tdata;
    wire        ana_low_tvalid;
    wire        ana_low_tlast;
    wire        ana_low_tready;

    // Analysis → Gain (High)
    wire [31:0] ana_high_tdata;
    wire        ana_high_tvalid;
    wire        ana_high_tlast;
    wire        ana_high_tready;

    // Gain → Synthesis
    wire [31:0] gain_low_tdata;
    wire        gain_low_tvalid;
    wire        gain_low_tlast;
    wire        gain_low_tready;

    wire [31:0] gain_high_tdata;
    wire        gain_high_tvalid;
    wire        gain_high_tlast;
    wire        gain_high_tready;

    // Synthesis → Sink
    wire [31:0] final_tdata;
    wire        final_tvalid;
    wire        final_tlast;
    wire        final_tready;

    assign final_tready = 1'b1; // Sink always ready

    // =====================================================================
    // 4. AXI-LITE CONTROL (MANUAL DECODER)
    // =====================================================================
    reg [ADDRW-1:0] tb_awaddr;
    reg [31:0]      tb_wdata;
    reg             tb_awvalid;
    reg             tb_wvalid;
    reg             tb_bready;
    reg [1:0]       target_sel;
    // target_sel:
    // 0 = QMF Analysis
    // 1 = QMF Synthesis
    // 2 = Gain Low
    // 3 = Gain High

    // --- Analysis AXI-Lite ---
    wire [ADDRW-1:0] ana_awaddr  = tb_awaddr;
    wire [31:0]      ana_wdata   = tb_wdata;
    wire             ana_awvalid = (target_sel == 0) ? tb_awvalid : 1'b0;
    wire             ana_wvalid  = (target_sel == 0) ? tb_wvalid  : 1'b0;
    wire             ana_bready  = tb_bready;
    wire             ana_awready, ana_wready, ana_bvalid;

    // --- Synthesis AXI-Lite ---
    wire [ADDRW-1:0] syn_awaddr  = tb_awaddr;
    wire [31:0]      syn_wdata   = tb_wdata;
    wire             syn_awvalid = (target_sel == 1) ? tb_awvalid : 1'b0;
    wire             syn_wvalid  = (target_sel == 1) ? tb_wvalid  : 1'b0;
    wire             syn_bready  = tb_bready;
    wire             syn_awready, syn_wready, syn_bvalid;

    // --- Gain Low AXI-Lite ---
    wire [3:0] gain_l_awaddr  = tb_awaddr[3:0];
    wire       gain_l_awvalid = (target_sel == 2) ? tb_awvalid : 1'b0;
    wire       gain_l_wvalid  = (target_sel == 2) ? tb_wvalid  : 1'b0;
    wire       gain_l_bready  = tb_bready;
    wire       gain_l_awready, gain_l_wready, gain_l_bvalid;

    // --- Gain High AXI-Lite ---
    wire [3:0] gain_h_awaddr  = tb_awaddr[3:0];
    wire       gain_h_awvalid = (target_sel == 3) ? tb_awvalid : 1'b0;
    wire       gain_h_wvalid  = (target_sel == 3) ? tb_wvalid  : 1'b0;
    wire       gain_h_bready  = tb_bready;
    wire       gain_h_awready, gain_h_wready, gain_h_bvalid;

    // =====================================================================
    // 5. DUT INSTANTIATION
    // =====================================================================

    // --- QMF ANALYSIS ---
    qmf_analysis_axis #(
        .C_S_AXI_ADDR_WIDTH(ADDRW),
        .NTAPS(NTAPS)
    ) u_analysis (
        .clk(clk), .rstn(rstn),
        .s_axis_tdata(src_tdata),
        .s_axis_tvalid(src_tvalid),
        .s_axis_tready(src_tready),
        .s_axis_tlast(src_tlast),
        .m_axis_low_tdata(ana_low_tdata),
        .m_axis_low_tvalid(ana_low_tvalid),
        .m_axis_low_tready(ana_low_tready),
        .m_axis_low_tlast(ana_low_tlast),
        .m_axis_high_tdata(ana_high_tdata),
        .m_axis_high_tvalid(ana_high_tvalid),
        .m_axis_high_tready(ana_high_tready),
        .m_axis_high_tlast(ana_high_tlast),
        .s_axi_awaddr(ana_awaddr),
        .s_axi_awvalid(ana_awvalid),
        .s_axi_awready(ana_awready),
        .s_axi_wdata(ana_wdata),
        .s_axi_wvalid(ana_wvalid),
        .s_axi_wready(ana_wready),
        .s_axi_bvalid(ana_bvalid),
        .s_axi_bready(ana_bready),
        .s_axi_arready(),
        .s_axi_rvalid()
    );

    // --- GAIN LOW ---
    gain_axis_wrapper #(.GAIN_FBITS(GAIN_FBITS)) u_gain_low (
        .aclk(clk), .aresetn(rstn),
        .s_axis_tdata(ana_low_tdata),
        .s_axis_tvalid(ana_low_tvalid),
        .s_axis_tready(ana_low_tready),
        .s_axis_tlast(ana_low_tlast),
        .m_axis_tdata(gain_low_tdata),
        .m_axis_tvalid(gain_low_tvalid),
        .m_axis_tready(gain_low_tready),
        .m_axis_tlast(gain_low_tlast),
        .s_axi_awaddr(gain_l_awaddr),
        .s_axi_awvalid(gain_l_awvalid),
        .s_axi_awready(gain_l_awready),
        .s_axi_wdata(tb_wdata),
        .s_axi_wvalid(gain_l_wvalid),
        .s_axi_wready(gain_l_wready),
        .s_axi_bvalid(gain_l_bvalid),
        .s_axi_bready(gain_l_bready),
        .s_axi_arready(),
        .s_axi_rvalid()
    );

    // --- GAIN HIGH ---
    gain_axis_wrapper #(.GAIN_FBITS(GAIN_FBITS)) u_gain_high (
        .aclk(clk), .aresetn(rstn),
        .s_axis_tdata(ana_high_tdata),
        .s_axis_tvalid(ana_high_tvalid),
        .s_axis_tready(ana_high_tready),
        .s_axis_tlast(ana_high_tlast),
        .m_axis_tdata(gain_high_tdata),
        .m_axis_tvalid(gain_high_tvalid),
        .m_axis_tready(gain_high_tready),
        .m_axis_tlast(gain_high_tlast),
        .s_axi_awaddr(gain_h_awaddr),
        .s_axi_awvalid(gain_h_awvalid),
        .s_axi_awready(gain_h_awready),
        .s_axi_wdata(tb_wdata),
        .s_axi_wvalid(gain_h_wvalid),
        .s_axi_wready(gain_h_wready),
        .s_axi_bvalid(gain_h_bvalid),
        .s_axi_bready(gain_h_bready),
        .s_axi_arready(),
        .s_axi_rvalid()
    );

    // --- QMF SYNTHESIS ---
    qmf_synthesis_axis #(
        .C_S_AXI_ADDR_WIDTH(ADDRW),
        .NTAPS(NTAPS)
    ) u_synthesis (
        .clk(clk), .rstn(rstn),
        .s_axis_low_tdata(gain_low_tdata),
        .s_axis_low_tvalid(gain_low_tvalid),
        .s_axis_low_tready(gain_low_tready),
        .s_axis_low_tlast(gain_low_tlast),
        .s_axis_high_tdata(gain_high_tdata),
        .s_axis_high_tvalid(gain_high_tvalid),
        .s_axis_high_tready(gain_high_tready),
        .s_axis_high_tlast(gain_high_tlast),
        .m_axis_tdata(final_tdata),
        .m_axis_tvalid(final_tvalid),
        .m_axis_tready(final_tready),
        .m_axis_tlast(final_tlast),
        .s_axi_awaddr(syn_awaddr),
        .s_axi_awvalid(syn_awvalid),
        .s_axi_awready(syn_awready),
        .s_axi_wdata(syn_wdata),
        .s_axi_wvalid(syn_wvalid),
        .s_axi_wready(syn_wready),
        .s_axi_bvalid(syn_bvalid),
        .s_axi_bready(syn_bready),
        .s_axi_arready(),
        .s_axi_rvalid()
    );

    // =====================================================================
    // 6. TASKS
    // =====================================================================
    task axis_write_sample(input [31:0] data);
        begin
            src_tdata  <= data;
            src_tvalid <= 1'b1;
            do @(posedge clk); while (!src_tready);
            src_tvalid <= 1'b0;
        end
    endtask

    task axi_write(input [ADDRW-1:0] addr, input [31:0] data, input [1:0] target);
        begin
            @(posedge clk);
            target_sel = target;
            tb_awaddr  = addr;
            tb_wdata   = data;
            tb_awvalid = 1;
            tb_wvalid  = 1;
            tb_bready  = 1;

            case (target)
                0: wait(ana_awready && ana_wready);
                1: wait(syn_awready && syn_wready);
                2: wait(gain_l_awready && gain_l_wready);
                3: wait(gain_h_awready && gain_h_wready);
            endcase

            @(posedge clk);
            tb_awvalid = 0;
            tb_wvalid  = 0;

            case (target)
                0: wait(ana_bvalid);
                1: wait(syn_bvalid);
                2: wait(gain_l_bvalid);
                3: wait(gain_h_bvalid);
            endcase

            tb_bready = 0;
        end
    endtask

    // =====================================================================
    // 7. STIMULUS
    // =====================================================================
    integer i;
    real sin_low, sin_high;
    shortint wave;
    shortint j8a[8] = '{308, -2315, 2275, 16056, 16056, 2275, -2315, 308};

    initial begin
        clk = 0;
        rstn = 0;
        src_tvalid = 0;
        tb_awvalid = 0;
        tb_wvalid  = 0;
        tb_bready  = 0;
        target_sel = 0;

        #100 rstn = 1;
        #100;

        // Configure QMF coefficients
        for (i = 0; i < 8; i++) begin
            axi_write((i+1)*4, {16'd0, j8a[i]}, 0);
            axi_write((i+1)*4, {16'd0, j8a[i]}, 1);
        end

        axi_write(0, 32'h1, 0); // Enable analysis
        axi_write(0, 32'h1, 1); // Enable synthesis

        // Configure gains
        axi_write(4, 32'h0000_2000, 2); // Gain low
        axi_write(0, 32'h1, 2);

        axi_write(4, 32'h0000_0400, 3); // Gain high
        axi_write(0, 32'h1, 3);

        // Stream samples
        for (i = 0; i < 500; i++) begin
            sin_low  = 6000.0 * $sin(2.0 * 3.14159 * i / 40.0);
            sin_high = 4000.0 * $sin(2.0 * 3.14159 * i / 6.0);
            wave = $rtoi(sin_low + sin_high);
            axis_write_sample({wave, wave});
        end

        #2000;
        $finish;
    end

endmodule
