<table><tr width=64px><td><img height=64px src="https://user-images.githubusercontent.com/526829/169241046-3087a41d-9606-43ab-90ae-ee0055bef039.png"/></td><td><h1>godot-version-manager</h1></td></tr></table>
  
Download, install and manage any version of Godot Engine from a simple app. 

![image](https://user-images.githubusercontent.com/526829/169240992-08fe1939-4d97-4577-b989-dda0901aa731.png)

## Installation
### Windows:
Unzip and double-click. Extraction of downloaded versions requires powershell
### Linux:
Unzip and double-click. Extraction of downloaded versions requires `unzip` which, if not installed, should be available in your distro repository
### OSX:
- Should auto extract after download
- You need to run `sudo xattr -r -d com.apple.quarantine path/to/Godot Version Manager.app` since unsigned binaries get marked as untrusted otherwise. Feel free to build the project yourself if you don't trust the prebuilt binaries
- Double click Godot Version Manager.app

## Features
- Automatically download and install any version of Godot from a drop-drown menu. (requires powershell for extraction)
- Show or hide alpha, beta, rc versions from download drop-down. 
- Add your own binaries anywhere on your filesystem. 
- Colorful icons to easily distinguish stable, rc, beta, alpha and master builds. 
- Right click to remove entry entry from the list

## F.A.Q
**Q: Where are the downloaded binaries saved to?**

A: They are saved to `user://versions` which varies depending on your platform. On windows it's %appdata%/Godot/app_serdata/Godot Version Manager/versions

**Q: How is this different from Hourglass?**

A: [Hourglass](https://hourglass.jwestman.net/) is a much more mature and featureful project which also does project management. Maybe the only advantage GVM has is that it also downloads news snippets from the official website :)

## TODO
- [x] Linux support
- [x] OSX support
- [ ] General code clean up
- [ ] Better(i.e some at all) error handling
- [ ] Inform about available updates for installed versions
- [x] Inform about available updates for Godot Version Manager
- [x] Show news snippets from godotengine.com/news?
