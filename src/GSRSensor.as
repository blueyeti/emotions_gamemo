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
	import com.greensock.TweenLite;
	import com.greensock.easing.Linear;
	import com.greensock.easing.Sine;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.display.CapsStyle;
	import flash.display.LineScaleMode;
	import flash.display.MovieClip;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.IOErrorEvent;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.geom.Point;
	import flash.utils.Timer;
	
	import fr.blueyeti.utils.Utils;
	
	/**
	 * GSRSensor class, communication with GSR sensor through python script
	 * @author Laurent Garnier
	 */
	public class GSRSensor extends Sprite
	{
		public static const PLOT_WIDTH 			: int = 930;
		public static const PLOT_HEIGHT 		: int = 180;
		public static const TIME_MIN	 		: Number = 0;
		public static const TIME_MAX	 		: Number = 60;
		public static const GSR_MIN		 		: Number = 0;
		public static const GSR_MAX		 		: Number = 5;
		public static const LINE_THICKNESS		: int = 2;
		public static const EMOPLAY_START_TIME	: int = 30;
		
		// graphical elements
		private var m_parent 					: MovieClip;				// parent class
		private var m_interface 				: InterfaceClip;			// main interface mc
		private var m_tetris 					: Tetris
		
		private var m_process					: NativeProcess;			// native process to call python script
		private var m_processInfo 				: NativeProcessStartupInfo;	// native process infos
		private var m_GSRGraph					: Sprite;
		
		private var m_points 					: Vector.<Number>;
		
		// timer
		private var m_timerRandomAnxiety 		: Timer;
		private var m_timerRandomData	 		: Timer;
		private var m_timerRandomEndCalib	 	: Timer;
		
		private var m_slidePoint 				: Point;
		
		private var debug 						: Boolean;
		
		private var m_arc1 						: Shape;					// arc de cercle de la palette
		public var m_angle 						: Number;					// angle de la palette
		private var m_startingTime 				: Number;
		
		public function GSRSensor(parent : MovieClip, mainInterface : InterfaceClip, tetris : Tetris)
		{
			m_parent = parent;
			m_interface = mainInterface;
			m_tetris = tetris;
			
			init();
		}
		
		/**
		 * init
		 */
		private function init() : void
		{			
			createGSRGraph();
			
			if (Main.s_presetManager.getPresetStringValue("/debug") == "false")
			{
				debug = false;
				createNativeProcess();
			}
			else
			{
				debug = true;
				createRandomProcess();
			}
			
			m_slidePoint = new Point();
			m_slidePoint.x = 0;
			
			m_arc1 = new Shape();
			m_arc1.name = "arc1";
			m_interface.calibrationScreen.addChild(m_arc1);
			m_angle = 90;
		}
		
		/**
		 * create GSR Graph
		 */
		private function createGSRGraph() : void
		{
			m_points = new Vector.<Number>();
			
			m_GSRGraph = new Sprite();
			m_interface.cadreCourbe.courbe.addChild(m_GSRGraph);
			m_interface.cadreCourbe.courbe.mask = m_interface.cadreCourbe.courbeMask;
			m_GSRGraph.graphics.lineStyle(LINE_THICKNESS, 0xFF0010);
			m_GSRGraph.graphics.moveTo(getTimeInPixels(0), getGSRInPixels(0));
		}
		
		/**
		 * create native process
		 */
		private function createNativeProcess() : void
		{
			if (!NativeProcess.isSupported)
			{
				trace("NativeProcess not supported.");
				Main.s_logManager.write("[err] native process not supported");
				
				return;
			}
			
			trace("NativeProcess supported.");
			Main.s_logManager.write("[log] native process supported");
			
			var file : File = File.userDirectory.resolvePath(Main.s_presetManager.getPresetStringValue("/python/bin"));
			m_processInfo = new NativeProcessStartupInfo();
			m_processInfo.executable = file;
			
			var processArgs:Vector.<String> = new Vector.<String>();
			processArgs.push([Main.s_presetManager.getPresetStringValue("/python/gsr")]);
			m_processInfo.arguments = processArgs;
			
			m_process = new NativeProcess();
			m_process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData);
			m_process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData);
			m_process.addEventListener(NativeProcessExitEvent.EXIT, onExit);
			m_process.addEventListener(IOErrorEvent.STANDARD_OUTPUT_IO_ERROR, onIOError);
			m_process.addEventListener(IOErrorEvent.STANDARD_ERROR_IO_ERROR, onIOError);
		}
		
		/**
		 * create random process for debug without python
		 */
		private function createRandomProcess() : void
		{
			m_timerRandomAnxiety = new Timer(5000, int(Main.s_presetManager.getPresetValue("/time/chrono")));
			m_timerRandomAnxiety.addEventListener(TimerEvent.TIMER, onTimerAnxietyTick);
			
			m_timerRandomData = new Timer(200, int(Main.s_presetManager.getPresetValue("/time/chrono"))*5);
			m_timerRandomData.addEventListener(TimerEvent.TIMER, onTimerDataTick);
			
			m_timerRandomEndCalib = new Timer(2 * EMOPLAY_START_TIME * 1000, 1);
			m_timerRandomEndCalib.addEventListener(TimerEvent.TIMER_COMPLETE, onTimerEndCalibration);
		}
		
		/**
		 * create time measure in pixels
		 */
		private function getTimeInPixels(value : Number) : Number
		{
			return Utils.normalize(value, TIME_MIN, TIME_MAX, 0, PLOT_WIDTH);
		}
		
		/**
		 * create GSR measure in pixels
		 */
		private function getGSRInPixels(value : Number) : Number
		{
			return Utils.normalize(value, GSR_MIN, GSR_MAX, 0, -PLOT_HEIGHT) + 186;
		}
		
		/**
		 * reset
		 */
		public function reset() : void
		{
			if (!debug)
				if (m_process.running)
				{
					trace("[log] exit python process");
					Main.s_logManager.write("[log] exit python process");
					m_process.exit(true);
				}
			
			if (debug)
			{
				m_timerRandomAnxiety.stop();
				m_timerRandomData.stop();
				m_timerRandomEndCalib.stop();
				m_timerRandomAnxiety.reset();
				m_timerRandomData.reset();
				m_timerRandomEndCalib.stop();
			}
			
			m_GSRGraph.graphics.clear();
			m_GSRGraph.graphics.lineStyle(LINE_THICKNESS, 0xFF0010);
			m_GSRGraph.graphics.moveTo(getTimeInPixels(0), getGSRInPixels(0));
			m_GSRGraph.x = 0;
			m_points.length = 0;
			
			m_arc1.graphics.clear();
			m_angle = 90;
			m_startingTime = 0;
			
			m_interface.gameScreen.cursor.curseurEmotion.x = -24.30;
		}
		
		public function startSensor() : void 
		{
			if (!debug)
			{
				if (m_process.running)
				{
					trace("[log] exit python process");
					Main.s_logManager.write("[log] exit python process");
					m_process.exit(true);
				}
				
				trace("[log] start python process");
				Main.s_logManager.write("[log] start python process");
				m_process.start(m_processInfo);
				
//				TweenLite.killTweensOf(m_slidePoint);
//				m_slidePoint.x = 0;
//				TweenLite.to(m_slidePoint, EMOPLAY_START_TIME, { x : getTimeInPixels(EMOPLAY_START_TIME), ease:Linear.easeNone, onUpdate : function() : void { m_GSRGraph.graphics.lineTo(m_slidePoint.x, getGSRInPixels(GSR_MAX / 4)); }});
				m_arc1.graphics.clear();
				m_angle = -90;
				TweenLite.to(this, EMOPLAY_START_TIME*2, { ease : Linear.easeNone, m_angle : 270, onStart:function() {  }, onUpdate:function() { drawCircleArc(540.025, 1573.875, -90, m_angle, 210, 0xFFF200, m_arc1); }, onComplete:function() {  }} );
			}
			else
			{
				m_timerRandomEndCalib.start();
//				TweenLite.killTweensOf(m_slidePoint);
//				m_slidePoint.x = 0;
//				TweenLite.to(m_slidePoint, EMOPLAY_START_TIME, { x : getTimeInPixels(EMOPLAY_START_TIME), ease:Linear.easeNone, onUpdate : function() : void { m_GSRGraph.graphics.lineTo(m_slidePoint.x, getGSRInPixels(GSR_MAX / 4)); }, 
//					onComplete : function() : void 
//					{
//						trace("[log] end calibration");
//						Main.s_logManager.write("[log] end calibration");
//						m_timerRandomData.start();
//					}});
				m_arc1.graphics.clear();
				m_angle = -90;
				TweenLite.to(this, EMOPLAY_START_TIME*2, { ease : Linear.easeNone, m_angle : 270, onStart:function() {  }, onUpdate:function() { drawCircleArc(540.025, 1573.875, -90, m_angle, 210, 0xFFF200, m_arc1); }, 
					onComplete:function() 
					{  
						trace("[log] end calibration");
						Main.s_logManager.write("[log] end calibration");
						m_timerRandomData.start();
					}});
			}
		}
		
		public function startRandomProcess() : void 
		{
			m_timerRandomAnxiety.reset();
			m_timerRandomAnxiety.start();
		}
		
		public function stopSensor() : void 
		{
			if (!debug)
			{
				if (m_process.running)
				{
//					m_process.standardInput.writeBoolean(true);
					trace("[log] exit python process");
					Main.s_logManager.write("[log] exit python process");
					m_process.exit(true);
				}
			}
			else
				m_timerRandomAnxiety.stop();
		}
		
		/**
		 * start calibration
		 */
		public function startCalibration() : void
		{	
			trace("[log] start calibration");
			Main.s_logManager.write("[log] start calibration");
			
			startSensor();
		}
		
		/**
		 * Fonction qui trace un arc de cercle
		 */
		private function drawCircleArc(x:Number, y:Number, angledep:Number, anglefin:Number, rayon:Number, color:uint, arc:Shape) : void
		{
			angledep = angledep / 180 * Math.PI;
			anglefin = anglefin / 180 * Math.PI;
			var segmentAngle:Number = ((anglefin - angledep) / 8);
			var controlDist:Number = rayon / Math.cos (segmentAngle / 2);
			
			arc.graphics.clear();
			arc.graphics.lineStyle(20, color, 1, false, LineScaleMode.NORMAL, CapsStyle.NONE);
			arc.graphics.moveTo(x+rayon*Math.cos(angledep),y+rayon*Math.sin(angledep));
			for (var e:int = 1; e <= 8; e ++)
			{
				var endX:Number =x + rayon * Math.cos (angledep + e * segmentAngle);
				var endY:Number =y +  rayon * Math.sin (angledep + e * segmentAngle);
				var controlX:Number =x + controlDist * Math.cos (angledep+e * segmentAngle - segmentAngle / 2);
				var controlY:Number =y + controlDist * Math.sin (angledep+e * segmentAngle - segmentAngle / 2);
				arc.graphics.curveTo(controlX, controlY, endX, endY);
			}
		}
		
		
		/////////////
		// Listeners
		/////////////
		
		
		public function onOutputData(event : ProgressEvent) : void
		{	
			var datas:String = m_process.standardOutput.readUTFBytes(m_process.standardOutput.bytesAvailable);

			if (datas.search("Starting") >= 0)
			{
				trace("[log] end calibration");
				Main.s_logManager.write("[log] end calibration");
				
				m_parent.showCalibrationEnd();
			}
			
			if (datas.search("Anxiety") >= 0)
			{
				trace("[log] anxiety detected");
				Main.s_logManager.write("[log] anxiety detected");
				if (m_tetris.isRunning)
				{
					m_interface.gameScreen.cursor.curseurEmotion.x += 20;
					if (m_interface.gameScreen.cursor.curseurEmotion.x >= 208.4)
						m_interface.gameScreen.cursor.curseurEmotion.x = 208.4;
				}
				if (m_tetris.isRunning && m_tetris.level >= 2)
				{
					m_tetris.level -= 1;
					Main.s_levelDownSnd.play();
					trace("[log] => level down = " + m_tetris.level.toString());
					Main.s_logManager.write("[log] => level down = " + m_tetris.level.toString());
					
					m_interface.gameScreen.niveauAlpha.htmlText = "<font size=100>"+Main.s_presetManager.getPresetStringValue("/game/level", -1, m_parent.m_lang)+"<br></font>" + "<font size=200>-1</font>";
					m_interface.gameScreen.niveauAlpha.height = m_interface.gameScreen.niveauAlpha.textHeight;
					m_interface.gameScreen.niveauAlpha.alpha = 0.5;
					m_interface.gameScreen.level.containerLevel.niveau.textColor = 0xFFF200;
					m_interface.gameScreen.level.levelLabel.textColor = 0xFFF200;
					TweenLite.to(m_interface.gameScreen.niveauAlpha, 1.2, { ease : Sine.easeOut, x : -98.45, y : 928.5, alpha : 0.2, onComplete : function() : void 
					{ 
						m_interface.gameScreen.niveauAlpha.alpha = 0;
						m_interface.gameScreen.niveauAlpha.x = 417.5;
						m_interface.gameScreen.niveauAlpha.y = 881.6;
						m_interface.gameScreen.level.containerLevel.scaleX = 1.5;
						m_interface.gameScreen.level.containerLevel.scaleY = 1.5;
						m_interface.gameScreen.level.containerLevel.niveau.text = m_tetris.level.toString();
						
						TweenLite.to(m_interface.gameScreen.level.containerLevel, 1, { scaleX : 1, scaleY : 1, onComplete : function() : void 
						{ 
							m_interface.gameScreen.level.containerLevel.niveau.textColor = 0xFFFFFF;
							m_interface.gameScreen.level.levelLabel.textColor = 0xFFFFFF;
						}});
					}});
				}
			}
			
			if (datas.search("Boredom") >= 0)
			{
				trace("[log] boredom detected");
				Main.s_logManager.write("[log] boredom detected");
				if (m_tetris.isRunning)
				{
					m_tetris.level += 1;
					Main.s_levelUpSnd.play();
					
					trace("[log] => level up = " + m_tetris.level.toString());
					Main.s_logManager.write("[log] => level up = " + m_tetris.level.toString());
					
					m_interface.gameScreen.cursor.curseurEmotion.x -= 20;
					if (m_interface.gameScreen.cursor.curseurEmotion.x <= -294.1)
						m_interface.gameScreen.cursor.curseurEmotion.x = -294.1;
					
					m_interface.gameScreen.niveauAlpha.htmlText = "<font size=100>"+Main.s_presetManager.getPresetStringValue("/game/level", -1, m_parent.m_lang)+"<br></font>" + "<font size=200>+1</font>";
					m_interface.gameScreen.niveauAlpha.height = m_interface.gameScreen.niveauAlpha.textHeight;
					m_interface.gameScreen.niveauAlpha.alpha = 0.5;
					m_interface.gameScreen.level.containerLevel.niveau.textColor = 0xFFF200;
					m_interface.gameScreen.level.levelLabel.textColor = 0xFFF200;
					TweenLite.to(m_interface.gameScreen.niveauAlpha, 1.2, { ease : Sine.easeOut, x : -98.45, y : 928.5, alpha : 0.2, onComplete : function() : void 
					{ 
						m_interface.gameScreen.niveauAlpha.alpha = 0;
						m_interface.gameScreen.niveauAlpha.x = 417.5;
						m_interface.gameScreen.niveauAlpha.y = 881.6;
						m_interface.gameScreen.level.containerLevel.scaleX = 1.5;
						m_interface.gameScreen.level.containerLevel.scaleY = 1.5;
						m_interface.gameScreen.level.containerLevel.niveau.text = m_tetris.level.toString();
						
						TweenLite.to(m_interface.gameScreen.level.containerLevel, 1, { scaleX : 1, scaleY : 1, onComplete : function() : void 
						{ 
							m_interface.gameScreen.level.containerLevel.niveau.textColor = 0xFFFFFF;
							m_interface.gameScreen.level.levelLabel.textColor = 0xFFFFFF;
						}});
					}});
				}
			}
			if (datas.search("rawdatas") >= 0)
			{
				var time : Number = Number(datas.substring(datas.indexOf(":") + 1, datas.indexOf(";")));
				if (!m_tetris.isRunning)
				{
					m_startingTime = time;
				}
				else
				{
					var gsr : Number = Number(datas.substr(datas.indexOf(";") + 1, 6));
					var xCoord : Number = getTimeInPixels(time - m_startingTime);
					var yCoord : Number = getGSRInPixels(gsr);
					
					// trace new point
					if (xCoord > 0)
						m_GSRGraph.graphics.lineTo(xCoord, yCoord);
					
					// move the graph to center on last measure
					if (xCoord >= PLOT_WIDTH)
						m_GSRGraph.x = -(xCoord - PLOT_WIDTH);
				}
			}
		}
		
		private function onTimerEndCalibration(e : TimerEvent) : void
		{
			trace("onTimerEndCalibration");
			m_parent.showCalibrationEnd();
		}
		
		private function onTimerDataTick(e : TimerEvent) : void
		{
			if (!m_tetris.isRunning)
			{
				m_startingTime = m_timerRandomData.currentCount/5;
			}
			if (m_tetris.isRunning)
			{
				var time : int = getTimeInPixels(m_timerRandomData.currentCount/5 - m_startingTime);
				var gsrRaw : Number = Math.random() * 5;
				var gsr : Number = getGSRInPixels(gsrRaw);
				
				// rescale graph
				if (m_points.length >= 10)
					m_points.shift();
				m_points.push(gsr);
				
				var amp : Number = 0;
	//			if (m_points.length >= 30)
	//			{
					for (var i : uint = 0; i < m_points.length; i++)
					{
						if (m_points[i] > amp)
							amp = m_points[i];
					}
	//				trace("amp", amp);
					var factor : Number = PLOT_HEIGHT / amp;
//					trace("factor", factor);
					m_GSRGraph.scaleY = factor;
	//			}
				
				// trace new point
				if (time > 0)
					m_GSRGraph.graphics.lineTo(time, gsr);
				
				// move the graph to center on last measure
				if (time >= PLOT_WIDTH)
					m_GSRGraph.x = -(time - PLOT_WIDTH);
			}
		}
		
		private function onTimerAnxietyTick(e : TimerEvent) : void
		{
			var anxiety : int = Math.random() * 2;
			if (anxiety < 1)
			{
				trace("[log] anxiety detected => level = " + m_tetris.level.toString());
				Main.s_logManager.write("[log] anxiety detected => level = " + m_tetris.level.toString());
				if (m_tetris.isRunning && m_tetris.level >= 2)
				{
					m_tetris.level -= 1;
					Main.s_levelDownSnd.play();
					
					m_interface.gameScreen.cursor.curseurEmotion.x += 20;
					if (m_interface.gameScreen.cursor.curseurEmotion.x >= 208.4)
						m_interface.gameScreen.cursor.curseurEmotion.x = 208.4;
					
					m_interface.gameScreen.niveauAlpha.htmlText = "<font size=100>"+Main.s_presetManager.getPresetStringValue("/game/level", -1, m_parent.m_lang)+"<br></font>" + "<font size=200>-1</font>";
					m_interface.gameScreen.niveauAlpha.height = m_interface.gameScreen.niveauAlpha.textHeight;
					m_interface.gameScreen.niveauAlpha.alpha = 0.5;
					m_interface.gameScreen.level.containerLevel.niveau.textColor = 0xFFF200;
					m_interface.gameScreen.level.levelLabel.textColor = 0xFFF200;
					TweenLite.to(m_interface.gameScreen.niveauAlpha, 1.2, { ease : Sine.easeOut, x : -98.45, y : 928.5, alpha : 0.2, onComplete : function() : void 
					{ 
						m_interface.gameScreen.niveauAlpha.alpha = 0;
						m_interface.gameScreen.niveauAlpha.x = 417.5;
						m_interface.gameScreen.niveauAlpha.y = 881.6;
						m_interface.gameScreen.level.containerLevel.scaleX = 1.5;
						m_interface.gameScreen.level.containerLevel.scaleY = 1.5;
						m_interface.gameScreen.level.containerLevel.niveau.text = m_tetris.level.toString();
						
						TweenLite.to(m_interface.gameScreen.level.containerLevel, 1, { scaleX : 1, scaleY : 1, onComplete : function() : void 
						{ 
							m_interface.gameScreen.level.containerLevel.niveau.textColor = 0xFFFFFF;
							m_interface.gameScreen.level.levelLabel.textColor = 0xFFFFFF;
						}});
					}});
				}
			}
			else
			{
				trace("[log] boredom detected => level = " + m_tetris.level.toString());
				Main.s_logManager.write("[log] boredom detected => level = " + m_tetris.level.toString());
				
				if (m_tetris.isRunning && m_tetris.level >= 0)
				{
					m_tetris.level += 1;
					Main.s_levelUpSnd.play();
					
					m_interface.gameScreen.cursor.curseurEmotion.x -= 20;
					if (m_interface.gameScreen.cursor.curseurEmotion.x <= -294.1)
						m_interface.gameScreen.cursor.curseurEmotion.x = -294.1;
					
					m_interface.gameScreen.niveauAlpha.htmlText = "<font size=100>"+Main.s_presetManager.getPresetStringValue("/game/level", -1, m_parent.m_lang)+"<br></font>" + "<font size=200>+1</font>";
					m_interface.gameScreen.niveauAlpha.height = m_interface.gameScreen.niveauAlpha.textHeight;
					m_interface.gameScreen.niveauAlpha.alpha = 0.5;
					m_interface.gameScreen.level.containerLevel.niveau.textColor = 0xFFF200;
					m_interface.gameScreen.level.levelLabel.textColor = 0xFFF200;
					TweenLite.to(m_interface.gameScreen.niveauAlpha, 1.2, { ease : Sine.easeOut, x : -98.45, y : 928.5, alpha : 0.2, onComplete : function() : void 
					{ 
						m_interface.gameScreen.niveauAlpha.alpha = 0;
						m_interface.gameScreen.niveauAlpha.x = 417.5;
						m_interface.gameScreen.niveauAlpha.y = 881.6;
						m_interface.gameScreen.level.containerLevel.scaleX = 1.5;
						m_interface.gameScreen.level.containerLevel.scaleY = 1.5;
						m_interface.gameScreen.level.containerLevel.niveau.text = m_tetris.level.toString();
						
						TweenLite.to(m_interface.gameScreen.level.containerLevel, 1, { scaleX : 1, scaleY : 1, onComplete : function() : void 
						{ 
							m_interface.gameScreen.level.containerLevel.niveau.textColor = 0xFFFFFF;
							m_interface.gameScreen.level.levelLabel.textColor = 0xFFFFFF;
						}});
					}});
				}
			}
		}
		
		public function onErrorData(event : ProgressEvent) : void
		{
			if (m_process.running)
			{
				Main.s_logManager.write("[err] emoplay data error " + m_process.standardError.readUTFBytes(m_process.standardError.bytesAvailable));
				trace("[err] emoplay data error ", m_process.standardError.readUTFBytes(m_process.standardError.bytesAvailable)); 
			}
		}
		
		public function onExit(event : NativeProcessExitEvent) : void
		{
			Main.s_logManager.write("[log] emoplay exited");
			trace("[log] emoplay exited ", event.exitCode);
		}
		
		public function onIOError(event : IOErrorEvent) : void
		{
			Main.s_logManager.write("[err] emoplay IO error" + event.toString());
			trace("[err] emoplay IO error" + event.toString());
		}
	}
}