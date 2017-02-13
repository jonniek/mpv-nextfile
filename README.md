#Mpv-nextfile  
This script will force open next or previous file in the currently playing files directory. 

####Settings
Set them inside the settings variable at the head of the lua file.  
- filtering by filetype
- Allow/disallow looping
- linux/windows
- automatic next file on end of file
  
####keybindings
You can copy paste below into your input.conf if you want to change the keybindings. The last one is script message to set the automatic toggle to true or false.  
  `SHIFT+PGUP script-binding previousfile`  
  `SHIFT+PGDWN script-binding nextfile`  
  `CTRL+N script-binding autonextfiletoggle`  
  `KEY script-message loadnextautomatically [true|false]`  
  
#### My other mpv scripts
- [collection of scripts](https://github.com/donmaiq/mpv-scripts)
