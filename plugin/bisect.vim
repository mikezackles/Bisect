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

function! s:ToggleVirtualEdit()
  call s:StopBisect('n')
  if &virtualedit != "all"
    set virtualedit=all
  else
    set virtualedit=
  endif
endfunction

function! s:ToggleVaryingLineEndings()
  if exists("g:bisect_force_varying_line_endings")
    unlet g:bisect_force_varying_line_endings
  else
    let g:bisect_force_varying_line_endings = "true"
  endif
endfunction

" Save a timestamp for this invocation of visual mode.
function! s:SaveVisualStartPosition()
  let s:invoke_visual_timestamp = localtime()
  call setpos("'s", getpos('.'))
endfunction

function! s:GetColFromVirtCol(col)
  if !s:IsVirtualEdit() && a:col >= virtcol('$') && virtcol('$') != 1
    return virtcol('$') - 1
  else
    return a:col
  endif
endfunction

" Move the cursor to the next location.
" Note that the | command is the only way (that I've found) to move to an
" absolute position in vim.
function! s:MoveCursor()
  exe "normal! ".s:current_row."G"
  exe "normal! ".s:GetColFromVirtCol(s:current_col)."|"
endfunction

" Select the appropriate region
function! s:VisualSelect()
  exe "normal! `s".visualmode().s:current_row."G".s:GetColFromVirtCol(s:current_col)."|"
endfunction

" See if the cursor has moved
" If we aren't in virtualedit mode, the cursor may be shifted because of
" line endings.  For whatever reason, curswant is off by one from the normal
" cursor representation.
function! s:CursorIsAtExpectedLocation()
  let l:aview = winsaveview()
  let l:row_passes = s:current_row == l:aview.lnum
  let l:column_passes = (s:current_col - 1) == l:aview.curswant || s:current_col == virtcol('.')
  return l:row_passes && l:column_passes
endfunction

" Limit bisections to the longest line on screen.
function! s:MaxLineLength()
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

function! s:SetStartingTopMark()
  let s:top_mark = line('w0') - 1
endfunction

function! s:SetStartingBottomMark()
  let s:bottom_mark = line('w$') + 1
endfunction

function! s:SetStartingLeftMark()
  let s:left_mark = winsaveview().leftcol
endfunction

function! s:SetStartingRightMark()
  let s:right_mark = s:MaxLineLength()
endfunction

" This function determines the initial parameters of a bisection.  There is a
" special exception made for the case that BisectRight is called to start a
" bisection.  In this case, we make the guess that the user is trying to get
" to a location on the same line, so we avoid jumping past the end of the
" line.
function! s:StartBisect(direction, invoking_mode)
  let s:current_row = line('.')
  let s:current_col = virtcol('.')

  call s:SetStartingTopMark()
  call s:SetStartingBottomMark()
  call s:SetStartingLeftMark()
  call s:SetStartingRightMark()

  if a:invoking_mode == 'n'
    " Normal mode
    let s:running = 1
  else
    " Visual modes
    let s:current_bisection_timestamp = s:invoke_visual_timestamp
  endif
endfunction

function! s:BisectIsRunning(invoking_mode)
  if a:invoking_mode == 'n'
    " Normal mode
    return exists("s:running") && s:running && s:CursorIsAtExpectedLocation()
  else
    " Visual modes
    return exists("s:current_bisection_timestamp") && s:current_bisection_timestamp == s:invoke_visual_timestamp
  endif
endfunction

function s:IsVirtualEdit()
  return &virtualedit == "all"
endfunction

function s:NarrowBoundaries(direction)
  if a:direction == "up"
    let s:bottom_mark = s:current_row
    let s:current_row = s:top_mark + float2nr(ceil((s:bottom_mark - s:top_mark)/2.0))
    if s:current_row == s:bottom_mark && !exists("g:bisect_force_strict_bisection")
      call s:SetStartingTopMark()
      if s:current_row != s:top_mark+1
        call s:NarrowBoundaries(a:direction)
      endif
    endif
  elseif a:direction == "down"
    let s:top_mark = s:current_row
    let s:current_row = s:top_mark + float2nr(floor((s:bottom_mark - s:top_mark)/2.0))
    if s:current_row == s:top_mark && !exists("g:bisect_force_strict_bisection")
      call s:SetStartingBottomMark()
      if s:current_row != s:bottom_mark-1
        call s:NarrowBoundaries(a:direction)
      endif
    endif
  elseif a:direction == "left"
    let s:right_mark = s:current_col
    if virtcol('.') < virtcol('$') && (!s:IsVirtualEdit() || exists("g:bisect_force_varying_line_endings"))
      let s:current_col = s:left_mark + float2nr(ceil((virtcol('.') - s:left_mark)/2.0))
    else
      let s:current_col = s:left_mark + float2nr(ceil((s:right_mark - s:left_mark)/2.0))
    endif
    if s:current_col == s:right_mark && !exists("g:bisect_force_strict_bisection")
      call s:SetStartingLeftMark()
      if s:current_col != s:left_mark+1
        call s:NarrowBoundaries(a:direction)
      endif
    endif
  elseif a:direction == "right"
    let s:left_mark = s:current_col
    if virtcol('.') < virtcol('$') && s:right_mark > virtcol('$') && (!s:IsVirtualEdit() || exists("g:bisect_force_varying_line_endings"))
      let l:varying_line_endings = 1
      let s:current_col = s:left_mark + float2nr(floor((virtcol('$') - s:left_mark)/2.0))
    else
      let l:varying_line_endings = 0
      let s:current_col = s:left_mark + float2nr(floor((s:right_mark - s:left_mark)/2.0))
    endif
    if s:current_col == s:left_mark && !exists("g:bisect_force_strict_bisection")
      call s:SetStartingRightMark()
      if l:varying_line_endings
        let l:tmp_right_mark = virtcol('$')
      else
        let l:tmp_right_mark = s:right_mark
      endif
      if s:current_col != l:tmp_right_mark-1
        call s:NarrowBoundaries(a:direction)
      endif
    endif
  endif
