package substates;

import flixel.addons.display.FlxBackdrop;
import flixel.util.typeLimit.OneOfTwo;
import flixel.group.FlxContainer.FlxTypedContainer;
import haxe.Json;
import options.OptionsState;
import backend.WeekData;

typedef TextOpt = 
{
	id:String,
	defName:String,
	?translateValues:Array<Void->Dynamic>,
	action:Void->Void
}

private typedef RenderData = 
{
	scale:Float,
	offsets:Array<Float>
}

class TonhoPauseSubstate extends MusicBeatSubstate
{
	var options:Array<TextOpt> = [];
	public static var extraOptions:Array<TextOpt> = new Array();
	static var renderData:RenderData;
	static inline function translateTag(option:String):String { return 'pause_$option'; }
	var curSelected:Int = 0;
	var __secondsPaused:Float = 0;

	// Maybe saves up on memory
	@:allow(states.PlayState)
	static var textMembers:Array<FlxText> = [];
	static var gridGph:openfl.display.BitmapData;
	static var renderGph:flixel.graphics.FlxGraphic;

	var textGrp:FlxTypedContainer<FlxText>;
	var bgGrid:FlxBackdrop;
	public static var music:FlxSound = new FlxSound();
	public static var musicName(default, set):String;
	@:noCompletion static inline function set_musicName(m)
	{
		if (musicName == m && music.exists) return musicName;

		music.loadEmbedded(Paths.music('pause/$m'), true);
		return musicName = m;
	}

	public function new(?camera:FlxCamera)
	{
		camera ??= FlxG.cameras.list[FlxG.cameras.list.length - 1];
		this.camera = camera;

		options = 
		[
			{id: "resume", defName: "Resumir", action: () -> getTFOut(close)},
			{id: "restart", defName: "Reiniciar", action: FlxG.resetState},
			{id: "options", defName: "Opções", action: () -> FlxG.switchState(OptionsState.new)},
			{id: "back", defName: "Sair", action: function()
			{
				music.stop();
				if (extraOptions.length > 0) extraOptions.resize(0);

				#if DEMO
				FlxG.switchState(() -> new states.MainMenuState());
				#else
				FlxG.switchState(() -> new states.FreeplayState());
				#end
			}}
		];
		if (extraOptions.length > 0) for (i in 0...extraOptions.length)
			options.insert(options.length - 2, extraOptions[i]);

		curSelected = FlxMath.wrap(curSelected, 0, options.length - 1);
		super(0xB0000000);
	}

	public static function cacheStuff(targetSong:String, ?weekData:WeekData)
	{
		if (WeekData.weeksList.length == 0) WeekData.reloadWeekFiles(PlayState.isStoryMode);
		weekData ??= WeekData.getCurrentWeek();
		weekData ??= WeekData.weeksLoaded[WeekData.weeksList[0]]; // If PlayState week is null, we default to first week

		if (!Paths.fileExists('music/pause/$targetSong.${Paths.SOUND_EXT}', MUSIC) 
			&& !Paths.fileExists('music/pause/${targetSong = weekData.fileName}.${Paths.SOUND_EXT}', MUSIC)) targetSong = "breakfast"; 
		musicName = targetSong;
		FlxG.sound.list.add(music);

		Paths.cacheBitmap('images/pausescreen/bg.png');
		Paths.cacheBitmap(Language.getFileTranslation('images/pausescreen/info.png'));

		renderGph = Paths.cacheBitmap('images/${weekData.renderPath}.png');
		final imgName:String = weekData.renderPath.substr(weekData.renderPath.lastIndexOf("/") + 1);
		renderData = Json.parse(Paths.getTextFromFile( Paths.json('menus/pause_renderDatas/$imgName') ));
		renderData ??= {scale: 1, offsets: [0, 0]};

		if (ClientPrefs.data.lowQuality) return;
		gridGph = flixel.addons.display.FlxGridOverlay.createGrid(20, 20, 40, 40, true, FlxColor.WHITE, FlxColor.TRANSPARENT);
	}

