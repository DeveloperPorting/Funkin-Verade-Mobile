package backend;

import openfl.utils.Assets;
import lime.utils.Assets as LimeAssets;

class CoolUtil
{
	inline public static function quantize(f:Float, snap:Float){
		// changed so this actually works lol
		var m:Float = Math.fround(f * snap);
		//trace(snap);
		return (m / snap);
	}

	inline public static function capitalize(text:String)
		return text.charAt(0).toUpperCase() + text.substr(1).toLowerCase();

	public static function coolTextFile(path:String):Array<String>
	{
		var daList:String = Paths.getTextFromFile(path);
		return daList != null ? listFromString(daList) : [];
	}

	inline public static function colorFromString(color:String):FlxColor
	{
		var hideChars = ~/[\t\n\r]/;
		var color:String = hideChars.split(color).join('').trim();
		if(color.startsWith('0x')) color = color.substring(color.length - 6);

		var colorNum:Null<FlxColor> = FlxColor.fromString(color);
		if(colorNum == null) colorNum = FlxColor.fromString('#$color');
		return colorNum != null ? colorNum : FlxColor.WHITE;
	}

	inline public static function listFromString(string:String):Array<String>
	{
		string = string.trim();
		if (string == "") return [];

		var daList:Array<String> = [for (i in string.split('\n')) i.trim()];
		daList = daList.filter((f) -> !f.startsWith("//") && !f.startsWith("// "));
		return daList;
	}

	public static inline function floorDecimal(value:Float, decimals:Int):Float
	{
		if (decimals < 1) return Math.floor(value);
		return Math.floor(value * Math.pow(10, decimals)) / Math.pow(10, decimals);
	}

	public static function dominantColor(sprite:FlxSprite):FlxColor
	{
		var counting:Map<FlxColor, Int> = [];
		final actualWidth:Int = Math.round(sprite.frameWidth * sprite.scale.x);
		final actualHeight:Int = Math.round(sprite.frameHeight * sprite.scale.y);

		for (col in 0...actualWidth)
		{
			for (row in 0...actualHeight)
			{
				var pixelCol:FlxColor = sprite.pixels.getPixel32(col, row);
				if (pixelCol.alphaFloat < 0.1 || pixelCol.brightness < 0.12) continue; // Avoiding dark colors, since colors that tone normally are outlines
				pixelCol.alpha = 1;
				
				final count:Int = counting.exists(pixelCol) ? counting[pixelCol] : 0;
				counting[pixelCol] = count + 1;
			}
		}

		var maxCol:Int = 0;
		var maxCount:Int = 0;
		for (col=>uses in counting)
		{
			if (uses < maxCount) continue;
			
			maxCount = uses;
			maxCol = col;
		}
		return maxCol;
	}

	public static inline function numberArray(max:Int, ?min = 0):Array<Int>
		return [for (i in min...(max + 1)) i];

	inline public static function browserLoad(site:String) {
		#if linux
		Sys.command('/usr/bin/xdg-open', [site]);
		#else
		FlxG.openURL(site);
		#end
	}

	inline public static function openFolder(folder:String, absolute:Bool = false) {
		#if (sys && desktop)
			if(!absolute) folder =  Sys.getCwd() + '$folder';

			folder = folder.replace('/', '\\');
			if(folder.endsWith('/')) folder.substr(0, folder.length - 1);

			#if linux
			var command:String = '/usr/bin/xdg-open';
			#else
			var command:String = 'explorer.exe';
			#end
			Sys.command(command, [folder]);
			trace('$command $folder');
		#else
			flixel.FlxG.error("Platform is not supported for CoolUtil.openFolder");
		#end
	}

	/**
		Helper Function to Fix Save Files for Flixel 5

		-- EDIT: [November 29, 2023] --

		this function is used to get the save path, period.
		since newer flixel versions are being enforced anyways.
		@crowplexus
	**/
	@:access(flixel.util.FlxSave.validate)
	inline public static function getSavePath():String {
		final company:String = FlxG.stage.application.meta.get('company');
		// #if (flixel < "5.0.0") return company; #else
		return '${company}/${flixel.util.FlxSave.validate(FlxG.stage.application.meta.get('file'))}';
		// #end
	}

	public static function setTextBorderFromString(text:FlxText, border:String)
	{
		switch(border.toLowerCase().trim())
		{
			case 'shadow':
				text.borderStyle = SHADOW;
			case 'outline':
				text.borderStyle = OUTLINE;
			case 'outline_fast', 'outlinefast':
				text.borderStyle = OUTLINE_FAST;
			default:
				text.borderStyle = NONE;
		}
	}

	/**
	 * Plays `freakyMenu.ogg` AND sets the bpm to `freakyMenu`'s.
	 * If a song is already playing, then it won't be overriden by this.
	 * @param fadeIn **OPTIONAL** FadeIn duration. When excluded (or -1), the menu music won't have a fade in effect.
	 */
	public static function playMenuSong(fadeIn:Float = -1)
	{
		if (FlxG.sound.music?.playing)
		{
			// Conductor.bpm = 102;
			return;
		}
		final doFade:Bool = fadeIn > -1;

		FlxG.sound.playMusic(Paths.music("freakyMenu"), doFade ? 0 : 1);
		if (doFade) FlxG.sound.music.fadeIn(fadeIn, 0, 0.7);
		Conductor.bpm = 102;
	}

	/**
	 * Plays `freakyMenu.ogg` AND sets the bpm to `freakyMenu`'s, unminding of the currently playing song.
	 * @param fadeIn **OPTIONAL** FadeIn duration. When excluded (or -1), the menu music won't have a fade in effect.
	 */
	public static function playMenuSongForce(fadeIn:Float = -1)
	{
		final doFade:Bool = fadeIn > -1;

		FlxG.sound.playMusic(Paths.music("freakyMenu"), doFade ? 0 : 1);
		if (doFade) FlxG.sound.music.fadeIn(fadeIn, 0, 0.7);
		Conductor.bpm = 102;
	}

	public static inline function pointsAreEqual(point1:FlxPoint, point2:FlxPoint):Bool { return (point1.x == point2.x && point1.y == point2.y); }

	/**
	 * FlxSound uses a list for playing sounds (in order to have multiple). 
	 * But since there's no way to access the latest sound for doing anything, you gotta use some fat code.
	 * 
	 * Hence why I made this shorthand, enjoy.
	 * @author BerGP
	 * @return Bool
	 */
	public static inline function isSoundPlaying():Bool { return FlxG.sound.list.getLast((s) -> s.exists == true)?.playing; }
}
