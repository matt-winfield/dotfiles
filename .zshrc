# Load secrets file
if [[ -f ~/.zsh_secrets ]]; then
  source ~/.zsh_secrets
fi

case ":$PATH:" in
  *":$HOME/dotfiles/bin:"*) ;;
  *) export PATH="$HOME/dotfiles/bin:$PATH" ;;
esac

# Work laptop: GitHub CLI package-manager wrappers, pnpm, and the Android SDK.
source "$HOME/dotfiles/machine-profile.sh"
if [[ "$(dotfiles_machine_profile)" == "work" ]]; then
  source "$HOME/dotfiles/.zshrc.work"
fi

# Create a branch and worktree with the given name
gwt() {
  local branchName="$1"
  local filesToCopy=(".env.local" ".env") # Define your own set of common files here

  if [[ -z "$branchName" ]]; then
    echo "Branch name is required." >&2
    return 1
  fi

  if ! git check-ref-format --branch "$branchName" > /dev/null 2>&1; then
    echo "Invalid branch name: $branchName" >&2
    return 1
  fi

  # Refresh remote refs without moving a checked-out local base branch.
  if git remote get-url origin > /dev/null 2>&1; then
    git fetch origin || return 1
  fi

  local baseBranch=""
  baseBranch="$(_git_default_branch)" || return 1

  local baseRef="$baseBranch"
  if git show-ref --verify --quiet "refs/remotes/origin/$baseBranch"; then
    baseRef="origin/$baseBranch"
  fi

  # Reuse a local branch, or create one from its remote counterpart when it exists.
  if git show-ref --verify --quiet "refs/heads/$branchName"; then
    echo "Branch '$branchName' already exists. Re-using the existing branch."

    if git show-ref --verify --quiet "refs/remotes/origin/$branchName" &&
      ! git rev-parse --verify --quiet "$branchName@{upstream}" > /dev/null 2>&1; then
      git branch --set-upstream-to="origin/$branchName" "$branchName" || return 1
      echo "Branch '$branchName' now tracks origin/$branchName."
    fi

    git worktree add "$branchName" "$branchName" || return 1
  elif git show-ref --verify --quiet "refs/remotes/origin/$branchName"; then
    git worktree add --track -b "$branchName" "$branchName" "origin/$branchName" || return 1
    echo "Created branch '$branchName' tracking origin/$branchName."
  else
    git worktree add --no-track -b "$branchName" "$branchName" "$baseRef" || return 1
    echo "Created new branch: $branchName"
  fi

  # Determine source directory (the default branch worktree)
  local sourceDir="."
  if [[ -e "$baseBranch/.git" ]]; then
    sourceDir="$baseBranch"
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
  pushd "$branchName" > /dev/null || return 1

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

  mkdir -p "$name" || return 1
  cd "$name" || return 1

  git clone --bare "$url" .bare || return 1
  echo "gitdir: ./.bare" > .git || return 1

  git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" || return 1
  git fetch origin || return 1

  local defaultBranch
  defaultBranch="$(_git_default_branch)" || return 1

  if git show-ref --verify --quiet "refs/heads/$defaultBranch"; then
    git worktree add "$defaultBranch" "$defaultBranch" || return 1
  else
    git worktree add --track -b "$defaultBranch" "$defaultBranch" "origin/$defaultBranch" || return 1
  fi

  git branch --set-upstream-to="origin/$defaultBranch" "$defaultBranch" || return 1
  echo "Created '$defaultBranch' worktree tracking origin/$defaultBranch."
}

alias clone-worktree=Git_CloneBareWorktree

# Create a GitHub Pull Request, auto-set the title with JIRA ticket based on branch name
ghpr() {
  # ---- Infer JIRA ref from branch ----
  local branch jira_ref=""
  branch="$(git branch --show-current 2>/dev/null)"

  if [[ "$branch" =~ ([a-z]+-[0-9]+) ]]; then
    jira_ref="[${${match[1]}:u}] "
  fi

  # ---- Last commit subject ----
  local last_commit
  last_commit="$(git log -1 --pretty=%s 2>/dev/null)"

  local default_title="${jira_ref}${last_commit}"

  # ---- Draft selector (arrow keys) ----
  local draft_choice
  draft_choice="$(gum choose \
    "Ready for review" \
    "Draft PR"
  )" || return 1

  local draft_flag=""
  [[ "$draft_choice" == "Draft PR" ]] && draft_flag="--draft"

  # ---- Create PR ----
  gh pr create \
    --title "$default_title" \
    --editor \
    --fill \
    $draft_flag
}

_git_default_branch() {
  local remoteHead=""

  if remoteHead="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2> /dev/null)"; then
    remoteHead="${remoteHead#origin/}"
    if git show-ref --verify --quiet "refs/remotes/origin/$remoteHead"; then
      printf '%s\n' "$remoteHead"
      return 0
    fi
  fi

  local candidate
  for candidate in main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$candidate" ||
      git show-ref --verify --quiet "refs/heads/$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  echo "Could not determine the repository's default branch." >&2
  return 1
}

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

[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# nvm auto-switch from .nvmrc
autoload -U add-zsh-hook

load-nvmrc() {
  local nvmrc_path
  nvmrc_path="$(nvm_find_nvmrc)"

  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version
    nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
      nvm use
    fi
  elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}

add-zsh-hook chpwd load-nvmrc
load-nvmrc

# Include Go binaries in the path
export PATH=$PATH:$HOME/go/bin

alias ls="eza"
alias lg="lazygit"
alias cat="bat"
# place this after nvm initialization!
autoload -U add-zsh-hook

load-nvmrc() {
  local nvmrc_path
  nvmrc_path="$(nvm_find_nvmrc)"

  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version
    nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
      nvm use
    fi
  elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}

add-zsh-hook chpwd load-nvmrc
load-nvmrc

# Check that the function `starship_zle-keymap-select()` is defined.
# xref: https://github.com/starship/starship/issues/3418
type starship_zle-keymap-select >/dev/null || \
  {
    eval "$(starship init zsh)"
  }


eval "$(atuin init zsh)"
export PATH="$HOME/.local/bin:$PATH"

# opencode
export PATH=/Users/mattw/.opencode/bin:$PATH
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk@17/include"
export JAVA_HOME=$(/usr/libexec/java_home)

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/mattw/.lmstudio/bin"
# End of LM Studio CLI section

# Machine-only settings (not tracked), e.g. installer-added PATH entries.
if [[ -f ~/.zshrc.local ]]; then
  source ~/.zshrc.local
fi

# Ghostty only loads its shell integration in shells it starts itself, so load
# it inside tmux too. It sets the pane title tmux shows as the tab name.
if [[ -n $TMUX && -n $GHOSTTY_RESOURCES_DIR ]]; then
  source "$GHOSTTY_RESOURCES_DIR"/shell-integration/zsh/ghostty-integration
fi
