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

"""Utility functions"""

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

function! s:CenterVerticallyOnCursorStr()
  return "zz"
endfunction

function! s:GetScreenLine( expr )
  let saved = getpos(".")
  call s:Do('', s:MoveToFileLineStr(line(a:expr)))
  let result = winline()
  call setpos('.', saved)
  return result
endfunction

function! s:MoveDownNScreenLinesStr( num_lines )
  return (a:num_lines == 0) ? "" : (a:num_lines."gj")
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



function! s:Do(vmode, expr)
  let str = a:vmode.a:expr
  if (str != "")
    exe "normal! ".str
  endif
endfunction

" This is called before the mode is set, so we have to pass it in explicitly.
function! s:SaveVisualStartPosition(vmode)
  if a:vmode ==# "V" "Visual line mode
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

  let s:vertical_bounds = {}
  let s:vertical_bounds.top_edge = s:ScreenTopLine()
  let s:vertical_bounds.bottom_edge = s:ScreenBottomLine()

  let s:horizontal_bounds = {}
  let s:horizontal_bounds.left_edge = s:ScreenLeftCol()
  let s:horizontal_bounds.right_edge =  s:ScreenRightCol()

  let s:final_position = [-1,-1,-1,-1]
  let s:running = 1
endfunction

function! s:BisectIsRunning()
  return exists("s:running")
endfunction

function s:IsVirtualEdit()
  return &virtualedit == "all"
endfunction

function s:NarrowBoundariesUp(vert_bounds)
  let a:vert_bounds.bottom_edge = s:current_row
endfunction

function s:MoveCursorUp(vert_bounds)
  let s:current_row = a:vert_bounds.top_edge + float2nr(ceil((a:vert_bounds.bottom_edge - a:vert_bounds.top_edge)/2.0))
endfunction

function s:NarrowBoundariesDown(vert_bounds)
  let a:vert_bounds.top_edge = s:current_row
endfunction

function s:MoveCursorDown(vert_bounds)
  let s:current_row = a:vert_bounds.top_edge + float2nr(floor((a:vert_bounds.bottom_edge - a:vert_bounds.top_edge)/2.0))
endfunction

function s:NarrowBoundariesLeft(horiz_bounds)
  let a:horiz_bounds.right_edge = s:current_col
endfunction

function s:MoveCursorLeft(horiz_bounds)
  if virtcol('.') < virtcol('$') && (!s:IsVirtualEdit() || !exists("g:bisect_disable_varying_line_endings"))
    let s:current_col = a:horiz_bounds.left_edge + float2nr(ceil((virtcol('.') - a:horiz_bounds.left_edge)/2.0))
  else
    let s:current_col = a:horiz_bounds.left_edge + float2nr(ceil((a:horiz_bounds.right_edge - a:horiz_bounds.left_edge)/2.0))
  endif
endfunction

function s:NarrowBoundariesRight(horiz_bounds)
  let a:horiz_bounds.left_edge = s:current_col
endfunction

function s:MoveCursorRight(horiz_bounds)
  if virtcol('.') < virtcol('$') && a:horiz_bounds.right_edge > virtcol('$') && s:current_col != (virtcol('$')-1) && (!s:IsVirtualEdit() || !exists("g:bisect_disable_varying_line_endings"))
    " varying line endings
    let s:current_col = a:horiz_bounds.left_edge + float2nr(floor((virtcol('$') - a:horiz_bounds.left_edge)/2.0))
  else
    " absolute line endings
    let s:current_col = a:horiz_bounds.left_edge + float2nr(floor((a:horiz_bounds.right_edge - a:horiz_bounds.left_edge)/2.0))
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

  " Narrow the boundaries of the selection rectangle
  if a:direction == "up"
    call s:NarrowBoundariesUp(s:vertical_bounds)
    call s:MoveCursorUp(s:vertical_bounds)
  elseif a:direction == "down"
    call s:NarrowBoundariesDown(s:vertical_bounds)
    call s:MoveCursorDown(s:vertical_bounds)
  elseif a:direction == "left"
    call s:NarrowBoundariesLeft(s:horizontal_bounds)
    call s:MoveCursorLeft(s:horizontal_bounds)
  elseif a:direction == "right"
    call s:NarrowBoundariesRight(s:horizontal_bounds)
    call s:MoveCursorRight(s:horizontal_bounds)
  endif

  " We save the window location in case moving the cursor causes it to change
  let l:state = s:SaveWindowState()

  " Move the cursor if in normal mode, or update the visual selection if in a
  " visual mode
  let l:target_screen_line = s:current_row
  let l:target_screen_col = s:GetTruncatedCol()
  if a:invoking_mode == 'n'
    " Normal mode
    call s:MoveCursor("", l:target_screen_line, l:target_screen_col)
  else
    " Visual mode
    call s:SelectRegion(s:visual_start_position, l:target_screen_line, l:target_screen_col)
  endif

  " Restore the window location now that the cursor is moved
  call s:RestoreWindowState(l:state)
