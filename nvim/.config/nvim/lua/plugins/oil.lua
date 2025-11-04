return {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        require("oil").setup({
            -- Default file explorer to use when opening a directory
            default_file_explorer = true,

            -- Columns to display in oil buffer
            columns = {
                "icon",
                -- "permissions",
                -- "size",
                -- "mtime",
            },

            -- Buffer options for oil buffers
            buf_options = {
                buflisted = false,
                bufhidden = "hide",
            },

            -- Window options for oil buffers
            win_options = {
                wrap = false,
                signcolumn = "no",
                cursorcolumn = false,
                foldcolumn = "0",
                spell = false,
                list = false,
                conceallevel = 3,
                concealcursor = "nvic",
            },

            -- Delete files/folders to trash instead of permanently deleting
            delete_to_trash = true,

            -- Skip confirmation for simple operations
            skip_confirm_for_simple_edits = false,

            -- Prompt to save changes when leaving oil buffer
            prompt_save_on_select_new_entry = true,

            -- Keymaps in oil buffer. Set to false to remove a keymap
            keymaps = {

                ["g?"] = "actions.show_help",
                ["<CR>"] = "actions.select",
                ["<C-s>"] = "actions.select_vsplit",
                ["<C-h>"] = "actions.select_split",
                ["<C-t>"] = "actions.select_tab",
                ["<C-p>"] = "actions.preview",
                ["<C-c>"] = "actions.close",
                ["<C-l>"] = "actions.refresh",
                ["-"] = "actions.parent",
                ["_"] = "actions.open_cwd",
                ["`"] = "actions.cd",
                ["~"] = "actions.tcd",
                ["gs"] = "actions.change_sort",
                ["gx"] = "actions.open_external",
                ["g."] = "actions.toggle_hidden",
                ["g\\"] = "actions.toggle_trash",
            },

            -- Set to false to disable all keymaps
            use_default_keymaps = true,

            -- Configuration for the floating window
            float = {
                padding = 2,
                max_width = 0,
                max_height = 0,
                border = "rounded",
                win_options = {
                    winblend = 0,
                },
                override = function(conf)
                    return conf
                end,
            },

            -- Configuration for the actions floating preview window
            preview = {
                max_width = 0.9,
                min_width = { 40, 0.4 },
                width = nil,
                max_height = 0.9,
                min_height = { 5, 0.1 },
                height = nil,
                border = "rounded",
                win_options = {
                    winblend = 0,
                },
            },

            -- Configuration for the floating progress window
            progress = {
                max_width = 0.9,
                min_width = { 40, 0.4 },
                width = nil,
                max_height = { 10, 0.9 },
                min_height = { 5, 0.1 },
                height = nil,
                border = "rounded",
                minimized_border = "none",
                win_options = {
                    winblend = 0,
                },
            },
        })

        -- Keymaps for opening oil
        vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
        vim.keymap.set("n", "<leader>-", require("oil").toggle_float, { desc = "Open oil in floating window" })
    end,
}
