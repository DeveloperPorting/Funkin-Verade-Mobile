package states;

import objects.GamepadCursor;
import objects.AttachedSprite;
import flixel.group.FlxContainer.FlxTypedContainer;
import openfl.utils.Assets;
import mobile.backend.utils.TouchUtil;

private typedef CredEntry =
{
	name:String,
	?frameChar:PaintingCharacter,

	role:String,
	doings:String, // Lista doq fez
	?quote:String, // Frasezinha opicional

	?socials:Array<SocialHandle>,
}

private typedef SocialHandle =
{
	display:String,
	link:String,
	social:String
}

private enum abstract SocialMediaType(String) from String to String
{
	public static final TWITTER:String = "Xwitter";
	public static final DISCORD:String = "Discord";
	public static final YT:String = "YouTube";
	public static final NG:String = "Newgrounds";
	public static final BSKY:String = "BlueSky";
	public static final REDDIT:String = "Reddit";
	public static final TTK:String = "TikTok";
	public static final CARRD:String = "Carrd";
	public static final OTHER:String = "Link";
}

private enum abstract PaintingCharacter(String) from String to String
{
	public static final TORAJO:String = "torajo";
	public static final MORAJO:String = "morajo";
	public static final ZULMI:String = "zulmi";
	public static final LINN:String = "linn";
	public static final AZEDO:String = "azedo";
	public static final PESSY:String = "pessy";
}

private class SocialMedia
{
	private var _data:SocialHandle;
	public var social(default, null):SocialMediaType = SocialMediaType.OTHER;

	public function new(data:SocialHandle)
	{
		_data = data;
		social = socialFromString(_data.social);
	}

	public static inline function socialFromString(string:String):SocialMediaType
	{
		return switch (string.toLowerCase())
		{
			case "twitter": SocialMediaType.TWITTER;
			case "dc": SocialMediaType.DISCORD;
			case "yt": SocialMediaType.YT;
			case "ng": SocialMediaType.NG;
			case "bsky": SocialMediaType.BSKY;
			case "reddit": SocialMediaType.REDDIT;
			case "tiktok": SocialMediaType.TTK;
			case "carrd": SocialMediaType.CARRD;
			default: SocialMediaType.OTHER;
		};
	}

	public inline function getWebsite():String
	{
		return switch (social)
		{
			case SocialMediaType.TWITTER: 'x.com/${_data.link}';
			case SocialMediaType.DISCORD: #if !mobile 'discord://-/users/${_data.link}' #else 'discord.com/users/${_data.link}' #end; // Abre no app do Discord, se possível
			case SocialMediaType.YT: 'youtube.com/@${_data.link}';
			case SocialMediaType.NG: '${_data.link}.newgrounds.com';
			case SocialMediaType.BSKY: 'bsky.app/profile/${_data.link}';
			case SocialMediaType.REDDIT: 'reddit.com/user/${_data.link}';
			case SocialMediaType.TTK: 'tiktok.com/@${_data.link}';
			case SocialMediaType.CARRD: '${_data.link}.carrd.co';
			default: _data.link;
		};
	}

	public inline function getAccName():String { return _data.display ?? '@${_data.link}'; }
	public inline function toString():String { return 'Social Media: $social(${_data.link})'; }
}

