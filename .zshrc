# Load secrets file
if [[ -f ~/.zsh_secrets ]]; then
  source ~/.zsh_secrets
fi

# Create a new branch and worktree with the given name
gwt() {
  local branchName="$1"
  local filesToCopy=(".env.local" ".env") # Define your own set of common files here

  if [[ -z "$branchName" ]]; then
    echo "Branch name is required." >&2
    return 1
  fi

  # Check if branch already exists
  if git branch --list "$branchName" | grep -q "$branchName"; then
    echo "Branch '$branchName' already exists. Re-using the existing branch."
  else
    git branch "$branchName"
    echo "Created new branch: $branchName"
  fi

  # Create the new worktree
  git worktree add "$branchName" "$branchName"

  # Determine source directory (main or master worktree)
  local sourceDir="."
  if [[ -d ".git/worktrees/master" ]]; then
    sourceDir="./master"
  elif [[ -d ".git/worktrees/main" ]]; then
    sourceDir="./main"
  fi

  # Copy common files
  for filename in "${filesToCopy[@]}"; do
    local src="$sourceDir/$filename"
    if [[ -f "$src" ]]; then
      cp "$src" "$branchName"
    else
      echo "File not found: $src"
    fi
  done

  # Enter the new worktree directory and install dependencies
  pushd "$branchName" > /dev/null

  if [[ -f "pnpm-lock.yaml" ]]; then
    pnpm install
  elif [[ -f "yarn.lock" ]]; then
    yarn install
  elif [[ -f "package-lock.json" ]]; then
    npm install
  fi

  popd > /dev/null
}

# Clone a repo as a bare repo and set up initial worktree
Git_CloneBareWorktree() {
  local url="$1"
  local name="$2"

  if [[ -z "$url" ]]; then
    echo "Usage: Git_CloneBareWorktree <url> [name]" >&2
    return 1
  fi

  # Get repo name if no custom name is provided
  local basename=$(basename "$url")
  [[ "$basename" == *.git ]] && basename="${basename%.git}"

  [[ -z "$name" ]] && name="$basename"

  mkdir -p "$name"
  cd "$name" || return 1

  git clone --bare "$url" .bare
  echo "gitdir: ./.bare" > .git

  git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git fetch origin
}

alias clone-worktree=Git_CloneBareWorktree

# Initialise zoxide
eval "$(zoxide init zsh)"

# Enable vim mode
bindkey -v

# Case insensitive tab complete
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select
autoload -Uz compinit
compinit

# Enable auto-suggestions
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Load nvm
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

alias ls="eza"
alias lg="lazygit"

# Check that the function `starship_zle-keymap-select()` is defined.
# xref: https://github.com/starship/starship/issues/3418
type starship_zle-keymap-select >/dev/null || \
  {
    eval "$(starship init zsh)"
  }

. "$HOME/.atuin/bin/env"
eval "$(atuin init zsh)"
