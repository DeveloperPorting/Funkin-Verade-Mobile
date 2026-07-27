package states;

import openfl.display.BitmapData;
import objects.Bar;
import flixel.group.FlxContainer.FlxTypedContainer;
import openfl.geom.Point;

class TonhoAchievementsState extends MusicBeatState
{
	var achievesData:Array<Achievement> = [];
	var achieves:Array<String> = [];

	static var curSelected:Int = 0;
	var blockInput:Bool = false;

	static final COLUMNS_COUNT:Int = 4;
	static final MAGIC_MARGIN:Int = 12;
	var achieveSprites:FlxTypedContainer<FlxSprite>;
	var achieveBmps:Array<BitmapData> = [];
	var selectionShine:FlxSprite;
	var selectionSpr:FlxSprite;
	var spotlight:FlxSprite;

	var achieveText:FlxText;
	var achieveProgress:Bar;
	var achieveProgressTxt:FlxText;

	var globalAchieveProgress:Float;
	var fakeAchieveProgress:Float;
	var globalAchieveProgressTxt:FlxText;

	public function new()
	{
		for (n=>a in Achievements.achievements)
		{
			if (a.hidden && !Achievements.isUnlocked(n)) continue;

			achievesData.push(a);
			achieves.push('${a.ID}$n');
		}

		achievesData.sort((a1, a2) -> flixel.util.FlxSort.byValues(flixel.util.FlxSort.ASCENDING, a1.ID, a2.ID));
		achieves.sort((n1, n2) ->
		{
			final id1:String = ~/[a-z]/i.split(n1)[0];
			final id2:String = ~/[a-z]/i.split(n2)[0];

			flixel.util.FlxSort.byValues(flixel.util.FlxSort.ASCENDING, Std.parseInt(id1), Std.parseInt(id2));
		});
		for (i in 0...achieves.length) achieves[i] = ~/[0-9]+/.replace(achieves[i], "");

		curSelected = FlxMath.wrap(curSelected, 0, achievesData.length - 1); // You never know
		@:privateAccess
		globalAchieveProgress = FlxMath.remapToRange(Achievements.achievementsUnlocked.length, 0, Achievements._originalLength - 1, 0, 100);
		super();
	}

	override function create()
	{
		FlxG.mouse.visible = false;
		#if DISCORD_ALLOWED DiscordClient.changePresence("Checking Progression", "Achievements Menu"); #end
		super.create();

		var bg:FlxSprite = new FlxSprite(0, 0, Paths.image('achievements/menu/bg'));
		bg.setGraphicSize(0, FlxG.height); bg.updateHitbox();
		bg.screenCenter(Y).x = FlxG.width - bg.width;
		bg.active = false;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		
		if (!ClientPrefs.data.lowQuality)
		{
			spotlight = new FlxSprite(0, 0, Paths.image('achievements/menu/spotlight'));
			spotlight.scale.x = 1.5;
			spotlight.x = FlxG.width - spotlight.width;
			spotlight.blend = SCREEN;
			spotlight.active = false;
			spotlight.alpha = spotlight.alpha = 0.0001;
			spotlight.antialiasing = ClientPrefs.data.antialiasing;
			add(spotlight);
		}

		var overlay:FlxSprite = new FlxSprite(0, 0, Paths.image('achievements/menu/achieveBG'));
		overlay.setGraphicSize(0, FlxG.height); overlay.updateHitbox();
		overlay.screenCenter(Y);
		overlay.active = false;
		overlay.antialiasing = ClientPrefs.data.antialiasing;
		add(overlay);

		achieveSprites = new FlxTypedContainer<FlxSprite>();
		add(achieveSprites);

		var row:Int = 0;
		for (i=>d in achievesData)
		{
			if (i >= COLUMNS_COUNT * (row + 1)) row++;
			createAchieveSpr(d, achieves[i], i, row);
		}

		selectionShine = new FlxSprite().makeGraphic(Math.round(achieveSprites.members[0].width + MAGIC_MARGIN), Math.round(achieveSprites.members[0].height + MAGIC_MARGIN));
		selectionShine.offset.set(MAGIC_MARGIN / 2, MAGIC_MARGIN / 2);
		selectionShine.alpha = 0.42;
		selectionShine.active = false;
		selectionShine.setSize(0, 0); // No hitbox wanted
		insert(members.indexOf(achieveSprites), selectionShine);

		final overlayWidth:Float = (overlay.x + overlay.width); 
		achieveText = new FlxText(overlayWidth - MAGIC_MARGIN, 0, FlxG.width - overlayWidth);
		achieveText.setFormat(Paths.font("fraiche.ttf"), (MAGIC_MARGIN * 3), FlxColor.WHITE, CENTER);
		achieveText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2.25);
		achieveText.antialiasing = true;
		add(achieveText);

