.PHONY: test format format-check check preview clean

NVIM ?= nvim
STYLUA ?= stylua

TESTS := $(filter-out tests/helper.lua,$(wildcard tests/*.lua))

# Run every test file headlessly. Each file is self contained and exits non zero
# on failure, so a single failing suite fails the whole target.
test:
	@for file in $(TESTS); do \
		echo "==> $$file"; \
		$(NVIM) --clean --headless -l $$file || exit 1; \
	done

# Print the layout as plain text.
preview:
	$(NVIM) --clean --headless -l scripts/preview.lua

# Format the Lua sources in place.
format:
	$(STYLUA) lua plugin tests scripts

# Fail when the sources are not formatted.
format-check:
	$(STYLUA) --check lua plugin tests scripts

check: test format-check

clean:
	rm -f doc/tags
