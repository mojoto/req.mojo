MOJO ?= pixi run mojo
MOJO_FLAGS ?= --Werror -I .
PYTHON ?= pixi run python
CFLAGS ?= -O2 -std=c11 -D_POSIX_C_SOURCE=200809L -Wall -Wextra -Werror
LINK_FLAGS := -Xlinker build/libreq_curl.a -Xlinker -lcurl

DOCS_DIR := website

.PHONY: install native test build format clean doc-install doc-start doc-build doc-serve doc-clean

install:
	pixi install
	$(MOJO) --version

native: build/libreq_curl.a

build/libreq_curl.a: req/_transports/_curl.c
	mkdir -p build
	$(CC) $(CFLAGS) -c $< -o build/req_curl.o
	$(AR) rcs $@ build/req_curl.o

test: native
	REQ_MOJO="$(MOJO)" REQ_MOJO_FLAGS="$(MOJO_FLAGS)" $(PYTHON) tests/run_tests.py $(TEST_ARGS)

build: native
	mkdir -p build
	$(MOJO) precompile $(MOJO_FLAGS) req -o build/req.mojoc

format:
	$(MOJO) format req tests

clean:
	rm -rf build .req-test-* __pycache__
	find req tests -type d -name __pycache__ -prune -exec rm -rf {} +
	find req tests -type f \( -name '*.pyc' -o -name '*.pyo' \) -exec rm -f {} +

doc-install:
	npm --prefix $(DOCS_DIR) ci

doc-start:
	npm --prefix $(DOCS_DIR) start

doc-build:
	npm --prefix $(DOCS_DIR) run build

doc-serve:
	npm --prefix $(DOCS_DIR) run serve

doc-clean:
	npm --prefix $(DOCS_DIR) run clear
	rm -rf $(DOCS_DIR)/build
