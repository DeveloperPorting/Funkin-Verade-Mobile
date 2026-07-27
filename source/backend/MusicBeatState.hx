package backend;

import flixel.FlxSubState;
import flixel.FlxState;
import backend.PsychCamera;

#if mobile
import flixel.group.FlxGroup;
import flixel.util.FlxDestroyUtil;
import mobile.controls.MobileHitbox;
import mobile.controls.MobileVirtualPad;
#end

class MusicBeatState extends flixel.addons.transition.FlxTransitionableState
{
    public static var instance:MusicBeatState;
    
	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	public var controls(get, never):Controls;
	private function get_controls()
	{
		return Controls.instance;
	}
	
	#if mobile
	public var hitbox:MobileHitbox;
	public var virtualPad:MobileVirtualPad;

	public var virtualPadCam:FlxCamera;
	public var hitboxCam:FlxCamera;

    public function addVirtualPad(DPad:MobileDPadMode, Action:MobileActionMode)
	{
		virtualPad = new MobileVirtualPad(DPad, Action);
		add(virtualPad);
	}
	
	public function addVirtualPadCamera(DefaultDrawTarget:Bool = false)
	{
		if (virtualPad != null)
		{
			virtualPadCam = new FlxCamera();
			virtualPadCam.bgColor.alpha = 0;
			FlxG.cameras.add(virtualPadCam, DefaultDrawTarget);
			
			virtualPad.cameras = [virtualPadCam];
		}
	}

	public function removeVirtualPad()
	{
		if (virtualPad != null)
		{
			remove(virtualPad);
			virtualPad = FlxDestroyUtil.destroy(virtualPad);
		}

		if(virtualPadCam != null)
		{
			FlxG.cameras.remove(virtualPadCam);
			virtualPadCam = FlxDestroyUtil.destroy(virtualPadCam);
		}
	}

	public function addMobileControls(DefaultDrawTarget:Bool = false)
	{
		hitbox = new MobileHitbox();

		hitboxCam = new FlxCamera();
		hitboxCam.bgColor.alpha = 0;
		FlxG.cameras.add(hitboxCam, DefaultDrawTarget);

		hitbox.cameras = [hitboxCam];
		hitbox.visible = false;
		add(hitbox);
	}

	public function removeMobileControls()
	{
		if (hitbox != null)
		{
			remove(hitbox);
			hitbox = FlxDestroyUtil.destroy(hitbox);
		}

		if(hitboxCam != null)
		{
			FlxG.cameras.remove(hitboxCam);
			hitboxCam = FlxDestroyUtil.destroy(hitboxCam);
		}
	}

	override function destroy()
    {
        super.destroy();
		removeVirtualPad();
		removeMobileControls();
	}
	#end

	var _psychCameraInitialized:Bool = false;

	public var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	public static function getVariables()
		return getState().variables;

	/**
	 * Set this to a class path, if you want to use a custom trans substate instead of the flixel ones
	 */
	public static var customTransClass:String = "";

	override function create()
	{
	     instance = this;
		#if MODS_ALLOWED Mods.updatedOnState = false; #end
		#if ACHIEVEMENTS_ALLOWED
		@:privateAccess if (Achievements.achievementsUnlocked.length == (Achievements._originalLength - 1))
			Achievements.unlock('walktrough');
		#end

		if (!_psychCameraInitialized) initPsychCamera();
		super.create();
	}

	public function initPsychCamera():PsychCamera
	{
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		_psychCameraInitialized = true;
		//trace('initialized psych camera ' + Sys.cpuTime());
		return camera;
	}

	override function update(elapsed:Float)
	{
		final oldStep:Int = curStep;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep)
		{
			if (curStep > 0) stepHit();

			if (PlayState.SONG != null)
			{
				if (oldStep < curStep)
					updateSection();
				else
					rollbackSection();
			}
		}
		
		stagesFunc(function(stage:BaseStage) stage.update(elapsed));
		super.update(elapsed);
	}

	private function updateSection():Void
	{
		if(stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		while(curStep >= stepsToDo)
		{
			curSection++;
			var beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
		}
	}

	private function rollbackSection():Void
	{
		if(curStep < 0) return;

		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if(stepsToDo > curStep) break;
				
				curSection++;
			}
		}

		if(curSection > lastSection) sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	override function finishTransOut()
	{
		transOutFinished = true;
		if (_onExit != null) _onExit();
	}

	override function transitionIn()
	{
		var cls:Class<FlxSubState> = cast Type.resolveClass(customTransClass);
		if (cls == null && hasTransIn) // Uses the TILE or FADE transition (base FlxTransitionableState transitions)
		{
			super.transitionIn();
			return;
		}

		if (FlxTransitionableState.skipNextTransIn)
		{
			FlxTransitionableState.skipNextTransIn = false;
			finishTransIn();
			return;
		}

		if (transIn == null)
		{
			finishTransIn();
			return;
		}

		var trans:FlxSubState = Type.createInstance(cls, [transIn, true]);
		trans.closeCallback = finishTransIn;
		openSubState(trans);
	}
	
	override function transitionOut(?OnExit:Void->Void)
	{
		var cls:Class<FlxSubState> = cast Type.resolveClass(customTransClass);
		if (cls == null && hasTransOut) // Uses the TILE or FADE transition (base FlxTransitionableState transitions)
		{
			super.transitionOut(OnExit);
			return;
		}
		_onExit = OnExit;

		if (transOut == null)
		{
			finishTransOut();
			return;
		}

		var trans:FlxSubState = Type.createInstance(cls, [transOut, false]);
		trans.closeCallback = finishTransOut;
		openSubState(trans);
	}

	override function startOutro(onOutroComplete:() -> Void)
	{
		transitionOut(onOutroComplete);
			
		if (FlxTransitionableState.skipNextTransOut)
		{
			FlxTransitionableState.skipNextTransOut = false;
			finishTransOut();
		}
	}

	public static function getState():MusicBeatState {
		return cast (FlxG.state, MusicBeatState);
	}

	public function stepHit():Void
	{
		stagesFunc(function(stage:BaseStage) {
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});

		if (curStep % 4 == 0)
			beatHit();
	}

	public var stages:Array<BaseStage> = [];
	public function beatHit():Void
	{
		//trace('Beat: ' + curBeat);
		stagesFunc(function(stage:BaseStage) {
			stage.curBeat = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});
	}

	public function sectionHit():Void
	{
		//trace('Section: ' + curSection + ', Beat: ' + curBeat + ', Step: ' + curStep);
		stagesFunc(function(stage:BaseStage) {
			stage.curSection = curSection;
			stage.sectionHit();
		});
	}

	function stagesFunc(func:BaseStage->Void)
	{
		for (stage in stages)
			if(stage != null && stage.exists && stage.active)
				func(stage);
	}

	function getBeatsOnSection()
	{
		var val:Null<Float> = 4;
		if(PlayState.SONG != null && PlayState.SONG.notes[curSection] != null) val = PlayState.SONG.notes[curSection].sectionBeats;
		return val == null ? 4 : val;
	}
}
