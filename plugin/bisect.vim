" Vim global plugin which allows navigation via bisection
" Last Change: 2011 Oct 24
" Author:      Zachary Michaels |mikezackles
"                               |    @t
"                               |gmail.com
" License:     This file is released under the Vim license.
" Version:     1.0.1

if exists("loaded_bisect")
  finish
endif
let g:loaded_bisect = 1
set virtualedit=all " Allows us to move the cursor anywhere on the visible screen

" Save a timestamp for this invocation of visual mode.
function! s:SaveVisualStartPosition()
  let s:invoke_visual_timestamp = localtime()
  call setpos("'s", getpos('.'))
endfunction

" Actually move the cursor to the next location
function! s:MoveCursor()
  exe "normal! ".s:current_row."G"
  exe "normal! ".s:current_col."|"
endfunction

" See if the cursor has moved in normal mode
function! s:CursorHasNotMoved()
  return s:current_row == line('.') && s:current_col == virtcol('.')
endfunction

" Limit bisections to the longest line on screen.
function! s:GetRightMark()
  let l:max_width = winwidth(0)+virtcol('.')-wincol()+1
  let l:max_so_far = 0
  for linenum in range(line('w0'), line('w$'))
    let l:line_length = virtcol([linenum,'$'])
    if l:line_length > l:max_width
      return l:max_width
    elseif l:line_length > l:max_so_far
      let l:max_so_far = l:line_length
    endif
  endfor
  return l:max_so_far
endfunction

function! s:SetInitialMarks()
  let s:top_mark = line('w0') - 1
  let s:bottom_mark = line('w$') + 1
  let s:left_mark = winsaveview()['leftcol']
  let s:right_mark = s:GetRightMark()
endfunction

function! s:StartBisect(invoking_mode)
  call s:SetInitialMarks()

  if a:invoking_mode == 'n'
    " Normal mode
    let s:current_row = line('.')
    let s:current_col = virtcol('.')
    let s:running = 1
  else
    " Visual modes
    let s:current_row = line("'s")
    let s:current_col = virtcol("'s")
    let s:current_bisection_timestamp = s:invoke_visual_timestamp
  endif
endfunction

function! s:BisectIsRunning(invoking_mode)
  if a:invoking_mode == 'n'
    " Normal mode
    return exists("s:running") && s:running && s:CursorHasNotMoved()
  else
    " Visual modes
    return exists("s:current_bisection_timestamp") && s:current_bisection_timestamp == s:invoke_visual_timestamp
  endif
endfunction

function! s:NarrowBoundaries(direction)
  if a:direction == "up"
    let s:bottom_mark = s:current_row
    let s:current_row = s:top_mark + float2nr(ceil((s:bottom_mark - s:top_mark)/2.0))
  elseif a:direction == "down"
    let s:top_mark = s:current_row
    let s:current_row = s:top_mark + float2nr(floor((s:bottom_mark - s:top_mark)/2.0))
  elseif a:direction == "left"
    let s:right_mark = s:current_col
    let s:current_col = s:left_mark + float2nr(ceil((s:right_mark - s:left_mark)/2.0))
  elseif a:direction == "right"
    let s:left_mark = s:current_col
    let s:current_col = s:left_mark + float2nr(floor((s:right_mark - s:left_mark)/2.0))
  endif
endfunction

" Cancels a bisection, more or less.  In visual mode it allows the user to
" start from their last bisect location.
function! s:StopBisect(invoking_mode)
  if a:invoking_mode == 'n'
    let s:running = 0
  else
    call s:SetInitialMarks()
  endif
endfunction

" This is the main function.  It sets up some instance variables for a new
" bisection if there isn't one already running.  On subsequent calls it
" narrows the bisection boundaries and handles moving the cursor and making
" visual selections.
function! s:Bisect(direction, invoking_mode)
  if !s:BisectIsRunning(a:invoking_mode)
    call s:StartBisect(a:invoking_mode)
  endif

  call s:NarrowBoundaries(a:direction)
  let l:view = winsaveview()
  if a:invoking_mode == 'n'
    call s:MoveCursor()
  else
    call s:VisualSelect()
  endif
  call setpos("'t", getpos("."))
  call winrestview(l:view)
  call setpos('.', getpos("'t"))
endfunction

" Wrappers for s:Bisect
function! s:NormalBisect(direction)
  call s:Bisect(a:direction, 'n')
endfunction

function! s:VisualBisect(direction)
  call s:Bisect(a:direction, visualmode())
endfunction

" Select the appropriate region
function! s:VisualSelect()
  exe "normal! `s".visualmode().s:current_row."G".s:current_col."|"
endfunction

function! s:PageDown()
  normal! Lzz
endfunction

function! s:PageUp()
  normal! Hzz
endfunction

function! s:PageLeft()
  let l:view = winsaveview()
  exe "normal! ".(s:left_mark+1)."|"
  call setpos("'t", getpos("."))
  call winrestview(l:view)
  call setpos('.', getpos("'t"))
endfunction

function! s:PageRight()
  let l:view = winsaveview()
  exe "normal! ".(winwidth(0)+s:left_mark-1i)."|"
  call setpos("'t", getpos("."))
  call winrestview(l:view)
  call setpos('.', getpos("'t"))
endfunction

