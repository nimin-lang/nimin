.PHONY: all build test bench docs install clean

YEAR := $(shell date +%Y)

all: build

build:
	nimble build -y --define:BuildYear=$(YEAR)

test:
	nimble test -y

bench:
	nimble bench -y

docs:
	nim doc2 --project --index:on --path:lib --outdir:docs lib/nimin/span.nim
	nim doc2 --project --index:on --path:lib --outdir:docs lib/nimin/io.nim
	nim doc2 --project --index:on --path:lib --outdir:docs lib/nimin/cli.nim
	@echo "Docs generated in docs/"

install:
	nimble install -y

clean:
	rm -rf nimcache bin/ docs/ bench/bench tests/test_config tests/test_driver_assembly tests/test_panicoverride tests/test_linter tests/test_span tests/test_io tests/test_cli