		selectionSpr = new FlxSprite();
		selectionSpr.antialiasing = ClientPrefs.data.antialiasing;
		selectionSpr.active = false;

		achieveProgress = new Bar(0, FlxG.height - (MAGIC_MARGIN * 5), "timeBar");
		achieveProgress.x = (FlxG.width - achieveProgress.width) - (MAGIC_MARGIN * 2);
		add(achieveProgress);

		achieveProgressTxt = new FlxText(0, 0, achieveProgress.width / 2);
		achieveProgressTxt.setFormat(Paths.font("fraiche.ttf"), Math.round(MAGIC_MARGIN * 3), 0xFFB57AF4, RIGHT);
		achieveProgressTxt.setBorderStyle(OUTLINE_FAST, FlxColor.BLACK, 3);
		achieveProgressTxt.x = (achieveProgress.x + achieveProgress.width) - (achieveProgressTxt.width - 10);
		achieveProgressTxt.antialiasing = true;
		add(achieveProgressTxt);

		globalAchieveProgressTxt = new FlxText(0, MAGIC_MARGIN * 2, bg.width / 2, "0%");
		globalAchieveProgressTxt.setFormat(Paths.font("tardling.ttf"), MAGIC_MARGIN * 5, FlxColor.WHITE, CENTER);
		globalAchieveProgressTxt.setBorderStyle(OUTLINE_FAST, FlxColor.BLACK, 1.5);
		globalAchieveProgressTxt.x = (bg.x + ((bg.width / 2) - (globalAchieveProgressTxt.width / 2))) + (MAGIC_MARGIN * 4);
		globalAchieveProgressTxt.antialiasing = true;
		add(globalAchieveProgressTxt);
		
		#if mobile
		addVirtualPad(LEFT_FULL, A_B);
		#end

