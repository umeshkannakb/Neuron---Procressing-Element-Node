module neuron #(
    parameter layerNo = 0,
    parameter neuronNo = 0,
    parameter numWeight = 8,
    parameter dataWidth = 16,
    parameter sigmoidSize = 10,
    parameter weightIntWidth = 1,
    parameter actType = "sigmoid",
    parameter biasFile = "b_1_15.mif",
    parameter weightFile = "w_1_15.mif"
)(
    input           clk,
    input           rst,
    input           myinputValid,
    input           weightValid,
    input           biasValid,
    output [dataWidth-1:0] out,
    output reg      outvalid
);

    // -----------------------------
    // Default constant assignments
    // -----------------------------
    wire [dataWidth-1:0] myinput       = 16'd5;      // simple constant test input
    wire [31:0] weightValue            = 32'h0003_0001;  // fixed weight for testing
    wire [31:0] biasValue              = 32'h0000_0001;  // fixed bias
    wire [31:0] config_layer_num       = 32'd0;
    wire [31:0] config_neuron_num      = 32'd0;

    // -----------------------------
    // Internal signals
    // -----------------------------
    localparam addressWidth = $clog2(numWeight);

    reg         wen;
    wire        ren;
    reg [addressWidth-1:0] w_addr;
    reg [addressWidth:0]   r_addr;
    reg [dataWidth-1:0]    w_in;
    wire [dataWidth-1:0]   w_out;
    reg [2*dataWidth-1:0]  mul; 
    reg [2*dataWidth-1:0]  sum;
    reg [2*dataWidth-1:0]  bias;
    reg [31:0]             biasReg[0:0];
    reg                    weight_valid;
    reg                    mult_valid;
    wire                   mux_valid;
    reg                    sigValid; 
    wire [2*dataWidth:0]   comboAdd;
    wire [2*dataWidth:0]   BiasAdd;
    reg  [dataWidth-1:0]   myinputd;
    reg                    muxValid_d;
    reg                    muxValid_f;
    reg                    addr = 0;

    // -----------------------------
    // Weight loading logic
    // -----------------------------
    always @(posedge clk) begin
        if (rst) begin
            w_addr <= {addressWidth{1'b1}};
            wen <= 0;
        end else if (weightValid & (config_layer_num == layerNo) & (config_neuron_num == neuronNo)) begin
            w_in <= weightValue[dataWidth-1:0];
            w_addr <= w_addr + 1;
            wen <= 1;
        end else begin
            wen <= 0;
        end
    end

    assign mux_valid = mult_valid;
    assign comboAdd = mul + sum;
    assign BiasAdd = bias + sum;
    assign ren = myinputValid;

    // -----------------------------
    // Bias loading logic
    // -----------------------------
    `ifdef pretrained
        initial begin
            $readmemb(biasFile, biasReg);
        end
        always @(posedge clk) begin
            bias <= {biasReg[addr][dataWidth-1:0], {dataWidth{1'b0}}};
        end
    `else
        always @(posedge clk) begin
            if (biasValid & (config_layer_num == layerNo) & (config_neuron_num == neuronNo)) begin
                bias <= {biasValue[dataWidth-1:0], {dataWidth{1'b0}}};
            end
        end
    `endif

    // -----------------------------
    // Read address update
    // -----------------------------
    always @(posedge clk) begin
        if (rst | outvalid)
            r_addr <= 0;
        else if (myinputValid)
            r_addr <= r_addr + 1;
    end

    // -----------------------------
    // Multiply and accumulate
    // -----------------------------
    always @(posedge clk) begin
        mul <= $signed(myinputd) * $signed(w_out);
    end

    always @(posedge clk) begin
        if (rst | outvalid)
            sum <= 0;
        else if ((r_addr == numWeight) & muxValid_f) begin
            // Bias addition with saturation
            if (!bias[2*dataWidth-1] & !sum[2*dataWidth-1] & BiasAdd[2*dataWidth-1])
                sum <= {1'b0, {(2*dataWidth-1){1'b1}}};
            else if (bias[2*dataWidth-1] & sum[2*dataWidth-1] & !BiasAdd[2*dataWidth-1])
                sum <= {1'b1, {(2*dataWidth-1){1'b0}}};
            else
                sum <= BiasAdd;
        end else if (mux_valid) begin
            // Multiply-accumulate
            if (!mul[2*dataWidth-1] & !sum[2*dataWidth-1] & comboAdd[2*dataWidth-1])
                sum <= {1'b0, {(2*dataWidth-1){1'b1}}};
            else if (mul[2*dataWidth-1] & sum[2*dataWidth-1] & !comboAdd[2*dataWidth-1])
                sum <= {1'b1, {(2*dataWidth-1){1'b0}}};
            else
                sum <= comboAdd;
        end
    end

    // -----------------------------
    // Control signal timing
    // -----------------------------
    always @(posedge clk) begin
        myinputd <= myinput;
        weight_valid <= myinputValid;
        mult_valid <= weight_valid;
        sigValid <= ((r_addr == numWeight) & muxValid_f) ? 1'b1 : 1'b0;
        outvalid <= sigValid;
        muxValid_d <= mux_valid;
        muxValid_f <= !mux_valid & muxValid_d;
    end

    // -----------------------------
    // Instantiate Weight Memory
    // -----------------------------
    Weight_Memory #(
        .numWeight(numWeight),
        .neuronNo(neuronNo),
        .layerNo(layerNo),
        .addressWidth(addressWidth),
        .dataWidth(dataWidth),
        .weightFile(weightFile)
    ) WM (
        .clk(clk),
        .wen(wen),
        .ren(ren),
        .wadd(w_addr),
        .radd(r_addr),
        .win(w_in),
        .wout(w_out)
    );

    // -----------------------------
    // Activation Function
    // -----------------------------
    generate
        if (actType == "sigmoid") begin : siginst
            Sig_ROM #(
                .inWidth(sigmoidSize),
                .dataWidth(dataWidth)
            ) s1 (
                .clk(clk),
                .x(sum[2*dataWidth-1-:sigmoidSize]),
                .out(out)
            );
        end else begin : ReLUinst
            ReLU #(
                .dataWidth(dataWidth),
                .weightIntWidth(weightIntWidth)
            ) s1 (
                .clk(clk),
                .x(sum),
                .out(out)
            );
        end
    endgenerate

endmodule
