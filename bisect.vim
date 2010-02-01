"This script allows the user to quickly navigate to any currently visible
"position by bisection.

"Author: Zachary Michaels

let s:current_pos_ud = [ -1, -1 ] "Invalid position
let s:current_pos_lr = [ -1, -1 ]

function! SplitHeight(direction)
  if !exists("s:top_mark") || s:current_pos_ud != [ line('.'), col('.') ]
    let s:top_mark = line('w0') - 1
    let s:bottom_mark = line('w$') + 1
    let s:current_pos = [ line("."), col(".") ]
  endif

  if a:direction == "up"
    let s:bottom_mark = line('.')
  elseif a:direction == "down"
    let s:top_mark = line('.')
  else
    echo "SplitHeight should specify either \"up\" or \"down\" as an argument."
  endif

  let l:increment = (s:bottom_mark - s:top_mark)/2
  call cursor(s:bottom_mark - l:increment, col('.'))
  let s:current_pos_ud = [ line('.'), col('.') ]
endfunction

function! SplitWidth(direction)
  if !exists("s:left_mark") || s:current_pos_lr != [ line('.'), col('.') ]
    let s:left_mark = 0
    let s:right_mark = col('$')
    let s:current_pos_lr = [ line("."), col(".") ]
  endif

  if a:direction == "left"
    let s:right_mark = col('.')
  elseif a:direction == "right"
    let s:left_mark = col('.')
  else
    echo "SplitWidth should specify either \"left\" or \"right\" as an argument."
  endif

  let l:increment = (s:right_mark - s:left_mark)/2
  call cursor(line('.'), s:right_mark - l:increment)
  let s:current_pos_lr = [ line('.'), col('.') ]
endfunction

nmap <silent> <C-j> :call SplitHeight("down")<CR>
nmap <silent> <C-k> :call SplitHeight("up")<CR>
nmap <silent> <C-h> :call SplitWidth("left")<CR>
nmap <silent> <C-l> :call SplitWidth("right")<CR>
