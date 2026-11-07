SOURCES := $(wildcard *.s)

snake: $(SOURCES)
	gcc -no-pie -o snake main.s