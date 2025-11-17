export ZSH="/Users/nielsmokkenstorm/.oh-my-zsh"

alias ngrok='/Applications/ngrok'
alias cat='bat'

export PYTHONPATH=$(brew --prefix)/lib/python3.13/site-packages

pw() {
  branch=${1:-'origin/main'}
  git add -p && git commit -m 'wip' && git fetch && git rebase $branch && git push --force-with-lease
}

JSII_SILENCE_WARNING_UNTESTED_NODE_VERSION=1

ZSH_THEME="robbyrussell"

export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh"
[ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm"

plugins=(git)

source $ZSH/oh-my-zsh.sh

export PATH="$(brew --prefix)/opt/ruby/bin:$(brew --prefix)/lib/ruby/gems/3.0.0/bin:$PATH"
export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"
export PATH="$(brew --prefix)/opt/postgresql@15/bin:$PATH"
