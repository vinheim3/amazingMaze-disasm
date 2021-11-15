OBJS = $(shell find code/ -name '*.s' | sed "s/code/build/" | sed "s/\.s/.o/")
RAM_OBJS = build/wram.o

all: maze.bin

build/wram.o: include/wram.s
	wla-8080 -o $@ $<

build/%.o: code/%.s
	wla-8080 -o $@ $<

maze.bin: $(OBJS) $(RAM_OBJS)
	wlalink -S linkfile $@
