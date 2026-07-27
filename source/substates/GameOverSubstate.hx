package substates;

import psychlua.LuaUtils.Function_Stop;

import objects.Character;
import flixel.math.FlxPoint;

class GameOverSubstate extends MusicBeatSubstate
{
	public var boyfriend:Character;
	var camFollow(get, never):flixel.FlxObject;
	var isEnding:Bool = false;

	public static var characterName:String = 'bf-dead';
	public static var deathSoundName:String = 'loss';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';
	public static var deathDelay:Float = 0;
	public static var instance:GameOverSubstate;

	public function new(playStateBoyfriend:Character = null)
	{
		// Avoids spawning a second boyfriend cuz animate atlas is laggy
		if (playStateBoyfriend?.curCharacter == characterName) boyfriend = playStateBoyfriend;
		super(0xFF000000); // Change GameOverSubstate.instance.bgColor to use another bg color
	}

	inline function get_camFollow()
		return PlayState.instance.camFollow ?? new flixel.FlxObject(0, 0, 1, 1);

	public static function resetVariables()
	{
		characterName = 'bf-dead';
		deathSoundName = 'loss';
		loopSoundName = 'gameOver';
		endSoundName = 'gameOverEnd';
		deathDelay = 0;

		final _song:backend.Song.SwagSong = PlayState.SONG;
		if (_song != null)
		{
			if (_song.gameOverChar?.trim().length > 0) characterName = _song.gameOverChar;
			if (_song.gameOverSound?.trim().length > 0) deathSoundName = _song.gameOverSound;
			if (_song.gameOverLoop?.trim().length > 0) loopSoundName = _song.gameOverLoop;
			if (_song.gameOverEnd?.trim().length > 0) endSoundName = _song.gameOverEnd;
		}
	}

	override function create()
	{
		instance = this;
		Conductor.songPosition = 0;
		FlxTransitionableState.skipNextTransOut = true;
		FlxTransitionableState.skipNextTransIn = true;
		PlayState.instance.setOnScripts('inGameOver', true);
		camera.followLerp = 0.01;

		if (boyfriend == null)
		{
			boyfriend = new Character(PlayState.instance.BF_X, PlayState.instance.BF_Y, characterName, true);
			boyfriend.x += boyfriend.positionArray[0];
			boyfriend.y += boyfriend.positionArray[1];
		}
		boyfriend.skipDance = true;
		add(boyfriend);
		if (PlayState.instance.callOnScripts('onGameOverStart', []) == Function_Stop) return;

		boyfriend.playAnim('firstDeath');
		FlxG.sound.play(Paths.sound(deathSoundName), 1, false, true, () -> 
		{
			boyfriend?.playAnim('deathLoop');
			FlxG.sound.music.play(true);
		});
		
		#if mobile
		addVirtualPad(NONE, A_B);
		addVirtualPadCamera();
		#end

		camFollow.setPosition(boyfriend.getMidpoint().x - boyfriend.cameraPosition[0], boyfriend.getMidpoint().y + boyfriend.cameraPosition[1]);
		FlxG.sound.music.loadEmbedded(Paths.music(loopSoundName), true);
		super.create();
	}

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.playing) Conductor.songPosition = FlxG.sound.music.time;
		super.update(elapsed);
		PlayState.instance.callOnScripts('onUpdate', [elapsed]);

		if (isEnding)
		{
			PlayState.instance.callOnScripts('onUpdatePost', [elapsed]);
			return;
		}

		if (controls.ACCEPT) endBullshit();
		if (controls.BACK) exitBullshit();
		
		PlayState.instance.callOnScripts('onUpdatePost', [elapsed]);
	}

	function endBullshit()
	{
		if (PlayState.instance.callOnScripts('onGameOverConfirm', [true]) == Function_Stop) return;
		isEnding = true;

		if (boyfriend.hasAnimation('deathConfirm')) boyfriend.playAnim('deathConfirm', true);
		FlxG.sound.music.stop();
		FlxG.sound.play(Paths.music(endSoundName));
		
		FlxTimer.wait(0.7, () -> FlxG.camera.fade(FlxColor.BLACK, 2, false, FlxG.resetState));
	}

	function exitBullshit()
	{
		if (PlayState.instance.callOnScripts('onGameOverConfirm', [false]) == Function_Stop) return;
		isEnding = true;
		FlxG.sound.music.stop();
		
		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
		PlayState.deathCounter = 0;
		PlayState.seenCutscene = false;
		PlayState.chartingMode = false;

		#if !DEMO
		if (PlayState.isStoryMode)
		{
			Mods.loadTopMod();
			FlxG.switchState(() -> new states.StoryMenuState());
		}
		else
			FlxG.switchState(() -> new states.FreeplayState());
		CoolUtil.playMenuSong();
		#else
		Mods.loadTopMod();
		FlxG.switchState(() -> new states.MainMenuState());
		#end
	}

	override function destroy()
	{
		instance = null;
		super.destroy();
	}
}
