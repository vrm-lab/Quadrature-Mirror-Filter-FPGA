`timescale 1ns / 1ps

// =============================================================
// QMF Analysis AXI Wrapper
// -------------------------------------------------------------
// AXI-Stream + AXI-Lite wrapper for the QMF analysis core.
//
// - Accepts stereo audio samples via AXI-Stream slave
// - Produces low-band and high-band subband streams
// - Provides AXI-Lite register interface for:
//     * Global enable
//     * Prototype filter coefficients (h0[n])
//
// This module is responsible ONLY for:
// - AXI handshaking
// - Register management
// - Channel splitting and recombination
//
// All DSP arithmetic is delegated to qmf_analysis_core.
// =============================================================
module qmf_analysis_axis #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 12, // 4 KB AXI-Lite address space
    parameter integer NTAPS               = 8   // FIR tap count (validation config)
)(
    input  wire clk,
    input  wire rstn,

    // ---------------------------------------------------------
    // AXI-Stream Slave (Stereo Input)
    // ---------------------------------------------------------
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,

    // ---------------------------------------------------------
    // AXI-Stream Master: Low-Band Output
    // ---------------------------------------------------------
    output wire [31:0] m_axis_low_tdata,
    output wire        m_axis_low_tvalid,
    input  wire        m_axis_low_tready,
    output wire        m_axis_low_tlast,

    // ---------------------------------------------------------
    // AXI-Stream Master: High-Band Output
    // ---------------------------------------------------------
    output wire [31:0] m_axis_high_tdata,
    output wire        m_axis_high_tvalid,
    input  wire        m_axis_high_tready,
    output wire        m_axis_high_tlast,

    // ---------------------------------------------------------
    // AXI-Lite Interface (Control & Coefficients)
    // ---------------------------------------------------------
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,
    output reg [1:0]   s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg [31:0]  s_axi_rdata,
    output reg [1:0]   s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready
);

    // =========================================================================
    // 1. AXI4-LITE REGISTER FILE
    // =========================================================================
    // Address map (word-aligned):
    //   0x00 : Control register
    //          bit[0] = global enable
    //
    //   0x04, 0x08, ... :
    //          FIR prototype coefficients h0[n]
    // =========================================================================

    reg signed [15:0] h0_regs [0:NTAPS-1]; // Prototype FIR coefficients
    reg               reg_en;              // Global enable register
    wire [NTAPS*16-1:0] h0_flat;            // Flattened coefficient array

    // ---------------------------------------------------------
    // AXI-Lite WRITE logic
    // ---------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            reg_en        <= 1'b0;
        end else begin
            // Write address & data handshake
            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;

                // Control register
                if (s_axi_awaddr == 0) begin
                    reg_en <= s_axi_wdata[0];
                end else begin
                    // Coefficient registers
                    // Index = (address >> 2) - 1
                    h0_regs[s_axi_awaddr[C_S_AXI_ADDR_WIDTH-1:2] - 1]
                        <= s_axi_wdata[15:0];
                end
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
            end

            // Write response
            if (s_axi_awready && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY
            end else if (s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------
    // AXI-Lite READ logic
    // ---------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'd0;
        end else begin
            if (!s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00; // OKAY

                if (s_axi_araddr == 0) begin
                    s_axi_rdata <= {31'd0, reg_en};
                end else begin
                    s_axi_rdata <= {
                        16'd0,
                        h0_regs[s_axi_araddr[C_S_AXI_ADDR_WIDTH-1:2] - 1]
                    };
                end
            end else begin
                s_axi_arready <= 1'b0;
                if (s_axi_rvalid && s_axi_rready)
                    s_axi_rvalid <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------
    // Flatten coefficient array for DSP core
    // ---------------------------------------------------------
    genvar k;
    generate
        for (k = 0; k < NTAPS; k = k + 1) begin : flatten_coeffs
            assign h0_flat[k*16 +: 16] = h0_regs[k];
        end
    endgenerate

    // =========================================================================
    // 2. AXI-STREAM HANDSHAKING & PIPELINING
    // =========================================================================
    // The input stream is accepted ONLY when both output streams
    // are ready. This guarantees symmetric flow and avoids
    // subband misalignment due to backpressure.
    // =========================================================================

    wire stream_ready_out = m_axis_low_tready && m_axis_high_tready;

    assign s_axis_tready = stream_ready_out;

    // Core enable condition:
    // - global enable asserted
    // - valid input sample
    // - both output paths ready
    wire core_en = reg_en && s_axis_tvalid && stream_ready_out;

    // ---------------------------------------------------------
    // QMF Analysis Core Instantiation (Stereo)
    // ---------------------------------------------------------

    // Left channel: bits [15:0]
    qmf_analysis_core #(.NTAPS(NTAPS)) analysis_L (
        .clk(clk),
        .rstn(rstn),
        .en(core_en),
        .din(s_axis_tdata[15:0]),
        .h0_coef_flat(h0_flat),
        .dout_low(m_axis_low_tdata[15:0]),
        .dout_high(m_axis_high_tdata[15:0])
    );

    // Right channel: bits [31:16]
    qmf_analysis_core #(.NTAPS(NTAPS)) analysis_R (
        .clk(clk),
        .rstn(rstn),
        .en(core_en),
        .din(s_axis_tdata[31:16]),
        .h0_coef_flat(h0_flat),
        .dout_low(m_axis_low_tdata[31:16]),
        .dout_high(m_axis_high_tdata[31:16])
    );

    // ---------------------------------------------------------
    // Control signal pipelining (VALID / LAST)
    // ---------------------------------------------------------
    // The DSP core introduces a fixed processing latency.
    // VALID and LAST are delayed accordingly to remain
    // aligned with the output data.
    //
    // When stalled, control signals are held.
    // ---------------------------------------------------------
    reg valid_delayed;
    reg last_delayed;

    always @(posedge clk) begin
        if (!rstn) begin
            valid_delayed <= 1'b0;
            last_delayed  <= 1'b0;
        end else if (stream_ready_out) begin
            valid_delayed <= s_axis_tvalid && reg_en;
            last_delayed  <= s_axis_tlast;
        end
    end

    // Output control signals
    assign m_axis_low_tvalid  = valid_delayed;
    assign m_axis_high_tvalid = valid_delayed;

    assign m_axis_low_tlast   = last_delayed;
    assign m_axis_high_tlast  = last_delayed;

endmodule
