this repo requires nvim v0.9 or later.

clone this repo into ~/.config and change this repo name to nvim.
.ideavimrc is to be used at the root folder to config intellij

use `ln -s ~/.config/nvim/.ideavimrc ~/.ideavimrc` to create symlink

rename the after folder to .after so that the plugins setup does not run before they are installed.

find and go into packer.lua, type `:so` and press enter, followed by `:PackerSync` and press enter.
after packer installed all the plugins, exit nvim and rename .after back to after.
when you reopen nvim, the plugin setup will run.

to install formatters or lsp, go into Mason and install the formatter manually using the command `:Mason`
if null-ls is throwing error for eslint, run this command `:TSUpdate`

To inspect object under the cursor to find out the object type, use `:Inspect`.
Then to change to custom colors, go to colors.lua to change the color of the type to one that you want
