"Vim global plugin which allows navigation via bisection
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

function! s:Do(vmode, expr)
  let str = a:vmode.a:expr
  if (str != "")
    exe "normal! ".str
  endif
endfunction

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

function! s:MoveScreenCursorStr( line, col )
  return s:MoveToScreenLineStr(a:line).s:MoveToColStr(a:col)
endfunction

function! s:MoveFileCursorStr( line, col )
  return s:MoveToFileLineStr(a:line).s:MoveToColStr(a:col)
endfunction

function! s:MoveToFileLineStr( line_number )
  return a:line_number."G"
endfunction

" Note that the | command is the only way (that I've found) to move to an
" absolute position in vim.
function! s:MoveToColStr( col_number )
  return a:col_number."|"
endfunction

" Select the appropriate region
function! s:VisualSelect()
  call setpos('.', s:visual_start_position)
  if (s:current_row == 1)
    call s:Do(visualmode(), line("w0")."G".s:GetTruncatedCol()."|")
  else
    call s:Do(visualmode(), line("w0")."G".(s:current_row-1)."gj".s:GetTruncatedCol()."|")
  endif
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

function! s:GetScreenLine( expr )
  let saved = getpos(".")
  call s:Do('', s:MoveToFileLineStr(line(a:expr)))
  let result = winline()
  call setpos('.', saved)
  return result
endfunction

function! s:MoveDownNScreenLinesStr( num_lines )
  if (a:num_lines == 0)
    return ""
  else
    return a:num_lines."gj"
  endif
endfunction

function! s:MoveToScreenLineStr( line_number )
  return s:MoveToFileLineStr(line('w0')).s:MoveDownNScreenLinesStr( a:line_number - 1 )
endfunction

function! s:ScreenTopLine()
  return s:GetScreenLine('w0') - 1
endfunction

function! s:ScreenBottomLine()
  return s:GetScreenLine('w$') + 1
endfunction

function! s:ScreenLeftCol()
  return winsaveview().leftcol
endfunction

function! s:ScreenRightCol()
  return s:ScreenLeftCol() + s:VisibleWidth()
endfunction

" This function determines the initial parameters of a bisection.  There is a
" special exception made for the case that BisectRight is called to start a
" bisection.  In this case, we make the guess that the user is trying to get
" to a location on the same line, so we avoid jumping past the end of the
" line.
function! s:StartBisect()
  let s:current_row = s:GetScreenLine('.')
  let s:current_col = virtcol('.')

  let s:top_mark = s:ScreenTopLine()
  let s:bottom_mark = s:ScreenBottomLine()
  let s:left_mark = s:ScreenLeftCol()
  let s:right_mark = s:ScreenRightCol()
  "let s:right_mark = s:MaxLineLength()

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
      let s:top_mark = s:ScreenTopLine()
      if s:current_row != s:top_mark+1
        call s:NarrowBoundaries(a:direction)
      endif
    endif
  elseif a:direction == "down"
    let s:top_mark = s:current_row
    let s:current_row = s:top_mark + float2nr(floor((s:bottom_mark - s:top_mark)/2.0))
    if s:current_row == s:top_mark && !exists("g:bisect_force_strict_bisection")
      let s:bottom_mark = s:ScreenBottomLine()
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
      let s:left_mark = s:ScreenLeftCol()
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
      let s:right_mark = s:ScreenRightCol()
      "let s:right_mark = s:MaxLineLength()
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
  " debugging
  "echo "[".s:top_mark.",".s:current_row.",".s:bottom_mark."] [".s:left_mark.",".s:current_col.",".virtcol('$').",".s:right_mark."]" | redraw
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
    call s:Do('', s:MoveScreenCursorStr(s:current_row, s:GetTruncatedCol()))
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

function! s:CenterVerticallyOnCursorStr()
  return "zz"
endfunction

function! s:PageDownStr()
  return s:MoveToScreenLineStr(winheight(0)).s:MoveToColStr(virtcol('.')).s:CenterVerticallyOnCursorStr()
endfunction

