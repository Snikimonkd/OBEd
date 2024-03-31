build:
	zig build

run:build
	./zig-out/bin/obed

t:
	zig build test
