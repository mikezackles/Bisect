bisect.vim
==========

Bisection
---------

This plugin will allow you to reach a desired location on the visible
screen by performing a sequence of bisections to the left, right, up,
and down.  By default, these are performed using the C-h, C-l,
C-j, and C-k commands, respectively.  C-i cancels a bisect.

By default, a new bisection is started when you attempt to move past the edge
of the current bisection.  See below for how to disable this.

Horizontal and vertical commands can be interleaved.

Works in normal mode, insert mode, and all visual modes.  (Note that
insert mode was added after version 2.0 on vim.org, so you'll currently
need to install from this repository if you wish to use it).

Paging
------

By default, H,J,K, and L will center the cursor half a page to the left,
down, up, or right, respectively.  This isn't currently enabled in insert
mode for obvious reasons.

Also note that paging will currently cancel visual selections.
Unfortunately I'm not terribly hopefully about getting this working any
time soon because of the way vim handles visual mode.

VirtualEdit
-----------
It is highly recommended that you try virtualedit mode with bisect.vim, as it
allows the cursor to move to any position on the screen, resulting in less
confusing bisection.  bisect.vim is still fully
functional without virtualedit enabled.

Placing

    set virtualedit=all

in your .vimrc will enable virtualedit by default.  bisect.vim also provides
the <Plug>BisectToggleVirtualEdit convenience function, which can be enabled in
your .vimrc via something like:

    map <Leader>v <Plug>BisectToggleVirtualEdit

Strict Bisection
----------------
If you find bisect.vim too "jumpy" by default, try this in your .vimrc:

    let g:bisect_force_strict_bisection = 1

Remapping
---------

If you wish to use different keys, you need to remap the <Plug>Bisect and
<Plug>VisualBisect family of commands.  Here is an example that remaps right
bisection to ^p:

    nmap <C-p> <Plug>BisectRight
    xmap <C-p> <Plug>VisualBisectRight

Here is a full list of bisect commands, along with their default mappings:

    <C-j>(normal mode)   <Plug>BisectDown
    <C-k>(normal mode)   <Plug>BisectUp
    <C-h>(normal mode)   <Plug>BisectLeft
    <C-l>(normal mode)   <Plug>BisectRight
    <C-@>(normal mode)   <Plug>StopBisect
    <C-j>(visual mode)   <Plug>VisualBisectDown
    <C-k>(visual mode)   <Plug>VisualBisectUp
    <C-h>(visual mode)   <Plug>VisualBisectLeft
    <C-l>(visual mode)   <Plug>VisualBisectRight
    <C-@>(visual mode)   <Plug>VisualStopBisect
    <C-j>(insert mode)   <Plug>InsertBisectDown
    <C-k>(insert mode)   <Plug>InsertBisectUp
    <C-h>(insert mode)   <Plug>InsertBisectLeft
    <C-l>(insert mode)   <Plug>InsertBisectRight
    <C-@>(insert mode)   <Plug>InsertStopBisect
    J                    <Plug>BisectPageDown
    K                    <Plug>BisectPageUp
    H                    <Plug>BisectPageLeft
    L                    <Plug>BisectPageRight
    (not mapped)         <Plug>BisectToggleVirualEdit
    (not mapped)         <Plug>BisectToggleVaryingLineEndings

Customizing
---------

It is possible that you only wish to use some of bisect.vim's functionality.
(For example, you might prefer f and F to the horizontal bisect commands).

You can disable bisect features with the following mappings in your .vimrc:

    let g:bisect_disable_horizontal = 1
    let g:bisect_disable_vertical = 1
    let g:bisect_disable_paging = 1
    let g:bisect_force_strict_bisection = 1
    let g:bisect_force_varying_line_endings = 1
    let g:bisect_disable_normal
    let g:bisect_disable_visual
    let g:bisect_disable_insert

Clearing the Screen
----------------------

By default, bisect.vim overwrites the ^l binding to clear the screen.
This behavior can be mapped to another key as follows (using ^b here):

    map <silent> <C-b> <ESC>:redraw!<CR>

NERDTree
--------

bisect.vim and NERDTree have conflicting mappings.  Use the following to
enable bisect.vim's default mappings.

    let NERDTreeMapJumpNextSibling=''
    let NERDTreeMapJumpPrevSibling=''

Suggestions
-----------

As mentioned before, please try virtualedit mode with bisect.vim

I use

    let g:bisect_force_varying_line_endings = 1

with virtualedit mode.  This setting will make right bisections use the current
line ending instead of the length of the longest visible line.  Of course, if
the cursor is past the line ending, right bisections will work as normal.  With
this set you can still jump past the line ending once you reach it if you
haven't forced strict bisection.

You may also want to try

    set cursorline
    set cursorcolumn

Plug
----

If you like this plugin, please vote for it on vim.org!
http://www.vim.org/scripts/script.php?script_id=2960
