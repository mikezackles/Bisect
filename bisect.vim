"This script allows the user to quickly navigate to any currently visible
"position by bisection.

"Author: Zachary Michaels

if exists("loaded_bisect")
  finish
endif
let g:loaded_bisect = 1

function! CheckArg(direction)
  "empty for now
endfunction

function! StartBisect(direction)
  let s:running = 1
  let s:top_mark = line('w0') - 1
  let s:bottom_mark = line('w$') + 1
  let s:left_mark = 0
  let s:right_mark = col('$')
  let s:current_col = col('.')
  call setpos("'p", getpos('.')) "Save current position
endfunction

function! BisectIsRunning()
  "We use non-bisect movement as a way of ending a bisect
  "Note that moving away from a location and then coming back
  "will fool this mechanism.
  "Bind the StopBisect function if you wish the ability to manually stop bisects.
  return exists("s:running") && getpos("'p") == getpos('.')
endfunction

function! NarrowBoundaries(direction)
  "Notice that we update the value of s:right_mark every time the line changes, in
  "order to account for varying line length
  if a:direction == "up"
    let s:bottom_mark = line('.')
    let l:new_line = s:top_mark + (s:bottom_mark - s:top_mark)/2
    let l:extend = (s:right_mark == col('$')) ? 1 : 0 "should we extend right_mark or not?
    call cursor(l:new_line, s:current_col)
    if l:extend
      let s:right_mark = col('$')
    endif
  elseif a:direction == "down"
    let s:top_mark = line('.')
    let l:new_line = s:top_mark + (s:bottom_mark - s:top_mark)/2
    let l:extend = (s:right_mark == col('$')) ? 1 : 0 "should we extend right_mark or not?
    call cursor(l:new_line, s:current_col)
    if l:extend
      let s:right_mark = col('$')
    endif
  elseif a:direction == "left" && col('.') > s:left_mark && col('.') != 0 "Corner case because of varying line length
    let s:right_mark = col('.')
    let s:current_col = s:left_mark + (s:right_mark - s:left_mark)/2
    call cursor(line('.'), s:current_col)
  elseif a:direction == "right" && col('.') > s:left_mark && col('.') != col('$') - 1 && col('.') != col('$')
    let s:left_mark = col('.')
    let l:tmp_right = min([s:right_mark, col('$')]) "This column could be shorter
    let s:current_col = s:left_mark + (l:tmp_right - s:left_mark)/2
    call cursor(line('.'), s:current_col)
  endif
endfunction

function! StopBisect()
  let s:running = 0
endfunction

function! Bisect(direction)
  call CheckArg(a:direction)

  if !BisectIsRunning()
    call StartBisect(a:direction)
  endif

  call NarrowBoundaries(a:direction)

  call setpos("'p", getpos('.')) "Save current position
endfunction

function! VisualBisect(direction)
  if getpos(".") == getpos("'<")
    call setpos("'s", getpos("'>")) "'s for start - saves the position where the visual select started
  elseif getpos(".") == getpos("'>")
    call setpos("'s", getpos("'<"))
  elseif line('.') == line("'<")    "for visual line mode
    call setpos("'s", getpos("'>"))
  else
    call setpos("'s", getpos("'<"))
  endif
  call Bisect(a:direction)
endfunction

nmap <silent> <C-j> :call Bisect("down")<CR>
nmap <silent> <C-k> :call Bisect("up")<CR>
nmap <silent> <C-h> :call Bisect("left")<CR>
nmap <silent> <C-l> :call Bisect("right")<CR>

xmap <silent> <C-j> <ESC>:call VisualBisect("down")<CR>:exe "normal! `s".visualmode()."`p"<CR>
xmap <silent> <C-k> <ESC>:call VisualBisect("up")<CR>:exe "normal! `s".visualmode()."`p"<CR>
xmap <silent> <C-h> <ESC>:call VisualBisect("left")<CR>:exe "normal! `s".visualmode()."`p"<CR>
xmap <silent> <C-l> <ESC>:call VisualBisect("right")<CR>:exe "normal! `s".visualmode()."`p"<CR>
