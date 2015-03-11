/* 
Copyright (c) 2014 Laurent Garnier (laurent@blueyeti.fr)
http://www.blueyeti.fr/

 This software is provided 'as-is', without any express or implied
 warranty.  In no event will the authors be held liable for any damages
 arising from the use of this software.

 Permission is granted to anyone to use this software for any personal, non-commercial
 purpose, and to alter it and redistribute it freely, subject to the following restrictions:
 1. The origin of this software must not be misrepresented; you must not
 claim that you wrote the original software.
 2. This notice may not be removed or altered from any source distribution. 
 */
package
{
	import com.greensock.TimelineMax;
	import com.greensock.TweenLite;
	import com.greensock.TweenMax;
	import com.greensock.easing.Bounce;
	import com.greensock.easing.Linear;
	import com.greensock.easing.Sine;
	
	import flash.display.MovieClip;
	import flash.display.Shape;
	import flash.display.StageDisplayState;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.ProgressEvent;
	import flash.text.Font;
	import flash.ui.Mouse;
	
	import fr.blueyeti.manager.LogManager;
	import fr.blueyeti.manager.PresetManager;
	import fr.blueyeti.manager.TimeManager;
	import fr.blueyeti.player.AudioPlayerRand;
	
	[SWF(width="1080", height="1920", frameRate="30", backgroundColor="#000000")]
	
	/**
	 * Main class
	 * @author Laurent Garnier
	 */
	public class Main extends MovieClip
	{
		// static const
		public static const TWEEN_TIME_ALPHA 	: Number = 2;
		public static const TWEEN_TIME_BUTTON 	: Number = 1.5;
		public static const TWEEN_TIME_SLIDE 	: Number = 0.5;
		public static const TWEEN_TIME_PULSE 	: Number = 5;
		
		public static const STATE_WELCOME		: uint = 0;
		public static const STATE_LANG			: uint = 1;
		public static const STATE_SENSOR		: uint = 2;
		public static const STATE_CALIBRATION	: uint = 3;
		public static const STATE_CALIBRATION2	: uint = 4;
		public static const STATE_GAME			: uint = 5;
		public static const STATE_GAMEOVER		: uint = 6;
		public static const STATE_CONCLUSION	: uint = 7;
		
		public static var CODE_VALID			: uint;
		public static var CODE_LEFT				: uint;
		public static var CODE_RIGHT			: uint;
		public static var CODE_UP				: uint;
		public static var CODE_DOWN				: uint;
		
		// static vars
		public static var s_timerManager 		: TimeManager;		 	// global inactivity timer manager
		public static var s_presetManager 		: PresetManager;		// preset manager
		public static var s_logManager 			: LogManager;			// log manager
		
		// sounds
		public static var s_slideInterfaceSnd 	: AudioPlayerRand;
		public static var s_slideItemSnd 		: AudioPlayerRand;
		public static var s_showValidButtonSnd	: AudioPlayerRand;
		public static var s_showDirButtonSnd	: AudioPlayerRand;
		public static var s_clickValidSnd 		: AudioPlayerRand;
		public static var s_clickDirSnd		 	: AudioPlayerRand;
		public static var s_calibrationSnd 		: AudioPlayerRand;
		public static var s_tetrisSnd 			: AudioPlayerRand;
		public static var s_levelUpSnd 			: AudioPlayerRand;
		public static var s_levelDownSnd		: AudioPlayerRand;
		public static var s_winBlockSnd		 	: AudioPlayerRand;
		public static var s_winLineSnd		 	: AudioPlayerRand;
		public static var s_gameOverSnd		 	: AudioPlayerRand;
		public static var s_timeoutSnd		 	: AudioPlayerRand;
		public static var s_gameTimeoutSnd		: AudioPlayerRand;
		
		// graphical elements
		private var m_interface					: InterfaceClip;		// main interface
		private var m_gsrSensor 				: GSRSensor;			// GSR sensor interface
		private var m_tetris 					: Tetris;				// tetris interface
		private var m_mask	 					: Shape;				// mask
		private var m_gameMask	 				: Shape;				// mask
		
		// fonts
		public static var s_akzidenzMFt 		: AkzidenzMFt;
		public static var s_akzidenzRFt 		: AkzidenzRFt;
		
		public  var m_state						: uint;					// application state
		public  var m_lang						: String;				// selected langage
		
		public  var m_isTimeOut					: Boolean;
		public  var m_timelineMax				: TimelineMax;
		
		private var debug 						: Boolean;
		private var m_isKeyDown 				: Boolean;
		
		
		/**
		 * constructor main class
		 */
		public function Main()
		{
			if (stage) loadPresets ();
			else addEventListener(Event.ADDED_TO_STAGE, loadPresets);
		}
		
		/**
		 * create PresetManager and load presets
		 */
		private function loadPresets(e : Event = null) : void
		{
			removeEventListener(Event.ADDED_TO_STAGE, loadPresets);
			
			s_presetManager = new PresetManager();
			addEventListener(PresetManager.EVENT_PRESETS_LOADED, onPresetsLoaded);
			s_presetManager.loadPresets(this, "gamemo.xml");
		}
		
		/**
		 * init
		 */
		private function init() : void
		{
			// create log manager
			s_logManager = new LogManager("gamemo");
			s_logManager.write("[log] start GamEMO");
			
			// create inactivity timer
			s_timerManager = new TimeManager(Number(s_presetManager.getPresetValue("/time/timeout")));
			s_timerManager.registerMc(this);
			addEventListener(TimeManager.EVENT_TIME_OUT, onTimeOut);
			
			// init key codes
			CODE_VALID = uint(s_presetManager.getPresetValue("/keycode/valid"));
			CODE_LEFT = uint(s_presetManager.getPresetValue("/keycode/left"));
			CODE_RIGHT = uint(s_presetManager.getPresetValue("/keycode/right"));
			CODE_UP = uint(s_presetManager.getPresetValue("/keycode/rotate"));
			CODE_DOWN = uint(s_presetManager.getPresetValue("/keycode/accelerate"));
			
			// create main interface
			m_interface = new InterfaceClip();
			addChild(m_interface);
			
			// create interface mask
			m_mask = new Shape();
			m_mask.graphics.beginFill(0xFF0000);
			m_mask.graphics.drawRect(0, 290, 1080, 1920);
			m_mask.graphics.endFill();
			
			m_gameMask = new Shape();
			m_gameMask.graphics.beginFill(0xFF0000);
			m_gameMask.graphics.drawRect(0, 583, 1080, 1920);
			m_gameMask.graphics.endFill();
			
			m_interface.welcomeScreen.visible = true;
			m_interface.languageScreen.visible = false;
			m_interface.sensorScreen.visible = false;
			m_interface.calibrationScreen.visible = false;
			m_interface.ecran5.visible = false;
			m_interface.gameScreen.visible = false;
			m_interface.gameOverScreen.visible = false;
			m_interface.conclusionScreen.visible = false;
			m_interface.cadreCourbe.visible = false;
			m_interface.timeout.visible = false;
			
			m_interface.gameScreen.mask = m_gameMask;
			
			// create main interface
			m_tetris = new Tetris(this, m_interface);
			
			// create GSR sensor interface
			m_gsrSensor = new GSRSensor(this, m_interface, m_tetris);
			
			// keyboard handlers
			stage.addEventListener(KeyboardEvent.KEY_DOWN, key_pressed);
			stage.addEventListener(KeyboardEvent.KEY_UP, key_released);
			
			// create fonts
			createFonts();
			
			// create sounds
			createSounds();
			
			// init texts with main language
			updateTextLang(s_presetManager.getPresetStringValue("/languages/main"));
			
			// set fullscreen mode
			if (s_presetManager.getPresetStringValue("/screen/fullscreen") == "true")
//				stage.displayState = StageDisplayState.FULL_SCREEN;
				stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
			
			// set cursor mode
			if (s_presetManager.getPresetStringValue("/screen/hideCursor") == "true")
				Mouse.hide();
			
			if (Main.s_presetManager.getPresetStringValue("/debug") == "false")
				debug = false;
			else
				debug = true;
		}
		
		/**
		 * create fonts
		 */
		private function createFonts() : void
		{
			Font.registerFont(AkzidenzMFt);
			Font.registerFont(AkzidenzRFt);
			
			s_akzidenzMFt = new AkzidenzMFt();
			s_akzidenzRFt = new AkzidenzRFt();
		}
		
		/**
		 * create sounds
		 */
		private function createSounds() : void
		{
			s_slideInterfaceSnd = new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/slide_interface/filepath"), int(s_presetManager.getPresetValue("/sound/effects/slide_interface/volume"))/100);
			s_slideItemSnd 		= new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/slide_item/filepath"), int(s_presetManager.getPresetValue("/sound/effects/slide_item/volume"))/100);
			s_showValidButtonSnd= new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/show_valid_button/filepath"), int(s_presetManager.getPresetValue("/sound/effects/show_valid_button/volume"))/100);
			s_showDirButtonSnd  = new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/show_direction_button/filepath"), int(s_presetManager.getPresetValue("/sound/effects/show_direction_button/volume"))/100);
			s_clickValidSnd  	= new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/click_valid_button/filepath"), int(s_presetManager.getPresetValue("/sound/effects/click_valid_button/volume"))/100);
			s_clickDirSnd  		= new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/click_direction_button/filepath"), int(s_presetManager.getPresetValue("/sound/effects/click_direction_button/volume"))/100);
			s_calibrationSnd  	= new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/quiet_calibration/filepath"), int(s_presetManager.getPresetValue("/sound/effects/quiet_calibration/volume"))/100);
			s_tetrisSnd 		= new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/tetris/filepath"), int(s_presetManager.getPresetValue("/sound/effects/tetris/volume"))/100);
			s_levelUpSnd  		= new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/level/up/filepath"), int(s_presetManager.getPresetValue("/sound/effects/level/up/volume"))/100);
			s_levelDownSnd  	= new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/level/down/filepath"), int(s_presetManager.getPresetValue("/sound/effects/level/down/volume"))/100);
			s_winBlockSnd 		= new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/points/win_block/filepath"), int(s_presetManager.getPresetValue("/sound/effects/points/win_block/volume"))/100);
			s_winLineSnd 		= new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/points/win_line/filepath"), int(s_presetManager.getPresetValue("/sound/effects/points/win_line/volume"))/100);
			s_gameOverSnd	 	= new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/game_over/filepath"), int(s_presetManager.getPresetValue("/sound/effects/game_over/volume"))/100);
			s_timeoutSnd 		= new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/timeout/filepath"), int(s_presetManager.getPresetValue("/sound/effects/timeout/volume"))/100);
			s_gameTimeoutSnd 	= new AudioPlayerRand(s_presetManager.getPresetStringValue("/sound/effects/timeout/filepath"), int(s_presetManager.getPresetValue("/sound/effects/timeout/volume"))/100);
		}
		
		/**
		 * reset
		 */
		public function reset() : void
		{
			s_timerManager.stop();
			m_isTimeOut = false;
			s_timeoutSnd.stop();
			
			m_tetris.reset();
			m_gsrSensor.reset();
			
			m_isKeyDown = false;
		}
		
		/**
		 * infoplus need down case lang string
		 */
		public function getLangForInfoPlus() : String
		{
			if (m_lang == "FR")
				return "fr";
			else
				return "en";
		}
		
		/**
		 * update text language
		 */
		public function updateTextLang(lang : String) : void
		{
			m_lang = lang;
			
			m_interface.title.text.htmlText = s_presetManager.getPresetStringValue("/accueil/title", -1, lang);
			m_interface.welcomeScreen.tooltipLANG1.text.htmlText = s_presetManager.getPresetStringValue("/accueil/tooltip", -1, s_presetManager.getPresetStringValue("/languages/main"));
			m_interface.welcomeScreen.tooltipLANG2.text.htmlText = s_presetManager.getPresetStringValue("/accueil/tooltip", -1, s_presetManager.getPresetStringValue("/languages/second"));
			m_interface.languageScreen.tooltipLANG1.text.htmlText = s_presetManager.getPresetStringValue("/lang/tooltip", -1, s_presetManager.getPresetStringValue("/languages/main"));
			m_interface.languageScreen.tooltipLANG2.text.htmlText = s_presetManager.getPresetStringValue("/lang/tooltip", -1, s_presetManager.getPresetStringValue("/languages/second"));
			m_interface.languageScreen.lang1.text.htmlText = s_presetManager.getPresetStringValue("/lang/name", -1, s_presetManager.getPresetStringValue("/languages/main"));
			m_interface.languageScreen.lang2.text.htmlText = s_presetManager.getPresetStringValue("/lang/name", -1, s_presetManager.getPresetStringValue("/languages/second"));
			m_interface.sensorScreen.tooltip1.tooltip1.text.htmlText = s_presetManager.getPresetStringValue("/sensor/tooltip1", -1, lang);
			m_interface.sensorScreen.tooltip2.tooltip2.text.htmlText = s_presetManager.getPresetStringValue("/sensor/tooltip2", -1, lang);
			m_interface.sensorScreen.tooltip3.tooltip3.text.htmlText = s_presetManager.getPresetStringValue("/sensor/tooltip3", -1, lang);
			m_interface.calibrationScreen.tooltip1.text.htmlText = s_presetManager.getPresetStringValue("/calibration/start", -1, lang);
			m_interface.calibrationScreen.tooltip2.text.htmlText = s_presetManager.getPresetStringValue("/calibration/tooltip1", -1, lang);
			m_interface.ecran5.tooltip1.text.htmlText = s_presetManager.getPresetStringValue("/calibration/stop", -1, lang);
			m_interface.ecran5.tooltip2.text.htmlText = s_presetManager.getPresetStringValue("/calibration/tooltip2", -1, lang);
			m_interface.gameScreen.cursor.boredom.htmlText = s_presetManager.getPresetStringValue("/game/boredom", -1, lang);
			m_interface.gameScreen.cursor.anxiety.htmlText = s_presetManager.getPresetStringValue("/game/anxiety", -1, lang);
			m_interface.gameScreen.level.levelLabel.htmlText = s_presetManager.getPresetStringValue("/game/level", -1, lang);
			m_interface.gameScreen.timer.timerLabel.htmlText = s_presetManager.getPresetStringValue("/game/timer", -1, lang);
			m_interface.gameScreen.score.scoreLabel.htmlText = s_presetManager.getPresetStringValue("/game/score", -1, lang);
			m_interface.conclusionScreen.conclusion.text.htmlText = s_presetManager.getPresetStringValue("/game/conclusion", -1, lang);
			
			m_interface.gameScreen.level.containerLevel.niveau.width = m_interface.gameScreen.level.levelLabel.textWidth;
			m_interface.gameScreen.timer.containerTime.temps.width = m_interface.gameScreen.timer.timerLabel.textWidth;
			m_interface.gameScreen.score.containerScore.score.width = m_interface.gameScreen.score.scoreLabel.textWidth;
		}
		
		
		/**
		 * enable last step
		 */
		public function enableLastStep() : void
		{
		}
		
		/**
		 * disable last step
		 */
		public function disableLastStep() : void
		{
		}
		
		/**
		 * enable next step
		 */
		public function enableNextStep() : void
		{
			if (!stage.hasEventListener(KeyboardEvent.KEY_DOWN))
				stage.addEventListener(KeyboardEvent.KEY_DOWN, key_pressed);
			if (!stage.hasEventListener(KeyboardEvent.KEY_UP))
				stage.addEventListener(KeyboardEvent.KEY_UP, key_released);
		}
		
		/**
		 * disable next step
		 */
		public function disableNextStep() : void
		{
			if (stage.hasEventListener(KeyboardEvent.KEY_DOWN))
				stage.removeEventListener(KeyboardEvent.KEY_DOWN, key_pressed);
			if (stage.hasEventListener(KeyboardEvent.KEY_UP))
				stage.removeEventListener(KeyboardEvent.KEY_UP, key_released);
		}
		
		/**
		 * show next step
		 */
		public function showNextStep() : void
		{
			switch (m_state)
			{
				case STATE_WELCOME:
					showLang();
					break;
				case STATE_LANG:
					showSensor();
					break;
				case STATE_SENSOR:
					showCalibration();
					break;
				case STATE_CALIBRATION2:
					showGame();
					break;
				case STATE_GAME:
					break;
				case STATE_GAMEOVER:
//					showConclusion();
					break;
				case STATE_CONCLUSION:
					showWelcome();
					break;
			}
		}
		
		/**
		 * show last step
		 */
		public function showLastStep() : void
		{
			switch (m_state)
			{
				case STATE_LANG:
					break;
				case STATE_SENSOR:
					break;
				case STATE_CALIBRATION:
					break;
				case STATE_GAME:
					break;
			}
		}
		
		/**
		 * show welcome screen
		 */
		public function showWelcome() : void
		{
			m_state = STATE_WELCOME;
			
			disableNextStep();
			
			reset();
			
			m_interface.gameOverScreen.visible = false;
			m_interface.timeout.visible = false;
			m_interface.cadreCourbe.visible = false;
			m_interface.welcomeScreen.y = -1920;
			m_interface.welcomeScreen.visible = true;
			m_interface.welcomeScreen.mask = m_mask;
			m_interface.welcomeScreen.iconeBouton.scaleX = 0;
			m_interface.welcomeScreen.iconeBouton.scaleY = 0;
			
			var delay : Number = 0;
			TweenLite.to(m_interface.languageScreen, TWEEN_TIME_SLIDE, { delay : delay += 0, y : 1920, onStart : function() : void { }, onComplete : function() : void { m_interface.languageScreen.visible = false; m_interface.languageScreen.y = 0; } });
			TweenLite.to(m_interface.sensorScreen, TWEEN_TIME_SLIDE, { delay : delay += 0, y : 1920, onStart : function() : void { }, onComplete : function() : void { m_interface.sensorScreen.visible = false; m_interface.sensorScreen.y = 0; } });
			TweenLite.to(m_interface.calibrationScreen, TWEEN_TIME_SLIDE, { delay : delay += 0, y : 1920, onStart : function() : void { }, onComplete : function() : void { m_interface.calibrationScreen.visible = false; m_interface.calibrationScreen.y = 0; } });
			TweenLite.to(m_interface.ecran5, TWEEN_TIME_SLIDE, { delay : delay += 0, y : 1920, onStart : function() : void { }, onComplete : function() : void { m_interface.ecran5.visible = false; m_interface.ecran5.y = 0; } });
			TweenLite.to(m_interface.conclusionScreen, TWEEN_TIME_SLIDE, { delay : delay += 0, y : 1920, onStart : function() : void { }, onComplete : function() : void { m_interface.conclusionScreen.visible = false; m_interface.conclusionScreen.y = 0;  } });
			TweenLite.to(m_interface.gameScreen, TWEEN_TIME_SLIDE, { delay : delay += 0, y : 1920, onStart : function() : void { }, onComplete : function() : void { m_interface.gameScreen.visible = false; m_interface.gameScreen.y = 0; } });
			TweenLite.to(m_interface.welcomeScreen, TWEEN_TIME_SLIDE, { delay : delay += TWEEN_TIME_SLIDE, y : 0, onStart : function() : void { }, onComplete : function() : void { s_slideInterfaceSnd.play(); } });
			TweenLite.to(m_interface.welcomeScreen.iconeBouton, TWEEN_TIME_BUTTON, { delay : delay += TWEEN_TIME_SLIDE, scaleX : 1, scaleY : 1, ease : Bounce.easeOut, onStart : function() : void { s_showValidButtonSnd.play(); }, onComplete : function() : void { enableNextStep(); } });
		}
		
		/**
		 * show language screen
		 */
		public function showLang() : void
		{
			m_state = STATE_LANG;
			
			s_logManager.write("[log] NOUVELLE SESSION");
			
			disableNextStep();
			
			m_interface.languageScreen.mask = m_mask;
			m_interface.languageScreen.iconeJoystick.x = -50 - 369;
			m_interface.languageScreen.iconeBouton.scaleX = 0;
			m_interface.languageScreen.iconeBouton.scaleY = 0;
			
			var delay : Number = 0;
			TweenLite.to(m_interface.welcomeScreen, TWEEN_TIME_SLIDE, { delay : delay += 0, y : 1920, onStart : function() : void { s_slideInterfaceSnd.play(); }, onComplete : function() : void { m_interface.welcomeScreen.visible = false; m_interface.welcomeScreen.y = 0; m_interface.languageScreen.y = -1920; m_interface.languageScreen.visible = true; } });
			TweenLite.to(m_interface.languageScreen, TWEEN_TIME_SLIDE, { delay : delay += TWEEN_TIME_SLIDE, y : 0, onStart : function() : void { s_slideInterfaceSnd.play(); }, onComplete : function() : void { } });
			TweenLite.to(m_interface.languageScreen.iconeJoystick, TWEEN_TIME_SLIDE, { delay : delay += TWEEN_TIME_SLIDE, x : 133.1, ease : Linear.easeNone, onStart : function() : void { s_showDirButtonSnd.play();  }, onComplete : function() : void { } });
			TweenLite.to(m_interface.languageScreen.iconeBouton, TWEEN_TIME_BUTTON, { delay : delay += 0, scaleX : 1, scaleY : 1, ease : Bounce.easeOut, onStart : function() : void { s_showValidButtonSnd.play(); }, onComplete : function() : void { enableNextStep(); } });
		}
		
		/**
		 * show sensor screen
		 */
		public function showSensor() : void
		{
			m_state = STATE_SENSOR;
			
			disableNextStep();
			refreshTimer();
			
			m_interface.sensorScreen.mask = m_mask;
			m_interface.sensorScreen.iconeBouton.scaleX = 0;
			m_interface.sensorScreen.iconeBouton.scaleY = 0;
			m_interface.sensorScreen.tooltip1.x = -1080;
			m_interface.sensorScreen.tooltip2.x = -1080;
			m_interface.sensorScreen.tooltip3.x = -1080;
			m_interface.sensorScreen.iconeSensor.alpha = 0;
			m_interface.sensorScreen.iconeSensor.y = 2000;
			
			var delay : Number = 0;
			TweenLite.to(m_interface.languageScreen, TWEEN_TIME_SLIDE, { delay : delay += 0, y : 1920, onStart : function() : void { s_slideInterfaceSnd.play(); }, onComplete : function() : void { m_interface.languageScreen.visible = false; m_interface.languageScreen.y = 0; m_interface.sensorScreen.y = -1920; m_interface.sensorScreen.visible = true; } });
			TweenLite.to(m_interface.sensorScreen, 0.1, { delay : delay += TWEEN_TIME_SLIDE, y : 0, onStart : function() : void { s_slideInterfaceSnd.play(); }, onComplete : function() : void { } });
			TweenLite.to(m_interface.sensorScreen.tooltip1, 0.7, { delay : delay += 0.1, x : 540.9, onStart : function() : void { s_slideItemSnd.play(); }, onComplete : function() : void { } });
			TweenLite.to(m_interface.sensorScreen.tooltip2, 0.7, { delay : delay += 0.7, x : 540.9, onStart : function() : void { s_slideItemSnd.play(); }, onComplete : function() : void { } });
			TweenLite.to(m_interface.sensorScreen.tooltip3, 0.7, { delay : delay += 0.7, x : 540.9, onStart : function() : void { s_slideItemSnd.play(); }, onComplete : function() : void { } });
			TweenLite.to(m_interface.sensorScreen.iconeSensor, TWEEN_TIME_SLIDE, { delay : delay += TWEEN_TIME_SLIDE, y : 1389.65, ease : Linear.easeNone, onStart : function() : void { m_interface.sensorScreen.iconeSensor.alpha = 1; s_showDirButtonSnd.play(); }, onComplete : function() : void { } });
			TweenLite.to(m_interface.sensorScreen.iconeBouton, TWEEN_TIME_BUTTON, { delay : delay += 0, scaleX : 1, scaleY : 1, ease : Bounce.easeOut, onStart : function() : void { s_showValidButtonSnd.play(); }, onComplete : function() : void { enableNextStep(); } });
		}
		
		/**
		 * show calibration screen
		 */
		public function showCalibration() : void
		{
			m_state = STATE_CALIBRATION;

			disableNextStep();
			refreshTimer();
			
			m_interface.calibrationScreen.alpha = 1;
			m_interface.calibrationScreen.mask = m_mask;
			m_interface.calibrationScreen.iconeRespiration.pulse.width = 166;
			m_interface.calibrationScreen.iconeRespiration.pulse.height = 166;
			
			var delay : Number = 0;
			TweenLite.to(m_interface.sensorScreen, TWEEN_TIME_SLIDE, { delay : delay += 0, y : 1920, onStart : function() : void { s_slideInterfaceSnd.play(); }, onComplete : function() : void { m_interface.sensorScreen.visible = false; m_interface.sensorScreen.y = 0; m_interface.calibrationScreen.y = -1920; m_interface.calibrationScreen.visible = true; } });
			TweenLite.to(m_interface.calibrationScreen, TWEEN_TIME_SLIDE, { delay : delay += TWEEN_TIME_SLIDE, y : 0, onStart : function() : void { s_slideInterfaceSnd.play(); }, onComplete : function() : void { m_interface.cadreCourbe.alpha = 0; m_interface.cadreCourbe.visible = true; } });
			TweenLite.to(m_interface.cadreCourbe, 1, { delay : delay += TWEEN_TIME_SLIDE, alpha : 1, ease : Bounce.easeOut, onStart : function() : void {  }, onComplete : function() : void { m_gsrSensor.startCalibration(); s_calibrationSnd.play(); enableNextStep(); } });
			TweenMax.to(m_interface.calibrationScreen.iconeRespiration.pulse, TWEEN_TIME_PULSE, { width : 368.55, height : 368.55, repeat : -1, yoyo : true, ease : Sine.easeInOut, onComplete : function() : void { } });
		}
		
		/**
		 * show calibration screen
		 */
		public function showCalibrationEnd() : void
		{
			m_state = STATE_CALIBRATION2;
			
			disableNextStep();
			refreshTimer();
			
			TweenMax.killTweensOf(m_interface.calibrationScreen.iconeRespiration.pulse);
			
			s_calibrationSnd.stop(1);
			
			m_interface.ecran5.mask = m_mask;
			m_interface.ecran5.iconeBouton.scaleX = 0;
			m_interface.ecran5.iconeBouton.scaleY = 0;
			m_interface.ecran5.y = 0;
			m_interface.ecran5.alpha = 0;
			m_interface.ecran5.visible = true;
			
			var delay : Number = 0;
			TweenLite.to(m_interface.calibrationScreen, TWEEN_TIME_ALPHA, { delay : delay += 0, alpha : 0 });
			TweenLite.to(m_interface.ecran5, TWEEN_TIME_ALPHA, { delay : delay += 0, alpha : 1 });
			TweenLite.to(m_interface.ecran5.iconeBouton, TWEEN_TIME_BUTTON, { delay : delay += 1, scaleX : 1, scaleY : 1, onStart : function() : void { }, onComplete : function() : void { enableNextStep(); } });
		}
		
		/**
		 * show game screen
		 */
		public function showGame() : void
		{
			m_state = STATE_GAME;
			
			s_timerManager.stop();
			
			m_interface.gameScreen.score.y = -50;
			m_interface.gameScreen.timer.y = -50;
			m_interface.gameScreen.level.y = -50;
			m_interface.gameScreen.cursor.y = -50
			m_interface.gameScreen.cadrePreview.x = -500;
			m_interface.gameScreen.cadreJeu.x = 1200;
			
			var delay : Number = 0;
			TweenLite.to(m_interface.ecran5, TWEEN_TIME_SLIDE, { delay : delay += 0, y : 1920, onStart : function() : void { s_slideInterfaceSnd.play(); }, onComplete : function() : void { m_interface.ecran5.visible = false; m_interface.ecran5.y = 0; m_interface.gameScreen.y = -1920; m_interface.gameScreen.visible = true; } });
			TweenLite.to(m_interface.gameScreen, TWEEN_TIME_SLIDE, { delay : delay += TWEEN_TIME_SLIDE, y : 0, onStart : function() : void { }, onComplete : function() : void {  } });
			TweenLite.to(m_interface.gameScreen.score, 0.7, { delay : delay += TWEEN_TIME_SLIDE, y : 1523.15, onStart : function() : void { s_slideItemSnd.play(); }, onComplete : function() : void {  } });
			TweenLite.to(m_interface.gameScreen.timer, 0.7, { delay : delay += 0.7, y : 1288.45, onStart : function() : void { s_slideItemSnd.play(); }, onComplete : function() : void {  } });
			TweenLite.to(m_interface.gameScreen.level, 0.7, { delay : delay += 0.7, y : 1063.10, onStart : function() : void { s_slideItemSnd.play(); }, onComplete : function() : void {  } });
			TweenLite.to(m_interface.gameScreen.cursor, 0.7, { delay : delay += 0.7, y : 647.3, onStart : function() : void { s_slideItemSnd.play(); }, onComplete : function() : void {  } });
			TweenLite.to(m_interface.gameScreen.cadrePreview, 0.7, { delay : delay += 0.7, x : 70.8, onStart : function() : void { s_slideItemSnd.play(); }, onComplete : function() : void {  } });
			TweenLite.to(m_interface.gameScreen.cadreJeu, 0.7, { delay : delay += 0, x : 406.85, onStart : function() : void { s_slideItemSnd.play(); }, onComplete : function() : void { enableNextStep(); m_tetris.startGame(); s_tetrisSnd.play(4); if (debug)m_gsrSensor.startRandomProcess(); } });
		}
		
		/**
		 * show game over screen
		 */
		public function showGameOver() : void
		{
			m_state = STATE_GAMEOVER;
			
			s_tetrisSnd.stop();
			s_gameOverSnd.play();
			
			refreshTimer();
			
			s_logManager.write("[log] end game");
			
			m_interface.gameScreen.visible = true;
			m_interface.gameOverScreen.visible = true;
			
			m_tetris.stopTimers();
			m_gsrSensor.stopSensor();
			
			var delay : Number = 0;
			TweenLite.to(m_interface.gameOverScreen, 5, { onStart : function() : void {  }, onComplete : function() : void { } });
			TweenLite.to(m_interface.gameScreen, TWEEN_TIME_SLIDE, { delay : delay += 5, y : 1920, onStart : function() : void { s_slideInterfaceSnd.play(); }, onComplete : function() : void { m_interface.gameScreen.visible = false; m_interface.gameScreen.y = 0; showWelcome(); } });
		}
		
		/**
		 * show conclusion screen
		 */
		public function showConclusion() : void
		{
			m_state = STATE_CONCLUSION;
			
			disableNextStep();
			
			m_interface.gameOverScreen.visible = false;
			m_interface.conclusionScreen.mask = m_mask;
			m_interface.conclusionScreen.iconeBouton.scaleX = 0;
			m_interface.conclusionScreen.iconeBouton.scaleY = 0;
			
			var delay : Number = 0;
			TweenLite.to(m_interface.gameScreen, TWEEN_TIME_SLIDE, { delay : delay += TWEEN_TIME_SLIDE, y : 1920, onStart : function() : void { s_slideInterfaceSnd.play(); }, onComplete : function() : void { m_interface.gameScreen.visible = false; m_interface.gameScreen.y = 0; m_interface.conclusionScreen.y = -1920; m_interface.conclusionScreen.visible = true; } });
			TweenLite.to(m_interface.conclusionScreen, TWEEN_TIME_SLIDE, { delay : delay += TWEEN_TIME_SLIDE, y : 0, onStart : function() : void { s_slideInterfaceSnd.play(); }, onComplete : function() : void { } });
			TweenLite.to(m_interface.conclusionScreen.iconeBouton, TWEEN_TIME_BUTTON, { delay : delay += TWEEN_TIME_SLIDE, scaleX : 1, scaleY : 1, ease : Bounce.easeOut, onStart : function() : void { s_showValidButtonSnd.play(); }, onComplete : function() : void { enableNextStep(); } });
		}
		
		public function refreshTimer() : void 
		{
			s_timeoutSnd.stop();
			
			TweenLite.killTweensOf(m_interface.timeout.timeoutCursor.getChildAt(0));
			TweenLite.killTweensOf(m_interface.timeout.timeoutCursor.getChildAt(1));
			TweenLite.killTweensOf(m_interface.timeout.timeoutCursor.getChildAt(2));
			TweenLite.killTweensOf(m_interface.timeout.timeoutCursor.getChildAt(3));
			TweenLite.killTweensOf(m_interface.timeout.timeoutCursor.getChildAt(4));
			TweenLite.killTweensOf(m_interface.timeout.timeoutCursor.getChildAt(5));
			TweenLite.killTweensOf(m_interface.timeout.timeoutCursor.getChildAt(6));
			TweenLite.killTweensOf(m_interface.timeout.timeoutCursor.getChildAt(7));
			TweenLite.killTweensOf(m_interface.timeout.timeoutCursor.getChildAt(8));
			
			m_interface.timeout.visible = false;
			m_isTimeOut = false;
			s_timerManager.RefreshChrono();
		}
		
		
		/////////////
		// Listeners
		/////////////
		
		
		/**
		 * EVENT_PRESETS_LOADED event
		 * 
		 */
		private function onPresetsLoaded(evt : Event) : void
		{
			removeEventListener(PresetManager.EVENT_PRESETS_LOADED, onPresetsLoaded);
			
			init();
		}
		
		/**
		 * Inactivity timeout
		 */
		private function onTimeOut(evt : Event) : void
		{
			s_timeoutSnd.play();
			
			m_interface.timeout.timeoutCursor.getChildAt(0).alpha = 0.3;
			m_interface.timeout.timeoutCursor.getChildAt(1).alpha = 0.3;
			m_interface.timeout.timeoutCursor.getChildAt(2).alpha = 0.3;
			m_interface.timeout.timeoutCursor.getChildAt(3).alpha = 0.3;
			m_interface.timeout.timeoutCursor.getChildAt(4).alpha = 0.3;
			m_interface.timeout.timeoutCursor.getChildAt(5).alpha = 0.3;
			m_interface.timeout.timeoutCursor.getChildAt(6).alpha = 0.3;
			m_interface.timeout.timeoutCursor.getChildAt(7).alpha = 0.3;
			m_interface.timeout.timeoutCursor.getChildAt(8).alpha = 0.3;
			
			m_interface.timeout.visible = true;
			m_isTimeOut = true;
			
			var delay : Number = 0;
			TweenLite.to(m_interface.timeout.timeoutCursor.getChildAt(0), 1, { delay : delay += 0, onComplete : function() : void { m_interface.timeout.timeoutCursor.getChildAt(0).alpha = 1; } });
			TweenLite.to(m_interface.timeout.timeoutCursor.getChildAt(1), 1, { delay : delay += 1, onComplete : function() : void { m_interface.timeout.timeoutCursor.getChildAt(1).alpha = 1; } });
			TweenLite.to(m_interface.timeout.timeoutCursor.getChildAt(2), 1, { delay : delay += 1, onComplete : function() : void { m_interface.timeout.timeoutCursor.getChildAt(2).alpha = 1; } });
			TweenLite.to(m_interface.timeout.timeoutCursor.getChildAt(3), 1, { delay : delay += 1, onComplete : function() : void { m_interface.timeout.timeoutCursor.getChildAt(3).alpha = 1; } });
			TweenLite.to(m_interface.timeout.timeoutCursor.getChildAt(4), 1, { delay : delay += 1, onComplete : function() : void { m_interface.timeout.timeoutCursor.getChildAt(4).alpha = 1; } });
			TweenLite.to(m_interface.timeout.timeoutCursor.getChildAt(5), 1, { delay : delay += 1, onComplete : function() : void { m_interface.timeout.timeoutCursor.getChildAt(5).alpha = 1; } });
			TweenLite.to(m_interface.timeout.timeoutCursor.getChildAt(6), 1, { delay : delay += 1, onComplete : function() : void { m_interface.timeout.timeoutCursor.getChildAt(6).alpha = 1; } });
			TweenLite.to(m_interface.timeout.timeoutCursor.getChildAt(7), 1, { delay : delay += 1, onComplete : function() : void { m_interface.timeout.timeoutCursor.getChildAt(7).alpha = 1; } });
			TweenLite.to(m_interface.timeout.timeoutCursor.getChildAt(8), 1, { delay : delay += 1, onComplete : function() : void { m_interface.timeout.timeoutCursor.getChildAt(8).alpha = 1; showWelcome(); } });
		}
		
		private function key_pressed(evt : KeyboardEvent) : void 
		{
			if (m_state != STATE_WELCOME && m_state != STATE_GAME && !m_isTimeOut)
				refreshTimer();
			
			if (m_state == STATE_LANG)
			{
				if (evt.keyCode == CODE_LEFT)
				{
					s_clickDirSnd.play();
					m_interface.languageScreen.btChoixLang.x = 238;
					updateTextLang(s_presetManager.getPresetStringValue("/languages/main"));
				}
				if (evt.keyCode == CODE_RIGHT)
				{
					s_clickDirSnd.play();
					m_interface.languageScreen.btChoixLang.x = 716;
					updateTextLang(s_presetManager.getPresetStringValue("/languages/second"));
				}
			}
			
			if (m_state == STATE_GAME)
			{
				if (evt.keyCode == CODE_UP)
				{
					if (!m_isKeyDown)
					{
						m_isKeyDown = true;
						m_tetris.key_pressed(evt);
					}
				}
				else
					m_tetris.key_pressed(evt);
			}
		}
		
		private function key_released(evt : KeyboardEvent) : void 
		{
			m_isKeyDown = false;
			
			if (m_state != STATE_GAME && m_state != STATE_CALIBRATION && !m_isTimeOut && evt.keyCode == CODE_VALID)
			{
				s_clickValidSnd.play();
				showNextStep();
			}
			else
				m_tetris.key_released(evt);
			
			if (m_state != STATE_WELCOME && m_state != STATE_GAME)
			{
				refreshTimer();
			}
		}
	}
}