class TonhoCreditsState extends MusicBeatState
{
	var creds:Array<CredEntry> = [];
	var colors:Map<String, Array<FlxColor>> =
	[ // As setas já possuem as cores dos principais
		PaintingCharacter.TORAJO => [ClientPrefs.defaultData.arrowRGB[2][0], ClientPrefs.defaultData.arrowRGB[2][2]],
		PaintingCharacter.MORAJO => [ClientPrefs.defaultData.arrowRGB[1][0], ClientPrefs.defaultData.arrowRGB[1][2]],
		PaintingCharacter.LINN => [ClientPrefs.defaultData.arrowRGB[0][0], ClientPrefs.defaultData.arrowRGB[0][2]],
		PaintingCharacter.ZULMI => [ClientPrefs.defaultData.arrowRGB[3][0], ClientPrefs.defaultData.arrowRGB[3][2]],
		PaintingCharacter.AZEDO => [0xFF277017, 0xFF874DF7],
		PaintingCharacter.PESSY => [0xFFFE992F, 0xFF2C1B9F],
		"default" => [0xFFADADAD, 0xFF3F3F3F]
	];
	var socialDatas:Array<Array<SocialMedia>> = [];
	var prevSocials:Array<SocialMediaType> = []; // Used for avoiding less calls to `FlxSprite.loadGraphic`
	static var curSelected:Int;
	static var firstChange:Bool = true;

	var blockInput:Bool;
	var usingController:Bool = false;
	var controllerCursor:GamepadCursor;
	var lastMousePos:FlxPoint = new FlxPoint();
	var curMousePos:FlxPoint = new FlxPoint();

	static var alreadyIntrodid:Bool;
	static inline final MAGIC_MARGIN:Int = 12;
	var portraitGroup:FlxTypedContainer<FlxSprite>;
	var camFollow:flixel.FlxObject;
	var gradColor:shaders.RGBPalette;
	var infoBG:FlxSprite;

	var arrowUp:FlxSprite; var arrowDown:FlxSprite;
	var startUpPos:Float; var startDownPos:Float;
	var startUpOffs:Float; var startDownOffs:Float;
	static inline final arrowAnimDist:Float = 10;
	static inline final arrowAnimSpeed:Float = 2;
	var arrowFloatTime:Float = 0;

	var descTxt:FlxText;
	var separator:FlxSprite;
	var social1Ico:AttachedSprite; var social1:FlxText;
	var social2Ico:AttachedSprite; var social2:FlxText;
	static inline final SOCIAL_ICON_SCALE:Float = 0.5;

	var quoteBG:FlxSprite;
	var quoteOffs:Float; // Tamanho da setinha lá do balão
	var lilQuote:FlxText;
	var lilQuoteIMG:FlxSprite;

	public function new()
	{
		creds = haxe.Json.parse(Paths.getTextFromFile('data/menus/credits.json'));
		curSelected = FlxMath.wrap(curSelected, 0, creds.length - 1);

		firstChange = true;
		super();
	}

	inline function playMenuSong()
	{
		Paths.avoidDumping(Paths.getSharedPath('music/creditsMenu.${Paths.SOUND_EXT}')); // Incase you come back here

		FlxG.sound.playMusic(Paths.music('creditsMenu'), alreadyIntrodid ? 0.7 : 0);
		if (!alreadyIntrodid) FlxG.sound.music.fadeIn(4, 0, 0.7);
		Conductor.bpm = 100;
		alreadyIntrodid = true;
	}

