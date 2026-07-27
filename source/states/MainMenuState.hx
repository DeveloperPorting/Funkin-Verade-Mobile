package states;

import objects.GamepadCursor;
import flixel.FlxObject;
import flixel.input.keyboard.FlxKey;
import backend.WeekData;
import backend.Song;
import openfl.utils.Assets;
import flixel.util.typeLimit.NextState;

private enum abstract AlignType(String) from String
{
	final CENTER:String = "centered";
	final BOTTOM_LEFT:String = "bottomL";
	final BOTTOM_RIGHT:String = "bottomR";
	final TOP_LEFT:String = "topL";
	final TOP_RIGHT:String = "topR";
}

private typedef RenderData = 
{
	imageName:String,
	offset:Array<Float>,
	scale:Float,
	?originAlign:AlignType
}

private typedef MenuOpt = 
{
	offset:Array<Float>,
	scale:Float,
	render:RenderData
}

private enum abstract EasterEgg(String) from String to String
{
	public static final ABEL:String = "abel";	
	public static final AZEDO:String = "azedaria";
	public static final JABUTICABA:String = "jabuticaba";
	public static final ALGORITHOMUS:String = "algorithomus";

	public static final repeatable:haxe.ds.ReadOnlyArray<EasterEgg> = [ABEL];
}

class MainMenuState extends MusicBeatState
{
	var optionShit:Array<String> = [];
	static final datasPath:String = Paths.getSharedPath('data/menus/main/');
	static var curSelected:Int = 0;
	static var prevTransition:String;

	var selectedSomethin:Bool = false;
	var selectionShit:Map<Int, Array<String>> = [];
	var controllerCursor:GamepadCursor;
	var lastMousePos:FlxPoint = new FlxPoint();
	var curMousePos:FlxPoint = new FlxPoint();

	var menuItems:FlxTypedGroup<FlxSprite>;
	var menuColors:Array<FlxColor> = [];
	var bgGrad:FlxSprite;

	var renderSprs:Array<FlxSprite> = [];
	// Neat bopping effect
	var renderScales:Array<Float> = [];
	final bopInterval:Int = 2;
	final lerpSpeed:Float = 6;

	var easterEggs:Map<EasterEgg, Void->Void> = [];
	var eggsLastClues:Array<Int> = [];
	var eggsLastGuesses:Array<String> = [];
	var eggHunts:Array<Void->Void> = [];
	var deivHitbox:FlxObject;

