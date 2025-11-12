`timescale 1ns / 1ps

module tb_neuron_sigmoid_multi;

    // === Parameters ===
    parameter DATA_WIDTH   = 16;
    parameter NUM_WEIGHT   = 8;
    parameter SIGMOID_SIZE = 10;

    // === DUT Inputs ===
    reg clk, rst;
    reg myinputValid;
    reg weightValid;
    reg biasValid;

    // === DUT Outputs ===
    wire [DATA_WIDTH-1:0] out;
    wire outvalid;

    // === Instantiate DUT (Neuron with Sigmoid Activation) ===
    neuron #(
        .layerNo(0),
        .neuronNo(0),
        .numWeight(NUM_WEIGHT),
        .dataWidth(DATA_WIDTH),
        .sigmoidSize(SIGMOID_SIZE),
        .actType("sigmoid"),        
        .biasFile("b_1_15.mif"),
        .weightFile("w_1_15.mif")
    ) DUT (
        .clk(clk),
        .rst(rst),
        .myinputValid(myinputValid),
        .weightValid(weightValid),
        .biasValid(biasValid),
        .out(out),
        .outvalid(outvalid)
    );

    // === Clock Generation (100 MHz) ===
    always #5 clk = ~clk;

    // === Internal counters and variables ===
    integer i;
    integer j;

    // === Stimulus ===
    initial begin
        $display("========================================");
        $display("   MULTI-OUTPUT TESTBENCH START");
        $display("========================================");

        // Initialize
        clk = 0;
        rst = 1;
        myinputValid = 0;
        weightValid = 0;
        biasValid = 0;

        // Reset phase
        #20;
        rst = 0;
        $display("[%0t] Reset released", $time);

        // ------------------------------------------------------
        // 1?? Load weights (simulated)
        // ------------------------------------------------------
        $display("[%0t] Loading weights...", $time);
        weightValid = 1;
        repeat (NUM_WEIGHT) #10;
        weightValid = 0;

        // ------------------------------------------------------
        // 2?? Load bias
        // ------------------------------------------------------
        $display("[%0t] Loading bias...", $time);
        biasValid = 1;
        #10 biasValid = 0;

        // ------------------------------------------------------
        // 3?? Apply multiple input sequences
        // ------------------------------------------------------
        for (j = 0; j < 5; j = j + 1) begin   // Generate 5 different outputs
            $display("[%0t] --- Input Cycle %0d ---", $time, j+1);
            
            myinputValid = 1;
            repeat (NUM_WEIGHT) #10; // simulate NUM_WEIGHT input samples
            myinputValid = 0;

            // Wait until output valid
            wait (outvalid == 1);
            $display("[%0t] Output #%0d valid. Neuron Output = %h", $time, j+1, out);

            // Hold for a few cycles before next input
            #50;
        end

        // ------------------------------------------------------
        // 4?? Finish
        // ------------------------------------------------------
        #100;
        $display("========================================");
        $display("     MULTI-OUTPUT TEST COMPLETE");
        $display("========================================");
        $stop;
    end

endmodule
