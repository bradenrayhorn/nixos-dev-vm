return {
	"stevearc/conform.nvim",
	opts = {
		formatters_by_ft = {
			lua = { "stylua" },
			go = { "gofmt" },
			json = { "prettierd" },
			jsonc = { "prettierd" },
			javascript = { "prettierd" },
			typescript = { "prettierd" },
			typescriptreact = { "prettierd" },
			svelte = { "prettierd" },
			html = { "prettierd" },
			css = { "prettierd" },
			rust = { "rustfmt" },
			proto = { "buf" },
			nix = { "nixfmt" },
		},
		log_level = vim.log.levels.TRACE,
		format_on_save = {
			timeout_ms = 500,
			lsp_fallback = false,
		},
	},
}
