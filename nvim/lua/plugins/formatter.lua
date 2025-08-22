return {
    "stevearc/conform.nvim",
    opts = {
        formatters_by_ft = {
            lua = { "stylua" },
            javascript = { "prettierd", "prettier", stop_after_first = true },
            javascriptreact = { "prettier" },
            python = { "black" },
            -- Add more file types and formatters as needed
        },
        formatters = {
            black = {
                prepend_args = {"--quiet", "--line-length", "80"}
            }
        },
        format_on_save = {
            lsp_format = "fallback", -- Use LSP formatters as a fallback
            timeout_ms = 20000,
        },
vim.api.nvim_create_autocmd("BufWritePre", {
            pattern = {"*.py", "*.js", "*.jsx"}, -- Matches all filetypes
            callback = function(args)
                require("conform").format({
                    bufnr = args.buf,
                    timeout_ms = 20000,   -- 20 seconds, no more "timeout"
                    lsp_fallback = true,  -- use LSP if formatter not found
                })
            end,
            group = vim.api.nvim_create_augroup("AutoFormat", { clear = true }),
        })
    }, -- Your configuration goes here
}

