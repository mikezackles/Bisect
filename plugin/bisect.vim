" Vim global plugin which allows navigation via bisection
" Last Change: 2010 Feb 3
" Author:      Zachary Michaels |mikezackles
"                               |    @t
"                               |gmail.com
" License:     This file is released under the Vim license.
" Version:     0.0.1

" GetLatestVimScripts: 2960 1 :AutoInstall: bisect

if exists("loaded_bisect")
  finish
endif
let g:loaded_bisect = 1

function! s:StartBisect(direction)
  let s:running = 1
  let s:top_mark = line('w0') - 1
  let s:bottom_mark = line('w$') + 1
  let s:left_mark = 0
  let s:right_mark = col('$')
  let s:current_col = col('.')
  call setpos("'p", getpos('.')) "Save current position
endfunction

function! s:BisectIsRunning()
  "We use non-bisect movement as a way of ending a bisect
  "Note that moving away from a location and then coming back
  "will fool this mechanism.
  "Bind the StopBisect function if you wish the ability to manually stop bisects.
  return exists("s:running") && s:running && getpos("'p") == getpos('.')
endfunction

function! s:NarrowBoundaries(direction)
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

function! s:StopBisect()
  let s:running = 0
endfunction

function! s:Bisect(direction)
  if !s:BisectIsRunning()
    call s:StartBisect(a:direction)
  endif

  call s:NarrowBoundaries(a:direction)

  call setpos("'p", getpos('.')) "Save current position
endfunction

function! s:VisualBisect(direction)
  if getpos(".") == getpos("'<")
    call setpos("'s", getpos("'>")) "'s for start - saves the position where the visual select started
  elseif getpos(".") == getpos("'>")
    call setpos("'s", getpos("'<"))
  elseif line('.') == line("'<")    "for visual line mode
    call setpos("'s", getpos("'>"))
  else
    call setpos("'s", getpos("'<"))
  endif
  call s:Bisect(a:direction)
endfunction

" Normal mode mappings
if !hasmapto('<Plug>BisectDown', 'n')
  nmap <C-j> <Plug>BisectDown
endif
if !hasmapto('<Plug>BisectUp', 'n')
  nmap <C-k> <Plug>BisectUp
endif
if !hasmapto('<Plug>BisectLeft', 'n')
  nmap <C-h> <Plug>BisectLeft
endif
if !hasmapto('<Plug>BisectRight', 'n')
  nmap <C-l> <Plug>BisectRight
endif
if !hasmapto('<Plug>StopBisect', 'n')
  nmap <C-n> <Plug>StopBisect
endif
nnoremap <unique> <script> <Plug>BisectDown <SID>BisectDown
nnoremap <unique> <script> <Plug>BisectUp <SID>BisectUp
nnoremap <unique> <script> <Plug>BisectLeft <SID>BisectLeft
nnoremap <unique> <script> <Plug>BisectRight <SID>BisectRight
nnoremap <unique> <script> <Plug>StopBisect <SID>StopBisect
nnoremap <silent> <SID>BisectDown :call <SID>Bisect("down")<CR>
nnoremap <silent> <SID>BisectUp :call <SID>Bisect("up")<CR>
nnoremap <silent> <SID>BisectLeft :call <SID>Bisect("left")<CR>
nnoremap <silent> <SID>BisectRight :call <SID>Bisect("right")<CR>
nnoremap <silent> <SID>StopBisect :call <SID>StopBisect()<CR>

" Visual mode mappings
if !hasmapto('<Plug>VisualBisectDown', 'v')
  xmap <C-j> <Plug>VisualBisectDown
endif
if !hasmapto('<Plug>VisualBisectUp', 'v')
  xmap <C-k> <Plug>VisualBisectUp
endif
if !hasmapto('<Plug>VisualBisectLeft', 'v')
  xmap <C-h> <Plug>VisualBisectLeft
endif
if !hasmapto('<Plug>VisualBisectRight', 'v')
  xmap <C-l> <Plug>VisualBisectRight
endif
if !hasmapto('<Plug>VisualStopBisect', 'v')
  xmap <C-n> <Plug>VisualStopBisect
endif
xnoremap <unique> <script> <Plug>VisualBisectDown <SID>VisualBisectDown
xnoremap <unique> <script> <Plug>VisualBisectUp <SID>VisualBisectUp
xnoremap <unique> <script> <Plug>VisualBisectLeft <SID>VisualBisectLeft
xnoremap <unique> <script> <Plug>VisualBisectRight <SID>VisualBisectRight
xnoremap <unique> <script> <Plug>VisualStopBisect <SID>VisualStopBisect
xnoremap <silent> <SID>VisualBisectDown <ESC>:call <SID>VisualBisect("down")<CR>:exe "normal! `s".visualmode()."`p"<CR>
xnoremap <silent> <SID>VisualBisectUp <ESC>:call <SID>VisualBisect("up")<CR>:exe "normal! `s".visualmode()."`p"<CR>
xnoremap <silent> <SID>VisualBisectLeft <ESC>:call <SID>VisualBisect("left")<CR>:exe "normal! `s".visualmode()."`p"<CR>
xnoremap <silent> <SID>VisualBisectRight <ESC>:call <SID>VisualBisect("right")<CR>:exe "normal! `s".visualmode()."`p"<CR>
xnoremap <silent> <SID>VisualStopBisect :call <SID>StopBisect()<CR>gv
