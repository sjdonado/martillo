# 3D Icons

This directory contains 3D icons from [3dicons.co](https://3dicons.co/) in the color variant.

## Usage

Use the `lib/icons.lua` helper to access these icons in your code:

```lua
local icons = require 'lib.icons'

-- Get icon by file extension (returns standard size icon)
local pdfIcon = icons.getIconForExtension('pdf')

-- Get icon by name (returns standard size icon)
local fileIcon = icons.getIcon('file')

-- Get all available icon names
local availableIcons = icons.getAvailableIcons()

-- The standard icon size is defined in icons.ICON_SIZE
-- Default: { w = 32, h = 32 }
-- You can modify this global if needed
```

## Available Icons

Total: 120 icons

### Categories

- **Documents**: file, file-text, file-plus, file-fav, folder, new-folder, fav-folder, notebook
- **Communication**: mail, chat, chat-text, chat-bubble, phone-*, megaphone
- **Media**: picture, video-camera, music, camera, mic
- **Development**: figma, computer, mobile, rocket, puzzle
- **Design**: paint-brush, paint-kit, roll-brush, color-palette, eyedropper, brush, bucket
- **System**: setting, trash-can, lock, key, flash, battery, wifi
- **Money**: dollar, euro, pound, rupee, yuan, eth, 3d-coin, money, money-bag, wallet, card
- **UI Elements**: heart, star, bookmark, crown, medal, trophy, flag, target, pin
- **Actions**: play, pause, forward, backward, next, back, copy, plus, tick, thumb-up, thumb-down
- **Objects**: cup, tea-cup, takeaway-cup, bulb, calculator, clock, calender, tool, umbrella
- **And many more...**

## File Extension Mappings

The icons helper automatically maps common file extensions to appropriate icons:

- **Documents**: pdf, doc, docx, txt, md → file, file-text
- **Code**: js, ts, py, lua, etc. → file-text
- **Images**: png, jpg, gif, etc. → picture
- **Video**: mp4, mov, avi, etc. → video-camera
- **Audio**: mp3, wav, flac, etc. → music
- **Design**: psd, ai, sketch, fig → paint-brush, figma

## License

Icons sourced from [3dicons.co](https://3dicons.co/) - Please refer to their licensing terms.
