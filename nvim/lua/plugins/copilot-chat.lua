-- ~/.config/nvim/lua/plugins/copilot-chat.lua
-- Comprehensive Copilot Chat configuration for seamless code generation and refactoring

return {
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        event = "InsertEnter",
        config = function()
            require("copilot").setup({
                panel = {
                    enabled = true,
                    auto_refresh = false,
                    keymap = {
                        jump_prev = "[[",
                        jump_next = "]]",
                        accept = "<CR>",
                        refresh = "gr",
                        open = "<M-CR>"
                    },
                    layout = {
                        position = "bottom", -- | top | left | right
                        ratio = 0.4
                    },
                },
                suggestion = {
                    enabled = true,
                    auto_trigger = true,
                    hide_during_completion = true,
                    debounce = 75,
                    keymap = {
                        accept = "<M-l>",
                        accept_word = false,
                        accept_line = false,
                        next = "<M-]>",
                        prev = "<M-[>",
                        dismiss = "<C-]>",
                    },
                },
                filetypes = {
                    yaml = false,
                    markdown = false,
                    help = false,
                    gitcommit = false,
                    gitrebase = false,
                    hgcommit = false,
                    svn = false,
                    cvs = false,
                    ["."] = false,
                },
                copilot_node_command = 'node', -- Node.js version must be > 18.x
                server_opts_overrides = {},
            })
        end,
    },
    {
        "CopilotC-Nvim/CopilotChat.nvim",
        branch = "canary",
        dependencies = {
            { "zbirenbaum/copilot.lua" },              -- or github/copilot.vim
            { "nvim-lua/plenary.nvim" },               -- for curl, log wrapper
            { "MeanderingProgrammer/render-markdown.nvim" }, -- Better markdown rendering
            { "nvim-treesitter/nvim-treesitter" },     -- Required for markdown rendering
        },
        build = "make tiktoken",                       -- Only on MacOS or Linux
        opts = {
            debug = false,                             -- Enable debugging
            -- See Configuration section for rest
        },
        config = function()
            local chat = require("CopilotChat")
            local select = require("CopilotChat.select")

            -- Setup CopilotChat with custom configuration
            chat.setup({
                debug = false,
                proxy = nil,    -- [protocol://]host[:port] Use this proxy
                allow_insecure = false, -- Allow insecure server connections

                system_prompt = [[You are an AI programming assistant integrated into Neovim.
Your role is to help with code generation, refactoring, debugging, and explanation.
Always provide practical, working solutions and explain your reasoning.
Focus on clean, readable, and maintainable code.
When refactoring, preserve functionality while improving code quality.
Format code blocks with proper language tags for syntax highlighting.]],

                -- model = 'gpt-4', -- GPT model to use
                temperature = 0.1,
                question_header = '## User ', -- Header to use for user questions
                answer_header = '## Copilot ', -- Header to use for AI answers
                error_header = '## Error ', -- Header to use for errors
                separator = '───', -- Separator to use in chat

                show_folds = true, -- Shows folds for sections in chat
                show_help = true, -- Shows help message as virtual lines when waiting for user input
                auto_follow_cursor = true, -- Auto-follow cursor in chat
                auto_insert_mode = false, -- Automatically enter insert mode when opening window and if auto follow cursor is enabled on new prompt
                insert_at_end = false, -- Move cursor to end of buffer when inserting text
                clear_chat_on_new_prompt = false, -- Clears chat on every new prompt
                highlight_selection = true, -- Highlight selection in the source buffer when in the chat window

                -- Enhanced markdown rendering for better readability
                chat_autocomplete = true,                                -- Enable autocomplete in chat
                show_help = true,                                        -- Show help text

                context = nil,                                           -- Default context to use, 'buffers', 'buffer' or none (can be specified manually in prompt via @).
                history_path = vim.fn.stdpath('data') .. '/copilotchat_history', -- Default path to stored history
                callback = nil,                                          -- Callback to use when ask response is received

                -- default selection (visual or line)
                selection = select.visual,

                -- default prompts
                prompts = {
                    Explain = {
                        prompt = '/COPILOT_EXPLAIN Write an explanation for the active selection as paragraphs of text.',
                    },
                    Review = {
                        prompt = '/COPILOT_REVIEW Review the selected code.',
                        callback = function(response, source)
                            -- see config.lua for implementation
                        end,
                    },
                    Fix = {
                        prompt =
                        '/COPILOT_GENERATE There is a problem in this code. Rewrite the code to fix the problem.',
                    },
                    Optimize = {
                        prompt = '/COPILOT_GENERATE Optimize the selected code to improve performance and readability.',
                    },
                    Docs = {
                        prompt = '/COPILOT_GENERATE Please add documentation comment for the selection.',
                    },
                    Tests = {
                        prompt = '/COPILOT_GENERATE Please generate tests for my code.',
                    },
                    FixDiagnostic = {
                        prompt = 'Please assist with the following diagnostic issue in file:',
                        selection = select.diagnostics,
                    },
                    Commit = {
                        prompt =
                        'Write commit message for the change with commitizen convention. Make sure the title has maximum 50 characters and message is wrapped at 72 characters. Wrap the whole message in code block with language gitcommit and write description after the title.',
                        selection = select.gitdiff,
                    },
                    CommitStaged = {
                        prompt =
                        'Write commit message for the change with commitizen convention. Make sure the title has maximum 50 characters and message is wrapped at 72 characters. Wrap the whole message in code block with language gitcommit and write description after the title.',
                        selection = function(source)
                            return select.gitdiff(source, true)
                        end,
                    },
                    -- Custom prompts for advanced workflows
                    Refactor = {
                        prompt =
                        '/COPILOT_GENERATE Please refactor the following code to improve its structure, readability, and maintainability while preserving functionality:',
                    },
                    CodeReview = {
                        prompt =
                        'Please provide a thorough code review focusing on: 1) Potential bugs, 2) Code quality and best practices, 3) Performance improvements, 4) Security considerations',
                    },
                    GenerateFunction = {
                        prompt =
                        '/COPILOT_GENERATE Based on the context and requirements, please generate a complete function implementation:',
                    },
                    ExplainError = {
                        prompt = 'Please explain this error and provide a solution:',
                        selection = select.diagnostics,
                    },
                },

                -- default window options
                window = {
                    layout = 'vertical', -- 'vertical', 'horizontal', 'float', 'replace'
                    width = 0.5,  -- fractional width of parent, or absolute width in columns when > 1
                    height = 0.5, -- fractional height of parent, or absolute height in rows when > 1
                    -- Options below only apply to floating windows
                    relative = 'editor', -- 'editor', 'win', 'cursor', 'mouse'
                    border = 'single', -- 'none', single', 'double', 'rounded', 'solid', 'shadow'
                    row = nil,    -- row position of the window, default is centered
                    col = nil,    -- column position of the window, default is centered
                    title = 'Copilot Chat', -- title of chat window
                    footer = nil, -- footer of chat window
                    zindex = 1,   -- determines if window is on top or below other floating windows
                },

                -- default mappings
                mappings = {
                    complete = {
                        detail = 'Use @<Tab> or /<Tab> for options.',
                        insert = '<Tab>',
                    },
                    close = {
                        normal = 'q',
                        insert = '<C-c>'
                    },
                    reset = {
                        normal = '<C-l>',
                        insert = '<C-l>'
                    },
                    submit_prompt = {
                        normal = '<CR>',
                        insert = '<C-s>'
                    },
                    accept_diff = {
                        normal = '<C-y>',
                        insert = '<C-y>'
                    },
                    yank_diff = {
                        normal = 'gy',
                        register = '"',
                    },
                    show_diff = {
                        normal = 'gd'
                    },
                    show_system_prompt = {
                        normal = 'gp'
                    },
                    show_user_selection = {
                        normal = 'gs'
                    },
                },
            })

            -- Key mappings for seamless integration
            local keymap = vim.keymap.set
            local opts = { noremap = true, silent = true }

            -- Core Copilot Chat functions
            keymap("n", "<leader>cc", "<cmd>CopilotChat<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Open chat window" }))
            keymap("v", "<leader>cc", "<cmd>CopilotChatVisual<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Open chat with visual selection" }))
            keymap("x", "<leader>cc", "<cmd>CopilotChatVisual<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Open chat with selection" }))

            -- Quick actions
            keymap("n", "<leader>ce", "<cmd>CopilotChatExplain<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Explain code" }))
            keymap("n", "<leader>cr", "<cmd>CopilotChatReview<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Review code" }))
            keymap("n", "<leader>cf", "<cmd>CopilotChatFix<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Fix code" }))
            keymap("n", "<leader>co", "<cmd>CopilotChatOptimize<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Optimize code" }))
            keymap("n", "<leader>cd", "<cmd>CopilotChatDocs<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Add documentation" }))
            keymap("n", "<leader>ct", "<cmd>CopilotChatTests<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Generate tests" }))

            -- Visual mode quick actions
            keymap("v", "<leader>ce", "<cmd>CopilotChatExplain<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Explain selection" }))
            keymap("v", "<leader>cr", "<cmd>CopilotChatReview<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Review selection" }))
            keymap("v", "<leader>cf", "<cmd>CopilotChatFix<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Fix selection" }))
            keymap("v", "<leader>co", "<cmd>CopilotChatOptimize<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Optimize selection" }))
            keymap("v", "<leader>cd", "<cmd>CopilotChatDocs<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Document selection" }))
            keymap("v", "<leader>ct", "<cmd>CopilotChatTests<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Generate tests for selection" }))

            -- Advanced refactoring and generation
            keymap("n", "<leader>cR", function()
                local input = vim.fn.input("Refactor prompt: ")
                if input ~= "" then
                    vim.cmd("CopilotChat " .. input)
                end
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Custom refactor prompt" }))

            keymap("v", "<leader>cR", function()
                local input = vim.fn.input("Refactor prompt: ")
                if input ~= "" then
                    vim.cmd("CopilotChatVisual " .. input)
                end
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Custom refactor prompt for selection" }))

            -- Predefined refactoring commands
            keymap("n", "<leader>crf", "<cmd>CopilotChat Refactor this code to use functional programming patterns<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Refactor to functional style" }))
            keymap("n", "<leader>cro", "<cmd>CopilotChat Refactor this code to improve object-oriented design<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Refactor to OOP style" }))
            keymap("n", "<leader>crs", "<cmd>CopilotChat Refactor this code to improve separation of concerns<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Improve separation of concerns" }))

            -- Quick fixes and diagnostics
            keymap("n", "<leader>cfd", "<cmd>CopilotChatFixDiagnostic<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Fix diagnostic" }))
            keymap("n", "<leader>cfe", function()
                local diagnostics = vim.diagnostic.get(0)
                if #diagnostics > 0 then
                    vim.cmd("CopilotChat Fix the following errors: " ..
                    vim.diagnostic.get_namespace(diagnostics[1].namespace).name)
                else
                    print("No diagnostics found")
                end
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Fix all errors in buffer" }))

            -- Code generation helpers
            keymap("n", "<leader>cgf", function()
                local input = vim.fn.input("Function description: ")
                if input ~= "" then
                    vim.cmd("CopilotChat Generate a function that " .. input)
                end
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Generate function" }))

            keymap("n", "<leader>cgc", function()
                local input = vim.fn.input("Class description: ")
                if input ~= "" then
                    vim.cmd("CopilotChat Generate a class that " .. input)
                end
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Generate class" }))

            keymap("n", "<leader>cgi", function()
                local input = vim.fn.input("Interface/Type description: ")
                if input ~= "" then
                    vim.cmd("CopilotChat Generate an interface/type that " .. input)
                end
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Generate interface" }))

            -- Git integration
            keymap("n", "<leader>ccm", "<cmd>CopilotChatCommit<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Generate commit message" }))
            keymap("n", "<leader>cms", "<cmd>CopilotChatCommitStaged<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Generate commit message for staged changes" }))

            -- Buffer and project context
            keymap("n", "<leader>ccb", function()
                local input = vim.fn.input("Question about buffer: ")
                if input ~= "" then
                    chat.ask(input, { selection = select.buffer })
                end
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Ask about current buffer" }))

            keymap("n", "<leader>ccp", function()
                local input = vim.fn.input("Question about project: ")
                if input ~= "" then
                    chat.ask(input, { selection = select.gitdiff })
                end
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Ask about project changes" }))

            -- Window management
            keymap("n", "<leader>ccv", function()
                chat.open({
                    window = { layout = 'vertical', width = 0.4 }
                })
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Open vertical split" }))

            keymap("n", "<leader>cch", function()
                chat.open({
                    window = { layout = 'horizontal', height = 0.4 }
                })
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Open horizontal split" }))

            keymap("n", "<leader>ccf", function()
                chat.open({
                    window = {
                        layout = 'float',
                        relative = 'editor',
                        width = 0.8,
                        height = 0.8,
                        row = 0.1,
                        col = 0.1,
                        border = 'rounded'
                    }
                })
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Open floating window" }))

            -- Toggle and reset functions
            keymap("n", "<leader>cct", "<cmd>CopilotChatToggle<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Toggle chat window" }))
            keymap("n", "<leader>ccr", "<cmd>CopilotChatReset<CR>",
                vim.tbl_extend("force", opts, { desc = "CopilotChat - Reset chat history" }))

            -- Advanced features
            keymap("n", "<leader>ccs", function()
                chat.ask("Summarize the current file and suggest improvements", {
                    selection = select.buffer,
                })
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Summarize and suggest improvements" }))

            keymap("n", "<leader>ccw", function()
                local input = vim.fn.input("What should this code do? ")
                if input ~= "" then
                    chat.ask("Generate code that " .. input, {
                        selection = function() return "" end, -- Empty selection for new code generation
                    })
                end
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Generate new code from description" }))

            -- Language-specific helpers
            keymap("n", "<leader>cls", function()
                chat.ask("Convert this code to use more modern language features and best practices", {
                    selection = select.visual,
                })
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Modernize code" }))

            keymap("n", "<leader>clc", function()
                local lang = vim.fn.input("Convert to language: ")
                if lang ~= "" then
                    chat.ask("Convert this code to " .. lang, {
                        selection = select.visual,
                    })
                end
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Convert to another language" }))

            -- Custom selection functions for better context
            local custom_select = {
                -- Select function under cursor
                current_function = function()
                    local ts_utils = require('nvim-treesitter.ts_utils')
                    local node = ts_utils.get_node_at_cursor()

                    while node do
                        if node:type():match("function") or node:type():match("method") then
                            return ts_utils.get_node_text(node)[1]
                        end
                        node = node:parent()
                    end

                    return select.visual()
                end,

                -- Select current class/struct
                current_class = function()
                    local ts_utils = require('nvim-treesitter.ts_utils')
                    local node = ts_utils.get_node_at_cursor()

                    while node do
                        if node:type():match("class") or node:type():match("struct") or node:type():match("interface") then
                            return ts_utils.get_node_text(node)[1]
                        end
                        node = node:parent()
                    end

                    return select.visual()
                end,
            }

            -- Function and class specific commands
            keymap("n", "<leader>cuf", function()
                chat.ask("Explain what this function does and suggest improvements", {
                    selection = custom_select.current_function,
                })
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Analyze current function" }))

            keymap("n", "<leader>cuc", function()
                chat.ask("Analyze this class structure and suggest improvements", {
                    selection = custom_select.current_class,
                })
            end, vim.tbl_extend("force", opts, { desc = "CopilotChat - Analyze current class" }))

            -- Setup markdown rendering for chat buffers
            vim.api.nvim_create_autocmd("FileType", {
                pattern = "copilot-chat",
                callback = function(event)
                    local buf = event.buf

                    -- Enable render-markdown for this buffer
                    pcall(function()
                        require('render-markdown').setup_buffer(buf, {
                            -- Custom config for chat
                            headings = { '󰉫 ', '󰉬 ', '󰉭 ', '󰉮 ', '󰉯 ', '󰉰 ' },
                            code = {
                                sign = false,
                                width = 'block',
                                right_pad = 1,
                            },
                            dash = '─',
                            bullets = { '●', '○', '◆', '◇' },
                            checkbox = {
                                unchecked = '󰄱 ',
                                checked = '󰱒 ',
                            },
                            quote = '▎',
                            win_options = {
                                conceallevel = { default = vim.api.nvim_get_option_value('conceallevel', {}) },
                                concealcursor = { default = vim.api.nvim_get_option_value('concealcursor', {}) },
                            },
                        })
                    end)

                    -- Set up better syntax highlighting
                    vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
                    vim.api.nvim_buf_set_option(buf, 'wrap', true)
                    vim.api.nvim_buf_set_option(buf, 'linebreak', true)

                    -- Improve readability
                    vim.api.nvim_win_set_option(0, 'conceallevel', 2)
                    vim.api.nvim_win_set_option(0, 'concealcursor', 'nc')
                end,
            })

            -- Additional chat window customizations
            vim.api.nvim_create_autocmd("BufEnter", {
                pattern = "*copilot-chat*",
                callback = function()
                    -- Enable spell checking in chat
                    vim.opt_local.spell = true
                    vim.opt_local.spelllang = "en_us"

                    -- Better text editing experience
                    vim.opt_local.textwidth = 80
                    vim.opt_local.colorcolumn = "80"
                end,
            })
        end,
    },

    -- Markdown rendering for better chat readability
    {
        "MeanderingProgrammer/render-markdown.nvim",
        dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
        -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
        -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
        opts = {
            -- Enhanced rendering for code blocks
            code = {
                sign = false,
                width = 'block',
                right_pad = 1,
                min_width = 60,
                border = 'thin',
                above = '▄',
                below = '▀',
                highlight = 'RenderMarkdownCode',
                highlight_inline = 'RenderMarkdownCodeInline',
            },
            -- Better heading rendering
            heading = {
                sign = false,
                icons = { '󰉫 ', '󰉬 ', '󰉭 ', '󰉮 ', '󰉯 ', '󰉰 ' },
                backgrounds = {
                    'RenderMarkdownH1Bg',
                    'RenderMarkdownH2Bg',
                    'RenderMarkdownH3Bg',
                    'RenderMarkdownH4Bg',
                    'RenderMarkdownH5Bg',
                    'RenderMarkdownH6Bg',
                },
            },
            -- Enhanced list rendering
            bullet = {
                icons = { '●', '○', '◆', '◇' },
                highlight = 'RenderMarkdownBullet',
            },
            checkbox = {
                unchecked = { icon = '󰄱 ', highlight = 'RenderMarkdownUnchecked' },
                checked = { icon = '󰱒 ', highlight = 'RenderMarkdownChecked' },
            },
            quote = { icon = '▎', highlight = 'RenderMarkdownQuote' },
            -- File types to enable
            file_types = { 'markdown', 'copilot-chat' },
            -- Render in normal mode
            render_modes = { 'n', 'c' },
        },
    },

    -- Optional: Enhanced experience with additional plugins
    {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
            vim.list_extend(opts.ensure_installed or {}, {
                "lua",
                "python",
                "javascript",
                "typescript",
                "rust",
                "go",
                "java",
                "cpp",
                "c"
            })
        end,
    },

    -- Telescope integration for better search
    {
        "nvim-telescope/telescope.nvim",
        optional = true,
        keys = {
            {
                "<leader>cch",
                function()
                    local actions = require("CopilotChat.actions")
                    require("CopilotChat.integrations.telescope").pick(actions.prompt_actions())
                end,
                mode = { "n", "v" },
                desc = "CopilotChat - Help actions",
            },
        },
        config = function()
            -- Optional: Load telescope extension if available
            pcall(require("telescope").load_extension, "copilotchat")
        end,
    },

    -- fzf-lua integration (alternative to telescope)
    {
        "ibhagwan/fzf-lua",
        optional = true,
        keys = {
            {
                "<leader>cch",
                function()
                    local actions = require("CopilotChat.actions")
                    require("CopilotChat.integrations.fzflua").pick(actions.prompt_actions())
                end,
                mode = { "n", "v" },
                desc = "CopilotChat - Help actions (fzf)",
            },
        },
    },
}