	@:noCompletion inline function __selectionDataFromNode(element:Xml):Array<String>
	{
		var selectionData:Array<String> = [];
		for (d in element.elements())
		{
			selectionData.push(
				#if DEMO
				d.get("demo").length > 0 ? d.get("demo") : d.get("default")
				#else
				d.get("default")
				#end);
		}

		for (d in selectionData.copy())
		{
			if (d.length != 0) continue;
			selectionData.remove(d);
		}
		return selectionData;
	}

	public function new()
	{
		final optionData:Xml = Xml.parse(Paths.getTextFromFile('${datasPath}options.xml')).firstElement();

		var i:Int = 0;
		for (e in optionData.elements())
		{
			optionShit.push(e.get("name"));
			if (e.firstElement() == null) continue;

			selectionShit[i++] = __selectionDataFromNode(e);
		}

		prevTransition ??= MusicBeatState.customTransClass;
		super();
	}

	override function finishTransIn()
	{
		super.finishTransIn();
		MusicBeatState.customTransClass = "states.transitions.AppleZoomTransition"; // Reset to Default so game restart doesn't break
	}

	override function create()
	{
		FlxG.mouse.visible = false;
		Paths.clearUnusedMemory();
		CoolUtil.playMenuSong();

		if (optionShit.length == 0)
		{
			selectedSomethin = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxTransitionableState.skipNextTransIn = true;

			FlxG.switchState(function() 
			{
				return new ErrorState(
					'No menu items were found!! Try making sure options are added correctly in "${datasPath}options.xml".\nPress ACCEPT to Reload | Press BACK to Leave this Menu',
					() -> FlxG.switchState(MainMenuState.new),
					() -> FlxG.switchState(() -> new TitleState())
				);
			});
			return;
		}

		// Easter eggs são assinalados aqui pq não se pode acessar funções locais no declarar de variáveis
		EasterEggHandler.state = this;
		easterEggs = 
		[
			EasterEgg.ABEL => EasterEggHandler.spawnAbels,
			EasterEgg.ALGORITHOMUS => EasterEggHandler.agmRef,
			EasterEgg.AZEDO => EasterEggHandler.broGotBaited,
			EasterEgg.JABUTICABA => EasterEggHandler.jabuticabaSequence
		];

		EasterEggHandler.init();
		for (i in 1...4) Paths.returnSound('sounds/typing/$i', true, false);
		Paths.returnSound('sounds/typing/wrong', true, false);
		Paths.returnSound('sounds/secret', true, false);

		var eggId:Int = 0;
		for (clues=>egg in easterEggs)
		{
			eggsLastClues.push(-1);
			eggsLastGuesses.push("");
			final huntTask:Void->Void = huntForEgg.bind(egg, eggId, clues);

			eggHunts.push(huntTask);
			FlxG.signals.postUpdate.add(huntTask);
			++eggId;
		}
		FlxG.signals.postUpdate.add(EasterEggHandler.onUpdate);

		super.create();
		#if DISCORD_ALLOWED DiscordClient.changePresence("Choosing a Menu", "Menu Selection", true); #end

		var bg:FlxSprite = new FlxSprite(0, 0, Paths.image('menuBG'));
		bg.screenCenter();
		bg.flipX = true;
		bg.active = false;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		if (!ClientPrefs.data.lowQuality)
		{	
			bgGrad = new FlxSprite(0, 0, flixel.util.FlxGradient.createGradientBitmapData(1, FlxG.height, [0xFFADADAD, 0xFF3F3F3F]));
			bgGrad.scale.x = FlxG.width; bgGrad.updateHitbox();
			bgGrad.screenCenter();
			bgGrad.active = false;
			bgGrad.antialiasing = false;
			bgGrad.blend = MULTIPLY;
			add(bgGrad);

			var bgGrid:flixel.addons.display.FlxBackdrop = new flixel.addons.display.FlxBackdrop(flixel.addons.display.FlxGridOverlay.createGrid(20, 20, 40, 40, true, FlxColor.WHITE, FlxColor.TRANSPARENT));
			bgGrid.scale.set(1.85, 1.85); bgGrid.updateHitbox();
			bgGrid.velocity.set(-24, 24);
			bgGrid.alpha = 0.13;
			add(bgGrid);
		}

		menuItems = new FlxTypedGroup<FlxSprite>();
		for (o in optionShit)
		{
			final optData:MenuOpt = haxe.Json.parse(Paths.getTextFromFile('${datasPath}opt_$o.json'));

			var item:FlxSprite = createMenuItem(o, 30, -200 / ((optionShit.length / 2) - 1), optData);
			if (bgGrad != null) menuColors.push(CoolUtil.dominantColor(item));

			createRender(optData.render);
		}

		var overlay:FlxSprite = new FlxSprite(0, 0, Paths.image('mainmenu/overlay'));
		overlay.setGraphicSize(FlxG.width, FlxG.height); overlay.updateHitbox();
		overlay.screenCenter();
		overlay.active = false;
		overlay.antialiasing = ClientPrefs.data.antialiasing;
		add(overlay);
		add(menuItems);

		var psychVer:FlxText = new FlxText(0, 0, 0, 'Funkin\' Verade V${lime.app.Application.current.meta["version"]}\nPsych V1.0.4');
		psychVer.setFormat(Paths.font("fraiche.ttf"), 24, FlxColor.WHITE, RIGHT);
		psychVer.setBorderStyle(OUTLINE_FAST, FlxColor.BLACK, 1.5);
		psychVer.setPosition(
			(FlxG.width - psychVer.width) - psychVer.size, 
			(FlxG.height - psychVer.height) - (psychVer.size / 2)
		);
		psychVer.active = false;
		psychVer.antialiasing = true;
		add(psychVer);
		
		#if mobile
		controls.isInSubstate = false;
		addVirtualPad(UP_DOWN, A_B);
		#end

		changeItem(0);
		beatHit(); // Em caso de vc entrar no menu sem a música tar na batida, pelo menos um bop vai ocorrer. De nada :3 	-@BernardoGP4504

		controllerCursor = new GamepadCursor();
		add(controllerCursor);
	}

	function createMenuItem(name:String, x:Float, y:Float, data:MenuOpt):FlxSprite
	{
		final defScale:Float = 1.35 / optionShit.length;

		var spr:FlxSprite = new FlxSprite(x, y);
		spr.frames = Paths.getSparrowAtlas('mainmenu/options/$name', false);
		spr.animation.addByPrefix('idle', 'NaoSelecionado', 0, false);
		spr.animation.addByPrefix('selected', 'Selecionado', 24);
		spr.animation.play('idle');

		spr.scale.set(defScale * data.scale, defScale * data.scale); spr.updateHitbox();
		spr.y += ((spr.height * spr.scale.y) * optionShit.indexOf(name)) + 90;
		spr.offset.add(-data.offset[0], -data.offset[1]);

		spr.antialiasing = ClientPrefs.data.antialiasing;
		menuItems.add(spr);
		return spr;
	}

	function createRender(data:RenderData)
	{
		data.originAlign ??= AlignType.CENTER;

		var spr:FlxSprite = new FlxSprite(FlxG.width / 2.5, 0, Paths.image('mainmenu/renders/${data.imageName}'));
		spr.scale.set(data.scale, data.scale); spr.updateHitbox();
		spr.screenCenter(Y);
		spr.active = false;
		spr.visible = false;
		spr.antialiasing = true;

		final originOffsets:Array<Float> = switch (data.originAlign)
		{
			case CENTER: [0.5, 0.5];
			case BOTTOM_LEFT: [0.2, 0.8];
			case BOTTOM_RIGHT: [0.8, 0.8];
			case TOP_LEFT: [0.2, 0.2];
			case TOP_RIGHT: [0.8, 0.2];
		};
		spr.origin.set(spr.frameWidth * originOffsets[0], spr.frameHeight * originOffsets[1]);
		spr.offset.set(-data.offset[0], -data.offset[1]);

		if (data.imageName == 'ohwow_theymadethis')
		{
			deivHitbox = new FlxObject(spr.x, spr.y, 147 * data.scale, 206 * data.scale);
			deivHitbox.x -= (data.offset[0] * 1.5);
			deivHitbox.y += (spr.height - deivHitbox.height) + data.offset[1];
			deivHitbox.active = false;
			deivHitbox.visible = false;
			add(deivHitbox);
		}

		renderSprs.push(spr);
		if (!ClientPrefs.data.lowQuality) renderScales.push(data.scale);
		add(spr);
	}

	override function update(elapsed:Float)
	{
		if (selectedSomethin)
		{
			super.update(elapsed);
			return;
		}
		if (FlxG.sound.music?.playing) Conductor.songPosition = FlxG.sound.music.time;
		FlxG.mouse.getGamePosition(curMousePos);

		if (FlxG.gamepads.anyInput()) controls.controllerMode = true;
		else if (FlxG.keys.justPressed.ANY || (!CoolUtil.pointsAreEqual(curMousePos, lastMousePos) || FlxG.mouse.justPressed)) controls.controllerMode = false;

		controllerCursor.visible = deivHitbox.visible && controls.controllerMode;
		FlxG.mouse.visible = deivHitbox.visible && !controls.controllerMode;
		final deivMouseCheck:Bool = !controls.controllerMode ? (FlxG.mouse.visible && FlxG.mouse.overlaps(deivHitbox) && FlxG.mouse.justPressed) : (controllerCursor.visible && controllerCursor.overlaps(deivHitbox) && controls.ACCEPT);

		var up_p:Bool = FlxG.keys.anyJustPressed(controls.keyboardBinds['ui_up']) || FlxG.gamepads.anyJustPressed(DPAD_UP) #if mobile || virtualPad.buttonUp.justPressed #end;
		var down_p:Bool = FlxG.keys.anyJustPressed(controls.keyboardBinds['ui_down']) || FlxG.gamepads.anyJustPressed(DPAD_DOWN) #if mobile || virtualPad.buttonDown.justPressed #end;
		if (up_p || down_p)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'));
			changeItem(up_p ? -1 : 1);
		}

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound("cancelMenu"));
			MusicBeatState.customTransClass = prevTransition;
			FlxG.switchState(() -> new TitleState());
		}
		if (controls.ACCEPT && (!controls.controllerMode || !deivMouseCheck)) chooseItem();

		#if debug
		if (FlxG.keys.justPressed.F5) FlxG.resetState();
		#end
		#if EDITORS_ALLOWED
		if (controls.justPressed('debug_1'))
		{
			selectedSomethin = true;

			var editorsMenu:flixel.FlxSubState = new states.editors.MasterEditorMenu();
			editorsMenu.closeCallback = () -> selectedSomethin = false;
			openSubState(editorsMenu);
		}
		#end

		if (deivHitbox != null && deivMouseCheck)
		{
			if (!Achievements.achievementsUnlocked.contains('deivCameo')) Achievements.unlock('deivCameo');
			else FlxG.sound.play(Paths.sound('plushie'));
		}

		super.update(elapsed);
		FlxG.mouse.getGamePosition(lastMousePos);
		FlxG.watch.addQuick("lastPressedEaster", eggsLastClues);
		FlxG.watch.addQuick("lastTypedEaster", eggsLastGuesses);

		if (renderScales.length == 0) return;
		renderSprs[curSelected].scale.set(
			FlxMath.lerp(renderScales[curSelected], renderSprs[curSelected].scale.x, Math.exp(-elapsed * lerpSpeed)),
			FlxMath.lerp(renderScales[curSelected], renderSprs[curSelected].scale.y, Math.exp(-elapsed * lerpSpeed))
		);
	}

	override function beatHit()
	{
		if (curBeat % bopInterval != 0 || renderScales.length == 0) return;
		renderSprs[curSelected].scale.add(0.024, 0.024);
	}

	function huntForEgg(egg:Void->Void, eggId:Int, clues:String)
	{
		final keyPress:FlxKey = FlxG.keys.firstJustPressed();
		final canUseMoreEggs:Bool = EasterEggHandler.currentEggs.length == 0 || EasterEggHandler.currentEggs.length == EasterEgg.repeatable.length;
		if (keyPress == -1 || !canUseMoreEggs) return;

		var eachClue:Array<String> = clues.split("");
		function resetProgress()
		{
			eggsLastClues[eggId] = -1;
			eggsLastGuesses[eggId] = "";
		}

		if (keyPress == FlxKey.fromString(eachClue[eggsLastClues[eggId] + 1]))
		{
			eggsLastGuesses[eggId] += eachClue[++eggsLastClues[eggId]];
			FlxG.sound.play(Paths.soundRandom('typing/', 1, 3), 0.5);
		}
		else if (~/^[a-z]$/i.match( FlxKey.fromString(keyPress) ))
		{
			final youreLikelyWrong:Bool = eggsLastGuesses.indexOf("", eggId) != eggId && Lambda.count(eggsLastGuesses, (g) -> g.length == 0) < eggsLastGuesses.length;

			// Sound check incase the "likely wrong" prediction failed (aka eggs including this starting with a shared letter and another letter is typed)
			if (youreLikelyWrong && !CoolUtil.isSoundPlaying()) FlxG.sound.play(Paths.sound('typing/wrong'), 0.75);
			resetProgress();
		}

		if (eggsLastGuesses[eggId] == clues.toLowerCase() && canUseMoreEggs)
		{
			// Cleanup
			resetProgress();
			eachClue.resize(0);

			egg();
			FlxG.sound.play(Paths.sound('secret'));
			for (c in 0...eggsLastClues.length) eggsLastClues[c] = -1;
			for (g in 0...eggsLastGuesses.length) eggsLastGuesses[g] = "";
		}
	}

	override function destroy()
	{
		for (i in selectionShit.keys()) selectionShit[i].resize(0);
		selectionShit.clear();

		optionShit.resize(0);
		menuColors.resize(0);
		renderSprs.resize(0);
		renderScales.resize(0);

		// "Easter Hunt" cleanup
		for (i in 0...eggHunts.length)
		{
			FlxG.signals.postUpdate.remove(eggHunts[i]);
			eggHunts[i] = null;
		}
		for (i in easterEggs.keys()) easterEggs[i] = null;

		easterEggs.clear();
		eggHunts.resize(0);
		eggsLastClues.resize(0);
		eggsLastGuesses.resize(0);

		FlxG.signals.postUpdate.remove(EasterEggHandler.onUpdate);
		EasterEggHandler.onDestroy();

		lastMousePos.put();
		curMousePos.put();
		super.destroy();
	}

	function changeItem(change:Int)
	{
		menuItems.members[curSelected].animation.play("idle");
		renderSprs[curSelected].visible = false;

		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
		menuItems.members[curSelected].animation.play("selected");

		renderSprs[curSelected].visible = true;
		if (menuColors.length != 0) bgGrad.color = menuColors[curSelected];
		deivHitbox.visible = curSelected == 2;
	}

	function chooseItem()
	{
		inline function unchooseItem()
		{
			FlxG.sound.play(Paths.sound("cancelMenu"));
			FlxG.log.warn('"${optionShit[curSelected]}" doesn\'t do anything');
		}

		if (!selectionShit.exists(curSelected))
		{
			unchooseItem();
			return;
		}

		final classFromStr:Class<flixel.FlxState> = cast Type.resolveClass(selectionShit[curSelected][0]);
		if (classFromStr == null)
		{
			unchooseItem();
			return;
		}

		selectedSomethin = true;
		FlxG.sound.play(Paths.sound("confirmMenu"));

		flixel.effects.FlxFlicker.flicker(menuItems.members[curSelected], 1, 0.06, true, true, (_) -> 
			__getToNextState(() -> Type.createInstance(classFromStr, []), (selectionShit[curSelected].length % 2 != 0) ? Reflect.field(this, selectionShit[curSelected][1]) : null, selectionShit[curSelected][selectionShit[curSelected].length - 1])
		);

		FlxTween.num(1, 0, 0.4, {ease: FlxEase.quadOut}, function(a) for (i in 0...menuItems.members.length)
			if (i != curSelected) menuItems.members[i].alpha = a);
	}

	@:noCompletion function __getToNextState(state:NextState, ?preloadPrep:haxe.Constraints.Function, transition:String)
	{
		MusicBeatState.customTransClass = transition;
		if (preloadPrep == null)
		{
			FlxG.switchState(state);
			return;
		}

		Reflect.callMethod(this, preloadPrep, []);
		LoadingState.loadAndSwitchState(state.createInstance(), true);
	}

	#if DEMO
	@:noCompletion function preparePlayState()
	{
		WeekData.reloadWeekFiles(true); // WeekData.weeksList doesn't get set until we do this
		PlayState.storyPlaylist = [for (s in WeekData.getCurrentWeek().songs) s[0]]; // Make sure to set PlayState.currentWeek beforehand or it'll grab the first week
		PlayState.isStoryMode = true;

		Song.loadFromJson(PlayState.storyPlaylist[0], 'songs/${PlayState.storyPlaylist[0]}');
		PlayState.campaignScore = 0;
		PlayState.campaignMisses = 0;
		LoadingState.prepareToSong();
	}
	#end
}

