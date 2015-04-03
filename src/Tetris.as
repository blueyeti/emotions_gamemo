/* 
Copyright (c) 2008 Anthony Rogers (trresonant@yahoo.com)
www.brainblitz.org

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
	import com.greensock.easing.Expo;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.TimerEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Timer;
	
	/**
	 * Tetris class
	 * @author Anthony Rogers, Laurent Garnier
	 */
	public class Tetris extends MovieClip 
	{
		public static const LINEPOINTS 		: int = 800;
		public static const PIECEPOINTS 	: int = 10;
		public static const LEVELINC 		: int = 6000;
		
		public static const BLOCKMAP_WIDTH 	: int = 420;
		public static const BLOCK_WIDTH 	: int = 60;
		public static const PREVIEW_WIDTH 	: int = 302;
		
		// graphical elements
		private var m_parent 				: MovieClip;			// parent class
		private var m_interface 			: InterfaceClip;		// main interface mc
		
		private var body					: Body; // Body Object to hold a set of Block Objects
		private var nextBody				: Body; // where the upcoming body is stored. Necessary for preview.
		
		// incrementing private variables to control timing of operations.
		private var currentStep				: Number = 0;
		private var currentConStep			: Number = 0; // current "Control" Step
		private var totalSteps				: int = 20;
		
		private var aryBlockRow 			: Array;
		
		// used by function commitBody to determine if row is completely filled.
		private var aryBlockSum				: Array;
		
		private var moveDown				: Boolean = false;
		
		private var m_blockMap				: BitmapData;
		private var bCanvasBuffer			: Bitmap;
		private var bCanvasBufferData		: BitmapData;
		private var bPreviewBufferData		: BitmapData;
		private var bPreviewBuffer			: Bitmap;
		
		private var ii:int;
		private var jj:int;
		
		//game logic private variables
		private var score					:int;
		private var levelIncScore			:int;
		public  var level					:int;
		private var lines					:int;
		private var scoreMultiplier			:int;			
		private var gameOver				:Boolean = false;
		public  var isRunning				:Boolean = false;
		
		// timer
		private var m_timerTick				: Timer;
		private var m_time					: int;
		
		public function Tetris(parent : MovieClip, mainInterface : InterfaceClip)
		{
			m_parent = parent;
			m_interface = mainInterface;
			
			init();
		}
		
		private function init() : void
		{
			// init timers
			m_time = int(Main.s_presetManager.getPresetValue("/time/chrono"));
			m_interface.gameScreen.timer.containerTime.temps.text = m_time.toString();
			
			m_timerTick = new Timer(1000, m_time);
			m_timerTick.addEventListener(TimerEvent.TIMER, onTimerTick);
			
			loadGame();
		}
		
		// load game is called only when swf is first loaded. Restarting the game does not call this function.
		public function loadGame():void
		{	
			//---------------------------------------------------------------------------------------------
			//set up drawing surfaces ---------------------------------------------------------------------
			//---------------------------------------------------------------------------------------------
			
			// main drawing surface
			bCanvasBufferData = new BitmapData(m_interface.gameScreen.cadreJeu.width, m_interface.gameScreen.cadreJeu.height, true);
			bCanvasBuffer = new Bitmap(bCanvasBufferData);
			m_interface.gameScreen.cadreJeu.addChild(bCanvasBuffer);
			
			// piece preview drawing surface
			bPreviewBufferData = new BitmapData(m_interface.gameScreen.cadrePreview.width, m_interface.gameScreen.cadrePreview.height, true);
			bPreviewBuffer = new Bitmap(bPreviewBufferData);
			m_interface.gameScreen.cadrePreview.addChild(bPreviewBuffer);
			
			// block map
			m_blockMap = new BlockMapBitmapData();	
			
			// main game loop
			addEventListener(Event.ENTER_FRAME, Run);
			
			reset();	
		}
		
		// reset is called every time the game is restarted. All game logic variables are cleared.
		public function reset() : void 
		{
			// create resetial and preview pieces.
			body = new Body(PREVIEW_WIDTH, -BLOCK_WIDTH); // "-" BLOCK_WIDTH used to start objects 1 step above canvas visibility
			nextBody = new Body(PREVIEW_WIDTH, -BLOCK_WIDTH);
			
			// create arrays
			aryBlockRow = new Array(); 
			aryBlockSum = new Array();
			
			// reset arrays. aryBlockRow is a 2-dimensional (nested) array.
			for(ii = 0; ii < 18; ii++) {
				aryBlockRow[ii] = new Array();
				aryBlockSum[ii] = 0;
			}
			
			// resetialize game logic.
			gameOver = false;
			isRunning = false; // game won't run until user presses start key
			score = 0;
			lines = 0;
			level = 1;
			scoreMultiplier = 0;
			m_interface.gameScreen.score.containerScore.score.text = "0";
			m_interface.gameScreen.level.containerLevel.niveau.text = "1";
			m_interface.gameScreen.niveauAlpha.text = "1";
			m_interface.gameScreen.niveauAlpha.alpha = 0;
			
			// reset timers
			m_time = int(Main.s_presetManager.getPresetValue("/time/chrono"));
			m_interface.gameScreen.timer.containerTime.temps.text = m_time.toString();
			m_interface.gameScreen.timer.containerTime.temps.textColor = 0xFFFFFF;
			m_interface.gameScreen.timer.timerLabel.textColor = 0xFFFFFF;
			
			m_timerTick.stop();
			m_timerTick.reset();
			
			// clear preview buffer
			bCanvasBufferData.fillRect(new Rectangle(0, 0, bCanvasBufferData.width, bCanvasBufferData.height), 0x000000);
			bPreviewBufferData.fillRect(new Rectangle(0, 0, bPreviewBufferData.width, bPreviewBufferData.height), 0x000000);
			
			// draw preview piece into preview buffer.
			for(ii = 0; ii < nextBody.block.length; ii++) {
				bPreviewBufferData.copyPixels(m_blockMap, new Rectangle(nextBody.block[ii].spriteoffset, 0, BLOCK_WIDTH, BLOCK_WIDTH), 
					new Point(nextBody.block[ii].xp - nextBody.GetCenter().x + 120, nextBody.block[ii].yp - nextBody.GetCenter().y + 60), null, null, true);
			}
		}
		
		/**
		 * start timer
		 */
		public function startTimers() : void
		{
			m_timerTick.reset();
			m_timerTick.start();
		}
		
		/**
		 * stop timer
		 */
		public function stopTimers() : void
		{
			Main.s_gameTimeoutSnd.stop();
			m_timerTick.stop();
		}
		
		/**
		 * start Tetris game
		 */
		public function startGame() : void 
		{
			trace("[log] start a game");
			Main.s_logManager.write("[log] start game");
			isRunning = true;
			startTimers();
		}
		
		/**
		 * stop Tetris game
		 */
		public function stopGame() : void 
		{
			isRunning = false;
			stopTimers();
		}
		
		private function Run(evt : Event) : void
		{		
			if (!isRunning) return; // game is paused if isRunning = false.
			
			// The run private function executes 30 times per second. currentStep increments by a certain amount each frame, and
			// only computes game logic when currentStep is greater than totalSteps. The increment value was chosen to
			// increase speed as the level increases. It uses the sqrt to causes the game to accelerate faster at the beginning
			// than later on. 1.35 was chosen by trial and error, such that the game does not advance TOO fast, but does not
			// get boring either.
			currentStep += Math.sqrt(Number(Main.s_presetManager.getPresetValue("/difficulty_factor")) * (level));
			
			// this limits how fast an object will move if the user is holding down the down-arrow key. It works similiar to currentStep.
			currentConStep += 1;
			
			// every time levelIncScore reaches the "next level" value, increment level, and reset levelIncScore.
			if(levelIncScore >= LEVELINC) {
				//				level++;
				levelIncScore = 0;
				m_interface.gameScreen.level.containerLevel.niveau.text = level.toString(); //update text field displaying current level.
			}			
			
			// has current step incremented far enough to advance the game?
			if(currentStep >= totalSteps) {
				// check current against existing				
				currentStep = 0;
				body.Move(0, BLOCK_WIDTH);
				collisionCheckVertical();
				// if current step has not incremented far enough to advance game, but the user is pressing the down arrow,
				// then advance the game. This simply lets the user "fast forward".
			} else if(currentConStep * 10 >= totalSteps && moveDown) {
				currentConStep = 0;
				body.Move(0, BLOCK_WIDTH);
				collisionCheckVertical();				
			}
			
			// clear drawing surface
			bCanvasBufferData.fillRect(new Rectangle(0, 0, bCanvasBufferData.width, bCanvasBufferData.height), 0x000000);
			
			// draw current body
			for(ii = 0; ii < body.block.length; ii++) {
				bCanvasBufferData.copyPixels(m_blockMap, new Rectangle(body.block[ii].spriteoffset, 1, BLOCK_WIDTH, BLOCK_WIDTH), 
					new Point(body.xp + body.block[ii].xp + 2,  body.yp + body.block[ii].yp + 1));
			}
			
			// draw blocks (committed bodies, per private function "commitBody()").
			for(jj = 0; jj < aryBlockRow.length; jj++) { 
				for(ii = 0; ii < aryBlockRow[jj].length; ii++) { 				
					if(aryBlockRow[jj][ii]) {						
						// copyPixels copies a rectangle of data from the sprite sheet (m_blockMap) to the canvas. The block objects 
						// themselves determine which one of 7 regions to copy from, based on the 7 tetris shapes.
						// the sprite sheet is a bitmap copy of the library symbol BlockMap.
						bCanvasBufferData.copyPixels(m_blockMap, new Rectangle(aryBlockRow[jj][ii].spriteoffset, 1, BLOCK_WIDTH, BLOCK_WIDTH), 
							new Point(aryBlockRow[jj][ii].xp + 2,  aryBlockRow[jj][ii].yp + 1));
					}
				}
			}		
		}
		
		
		// a vertical collision will always result in a body commit, so is distinct from horizontal collisions
		private function collisionCheckVertical():void 
		{
			
			// this scans through all of the blocks within a body, and if any have touched the "ground", it commits the body.		
			for(ii = 0; ii < body.block.length; ii++) {
				// to test the position of the block, you have to add the blocks position within the body to the body's position
				// within the "world". This gives you the BLOCKS position within the world.
				if(body.yp + body.block[ii].yp >= m_interface.gameScreen.cadreJeu.height - BLOCK_WIDTH) {
					commitBody();	
					return;
				}
			}
			
			// this checks current body's blocks against commited blocks for collisions.
			for(jj = 0; jj < aryBlockRow.length; jj++) { // scan through each row...
				for(ii = 0; ii < aryBlockRow[jj].length; ii++) { // scan through each block of each row...
					if(aryBlockRow[jj][ii]) { // if a block has been commited to that row...
						if(body.CollisionCheck(aryBlockRow[jj][ii])) { // was there a collision? Then commitBody.
							commitBody();			
							return;					
						}
					}
				}
			}						
		}
		
		//a horizontal collision does no result in committing a block. It simply means the body must be "rewound" to it's non-collision state.
		private function collisionCheckHorizontal():void 
		{
			
			//first check for collisions with the side of the canvas.
			for(ii = 0; ii < body.block.length; ii++) {
				if(body.xp + body.block[ii].xp > m_interface.gameScreen.cadreJeu.width - BLOCK_WIDTH || body.xp + body.block[ii].xp < 0) {
					body.Rewind();
					return;
				}
			}
			
			//now check for collisions with other blocks. 
			for(jj = 0; jj < aryBlockRow.length; jj++) { 
				for(ii = 0; ii < aryBlockRow[jj].length; ii++) { 		
					if(aryBlockRow[jj][ii]) {
						if(body.CollisionCheck(aryBlockRow[jj][ii])) {
							//unlike the similiar loop in the vertical collision test, this one does not commit the body,
							//it simply rewinds it to it's previous (valid) state.
							body.Rewind();				
						}
					}
				}
			}				
		}
		
		// rotation collision differs from horizontal collision in 2 ways.
		// 1. It might hit the bottom or side of the canvas, but that doesn't mean it should be commited, it just means it should be rewound.
		// 2. The body isn't "rewound" - it's "rotate rewound." This has to do with the way the body and block objects remember
		// their previous positions. Rewinding a rotate move is not as straight forward (see Body.as and Block.as).
		private function collisionCheckRotate():void 
		{
			for (ii = 0; ii < body.block.length; ii++) {
				// to test the position of the block, you have to add the blocks position within the body to the body's position
				// within the "world". This gives you the BLOCKS position within the world.
				if (body.xp + body.block[ii].xp > m_interface.gameScreen.cadreJeu.width - BLOCK_WIDTH || body.xp + body.block[ii].xp < 0 ||
					body.yp + body.block[ii].yp >= m_interface.gameScreen.cadreJeu.height -  BLOCK_WIDTH) 
				{
					body.RewindRotate();
					return;
				}
			}			
			
			for (jj = 0; jj < aryBlockRow.length; jj++) { 
				for (ii = 0; ii < aryBlockRow[jj].length; ii++) { 		
					if (aryBlockRow[jj][ii]) {
						if (body.CollisionCheck(aryBlockRow[jj][ii])) {
							body.RewindRotate();				
						}
					}
				}
			}		
		}
		
		// this private function is called after collisionCheckVertical detects a collision. It's private function is to:
		// 1. read the blocks from the body
		// 2. add the blocks to aryBlockRow
		// 3. calculate how many blocks are now in aryBlockRow
		// 4. if the number is "10", then the row is completely filled, so delete the row, increment score, level, etc, and play the 
		//   "rowEffect" clip (library symbol).
		// 5. if the collision happened when a body was in it's resetial position, then we know the blocks have reached the top of the
		//   screen, so "game over"
		private function commitBody() : void
		{		
			// last move resulted in collision, so rewind one step.
			body.Rewind();
			
			// transfer blocks from body to aryBlockRow.
			for (ii = 0; ii < body.block.length; ii++) 
			{
				// if collision happend at yp == 0, then game is over.
				if (body.yp + body.block[ii].yp <= 0)
				{
					isRunning = false;
					gameOver = true;
					// make sure moveDown is set to false if the down key was pressed when game ended. Otherwise the pieces will come flying
					// down the screen very fast when it restarts.
					moveDown = false;
					
					stopTimers();
					
					m_interface.gameOverScreen.gameOver.g.y = -1500;
					m_interface.gameOverScreen.gameOver.a.y = -1500;
					m_interface.gameOverScreen.gameOver.m.y = -1500;
					m_interface.gameOverScreen.gameOver.e1.y = -1500;
					m_interface.gameOverScreen.gameOver.o.y = -1500;
					m_interface.gameOverScreen.gameOver.v.y = -1500;
					m_interface.gameOverScreen.gameOver.e2.y = -1500;
					m_interface.gameOverScreen.gameOver.r.y = -1500;
					
					m_parent.showGameOver();
					
					TweenLite.to(m_interface.gameOverScreen.gameOver.g, 1, { ease : Expo.easeIn, y : -20.85 });
					TweenLite.to(m_interface.gameOverScreen.gameOver.a, 1, { ease : Expo.easeIn, delay : 1.3, y : -8.55 });
					TweenLite.to(m_interface.gameOverScreen.gameOver.m, 1, {  ease : Expo.easeIn, delay : 0.2, y : -9.3 });
					TweenLite.to(m_interface.gameOverScreen.gameOver.e1, 1, {  ease : Expo.easeIn, delay : 1.5, y : -8.4 });
					
					TweenLite.to(m_interface.gameOverScreen.gameOver.o, 1, {  ease : Expo.easeIn, delay : 2, y : 123.15 });
					TweenLite.to(m_interface.gameOverScreen.gameOver.v, 1, {  ease : Expo.easeIn, delay : 0.1, y : 135.6 });
					TweenLite.to(m_interface.gameOverScreen.gameOver.e2, 1, {  ease : Expo.easeIn, delay : 1.15, y : 135.6 });
					TweenLite.to(m_interface.gameOverScreen.gameOver.r, 1, {  ease : Expo.easeIn, delay : 0.5, y : 134.9 });
					
					return;
				}	
				
				// game is not over, so add block to appropriate row and column: aryBlockRow(row, column).  
				aryBlockRow[(body.yp + body.block[ii].yp)/BLOCK_WIDTH][int((body.xp + body.block[ii].xp)/BLOCK_WIDTH)] = 
					new Block((body.xp + body.block[ii].xp), (body.yp + body.block[ii].yp), body.block[ii].spriteoffset);
				// for each block that is added, increment score. levelIncScore is kept separate because it will reset to zero when the level increments.
				score += PIECEPOINTS;
				levelIncScore += PIECEPOINTS;
				
				// update score text.
				m_interface.gameScreen.score.containerScore.score.text = score.toString();
				m_interface.gameScreen.score.containerScore.score.textColor = 0xFFF200;
				m_interface.gameScreen.score.scoreLabel.textColor = 0xFFF200;
				m_interface.gameScreen.score.containerScore.scaleX = 1.5;
				m_interface.gameScreen.score.containerScore.scaleY = 1.5;
				Main.s_winBlockSnd.play();
				TweenLite.to(m_interface.gameScreen.score.containerScore, 1, { scaleX : 1, scaleY : 1, onComplete : function() : void 
				{ 
					m_interface.gameScreen.score.containerScore.score.textColor = 0xFFFFFF;
					m_interface.gameScreen.score.scoreLabel.textColor = 0xFFFFFF;
				}});
				
				// increment the block count for this row. Once the sum reaches "10", we know the row has been filled.
				aryBlockSum[(body.yp + body.block[ii].yp)/BLOCK_WIDTH] ++;
			}
			
			// scan through each row for filled rows.
			for (ii = 0; ii < aryBlockSum.length; ii++)
			{				
				// if block count = 10, the row is full
				if (aryBlockSum[ii] == 10)
				{
					// update score.
					score += scoreMultiplier * LINEPOINTS;
					
					// multiplier increments for each line eliminated in one move.
					scoreMultiplier++;
					
					levelIncScore += scoreMultiplier * LINEPOINTS;
					
					// update line count, and display.
					lines++;
					m_interface.gameScreen.score.containerScore.score.text = score.toString();
					m_interface.gameScreen.score.containerScore.score.textColor = 0xFFF200;
					m_interface.gameScreen.score.scoreLabel.textColor = 0xFFF200;
					m_interface.gameScreen.score.containerScore.scaleX = 1.5;
					m_interface.gameScreen.score.containerScore.scaleY = 1.5;
					Main.s_winLineSnd.play();
					TweenLite.to(m_interface.gameScreen.score.containerScore, 1, { scaleX : 1, scaleY : 1, onComplete : function() : void 
					{ 
						m_interface.gameScreen.score.containerScore.score.textColor = 0xFFFFFF;
						m_interface.gameScreen.score.scoreLabel.textColor = 0xFFFFFF;
					}});
					
					// these array functions do the following:
					// 1. cut the row from the Block array and the Sum array.
					// 2. push a new row to the top of the canvas.
					aryBlockRow.splice(ii, 1);
					aryBlockSum.splice(ii, 1);
					aryBlockRow.unshift(new Array());
					aryBlockSum.unshift(0);
					
					// since we spliced, we now have an empty row, so, starting from the top and going down to the row that was deleted,
					// push each block down.
					for (jj = 0; jj <= ii; jj++) { 
						for (var kk:int = 0; kk < aryBlockRow[jj].length; kk++) { 		
							if (aryBlockRow[jj][kk]) {
								aryBlockRow[jj][kk].yp += BLOCK_WIDTH;
								
							}
						}
					}		
					
				} // end "(aryBlockSum[ii] == 10)"
				
				// now go on to the next row, and see if it's filled.
			} // end for(ii = 0; ii < aryBlockSum.length; ii++)"
			
			
			// reset multiplier to 1 for the next time the private function is called.
			scoreMultiplier = 1;
			// transfer the next body (the one in preview) to the current body...
			body = nextBody;
			// and create the new nextBody.
			nextBody = new Body(PREVIEW_WIDTH, -BLOCK_WIDTH);
			
			// redraw the new nextBody into the preview pane.
			bPreviewBufferData.fillRect(new Rectangle(0, 0, bPreviewBufferData.width, bPreviewBufferData.height), 0x000000);
			for(ii = 0; ii < nextBody.block.length; ii++) {
				bPreviewBufferData.copyPixels(m_blockMap, new Rectangle(nextBody.block[ii].spriteoffset, 1, BLOCK_WIDTH, BLOCK_WIDTH), 
					new Point(nextBody.block[ii].xp - nextBody.GetCenter().x + 120, nextBody.block[ii].yp - nextBody.GetCenter().y + 60), null, null, true);
			}
		}
		
		public function key_pressed(evt:KeyboardEvent):void 
		{
			if(isRunning) 
			{
				switch(evt.keyCode) 
				{ 
					case Main.CODE_UP: //up
						body.Rotate();
						collisionCheckRotate();
						break;
					
					case Main.CODE_DOWN: //down
						moveDown = true;						
						break;
					
					case Main.CODE_LEFT: //left
						body.Move(-BLOCK_WIDTH, 0);						
						collisionCheckHorizontal();				
						break;
					
					case Main.CODE_RIGHT: //right
						body.Move(BLOCK_WIDTH, 0);						
						collisionCheckHorizontal();				
						break;		
				}
			}
		}
		
		public function key_released(evt:KeyboardEvent):void 
		{
			switch(evt.keyCode) 
			{				
				case Main.CODE_DOWN: //down
					moveDown = false;
					break;
			}			
		}
		
		private function onTimerTick(e : TimerEvent) : void
		{
			m_time--;
			var sec : String = m_time.toString();
			if (sec.length < 3 && sec.length >= 2)
				sec = "0" + sec;
			if (sec.length < 2)
				sec = "00" + sec;
			m_interface.gameScreen.timer.containerTime.temps.text = sec;
			
			if (m_time <= 10)
			{
				if (m_time == 10)
					Main.s_gameTimeoutSnd.play();
				m_interface.gameScreen.timer.containerTime.temps.textColor = 0xFF0010;
				m_interface.gameScreen.timer.timerLabel.textColor = 0xFF0010;
				m_interface.gameScreen.timer.containerTime.scaleX = 1.5;
				m_interface.gameScreen.timer.containerTime.scaleY = 1.5;
				TweenLite.to(m_interface.gameScreen.timer.containerTime, 1, { scaleX : 1, scaleY : 1 });
			}
			else
			{
				m_interface.gameScreen.timer.containerTime.temps.textColor = 0xFFFFFF;
				m_interface.gameScreen.timer.timerLabel.textColor = 0xFFFFFF;
			}
			
			if (m_time == 0)
			{
				Main.s_gameTimeoutSnd.stop();
				
				isRunning = false;
				gameOver = true;
				moveDown = false;
				
				m_interface.gameScreen.timer.containerTime.temps.textColor = 0xFFFFFF;
				m_interface.gameScreen.timer.timerLabel.textColor = 0xFFFFFF;
				
				m_interface.gameOverScreen.gameOver.g.y = -1500;
				m_interface.gameOverScreen.gameOver.a.y = -1500;
				m_interface.gameOverScreen.gameOver.m.y = -1500;
				m_interface.gameOverScreen.gameOver.e1.y = -1500;
				m_interface.gameOverScreen.gameOver.o.y = -1500;
				m_interface.gameOverScreen.gameOver.v.y = -1500;
				m_interface.gameOverScreen.gameOver.e2.y = -1500;
				m_interface.gameOverScreen.gameOver.r.y = -1500;
				
				m_parent.showGameOver();
				
				TweenLite.to(m_interface.gameOverScreen.gameOver.g, 1, { ease : Expo.easeIn, y : -20.85 });
				TweenLite.to(m_interface.gameOverScreen.gameOver.a, 1, { ease : Expo.easeIn, delay : 1.3, y : -8.55 });
				TweenLite.to(m_interface.gameOverScreen.gameOver.m, 1, {  ease : Expo.easeIn, delay : 0.2, y : -9.3 });
				TweenLite.to(m_interface.gameOverScreen.gameOver.e1, 1, {  ease : Expo.easeIn, delay : 1.5, y : -8.4 });
				
				TweenLite.to(m_interface.gameOverScreen.gameOver.o, 1, {  ease : Expo.easeIn, delay : 2, y : 123.15 });
				TweenLite.to(m_interface.gameOverScreen.gameOver.v, 1, {  ease : Expo.easeIn, delay : 0.1, y : 135.6 });
				TweenLite.to(m_interface.gameOverScreen.gameOver.e2, 1, {  ease : Expo.easeIn, delay : 1.15, y : 135.6 });
				TweenLite.to(m_interface.gameOverScreen.gameOver.r, 1, {  ease : Expo.easeIn, delay : 0.5, y : 134.9 });
			}
				
		}
	}
}