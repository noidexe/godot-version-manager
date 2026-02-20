<table><tr width=64px><td><img height=64px src="https://user-images.githubusercontent.com/526829/169241046-3087a41d-9606-43ab-90ae-ee0055bef039.png"/></td><td><h1>godot-version-manager</h1></td></tr></table>
  
Download, install and manage any version of Godot Engine from a simple app. 

<img alt="screenshot with light theme" src="https://github.com/user-attachments/assets/5b504fa3-59ea-46c8-bb78-6a743759d984" />
<img alt="screenshot with dark theme" src="https://github.com/user-attachments/assets/08ff0100-fbd5-40be-a8a4-80bbb186d37e" />

## Installation
### Windows:
Unzip and double-click. (On Windows XP please make sure Powershell is installed)
### Linux:
Unzip and double-click. Extraction of downloaded versions requires `unzip` which, if not installed, should be available in your distro repository
### OSX:
- Should auto extract after download
- You need to run `sudo xattr -r -d com.apple.quarantine path/to/Godot Version Manager.app` since unsigned binaries get marked as untrusted otherwise. Feel free to build the project yourself if you don't trust the prebuilt binaries
- Double click Godot Version Manager.app

## Features
- Automatically download and install any version of Godot from a drop-drown menu. (requires powershell for extraction)
- Show or hide alpha, beta, rc and dev versions from download drop-down. 
- Add your own binaries anywhere on your filesystem. 
- Colorful icons to easily distinguish stable, rc, beta, alpha and master builds. 
- Right click to remove any entry from the list
- Drag and drop to reorder enties
- Drag and drop a project.godot file or Godot project folder to add a project and launch it with a specific version
- News feed from godotengine.org./news

## F.A.Q
**Q: Where are the downloaded binaries saved to?**

A: They are saved to `user://versions` which varies depending on your platform. On windows it's %appdata%/Godot/app_userdata/Godot Version Manager/versions

**Q: How is this different from Hourglass or Godot Manager?**

A:
 - [Hourglass](https://hourglass.jwestman.net/) is a much more mature and featureful project with better support for project management. Maybe the only advantage GVM has is that it also downloads news snippets from the official website :)
 - [Godot Manager](https://github.com/eumario/godot-manager) seems to be a pretty mature and featureful alternative too.
 - [Godots](https://github.com/MakovWait/godots) is a new (Aug 2023) alternative that a lot of people seem to like.
 - [GodotEnv](https://github.com/chickensoft-games/GodotEnv) and [godot-version-manager](https://github.com/gaheldev/godot-version-manager) are CLI-only alternatives.
 - [Godot Launcher](https://github.com/sebastianoboem/godot-launcher) is a python-based alternative with support for extension and cache management.
 - [gdvm](https://github.com/adalinesimonian/gdvm) is another CLI based version manager built with Rust.

## LICENSE
MIT Licensed (see LICENSE.md)
Copyright ©️2022 Lisandro Lorea and contributors

Lilita One Font ©️2011 Juan Montoreano
<a href="https://www.flaticon.com/free-icons/exe" title="exe icons">Exe icons created by Freepik - Flaticon</a>
