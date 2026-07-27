package options;

import states.MainMenuState;
import backend.StageData;
import substates.TonhoPauseSubstate.TextOpt;

class OptionsState extends MusicBeatState
{
	var options:Array<TextOpt> = [];
	public static var onPlayState:Bool = false;
	static var curSelected:Int = 0;

	var grpOptions:FlxTypedGroup<Alphabet>;
	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;

	public function new() 
	{
		options = 
		[
			{id: 'gameplay', defName: 'Jogabilidade', action: () -> openSubState(new GameplaySettingsSubState())},
			{id: 'controls', defName: 'Controles', action: () -> openSubState(new ControlsSubState())},
			#if TRANSLATIONS_ALLOWED {id: 'langs', defName: 'Language (Idioma)', action: () -> openSubState(new LanguageSubState())}, #end
			{id: 'aud_delay', defName: 'Ajustar Delay de Áudio', action: () -> FlxG.switchState(() -> new NoteOffsetState())},
			{id: 'graphics', defName: 'Gráficos', action: () -> openSubState(new GraphicsSettingsSubState())},
			{id: 'visuals', defName: 'Visuais e Outros', action: () -> openSubState(new VisualsSettingsSubState())}
		];
		super();
	}

	override function create()
	{
		#if DISCORD_ALLOWED DiscordClient.changePresence("Options Menu"); #end

		var bg:FlxSprite = new FlxSprite(0, 0, Paths.image('menuBG'));
		bg.color = 0xFFea71fd;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (num => option in options)
		{
			var optionText:Alphabet = new Alphabet(0, 0, Language.getPhrase('options_${option.id}', option.defName), true);
			optionText.screenCenter().y += (92 * (num - (options.length / 2))) + 45;
			optionText.alpha = 0.6;
			grpOptions.add(optionText);
		}

		selectorLeft = new Alphabet(0, 0, '>', true);
		add(selectorLeft);
		selectorRight = new Alphabet(0, 0, '<', true);
		add(selectorRight);

		changeSelection(0);
		#if mobile
		addVirtualPad(UP_DOWN, A_B);
		#end
		ClientPrefs.saveSettings();
		super.create();
	}

	override function closeSubState() {
		super.closeSubState();
		#if mobile
		new FlxTimer().start(0.1, function(tmr:FlxTimer) {
			controls.isInSubstate = false;
		});
		#end
		ClientPrefs.saveSettings();
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end
		
		#if mobile
		removeVirtualPad();
		addVirtualPad(UP_DOWN, A_B);
		#end
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.UI_UP_P)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'));
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'));
			changeSelection(1);
		}

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			if (onPlayState)
			{
				StageData.loadDirectory(PlayState.SONG);
				LoadingState.loadAndSwitchState(new PlayState());
				FlxG.sound.music.volume = 0;
			}
			else FlxG.switchState(() -> new MainMenuState());
		}

		if (controls.ACCEPT) options[curSelected].action();
	}
	
	function changeSelection(change:Int)
	{
		grpOptions.members[curSelected].alpha = 0.6;

		curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);
		grpOptions.members[curSelected].alpha = 1;

		selectorLeft.setPosition(grpOptions.members[curSelected].x - (selectorLeft.width + 15), grpOptions.members[curSelected].y);
		selectorRight.setPosition((grpOptions.members[curSelected].x + grpOptions.members[curSelected].width) + 15, selectorLeft.y);
		for (i=>o in grpOptions.members) o.targetY = i - curSelected;
	}

	override function destroy()
	{
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}