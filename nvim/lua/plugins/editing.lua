return {
	-- Self explanatory, automatically creates other end of paired characters
	{ "windwp/nvim-autopairs", opts = {} },

	{ "tpope/vim-commentary" },
	{ "tpope/vim-surround" },

	{
		"otavioschwanck/arrow.nvim",
		opts = {
			show_icons = false,
			leader_key = "\\", -- Recommended to be a single key
			buffer_leader_key = "m", -- Per Buffer Mappings
		},
	},

	--{ "Wansmer/treesj", opts = { use_default_keymap = true } },
	-- flash.nvim
}
