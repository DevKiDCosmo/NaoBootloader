rm -rf dump

mkdir -p dump
cd dump

objdump -f ../osshell.bin
objdump -d ../osshell.bin > disassembly.DAT
objdump -s ../osshell.bin > hex.DAT
objdump -h ../osshell.bin > sections.DAT
objdump -t ../osshell.bin > symbols.DAT
objdump -S ../osshell.bin > interleaved.DAT
objdump -x ../osshell.bin > all.DAT
objdump -p ../osshell.bin > program.DAT