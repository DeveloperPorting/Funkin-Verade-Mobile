#!/bin/sh

pause() {
  if [ "$GITHUB_ACTIONS" != "true" ]; then
    read -rsn 1 -p "Press any key to continue. . ." _
  fi
  echo ""
  
  exit
}

echo Making local haxelib and setting it up...
mkdir ~/haxelib && haxelib setup ~/haxelib

echo Installing dependencies...
echo This might take a few moments depending on your internet speed.
haxelib install lime 8.2.2 --quiet
haxelib git hxcpp https://github.com/HaxeFoundation/hxcpp
haxelib install openfl 9.4.1 --quiet
haxelib install flixel 6.1.0 --quiet --skip-dependencies
haxelib install flixel-addons 3.3.2 --quiet --skip-dependencies
haxelib install hscript-iris 1.1.3 --quiet
haxelib install tjson 1.4.0 --quiet
haxelib install hxdiscord_rpc 1.2.4 --quiet --skip-dependencies
haxelib install hxvlc 2.0.1 --quiet --skip-dependencies
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate b8970d2e4d875c743abe28e356a15413b1774d94
haxelib git linc_luajit https://github.com/DeveloperPorting-Stuff/linc_luajit main
pause
