#!/bin/bash

# Exit on error
set -e

echo "Starting Mac setup..."

# Install homebrew if not already installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo "Homebrew already installed"
fi

# Clone dotfiles repo if not already present
if [ ! -d ~/dotfiles ]; then
    echo "Cloning dotfiles repo..."
    git clone https://github.com/matt-winfield/dotfiles.git ~/dotfiles
else
    echo "Dotfiles repo already exists"
fi

# Install iTerm2 if not already installed
if [ ! -d "/Applications/iTerm.app" ]; then
    echo "Installing iTerm2..."
    brew install --cask iterm2
else
    echo "iTerm2 already installed"
fi

brew install --cask font-meslo-lg-nerd-font

# Create config directory if it doesn't exist
mkdir -p ~/.config/karabiner

# Link karabiner config file
echo "Linking Karabiner config..."
ln -sf ~/dotfiles/.config/karabiner/karabiner.json ~/.config/karabiner/karabiner.json

# Install Karabiner Elements if not already installed
if [ ! -d "/Applications/Karabiner-Elements.app" ]; then
    echo "Installing Karabiner Elements..."
    brew install --cask karabiner-elements
else
    echo "Karabiner Elements already installed"
fi

# Install CLI tools if not already installed
for tool in eza zoxide lazygit fzf atuin starship gh nvm zsh-autosuggestions neovim ripgrep; do
    if ! brew list $tool &> /dev/null; then
        echo "Installing $tool..."
        brew install $tool
    else
        echo "$tool already installed"
    fi
done

# Initialize nvm in this script
if [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
    echo "Initializing nvm..."
    export NVM_DIR="$HOME/.nvm"
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
    
    echo "Installing and using LTS Node version..."
    nvm install --lts
    nvm use --lts
elif [ -s "/usr/local/opt/nvm/nvm.sh" ]; then
    # For Intel Macs
    export NVM_DIR="$HOME/.nvm"
    [ -s "/usr/local/opt/nvm/nvm.sh" ] && \. "/usr/local/opt/nvm/nvm.sh"
    
    echo "Installing and using LTS Node version..."
    nvm install --lts
    nvm use --lts
else
    echo "nvm not found, skipping Node installation"
fi

# Link starship config
echo "Linking Starship config..."
mkdir -p ~/.config
ln -sf ~/dotfiles/.config/starship.toml ~/.config/starship.toml

# Link aerospace config
echo "Linking Aerospace config..."
ln -sf ~/dotfiles/.aerospace.toml ~/.aerospace.toml

# Install Aerospace if not already installed
if [ ! -d "/Applications/AeroSpace.app" ]; then
    echo "Installing Aerospace..."
    brew install --cask nikitabobko/tap/aerospace
else
    echo "Aerospace already installed"
fi

# Link zshrc
echo "Linking .zshrc..."
ln -sf ~/dotfiles/.zshrc ~/.zshrc

# Clone neovim config repo if not already present
if [ ! -d ~/.config/nvim ]; then
    echo "Cloning neovim config repo..."
    git clone https://github.com/matt-winfield/neovim-config.git ~/.config/nvim
else
    echo "nvim directory already exists"
fi

# Disable dock autohide delay
echo "Configuring Dock..."
defaults write com.apple.dock autohide-delay -float 0 && killall Dock

echo "Setup complete!"
