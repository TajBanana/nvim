clone this repo into ~/.config and change this repo name to nvim.
.ideavimrc is to be used at the root folder to config intellij

use `ln -s ~/.config/nvim/.ideavimrc ~/.ideavimrc` to create symlink

for formatters, go into Mason and install the formatter manually
if null-ls is throwing error for eslint, run this command `:TSUpdate`

To inspect object under the cursor to find out the object type, use `:Inspect`.
Then to change to custom colors, go to colors.lua to change the color of the type to one that you want
