default: build

build:
	zig build-exe main.zig -O ReleaseFast --name pizzakv

install: build
	mv pizzakv /usr/local/bin/pizzakv

clean:
	rm -f pizzakv

test:
	node tools/test_nov.js