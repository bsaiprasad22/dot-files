return {
    "stevearc/conform.nvim",
    opts = {
        formatters_by_ft = {
            lua = { "stylua" },
            javascript = { "prettierd", "prettier", stop_after_first = true },
            javascriptreact = { "prettier" },
            python = { "isort", "black" },
            -- Add more file types and formatters as needed
        },
        format_on_save = {
            lsp_format = "fallback", -- Use LSP formatters as a fallback
            timeout_ms = 500,
        },
vim.api.nvim_create_autocmd("BufWritePre", {
            pattern = "*", -- Matches all filetypes
            callback = function(args)
                require("conform").format({ bufnr = args.buf })
            end,
            group = vim.api.nvim_create_augroup("AutoFormat", { clear = true }),
        })
    }, -- Your configuration goes here
}