" User can either remap these or disable them entirely
" Vertical bisection
if !exists("bisect_disable_vertical")
  " Normal
  if !hasmapto('<Plug>BisectDown', 'n')
    nmap <C-j> <Plug>BisectDown
  endif
  if !hasmapto('<Plug>BisectUp', 'n')
    nmap <C-k> <Plug>BisectUp
  endif
  nnoremap <unique> <script> <Plug>BisectDown <SID>BisectDown
  nnoremap <unique> <script> <Plug>BisectUp <SID>BisectUp
  nnoremap <silent> <SID>BisectDown :call <SID>NormalBisect("down")<CR>
  nnoremap <silent> <SID>BisectUp :call <SID>NormalBisect("up")<CR>

  " Visual
  if !hasmapto('<Plug>VisualBisectDown', 'v')
    xmap <C-j> <Plug>VisualBisectDown
  endif
  if !hasmapto('<Plug>VisualBisectUp', 'v')
    xmap <C-k> <Plug>VisualBisectUp
  endif
  xnoremap <unique> <script> <Plug>VisualBisectDown <SID>VisualBisectDown
  xnoremap <unique> <script> <Plug>VisualBisectUp <SID>VisualBisectUp
  xnoremap <silent> <SID>VisualBisectDown <ESC>:call <SID>VisualBisect("down")<CR>
  xnoremap <silent> <SID>VisualBisectUp <ESC>:call <SID>VisualBisect("up")<CR>
endif

" Horizontal bisection
if !exists("bisect_disable_horizontal")
  " Normal
  if !hasmapto('<Plug>BisectLeft', 'n')
    nmap <C-h> <Plug>BisectLeft
  endif
  if !hasmapto('<Plug>BisectRight', 'n')
    nmap <C-l> <Plug>BisectRight
  endif
  nnoremap <unique> <script> <Plug>BisectLeft <SID>BisectLeft
  nnoremap <unique> <script> <Plug>BisectRight <SID>BisectRight
  nnoremap <silent> <SID>BisectLeft :call <SID>NormalBisect("left")<CR>
  nnoremap <silent> <SID>BisectRight :call <SID>NormalBisect("right")<CR>

  " Visual
  if !hasmapto('<Plug>VisualBisectLeft', 'v')
    xmap <C-h> <Plug>VisualBisectLeft
  endif
  if !hasmapto('<Plug>VisualBisectRight', 'v')
    xmap <C-l> <Plug>VisualBisectRight
  endif
  xnoremap <unique> <script> <Plug>VisualBisectLeft <SID>VisualBisectLeft
  xnoremap <unique> <script> <Plug>VisualBisectRight <SID>VisualBisectRight
  xnoremap <silent> <SID>VisualBisectLeft <ESC>:call <SID>VisualBisect("left")<CR>
  xnoremap <silent> <SID>VisualBisectRight <ESC>:call <SID>VisualBisect("right")<CR>
endif

" Paging
if !exists("bisect_disable_paging")
  if !hasmapto('<Plug>BisectPageDown', 'n')
    map J <Plug>BisectPageDown
  endif
  if !hasmapto('<Plug>BisectPageUp', 'n')
    map K <Plug>BisectPageUp
  endif
  if !hasmapto('<Plug>BisectPageLeft', 'n')
    map H <Plug>BisectPageLeft
  endif
  if !hasmapto('<Plug>BisectPageRight', 'n')
    map L <Plug>BisectPageRight
  endif
  noremap <unique> <script> <Plug>BisectPageDown  <SID>BisectPageDown
  noremap <unique> <script> <Plug>BisectPageUp    <SID>BisectPageUp
  noremap <unique> <script> <Plug>BisectPageLeft  <SID>BisectPageLeft
  noremap <unique> <script> <Plug>BisectPageRight <SID>BisectPageRight
  noremap <silent> <SID>BisectPageDown  <ESC>:call <SID>PageDown()<CR>
  noremap <silent> <SID>BisectPageUp    <ESC>:call <SID>PageUp()<CR>
  noremap <silent> <SID>BisectPageLeft  <ESC>:call <SID>PageLeft()<CR>
  noremap <silent> <SID>BisectPageRight <ESC>:call <SID>PageRight()<CR>
endif

" Stop Bisection
" Normal
if !hasmapto('<Plug>StopBisect', 'n')
  nmap <C-i> <Plug>StopBisect
endif
nnoremap <unique> <script> <Plug>StopBisect <SID>StopBisect
nnoremap <silent> <SID>StopBisect :call <SID>StopBisect('n')<CR>

" Visual
if !hasmapto('<Plug>VisualStopBisect', 'v')
  xmap <C-i> <Plug>VisualStopBisect
endif
xnoremap <unique> <script> <Plug>VisualStopBisect <SID>VisualStopBisect
xnoremap <silent> <SID>VisualStopBisect <ESC>:call <SID>StopBisect(visualmode())<CR>gv

" We add timestamps to invoking visual modes here so that each visual
" selection can correspond to a single bisection (or group of bisections if
" StopBisect is called).
nnoremap <silent> v :call <SID>SaveVisualStartPosition()<CR>v
nnoremap <silent> V :call <SID>SaveVisualStartPosition()<CR>V
nnoremap <silent> <C-v> :call <SID>SaveVisualStartPosition()<CR><C-v>
