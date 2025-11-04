# My configs
```
sudo apt install ripgrep
sudo apt install fzf
sudo apt install zoxide
sudo apt install stow
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

For copilot chat
```
sudo apt install luarocks
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
sudo apt install build-essential pkg-config libssl-dev
luarocks install --lua-version 5.1 tiktoken_core --local
export PATH="$HOME/.luarocks/bin:$PATH" #Add to bashrc
sudo apt install lynx
```

For local nvim setup (edit locally and sync)
```
# Download the FULL release (not just the binary)
cd /tmp
curl -L -o mutagen.tar.gz https://github.com/mutagen-io/mutagen/releases/download/v0.17.6/mutagen_linux_amd64_v0.17.6.tar.gz

# Extract everything
tar -xzf mutagen.tar.gz

# You should see both 'mutagen' and 'mutagen-agents.tar.gz'
ls -la mutagen*

# Move both files
sudo mv mutagen /usr/local/bin/
sudo mv mutagen-agents.tar.gz /usr/local/bin/
sudo chmod +x /usr/local/bin/mutagen

# Start daemon
mutagen daemon start
```
