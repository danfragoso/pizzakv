default: build

run:
	zig run main.zig 

build:
	zig build-exe main.zig -O ReleaseFast --name pizzakv

build-amd64:
	zig build-exe main.zig -O ReleaseFast --name pizzakv_amd64 -lc -target x86_64-linux

install: build
	mv pizzakv /usr/local/bin/pizzakv

clean:
	rm -f pizzakv

test:
	node tools/test_nov.js