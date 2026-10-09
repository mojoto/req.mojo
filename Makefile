MOJO ?= pixi run mojo
MOJO_FLAGS ?= --Werror -I .
TEST_FILES := $(sort $(wildcard tests/test_*.mojo tests/models/test_*.mojo tests/client/test_*.mojo))

.PHONY: install test build format

install:
	pixi install
	$(MOJO) --version

test:
	@set -e; for file in $(TEST_FILES); do $(MOJO) run $(MOJO_FLAGS) "$$file"; done

build:
	mkdir -p build
	$(MOJO) precompile $(MOJO_FLAGS) req -o build/req.mojoc

format:
	$(MOJO) format req tests examples
