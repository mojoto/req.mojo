MOJO ?= uv run mojo
MOJO_VERSION ?= 1.1.0
MOJO_FLAGS ?= --Werror -I . -I .deps/json
JSON_REV := 0bae1f3815d249efa6cb0a3483eb6658700635e5
TEST_FILES := $(sort $(wildcard tests/test_*.mojo tests/models/test_*.mojo tests/client/test_*.mojo))

.PHONY: install deps test build format

install:
	uv venv --python 3.14 --allow-existing
	uv pip install "mojo==$(MOJO_VERSION)"
	$(MAKE) deps
	$(MOJO) --version

deps:
	sh tools/install_json.sh $(JSON_REV)

test:
	@set -e; for file in $(TEST_FILES); do $(MOJO) run $(MOJO_FLAGS) "$$file"; done

build:
	mkdir -p build
	$(MOJO) precompile $(MOJO_FLAGS) req -o build/req.mojoc

format:
	$(MOJO) format req tests examples
