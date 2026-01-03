# Detect OS and export for subshells/prompts
case "$(uname -s)" in
  Darwin*)    export OS_TYPE="mac";;
  Linux*)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      export OS_TYPE="wsl"
    else
      export OS_TYPE="linux"
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*) export OS_TYPE="windows";;
  *)          export OS_TYPE="unknown";;
esac

# Ensure user bin directories are in PATH
export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:$PATH"

# Initialize Nix (multi-user installation)
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# macOS-specific configuration
if [[ "$OS_TYPE" == "mac" ]]; then
  # Initialize Homebrew
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi

  # Prefer 1Password's SSH agent if present
  if [ -S "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ]; then
    export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  fi
fi

# WSL-specific configuration
if [[ "$OS_TYPE" == "wsl" ]]; then
  # Bridge WSL to Windows 1Password SSH agent via npiperelay
  export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
  if ! ss -a 2>/dev/null | grep -q "$SSH_AUTH_SOCK"; then
    rm -f "$SSH_AUTH_SOCK"
    if command -v npiperelay.exe >/dev/null 2>&1 && command -v socat >/dev/null 2>&1; then
      (setsid socat UNIX-LISTEN:"$SSH_AUTH_SOCK,fork" EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork &) >/dev/null 2>&1
    fi
  fi
fi

# Use bat if available
if command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1; then
  alias cat='bat 2>/dev/null || batcat'
fi

alias sw='f() { git checkout $(git branch | grep $1); };f'

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Skip slow security checks for completions (safe on personal machine)
ZSH_DISABLE_COMPFIX=true

# macOS-specific environment
if [[ "$OS_TYPE" == "mac" ]]; then
  export HOMEBREW_NO_INSECURE_REDIRECT=1
fi

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="catppuccin"  # Disabled - using Starship instead
# CATPPUCCIN_FLAVOR="mocha" # Required! Options: mocha, flappe, macchiato, latte

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

# Base plugins for all platforms
plugins=(git docker)

# Add platform-specific plugins
if [[ "$OS_TYPE" == "mac" ]]; then
  plugins+=(brew macos)
fi

source $ZSH/oh-my-zsh.sh

# Load zsh-syntax-highlighting if available
if [ -f "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# Initialize Starship prompt if available
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# macOS-specific paths and tools
if [[ "$OS_TYPE" == "mac" ]]; then
  export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"
  export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"

  # bun completions (macOS)
  [ -s "/Users/niels/.bun/_bun" ] && source "/Users/niels/.bun/_bun"

  # pipx (macOS)
  export PATH="$PATH:/Users/niels/.local/bin"
fi

# bun (cross-platform)
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Docker color output
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Docker aliases with color output
alias docker-compose='docker compose'
alias dc='docker compose'
alias dcu='docker compose up'
alias dcd='docker compose down'
alias dcb='docker compose build'
alias dcl='docker compose logs'
alias dcp='docker compose ps'

# Docker commands with color output
alias dps='docker ps | docker-color-output'
alias di='docker images | docker-color-output'
alias ds='docker stats | docker-color-output'
alias dcps='docker compose ps | docker-color-output'


# macOS-specific: opam configuration
if [[ "$OS_TYPE" == "mac" ]]; then
  # BEGIN opam configuration
  # This is useful if you're using opam as it adds:
  #   - the correct directories to the PATH
  #   - auto-completion for the opam binary
  # This section can be safely removed at any time if needed.
  [[ ! -r '/Users/niels/.opam/opam-init/init.zsh' ]] || source '/Users/niels/.opam/opam-init/init.zsh' > /dev/null 2> /dev/null
  # END opam configuration

  # Auto-start tmux in Alacritty only (not SSH, not already in tmux)
  if [[ "$TERM" == "alacritty" ]] && [[ -z "$TMUX" ]] && [[ -z "$SSH_CONNECTION" ]]; then
    # Attach to existing session or create new one named 'main'
    tmux attach-session -t main 2>/dev/null || tmux new-session -s main
  fi
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# pnpm
export PNPM_HOME="/Users/niels/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
