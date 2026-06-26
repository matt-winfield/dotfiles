# Load secrets file
if [[ -f ~/.zsh_secrets ]]; then
  source ~/.zsh_secrets
fi

# Map of GitHub org -> env var name holding the PAT to use
# Add entries as: "OrgName" "ENV_VAR_NAME"
typeset -A GH_ORG_TOKEN_MAP=(
  "Sports-Global" "SPORTS_GLOBAL_GITHUB_TOKEN"
  "sg-ltd"        "SUPERGROUP_GITHUB_TOKEN"
)

# Resolve a GitHub token through the shared resolver.
gh_token_for_env_var() {
  local resolver
  resolver="$(command -v github-access-token 2>/dev/null || true)"

  if [[ -z "$resolver" ]]; then
    resolver="$HOME/dotfiles/bin/github-access-token"
  fi

  "$resolver" "$1" 2>/dev/null
}

# gh wrapper: automatically selects the correct PAT based on the current repo's org
gh() {
  local remote_url org token_var token
  remote_url=$(git remote get-url origin 2>/dev/null || true)

  for org token_var in "${(@kv)GH_ORG_TOKEN_MAP}"; do
    if [[ "$remote_url" == *"github.com"*"/$org/"* || "$remote_url" == *"github.com"*":$org/"* ]]; then
      if token="$(gh_token_for_env_var "$token_var")"; then
        GH_TOKEN="$token" GITHUB_TOKEN="$token" command gh "$@"
        return
      fi
    fi
  done

  command gh "$@"
}

package_install_with_all_github_tokens() {
  local sports_token supergroup_token
  local -a env_args

  if sports_token="$(gh_token_for_env_var SPORTS_GLOBAL_GITHUB_TOKEN)"; then
    env_args+=(
      "GITHUB_TOKEN=$sports_token"
      "SPORTS_GLOBAL_GITHUB_TOKEN=$sports_token"
    )
  fi

  if supergroup_token="$(gh_token_for_env_var SUPERGROUP_GITHUB_TOKEN)"; then
    env_args+=("GH_PKG_SG_LTD_TOKEN=$supergroup_token")
  fi

  env "${env_args[@]}" "$@"
}

pnpm() {
  local pnpm_bin
  pnpm_bin="$(whence -p pnpm)"

  if [[ "$1" == "install" || "$1" == "i" ]]; then
    package_install_with_all_github_tokens "$pnpm_bin" "$@"
    return
  fi

  "$pnpm_bin" "$@"
}

yarn() {
  local yarn_bin
  yarn_bin="$(whence -p yarn)"

  if [[ $# -eq 0 || "$1" == "install" ]]; then
    package_install_with_all_github_tokens "$yarn_bin" "$@"
    return
  fi

  "$yarn_bin" "$@"
}

# Create a new branch and worktree with the given name
gwt() {
  local branchName="$1"
  local filesToCopy=(".env.local" ".env") # Define your own set of common files here

  if [[ -z "$branchName" ]]; then
    echo "Branch name is required." >&2
    return 1
  fi

  # Determine base branch (main or master)
  local baseBranch=""
  if git show-ref --verify --quiet refs/heads/main; then
    baseBranch="main"
  elif git show-ref --verify --quiet refs/heads/master; then
    baseBranch="master"
  else
    echo "Neither 'main' nor 'master' branch found." >&2
    return 1
  fi

  # Ensure base branch is up to date (safe for bare/worktree)
  git fetch
  git update-ref "refs/heads/$baseBranch" "origin/$baseBranch"

  # Check if branch already exists
  if git branch --list "$branchName" | grep -q "$branchName"; then
    echo "Branch '$branchName' already exists. Re-using the existing branch."
  else
    git branch "$branchName" "$baseBranch"
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

export NODE_OPTIONS=--use-system-ca