		changeSelection(0);
		selectionSpr.x = (achieveText.x + (achieveText.width / 2)) - (selectionSpr.width / 2);
		add(selectionSpr);
	}

	override function finishTransIn()
	{
		super.finishTransIn();

		if (spotlight == null) return;
		FlxTween.tween(spotlight, {alpha: FlxMath.remapToRange(globalAchieveProgress, 0, 100, 0, 1)}, 0.67, {ease: FlxEase.quartIn});
	}

	function createAchieveSpr(achieve:Achievement, achieveId:String, pos:Int, row:Int)
	{
		var icon:String = 'achievements/${achieve.icon}';
		if (!Paths.fileExists('images/$icon.png', IMAGE) && !Paths.fileExists('images/${icon += '-pixel'}.png', IMAGE)) icon = "menu/unknownAchieve";

		var achieveBmp:BitmapData = (Paths.image(icon, false).bitmap).clone(); // Paths.hx caches images forcefully, and we wouldnt want an effect applied double
		if (!Achievements.isUnlocked(achieveId))
		{
			achieveBmp.colorTransform(achieveBmp.rect, new openfl.geom.ColorTransform(0.45, 0.45, 0.45));

			final scaling:Float = 1.5;
			var lockGph:openfl.display.BitmapData = Paths.image('achievements/menu/lock', false).bitmap;

			lockGph.image.resize(Math.round(lockGph.width * scaling), Math.round(lockGph.height * scaling));
			achieveBmp.copyPixels(lockGph, new openfl.geom.Rectangle(0, 0, lockGph.image.width, lockGph.image.height), new Point(
				// I dislike how specific these offsets are, like seriously wtf
				((achieveBmp.width / 2) / scaling) - (MAGIC_MARGIN / 2),
				((achieveBmp.height / 2) / Math.round(scaling)) - MAGIC_MARGIN
			), null, null, true);
		}
		achieveBmps.push(achieveBmp);

		var achieveSpr:FlxSprite = new FlxSprite(40, 54, achieveBmp);
		achieveSpr.scale.set(0.7, 0.7); achieveSpr.updateHitbox();
		achieveSpr.x += (achieveSpr.width + MAGIC_MARGIN) * (pos % COLUMNS_COUNT);
		achieveSpr.y += (achieveSpr.height + (MAGIC_MARGIN * 3)) * row;
		achieveSpr.active = false;
		achieveSpr.antialiasing = ClientPrefs.data.antialiasing && !icon.endsWith('-pixel');
		achieveSprites.add(achieveSpr);
	}

	override function update(elapsed:Float)
	{
		fakeAchieveProgress = FlxMath.lerp(fakeAchieveProgress, globalAchieveProgress, Math.exp(-elapsed * 2));
		if (Math.abs(fakeAchieveProgress - globalAchieveProgress) <= 0.01) fakeAchieveProgress = globalAchieveProgress;

		globalAchieveProgressTxt.text = '${CoolUtil.floorDecimal(fakeAchieveProgress, 2)}%';

		if (blockInput)
		{
			super.update(elapsed);
			return;
		}

		if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'));
			changeSelection(controls.UI_LEFT_P ? -1 : 1);
		}
		if (controls.UI_UP_P || controls.UI_DOWN_P)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'));
			changeSelection(COLUMNS_COUNT * (controls.UI_UP_P ? -1 : 1));
		}

		if (controls.BACK)
		{
			blockInput = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));

			FlxG.switchState(() -> new MainMenuState());
		}

		// If you messed up on coding achieves, this resets 'em
		// TODO: Add a confirmation substate (prompt) to make this public
		#if debug
		if (controls.RESET)
		{
			blockInput = true;

			Achievements.variables.clear(); FlxG.save.data.achievementsVariables = null;
			Achievements.achievementsUnlocked.resize(0); FlxG.save.data.achievementsUnlocked = null;
			@:privateAccess Achievements._firstLoad	= true;

			FlxG.save.flush();
			FlxG.switchState(TonhoAchievementsState.new); // I think it's cause of the reflection stuff in MainMenuState.hx
		}
		#end

		super.update(elapsed);
	}

	function changeSelection(change:Int)
	{
		achieveProgress.valueFunction = null;
		achieveProgressTxt.text = "N/A";

		curSelected = FlxMath.wrap(curSelected + change, 0, achieveSprites.length - 1);
		selectionShine.setPosition(achieveSprites.members[curSelected].x, achieveSprites.members[curSelected].y);

		achieveText.text = '${achievesData[curSelected].name}\r\n${achievesData[curSelected].description}';
		achieveText.y = (achieveProgress.y - achieveText.height) - 25;

		selectionSpr.loadGraphic(achieveBmps[curSelected]);
		selectionSpr.scale.set(0.78, 0.78); selectionSpr.updateHitbox();
		selectionSpr.y = (achieveText.y - selectionSpr.height) - MAGIC_MARGIN;

		if (achievesData[curSelected].maxScore != null)
		{
			final curVal:Float = (achievesData[curSelected].maxDecimals > 0) ? CoolUtil.floorDecimal(Achievements.getScore(achieves[curSelected]), achievesData[curSelected].maxDecimals) : Achievements.getScore(achieves[curSelected]);
			final maxVal:Float = (achievesData[curSelected].maxDecimals > 0) ? CoolUtil.floorDecimal(achievesData[curSelected].maxScore, achievesData[curSelected].maxDecimals) : achievesData[curSelected].maxScore;
			achieveProgress.valueFunction = () -> curVal;
			achieveProgress.bounds.max = maxVal;

			achieveProgressTxt.text = '$curVal/$maxVal';
		}
		achieveProgress.visible = achieveProgress.valueFunction != null;

		achieveProgressTxt.visible = achieveProgress.visible;
		achieveProgressTxt.y = achieveProgress.y - (achieveProgressTxt.height / 4);
	}

	override function destroy()
	{
		for (b in achieveBmps)
		{
			b.dispose();
			b = null;
		}
		achieveBmps.resize(0);

		achievesData.resize(0);
		achieves.resize(0);
		super.destroy();
	}
}