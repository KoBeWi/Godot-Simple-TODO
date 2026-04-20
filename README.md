# <img src="https://github.com/KoBeWi/Godot-Simple-TODO/blob/master/Media/Icon.png" width="64" height="64"> Godot Simple TODO

This simple plugin that lets you take random notes and organize them in named columns (which also count number of items). If you like putting your TODO lists in a text file, but they are hundreds of lines long and you start thinking that it's maybe too big, this plugin is for you. It's like kanban board, but with minimal features.

Just enable it to get a new editor screen called "TODO" where you can create columns, where you can create random labels where you can put any text. Simple as that.

![](Media/ReadmeShowcase.webp)

The items can be added either using the `Add Item` button or <kbd>Ctrl</kbd>+<kbd>Enter</kbd>.

The plugin has full undo support, up to 20 actions.

![](Media/ReadmeUndo.webp)

And drag and drop support (contributed by [@Nukiloco](https://github.com/Nukiloco)).

![](Media/ReadmeDragAndDrop.webp)

You can filter items.

![](Media/ReadmeFilter.webp)

There is also a simple "marker" function. You can middle-click the item's drag field to leave a temporary visual marker (it can also be toggled from the context menu). The marker is not saved, it's only meant to easier keep track of the item you are currently working on.

![](Media/ReadmeMarker.webp)

You can right-click column's drag field to open a menu, which allows adding item at top, instead of bottom:

![](Media/ReadmeAddTop.webp)

## Images

You can also add images to your elements. Each element supports only one image. To add image, right-click item's drag field and select Paste Image, press Ctrl+V inside text field with image in the clipboard:

![](Media/ReadmeImages.webp)

Clicking an image will open a popup to preview it in full size.

![](Media/ReadmeImageFull.webp)

Note that images are stored as a binary PNG data in their own file, which makes them less VCS-friendly. Also, while undo/redo works with images, their ID will shift, so it's not advised to undo/redo image changes.

## Data

Data of your columns is stored in a simple .cfg file. You can edit it by hand (the item names don't matter btw), but do so only when the plugin is not active. The plugin automatically saves all your changes.

Images are stored separately in a .bin file (which is a serialized Dictionary). If an item has an image, it will be referenced by randomly generated unique ID. The plugin is able to automatically cleanup unused images, but it's better to not modify them manually, to avoid losing data.

The text data is stored in file defined by `addons/simple_todo/text_data_file` project setting (`res://TODO.cfg` by default), while images are stored in `addons/simple_todo/image_data_file` (`res://TODO.bin` by default). Changing either project setting will automatically move the respective file.

## Localization

The addon supports translations and will automatically use the editor's language, if available. Currently only Polish translation is available. To make a new translation use the `SimpleTODO.pot` file found in the addon's folder and feel free to open a pull request.

___
You can find all my addons on my [profile page](https://github.com/KoBeWi).

<a href='https://ko-fi.com/W7W7AD4W4' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://cdn.ko-fi.com/cdn/kofi1.png?v=3' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>
