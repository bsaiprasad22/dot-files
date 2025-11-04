-- bufferline.nvim configuration
-- Add this to your init.lua or in a separate file in your config

return {

    'akinsho/bufferline.nvim',
    version = "*",
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
        require("bufferline").setup({
            options = {
                mode = "buffers", -- set to "tabs" to only show tabpages instead
                themable = true,
                numbers = "none", -- can be "none" | "ordinal" | "buffer_id" | "both"

                close_command = "bdelete! %d",
                right_mouse_command = "bdelete! %d",
                left_mouse_command = "buffer %d",
                middle_mouse_command = nil,
                indicator = {
                    icon = '▎',
                    style = 'icon',
                },
                buffer_close_icon = '󰅖',
                modified_icon = '●',
                close_icon = '',
                left_trunc_marker = '',
                right_trunc_marker = '',
                max_name_length = 18,
                max_prefix_length = 15,
                truncate_names = true,
                tab_size = 18,
                diagnostics = "nvim_lsp",
                diagnostics_update_in_insert = false,
                diagnostics_indicator = function(count, level)
                    local icon = level:match("error") and " " or " "
                    return " " .. icon .. count
                end,
                offsets = {
                    {
                        filetype = "NvimTree",
                        text = "File Explorer",
                        text_align = "center",
                        separator = true
                    }

                },
                color_icons = true,
                show_buffer_icons = true,
                show_buffer_close_icons = true,
                show_close_icon = true,
                show_tab_indicators = true,
                show_duplicate_prefix = true,
                persist_buffer_sort = true,
                separator_style = "thin", -- "slant" | "slope" | "thick" | "thin" | { 'any', 'any' }
                enforce_regular_tabs = false,
                always_show_bufferline = true,
                hover = {

                    enabled = true,
                    delay = 200,
                    reveal = { 'close' }
                },
                sort_by = 'insert_after_current',
            }
        })

        -- Keybindings for easy buffer navigation
        local opts = { noremap = true, silent = true }

        -- -- Navigate to next/previous buffer
        -- vim.keymap.set('n', '<Tab>', '<Cmd>BufferLineCycleNext<CR>', opts)
        -- vim.keymap.set('n', '<S-Tab>', '<Cmd>BufferLineCyclePrev<CR>', opts)
        --
        -- -- Alternative: Use Ctrl+l/h for next/previous
        -- vim.keymap.set('n', '<C-l>', '<Cmd>BufferLineCycleNext<CR>', opts)
        -- vim.keymap.set('n', '<C-h>', '<Cmd>BufferLineCyclePrev<CR>', opts)
        --
        -- -- Move buffer position (reorder tabs)
        -- vim.keymap.set('n', '<A-l>', '<Cmd>BufferLineMoveNext<CR>', opts)
        -- vim.keymap.set('n', '<A-h>', '<Cmd>BufferLineMovePrev<CR>', opts)

        -- Go to specific buffer by number (1-9)
        vim.keymap.set('n', '<leader>1', '<Cmd>BufferLineGoToBuffer 1<CR>', opts)
        vim.keymap.set('n', '<leader>2', '<Cmd>BufferLineGoToBuffer 2<CR>', opts)
        vim.keymap.set('n', '<leader>3', '<Cmd>BufferLineGoToBuffer 3<CR>', opts)
        vim.keymap.set('n', '<leader>4', '<Cmd>BufferLineGoToBuffer 4<CR>', opts)
        vim.keymap.set('n', '<leader>5', '<Cmd>BufferLineGoToBuffer 5<CR>', opts)
        vim.keymap.set('n', '<leader>6', '<Cmd>BufferLineGoToBuffer 6<CR>', opts)
        vim.keymap.set('n', '<leader>7', '<Cmd>BufferLineGoToBuffer 7<CR>', opts)
        vim.keymap.set('n', '<leader>8', '<Cmd>BufferLineGoToBuffer 8<CR>', opts)
        vim.keymap.set('n', '<leader>9', '<Cmd>BufferLineGoToBuffer 9<CR>', opts)

        -- Close buffers
        vim.keymap.set('n', '<leader>bc', '<Cmd>bdelete<CR>', opts)           -- close current buffer
        vim.keymap.set('n', '<leader>bC', '<Cmd>BufferLinePickClose<CR>', opts) -- pick buffer to close
        vim.keymap.set('n', '<leader>bx', '<Cmd>BufferLineCloseOthers<CR>', opts) -- close all others
        vim.keymap.set('n', '<leader>bl', '<Cmd>BufferLineCloseLeft<CR>', opts) -- close all to the left
        vim.keymap.set('n', '<leader>br', '<Cmd>BufferLineCloseRight<CR>', opts) -- close all to the right

        -- Pick buffer (interactive selection)
        vim.keymap.set('n', '<leader>bp', '<Cmd>BufferLinePick<CR>', opts)

        -- Sort buffers
        vim.keymap.set('n', '<leader>bse', '<Cmd>BufferLineSortByExtension<CR>', opts)
        vim.keymap.set('n', '<leader>bsd', '<Cmd>BufferLineSortByDirectory<CR>', opts)
    end,
}
