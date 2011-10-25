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

Works in normal and all visual modes.

Paging
------

By default, H,J,K, and L will center the cursor half a page to the left, down,
up, or right, respectively.

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

    let g:bisect_enable_strict_bisection = "true"

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
    <C-j>(visual mode)   <Plug>VisualBisectDown
    <C-k>(visual mode)   <Plug>VisualBisectUp
    <C-h>(visual mode)   <Plug>VisualBisectLeft
    <C-l>(visual mode)   <Plug>VisualBisectRight
    <C-i>                <Plug>StopBisect
    J                    <Plug>BisectPageDown
    K                    <Plug>BisectPageUp
    H                    <Plug>BisectPageLeft
    L                    <Plug>BisectPageRight
    (not mapped)         <Plug>BisectToggleVirualEdit

Customizing
---------

It is possible that you only wish to use some of bisect.vim's functionality.
(For example, you might prefer f and F to the horizontal bisect commands).

You can disable bisect features with the following mappings in your .vimrc:

    let g:bisect_disable_horizontal = "true"
    let g:bisect_disable_vertical = "true"
    let g:bisect_disable_paging = "true"
    let g:bisect_enable_strict_bisection = "true"
    let g:bisect_force_varying_line_endings = "true"

Clearing the Screen
----------------------

By default, bisect.vim overwrites the ^l binding to clear the screen.
This behavior can be mapped to another key as follows (using ^b here):

    map <silent> <C-b> <ESC>:redraw!<CR>

Marks
-----

bisect.vim currently uses the marks 's, 'p, and 't internally.  Modifying these
values with bisect.vim enabled may lead to unexpected results.

NERDTree
--------

bisect.vim and NERDTree have conflicting mappings.  Use the following to
enable bisect.vim's default mappings.

    let NERDTreeMapJumpNextSibling=''
    let NERDTreeMapJumpPrevSibling=''

Suggestions
-----------

As mentioned before, please try virtualedit mode with bisect.vim

You may also want to try

    set cursorline
    set cursorcolumn
