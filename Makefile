MOJO ?= pixi run mojo
MOJO_FLAGS ?= --Werror -I .
PYTHON ?= pixi run python
CFLAGS ?= -O2 -std=c11 -D_POSIX_C_SOURCE=200809L -Wall -Wextra -Werror
NATIVE_EXT := $(if $(filter Darwin,$(shell uname -s)),dylib,so)
NATIVE_FLAGS := $(if $(filter Darwin,$(shell uname -s)),-dynamiclib,-shared)

DOCS_DIR := website

.PHONY: install native test-deps test test-package build format clean doc-install doc-start doc-build doc-serve doc-clean

install:
	pixi install
	$(MOJO) --version

native: build/libreq_curl.$(NATIVE_EXT)

build/libreq_curl.$(NATIVE_EXT): req/_transports/_curl.c
	mkdir -p build
	$(CC) $(CFLAGS) -fPIC $(NATIVE_FLAGS) $< -lcurl -lz -o $@

test-deps:
	$(PYTHON) -m ensurepip
	$(PYTHON) -m pip install -r tests/requirements.txt

test: native
	REQ_MOJO="$(MOJO)" REQ_MOJO_FLAGS="$(MOJO_FLAGS)" $(PYTHON) tests/run_tests.py $(TEST_ARGS)

build: native
	mkdir -p build
	$(MOJO) precompile $(MOJO_FLAGS) req -o build/req.mojoc

test-package: build
	$(PYTHON) tests/test_package.py

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
