package debug;

import flixel.FlxG;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.system.System;

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project
**/
class FPSCounter extends TextField
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int;

	/**
		The current memory usage (WARNING: this is NOT your total program memory usage, rather it shows the garbage collector memory)
	**/
	public var memoryMegas(get, never):Float;

	@:noCompletion @:unreflective private var times:Array<Float>;

	@:unreflective private final startingY:Float;
	public var offsetY:Float = 0;

	public function new(x:Float = 10, y:Float = 10)
	{
		super();

		this.x = x;
		this.y = startingY = y;

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat("_sans", 14, 0xFFFFFF);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: 0";

		times = [];
	}

	var deltaTimeout:Float = 0;
	private override function __enterFrame(deltaTime:Float)
	{
		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < (now - 1000)) times.shift();

		y = startingY + offsetY;
		// prevents the overlay from updating every frame, why would you need to anyways @crowplexus
		if (deltaTimeout < 50)
		{
			deltaTimeout += deltaTime;
			return;
		}

		currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;		
		updateText();
		#if mobile setScale(); #end
		deltaTimeout = 0;
	}

	public dynamic function updateText() // So people can override it in hscript
	{
		text = 'FPS: ${currentFPS}'
		+ '\nMemory: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)}';

		textColor = currentFPS >= (FlxG.drawFramerate * 0.5) ? 0xFFFFFFFF : 0xFFFF0000;
	}
	
	#if mobile
	public inline function setScale(?scale:Float):Void {
	    if (scale == null) {
	        var screenW:Float = FlxG.stage.window.width;
	        var screenH:Float = FlxG.stage.window.height;
	        scale = Math.min(screenW / FlxG.width, screenH / FlxG.height);
	    }
	
	    #if android
	        var finalScale:Float = (scale > 1) ? scale : 1;
	    #else
	        var finalScale:Float = (scale < 1 ? scale : 1);
	    #end
	
	    scaleX = scaleY = finalScale;
	}
	#end

	inline function get_memoryMegas():Float
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
}
