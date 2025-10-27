COLORS_DIR := colors
MINI_DIR := .deps/mini.nvim
MINI_GIT_DIR := $(MINI_DIR)/.git
MINIHUIT_COLORSCHEMES := $(COLORS_DIR)/minihuit-180.lua

.PHONY: clean

default: $(MINIHUIT_COLORSCHEMES)

$(MINI_GIT_DIR):
	@git submodule update --init --checkout --force -- $(MINI_DIR)

$(COLORS_DIR):
	@mkdir -p $(COLORS_DIR)

$(MINIHUIT_COLORSCHEMES): $(COLORS_DIR) $(MINI_GIT_DIR) generate.lua
	@nvim --headless --clean -l generate.lua

clean:
	@rm -rf $(COLORS_DIR)
