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
abc; opt
clean

write_blif AES.blif
