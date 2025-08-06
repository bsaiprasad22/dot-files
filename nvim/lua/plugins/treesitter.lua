return {
	"nvim-treesitter/nvim-treesitter", 
	branch = 'master', 
	lazy = false, 
	build = ":TSUpdate",
	configs = {
		ensure_installed = {"help", "javascript", "python", "lua", "typescript", "jsx", "tsx", "html", "css", "json"},
		sync_install = false,
		auto_install = true,
		highlight = {
			enable = true,
			additional_vim_regex_highlighting = false,
		}
	}
}
