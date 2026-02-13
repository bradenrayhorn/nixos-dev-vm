return {
	{
		"lewis6991/gitsigns.nvim",
		opts = {},
	},

	{
		"tpope/vim-fugitive",
		config = function() end,
	},

	{
		"georgeguimaraes/review.nvim",
		dependencies = {
			"esmuellert/codediff.nvim",
			"MunifTanjim/nui.nvim",
		},
		cmd = { "Review" },
		keys = {
			{ "<leader>r", "<cmd>Review<cr>", desc = "Review" },
			{ "<leader>R", "<cmd>Review commits<cr>", desc = "Review commits" },
		},
		opts = {},
	},
}
