$baseName = "Godot Version Manager "
$vtag = Read-Host "Type verion tag: "
$fullName = $baseName + $vtag
Rename-Item -Path '.\Godot Version Manager-osx.zip' -NewName "$fullName-osx.zip"
Compress-Archive -Path .\win\gvm.exe -DestinationPath "$fullName-win.zip"
Compress-Archive -Path .\linux\gvm.x86_64 -DestinationPath "$fullName-x11.zip"
Start-Process "https://github.com/noidexe/godot-version-manager/releases/new"