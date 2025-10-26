read_verilog AddRndKey_top.v
read_verilog AEScntx.v
read_verilog AESCore.v
read_verilog aes_sbox.v
read_verilog AES_top.v
read_verilog KeySchedule_top.v
read_verilog matrix_mult.v
read_verilog MixCol_top.v
read_verilog shiftRows_top.v
read_verilog subBytes_top.v

hierarchy -top AES_top

proc; opt
techmap; opt
fsm; opt
memory


dfflibmap -liberty sg13g2_stdcell_typ_1p50V_25C.lib
abc -liberty sg13g2_stdcell_typ_1p50V_25C.lib
clean

write_verilog AESout.v
