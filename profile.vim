set fileformat=dos

" Oscar Calvo <oscar@calvonet.com> vimrc file
"  To use copy this file to $home\_vimrc and edit

" When started as "evim", evim.vim will already have done these settings.
" Note: evim is "easy vim" -- aka vim in simple mode
if v:progname =~? "evim"
  finish
endif

source $VIMRUNTIME/evim.vim
source <sfile>:p:h/vimfiles/autoload/pathogen.vim

execute pathogen#infect()

" Use Vim settings, rather then Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

"        allow backspacing over everything in insert mode
set expandtab                     "Expand tab to spaces
set backspace=indent,eol,start
set nobackup                      " do not keep a backup file
set backupext=.bak                " sets the backup extension (if you change the previous line)
set nowrap                        " turns off line wrapping (re-enable with :set wrap)
set history=50                    " keep 50 lines of command line history
set ruler                         " show the cursor position all the time
set showcmd                       " display incomplete commands
set incsearch                     " do incremental searching
set ai                            " autoindent
set tabstop=4                     " 4 spaces per tab
set shiftwidth=4                  " ditto
set number                        " show line numbers
set showtabline=4                 "always show the tab line
set visualbell t_vb=              "disable the visualbell error sound
set invlist                       "show hidden caracters
set lcs=tab:->,trail:-            "hidden chars definitions
set encoding=utf-8

" Use the windows clipboard for the unnamed register (default yanks, etc)
set clipboard+=unnamed

" Use powershell as the default shell
set shell=powershell.exe

" The the font to be used in GUI mode
set guifont=Consolas:h11:cANSI,Lucida\ Console,Courier\ New,System

" Set the default color scheme
colo slate

" For Win32 GUI: remove 't' flag from 'guioptions': no tearoff menu entries
let &guioptions = substitute(&guioptions, "t", "", "g")

" Don't use Ex mode, use Q for formatting
map Q gq

" winmanager stuff
"  see http://robotics.eecs.berkeley.edu/~srinath/vim/winmanager-2.0.htm
" let g:winManagerWindowLayout = "FileExplorer"
map <c-w><c-f> :FirstExplorerWindow<cr>
map <c-w><c-b> :BottomExplorerWindow<cr>
map <c-w><c-t> :WMToggle<cr>

" Use the ,x command for reformatting XML files using Tidy.exe
vmap ,x :!tidy -q -i -xml<CR>

" This is an alternative that also works in block mode, but the deleted
" text is lost and it only works for putting the current register.
"vnoremap p "_dp

" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
endif

if has("gui_running")
    set lines=70
    set columns=120
endif

if has("win32") || has("win64")
   set directory=$TMP
else
   set directory=/tmp
end
" Only do this part when compiled with support for autocommands.
if has("autocmd")

  " Enable file type detection.
  " Use the default filetype settings, so that mail gets 'tw' set to 72,
  " 'cindent' is on in C files, etc.
  " Also load indent files, to automatically do language-dependent indenting.
  filetype plugin indent on

  " For all text files set 'textwidth' to 78 characters.
  autocmd FileType text setlocal textwidth=78

  " When editing a file, always jump to the last known cursor position.
  " Don't do it when the position is invalid or when inside an event handler
  " (happens when dropping a file on gvim).
  autocmd BufReadPost *
    \ if line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal g`\"" |
    \ endif

  augroup END

else

  set autoindent    " always set autoindenting on

endif " has("autocmd")

