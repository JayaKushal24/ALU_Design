`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.05.2026 11:50:38
// Design Name: 
// Module Name: N_bit_ALU_rtl_design
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module N_bit_ALU_rtl_design #(parameter N=4)(
    input  [N-1:0] OPA, OPB,
    input  CLK,RST,CE,MODE,CIN,
    input  [1:0] INP_VALID,
    input  [3:0] CMD,
    output reg [2*N-1:0] RES,
    output reg COUT,OFLOW,G,E,L,ERR
);
    reg [N-1:0]opa_r,opb_r,opa_r2,opb_r2;
    reg [3:0]cmd_r;
    reg  mode_r,cin_r;
    reg [1:0]inp_valid_r;
    reg [N-1:0]OPA_1,OPB_1;
    reg signed [2*N-1:0] sum_ext;//1 extra bit
    integer shift_amt;
    reg flag;

    always @(posedge CLK) begin
        if (RST) begin
            opa_r<=0;
            opb_r<=0;
            cmd_r<=0;
            mode_r<=0;
            cin_r<=0;
            inp_valid_r<=0;
        end 
        else if (CE) begin
            opa_r<=OPA;
            opb_r<=OPB;
            cmd_r<=CMD;
            mode_r<=MODE;
            cin_r<=CIN;
            inp_valid_r<=INP_VALID;
        end
    end

    always @(posedge CLK) begin
        if (RST) begin
            RES<=0;
            COUT<=0;
            OFLOW<=0;
            G<=0;
            E<=0;
            L<=0;
            ERR<=0;
            flag<=1'b0;
        end 
        else if (CE) begin
            RES<=0;
            COUT<=0;
            OFLOW<=0;
            G<=0;
            E<=0;
            L<=0;
            ERR<=0;
            opa_r2<={N{1'bx}};
            opb_r2<={N{1'bx}};
            flag<=1'b0;

            if (mode_r) begin
                case (cmd_r)
                    4'b0000: begin  //ADD
                        if (inp_valid_r==2'b11) begin
                            RES <=opa_r+opb_r;
                            COUT<=({1'b0,opa_r}+{1'b0,opb_r})>>N;//one bit is added to catch overflow for corner case
                        end else ERR<=1;
                    end
                    
                    4'b0001: begin //SUB
                        if (inp_valid_r==2'b11) begin
                            RES<=opa_r-opb_r;
                            OFLOW<=(opa_r<opb_r);
                        end else ERR<=1;
                    end

                    4'b0010: begin//ADD_CIN
                        if (inp_valid_r==2'b11) begin
                            RES <=opa_r+opb_r+cin_r;
                            COUT<=({1'b0,opa_r}+{1'b0,opb_r}+cin_r)>>N;
                        end else ERR<=1;
                    end

                    4'b0011: begin//SUB_CIN
                        if (inp_valid_r==2'b11) begin
                            RES<=opa_r-opb_r-cin_r;
                            OFLOW<=(opa_r<opb_r);
                        end else ERR<=1;
                    end

                    4'b0100: begin//increment A
                        if (inp_valid_r[0]) RES<=opa_r+1;
                        else ERR<=1;
                    end

                    4'b0101: begin//decrement A
                        if (inp_valid_r[0]) RES<=opa_r-1;
                        else ERR<=1;
                    end

                    4'b0110: begin//increment B
                        if (inp_valid_r[1]) RES<=opb_r+1;
                        else ERR<=1;
                    end

                    4'b0111: begin//decrement B
                        if (inp_valid_r[1]) RES<=opb_r-1;
                        else ERR<=1;
                    end

                    4'b1000: begin//compare
                        if (inp_valid_r==2'b11) begin
                            if (opa_r==opb_r) E<=1;
                            else if (opa_r > opb_r) G<=1;
                            else L<=1;
                        end 
                        else ERR<=1;
                    end
                    4'b1001:begin//increment and multiplication
                        if(inp_valid_r==2'b11)begin
                                opa_r2<=opa_r;
                                opb_r2<=opb_r;
                                RES<={2*N{1'bx}};
                                if(flag)begin
                                    RES<=(opa_r2+1)*(opb_r2+1);
                                    flag<=1'b0;
                                end
                                else flag<=1'b1;
                        end
                        else ERR<=1;
                    end
                    4'b1010:begin//left shift and multiplication
                        if(inp_valid_r==2'b11)begin
                                opa_r2<=opa_r;
                                opb_r2<=opb_r;
                                RES<={2*N{1'bx}};
                                if(flag)begin
                                    RES<=(opa_r2<<1)*(opb_r2);
                                    flag<=1'b0;
                                end
                                else flag<=1'b1;
                        end
                        else ERR<=1;
                    end

                    4'b1011:begin//signed addition
                        if (inp_valid_r==2'b11) begin
                            sum_ext = $signed({opa_r[N-1],opa_r})+$signed({opb_r[N-1],opb_r});
                            RES<=sum_ext;
//                            COUT <= sum_ext[N];
                            OFLOW<=(opa_r[N-1]==opb_r[N-1]) && (sum_ext[N-1]!=opa_r[N-1]);
                            E <= (sum_ext[2*N-1:0] == 0);
                            L <= sum_ext[2*N-1];//msb is 1..-ve num
                            G <= (~sum_ext[2*N-1]) && (sum_ext[2*N-2:0] != 0);//a+b is +ve
                        end
                        else 
                            ERR<=1;
                    end

                    4'b1100:begin//signed subtraction
                        if (inp_valid_r==2'b11) begin
                            sum_ext = $signed({opa_r[N-1],opa_r})-$signed({opb_r[N-1],opb_r});
                            RES<=sum_ext;
//                            COUT <= sum_ext[N];//this is borrow
                            OFLOW<=(opa_r[N-1]!=opb_r[N-1]) && (sum_ext[N-1]!=opa_r[N-1]);
                            E <= (sum_ext[2*N-1:0] == 0);
                            L <= sum_ext[2*N-1];//msb is 1..-ve num
                            G <= (~sum_ext[2*N-1]) && (sum_ext[2*N-2:0] != 0);//a+b is +ve
                        end
                        else 
                            ERR<=1;

                    end

                    default: ERR<=1;
                endcase
            end

            else begin//logical
                case (cmd_r)
                    //BOTH
                    4'b0000:    if (inp_valid_r==2'b11) 
                                    RES<={{N{1'b0}}, opa_r & opb_r}; 
                                else ERR<=1;
                    4'b0001:    if (inp_valid_r==2'b11) 
                                    RES<={{N{1'b0}}, ~(opa_r & opb_r)}; 
                                else ERR<=1;
                    4'b0010:    if (inp_valid_r==2'b11) 
                                    RES<={{N{1'b0}}, opa_r | opb_r}; 
                                else ERR<=1;
                    4'b0011:    if (inp_valid_r==2'b11) 
                                    RES<={{N{1'b0}}, ~(opa_r | opb_r)}; 
                                else ERR<=1;
                    4'b0100:    if (inp_valid_r==2'b11) 
                                    RES<={{N{1'b0}}, opa_r ^ opb_r}; 
                                else ERR<=1;
                    4'b0101:    if (inp_valid_r==2'b11) 
                                    RES<={{N{1'b0}}, ~(opa_r ^ opb_r)}; 
                                else ERR<=1;
                    //OPA
                    4'b0110:    if (inp_valid_r[0]) 
                                    RES<={{N{1'b0}}, ~opa_r}; 
                                else ERR<=1;
                    4'b1000:    if (inp_valid_r[0]) 
                                    RES<={{N{1'b0}}, opa_r>>1}; 
                                else ERR<=1;
                    4'b1001:    if (inp_valid_r[0]) 
                                    RES<={{N{1'b0}}, opa_r << 1}; 
                                else ERR<=1;
                    //OPB
                    4'b0111:    if (inp_valid_r[1]) 
                                    RES<={{N{1'b0}}, ~opb_r}; 
                                else ERR<=1;
                    4'b1010:    if (inp_valid_r[1]) 
                                    RES<={{N{1'b0}}, opb_r>>1}; 
                                else ERR<=1;
                    4'b1011:    if (inp_valid_r[1]) 
                                    RES<={{N{1'b0}}, opb_r<<1}; 
                                else ERR<=1;

                    4'b1100: begin //ROL
                        if (inp_valid_r==2'b11) begin
//                            shift_amt=opb_r[$clog2(N)-1:0];
                            if (shift_amt==0)     RES <= {{N{1'b0}},opa_r};
                            else                  RES <= {{N{1'b0}},(opa_r<<opb_r[$clog2(N)-1:0])|(opa_r>>(N-opb_r[$clog2(N)-1:0]))};
                            // RES <= {{N{1'b0}},OPB_1};
                            if (|opb_r[N-1:$clog2(N)+1]) ERR <= 1;
                        end 
                        else ERR <= 1;
                    end

                    4'b1101: begin //ROR
                        if (inp_valid_r==2'b11) begin
//                            shift_amt=opb_r[$clog2(N)-1:0];
                            if (shift_amt==0)     RES <= {{N{1'b0}},opa_r};
                            else                  RES <= {{N{1'b0}},(opa_r>>opb_r[$clog2(N)-1:0])|(opa_r<<(N-opb_r[$clog2(N)-1:0]))};
                            // RES <= {{N{1'b0}},OPB_1};
                            if (|opb_r[N-1:$clog2(N)+1]) ERR <= 1;

                        end else ERR <= 1;
                    end

                    default: ERR<=1;
                endcase
            end
        end
    end

endmodule