function! s:PageUpStr()
  let l:topline = line("w0")-1
  if l:topline > 0
    return s:MoveFileCursorStr(l:topline, virtcol('.')).s:CenterVerticallyOnCursorStr()
  else
    return ""
  endif
endfunction

function! s:VisibleWidth()
  "return winwidth(0)+virtcol('.')-wincol()+1
  return winwidth(0) - (wincol() - (virtcol('.') - winsaveview().leftcol)) + 1
endfunction

function! s:PageLeft()
  let l:aview = winsaveview()
  if l:aview.leftcol != 0
    exe "normal! ".(l:aview.leftcol)."|"
  endif
endfunction

function! s:PageRight()
  let l:width = s:VisibleWidth()
  let l:aview = winsaveview()
  let l:target_col = l:aview.leftcol + l:width
  exe "normal! ".(l:target_col)."|"
  if !s:IsVirtualEdit() && virtcol('.') < l:target_col
    call winrestview(l:aview)
  endif
endfunction

"BisectUp
nnoremap <silent> <unique> <script> <Plug>BisectNormalBisectUp         :call <SID>NormalBisect("up")<CR>
xnoremap <silent> <unique> <script> <Plug>BisectVisualBisectUp    <ESC>:call <SID>VisualBisect("up")<CR>
inoremap <silent> <unique> <script> <Plug>BisectInsertBisectUp    <ESC>:call <SID>InsertBisect("up")<CR>i

"BisectDown
nnoremap <silent> <unique> <script> <Plug>BisectNormalBisectDown       :call <SID>NormalBisect("down")<CR>
xnoremap <silent> <unique> <script> <Plug>BisectVisualBisectDown  <ESC>:call <SID>VisualBisect("down")<CR>
inoremap <silent> <unique> <script> <Plug>BisectInsertBisectDown  <ESC>:call <SID>InsertBisect("down")<CR>i

"BisectLeft
nnoremap <silent> <unique> <script> <Plug>BisectNormalBisectLeft       :call <SID>NormalBisect("left")<CR>
xnoremap <silent> <unique> <script> <Plug>BisectVisualBisectLeft  <ESC>:call <SID>VisualBisect("left")<CR>
inoremap <silent> <unique> <script> <Plug>BisectInsertBisectLeft  <ESC>:call <SID>InsertBisect("left")<CR>i

"BisectRight
nnoremap <silent> <unique> <script> <Plug>BisectNormalBisectRight      :call <SID>NormalBisect("right")<CR>
xnoremap <silent> <unique> <script> <Plug>BisectVisualBisectRight <ESC>:call <SID>VisualBisect("right")<CR>
inoremap <silent> <unique> <script> <Plug>BisectInsertBisectRight <ESC>:call <SID>InsertBisect("right")<CR>i

"PageUp
nnoremap <silent> <unique> <script> <Plug>BisectNormalPageUp      <ESC>:call <SID>Do('', <SID>PageUpStr())<CR>
xnoremap <silent> <unique> <script> <Plug>BisectVisualPageUp      <ESC>:call <SID>Do(visualmode(), <SID>PageUpStr())<CR>

"PageDown
nnoremap <silent> <unique> <script> <Plug>BisectNormalPageDown    <ESC>:call <SID>Do('', <SID>PageDownStr())<CR>
xnoremap <silent> <unique> <script> <Plug>BisectVisualPageDown    <ESC>:call <SID>Do(visualmode(), <SID>PageDownStr())<CR>

"PageLeft
noremap  <silent> <unique> <script> <Plug>BisectPageLeft          <ESC>:call <SID>PageLeft()<CR>

"PageRight
noremap  <silent> <unique> <script> <Plug>BisectPageRight         <ESC>:call <SID>PageRight()<CR>

"StopBisect
nnoremap <silent> <unique> <script> <Plug>BisectNormalStopBisect       :call <SID>StopBisect()<CR>
xnoremap <silent> <unique> <script> <Plug>BisectVisualStopBisect  <ESC>:call <SID>VisualStopBisect()<CR>
inoremap <silent> <unique> <script> <Plug>BisectInsertStopBisect  <ESC>:call <SID>StopBisect()<CR>i

