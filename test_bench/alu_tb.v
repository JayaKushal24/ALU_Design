`timescale 1ns/1ps
//`include "alu_reference_model.v"
//`include "alu_dut.v"
module alu_tb;

parameter N         = 8;
parameter CMD_WIDTH = 4;
parameter MAX_QUEUE = 512;

reg CLK,RST,CE,MODE,CIN;
reg [1:0]  INP_VALID;
reg [3:0]  CMD;
reg [N-1:0] OPA, OPB;
wire [(N*2)-1:0] RES;
wire ERR, OFLOW, COUT, G, L, E;
wire [(N*2)-1:0] exp_RES;
wire exp_ERR, exp_OFLOW, exp_COUT, exp_G, exp_L, exp_E;
integer pass_count, fail_count, test_count;
integer cycle_num;

//  Queue (FIFO) - driver writes, scoreboard reads
reg [(N*2)-1:0] q_res    [0:MAX_QUEUE-1];
reg             q_err    [0:MAX_QUEUE-1];
reg             q_oflow  [0:MAX_QUEUE-1];
reg             q_cout   [0:MAX_QUEUE-1];
reg             q_g      [0:MAX_QUEUE-1];
reg             q_l      [0:MAX_QUEUE-1];
reg             q_e      [0:MAX_QUEUE-1];
reg [8*40-1:0]  q_name   [0:MAX_QUEUE-1];
reg [3:0]       q_cmd    [0:MAX_QUEUE-1];
reg [N-1:0]     q_opa    [0:MAX_QUEUE-1];
reg [N-1:0]     q_opb    [0:MAX_QUEUE-1];
reg             q_is_mul [0:MAX_QUEUE-1];
integer         q_check_cycle [0:MAX_QUEUE-1];

integer q_head, q_tail;

alu_dut #(.WIDTH(N)) DUT (
    .CLK(CLK), .RST(RST), .CE(CE),
    .MODE(MODE), .CIN(CIN),
    .INP_VALID(INP_VALID), .CMD(CMD),
    .OPA(OPA), .OPB(OPB),
    .RES(RES), .COUT(COUT),
    .OFLOW(OFLOW), .G(G), .E(E), .L(L), .ERR(ERR)
);


//alu DUT (.clk(CLK),.rst(RST),         .ce        (CE),         .mode      (MODE),         .in_iv (INP_VALID),         .cmd       (CMD),         .in_a       (OPA),         .in_b       (OPB),         .in_cin       (CIN),         .res       (RES),         .err       (ERR),         .oflow     (OFLOW),         .cout      (COUT),         .g         (G),         .e         (E),         .l         (L)     );

alu_reference_model #(.N(N)) REF (
    .id(0),
    .OPA(OPA), .OPB(OPB),
    .CIN(CIN), .MODE(MODE),
    .INP_VALID(INP_VALID), .CMD(CMD),
    .id_out(),
    .RES(exp_RES), .COUT(exp_COUT),
    .OFLOW(exp_OFLOW), .G(exp_G),
    .E(exp_E), .L(exp_L), .ERR(exp_ERR)
);

initial begin
    cycle_num = 0;
    CLK = 0;
    forever #5 CLK = ~CLK;
end

//counts posedges so scoreboard can keep track
always @(posedge CLK) begin
    cycle_num = cycle_num + 1;
end

//printing DUT value at evry posedge clk for debugiing 
always @(posedge CLK) begin
    #1;
    $display("[DUT] Cycle=%4d time=%-8t MODE=%b CMD=%2d VALID=%2b CIN=%b OPA=%3d OPB=%3d | RES=%5d ERR=%b COUT=%b OFLOW=%b G=%b L=%b E=%b",
                    cycle_num, $time,    MODE,    CMD, INP_VALID, CIN,    OPA,    OPB,       RES,   ERR,   COUT,   OFLOW,   G,   L,   E);
end