@:access(states.MainMenuState)
private class EasterEggHandler
{
	public static var state:MainMenuState;
	public static var currentEggs(default, null):Array<EasterEgg> = [];

	static var abels:Array<FlxSprite> = [];
	static var abelFallVel(default, null):FlxPoint;
	static var abelJumpVel(default, null):FlxPoint;

	static var canSkipJabuticaba:Bool;
	static var white:FlxSprite;
	static var jabuticaba:FlxSprite;
	static var jabuticabaSnd:FlxSound;

	static inline final voluntariaPath:String = 'characters/voluntaria';
	static var voluntariaPathRAW:String = Paths.getSharedPath('images/');

	/**
	 * Does precaching and initializes stuff if needed.
	 */
	public static function init()
	{
		abelFallVel = FlxPoint.get(0, 280);
		abelJumpVel = FlxPoint.get(28 -0.24);
		Paths.cacheBitmap('images/credits/abel.png');

		Paths.image('TROUXACAIUNOPAPO');
		Paths.returnSound('music/secret', true, false);

		Paths.cacheBitmap('images/JABUTICABA.png');
		Paths.returnSound('music/invincible', true, false);

		if (!voluntariaPathRAW.contains(voluntariaPath)) voluntariaPathRAW += voluntariaPath;
		Paths.cacheBitmap('images/$voluntariaPath/agm/agm.png');
		for (asset in Assets.list())
		{
			if (StringTools.startsWith(asset, voluntariaPathRAW) && StringTools.endsWith(asset.toLowerCase(), '.png'))
			{
				var parts = asset.split('/');
				var fileName = parts[parts.length - 1];
				Paths.cacheBitmap('images/$voluntariaPath/$fileName');
			}
		}
		
		/*for (f in FileSystem.readDirectory(voluntariaPathRAW))
		{
			if (!f.endsWith('.png')) continue;
			Paths.cacheBitmap('images/$voluntariaPath/$f');
		}*/

		Paths.returnSound('sounds/VOLUNTARIA RS', true, false);
		Paths.returnSound('music/ohShit', true, false);
	}

