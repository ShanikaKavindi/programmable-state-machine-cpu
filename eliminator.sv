
`timescale 1ns/1ps

module eliminator #(
    parameter int IMEM_DEPTH = 256,
    parameter int DMEM_DEPTH = 256
) (
    input  logic clk,
    input  logic reset,
    output logic halted,
    output logic [15:0] pc
);

    // Memories + register file (testbench can access: dut.imem, dut.dmem, dut.regs)
    logic [15:0] imem [0:IMEM_DEPTH-1];
    logic [31:0] dmem [0:DMEM_DEPTH-1];
    logic [31:0] regs [0:15];

    // Address widths for safe indexing
    localparam int IM_ADDR_W = (IMEM_DEPTH <= 1) ? 1 : $clog2(IMEM_DEPTH);
    localparam int DM_ADDR_W = (DMEM_DEPTH <= 1) ? 1 : $clog2(DMEM_DEPTH);

    // Current instruction (combinational fetch/decode)
    logic [15:0] instr;
    logic [3:0]  opcode, rd, rs1, rs2;

    // Data memory address (combinational)
    logic [DM_ADDR_W-1:0] daddr;

    always_comb begin
        instr  = imem[ pc[IM_ADDR_W-1:0] ];
        opcode = instr[15:12];
        rd     = instr[11:8];
        rs1    = instr[7:4];
        rs2    = instr[3:0];

        daddr  = regs[rs1][DM_ADDR_W-1:0] + regs[rs2][DM_ADDR_W-1:0];
    end

    // Execute one instruction per clock
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pc     <= 16'd0;
            halted <= 1'b0;
            regs[0] <= 32'd0;
        end
        else if (!halted) begin
            // default PC increment
            pc <= pc + 16'd1;

            unique case (opcode)
                4'h0: regs[rd] <= regs[rs1] + regs[rs2];                       // ADD
                4'h1: regs[rd] <= regs[rs1] - regs[rs2];                       // SUB
                4'h2: regs[rd] <= regs[rs1] << regs[rs2][4:0];                 // SLL
                4'h3: regs[rd] <= regs[rs1] >> regs[rs2][4:0];                 // SRL
                4'h4: regs[rd] <= regs[rs1] * regs[rs2];                       // MUL
                4'h5: regs[rd] <= (regs[rs2] == 0) ? 32'd0 : (regs[rs1] / regs[rs2]); // DIV
                4'h6: regs[rd] <= ($signed(regs[rs1]) < $signed(regs[rs2])) ? regs[rs1] : regs[rs2]; // MIN (signed)
                4'h7: regs[rd] <= regs[rs1] & regs[rs2];                       // AND
                4'h8: regs[rd] <= dmem[daddr];                                  // LOAD
                4'h9: dmem[daddr] <= regs[rd];                                  // STORE
                4'hA: regs[rd] <= regs[rs1];                                   // MOV
                4'hF: begin                                                     // HALT
                    halted <= 1'b1;
                    pc     <= pc; // hold PC
                end
                default: begin
                    // NOP for undefined opcode
                end
            endcase

            // keep r0 = 0
            regs[0] <= 32'd0;
        end
    end

endmodule
