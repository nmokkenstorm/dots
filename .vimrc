set nocompatible
filetype off
set number
syntax on

set tabstop=4
set shiftwidth=4
set expandtab

set fillchars=vert:\| 
set rtp^=~/.vim/bundle/ctrlp.vim
set rtp+=~/.vim/bundle/Vundle.vim

call vundle#begin()

Plugin 'VundleVim/Vundle.vim'
Plugin 'beigebrucewayne/Turtles'
Plugin 'pangloss/vim-javascript'
Plugin 'airblade/vim-gitgutter'
Plugin 'prettier/vim-prettier'
Plugin 'leafgarland/typescript-vim'
Plugin 'maxmellon/vim-jsx-pretty'
Plugin 'ryanoasis/vim-devicons'
Plugin 'morhetz/gruvbox'

call vundle#end()
filetype plugin indent on

execute pathogen#infect()

let g:jsx_ext_required = 0

let mapleader = " "

map <leader><leader> :CtrlP<CR>
map <leader>m :NERDTreeToggle<CR>
map <leader>g :Gstatus<CR>
:inoremap <lt>/ </<C-x><C-o><Esc>==gi

" Disable annoying beeping
set noerrorbells
set vb t_vb=

set path+=**

set wildmenu

let g:ctrlp_custom_ignore = 'node_modules\|DS_Store\|git\|tags\|storage|\vendor'

set guifont=Lotion

set clipboard=unnamed

" colorscheme turtles
colorscheme gruvbox

hi Normal guibg=NONE ctermbg=NONE
highlight clear LineNr
highlight clear VertSplit
highlight clear StatusLineNC

let g:prettier#quickfix_auto_focus = 0
let g:prettier#autoformat = 0
autocmd BufWritePre *.js,*.jsx,*.mjs,*.ts,*.tsx,*.css,*.less,*.scss,*.json,*.graphql,*.md,*.vue,*.yaml,*.html PrettierAsync
