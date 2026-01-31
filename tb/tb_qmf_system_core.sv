`timescale 1ns/1ps

// =============================================================
// Testbench: QMF System Core (Analysis -> Synthesis)
// -------------------------------------------------------------
// System-level functional verification for the QMF core chain:
//
//   qmf_analysis_core -> qmf_synthesis_core
//
// Verification goals:
// - Validate end-to-end behavior of the QMF system at core level
// - Observe subband signals (low/high) and reconstructed output
// - Provide CSV output for offline inspection
//
// Validation configuration:
// - Johnston 8A prototype filter
// - 8-tap FIR
//
// This testbench is a practical sanity check.
// It is not intended as a formal perfect-reconstruction proof.
// =============================================================
module tb_qmf_system_core;

    // ========================================================================
    // 1. PARAMETERS & SIGNALS
    // ========================================================================
    parameter integer DATAW     = 16;
    parameter integer COEFW     = 16;
    parameter integer NTAPS     = 8;   // Validation config: Johnston 8A
    parameter integer OUT_SHIFT = 15;  // Q15 normalization

    reg  clk;
    reg  rstn;
    reg  en;
    reg  signed [DATAW-1:0] din;
    reg  [NTAPS*COEFW-1:0]  h0_coef_flat;

    // Interconnect signals (analysis -> synthesis)
    wire signed [DATAW-1:0] low_band;
    wire signed [DATAW-1:0] high_band;

    // Final reconstructed output
    wire signed [DATAW-1:0] dout_merged;

    // Simulation helpers
    integer f;
    integer i;

    real phase_low;
    real phase_high;
    real ampl_low;
    real ampl_high;
    real sin_val;
    real pi;

    // ========================================================================
    // 2. CLOCK GENERATION
    // ========================================================================
    // 100 MHz clock (10 ns period)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ========================================================================
    // 3. SYSTEM INSTANTIATION (BACK-TO-BACK)
    // ========================================================================

    // ---------------------------------------------------------
    // Unit 1: QMF Analysis Core
    // ---------------------------------------------------------
    qmf_analysis_core #(
        .DATAW     (DATAW),
        .COEFW     (COEFW),
        .NTAPS     (NTAPS),
        .OUT_SHIFT (OUT_SHIFT)
    ) dut_analysis (
        .clk         (clk),
        .rstn        (rstn),
        .en          (en),
        .din         (din),
        .h0_coef_flat(h0_coef_flat),
        .dout_low    (low_band),
        .dout_high   (high_band)
    );

    // ---------------------------------------------------------
    // Unit 2: QMF Synthesis Core
    // ---------------------------------------------------------
    qmf_synthesis_core #(
        .DATAW     (DATAW),
        .COEFW     (COEFW),
        .NTAPS     (NTAPS),
        .OUT_SHIFT (OUT_SHIFT)
    ) dut_synthesis (
        .clk         (clk),
        .rstn        (rstn),
        .en          (en),
        .din_low     (low_band),
        .din_high    (high_band),
        .h0_coef_flat(h0_coef_flat), // Same prototype coefficients
        .dout_merged (dout_merged)
    );

    // ========================================================================
    // 4. MAIN STIMULUS
    // ========================================================================
    initial begin
        // -----------------------------------------------------
        // A. CSV FILE INITIALIZATION
        // -----------------------------------------------------
        i = 0;
        f = $fopen("tb_data_qmf_system.csv", "w");
        if (f == 0) begin
            $display("ERROR: Failed to open CSV output file.");
            $finish;
        end

        // Log: original input, subbands, reconstructed output
        $fwrite(f, "time_ns,din_orig,sub_low,sub_high,dout_recon\n");

        // -----------------------------------------------------
        // B. PROTOTYPE FILTER COEFFICIENTS (Johnston 8A, Q15)
        // -----------------------------------------------------
        // Coefficient ordering:
        //   index 0  -> h0 (LSB)
        //   index 7  -> h7 (MSB)
        h0_coef_flat = '0;
        h0_coef_flat[0*16 +: 16] =  16'sd308;    // h(0)
        h0_coef_flat[1*16 +: 16] = -16'sd2315;   // h(1)
        h0_coef_flat[2*16 +: 16] =  16'sd2275;   // h(2)
        h0_coef_flat[3*16 +: 16] =  16'sd16056;  // h(3)
        h0_coef_flat[4*16 +: 16] =  16'sd16056;  // h(4)
        h0_coef_flat[5*16 +: 16] =  16'sd2275;   // h(5)
        h0_coef_flat[6*16 +: 16] = -16'sd2315;   // h(6)
        h0_coef_flat[7*16 +: 16] =  16'sd308;    // h(7)

        // -----------------------------------------------------
        // C. RESET AND INITIAL CONDITIONS
        // -----------------------------------------------------
        rstn = 1'b0;
        en   = 1'b0;
        din  = '0;

        phase_low  = 0.0;
        phase_high = 0.0;
        ampl_low   = 10000.0;
        ampl_high  = 5000.0;
        pi         = 3.14159265359;

        #100;
        rstn = 1'b1;
        #20;
        en   = 1'b1;

        $display("Starting QMF system-level simulation (analysis -> synthesis)...");

        // -----------------------------------------------------
        // D. INPUT SIGNAL LOOP
        // -----------------------------------------------------
        // Composite signal:
        // - Low-frequency sinusoid (Fs / 50)
        // - High-frequency sinusoid (Fs / 4)
        for (i = 0; i < 1000; i = i + 1) begin
            @(posedge clk);

            phase_low  += (2.0 * pi / 50.0);
            phase_high += (2.0 * pi / 4.0);

            sin_val = (ampl_low  * $sin(phase_low)) +
                      (ampl_high * $sin(phase_high));

            din = $rtoi(sin_val);

            // Small delay to ensure stable outputs before logging
            #1;
            $fwrite(
                f,
                "%0d,%0d,%0d,%0d,%0d\n",
                $time,
                $signed(din),
                $signed(low_band),
                $signed(high_band),
                $signed(dout_merged)
            );
        end

        // -----------------------------------------------------
        // E. END OF SIMULATION
        // -----------------------------------------------------
        #100;
        $display("Simulation complete. Output written to tb_data_qmf_system_core.csv");
        $fclose(f);
        $finish;
    end

endmodule
