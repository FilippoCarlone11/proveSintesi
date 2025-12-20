read_verilog CarryLookaheadAdder.v
hierarchy -top CLA8

techmap; opt; abc; opt
clean

write_blif CLA9.blif
