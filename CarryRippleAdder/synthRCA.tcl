read_verilog CarryRippleAdder.v

hierarchy -top RCA8

proc; opt; techmap; opt; 
synth -top RCA8

write_blif RCA9.blif
