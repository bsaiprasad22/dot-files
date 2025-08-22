return {
	"nvim-treesitter/nvim-treesitter", 
	branch = 'master', 
	-- lazy = false, 
	build = ":TSUpdate",
	opts = {
		ensure_installed = {"javascript", "python", "lua", "typescript", "tsx", "html", "css", "json"},
		sync_install = false,
		auto_install = true,
		highlight = {
			enable = true,
			additional_vim_regex_highlighting = false,
		},
        vim.cmd [[
        au BufNewFile,BufRead *.js set filetype=javascriptreact
        au BufNewFile,BufRead *.jsx set filetype=javascriptreact
        au BufNewFile,BufRead *.tsx set filetype=typescriptreact
        ]],
        vim.api.nvim_create_autocmd("BufEnter", {
            callback = function()
                pcall(vim.cmd, "TSBufEnable highlight")
            end,
        })
	},
    --[[ config = function(_, opts)
        require("nvim-treesitter.configs").setup(opts)
    end, ]]
    {
        "nvim-treesitter/playground",
    },
}

