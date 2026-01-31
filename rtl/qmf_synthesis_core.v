// =============================================================
// QMF Synthesis Core
// -------------------------------------------------------------
// Implements the synthesis stage of a two-channel Quadrature
// Mirror Filter (QMF) bank.
//
// - Low-band input is filtered using f0[n] = h0[n]
// - High-band input is filtered using f1[n] = -h0[n] * (-1)^n
//
// The two filtered paths are then summed to reconstruct
// the full-band signal.
//
// This module performs *pure synthesis filtering*:
// no interpolation, no buffering, no AXI logic.
// =============================================================
module qmf_synthesis_core #(
    parameter integer DATAW     = 16,   // Input/output data width
    parameter integer COEFW     = 16,   // FIR coefficient width
    parameter integer NTAPS     = 128,  // Number of FIR taps
    parameter integer OUT_SHIFT = 15    // Output scaling / normalization
)(
    input  wire clk,
    input  wire rstn,
    input  wire en,

    // Subband inputs from QMF analysis stage
    input  wire signed [DATAW-1:0] din_low,
    input  wire signed [DATAW-1:0] din_high,

    // Prototype low-pass coefficients (flattened array)
    input  wire [NTAPS*COEFW-1:0]  h0_coef_flat,

    // Reconstructed full-band output
    output wire signed [DATAW-1:0] dout_merged
);

    // ---------------------------------------------------------
    // Internal filtered subband signals
    // ---------------------------------------------------------
    wire signed [DATAW-1:0] f0_out;
    wire signed [DATAW-1:0] f1_out;

    // ---------------------------------------------------------
    // High-band synthesis coefficient generation
    // ---------------------------------------------------------
    // QMF synthesis relationship:
    //   f1[n] = -h1[n] = -(h0[n] * (-1)^n)
    //
    // This is implemented by alternating the sign of the
    // prototype coefficients, with an additional inversion.
    // ---------------------------------------------------------
    wire [NTAPS*COEFW-1:0] f1_coef_flat;

    genvar i;
    generate
        for (i = 0; i < NTAPS; i = i + 1) begin : gen_f1
            assign f1_coef_flat[i*COEFW +: COEFW] =
                (i % 2 == 0) ?
                   -$signed(h0_coef_flat[i*COEFW +: COEFW]) :
                    h0_coef_flat[i*COEFW +: COEFW];
        end
    endgenerate

    // ---------------------------------------------------------
    // Low-band synthesis filter
    // ---------------------------------------------------------
    // Uses the prototype FIR coefficients f0[n] = h0[n].
    // ---------------------------------------------------------
    fir_core #(
        .DATAW(DATAW),
        .COEFW(COEFW),
        .NTAPS(NTAPS),
        .OUT_SHIFT(OUT_SHIFT)
    ) filter_f0 (
        .clk        (clk),
        .rstn       (rstn),
        .en         (en),
        .clear_state(1'b0),
        .din        (din_low),
        .coef_flat  (h0_coef_flat),
        .dout       (f0_out)
    );

    // ---------------------------------------------------------
    // High-band synthesis filter
    // ---------------------------------------------------------
    // Complementary QMF branch using f1[n].
    // Structure is identical to the low-band path.
    // ---------------------------------------------------------
    fir_core #(
        .DATAW(DATAW),
        .COEFW(COEFW),
        .NTAPS(NTAPS),
        .OUT_SHIFT(OUT_SHIFT)
    ) filter_f1 (
        .clk        (clk),
        .rstn       (rstn),
        .en         (en),
        .clear_state(1'b0),
        .din        (din_high),
        .coef_flat  (f1_coef_flat),
        .dout       (f1_out)
    );

    // ---------------------------------------------------------
    // Final subband summation
    // ---------------------------------------------------------
    // For a properly normalized QMF bank, the direct sum
    // of the two synthesis paths reconstructs the input signal.
    //
    // A simple 1-bit extended accumulator is used to
    // capture potential overflow before saturation.
    // ---------------------------------------------------------
    reg signed [DATAW:0] sum_res;
    always @(posedge clk) begin
        if (!rstn)
            sum_res <= '0;
        else if (en)
            sum_res <= $signed(f0_out) + $signed(f1_out);
    end

    // ---------------------------------------------------------
    // Output saturation
    // ---------------------------------------------------------
    // Clamps the reconstructed signal back to DATAW bits.
    // ---------------------------------------------------------
    assign dout_merged =
        (sum_res >  32767)  ? 16'h7FFF :
        (sum_res < -32768)  ? 16'h8000 :
                              sum_res[DATAW-1:0];

endmodule
