package;

import flixel.util.typeLimit.NextState.InitialState;

import debug.FPSCounter;

import flixel.graphics.FlxGraphic;
import flixel.FlxGame;
import flixel.FlxState;
import haxe.io.Path;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import lime.app.Application;
import states.TitleState;

#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import psychlua.HScript.HScriptInfos;
#end

#if (linux || mac)
import lime.graphics.Image;
#end

#if desktop
import backend.ALSoftConfig; // Just to make sure DCE doesn't remove this, since it's not directly referenced anywhere else.
#end

//crash handler stuff
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
#end

import backend.Highscore;

// NATIVE API STUFF, YOU CAN IGNORE THIS AND SCROLL //
#if (linux && !debug)
@:cppInclude('./external/gamemode_client.h')
@:cppFileCode('#define GAMEMODE_AUTO')
#end

// // // // // // // // //
class Main extends Sprite
{
	public static var fpsVar:FPSCounter;

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		#if (cpp && windows) backend.Native.fixScaling(); #end

		FlxG.save.bind('funkin', CoolUtil.getSavePath());
		Highscore.load();
		Controls.instance = new Controls();
		ClientPrefs.loadDefaultKeys();

		#if CRASH_HANDLER Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash); #end
		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call)); #end
		#if HSCRIPT_ALLOWED
		Iris.warn = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(WARN, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '')  + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) {
				msgInfo += 'HScript:';
				newPos.showLine = false;
			}
			#end
			if (newPos.showLine == true) {
				msgInfo += '${newPos.lineNumber}:';
			}
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('WARNING: $msgInfo', FlxColor.YELLOW);
		}
		Iris.error = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(ERROR, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '')  + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) {
				msgInfo += 'HScript:';
				newPos.showLine = false;
			}
			#end
			if (newPos.showLine == true) {
				msgInfo += '${newPos.lineNumber}:';
			}
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('ERROR: $msgInfo', FlxColor.RED);
		}
		Iris.fatal = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(FATAL, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '')  + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) {
				msgInfo += 'HScript:';
				newPos.showLine = false;
			}
			#end
			if (newPos.showLine == true) {
				msgInfo += '${newPos.lineNumber}:';
			}
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('FATAL: $msgInfo', 0xFFBB0000);
		}
		#end
		#if VIDEOS_ALLOWED hxvlc.util.Handle.init(#if (hxvlc >= "1.8.0")  ['--no-lua'] #end); #end
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end

		var updateWarn:Bool = false;
		#if CHECK_FOR_UPDATES
		if (ClientPrefs.data.checkForUpdates)
		{
			trace('[UPDATE CHECK] Checking...');
			final version:String = lime.app.Application.current.meta['version'];

			var http:haxe.Http = new haxe.Http("https://raw.githubusercontent.com/BernardoGP4504/Funkin-Verade/main/gitVersion.txt");
			http.onData = (data:String) -> 
			{
				final onlineVersion:String = data.split('\n')[0].trim();
				trace('[UPDATE CHECK] Online: $onlineVersion | Local: $version');

				if (onlineVersion != version)
				{
					trace('[UPDATE CHECK] Version dismatch!! Please update if there\'s a newer version.');
					states.OutdatedState.updateVersion = onlineVersion;
					updateWarn = true;
				}
			};
			http.onError = (error) -> trace('[UPDATE CHECK] Error: $error');
			http.request();
		}
		#end

		#if (FREEPLAY && !DEMO)
		final trueInitialState:InitialState = states.FreeplayState;
		#elseif (CHARTING && EDITORS_ALLOWED)
		final trueInitialState:InitialState = states.editors.ChartingState;
		#else
		final initialState:InitialState = FlxG.save.data.flashing != null ? states.TitleState : () -> new states.FlashingState(states.TitleState);
		final trueInitialState:InitialState = updateWarn ? () -> new states.OutdatedState(initialState) : initialState;
		#end
		FlxTransitionableState.skipNextTransIn = true;
		addChild(new FlxGame(1280, 720, trueInitialState, 60, 60, true, FlxG.save.data.fullscreen));
		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		fpsVar = new FPSCounter(10, 3);
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		fpsVar.visible = ClientPrefs.data.showFPS;

		FlxG.signals.gameResized.add((_, _) -> resizeFix()); // shader coords fix
		FlxG.signals.preGameReset.add(() -> 
		{
			final tracked:Array<String> = Paths.localTrackedAssets.copy();
			for (i in tracked)
			{
				if (Paths.dumpExclusions.contains(i) || !Paths.currentTrackedAssets.exists(i)) continue;
				final g:flixel.graphics.FlxGraphic = Paths.currentTrackedAssets[i];

				Paths.currentTrackedAssets.remove(i);
				Paths.localTrackedAssets.remove(i);
				FlxG.bitmap.remove(g);
			}
			tracked.resize(0);
		}); // "Cannot render destroyed graphic" fix
		FlxG.debugger.visibilityChanged.add(() -> fpsVar.offsetY = FlxG.debugger.visible ? 20 : 0); // Use FlxG.debugger.visibilityChanged.removeAll() if you don't want this offset behaviour

		#if (linux || mac) // fix the app icon not showing up on the Linux Panel / Mac Dock
		var icon = Image.fromFile("icon.png");
		Lib.current.stage.window.setIcon(icon);
		#end

		ClientPrefs.loadPrefs();
		Language.reloadPhrases();
		#if DISCORD_ALLOWED DiscordClient.prepare(); #end

		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = 60;
		FlxG.keys.preventDefaultKeys = [TAB];
		#if android FlxG.android.preventDefaultKeys = [BACK]; #end
		FlxG.cameras.bgColor = FlxColor.BLACK;

		FlxTransitionableState.defaultTransIn = new flixel.addons.transition.TransitionData(FADE, FlxColor.BLACK, 0.5, FlxPoint.weak(0, -1));
		FlxTransitionableState.defaultTransOut = new flixel.addons.transition.TransitionData(FADE, FlxColor.BLACK, 0.5, FlxPoint.weak(0, 1));
		MusicBeatState.customTransClass = "states.transitions.AppleZoomTransition";
	}

	function resizeFix()
	{
		if (FlxG.cameras != null)
		{
			for (cam in FlxG.cameras.list)
			{
				if (cam == null || cam.filters == null) continue;
				resetSpriteCache(cam.flashSprite);
			}
		}

		if (FlxG.game == null) return;
		resetSpriteCache(FlxG.game);
	}

	@:privateAccess
	inline function resetSpriteCache(sprite:Sprite)
	{
		sprite.__cacheBitmap = null;
		sprite.__cacheBitmapData = null;
	}

	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");
		final path:String = 'crash/$dateNow.txt';

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(_, file, line, column): errMsg += '$file (line $line at $column)\n';
				default: Sys.println(stackItem);
			}
		}

		errMsg += '\nAn uncaught error occured: ${e.error}!';
		errMsg += "\nPlease report it to here if possible: https://github.com/BernardoGP4504/Funkin-Verade";
		errMsg += "\r\n> Crash Handler written by: sqirra-rng";

        #if (sys && desktop)
		if (!FileSystem.exists("./crash/")) FileSystem.createDirectory("./crash/");
		File.saveContent(path, '${errMsg}\n');
		#end

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		#if DISCORD_ALLOWED DiscordClient.shutdown(); #end
		Sys.exit(1);
	}
	#end
}