	override function create()
	{
		FlxG.mouse.visible = true;
		#if DISCORD_ALLOWED DiscordClient.changePresence("Checking the Team", "Credits Menu"); #end
		playMenuSong();
		super.create();

		var socials:Array<SocialMediaType> = [SocialMediaType.DISCORD, SocialMediaType.YT, SocialMediaType.TWITTER, SocialMediaType.NG];
		for (s in socials) Paths.cacheBitmap('images/credits/socials/$s.png');
		Paths.cacheBitmap('images/achievements/menu/unknownAchieve.png');
		socials.resize(0);

		camFollow = new flixel.FlxObject(0, 0, 1, 1);
		camera.follow(camFollow, LOCKON, 0.6);

		var bg:FlxSprite = new FlxSprite(0, 0, Paths.image('veradeBG'));
		bg.setGraphicSize(FlxG.width, FlxG.height); bg.updateHitbox();
		bg.screenCenter();
		bg.active = false;
		bg.scrollFactor.set();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		if (!ClientPrefs.data.lowQuality)
		{
			gradColor = new shaders.RGBPalette();

			var bgGrad:FlxSprite = new FlxSprite(0, 0, flixel.util.FlxGradient.createGradientBitmapData(1, 255, [FlxColor.RED, FlxColor.BLUE]));
			bgGrad.setGraphicSize(FlxG.width, FlxG.height); bgGrad.updateHitbox();
			bgGrad.screenCenter();
			bgGrad.shader = gradColor.shader;
			bgGrad.blend = MULTIPLY;
			bgGrad.active = false;
			bgGrad.scrollFactor.set();
			add(bgGrad);

			var bgGrid:flixel.addons.display.FlxBackdrop = new flixel.addons.display.FlxBackdrop(flixel.addons.display.FlxGridOverlay.createGrid(20, 20, 40, 40, true, FlxColor.WHITE, FlxColor.TRANSPARENT));
			bgGrid.scale.set(2.5, 2.5); bgGrid.updateHitbox();
			bgGrid.velocity.set(15, 15);
			bgGrid.alpha = 0.13;
			bgGrid.scrollFactor.set();
			add(bgGrid);
		}

		portraitGroup = new FlxTypedContainer<FlxSprite>();
		add(portraitGroup);

		for (i=>e in creds)
		{
			var imgPath:String = 'credits/portraits/${e.name}';
			if (!Paths.fileExists('images/$imgPath.png', IMAGE)) imgPath = 'credits/portraits/TBA';
			e.doings ??= "...Não sei quem é não";
			if (Paths.fileExists('images/${e.quote}', IMAGE)) Paths.cacheBitmap('images/${e.quote}');

			var portrait:FlxSprite = new FlxSprite(0, 0, Paths.image(imgPath));
			portrait.setGraphicSize(670); portrait.updateHitbox();
			portrait.y = (portrait.height + 8) * i;
			portrait.active = false;
			portrait.antialiasing = ClientPrefs.data.antialiasing;
			portraitGroup.add(portrait);

			if (e.socials == null)
			{
				socialDatas.push(null);
				continue;
			}
			socialDatas.push([for (d in e.socials) new SocialMedia(d)]);
		}

		arrowUp = new FlxSprite(0, (startUpPos = 24), Paths.image('credits/arrow'));
		arrowUp.scale.set(0.5, 0.5); arrowUp.updateHitbox();
		arrowUp.x = (50 + (portraitGroup.members[0].width / 2)) - (arrowUp.width / 2);
		arrowUp.active = arrowUp.moves = false;
		arrowUp.antialiasing = ClientPrefs.data.antialiasing;
		arrowUp.scrollFactor.set();
		
		arrowDown = arrowUp.clone();
		arrowDown.scale.copyFrom(arrowUp.scale); arrowDown.updateHitbox();
		arrowDown.setPosition(arrowUp.x, (startDownPos = (FlxG.height - arrowDown.height) - (startUpPos * 2)));
		arrowDown.flipX = arrowDown.flipY = true;
		arrowDown.active = arrowUp.moves = false;
		arrowDown.scrollFactor.set();
		
		startUpOffs = arrowUp.offset.y;
		startDownOffs = arrowDown.offset.y;
		add(arrowUp);
		add(arrowDown);

		infoBG = new FlxSprite(0, 50).makeGraphic(1, 1, FlxColor.BLACK);
		infoBG.setGraphicSize(500, 600); infoBG.updateHitbox();
		infoBG.screenCenter(X).x += portraitGroup.members[0].width / 2;
		infoBG.alpha = 0.4;
		infoBG.active = false;
		infoBG.scrollFactor.set();
		add(infoBG);

		descTxt = new FlxText(infoBG.x + MAGIC_MARGIN, infoBG.y + MAGIC_MARGIN, (infoBG.width/*  - scrollBar.width */) - (MAGIC_MARGIN * 2));
		descTxt.setFormat(Paths.font("fraiche.ttf"), 32, FlxColor.PURPLE, LEFT);
		descTxt.setBorderStyle(OUTLINE_FAST, 0xFF46053C, 2);
		descTxt.antialiasing = true;
		descTxt.scrollFactor.set();
		add(descTxt);

		separator = new FlxSprite().makeGraphic(1, 1);
		separator.setGraphicSize(MAGIC_MARGIN, (150 / 2) + 32); separator.updateHitbox();
		separator.setPosition(infoBG.x + ((infoBG.width / 2) - (separator.width / 2)), (infoBG.y + infoBG.height) - (separator.height + MAGIC_MARGIN));
		separator.alpha = infoBG.alpha / 2;
		separator.active = false;
		separator.scrollFactor.set();
		add(separator);

		social1 = new FlxText(infoBG.x + MAGIC_MARGIN, (infoBG.y + infoBG.height) - 32, (infoBG.width / 2) - (separator.width * 2.5));
		social1.setFormat(Paths.font("tardling.ttf"), (MAGIC_MARGIN * 2), 0xFFEA2D1F, CENTER);
		social1.setBorderStyle(OUTLINE, 0xFFE9724C, 1.35);
		social1.antialiasing = true;
		social1.scrollFactor.set();

		social1Ico = new AttachedSprite('credits/socials/Discord'); // Just to have image size for position calc
		social1Ico.scale.set(SOCIAL_ICON_SCALE, SOCIAL_ICON_SCALE); social1Ico.updateHitbox();
		social1Ico.sprTracker = social1;
		social1Ico.xAdd = social1Ico.width;
		social1Ico.yAdd = -social1Ico.height;
		social1Ico.copyVisible = true;
		social1Ico.antialiasing = false;

		social2 = new FlxText((separator.x + separator.width) + MAGIC_MARGIN, social1.y, social1.fieldWidth);
		social2.setFormat(social1.font, social1.size, 0xFFEA2D1F, CENTER);
		social2.setBorderStyle(social1.borderStyle, social1.borderColor, social1.borderSize);
		social2.antialiasing = social1.antialiasing;
		social2.scrollFactor.set();

		social2Ico = new AttachedSprite('credits/socials/Discord');
		social2Ico.scale.copyFrom(social1Ico.scale); social2Ico.updateHitbox();
		social2Ico.sprTracker = social2;
		social2Ico.xAdd = social2Ico.width;
		social2Ico.yAdd = -social2Ico.height;
		social2Ico.copyVisible = true;
		social2Ico.antialiasing = social1Ico.antialiasing;

		add(social1Ico); add(social2Ico);
		add(social1); add(social2);

		quoteBG = new FlxSprite(infoBG.x + MAGIC_MARGIN, 0, Paths.image('credits/speech'));
		quoteBG.setGraphicSize(infoBG.width - (MAGIC_MARGIN * 2)); quoteBG.scale.y = 0.25;
		quoteBG.updateHitbox();
		quoteBG.y = (separator.y - MAGIC_MARGIN) - quoteBG.height;
		quoteBG.antialiasing = ClientPrefs.data.antialiasing;
		quoteBG.active = false;
		quoteBG.scrollFactor.set();
		add(quoteBG);

		quoteOffs = 60 * quoteBG.scale.x;
		lilQuote = new FlxText((quoteBG.x + quoteOffs) + (MAGIC_MARGIN / 2), 0, (quoteBG.width - quoteOffs) - MAGIC_MARGIN);
		lilQuote.setFormat(Paths.font("fraiche.ttf"), (MAGIC_MARGIN * 2), FlxColor.WHITE, CENTER);
		lilQuote.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.5);
		lilQuote.antialiasing = true;
		lilQuote.scrollFactor.set();
		add(lilQuote);

