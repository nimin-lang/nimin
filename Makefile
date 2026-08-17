.PHONY: all build test bench install clean

all: build

build:
	nimble build -y

test:
	nimble test -y

bench:
	nimble bench -y

install:
	nimble install -y

clean:
	rm -rf nimcache bin/ bench/bench tests/test_config tests/test_driver_assembly tests/test_panicoverride tests/test_linter tests/test_span tests/test_io tests/test_cli
