package states;

import haxe.Json;

private typedef ImageInfo =
{
	?displayName:String,
	owner:String,

	__imagePath:String, // Interno, usado apenas pelo menu
}

class GalleryState extends MusicBeatState
{
	var list:Array<Array<ImageInfo>> = [];
	var categories:Array<String> = [];
	var images:Array<Array<FlxSprite>> = [];

	static var curCategory:Int;
	static var curSelected:Int;
	static var alreadyIntrodid:Bool;

	var nameTxt:FlxText;
	var artistTxt:FlxText;
	var categoryTxt:FlxText;

	var arrowUp:FlxSprite; var arrowDown:FlxSprite;
	var arrowLeft:FlxSprite; var arrowRight:FlxSprite;
	final hArrowScales:Float = 0.6;
	final vArrowScales:Float = 0.4;

	public function new()
	{
		final dir:String = Paths.getSharedPath('images/gallery/');
		var i:Int = 0;
		var l:Int = 0;

		var searchDir:String = dir.endsWith('/') ? dir : dir + '/';
		
		var folderAssets:Map<String, Array<String>> = new Map();
		var categoriesList:Array<String> = [];
		
		for (asset in openfl.utils.Assets.list())
		{
			var idx = asset.indexOf(searchDir);
			if (idx != -1)
			{
				var afterDir = asset.substring(idx + searchDir.length);
				var parts = afterDir.split('/');
		
				if (parts.length >= 2)
				{
					var folderName = parts[0];
					var subfile = parts[parts.length - 1];
		
					if (folderName == "menu") continue;
		
					if (!folderAssets.exists(folderName))
					{
						folderAssets.set(folderName, []);
						categoriesList.push(folderName);
					}
		
					folderAssets.get(folderName).push(subfile);
				}
			}
		}
		
		for (folder in categoriesList)
		{
			categories.push(folder);
			if (list.length < (i + 1)) list[i] = [];
			if (images.length < (i + 1)) images[i] = [];
		
			var filesInFolder = folderAssets.get(folder);
		
			for (subfile in filesInFolder)
			{
				if (StringTools.endsWith(subfile.toLowerCase(), '.png'))
				{
					Paths.cacheBitmap('images/gallery/$folder/$subfile');
					continue;
				}
		
				if (!StringTools.endsWith(subfile.toLowerCase(), '.json')) continue;
				
				final subfileName:String = subfile.substr(0, subfile.lastIndexOf("."));
		
				var info:ImageInfo = Json.parse(openfl.utils.Assets.getText('$dir$folder/$subfile'));
				info.displayName ??= '$subfileName.png';
				info.__imagePath = 'gallery/$folder/$subfileName';
				list[i].push(info);
				l++;
			}
			i++;
		}

		curSelected = FlxMath.wrap(curSelected, 0, l);
		curCategory = FlxMath.wrap(curCategory, 0, categories.length - 1);
		super();
	}

	inline function playMenuSong()
	{
		Paths.avoidDumping(Paths.getSharedPath('music/galleryMenu.${Paths.SOUND_EXT}')); // Incase you come back here

		FlxG.sound.playMusic(Paths.music('galleryMenu'), alreadyIntrodid ? 0.7 : 0);
		if (!alreadyIntrodid) FlxG.sound.music.fadeIn(4, 0, 0.7);
		Conductor.bpm = 118;
		alreadyIntrodid = true;
	}