	public static function spawnAbels()
	{
		if (!currentEggs.contains(EasterEgg.ABEL)) currentEggs.push(EasterEgg.ABEL);
		#if ACHIEVEMENTS_ALLOWED Achievements.unlock("abel.webp"); #end

		var abel:FlxSprite = new FlxSprite(0, 0, Paths.image('credits/abel'));
		abel.scale.set(0.1, 0.1); abel.updateHitbox();

		final posX:Float = FlxG.random.float(40, (FlxG.width - abel.width) - 40);
		final posY:Float = FlxG.random.float(40, (FlxG.height - abel.height) - 40);
		abel.setPosition(posX, posY);
		abels.push(abel);

		abel.velocity.set(abelFallVel.x, abelFallVel.y);
		abel.drag.set(0, 15);
		state.add(abel);
	}

	public static function broGotBaited()
	{
		currentEggs.push(EasterEgg.AZEDO);
		state.selectedSomethin = true; // Desabilitar qualquer input que pode quebrar tudo

		var azedou:FlxSprite = new FlxSprite(0, 0, Paths.image('TROUXACAIUNOPAPO'));
		azedou.setGraphicSize(FlxG.width * 1.4, FlxG.height); azedou.updateHitbox();
		azedou.screenCenter();
		azedou.active = false;
		state.add(azedou);

		var bestSong:FlxSound = FlxG.sound.play(Paths.music('secret'), 0.85);
		FlxG.sound.music.pause();

		FlxTimer.wait(20, () -> 
		{
			state.selectedSomethin = false;
			currentEggs.pop();

			state.remove(azedou, true); azedou.destroy();
			bestSong.stop(); FlxG.sound.music.resume();
		});
	}