"ToggleVirtualEdit
noremap <silent> <unique> <script> <Plug>BisectToggleVirtualEdit        <ESC>:call <SID>ToggleVirtualEdit()<CR>

"ToggleVaryingLineEndings
noremap <silent> <unique> <script> <Plug>BisectToggleVaryingLineEndings <ESC>:call <SID>ToggleVaryingLineEndings()<CR>

"Sneaky visual mode handling
nnoremap <silent> v :call <SID>SaveVisualStartPosition('v')<CR>v
nnoremap <silent> V :call <SID>SaveVisualStartPosition('V')<CR>V
nnoremap <silent> <C-v> :call <SID>SaveVisualStartPosition('C-v')<CR><C-v>

if !exists("g:bisect_disable_default_mappings")
  "BisectUp
  if !hasmapto('<Plug>BisectNormalBisectUp', 'n')
    nmap <C-k> <Plug>BisectNormalBisectUp
  endif
  if !hasmapto('<Plug>BisectVisualBisectUp', 'v')
    xmap <C-k> <Plug>BisectVisualBisectUp
  endif
  if !hasmapto('<Plug>BisectInsertBisectUp', 'i')
    imap <C-k> <Plug>BisectInsertBisectUp
  endif

  "BisectDown
  if !hasmapto('<Plug>BisectNormalBisectDown', 'n')
    nmap <C-j> <Plug>BisectNormalBisectDown
  endif
  if !hasmapto('<Plug>BisectVisualBisectDown', 'v')
    xmap <C-j> <Plug>BisectVisualBisectDown
  endif
  if !hasmapto('<Plug>BisectInsertBisectDown', 'i')
    imap <C-j> <Plug>BisectInsertBisectDown
  endif

  "BisectLeft
  if !hasmapto('<Plug>BisectNormalBisectLeft', 'n')
    nmap <C-h> <Plug>BisectNormalBisectLeft
  endif
  if !hasmapto('<Plug>BisectVisualBisectLeft', 'v')
    xmap <C-h> <Plug>BisectVisualBisectLeft
  endif
  if !hasmapto('<Plug>BisectInsertBisectLeft', 'i')
    imap <C-h> <Plug>BisectInsertBisectLeft
  endif

  "BisectRight
  if !hasmapto('<Plug>BisectNormalBisectRight', 'n')
    nmap <C-l> <Plug>BisectNormalBisectRight
  endif
  if !hasmapto('<Plug>BisectVisualBisectRight', 'v')
    xmap <C-l> <Plug>BisectVisualBisectRight
  endif
  if !hasmapto('<Plug>BisectInsertBisectRight', 'i')
    imap <C-l> <Plug>BisectInsertBisectRight
  endif

  "PageUp
  if !hasmapto('<Plug>BisectNormalPageUp', 'n')
    nmap K <Plug>BisectNormalPageUp
  endif
  if !hasmapto('<Plug>BisectVisualPageUp', 'v')
    xmap K <Plug>BisectVisualPageUp
  endif

  "PageDown
  if !hasmapto('<Plug>BisectNormalPageDown', 'n')
    nmap J <Plug>BisectNormalPageDown
  endif
  if !hasmapto('<Plug>BisectVisualPageDown', 'v')
    xmap J <Plug>BisectVisualPageDown
  endif

  "PageLeft
  if !hasmapto('<Plug>BisectPageLeft', 'n')
    map H <Plug>BisectPageLeft
  endif

  "PageRight
  if !hasmapto('<Plug>BisectPageRight', 'n')
    map L <Plug>BisectPageRight
  endif

  "StopBisect
  if !hasmapto('<Plug>BisectNormalStopBisect', 'n')
    nmap <C-i> <Plug>BisectNormalStopBisect
  endif
  if !hasmapto('<Plug>BisectVisualStopBisect', 'v')
    xmap <C-i> <Plug>BisectVisualStopBisect
  endif
  if !hasmapto('<Plug>BisectInsertStopBisect', 'i')
    imap <C-i> <Plug>BisectInsertStopBisect
  endif
endif
