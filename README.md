# <img src="https://github.com/KoBeWi/Godot-Simple-TODO/blob/master/Media/Icon.png" width="64" height="64"> Godot Simple TODO

This simple plugin that lets you take random notes and organize them in named columns (which also count number of items). If you like putting your TODO lists in a text file, but they are hundreds of lines long and you start thinking that it's maybe too big, this plugin is for you. It's like kanban board, but without unnecessary features.

Just enable it to get a new editor screen called "TODO" where you can create columns, where you can create random labels where you can put any text. Simple as that.

![](https://github.com/KoBeWi/Godot-Simple-TODO/blob/master/Media/ReadmeShowcase.gif)

The plugin has full undo support.

![](https://github.com/KoBeWi/Godot-Simple-TODO/blob/master/Media/ReadmeUndo.gif)

## Data

Data of your columns is stored in a simple .cfg file. You can edit it by hand (the item names don't matter btw), but do so only when the plugin is not active. The plugin automatically saves all your changes. You can change the file where data is stored by modifying `DATA_FILE` constant in `SimpleTODO.gd`.