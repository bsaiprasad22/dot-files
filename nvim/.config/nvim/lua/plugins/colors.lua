vim.api.nvim_set_hl(0, "NormalFloat", {bg = "none"})
vim.api.nvim_set_hl(0, "Normal", {bg = "none"})

return {
    -- "catppuccin/nvim", 
    'rose-pine/neovim',
    as = "rose-pine",
    -- name = "catppuccin",
    priority = 1000, 
    config = function()
        -- vim.cmd.colorscheme "catppuccin-latte"
        -- vim.cmd.colorscheme "catppuccin-mocha"
		vim.cmd('colorscheme rose-pine')
    end
}

-- return {
--   "folke/tokyonight.nvim",
--   lazy = false,
--   priority = 1000,
--   opts = {},
--   config = function()
--     vim.cmd.colorscheme "tokyonight-storm"
--   end
-- }
