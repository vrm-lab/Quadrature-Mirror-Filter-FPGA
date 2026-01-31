`timescale 1ns / 1ps

// =============================================================
// Testbench: QMF Analysis AXI Wrapper
// -------------------------------------------------------------
// Integration-level verification for qmf_analysis_axis.
//
// Verification scope:
// - AXI-Lite register access (write + readback verification)
// - AXI-Stream input/output handshaking
// - Stereo QMF analysis behavior
//
// Validation configuration:
// - Johnston 8A prototype filter
// - 8-tap FIR
//
// This testbench focuses on:
// - Correct AXI behavior
// - End-to-end data flow
//
// It is NOT a performance or stress test.
// =============================================================
module tb_qmf_analysis_axis;

    // ========================================================================
    // 1. PARAMETERS
    // ========================================================================
    parameter integer C_S_AXI_DATA_WIDTH = 32;
    parameter integer C_S_AXI_ADDR_WIDTH = 12;
    parameter integer NTAPS               = 8; // Validation config: Johnston 8A

    // ========================================================================
    // 2. INTERFACE SIGNALS
    // ========================================================================
    reg clk;
    reg rstn;

    // ---------------------------------------------------------
    // AXI-Stream Slave (Input)
    // ---------------------------------------------------------
    reg  [31:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;
    reg         s_axis_tlast;

    // ---------------------------------------------------------
    // AXI-Stream Master: Low-Band Output
    // ---------------------------------------------------------
    wire [31:0] m_axis_low_tdata;
    wire        m_axis_low_tvalid;
    reg         m_axis_low_tready;
    wire        m_axis_low_tlast;

    // ---------------------------------------------------------
    // AXI-Stream Master: High-Band Output
    // ---------------------------------------------------------
    wire [31:0] m_axis_high_tdata;
    wire        m_axis_high_tvalid;
    reg         m_axis_high_tready;
    wire        m_axis_high_tlast;

    // ---------------------------------------------------------
    // AXI-Lite Write Channel
    // ---------------------------------------------------------
    reg  [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    reg                           s_axi_awvalid;
    wire                          s_axi_awready;
    reg  [31:0]                   s_axi_wdata;
    reg                           s_axi_wvalid;
    wire                          s_axi_wready;
    wire [1:0]                    s_axi_bresp;
    wire                          s_axi_bvalid;
    reg                           s_axi_bready;

    // ---------------------------------------------------------
    // AXI-Lite Read Channel
    // ---------------------------------------------------------
    reg  [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    reg                           s_axi_arvalid;
    wire                          s_axi_arready;
    wire [31:0]                   s_axi_rdata;
    wire [1:0]                    s_axi_rresp;
    wire                          s_axi_rvalid;
    reg                           s_axi_rready;

    // ========================================================================
    // 3. SIMULATION VARIABLES
    // ========================================================================
    integer f;
    integer i;

    // Signal generator (simulation-only)
    real phase_low;
    real phase_high;
    real ampl_low;
    real ampl_high;
    real sin_val;
    real pi;

    reg signed [15:0] audio_sample;

    // Prototype coefficients & readback buffer
    reg signed [15:0] coeffs [0:NTAPS-1];
    reg [31:0]        read_data_temp;

    // ========================================================================
    // 4. DUT INSTANTIATION
    // ========================================================================
    qmf_analysis_axis #(
        .NTAPS(NTAPS)
    ) uut (
        .clk(clk),
        .rstn(rstn),

        // AXI-Stream input
        .s_axis_tdata (s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast (s_axis_tlast),

        // AXI-Stream low-band output
        .m_axis_low_tdata (m_axis_low_tdata),
        .m_axis_low_tvalid(m_axis_low_tvalid),
        .m_axis_low_tready(m_axis_low_tready),
        .m_axis_low_tlast (m_axis_low_tlast),

        // AXI-Stream high-band output
        .m_axis_high_tdata (m_axis_high_tdata),
        .m_axis_high_tvalid(m_axis_high_tvalid),
        .m_axis_high_tready(m_axis_high_tready),
        .m_axis_high_tlast (m_axis_high_tlast),

        // AXI-Lite write
        .s_axi_awaddr (s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata  (s_axi_wdata),
        .s_axi_wvalid (s_axi_wvalid),
        .s_axi_wready (s_axi_wready),
        .s_axi_bresp  (s_axi_bresp),
        .s_axi_bvalid (s_axi_bvalid),
        .s_axi_bready (s_axi_bready),

        // AXI-Lite read
        .s_axi_araddr (s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata  (s_axi_rdata),
        .s_axi_rresp  (s_axi_rresp),
        .s_axi_rvalid (s_axi_rvalid),
        .s_axi_rready (s_axi_rready)
    );

    // ========================================================================
    // 5. CLOCK GENERATION
    // ========================================================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 100 MHz
    end

    // ========================================================================
    // 6. AXI-LITE TRANSACTION TASKS
    // ========================================================================

    // ---------------------------------------------------------
    // AXI-Lite WRITE transaction
    // ---------------------------------------------------------
    task axi_write;
        input [11:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            s_axi_awaddr  <= addr;
            s_axi_wdata   <= data;
            s_axi_awvalid <= 1'b1;
            s_axi_wvalid  <= 1'b1;
            s_axi_bready  <= 1'b1;

            // Wait for address & data acceptance
            wait (s_axi_awready && s_axi_wready);

            @(posedge clk);
            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;

            // Wait for write response
            wait (s_axi_bvalid);
            @(posedge clk);
            s_axi_bready <= 1'b0;
        end
    endtask

    // ---------------------------------------------------------
    // AXI-Lite READ transaction
    // ---------------------------------------------------------
    task axi_read;
        input  [11:0] addr;
        output [31:0] data_out;
        begin
            @(posedge clk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= 1'b1;
            s_axi_rready  <= 1'b1;

            // Wait for address acceptance
            wait (s_axi_arready);
            @(posedge clk);
            s_axi_arvalid <= 1'b0;

            // Wait for read data
            wait (s_axi_rvalid);
            data_out = s_axi_rdata;

            @(posedge clk);
            s_axi_rready <= 1'b0;
        end
    endtask

    // ========================================================================
    // 7. MAIN STIMULUS
    // ========================================================================
    initial begin
        // -----------------------------------------------------
        // Initialization
        // -----------------------------------------------------
        f = $fopen("tb_data_qmf_analysis_axis.csv", "w");
        $fwrite(
            f,
            "time_ns,din_sample,"
            "dout_low_L,dout_low_R,"
            "dout_high_L,dout_high_R\n"
        );

        rstn = 1'b0;
        i    = 0;

        // AXI-Stream init
        s_axis_tvalid = 1'b0;
        s_axis_tdata  = 32'd0;
        s_axis_tlast  = 1'b0;
        m_axis_low_tready  = 1'b1;
        m_axis_high_tready = 1'b1;

        // AXI-Lite init
        s_axi_awaddr  = 12'd0;
        s_axi_awvalid = 1'b0;
        s_axi_wdata   = 32'd0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;

        s_axi_araddr  = 12'd0;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;

        // Signal generator setup
        phase_low  = 0.0;
        phase_high = 0.0;
        ampl_low   = 10000.0;
        ampl_high  = 5000.0;
        pi         = 3.14159265359;

        // Johnston 8A coefficients (Q15)
        coeffs[0] =  16'd308;    coeffs[1] = -16'd2315;
        coeffs[2] =  16'd2275;   coeffs[3] =  16'd16056;
        coeffs[4] =  16'd16056;  coeffs[5] =  16'd2275;
        coeffs[6] = -16'd2315;   coeffs[7] =  16'd308;

        #100;
        rstn = 1'b1;
        #100;

        // -----------------------------------------------------
        // Phase 1: AXI-Lite configuration
        // -----------------------------------------------------
        $display("[AXI-LITE] Writing FIR coefficients...");
        for (i = 0; i < NTAPS; i = i + 1)
            axi_write((i + 1) * 4, {16'd0, coeffs[i]});

        // -----------------------------------------------------
        // Phase 2: AXI-Lite readback verification
        // -----------------------------------------------------
        $display("[AXI-LITE] Readback verification...");
        for (i = 0; i < NTAPS; i = i + 1) begin
            axi_read((i + 1) * 4, read_data_temp);
            if (read_data_temp[15:0] !== coeffs[i])
                $display(
                    "ERROR @ index %0d: expected %0d, got %0d",
                    i, coeffs[i], $signed(read_data_temp[15:0])
                );
            else
                $display(
                    "Index %0d OK: %0d",
                    i, $signed(read_data_temp[15:0])
                );
        end

        // Enable core
        $display("[CONTROL] Enabling QMF analysis core");
        axi_write(12'd0, 32'd1);

        #50;

        // -----------------------------------------------------
        // Phase 3: Streaming audio samples
        // -----------------------------------------------------
        $display("[STREAM] Starting audio stream...");
        for (i = 0; i < 1000; i = i + 1) begin
            @(posedge clk);

            phase_low  += (2.0 * pi / 50.0);
            phase_high += (2.0 * pi / 4.0);
            sin_val     = (ampl_low  * $sin(phase_low)) +
                          (ampl_high * $sin(phase_high));

            audio_sample = $rtoi(sin_val);

            s_axis_tdata  = {audio_sample, audio_sample};
            s_axis_tvalid = 1'b1;
            s_axis_tlast  = (i == 999);

            wait (s_axis_tready);

            @(posedge clk);
            s_axis_tvalid = 1'b0;
            s_axis_tlast  = 1'b0;
        end

        #200;
        $display("Simulation completed. Output written to CSV.");
        $fclose(f);
        $finish;
    end

    // ========================================================================
    // 8. OUTPUT LOGGING
    // ========================================================================
    always @(posedge clk) begin
        if (m_axis_low_tvalid && m_axis_high_tvalid && m_axis_low_tready) begin
            $fwrite(
                f,
                "%0d,%0d,%0d,%0d,%0d,%0d\n",
                $time,
                audio_sample,
                $signed(m_axis_low_tdata [15:0]),
                $signed(m_axis_low_tdata [31:16]),
                $signed(m_axis_high_tdata[15:0]),
                $signed(m_axis_high_tdata[31:16])
            );
        end
    end

endmodule
