set nocompatible
filetype off
set number
syntax on

set tabstop=4
set shiftwidth=4
set expandtab

set fillchars=vert:\| 

" Exit noob mode
noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Left> <Nop>
noremap <Right> <Nop>

set rtp^=~/.vim/bundle/ctrlp.vim
set rtp+=~/.vim/bundle/Vundle.vim

" Plugin management
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'

" functional stuff
Plugin 'fpob/nette.vim'
Plugin 'jparise/vim-graphql'
Plugin 'leafgarland/typescript-vim'
Plugin 'mattn/vim-lsp-settings'
Plugin 'maxmellon/vim-jsx-pretty'
Plugin 'pangloss/vim-javascript'
Plugin 'prabirshrestha/vim-lsp'
Plugin 'prettier/vim-prettier'
Plugin 'scrooloose/nerdtree'
Plugin 'tpope/vim-fugitive'
Plugin 'ctrlpvim/ctrlp.vim'

" colorschemes and themes
Plugin 'airblade/vim-gitgutter'
Plugin 'morhetz/gruvbox'
Plugin 'ryanoasis/vim-devicons'
Plugin 'AlessandroYorba/Alduin'
Plugin 'danilo-augusto/vim-afterglow'
Plugin 'glepnir/oceanic-material'
Plugin 'rakr/vim-two-firewatch'
Plugin 'jaredgorski/SpaceCamp'

call vundle#end()
filetype plugin indent on

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

let g:ctrlp_custom_ignore = 'DS_Store\|git\|tags\|storage'

set clipboard=unnamed

" colorscheme flags
let g:alduin_Shout_Become_Ethereal = 1
let g:two_firewatch_italics=1

" select random colorscheme of selection
let my_colorschemes = ['alduin', 'gruvbox', 'afterglow', 'oceanic_material', 'two-firewatch']
execute 'colorscheme' my_colorschemes[rand() % (len(my_colorschemes) - 1 ) ]

hi Normal guibg=NONE ctermbg=NONE

" Prettier
let g:prettier#quickfix_auto_focus = 0
let g:prettier#autoformat = 0
autocmd BufWritePre *.js,*.jsx,*.ts,*.tsx,*.css,*.less,*.scss,*.graphql,*.md,*.yaml PrettierAsync

" Ctags
set tags=tags;/
nnoremap <C-]> g<C-]>

" PHP Syntax Folding
set foldmethod=syntax
set foldlevelstart=999
let php_folding=1

" LSP
map ]] :rightbelow vertical :LspDefinition<CR>

" Fix .gql / .graphql files
autocmd BufRead,BufNewFile *.{graphql,gql} setlocal filetype=graphql

" Fix prettier
let g:prettier#config#tab_width = 2 
let g:prettier#config#single_quote = 'true'
let g:prettier#config#semi = 'false'

" Minimalist NERDTree
let NERDTreeMinimalUI=1
