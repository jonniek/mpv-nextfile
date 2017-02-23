#Mpv-nextfile  
This script will force open next or previous file in the currently playing files directory. 

####Settings
Set them inside the settings variable at the head of the lua file.  
- filtering by filetype
- Allow/disallow looping
- linux/windows
- automatic next file on end of file(experimental, consider playlists(autoload) instead)
  
####keybindings
You can copy paste below into your input.conf if you want to change the keybindings.   
  `SHIFT+PGUP script-binding previousfile`  
  `SHIFT+PGDWN script-binding nextfile`  
  `CTRL+N script-binding autonextfiletoggle`  
  
You can also control the script with script-messages if you'd prefer.  
  `KEY script-message nextfile command value`  
  
Where command is next, previous or auto. Auto will require the value parameter to be true, false or toggle.
  
#### My other mpv scripts
- [collection of scripts](https://github.com/donmaiq/mpv-scripts)
