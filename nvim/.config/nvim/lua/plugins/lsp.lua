local root_files = {
    '.luarc.json',
    '.luarc.jsonc',
    '.luacheckrc',
    '.stylua.toml',
    'stylua.toml',
    'selene.toml',
    'selene.yml',
    '.git',
}

return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "stevearc/conform.nvim",
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-cmdline",
        "hrsh7th/nvim-cmp",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
        "j-hui/fidget.nvim",
    },

    config = function()
        -- Conform setup for formatting
        require("conform").setup({
            formatters_by_ft = {
                javascript = { "eslint_d", "prettier" },
                javascriptreact = { "eslint_d", "prettier" },
                typescript = { "eslint_d", "prettier" },
                typescriptreact = { "eslint_d", "prettier" },
                json = { "prettier" },
                html = { "prettier" },
                css = { "prettier" },
                lua = { "stylua" },
            },
            format_on_save = {
                timeout_ms = 500,
                lsp_fallback = true,
            },
        })

        local cmp = require('cmp')
        local cmp_lsp = require("cmp_nvim_lsp")
        local capabilities = vim.tbl_deep_extend(
            "force",
            {},
            vim.lsp.protocol.make_client_capabilities(),
            cmp_lsp.default_capabilities())

        require("fidget").setup({})
        require("mason").setup()
        require("mason-lspconfig").setup({
            ensure_installed = {
                "lua_ls",
                "rust_analyzer",
                "ts_ls",  -- TypeScript/JavaScript LSP
                "eslint", -- ESLint for linting
                "pyright",
                "pylsp",
                "bashls",
                "cssls",
                "tailwindcss",
            },
            handlers = {
                function(server_name) -- default handler
                    require("lspconfig")[server_name].setup {
                        capabilities = capabilities
                    }
                end,

                ["lua_ls"] = function()
                    local lspconfig = require("lspconfig")
                    lspconfig.lua_ls.setup {
                        capabilities = capabilities,
                        settings = {
                            Lua = {
                                runtime = { version = "LuaJIT" },
                                diagnostics = { globals = { "vim" } },
                                workspace = {
                                    library = vim.api.nvim_get_runtime_file("", true),
                                    checkThirdParty = false,
                                },
                                format = {
                                    enable = true,
                                    defaultConfig = {
                                        indent_style = "space",
                                        indent_size = "2",
                                    }
                                },
                            }
                        }
                    }
                end,

                ["ts_ls"] = function()
                    local lspconfig = require("lspconfig")
                    lspconfig.ts_ls.setup {
                        capabilities = capabilities,
                        filetypes = {
                            "javascript",
                            "javascriptreact",
                            "typescript",
                            "typescriptreact"
                        },
                        root_dir = lspconfig.util.root_pattern(
                            "package.json",
                            "tsconfig.json",
                            "jsconfig.json",
                            ".git"
                        ),
                        settings = {
                            typescript = {
                                inlayHints = {
                                    includeInlayParameterNameHints = "all",
                                    includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                                    includeInlayFunctionParameterTypeHints = true,
                                    includeInlayVariableTypeHints = true,
                                    includeInlayPropertyDeclarationTypeHints = true,
                                    includeInlayFunctionLikeReturnTypeHints = true,
                                    includeInlayEnumMemberValueHints = true,
                                }
                            },
                            javascript = {
                                inlayHints = {
                                    includeInlayParameterNameHints = "all",
                                    includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                                    includeInlayFunctionParameterTypeHints = true,
                                    includeInlayVariableTypeHints = true,
                                    includeInlayPropertyDeclarationTypeHints = true,
                                    includeInlayFunctionLikeReturnTypeHints = true,
                                    includeInlayEnumMemberValueHints = true,
                                }
                            }
                        },
                        on_attach = function(client, bufnr)
                            -- Disable ts_ls formatting (let eslint/prettier handle it)
                            client.server_capabilities.documentFormattingProvider = false
                            client.server_capabilities.documentRangeFormattingProvider = false
                        end,
                    }
                end,

                ["eslint"] = function()
                    local lspconfig = require("lspconfig")
                    lspconfig.eslint.setup {
                        capabilities = capabilities,
                        filetypes = {
                            "javascript",
                            "javascriptreact",
                            "typescript",
                            "typescriptreact"
                        },
                        root_dir = lspconfig.util.root_pattern(
                            ".eslintrc",
                            ".eslintrc.js",
                            ".eslintrc.json",
                            ".eslintrc.yml",
                            ".eslintrc.yaml",
                            "eslint.config.js",
                            "package.json",
                            ".git"
                        ),
                        settings = {
                            codeAction = {
                                disableRuleComment = {
                                    enable = true,
                                    location = "separateLine"
                                },
                                showDocumentation = {
                                    enable = true
                                }
                            },
                            codeActionOnSave = {
                                enable = false,
                                mode = "all"
                            },
                            format = true,
                            nodePath = "",
                            onIgnoredFiles = "off",
                            packageManager = "npm",
                            quiet = false,
                            rulesCustomizations = {},
                            run = "onType",
                            useESLintClass = false,
                            validate = "on",
                            workingDirectory = {
                                mode = "location"
                            }
                        },
                        on_attach = function(client, bufnr)
                            -- Enable ESLint code actions and formatting
                            vim.api.nvim_create_autocmd("BufWritePre", {
                                buffer = bufnr,
                                command = "EslintFixAll",
                            })
                        end,
                    }
                end,

                ["zls"] = function()
                    local lspconfig = require("lspconfig")
                    lspconfig.zls.setup({
                        capabilities = capabilities,
                        root_dir = lspconfig.util.root_pattern(".git", "build.zig", "zls.json"),
                        settings = {
                            zls = {
                                enable_inlay_hints = true,
                                enable_snippets = true,
                                warn_style = true,
                            },
                        },
                    })
                    vim.g.zig_fmt_parse_errors = 0
                    vim.g.zig_fmt_autosave = 0
                end,
            }
        })

        local cmp_select = { behavior = cmp.SelectBehavior.Select }

        cmp.setup({
            snippet = {
                expand = function(args)
                    require('luasnip').lsp_expand(args.body)
                end,
            },
            mapping = cmp.mapping.preset.insert({
                ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
                ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
                ['<C-y>'] = cmp.mapping.confirm({ select = true }),
                ["<C-Space>"] = cmp.mapping.complete(),
            }),
            sources = cmp.config.sources({
                { name = "copilot", group_index = 2 },
                { name = 'nvim_lsp' },
                { name = 'luasnip' },
            }, {
                { name = 'buffer' },
            })
        })

        -- Diagnostic configuration
        vim.diagnostic.config({
            virtual_text = false,
            signs = true,
            underline = true,
            update_in_insert = false,
            severity_sort = true,
            float = {
                focusable = false,
                style = "minimal",
                border = "rounded",
                source = "always",
                header = "",
                prefix = "",
            },
        })

        -- LSP Keymaps
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = 'Go to definition' })
        vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, { desc = 'Go to declaration' })
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, { desc = 'Go to implementation' })
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, { desc = 'Show references' })
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, { desc = 'Show hover' })
        vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, { desc = 'Show signature help' })
        vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { desc = 'Rename' })
        vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { desc = 'Code action' })
        vim.keymap.set('v', '<leader>ca', vim.lsp.buf.code_action, { desc = 'Code action' })
        vim.keymap.set('n', '<leader>f', function()
            require("conform").format({ lsp_fallback = true })
        end, { desc = 'Format file' })

        -- Diagnostic keymaps
        vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Previous diagnostic' })
        vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Next diagnostic' })
        vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic' })
        vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Diagnostic quickfix' })

        -- Toggle diagnostic virtual_lines
        vim.keymap.set('n', 'gK', function()
            local new_config = not vim.diagnostic.config().virtual_lines
            vim.diagnostic.config({ virtual_lines = new_config })
        end, { desc = 'Toggle diagnostic virtual_lines' })
    end
}
