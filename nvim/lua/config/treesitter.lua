local ensureInstalled = {
	-- vim
	"lua",
	"vim",
	-- rust
	"rust",
	-- go
	"go",
	"gomod",
	-- web
	"typescript",
	"svelte",
	"javascript",
	"css",
	"html",
	"tsx",
	-- c
	"c",
	"cpp",
	-- general
	"json",
	"yaml",
	"toml",
	"csv",
	"dockerfile",
	"proto",
	"regex",
	-- iac
	"helm",
	"terraform",
	-- kotlin/jvm
	"kotlin",
}

-- Install all required parsers
local alreadyInstalled = require("nvim-treesitter.config").get_installed()
local parsersToInstall = vim.iter(ensureInstalled)
	:filter(function(parser)
		return not vim.tbl_contains(alreadyInstalled, parser)
	end)
	:totable()
require("nvim-treesitter").install(parsersToInstall)

-- Enable highlights
vim.api.nvim_create_autocmd("FileType", {
	pattern = ensureInstalled,
	callback = function()
		vim.treesitter.start()
	end,
})