	override function create()
	{
		super.create();
		FlxG.random.resetInitialSeed(); // Random randomized music position

		music.play(true, FlxG.random.float(0, (music.length / 2)));
		music.fadeIn(1.2, 0, 0.5);
		final scaling:Float = 0.67;

		if (gridGph != null)
		{
			bgGrid = new FlxBackdrop(gridGph);
			bgGrid.scale.set(2.5, 2.5); bgGrid.updateHitbox();
			bgGrid.velocity.set(-24, 24);
			bgGrid.alpha = 0.13;
			add(bgGrid);
		}

		if (renderGph != null)
		{
			var render:FlxSprite = new FlxSprite((FlxG.width / 2) + renderData.offsets[0], renderData.offsets[1], renderGph);
			render.scale.set(renderData.scale, renderData.scale); render.updateHitbox();
			render.antialiasing = ClientPrefs.data.antialiasing;
			render.active = false;
			add(render);
		}
		
		var bg:FlxSprite = new FlxSprite(0, 0, Paths.image('pausescreen/bg'));
		bg.scale.set(scaling, scaling); bg.updateHitbox();
		bg.screenCenter(Y);
		bg.active = false;
		add(bg);

		textGrp = new FlxTypedContainer<FlxText>(options.length);
		if (textMembers.length != 0) createTextsFrom(textMembers);
		if (options.length > textMembers.length) createTextsFrom(options);
		add(textGrp);

		var pauseTxt:FlxSprite = new FlxSprite(0, 0, Paths.image('pausescreen/info'));
		pauseTxt.scale.set(scaling, scaling); pauseTxt.updateHitbox();
		pauseTxt.screenCenter(Y);
		pauseTxt.active = false;
		add(pauseTxt);
		
		#if mobile
		addVirtualPad(UP_DOWN, A_B);
		addVirtualPadCamera();
		#end

		changeSelection(0);
	}	

	function createTextsFrom(options:Array<OneOfTwo<TextOpt, FlxText>>)
	{
		function makeNewTxt(pos:Int, data:TextOpt):FlxText
		{
			var translations:Array<Dynamic> = data.translateValues != null ? [for (t in data.translateValues) t()] : null;

			var text:FlxText = new FlxText(240, 120, (FlxG.width / 2), ' ${Language.getPhrase(translateTag(data.id), data.defName, translations)}', 64);
			text.font = Paths.font("fraiche.ttf");
			text.setBorderStyle(OUTLINE, FlxColor.BLACK, 4.2);
			text.y += (text.height + 12) * pos;
			text.active = false;
			text.antialiasing = true;
			textGrp.add(text);

			if (translations != null) translations.resize(0);
			return text;
		};

		for (p=>i in options)
		{
			if (i is FlxText)
			{
				final txt:FlxText = cast i;
				txt.revive();
				
				textGrp.add(txt);
				continue;
			}

			textMembers.push(makeNewTxt(p, i));
		}
	}

	override function update(elapsed:Float)
	{
		__secondsPaused += elapsed;
		if (controls.UI_UP_P || controls.UI_DOWN_P) changeSelection(1 * (controls.UI_UP_P ? -1 : 1));
		if (controls.ACCEPT && __secondsPaused > 0.1) options[curSelected].action();

		super.update(elapsed);
		if (textGrp == null || textGrp.length == 0) return;

		for (i=>o in options)
		{
			if (o.translateValues == null) continue;
			var translations:Array<Dynamic> = [for (t in o.translateValues) Language.getPhrase('${translateTag(o.id)}-${t()}', t())];

			textGrp.members[i].text = ' ${Language.getPhrase(translateTag(o.id), o.defName, translations)}'; // Trailing space so text doesn't look cutoff
			translations.resize(0);
		}
	}

	inline function changeSelection(change:Int)
	{
		textGrp.members[curSelected].color = FlxColor.WHITE;

		curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);
		textGrp.members[curSelected].color = FlxColor.YELLOW;
	}

	inline function setBGColAlpha(alpha:Float)
	{
		bgColor.alphaFloat = alpha;
		bgColor = bgColor;
	}

	function getTFOut(finishFunc:Void->Void)
	{
		music.stop();
		final twnEase:EaseFunction = FlxEase.expoOut;

		for (t in textGrp.members) FlxTween.tween(t, {alpha: 0}, 0.2, {ease: twnEase});
		for (s in members)
		{
			if (Reflect.getProperty(s, 'alpha') == null) continue;
			FlxTween.tween(s, {alpha: 0}, 0.2, {ease: twnEase});
		}

		FlxTween.num(bgColor.alphaFloat, 0, 0.2, {ease: twnEase, onComplete: (_) -> finishFunc()}, setBGColAlpha);
	}

	override function destroy()
	{
		remove(bgGrid, true); // Impede o gráfico de ser destruído
		if (textMembers.length == 0)
		{
			super.destroy();
			return;
		}

		for (t in textGrp.members)
		{
			FlxTween.cancelTweensOf(t); t.alpha = 1;
			t.kill();
			textGrp.remove(t);
		}
		super.destroy();
	}
}