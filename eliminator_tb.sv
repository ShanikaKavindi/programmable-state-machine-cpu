
`timescale 1ns/1ps

module eliminator_tb;

    // Clock / reset
    logic clk;
    logic reset;

    // DUT outputs
    logic halted;
    logic [15:0] pc;

    // Instantiate DUT
    eliminator #(
        .IMEM_DEPTH(256),
        .DMEM_DEPTH(256)
    ) dut (
        .clk(clk),
        .reset(reset),
        .halted(halted),
        .pc(pc)
    );

    // -----------------------
    // Make "results" visible as signals in waveform (no X confusion)
    // Output layout (starting at 100):
    // 100 sumA, 101 avgA, 102 minA, 103 keyA
    // 104 sumB, 105 avgB, 106 minB, 107 keyB
    // 108 sumC, 109 avgC, 110 minC, 111 keyC
    // 112 sumD, 113 avgD, 114 minD, 115 keyD
    // 116 final min_key
    // -----------------------
    logic [31:0] sumA, avgA, minA, keyA;
    logic [31:0] sumB, avgB, minB, keyB;
    logic [31:0] sumC, avgC, minC, keyC;
    logic [31:0] sumD, avgD, minD, keyD;
    logic [31:0] min_key;
    logic [2:0]  elim_id;

    assign sumA    = dut.dmem[100];
    assign avgA    = dut.dmem[101];
    assign minA    = dut.dmem[102];
    assign keyA    = dut.dmem[103];

    assign sumB    = dut.dmem[104];
    assign avgB    = dut.dmem[105];
    assign minB    = dut.dmem[106];
    assign keyB    = dut.dmem[107];

    assign sumC    = dut.dmem[108];
    assign avgC    = dut.dmem[109];
    assign minC    = dut.dmem[110];
    assign keyC    = dut.dmem[111];

    assign sumD    = dut.dmem[112];
    assign avgD    = dut.dmem[113];
    assign minD    = dut.dmem[114];
    assign keyD    = dut.dmem[115];

    assign min_key = dut.dmem[116];
    assign elim_id = min_key[2:0];

    // -----------------------
    // Helpers
    // -----------------------
    function automatic logic [15:0] I(
        input logic [3:0] op,
        input logic [3:0] rd,
        input logic [3:0] rs1,
        input logic [3:0] rs2
    );
        I = {op, rd, rs1, rs2};
    endfunction

    // Opcodes (must match eliminator.sv)
    localparam logic [3:0] OP_ADD   = 4'h0;
    localparam logic [3:0] OP_SUB   = 4'h1;
    localparam logic [3:0] OP_SLL   = 4'h2;
    localparam logic [3:0] OP_SRL   = 4'h3;
    localparam logic [3:0] OP_MUL   = 4'h4;
    localparam logic [3:0] OP_DIV   = 4'h5;
    localparam logic [3:0] OP_MIN   = 4'h6;
    localparam logic [3:0] OP_AND   = 4'h7;
    localparam logic [3:0] OP_LOAD  = 4'h8;
    localparam logic [3:0] OP_STORE = 4'h9;
    localparam logic [3:0] OP_MOV   = 4'hA;
    localparam logic [3:0] OP_HALT  = 4'hF;

    // -----------------------
    // Clock (fast so it finishes within default 1000 ns run)
    // period = 4 ns (250 MHz)
    // -----------------------
    initial clk = 1'b0;
    always #2 clk = ~clk;

    // Loop counters / temp vars
    integer i;
    integer k;
    integer cycles;
    integer p;

    // -----------------------
    // Load marks from marks.txt (optional) OR fallback to hardcoded marks
    // marks.txt format: 20 integers separated by spaces/newlines
    // Example:
    // 78 82 69 90 76
    // 88 85 79 92 86
    // 65 80 78 84 88
    // 85 79 90 78 88
    // -----------------------
    task automatic load_marks;
        integer fd;
        integer ok;
        begin
            fd = $fopen("marks.txt", "r");
            if (fd != 0) begin
                $display("INFO: Loading marks from marks.txt");
                for (i = 0; i < 20; i = i + 1) begin
                    ok = $fscanf(fd, "%d", dut.dmem[i]);
                    if (ok != 1) dut.dmem[i] = 0;
                end
                $fclose(fd);
            end
            else begin
                $display("INFO: marks.txt not found -> using hardcoded marks");
                // Group A (0..4)
                dut.dmem[0]  = 78; dut.dmem[1]  = 82; dut.dmem[2]  = 69; dut.dmem[3]  = 90; dut.dmem[4]  = 76;
                // Group B (5..9)
                dut.dmem[5]  = 88; dut.dmem[6]  = 85; dut.dmem[7]  = 79; dut.dmem[8]  = 92; dut.dmem[9]  = 86;
                // Group C (10..14)
                dut.dmem[10] = 65; dut.dmem[11] = 80; dut.dmem[12] = 78; dut.dmem[13] = 84; dut.dmem[14] = 88;
                // Group D (15..19)
                dut.dmem[15] = 85; dut.dmem[16] = 79; dut.dmem[17] = 90; dut.dmem[18] = 78; dut.dmem[19] = 88;
            end
        end
    endtask

    // -----------------------
    // Main
    // -----------------------
    initial begin
        // Reset high
        reset = 1'b1;

        // Clear memories for clean waveforms
        for (i = 0; i < 256; i = i + 1) begin
            dut.imem[i] = 16'h0000;
            dut.dmem[i] = 32'd0;
        end

        // Load marks (from file if present)
        load_marks();

        // Init registers while reset is high
        for (i = 0; i < 16; i = i + 1) dut.regs[i] = 32'd0;

        dut.regs[0]  = 0;     // r0 = 0
        dut.regs[1]  = 1;     // r1 = 1
        dut.regs[2]  = 100;   // r2 = output pointer (start address)
        dut.regs[3]  = 0;     // r3 = marks pointer (start at 0)
        dut.regs[4]  = 1024;  // r4 = sum multiplier (2^10)
        dut.regs[5]  = 8;     // r5 = min multiplier (2^3)
        dut.regs[6]  = 5;     // r6 = divisor for average (5 students)

        // group IDs in registers
        dut.regs[10] = 0;     // idA
        dut.regs[11] = 1;     // idB
        dut.regs[12] = 2;     // idC
        dut.regs[13] = 3;     // idD

        // -----------------------
        // Load program into IMEM
        // Strategy:
        //  - For each group: compute SUM and MIN of 5 marks
        //  - Compute AVG = SUM / 5
        //  - Store SUM, AVG, MIN, KEY into output region
        //  - KEY = sum*1024 + min*8 + id (so tie-break is automatic)
        //  - Track smallest KEY in r15 (min_key)
        // -----------------------
        p = 0;

        // ---------- GROUP A ----------
        dut.imem[p] = I(OP_LOAD, 4'd7, 4'd0, 4'd3); p=p+1;   // r7 = dmem[r3]
        dut.imem[p] = I(OP_MOV,  4'd8, 4'd7, 4'd0); p=p+1;   // r8 = sum
        dut.imem[p] = I(OP_MOV,  4'd9, 4'd7, 4'd0); p=p+1;   // r9 = min
        dut.imem[p] = I(OP_ADD,  4'd3, 4'd3, 4'd1); p=p+1;   // r3++

        for (k=0; k<4; k=k+1) begin
            dut.imem[p] = I(OP_LOAD, 4'd7, 4'd0, 4'd3); p=p+1;
            dut.imem[p] = I(OP_ADD,  4'd8, 4'd8, 4'd7); p=p+1;
            dut.imem[p] = I(OP_MIN,  4'd9, 4'd9, 4'd7); p=p+1;
            dut.imem[p] = I(OP_ADD,  4'd3, 4'd3, 4'd1); p=p+1;
        end

        dut.imem[p] = I(OP_DIV,  4'd7, 4'd8, 4'd6); p=p+1;   // r7 = avg = sum/5

        // store SUM, AVG, MIN
        dut.imem[p] = I(OP_STORE,4'd8, 4'd0, 4'd2); p=p+1;   // sum
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;
        dut.imem[p] = I(OP_STORE,4'd7, 4'd0, 4'd2); p=p+1;   // avg
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;
        dut.imem[p] = I(OP_STORE,4'd9, 4'd0, 4'd2); p=p+1;   // min
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;

        // keyA in r14
        dut.imem[p] = I(OP_MUL, 4'd14,4'd8, 4'd4); p=p+1;    // sum*1024
        dut.imem[p] = I(OP_MUL, 4'd7, 4'd9, 4'd5); p=p+1;    // min*8
        dut.imem[p] = I(OP_ADD, 4'd14,4'd14,4'd7); p=p+1;
        dut.imem[p] = I(OP_ADD, 4'd14,4'd14,4'd10);p=p+1;    // +idA
        dut.imem[p] = I(OP_STORE,4'd14,4'd0, 4'd2); p=p+1;   // key
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;
        dut.imem[p] = I(OP_MOV,  4'd15,4'd14,4'd0); p=p+1;   // min_key = keyA

        // ---------- GROUP B ----------
        dut.imem[p] = I(OP_LOAD, 4'd7, 4'd0, 4'd3); p=p+1;
        dut.imem[p] = I(OP_MOV,  4'd8, 4'd7, 4'd0); p=p+1;
        dut.imem[p] = I(OP_MOV,  4'd9, 4'd7, 4'd0); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd3, 4'd3, 4'd1); p=p+1;

        for (k=0; k<4; k=k+1) begin
            dut.imem[p] = I(OP_LOAD, 4'd7, 4'd0, 4'd3); p=p+1;
            dut.imem[p] = I(OP_ADD,  4'd8, 4'd8, 4'd7); p=p+1;
            dut.imem[p] = I(OP_MIN,  4'd9, 4'd9, 4'd7); p=p+1;
            dut.imem[p] = I(OP_ADD,  4'd3, 4'd3, 4'd1); p=p+1;
        end

        dut.imem[p] = I(OP_DIV,  4'd7, 4'd8, 4'd6); p=p+1;

        dut.imem[p] = I(OP_STORE,4'd8, 4'd0, 4'd2); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;
        dut.imem[p] = I(OP_STORE,4'd7, 4'd0, 4'd2); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;
        dut.imem[p] = I(OP_STORE,4'd9, 4'd0, 4'd2); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;

        dut.imem[p] = I(OP_MUL, 4'd14,4'd8, 4'd4); p=p+1;
        dut.imem[p] = I(OP_MUL, 4'd7, 4'd9, 4'd5); p=p+1;
        dut.imem[p] = I(OP_ADD, 4'd14,4'd14,4'd7); p=p+1;
        dut.imem[p] = I(OP_ADD, 4'd14,4'd14,4'd11);p=p+1;    // +idB
        dut.imem[p] = I(OP_STORE,4'd14,4'd0, 4'd2); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;
        dut.imem[p] = I(OP_MIN,  4'd15,4'd15,4'd14);p=p+1;    // update min_key

        // ---------- GROUP C ----------
        dut.imem[p] = I(OP_LOAD, 4'd7, 4'd0, 4'd3); p=p+1;
        dut.imem[p] = I(OP_MOV,  4'd8, 4'd7, 4'd0); p=p+1;
        dut.imem[p] = I(OP_MOV,  4'd9, 4'd7, 4'd0); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd3, 4'd3, 4'd1); p=p+1;

        for (k=0; k<4; k=k+1) begin
            dut.imem[p] = I(OP_LOAD, 4'd7, 4'd0, 4'd3); p=p+1;
            dut.imem[p] = I(OP_ADD,  4'd8, 4'd8, 4'd7); p=p+1;
            dut.imem[p] = I(OP_MIN,  4'd9, 4'd9, 4'd7); p=p+1;
            dut.imem[p] = I(OP_ADD,  4'd3, 4'd3, 4'd1); p=p+1;
        end

        dut.imem[p] = I(OP_DIV,  4'd7, 4'd8, 4'd6); p=p+1;

        dut.imem[p] = I(OP_STORE,4'd8, 4'd0, 4'd2); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;
        dut.imem[p] = I(OP_STORE,4'd7, 4'd0, 4'd2); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;
        dut.imem[p] = I(OP_STORE,4'd9, 4'd0, 4'd2); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;

        dut.imem[p] = I(OP_MUL, 4'd14,4'd8, 4'd4); p=p+1;
        dut.imem[p] = I(OP_MUL, 4'd7, 4'd9, 4'd5); p=p+1;
        dut.imem[p] = I(OP_ADD, 4'd14,4'd14,4'd7); p=p+1;
        dut.imem[p] = I(OP_ADD, 4'd14,4'd14,4'd12);p=p+1;    // +idC
        dut.imem[p] = I(OP_STORE,4'd14,4'd0, 4'd2); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;
        dut.imem[p] = I(OP_MIN,  4'd15,4'd15,4'd14);p=p+1;

        // ---------- GROUP D ----------
        dut.imem[p] = I(OP_LOAD, 4'd7, 4'd0, 4'd3); p=p+1;
        dut.imem[p] = I(OP_MOV,  4'd8, 4'd7, 4'd0); p=p+1;
        dut.imem[p] = I(OP_MOV,  4'd9, 4'd7, 4'd0); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd3, 4'd3, 4'd1); p=p+1;

        for (k=0; k<4; k=k+1) begin
            dut.imem[p] = I(OP_LOAD, 4'd7, 4'd0, 4'd3); p=p+1;
            dut.imem[p] = I(OP_ADD,  4'd8, 4'd8, 4'd7); p=p+1;
            dut.imem[p] = I(OP_MIN,  4'd9, 4'd9, 4'd7); p=p+1;
            dut.imem[p] = I(OP_ADD,  4'd3, 4'd3, 4'd1); p=p+1;
        end

        dut.imem[p] = I(OP_DIV,  4'd7, 4'd8, 4'd6); p=p+1;

        dut.imem[p] = I(OP_STORE,4'd8, 4'd0, 4'd2); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;
        dut.imem[p] = I(OP_STORE,4'd7, 4'd0, 4'd2); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;
        dut.imem[p] = I(OP_STORE,4'd9, 4'd0, 4'd2); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;

        dut.imem[p] = I(OP_MUL, 4'd14,4'd8, 4'd4); p=p+1;
        dut.imem[p] = I(OP_MUL, 4'd7, 4'd9, 4'd5); p=p+1;
        dut.imem[p] = I(OP_ADD, 4'd14,4'd14,4'd7); p=p+1;
        dut.imem[p] = I(OP_ADD, 4'd14,4'd14,4'd13);p=p+1;    // +idD
        dut.imem[p] = I(OP_STORE,4'd14,4'd0, 4'd2); p=p+1;
        dut.imem[p] = I(OP_ADD,  4'd2, 4'd2, 4'd1); p=p+1;
        dut.imem[p] = I(OP_MIN,  4'd15,4'd15,4'd14);p=p+1;

        // Final store min_key + HALT
        dut.imem[p] = I(OP_STORE,4'd15,4'd0, 4'd2); p=p+1;    // store at address 116
        dut.imem[p] = I(OP_HALT, 4'd0, 4'd0, 4'd0); p=p+1;

        // -----------------------
        // Release reset and run
        // -----------------------
        @(posedge clk);
        @(posedge clk);
        reset = 1'b0;

        cycles = 0;
        while (!halted && cycles < 500) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (!halted) begin
            $display("ERROR: TIMEOUT (program did not halt)");
            $finish;
        end

        // Print final results (also visible in waveform)
        $display("--------------------------------------------------");
        $display("Group A: sum=%0d avg=%0d min=%0d key=%0d", sumA, avgA, minA, keyA);
        $display("Group B: sum=%0d avg=%0d min=%0d key=%0d", sumB, avgB, minB, keyB);
        $display("Group C: sum=%0d avg=%0d min=%0d key=%0d", sumC, avgC, minC, keyC);
        $display("Group D: sum=%0d avg=%0d min=%0d key=%0d", sumD, avgD, minD, keyD);
        $display("Final min_key = %0d (elim_id=%0d)", min_key, elim_id);

        case (elim_id)
            0: $display("ELIMINATED GROUP = A");
            1: $display("ELIMINATED GROUP = B");
            2: $display("ELIMINATED GROUP = C");
            3: $display("ELIMINATED GROUP = D");
            default: $display("ELIMINATED GROUP = UNKNOWN");
        endcase

        $display("--------------------------------------------------");
        $finish;
    end

endmodule