		lilQuoteIMG = new FlxSprite();
		lilQuoteIMG.visible = false;
		lilQuoteIMG.active = false;
		lilQuoteIMG.antialiasing = true;
		lilQuoteIMG.scrollFactor.set();
		add(lilQuoteIMG);

		controllerCursor = new GamepadCursor();
		add(controllerCursor);

		camFollow.x = FlxG.width - portraitGroup.members[0].width;
		
		#if mobile
		addVirtualPad(NONE, B);
		#end
		changeSelection(0);
		camera.snapToTarget();
	}

	override function update(elapsed:Float)
	{
		if (blockInput)
		{
			super.update(elapsed);
			return;
		}
		FlxG.mouse.getGamePosition(curMousePos);

		if (FlxG.gamepads.anyInput()) usingController = true;
		else if (FlxG.keys.justPressed.ANY || (!CoolUtil.pointsAreEqual(curMousePos, lastMousePos) || FlxG.mouse.justPressed)) usingController = false;
		// FlxG.watch.addQuick("controllerMode", usingController);

		controllerCursor.visible = usingController;
		FlxG.mouse.visible = !usingController;

		var up_p:Bool = FlxG.keys.anyJustPressed(controls.keyboardBinds['ui_up']) || FlxG.gamepads.anyJustPressed(DPAD_UP) || TouchUtil.swipeDown;
		var down_p:Bool = FlxG.keys.anyJustPressed(controls.keyboardBinds['ui_down']) || FlxG.gamepads.anyJustPressed(DPAD_DOWN) || TouchUtil.swipeUp;
		if (up_p || down_p)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'));
			final change:Int = up_p ? -1 : 1;

			changeSelection(change);
			(up_p ? arrowUp : arrowDown).offset.y = (up_p ? startUpOffs : startDownOffs) + ((arrowAnimDist * -change) * 2);
		}

		if (controls.BACK)
		{
			blockInput = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));

			FlxG.switchState(() -> new MainMenuState());
		}

		if (social1 != null && social1.visible)
		{
			social1.underline = !usingController ? FlxG.mouse.overlaps(social1) : controllerCursor.overlaps(social1);
			social1.color = social1.underline ? 0xFFFFC857 : 0xFFEA2D1F;
			if (social1.underline && (!usingController ? FlxG.mouse.justPressed : controls.ACCEPT)) CoolUtil.browserLoad(socialDatas[curSelected][0].getWebsite());
		}
		if (social2 != null && social2.visible)
		{
			social2.underline = !usingController ? FlxG.mouse.overlaps(social2) : controllerCursor.overlaps(social2);
			social2.color = social2.underline ? 0xFFFFC857 : 0xFFEA2D1F;
			if (social2.underline && (!usingController ? FlxG.mouse.justPressed : controls.ACCEPT)) CoolUtil.browserLoad(socialDatas[curSelected][1].getWebsite());
		}

		super.update(elapsed);
		FlxG.mouse.getGamePosition(lastMousePos);
		final shoveDecay:Float = Math.exp(-elapsed * (arrowAnimSpeed * 1.5));
		arrowFloatTime += elapsed;

		arrowUp.offset.y = FlxMath.lerp(startUpOffs, arrowUp.offset.y, shoveDecay);
		arrowDown.offset.y = FlxMath.lerp(startDownOffs, arrowDown.offset.y, shoveDecay);

		final posSin:Float = !ClientPrefs.data.lowQuality ? Math.sin(arrowFloatTime * arrowAnimSpeed) : FlxMath.fastSin(arrowFloatTime * arrowAnimSpeed);
		arrowUp.y = startUpPos + posSin * arrowAnimDist;
		arrowDown.y = startDownPos + posSin * -arrowAnimDist;
	}

	function changeSelection(change:Int)
	{
		if (socialDatas[curSelected] != null) // Reset
		{
			if (socialDatas[curSelected][0].social == SocialMediaType.OTHER)
			{
				social1Ico.scale.set(SOCIAL_ICON_SCALE, SOCIAL_ICON_SCALE);
				social1Ico.updateHitbox();
			}
			if (socialDatas[curSelected][1]?.social == SocialMediaType.OTHER)
			{
				social2Ico.scale.set(SOCIAL_ICON_SCALE, SOCIAL_ICON_SCALE);
				social2Ico.updateHitbox();
			}
			
			if (!firstChange)
			{
				prevSocials[0] = socialDatas[curSelected][0].social;
				prevSocials[1] = socialDatas[curSelected][1]?.social;
			}
		}
		else
			prevSocials = prevSocials.map((s) -> s = null);

		curSelected = FlxMath.wrap(curSelected + change, 0, creds.length - 1);
		changeGradient(colors[creds[curSelected].frameChar ?? "default"]);
		camFollow.y = portraitGroup.members[curSelected].y + (portraitGroup.members[curSelected].height / 2);
		descTxt.text = '[${creds[curSelected].role}]\n${creds[curSelected].doings}';
		firstChange = false;

		quoteBG.visible = creds[curSelected].quote != null;
		lilQuoteIMG.visible = Paths.fileExists('images/${creds[curSelected].quote}', IMAGE);
		lilQuote.visible = quoteBG.visible && !lilQuoteIMG.visible;
		if (lilQuoteIMG.visible)
		{
			lilQuoteIMG.loadGraphic(Paths.image( creds[curSelected].quote.replace(".png", "") ));
			lilQuoteIMG.setGraphicSize((quoteBG.width - quoteOffs) - (MAGIC_MARGIN * 2), quoteBG.height - (MAGIC_MARGIN * 3)); lilQuoteIMG.updateHitbox();
			lilQuoteIMG.setPosition(
				((quoteBG.x + quoteOffs) + ((quoteBG.width - quoteOffs) / 2)) - (lilQuoteIMG.width / 2),
				(quoteBG.y + (quoteBG.height / 2)) - (lilQuoteIMG.height / 2)
			);
		}
		else if (lilQuote.visible)
		{
			lilQuote.text = creds[curSelected].quote;
			lilQuote.y = (quoteBG.y + (quoteBG.height / 2)) - (lilQuote.height / 2);
		}

		separator.visible = social1.visible = social2.visible = socialDatas[curSelected] != null;
		if (!social1.visible) return;
		updateSocialInfo(socialDatas[curSelected][0], prevSocials[0], social1, social1Ico);

		social2.visible = socialDatas[curSelected].length >= 2;
		if (!social2.visible) return;
		updateSocialInfo(socialDatas[curSelected][1], prevSocials[1], social2, social2Ico);
	}

	override function destroy()
	{
		for (c in colors) c.resize(0);
		colors.clear();
		creds.resize(0);
		socialDatas.resize(0);
		prevSocials.resize(0);

		lastMousePos.put();
		curMousePos.put();
		super.destroy();
	}

	inline function changeGradient(colors:Array<FlxColor>)
	{
		if (gradColor == null) return;

		gradColor.r = colors[0];
		gradColor.b = colors[1];
	}

	inline function updateSocialInfo(socialData:SocialMedia, prevSocial:SocialMediaType, text:FlxText, icon:FlxSprite)
	{
		text.text = socialData.getAccName();
		text.y = (infoBG.y + infoBG.height) - (text.height + MAGIC_MARGIN);
		if (socialData.social == prevSocial)
		{
			icon.updateHitbox();
			return;
		}

		final unknownSocial:Bool = socialData.social == SocialMediaType.OTHER;
		final socialIcon:String = !unknownSocial ? 'credits/socials/${socialData.social}' : 'achievements/menu/unknownAchieve';

		icon.loadGraphic(Paths.image(socialIcon));
		if (unknownSocial) icon.setGraphicSize(150 * SOCIAL_ICON_SCALE); // 150 é o tamanho de todos os ícone de social
		icon.updateHitbox();
	}
}