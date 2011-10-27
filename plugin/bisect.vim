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
  call s:StopBisect()
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

" This is called before the mode is set, so we have to pass it in explicitly.
function! s:SaveVisualStartPosition(vmode)
  if a:vmode == "V" "Visual line mode
    normal! 0
  endif
  let s:visual_start_position = getpos('.')
endfunction

function! s:GetTruncatedCol()
  let l:rowend = virtcol([s:current_row, '$'])
  if !s:IsVirtualEdit() && s:current_col >= l:rowend && l:rowend != 1
    return l:rowend - 1
  else
    return s:current_col
  endif
endfunction

" Move the cursor to the next location.
" Note that the | command is the only way (that I've found) to move to an
" absolute position in vim.
function! s:MoveCursor()
  exe "normal! ".s:current_row."G"
  exe "normal! ".s:GetTruncatedCol()."|"
endfunction

" Select the appropriate region
function! s:VisualSelect()
  call setpos('.', s:visual_start_position)
  exe "normal! ".visualmode().s:current_row."G".s:GetTruncatedCol()."|"
endfunction

" See if the cursor has moved
" If we aren't in virtualedit mode, the cursor may be shifted because of
" line endings.
function! s:CursorIsAtExpectedLocation()
  return s:invoking_position == s:final_position
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
function! s:StartBisect()
  let s:current_row = line('.')
  let s:current_col = virtcol('.')

  call s:SetStartingTopMark()
  call s:SetStartingBottomMark()
  call s:SetStartingLeftMark()
  call s:SetStartingRightMark()

  let s:final_position = [-1,-1,-1,-1]
  let s:running = 1
endfunction

function! s:BisectIsRunning()
  return exists("s:running") && s:CursorIsAtExpectedLocation()
endfunction

function s:IsVirtualEdit()
  return &virtualedit == "all"
endfunction

" This is the actual bisection algorithm
" TODO - clean this up if possible... Yuck!
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
    if virtcol('.') < virtcol('$') && s:right_mark > virtcol('$') && s:current_col != (virtcol('$')-1) && (!s:IsVirtualEdit() || exists("g:bisect_force_varying_line_endings"))
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

function! s:StopBisect()
  if exists("s:running")
    unlet s:running
  endif
endfunction

function! s:VisualStopBisect()
  call s:StopBisect()
  "Reselect the visual selection
  call setpos('.', s:visual_start_position)
  if s:visual_start_position == getpos("'<")
    exe "normal! ".visualmode()."`>"
  else
    exe "normal! ".visualmode()."`<"
  endif
endfunction

function! s:SaveWindowState()
  return winsaveview()
endfunction

function! s:RestoreWindowState(state)
  let s:final_position = getpos(".")
  let a:state.curswant = s:current_col - 1 " The column that vim 'thinks' we're in if not in virtualedit mode
  call winrestview(a:state)
  call setpos('.', s:final_position)
endfunction

" This is the main function.  It sets up some instance variables for a new
" bisection if there isn't one already running.  On subsequent calls it
" narrows the bisection boundaries and handles moving the cursor and making
" visual selections.
function! s:Bisect(direction, invoking_mode)
  if !s:BisectIsRunning()
    call s:StartBisect()
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
  let s:invoking_position = getpos('.')
  call s:Bisect(a:direction, 'n')
endfunction

function! s:VisualBisect(direction)
  " We know the cursor is at one end of the selection.  This is the *only* way
  " I've been able to find to get the cursor location in this particular
  " scenario.  Note that the column will be wrong in visual line mode, so we
  " just set it to 1 since we don't care about it anyway.  Note that a
  " horizontal bisection in this case will begin a new global bisection.
  if s:visual_start_position == getpos("'<")
    let s:invoking_position = getpos("'>")
  else
    let s:invoking_position = getpos("'<")
  endif
  if visualmode() == "V"
    normal! 0
    " Column is filled with garbage in this case
    let s:invoking_position[2] = 1
  endif
  call s:Bisect(a:direction, visualmode())
endfunction

function! s:InsertBisect(direction)
  call setpos('.', getpos("'^")) " Move the cursor back to where it was in insert mode
  call s:NormalBisect(a:direction)
endfunction

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

  " Insert
  if !hasmapto('<Plug>InsertBisectDown', 'i')
    imap <C-j> <Plug>InsertBisectDown
  endif
  if !hasmapto('<Plug>InsertBisectUp', 'i')
    imap <C-k> <Plug>InsertBisectUp
  endif
  inoremap <unique> <script> <Plug>InsertBisectDown <SID>InsertBisectDown
  inoremap <unique> <script> <Plug>InsertBisectUp <SID>InsertBisectUp
  inoremap <silent> <SID>InsertBisectDown <ESC>:call <SID>InsertBisect("down")<CR>i
  inoremap <silent> <SID>InsertBisectUp <ESC>:call <SID>InsertBisect("up")<CR>i
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

  " Insert
  if !hasmapto('<Plug>BisectLeft', 'i')
    imap <C-h> <Plug>InsertBisectLeft
  endif
  if !hasmapto('<Plug>BisectRight', 'i')
    imap <C-l> <Plug>InsertBisectRight
  endif
  inoremap <unique> <script> <Plug>InsertBisectLeft <SID>InsertBisectLeft
  inoremap <unique> <script> <Plug>InsertBisectRight <SID>InsertBisectRight
  inoremap <silent> <SID>InsertBisectLeft <ESC>:call <SID>InsertBisect("left")<CR>i
  inoremap <silent> <SID>InsertBisectRight <ESC>:call <SID>InsertBisect("right")<CR>i
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
nnoremap <silent> <SID>StopBisect :call <SID>StopBisect()<CR>
" Visual
if !hasmapto('<Plug>VisualStopBisect', 'v')
  xmap <C-i> <Plug>VisualStopBisect
endif
xnoremap <unique> <script> <Plug>VisualStopBisect <SID>VisualStopBisect
xnoremap <silent> <SID>VisualStopBisect <ESC>:call <SID>VisualStopBisect()<CR>

" Toggle virtualedit=all
noremap <unique> <script> <Plug>BisectToggleVirtualEdit <SID>ToggleVirtualEdit
noremap <silent> <SID>ToggleVirtualEdit <ESC>:call <SID>ToggleVirtualEdit()<CR>

" Toggle bisect_force_varying_line_endings
noremap <unique> <script> <Plug>BisectToggleVaryingLineEndings <SID>ToggleVaryingLineEndings
noremap <silent> <SID>ToggleVaryingLineEndings <ESC>:call <SID>ToggleVaryingLineEndings()<CR>

nnoremap <silent> v :call <SID>SaveVisualStartPosition('v')<CR>v
nnoremap <silent> V :call <SID>SaveVisualStartPosition('V')<CR>V
nnoremap <silent> <C-v> :call <SID>SaveVisualStartPosition('C-v')<CR><C-v>
