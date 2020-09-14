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

" Exit noob mode
noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Left> <Nop>
noremap <Right> <Nop>

" Plugin management
call vundle#begin()

Plugin 'VundleVim/Vundle.vim'
Plugin 'beigebrucewayne/Turtles'
Plugin 'pangloss/vim-javascript'
Plugin 'airblade/vim-gitgutter'
Plugin 'prettier/vim-prettier'
Plugin 'leafgarland/typescript-vim'
Plugin 'maxmellon/vim-jsx-pretty'
Plugin 'ryanoasis/vim-devicons'
Plugin 'scrooloose/nerdtree'
Plugin 'morhetz/gruvbox'
Plugin 'fpob/nette.vim'

call vundle#end()
filetype plugin indent on

execute pathogen#infect()

let g:jsx_ext_required = 0

let mapleader = " "

map <leader><leader> :CtrlP<CR>
map <leader>m :NERDTreeToggle<CR>
:inoremap <lt>/ </<C-x><C-o><Esc>==gi

" Disable annoying beeping
set noerrorbells
set vb t_vb=

set path+=**

set wildmenu

let g:ctrlp_custom_ignore = 'node_modules\|DS_Store\|git\|tags\|storage'

set guifont=Lotion

set clipboard=unnamed

" colorscheme turtles
colorscheme gruvbox

hi Normal guibg=NONE ctermbg=NONE

highlight clear LineNr
highlight clear VertSplit
highlight clear StatusLineNC

" Prettier
let g:prettier#quickfix_auto_focus = 0
let g:prettier#autoformat = 0
autocmd BufWritePre *.js,*.jsx,*.mjs,*.ts,*.tsx,*.css,*.less,*.scss,*.graphql,*.md,*.vue,*.yaml PrettierAsync

" Ctags
set tags=tags;/
nnoremap <C-]> g<C-]>

" PHP Syntax Folding
let php_folding=1
set foldmethod=syntax