endfunction

function! s:SelectRegion(start_position, end_screen_line, end_screen_col)
    call setpos('.', a:start_position)
    call s:MoveCursor(visualmode(), a:end_screen_line, a:end_screen_col)
endfunction

function! s:MoveCursor(visual_mode, screen_line, screen_col)
  let l:move_cursor_string = s:MoveScreenCursorStr(a:screen_line, a:screen_col)
  call s:Do(a:visual_mode, l:move_cursor_string)
endfunction

" Wrappers for s:Bisect
function! s:NormalBisect(direction)
  call s:Bisect(a:direction, 'n')
endfunction

function! s:VisualBisect(direction)
  if visualmode() ==# "V"
    normal! 0
  endif
  call s:Bisect(a:direction, visualmode())
endfunction

function! s:InsertBisect(direction)
  call setpos('.', getpos("'^")) " Move the cursor back to where it was in insert mode
  call s:NormalBisect(a:direction)
endfunction

function! s:VisibleWidth()
  "return winwidth(0)+virtcol('.')-wincol()+1
  return winwidth(0) - (wincol() - (virtcol('.') - winsaveview().leftcol)) + 1
endfunction

"""Misc functions"""

function! s:ToggleVirtualEdit()
  call s:StopBisect()
  if &virtualedit != "all"
    set virtualedit=all
  else
    set virtualedit=
  endif
endfunction

function! s:ToggleVaryingLineEndings()
  if exists("g:bisect_disable_varying_line_endings")
    unlet g:bisect_disable_varying_line_endings
  else
    let g:bisect_disable_varying_line_endings = "true"
  endif
endfunction

"""Function Mappings"""
" These expose symbols that can be bound by users

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

"StopBisect
nnoremap <silent> <unique> <script> <Plug>BisectNormalStopBisect       :call <SID>StopBisect()<CR>
xnoremap <silent> <unique> <script> <Plug>BisectVisualStopBisect  <ESC>:call <SID>VisualStopBisect()<CR>
inoremap <silent> <unique> <script> <Plug>BisectInsertStopBisect  <ESC>:call <SID>StopBisect()<CR>i

"ToggleVirtualEdit
noremap <silent> <unique> <script> <Plug>BisectToggleVirtualEdit        <ESC>:call <SID>ToggleVirtualEdit()<CR>

"ToggleVaryingLineEndings
noremap <silent> <unique> <script> <Plug>BisectToggleVaryingLineEndings <ESC>:call <SID>ToggleVaryingLineEndings()<CR>

"""Visual Mode Hackery"""
" A visual selection consists of a starting position and an ending position.
" One of these positions is always the current location of the cursor, and the
" other position is the location at which visual mode was invoked.  Our
" current method for moving the cursor cancels any visual mode selection, so
" we need to manually store the position at which the visual mode is invoked
" in order to select the correct region.  Here we rebind the keys that invoke
" visual modes to make them save the current position before starting the
" desired visual mode.

nnoremap <silent> v :call <SID>SaveVisualStartPosition('v')<CR>v
nnoremap <silent> V :call <SID>SaveVisualStartPosition('V')<CR>V
nnoremap <silent> <C-v> :call <SID>SaveVisualStartPosition('C-v')<CR><C-v>

"""Default Mappings"""

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

  "StopBisect
  if !hasmapto('<Plug>BisectNormalStopBisect', 'n')
    nmap <C-@> <Plug>BisectNormalStopBisect
  endif
  if !hasmapto('<Plug>BisectVisualStopBisect', 'v')
    xmap <C-@> <Plug>BisectVisualStopBisect
  endif
  if !hasmapto('<Plug>BisectInsertStopBisect', 'i')
    imap <C-@> <Plug>BisectInsertStopBisect
  endif
endif
