# Convert from ca64 disassembly to merlin32 source

# Remove the front if any line with disassembly information and leave just the opcodes
cat _rom.s | sed -r 's/^. . . . . . .{26}(.*)/\1/' > _rom0.s

# Convert .byte to db and .word to dw
cat _rom0.s | sed 's/\.byte/db/g' > _rom1.s
cat _rom1.s | sed 's/\.word/dw/g' > _rom2.s
cat _rom2.s | sed 's/\.dbyt/ddb/g' > _rom3.s

# Any ca65 directive or blank line, add a comment
cat _rom3.s | sed -r 's/^\.(.*)/;.\1/g' > _rom4.s
cat _rom4.s | sed -r 's/^   (.*)/;   \1/g' > _rom5.s

# Remove trailing ':' from labels
cat _rom5.s | sed -r 's/^(.+)[:]/\1/g' > _rom6.s

# Replace loads and stores with calls to the runtime
cat _rom6.s | sed -r 's/  (...) \$(200.)/  JSR \1_\2/g' | sed -r 's/  (...) \$(40[01].)/  JSR \1_\2/g' > rom.s

# Put this at the top of the rom

#        use  bank_ram.inc
#        use  bank_val.inc
#ROMBase ENT
#        ds   $C000-$380
#        put  ../../rom/rom_inject.s