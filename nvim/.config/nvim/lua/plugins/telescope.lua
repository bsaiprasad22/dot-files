local builtin = require('telescope.builtin')

vim.keymap.set('n', '<leader>ff', function()
builtin.find_files({ hidden = true })
end, { desc = 'Telescope find files'})

vim.keymap.set('n', '<C-p>', function()
builtin.git_files({ hidden = true })
end,{ desc = 'Telescope find git files'})

vim.keymap.set('n', '<leader>fg', function()
builtin.live_grep({ hidden = true })
end, { desc = 'Telescope live grep'})
-- vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })

return {
	'nvim-telescope/telescope.nvim', tag = '0.1.8',
	-- or                              , branch = '0.1.x',
	dependencies = { 'nvim-lua/plenary.nvim' },
--	defaults = {
--		vimgrep_arguments = {
--			"rg",
--			"--color=never",
--			"--no-heading",
--			"--with-filename",
--			"--line-number",
--			"--column",
--			"--smart-case",
--			"--hidden", -- Add this to include hidden files
--		},
--	},
}
