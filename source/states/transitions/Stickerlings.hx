package states.transitions;

import flixel.addons.transition.TransitionData;

private typedef StickerPack = 
{
	artist:String,

	stickers:Array<String>,
	?soundFolder:String
}

class Stickerlings extends flixel.FlxSubState
{
	public static var packName(default, set):String = null;
	static var stickerPack:StickerPack;
	static function set_packName(p)
	{
		if (packName == p) return packName;

		stickerPack = haxe.Json.parse(Paths.getTextFromFile( Paths.json('menus/stickerpacks/$p') ));
		for (s in stickerPack.stickers) Paths.cacheBitmap('images/$s.png');
		return packName = p;
	}

	var __data:TransitionData;
	static var _customCamera:FlxCamera;
	static var __customCamInitialized:Bool = false;

	var transIn:Bool = false;
	static var lastStickers:Array<FlxSprite> = [];
	static var lastTimings:Array<Float> = [];
	var possibleSounds:Array<openfl.media.Sound> = [];

	public function new(data:TransitionData, transIn:Bool)
	{
		this.transIn = transIn;
		__data = data;
		packName ??= "default";

		switch (__data.cameraMode)
		{
			case TOP: camera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
			case DEFAULT: camera = _parentState.camera;
			case NEW:
				if (!__customCamInitialized)
				{
					_customCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height);
					__customCamInitialized = true;
				}
				camera = _customCamera;
		}

		var soundFolders:Array<String> = [];
		final stickerSoundsDir:String = 'stickers/';
		final soundsDir:String = Paths.getSharedPath('sounds/$stickerSoundsDir');

		var baseDir:String = soundsDir.endsWith('/') ? soundsDir : soundsDir + '/';
		
		for (asset in openfl.utils.Assets.list())
		{
			var idx = asset.indexOf(baseDir);
			if (idx != -1)
			{
				var relativePath:String = asset.substring(idx + baseDir.length);
				var slashIndex = relativePath.indexOf('/');
				
				if (slashIndex != -1)
				{
					var folderName:String = relativePath.substring(0, slashIndex);
					
					if (!soundFolders.contains(folderName))
					{
						soundFolders.push(folderName);
					}
				}
			}
		}
		
		if (soundFolders.length > 0)
		{
			final pickedFolder:String = '${FlxG.random.getObject(soundFolders)}/';
			var searchPickedDir:String = baseDir + pickedFolder;
			var soundExt:String = '.' + Paths.SOUND_EXT;
		
			for (asset in openfl.utils.Assets.list())
			{
				var idx = asset.indexOf(searchPickedDir);
				
				if (idx != -1 && StringTools.endsWith(asset.toLowerCase(), soundExt.toLowerCase()))
				{
					var relativePath:String = asset.substring(idx + searchPickedDir.length);
					
					if (relativePath.indexOf('/') == -1)
					{
						var fileName:String = relativePath.substring(0, relativePath.length - soundExt.length);
						
						final soundName:String = '$stickerSoundsDir$pickedFolder$fileName';
						possibleSounds.push(Paths.sound(soundName));
					}
				}
			}
		}

		for (s in stickerPack.stickers) Paths.avoidDumping(Paths.getPath('images/$s.png', IMAGE));
		super();
	}	

	override function create()
	{
		super.create();

		if (transIn)
		{
			for (i=>s in lastStickers)
			{
				add(s); s.revive();
				FlxTimer.wait(lastTimings[i], () -> 
				{
					s.visible = false;
					FlxG.sound.play(FlxG.random.getObject(possibleSounds));

					if (i == lastStickers.length - 1) closeCallback();
				});
			}
			return;
		}

		var curX:Float = -100; var curY:Float = -100;
		while (curX <= FlxG.width)
		{
			var lilSticker:FlxSprite = new FlxSprite(curX, curY, Paths.image( FlxG.random.getObject(stickerPack.stickers) ));
			lilSticker.visible = false;
			lilSticker.angle = FlxG.random.int(-60, 70);
			lilSticker.active = false;
			lilSticker.antialiasing = ClientPrefs.data.antialiasing;

			curX += lilSticker.width / 2;
			if (curX >= FlxG.width && curY <= FlxG.height)
			{
				curX = -100;
				curY += FlxG.random.float(70, 120);
			}
			lilSticker.scrollFactor.set();
			add(lilSticker);
		}

		FlxG.random.shuffle(members);

		var lastSticker:FlxSprite = new FlxSprite(0, 0, Paths.image( FlxG.random.getObject(stickerPack.stickers) ));
		lastSticker.screenCenter();
		lastSticker.visible = false;
		lastSticker.active = false;
		lastSticker.antialiasing = ClientPrefs.data.antialiasing;
		lastSticker.scrollFactor.set();
		add(lastSticker);

		// I'm basing myself on vslice's code 
		// Wtf is these nested timers
		for (i=>s in members)
		{
			final sticker:FlxSprite = cast s;
			lastStickers.push(sticker);

			lastTimings.push(FlxMath.remapToRange(i, 0, members.length, 0, __data.duration - 0.1));
			FlxTimer.wait(lastTimings[lastTimings.length - 1], () -> 
			{
				sticker.visible = true;
				FlxG.sound.play(FlxG.random.getObject(possibleSounds));

				final lastie:Bool = i == (members.length - 1);
				final frameTimer:Int = lastie ? 2 : FlxG.random.int(0, 2);
				FlxTimer.wait((1 / 24) * frameTimer, () -> 
				{
					final scale:Float = FlxG.random.float(0.97, 1.02);
					sticker.scale.set(scale, scale);

					if (!lastie) return;
					closeCallback();
				});
			});
		}

		// BruhOliverLOL passou aq >:) //
	}

	override function destroy()
	{
		possibleSounds.resize(0);
		if (transIn)
		{
			lastStickers.resize(0);
			lastTimings.resize(0);
			
			super.destroy();
			return;
		}

		for (s in members)
		{
			remove(s);
			s.kill();
		}

		super.destroy();
	}
}
