return {
  "chipsenkbeil/distant.nvim",
  branch = "v0.3",
  config = function()
    require("distant"):setup({
      -- Apply these settings to all servers
      ["*"] = {
        connect = {
          default = {
            scheme = "ssh",
            options = "ssh.backend=libssh",
          },
        },
        lsp = {
          -- Automatically start LSP servers on remote when opening supported files
          ["*"] = {
            on_attach = function(client, bufnr)
              -- Your LSP keybindings can go here if needed
            end,
          },
        },
      },
    })

    -- Keymaps for distant operations
    vim.keymap.set("n", "<leader>dc", "<cmd>DistantConnect<cr>", { desc = "Distant: Connect to server" })
    vim.keymap.set("n", "<leader>dl", "<cmd>DistantLaunch<cr>", { desc = "Distant: Launch server" })
    vim.keymap.set("n", "<leader>do", "<cmd>DistantOpen<cr>", { desc = "Distant: Open file/dir" })
    vim.keymap.set("n", "<leader>ds", "<cmd>DistantShell<cr>", { desc = "Distant: Open remote shell" })
    vim.keymap.set("n", "<leader>dm", "<cmd>DistantMetadata<cr>", { desc = "Distant: Show metadata" })
  end,
}