	override function create()
	{
		FlxG.mouse.visible = false;
		playMenuSong();
		backend.Achievements.unlock("sillyDoodles");
		super.create();

		var bg:FlxSprite = new FlxSprite(0, 0, Paths.image('gallery/menu/room'));
		bg.setGraphicSize(FlxG.width, FlxG.height); bg.updateHitbox();
		bg.screenCenter();
		bg.active = false;

		var imgBG:FlxSprite = new FlxSprite(0, 0, Paths.image('gallery/menu/bg'));
		imgBG.setGraphicSize(0, bg.height / 2); imgBG.updateHitbox();
		imgBG.screenCenter().y += 12;
		imgBG.active = false;
		add(imgBG);

		for (i=>c in list)
		{
			for (d in c)
			{
				var imgSpr:FlxSprite = new FlxSprite(0, 0, Paths.image(d.__imagePath));
				if ((imgSpr.width / imgSpr.height) > 1.5)
					imgSpr.setGraphicSize(bg.width / 2.2);
				else
					imgSpr.setGraphicSize(0, bg.height / 2.2);
				imgSpr.updateHitbox();
				imgSpr.screenCenter().y += 9;
				imgSpr.active = false;
				imgSpr.visible = false;
				imgSpr.antialiasing = ClientPrefs.data.antialiasing;
				
				add(imgSpr);
				images[i].push(imgSpr);
			}
		}
		add(bg);

		final textOffset:Float = 110;
		nameTxt = new FlxText(0, images[0][0].y - textOffset, FlxG.width / 2);
		nameTxt.setFormat(Paths.font("fraiche.ttf"), 32, FlxColor.WHITE, CENTER);
		nameTxt.setBorderStyle(OUTLINE, FlxColor.BLACK, 1.5);
		nameTxt.screenCenter(X);
		nameTxt.antialiasing = true;
		add(nameTxt);

		artistTxt = new FlxText(0, (images[0][0].y + images[0][0].height) + (textOffset / 1.5), nameTxt.fieldWidth);
		artistTxt.setFormat(nameTxt.font, nameTxt.size, nameTxt.color, nameTxt.alignment);
		artistTxt.setBorderStyle(OUTLINE, nameTxt.borderColor, nameTxt.borderSize);
		artistTxt.screenCenter(X);
		artistTxt.antialiasing = nameTxt.antialiasing;
		add(artistTxt);

		arrowLeft = new FlxSprite(imgBG.x, 0, Paths.image('gallery/menu/arrow'));
		arrowLeft.colorTransform.color = FlxColor.WHITE;
		arrowLeft.scale.set(hArrowScales, hArrowScales); arrowLeft.updateHitbox();
		arrowLeft.screenCenter(Y).x -= arrowLeft.width;
		arrowLeft.flipX = true;
		arrowLeft.active = false;
		arrowLeft.antialiasing = true;
		add(arrowLeft);

		arrowRight = new FlxSprite(imgBG.x + imgBG.width, 0, Paths.image('gallery/menu/arrow'));
		arrowRight.colorTransform.color = arrowLeft.colorTransform.color;
		arrowRight.scale.copyFrom(arrowLeft.scale); arrowRight.updateHitbox();
		arrowRight.screenCenter(Y);
		arrowRight.active = false;
		arrowRight.antialiasing = arrowLeft.antialiasing;
		add(arrowRight);
		
		arrowDown = new FlxSprite(20, 0, Paths.image('gallery/menu/arrow'));
		arrowDown.colorTransform.color = FlxColor.WHITE;
		arrowDown.scale.set(vArrowScales, vArrowScales); arrowDown.updateHitbox();
		arrowDown.angle = 90;
		arrowDown.y = (FlxG.height - arrowDown.height);
		arrowDown.active = false;
		arrowDown.antialiasing = true;
		add(arrowDown);

		categoryTxt = new FlxText(20, 0, FlxG.width / 5);
		categoryTxt.setFormat(Paths.font("fraiche.ttf"), 24, FlxColor.WHITE, LEFT);
		categoryTxt.setBorderStyle(OUTLINE_FAST, FlxColor.BLACK, 1.5);
		categoryTxt.antialiasing = true;
		add(categoryTxt);

		arrowUp = new FlxSprite(arrowDown.x, 0, Paths.image('gallery/menu/arrow'));
		arrowUp.colorTransform.color = FlxColor.WHITE;
		arrowUp.scale.copyFrom(arrowDown.scale); arrowUp.updateHitbox();
		arrowUp.angle = -90;
		arrowUp.active = false;
		arrowUp.antialiasing = true;
		add(arrowUp);
		
		#if mobile
		addVirtualPad(LEFT_FULL, A_B);
		#end

		changeCategory(0);
	}

	override function update(elapsed:Float)
	{
		var left:Bool = false;
		if ((left = controls.UI_LEFT_P) || controls.UI_RIGHT_P)
		{
			FlxG.sound.play(Paths.sound("scrollMenu"));
			changeSelection(left ? -1 : 1);
			(left ? arrowLeft : arrowRight).scale.add(0.35, 0.35);
		}

		var up:Bool = false;
		if ((up = controls.UI_UP_P) || controls.UI_DOWN_P)
		{
			FlxG.sound.play(Paths.sound("scrollMenu"));
			changeCategory(up ? -1 : 1);
			(up ? arrowUp : arrowDown).scale.add(0.15, 0.15);
		}

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound("cancelMenu"));
			FlxG.switchState(() -> new MainMenuState());
		}

		super.update(elapsed);
		final decay:Float = Math.exp(-elapsed * 7);

		if (arrowLeft?.visible) updateArrowScale(arrowLeft, hArrowScales, decay);
		if (arrowRight?.visible) updateArrowScale(arrowRight, hArrowScales, decay);
		if (arrowDown?.visible) updateArrowScale(arrowDown, vArrowScales, decay);
		if (arrowUp?.visible) updateArrowScale(arrowUp, vArrowScales, decay);
	}

	inline function updateArrowScale(arrow:FlxSprite, originalScale:Float, decay:Float)
	{
		arrow.scale.set(
			FlxMath.lerp(originalScale, arrow.scale.x, decay),
			FlxMath.lerp(originalScale, arrow.scale.y, decay)
		);
	}

	function changeSelection(change:Int)
	{
		images[curCategory][curSelected].visible = false;

		curSelected = FlxMath.wrap(curSelected + change, 0, images[curCategory].length - 1);
		images[curCategory][curSelected].visible = true;

		nameTxt.text = list[curCategory][curSelected].displayName;
		artistTxt.text = list[curCategory][curSelected].owner;
	}

	function changeCategory(change:Int)
	{
		images[curCategory][curSelected].visible = false;

		curCategory = FlxMath.wrap(curCategory + change, 0, categories.length - 1);
		changeSelection(curSelected = 0);

		categoryTxt.text = categories[curCategory];
		categoryTxt.y = arrowDown.y - categoryTxt.height;
		arrowUp.y = (categoryTxt.y - arrowUp.height);

		#if DISCORD_ALLOWED DiscordClient.changePresence('Art Gallery', 'Checking the ${categories[curCategory]} category', true); #end
	}

	override function destroy()
	{
		list.resize(0);
		categories.resize(0);
		images.resize(0);
		super.destroy();
	}
}