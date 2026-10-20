#!/bin/bash

# Exit on error
set -e

echo "Starting Mac setup..."

# Install homebrew if not already installed
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >>~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo "Homebrew already installed"
fi

# Third-party taps are ignored until each formula or cask is trusted.
# Trust before other brew commands so installs and upgrades are not skipped.
echo "Trusting third-party Homebrew packages..."
brew trust --formula atlassian/acli/acli
brew trust --cask nikitabobko/tap/aerospace

# Clone dotfiles repo if not already present
if [ ! -d ~/dotfiles ]; then
    echo "Cloning dotfiles repo..."
    git clone https://github.com/matt-winfield/dotfiles.git ~/dotfiles
else
    echo "Dotfiles repo already exists"
fi

# Install Ghostty if not already installed
if [ ! -d "/Applications/Ghostty.app" ]; then
    echo "Installing Ghostty..."
    brew install --cask ghostty
else
    echo "Ghostty already installed"
fi

if ! ls $HOME/Library/Fonts/Meslo*NerdFontMono*.ttf >/dev/null 2>&1; then
    echo "Installing meslo nerd font..."
    brew install --cask font-meslo-lg-nerd-font
else
    echo "Meslo Nerd Font already installed"
fi

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

# Machine profile: "work" or "personal". See machine-profile.sh.
# Personal-only tools are skipped on the work laptop until they are approved.
source "$HOME/dotfiles/machine-profile.sh"
machine_profile="$(dotfiles_machine_profile)"
echo "Machine profile: $machine_profile"

# Installed on every machine. gum is used in .zshrc for multi-choice aliases.
common_tools=(
    eza
    zoxide
    lazygit
    fzf
    atuin
    starship
    gh
    nvm
    zsh-autosuggestions
    neovim
    go
    ripgrep
    gum
    thaw
    bat
    tmux
)

# Not approved for the work laptop yet.
personal_tools=(
    vorssaint
)

tools=("${common_tools[@]}")
case "$machine_profile" in
    personal)
        tools+=("${personal_tools[@]}")
        ;;
    work)
        echo "Skipping personal-only tools: ${personal_tools[*]}"
        ;;
    *)
        echo "Unknown machine profile '$machine_profile' (expected work or personal). Skipping personal-only tools."
        ;;
esac

# Install CLI tools if not already installed
for tool in "${tools[@]}"; do
    if ! brew list "$tool" &>/dev/null; then
        echo "Installing $tool..."
        brew install "$tool"
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

# Link Ghostty config
echo "Linking Ghostty config..."
mkdir -p ~/.config/ghostty
ln -sf ~/dotfiles/.config/ghostty/config.ghostty ~/.config/ghostty/config.ghostty

# Link tmux config (Ghostty runs inside tmux)
echo "Linking tmux config..."
ln -sf ~/dotfiles/.tmux.conf ~/.tmux.conf

# Link aerospace config
echo "Linking Aerospace config..."
ln -sf ~/dotfiles/.aerospace.toml ~/.aerospace.toml

# cmd + ctrl + drag to move window
defaults write -g NSWindowShouldDragOnGesture -bool true
# Better display for windows in Mission Control with aerospace active
defaults write com.apple.dock expose-group-apps -bool true

# Install Aerospace if not already installed
if [ ! -d "/Applications/AeroSpace.app" ]; then
    echo "Installing Aerospace..."
    brew install --cask nikitabobko/tap/aerospace
else
    echo "Aerospace already installed"
fi

# Set GH editor to vim
echo "Configuring GH editor..."
gh config set editor vim

# Link global agent instructions (shared by Codex and Claude Code)
echo "Linking AGENTS.md..."
mkdir -p ~/.codex ~/.claude
ln -sf ~/dotfiles/AGENTS.md ~/.codex/AGENTS.md
ln -sf ~/dotfiles/AGENTS.md ~/.claude/CLAUDE.md

# Link Claude Code settings and the hook scripts they reference
echo "Linking Claude Code settings..."
mkdir -p ~/.claude/hooks
ln -sf ~/dotfiles/claude/settings.json ~/.claude/settings.json
for hook in ~/dotfiles/claude/hooks/*.sh; do
    chmod +x "$hook"
    ln -sf "$hook" ~/.claude/hooks/"$(basename "$hook")"
done

# Link Cursor CLI hooks (also used by the IDE agent)
echo "Linking Cursor hooks..."
mkdir -p ~/.cursor
ln -sf ~/dotfiles/cursor/hooks.json ~/.cursor/hooks.json

# Shared skills. Cursor loads ~/.agents/skills and ~/.claude/skills.
# Claude Code loads ~/.claude/skills, which points at the shared copy.
echo "Linking agent skills..."
mkdir -p ~/.agents/skills ~/.claude/skills
for skill in ~/dotfiles/skills/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    ln -sfn "$skill" ~/.agents/skills/"$name"
    ln -sfn "../../.agents/skills/$name" ~/.claude/skills/"$name"
done

# Link gitconfig
echo "Linking .gitconfig..."
ln -sf ~/dotfiles/.gitconfig ~/.gitconfig

# Make git credential helper scripts executable
chmod +x ~/dotfiles/bin/github-access-token
chmod +x ~/dotfiles/bin/git-credential-sports-global
chmod +x ~/dotfiles/bin/git-credential-supergroup
chmod +x ~/dotfiles/bin/gh

# Link global gitignore
echo "Linking .gitignore_global..."
ln -sf ~/dotfiles/.gitignore_global ~/.gitignore_global

# Link zshrc
echo "Linking .zshrc..."
ln -sf ~/dotfiles/.zshrc ~/.zshrc

# Link package manager security configs
echo "Linking .npmrc (npm + pnpm)..."
ln -sf ~/dotfiles/.npmrc ~/.npmrc

echo "Linking .yarnrc.yml (Yarn Berry)..."
ln -sf ~/dotfiles/.yarnrc.yml ~/.yarnrc.yml

# pnpm global security settings (written to ~/Library/Preferences/pnpm/rc)
if command -v pnpm &>/dev/null; then
    echo "Configuring pnpm security settings..."
    pnpm config set save-exact true
    pnpm config set ignore-scripts true
    pnpm config set minimumReleaseAge 2880
    pnpm config set trustPolicy no-downgrade
else
    echo "pnpm not found — skipping pnpm config (re-run after installing pnpm)"
fi

# Clone neovim config repo if not already present
if [ ! -d ~/.config/nvim ]; then
    echo "Cloning neovim config repo..."
    git clone https://github.com/matt-winfield/neovim-config.git ~/.config/nvim
else
    echo "nvim directory already exists"
fi

# Disable "navigate with scrolls" in Firefox and Chrome
defaults write com.google.Chrome AppleEnableSwipeNavigateWithScrolls -bool FALSE
defaults write org.mozilla.firefox AppleEnableSwipeNavigateWithScrolls -bool FALSE

# Disable auto-punctuation and corrections
echo "Disabling auto-punctuation..."
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable hold-key for accented characters (messes with vim hold j / k in vscode)
defaults write -g ApplePressAndHoldEnabled -bool false

# Disable dock autohide delay
echo "Configuring Dock..."
defaults write com.apple.dock autohide-delay -float 0

# Disable hot-corner shortcuts
defaults write com.apple.dock wvous-tl-corner -int 0 # Top-left
defaults write com.apple.dock wvous-tr-corner -int 0 # Top-right
defaults write com.apple.dock wvous-bl-corner -int 0 # Bottom-left
defaults write com.apple.dock wvous-br-corner -int 0 # Bottom-right

killall Dock

echo "Setup complete!"