endfunction

" Cancels a bisection, more or less.  In visual mode it allows the user to
" start from their last bisect location.
function! s:StopBisect(invoking_mode)
  if a:invoking_mode == 'n'
    let s:running = 0
  else
    let s:current_bisection_timestamp = -1
  endif
endfunction

function! s:SaveWindowState()
  return winsaveview()
endfunction

function! s:RestoreWindowState(state)
  call setpos("'t", getpos("."))
  let a:state.curswant = s:current_col - 1 " The column that vim 'thinks' we're in if not in virtualedit mode
  call winrestview(a:state)
  call setpos('.', getpos("'t"))
endfunction

" This is the main function.  It sets up some instance variables for a new
" bisection if there isn't one already running.  On subsequent calls it
" narrows the bisection boundaries and handles moving the cursor and making
" visual selections.
function! s:Bisect(direction, invoking_mode)
  if !s:BisectIsRunning(a:invoking_mode)
    call s:StartBisect(a:direction, a:invoking_mode)
  endif

  call s:NarrowBoundaries(a:direction)
  let l:state = s:SaveWindowState()
  if a:invoking_mode == 'n'
    call s:MoveCursor()
  else
    call s:VisualSelect()
  endif
  call s:RestoreWindowState(l:state)
endfunction

" Wrappers for s:Bisect
function! s:NormalBisect(direction)
  call s:Bisect(a:direction, 'n')
endfunction

function! s:VisualBisect(direction)
  call s:Bisect(a:direction, visualmode())
endfunction

" TODO - make this behave like the other paging functions at the bottom of a
" buffer
function! s:PageDown()
  let l:bottomline = winsaveview().topline+winheight(0)
  let l:col = virtcol('.')
  exe "normal! ".l:bottomline."G"
  exe "normal! ".l:col."|"
  normal! zz
endfunction

function! s:PageUp()
  let l:topline = winsaveview().topline-1
  if l:topline > 0
    let l:col = virtcol('.')
    exe "normal! ".l:topline."G"
    exe "normal! ".l:col."|"
    normal! zz
  endif
endfunction

function! s:PageLeft()
  let l:aview = winsaveview()
  if l:aview.leftcol != 0
    exe "normal! ".(l:aview.leftcol)."|"
  endif
endfunction

" TODO - Prevent going off the edge in virtualedit mode
function! s:PageRight()
  let l:width = winwidth(0)+virtcol('.')-wincol()+1
  let l:aview = winsaveview()
  let l:target_col = l:aview.leftcol + l:width
  exe "normal! ".(l:target_col)."|"
  if !s:IsVirtualEdit() && virtcol('.') < l:target_col
    call winrestview(l:aview)
  endif
endfunction

" User can either remap these or disable them entirely
" Vertical bisection
if !exists("g:bisect_disable_vertical")
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
if !exists("g:bisect_disable_horizontal")
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
if !exists("g:bisect_disable_paging")
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

" Toggle virtualedit=all
noremap <unique> <script> <Plug>BisectToggleVirtualEdit <SID>ToggleVirtualEdit
noremap <silent> <SID>ToggleVirtualEdit <ESC>:call <SID>ToggleVirtualEdit()<CR>

" Toggle bisect_force_varying_line_endings
noremap <unique> <script> <Plug>BisectToggleVaryingLineEndings <SID>ToggleVaryingLineEndings
noremap <silent> <SID>ToggleVaryingLineEndings <ESC>:call <SID>ToggleVaryingLineEndings()<CR>

" We add timestamps to invoking visual modes here so that each visual
" selection can correspond to a single bisection (or group of bisections if
" StopBisect is called).
nnoremap <silent> v :call <SID>SaveVisualStartPosition()<CR>v
nnoremap <silent> V :call <SID>SaveVisualStartPosition()<CR>V
nnoremap <silent> <C-v> :call <SID>SaveVisualStartPosition()<CR><C-v>