	public static function jabuticabaSequence()
	{
		currentEggs.push(EasterEgg.JABUTICABA);
		state.selectedSomethin = true;

		white = new FlxSprite().makeGraphic(1, 1, ClientPrefs.data.flashing ? FlxColor.WHITE : FlxColor.GRAY);
		white.setGraphicSize(FlxG.width * 1.1, FlxG.height * 1.1); white.updateHitbox();
		white.screenCenter();
		white.active = false;
		state.add(white);

		jabuticaba = new FlxSprite(0, 0, Paths.image('JABUTICABA'));
		jabuticaba.scale.set(1.22, 1.22); jabuticaba.updateHitbox();
		jabuticaba.screenCenter();
		jabuticaba.visible = false;
		jabuticaba.active = false;
		state.add(jabuticaba);

		FlxG.sound.playMusic(Paths.music('invincible'), false);
		FlxG.sound.music.onComplete = skipJabuticaba;
		FlxTimer.wait(11, () -> 
		{
			jabuticabaSnd = FlxG.sound.play(Paths.sound('lindo'), false, false);
			jabuticaba.visible = true;
			canSkipJabuticaba = true;
		});
	}

	public static function agmRef()
	{
		currentEggs.resize(0);
		currentEggs.push(EasterEgg.ALGORITHOMUS);

		final screenSize:Float = FlxG.width * 1.2;
		state.selectedSomethin = true;
		FlxG.sound.playMusic(Paths.music('ohShit'), false);

		var agmBG:FlxSprite = new FlxSprite(0, 0, Paths.image('$voluntariaPath/agm/agm'));
		agmBG.setGraphicSize(screenSize); agmBG.updateHitbox();
		agmBG.origin.y = 0;
		agmBG.screenCenter(X).y -= agmBG.height + 10;
		agmBG.x += 15;
		agmBG.active = false;
		agmBG.antialiasing = true;
		state.add(agmBG);

		var agm:flxanimate.FlxAnimate = new flxanimate.FlxAnimate(670, 640);
		agm.loadAtlas(voluntariaPathRAW);
		agm.anim.addBySymbol('agm', "Símbolo 1", 24, false);
		agm.setGraphicSize(screenSize); agm.updateHitbox();
		agm.antialiasing = ClientPrefs.data.antialiasing;
		state.add(agm);

		FlxTween.tween(agmBG, {"scale.y": 5.5}, 7.45);
		agm.anim.play('agm');

		agm.anim.onFrame.add((f) -> 
		{
			if (f != 85) return;
			final strongLaugh:Bool = FlxG.random.bool();

			var laugh:FlxSound = FlxG.sound.play(Paths.sound('VOLUNTARIA RS'), false, false);
			if (strongLaugh) laugh.time = 4000;
			else laugh.endTime = 2000;
		});
		agm.anim.onComplete.addOnce(FlxG.resetGame);
	}

