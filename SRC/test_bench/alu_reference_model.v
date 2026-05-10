//==============================================
// ALU Reference Model
//==============================================

module alu_reference_model#(parameter N=8,parameter total_tests=50)(
	input [$clog2(total_tests)-1:0]id,
    input [N-1:0] OPA, OPB,
    input CIN, MODE,
	input [1:0]INP_VALID,
    input [3:0] CMD,
	output reg [$clog2(total_tests)-1:0]id_out,
    output reg [2*N-1:0] RES,
    output reg COUT, OFLOW, G, E, L, ERR
);

    //reg [N-1:0] OPA_1, OPB_1;
	integer shift_amt;
	reg signed [N:0]signed_sum;

    always @(*) begin
        // Default values
        RES = 0;
        COUT = 0;
        OFLOW = 0;
        G = 0;
        E = 0;
        L = 0;
        ERR = 0;
		id_out=id;

        if (MODE) begin  // Arithmetic Mode
            case(CMD)
                4'b0000: 	if(INP_VALID==2'b11)begin  // ADD
								RES=OPA+OPB;
								COUT=({1'b0,OPA}+{1'b0,OPB})>>N;
							end
							else ERR=1'b1;
                4'b0001: 	if(INP_VALID==2'b11)begin  // SUB
								OFLOW = (OPA < OPB);
								RES = OPA - OPB;
							end
							else ERR=1'b1;
				
                4'b0010: 	if(INP_VALID==2'b11)begin  // ADD_CIN
								RES=OPA+OPB+CIN;
								COUT=({1'b0,OPA}+{1'b0,OPB})>>N;
							end
							else ERR=1'b1;
							
                4'b0011: 	if(INP_VALID==2'b11)begin  // SUB_CIN
								OFLOW = (OPA < (OPB+CIN));
								RES = OPA - OPB - CIN;
							end
							else ERR=1'b1;
							
                4'b0100: 	if(INP_VALID[0]==1'b1)	RES = OPA + 1; 	else ERR=1'b1;  // INC_A
                4'b0101:	if(INP_VALID[0]==1'b1)	RES = OPA - 1; 	else ERR=1'b1; 	// DEC_A
                4'b0110:	if(INP_VALID[1]==1'b1)	RES = OPB + 1; 	else ERR=1'b1; 	// INC_B
                4'b0111: 	if(INP_VALID[1]==1'b1)	RES = OPB - 1; 	else ERR=1'b1; 	// DEC_B
				
                4'b1000: 	if(INP_VALID==2'b11)begin  // CMP
								RES =0;
								if (OPA == OPB)	E = 1'b1;
								else if (OPA > OPB) G = 1'b1;
								else L = 1'b1;
							end
							else ERR=1'b1;
							
				4'b1001:	if(INP_VALID==2'b11) RES=(OPA+1)*(OPB+1);
							else ERR=1'b1;
						
				4'b1010:	if(INP_VALID==2'b11)	RES=(OPA<<1)*(OPB);
							else ERR=1'b1;
						
				4'b1011:	if(INP_VALID==2'b11)begin 
								signed_sum=$signed(OPA)+$signed(OPB);
								RES=signed_sum;
								E= OPA==OPB;
								G=($signed(OPA)>$signed(OPB));
								L=($signed(OPA)<$signed(OPB));
								OFLOW=(OPA[N-1]==OPB[N-1])&&(signed_sum[N]!=signed_sum[N-1]);
							end
							else ERR=1'b1;
				4'b1100:	if(INP_VALID==2'b11)begin 
								signed_sum=$signed(OPA)-$signed(OPB);
								RES=signed_sum;
								E= OPA==OPB;
								G=($signed(OPA)>$signed(OPB));
								L=($signed(OPA)<$signed(OPB));
								OFLOW=(OPA[N-1]!=OPB[N-1])&&(signed_sum[N]!=signed_sum[N-1]);
							end
							else ERR=1'b1;
								default:begin
				                RES = 0;
                                COUT = 0;
                                OFLOW = 0;
                                G = 0;
                                E = 0;
                                L = 0;
                                ERR = 1;
				end
            endcase
        end 
        else begin  // Logical Mode
            case(CMD)
                4'b0000: if(INP_VALID==2'b11)	RES = {{N{1'b0}}, OPA & OPB};   	else ERR=1'b1;   // AND
                4'b0001: if(INP_VALID==2'b11)	RES = {{N{1'b0}},~(OPA & OPB)}; 	else ERR=1'b1;   // NAND
                4'b0010: if(INP_VALID==2'b11)	RES = {{N{1'b0}}, OPA | OPB};   	else ERR=1'b1;   // OR
                4'b0011: if(INP_VALID==2'b11)	RES = {{N{1'b0}}, ~(OPA | OPB)};	else ERR=1'b1;   // NOR
                4'b0100: if(INP_VALID==2'b11)	RES = {{N{1'b0}}, OPA ^ OPB};   	else ERR=1'b1;   // XOR
                4'b0101: if(INP_VALID==2'b11)	RES = {{N{1'b0}}, ~(OPA ^ OPB)}; 	else ERR=1'b1;   // XNOR
                4'b0110: if(INP_VALID[0]==1'b1) RES = {{N{1'b0}}, ~OPA};     		else ERR=1'b1;   // NOT_A
                4'b0111: if(INP_VALID[1]==1'b1)	RES = {{N{1'b0}}, ~OPB};       		else ERR=1'b1;   // NOT_B
                4'b1000: if(INP_VALID[0]==1'b1)	RES = {{N{1'b0}}, OPA >> 1};  		else ERR=1'b1;   // SHR1_A
                4'b1001: if(INP_VALID[0]==1'b1)	RES = {{N{1'b0}}, OPA << 1};  		else ERR=1'b1;   // SHL1_A
                4'b1010: if(INP_VALID[1]==1'b1)	RES = {{N{1'b0}}, OPB >> 1}; 		else ERR=1'b1;   // SHR1_B
                4'b1011: if(INP_VALID[1]==1'b1)	RES = {{N{1'b0}}, OPB << 1};  		else ERR=1'b1;   // SHL1_B
				
                4'b1100: if(INP_VALID==2'b11)begin  // ROL_A_B
							shift_amt=OPB[$clog2(N)-1:0];
							RES = {{N{1'b0}},(OPA<<shift_amt)|(OPA>>(N-shift_amt))};
							ERR = (|OPB[N-1:$clog2(N)+1]);
						end
						else ERR=1'b1;
                4'b1101: if(INP_VALID==2'b11)	begin  // ROR_A_B
							shift_amt=OPB[$clog2(N)-1:0];
							RES = {{N{1'b0}},(OPA>>shift_amt)|(OPA<<(N-shift_amt))};
							ERR = (|OPB[N-1:$clog2(N)+1]);
						end
						else ERR=1'b1;
				default:begin
				                RES = 0;
                                COUT = 0;
                                OFLOW = 0;
                                G = 0;
                                E = 0;
                                L = 0;
                                ERR = 1;
				end
            endcase
        end
    end

endmodule