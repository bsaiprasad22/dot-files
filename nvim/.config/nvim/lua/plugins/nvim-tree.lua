return {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        require("nvim-tree").setup({
            view = {
                width = 30,
                side = "left",
            },
            renderer = {
                group_empty = true,
                icons = {
                    show = {
                        git = true,
                        folder = true,
                        file = true,
                        folder_arrow = true,
                    },
                },
            },
            filters = {
                dotfiles = false,
                custom = { "^.git$" },
            },
            git = {
                enable = true,
                ignore = false,
            },
            actions = {
                open_file = {
                    quit_on_open = false,
                    resize_window = true,
                },
            },
            update_focused_file = {
                enable = true,
                update_root = false,
            },
        })

        local opts = { noremap = true, silent = true }
        vim.keymap.set("n", "<leader>e", "<Cmd>NvimTreeToggle<CR>", opts)
        vim.keymap.set("n", "<leader>fe", "<Cmd>NvimTreeFindFile<CR>", opts)
    end,
}