	static function skipJabuticaba()
	{
		currentEggs.pop();
		canSkipJabuticaba = false;
		state.selectedSomethin = false;

		state.remove(white); white.destroy();
		state.remove(jabuticaba); jabuticaba.destroy();
		CoolUtil.playMenuSongForce(1);
	}

	public static function onUpdate()
	{
		if (currentEggs.contains(EasterEgg.ABEL))
			for (i=>abel in abels)
			{
				var bounds:flixel.math.FlxRect = FlxG.camera.getViewMarginRect();
				FlxG.watch.addQuick("cam bounds for abel", bounds);

				final abelHeight:Float = abel.y + abel.height;
				final abelWidth:Float = abel.x + abel.width;

				if (abelHeight >= bounds.bottom)
				{
					FlxTween.tween(abel, {y: abel.y - 12}, 0.23, {ease: FlxEase.backOut, type: PINGPONG});
					abel.velocity.set(abelJumpVel.x, abelJumpVel.y);
				}

				if (abelWidth >= bounds.right)
				{
					FlxTween.tween(abel, {x: abel.x - 12, "scale.x": -abel.scale.x}, 0.23, {ease: FlxEase.backOut, onStart: (_) -> abelJumpVel.x *= -1});
				}
				if (abel.x <= bounds.left)
				{
					FlxTween.tween(abel, {x: abel.x + 12, "scale.x": -abel.scale.x}, 0.23, {ease: FlxEase.backOut, onStart: (_) -> abelJumpVel.x *= -1});
				}
			}

		if (!currentEggs.contains(EasterEgg.JABUTICABA)) return;
		if (canSkipJabuticaba && FlxG.keys.justPressed.ANY)
		{
			if (!jabuticabaSnd?.playing)
			{
				if (jabuticabaSnd == null)
				{
					jabuticabaSnd = FlxG.sound.play(Paths.sound('lindo'), skipJabuticaba);
					jabuticabaSnd.endTime = 1849;
				}
				else
				{
					jabuticabaSnd.onComplete = skipJabuticaba;
					jabuticabaSnd.play(true, 0, 1849);
				}
			}
			else
				skipJabuticaba();
		}
	}

	public static function onDestroy()
	{
		for (abel in abels)
		{
			state.remove(abel, true);
			abel.destroy();
		}
		abels.resize(0);
		abelFallVel.put();
		abelJumpVel.put();

		currentEggs.resize(0);
	}
}