task driver_send;
    input [3:0]       t_cmd;
    input [N-1:0]     t_opa, t_opb;
    input             t_cin;
    input [1:0]       t_valid;
    input             t_mode;
    input [8*40-1:0]  test_name;

    reg is_mul;
    begin
        is_mul = (t_mode == 1'b1) && (t_cmd == 4'd9 || t_cmd == 4'd10);

        @(negedge CLK);//at every negedge a value will be driver
        $display("New inputs given at NEGEDGE time =%0t",$time);

        MODE      = t_mode;
        CMD       = t_cmd;
        OPA       = t_opa;
        OPB       = t_opb;
        CIN       = t_cin;
        INP_VALID = t_valid;

        $display("[DRV] time=%-8t Sending: %-40s CMD=%0d OPA=%3d(%0d) OPB=%3d(%0d) MODE=%b VALID=%2b",
                 $time, test_name, t_cmd, t_opa, $signed(t_opa), t_opb, $signed(t_opb), t_mode, t_valid);

        // reference values are sent to queue
        #1;//settle combinatorially then snapshot
        q_res   [q_tail] = exp_RES;
        q_err   [q_tail] = exp_ERR;
        q_oflow [q_tail] = exp_OFLOW;
        q_cout  [q_tail] = exp_COUT;
        q_g     [q_tail] = exp_G;
        q_l     [q_tail] = exp_L;
        q_e     [q_tail] = exp_E;
        q_name  [q_tail] = test_name;
        q_cmd   [q_tail] = t_cmd;
        q_opa   [q_tail] = t_opa;
        q_opb   [q_tail] = t_opb;
        q_is_mul[q_tail] = is_mul;

        if (is_mul)     q_check_cycle[q_tail] = cycle_num + 3;//for mul need 3 cycles
        else            q_check_cycle[q_tail] = cycle_num + 2;//2 cycles
        q_tail = q_tail + 1;
     end
endtask

task scoreboard_check;
    reg [(N*2)-1:0] s_res;
    reg             s_err, s_oflow, s_cout;
    reg             s_g, s_l, s_e;
    reg [8*40-1:0]  s_name;
    reg [3:0]       s_cmd;
    reg [N-1:0]     s_opa, s_opb;
    reg             s_is_mul;
    integer         s_check_cycle;

    begin
        wait(q_tail > q_head);
        s_res         = q_res        [q_head];
        s_err         = q_err        [q_head];
        s_oflow       = q_oflow      [q_head];
        s_cout        = q_cout       [q_head];
        s_g           = q_g          [q_head];
        s_l           = q_l          [q_head];
        s_e           = q_e          [q_head];
        s_name        = q_name       [q_head];
        s_cmd         = q_cmd        [q_head];
        s_opa         = q_opa        [q_head];
        s_opb         = q_opb        [q_head];
        s_is_mul      = q_is_mul     [q_head];
        s_check_cycle = q_check_cycle[q_head];
        q_head        = q_head + 1;

        wait(cycle_num >= s_check_cycle);
        #1;
        $display("OUTPUTS CHECKED @ POSEDGE time =%0t",$time);
        $display("[SCB] time=%-8t Checking: %-40s CMD=%0d OPA=%3d OPB=%3d",$time, s_name, s_cmd, s_opa, s_opb);
        $display("  REF : RES=%0d ERR=%b COUT=%b OFLOW=%b G=%b L=%b E=%b",s_res, s_err, s_cout, s_oflow, s_g, s_l, s_e);
        $display("  DUT : RES=%0d ERR=%b COUT=%b OFLOW=%b G=%b L=%b E=%b",RES, ERR, COUT, OFLOW, G, L, E);

        test_count = test_count + 1;
        if ((RES!==s_res)||(ERR!==s_err)||(COUT!==s_cout)||(OFLOW!==s_oflow) ||(G!==s_g)||(L!==s_l)||(E!==s_e) ) begin
            $display("[FAIL] %-40s....................................................................................................................................................", s_name);
            fail_count = fail_count + 1;
        end 
        else begin
            $display("[PASS] %-40s", s_name);
        end
        $display("  ******************************************************************************************************");
    end
endtask


//  DRIVER send one test at every negedge
task run_driver;
    begin
        $display("\n Arithmetic Operations (MODE=1) ");
        $display(" Direct Cases ");
        driver_send(4'd0,  8'd10,  8'd20,  0, 2'b11, 1, "ADD_no_carry");
        driver_send(4'd1,  8'd10,  8'd5,   0, 2'b11, 1, "SUB_no_oflow");
        driver_send(4'd2,  8'd10,  8'd5,   1, 2'b11, 1, "ADD_with_CIN");
        driver_send(4'd3,  8'd10,  8'd5,   1, 2'b11, 1, "SUB_with_CIN");
        driver_send(4'd4,  8'd10,  8'd0,   0, 2'b01, 1, "INC_A");
        driver_send(4'd5,  8'd10,  8'd0,   0, 2'b01, 1, "DEC_A");
        driver_send(4'd6,  8'd10,  8'd0,   0, 2'b10, 1, "INC_B");
        driver_send(4'd7,  8'd10,  8'd0,   0, 2'b10, 1, "DEC_B");
        driver_send(4'd8,  8'd10,  8'd2,   0, 2'b11, 1, "COMP_G");
        driver_send(4'd8,  8'd10,  8'd20,  0, 2'b11, 1, "COMP_L");
        driver_send(4'd8,  8'd10,  8'd10,  0, 2'b11, 1, "COMP_E");
        driver_send(4'd9,  8'd3,   8'd2,   0, 2'b11, 1, "INC_MUL_3x2");
        driver_send(4'd9,  8'd3,   8'd5,   0, 2'b11, 1, "INC_MUL_3x5");
        driver_send(4'd9,  8'd7,   8'd9,   0, 2'b11, 1, "INC_MUL_7x9");
        driver_send(4'd9,  8'd8,   8'd10,   0, 2'b11, 1, "INC_MUL_8x10");
        driver_send(4'd9,  8'd8,   8'd10,   0, 2'b11, 1, "INC_MUL_139x129");
        driver_send(4'd10, 8'd4,   8'd3,   0, 2'b11, 1, "SHL_MUL_4x3");
        driver_send(4'd10, 8'd5,   8'd4,   0, 2'b11, 1, "SHL_MUL_5x4");
        driver_send(4'd11, 8'd5,   8'd4,   0, 2'b11, 1, "SIG_ADD_NO_OV");
        driver_send(4'd11, 8'd5,  -8'd3,   0, 2'b11, 1, "SIG_ADD_DIFF_SIGN");
        driver_send(4'd11, -8'd20, -8'd30, 0, 2'b11, 1, "SIG_ADD_NEG");
        driver_send(4'd11, -8'd100,-8'd50, 0, 2'b11, 1, "SIG_ADD_NEG_OV");
        driver_send(4'd12, 8'sd10, -8'sd5, 0, 2'b11, 1, "SIG_SUB_NO_OV");
        driver_send(4'd12, -8'd128, 8'sd1, 0, 2'b11, 1, "SIG_SUB_NEG_OV");
        driver_send(4'd12, 8'd8,   8'd3,   0, 2'b11, 1, "SIG_SUB_SAMESIGN");
        
        $display(" Corner Cases  ");
        driver_send(4'd0,  8'd10,  8'd5,   1, 2'b11, 1, "ADD_ignore_CIN");
        driver_send(4'd0,  8'd255, 8'd5,   0, 2'b11, 1, "ADD_with_COUT");
        driver_send(4'd0,  8'd50,  8'd5,   0, 2'b00, 1, "ADD_both_invalid");
        driver_send(4'd0,  8'd50,  8'd5,   0, 2'b01, 1, "ADD_B_missing");
        driver_send(4'd0,  8'd50,  8'd5,   0, 2'b10, 1, "ADD_A_missing");
        driver_send(4'd1,  8'd5,   8'd10,  0, 2'b11, 1, "SUB_with_OFLOW");
        driver_send(4'd1,  8'd5,   8'd3,   0, 2'b01, 1, "SUB_B_invalid");
        driver_send(4'd2,  8'd255, 8'd1,   1, 2'b11, 1, "ADD_CIN_COUT");
        driver_send(4'd2,  8'd25,  8'd2,   0, 2'b00, 1, "ADD_CIN_both_invalid");
        driver_send(4'd3,  8'd0,   8'd0,   1, 2'b11, 1, "SUB_CIN_OFLOW");
        driver_send(4'd3,  8'd2,   8'd1,   1, 2'b00, 1, "SUB_CIN_both_invalid");
        driver_send(4'd4,  8'd255, 8'd0,   0, 2'b01, 1, "INC_A_wrap");
        driver_send(4'd4,  8'd25,  8'd0,   0, 2'b00, 1, "INC_A_invalid");
        driver_send(4'd5,  8'd0,   8'd10,  0, 2'b01, 1, "DEC_A_underflow");
        driver_send(4'd5,  8'd10,  8'd2,   0, 2'b00, 1, "DEC_A_invalid");
        driver_send(4'd6,  8'd0,   8'd255, 0, 2'b10, 1, "INC_B_wrap");
        driver_send(4'd6,  8'd25,  8'd0,   0, 2'b00, 1, "INC_B_invalid");
        driver_send(4'd7,  8'd10,  8'd0,   0, 2'b10, 1, "DEC_B_underflow");
        driver_send(4'd7,  8'd10,  8'd2,   0, 2'b00, 1, "DEC_B_invalid");
        driver_send(4'd8,  8'd1,   8'd2,   0, 2'b00, 1, "COMP_both_invalid");
        driver_send(4'd9,  8'd3,   8'd2,   0, 2'b00, 1, "MUL_both_invalid");
        driver_send(4'd9,  8'd255, 8'd255, 0, 2'b11, 1, "MUL_max_operands");
        driver_send(4'd10, 8'd4,   8'd3,   0, 2'b00, 1, "SHL_MUL_both_invalid");
        driver_send(4'd10, 8'd128, 8'd1,   0, 2'b11, 1, "SHL_MUL_MSB_set");
        driver_send(4'd11, 8'd127, 8'd1,   0, 2'b11, 1, "SIG_ADD_OFLOW_pos");
        driver_send(4'd11, 8'd127, 8'd10,  0, 2'b00, 1, "SIG_ADD_both_invalid");
        driver_send(4'd12, 8'd127, -8'd2,  0, 2'b11, 1, "SIG_SUB_OFLOW");
        driver_send(4'd12, 8'd17,  8'd1,   0, 2'b00, 1, "SIG_SUB_both_invalid");
        driver_send(4'd14, 8'd5,   8'd2,   0, 2'b00, 0, "DEFAULT_opcode");


        $display("\n Logical Operations (MODE=0) ");
        $display("  Direct Cases ");
        driver_send(4'd0,  8'd4,   8'd0,   0, 2'b11, 0, "AND");
        driver_send(4'd1,  8'd4,   8'd2,   0, 2'b11, 0, "NAND");
        driver_send(4'd2,  8'd8,   8'd4,   0, 2'b11, 0, "OR");
        driver_send(4'd3,  8'd4,   8'd2,   0, 2'b11, 0, "NOR");
        driver_send(4'd4,  8'd5,   8'd3,   0, 2'b11, 0, "XOR");
        driver_send(4'd5,  8'd5,   8'd3,   0, 2'b11, 0, "XNOR");
        driver_send(4'd6,  8'd10,  8'd0,   0, 2'b01, 0, "NOT_A");
        driver_send(4'd7,  8'd10,  8'd7,   0, 2'b10, 0, "NOT_B");
        driver_send(4'd8,  8'd4,   8'd0,   0, 2'b01, 0, "SHR1_A");
        driver_send(4'd9,  8'd4,   8'd0,   0, 2'b01, 0, "SHL1_A");
        driver_send(4'd10, 8'd0,   8'd4,   0, 2'b10, 0, "SHR1_B");
        driver_send(4'd11, 8'd0,   8'd4,   0, 2'b10, 0, "SHL1_B");
        driver_send(4'd12, 8'd7,   8'd2,   0, 2'b11, 0, "ROL_A_B_2");
        driver_send(4'd12, 8'd7,   8'd3,   0, 2'b11, 0, "ROL_A_B_3");
        driver_send(4'd12, 8'd7,   8'd4,   0, 2'b11, 0, "ROL_A_B_4");
        driver_send(4'd12, 8'd7,   8'd5,   0, 2'b11, 0, "ROL_A_B_5");
        driver_send(4'd12, 8'd7,   8'd6,   0, 2'b11, 0, "ROL_A_B_6");
        driver_send(4'd12, 8'd7,   8'd7,   0, 2'b11, 0, "ROL_A_B_7");
        driver_send(4'd13, 8'd7,   8'd2,   0, 2'b11, 0, "ROR_A_B");

        $display(" Corner Cases ");
        driver_send(4'd0,  8'd4,   8'd2,   0, 2'b00, 0, "AND_invalid");
        driver_send(4'd1,  8'd4,   8'd2,   0, 2'b00, 0, "NAND_invalid");
        driver_send(4'd2,  8'd16,  8'd15,  0, 2'b00, 0, "OR_invalid");
        driver_send(4'd3,  8'd9,   8'd6,   0, 2'b00, 0, "NOR_invalid");
        driver_send(4'd4,  8'd7,   8'd3,   0, 2'b00, 0, "XOR_invalid");
        driver_send(4'd5,  8'd4,   8'd2,   0, 2'b00, 0, "XNOR_invalid");
        driver_send(4'd6,  8'd4,   8'd3,   0, 2'b00, 0, "NOT_A_invalid");
        driver_send(4'd7,  8'd4,   8'd2,   0, 2'b00, 0, "NOT_B_invalid");
        driver_send(4'd8,  8'd1,   8'd2,   0, 2'b01, 0, "SHR1_A_LSB");
        driver_send(4'd9,  8'd128, 8'd10,  0, 2'b01, 0, "SHL1_A_MSB_lost");
        driver_send(4'd10, 8'd4,   8'd1,   0, 2'b10, 0, "SHR1_B_LSB");
        driver_send(4'd11, 8'd4,   8'd128, 0, 2'b10, 0, "SHL1_B_MSB_lost");
        driver_send(4'd8,  8'd4,   8'd2,   0, 2'b00, 0, "SHR1_A_invalid");
        driver_send(4'd9,  8'd4,   8'd2,   0, 2'b00, 0, "SHL1_A_invalid");
        driver_send(4'd10, 8'd4,   8'd2,   0, 2'b00, 0, "SHR1_B_invalid");
        driver_send(4'd11, 8'd4,   8'd2,   0, 2'b00, 0, "SHL1_B_invalid");
        driver_send(4'd12, 8'd15,  8'd0,   0, 2'b11, 0, "ROL_by_zero");
        driver_send(4'd12, 8'd23,  8'd17,  0, 2'b11, 0, "ROL_OPB_oob_17");
        driver_send(4'd12, 8'd24,  8'd34,  0, 2'b11, 0, "ROL_OPB_oob_34");
        driver_send(4'd12, 8'd25,  8'd68,  0, 2'b11, 0, "ROL_OPB_oob_68");
        driver_send(4'd12, 8'd26,  8'd132, 0, 2'b11, 0, "ROL_OPB_oob_132");
        driver_send(4'd12, 8'd15,  8'd8,   0, 2'b11, 0, "ROL_by_8_wraps");
        driver_send(4'd12, 8'd5,   8'd2,   0, 2'b00, 0, "ROL_invalid");
        driver_send(4'd13, 8'd15,  8'd0,   0, 2'b11, 0, "ROR_by_zero");
        driver_send(4'd13, 8'd23,  8'd17,  0, 2'b11, 0, "ROR_OPB_oob_17");
        driver_send(4'd13, 8'd24,  8'd34,  0, 2'b11, 0, "ROR_OPB_oob_34");
        driver_send(4'd13, 8'd25,  8'd68,  0, 2'b11, 0, "ROR_OPB_oob_68");
        driver_send(4'd13, 8'd26,  8'd132, 0, 2'b11, 0, "ROR_OPB_oob_132");
        driver_send(4'd13, 8'd15,  8'd8,   0, 2'b11, 0, "ROR_by_8_wraps");
        driver_send(4'd13, 8'd5,   8'd2,   0, 2'b00, 0, "ROR_invalid");
        driver_send(4'd14, 8'd5,   8'd2,   1, 2'b00, 0, "DEFAULT_opcode");
    end
endtask

//SCOREBOARD forked so it runs in parallel, takes values from queue
task run_scoreboard;
    // Arithmetic direct:24
    // Arithmetic corner:28
    // Logical direct:19
    // Logical corner:31
    // Total:102
    integer i;
    begin
        for (i = 0; i < 102; i = i + 1) begin
            scoreboard_check;
        end
    end
endtask

initial begin
    pass_count = 0;
    fail_count = 0;
    test_count = 0;
    q_head     = 0;
    q_tail     = 0;

    RST = 1; CE = 0; CIN = 0;
    OPA = 0; OPB = 0; MODE = 0; CMD = 0; INP_VALID = 0;

    @(posedge CLK); CE  = 1;
    @(posedge CLK); RST = 0;

    fork
        run_driver;
        run_scoreboard;
    join
    
    repeat(3) @(posedge CLK);
    $display("\n============================================================");
    $display("                    TEST SUMMARY                             ");
    $display("============================================================");
    $display("  Total tests  : %0d", test_count);
    $display("  PASS         : %0d", test_count - fail_count);
    $display("  FAIL         : %0d", fail_count);
    $display("============================================================");

    $finish;
end

endmodule