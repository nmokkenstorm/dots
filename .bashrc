# OS-aware .bashrc for both Git Bash (Windows) and WSL/Linux
# Part of dotfiles managed at ~/Developer/dots

# Detect OS
case "$(uname -s)" in
  Darwin*)    OS_TYPE="mac";;
  Linux*)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      OS_TYPE="wsl"
    else
      OS_TYPE="linux"
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*) OS_TYPE="gitbash";;
  *)          OS_TYPE="unknown";;
esac

# Export OS_TYPE for prompts
export OS_TYPE

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History settings
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL=ignoredups:erasedups

# Append to history file, don't overwrite
if [ "$OS_TYPE" != "gitbash" ]; then
  shopt -s histappend
fi

# Check window size after each command
if [ "$OS_TYPE" != "gitbash" ]; then
  shopt -s checkwinsize
fi

# Git aliases (all platforms)
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'

# Git tree alias
git config --global alias.tree "log --oneline --decorate --all --graph"

# Convenient aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

# cd up shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Platform-specific configuration
if [[ "$OS_TYPE" == "gitbash" ]]; then
  # Git Bash / Windows specific
  alias wsl='wsl.exe'
  echo "Git Bash environment loaded. For full dev setup, use: wsl"

elif [[ "$OS_TYPE" == "wsl" ]] || [[ "$OS_TYPE" == "linux" ]]; then
  # WSL / Linux specific

  # Enable color support
  if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
  fi

  # Alert alias for long running commands
  alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

  # Source bash aliases if exists
  if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
  fi

  # Enable programmable completion
  if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
      . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
      . /etc/bash_completion
    fi
  fi

  # SSH agent bridge (WSL specific)
  if [ -f "$HOME/.agent-bridge.sh" ]; then
    source "$HOME/.agent-bridge.sh"
  fi

  # Neovim alias if installed
  if [ -x /opt/nvim-linux-x86_64/bin/nvim ]; then
    alias nvim="/opt/nvim-linux-x86_64/bin/nvim"
    export PATH="/opt/nvim-linux-x86_64/bin:$PATH"
  fi
fi

# Add user bin to PATH (all platforms)
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# Better ls colors (Git Bash)
if [[ "$OS_TYPE" == "gitbash" ]] && command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b)"
fi

# Initialize Starship prompt if available
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi
