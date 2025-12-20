read_verilog SIMDadd.v
read_verilog SIMDmultiply.v
read_verilog SIMDshifter.v
read_verilog CPUtop.v

hierarchy -top CPUtop

# per i blocchi always
proc; opt
#la fsm
fsm; opt

techmap; opt; abc; opt;
clean
memory
write_blif SIMD.blif
write_verilog SIMD.v
