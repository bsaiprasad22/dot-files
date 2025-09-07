return {
    "nvim-treesitter/nvim-treesitter", 
    branch = 'master', 
    build = ":TSUpdate",
    config = function()
        require("nvim-treesitter.configs").setup({
            ensure_installed = {"javascript", "python", "lua", "typescript", "tsx", "html", "css", "json"},
            sync_install = false,
            auto_install = true,
            highlight = {
                enable = true,
                additional_vim_regex_highlighting = false,
            },
        })
        
        -- Just the filetype detection
        vim.cmd([[
            augroup TreesitterFiletype
                autocmd!
                autocmd BufNewFile,BufRead *.js set filetype=javascriptreact
                autocmd BufNewFile,BufRead *.jsx set filetype=javascriptreact
                autocmd BufNewFile,BufRead *.tsx set filetype=typescriptreact
            augroup END
        ]])
    end,
}
