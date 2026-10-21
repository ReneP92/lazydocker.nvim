NVIM ?= nvim
STYLUA ?= stylua

.PHONY: test format format-check check

test:
	$(NVIM) --headless -u NONE -i NONE -n -l tests/run.lua

format:
	$(STYLUA) lua plugin tests

format-check:
	$(STYLUA) --check lua plugin tests

check: format-check test
