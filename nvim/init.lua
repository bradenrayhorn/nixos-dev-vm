require("remap")
require("set")

require("config.lazy")

-- setup lsp after plugins are loaded
require("config.lsp")

-- setup treesitter
require("config.treesitter")

-- set color scheme
vim.cmd.colorscheme("gruvbox")
