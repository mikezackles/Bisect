bisect.vim
==========

This plugin will allow you to reach a desired location on the visible
screen by performing a sequence of bisections to the left, right, up,
and down.  By default, these are performed using the C-h, C-l,
C-j, and C-k commands, respectively.  <C-n> cancels a bisect.

For example, suppose your cursor is above the desired location on the
screen.  Call the BisectDown command, and your cursor will move halfway
between its current location and the bottom of the screen.  Now suppose
your cursor is below the desired position.  Call the BisectUp command,
and your cursor will move to halfway between its current position and
its original position.  Repeat as necessary.  BisectLeft and BisectRight
work analagously.  Horizontal and vertical commands can be interleaved.

Works in normal and all visual modes. 

Clearing the Screen
----------------------

By default, bisect.vim overwrites the ^l binding to clear the screen.
This behavior can be mapped to another key as follows (using ^b here):

    map <silent> <C-b> <ESC>:redraw!<CR>

Remapping
---------

If you wish to use different keys, you need to remap the <Plug>Bisect and
<Plug>VisualBisect family of commands.  Here is an example that remaps right
bisection to ^p:

    nmap <C-p> <Plug>BisectRight
    xmap <C-p> <Plug>VisualBisectRight


Unmapping
---------

It is possible that you only wish to use some of bisect.vim's functionality.
(For example, you might prefer f and F to the horizontal bisect commands).
Unfortunately this is slightly awkward for now, but hopefully it will be fixed
in a future version.

To disable horizontal bisection, create a file named
~/.vim/after/plugin/bisect.vim containing:

    unmap <C-h>
    unmap <C-l>
