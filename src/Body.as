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
package {
	
	import flash.geom.Point;
		
	public class Body {
		
		public var bodyType:int;
		public var bodyColor:Array = new Array();
		
		public var xp:int;
		public var yp:int;
		public var xpPrev:int;
		public var ypPrev:int;
		public var block:Array;
		
		private var BL:int = 0;
		private var BJ:int = 1;
		private var BB:int = 2;
		private var BZ:int = 3;
		private var BS:int = 4;
		private var BC:int = 5;
		private var BI:int = 6;
		
		private var patternsX:Array = new Array();
		private var patternsY:Array = new Array();
		
				
		public function Body(_xp:int = 150, _yp:int = 0) {
			
			var spriteoffset : Array = new Array();
			
			//shape definitions.
			patternsX[BL] = new Array(-1,-1, 0, 1);
			patternsY[BL] = new Array( 0, 1, 1, 1);
			//bodyColor[BL] = new 0x0000FF;
			spriteoffset[BL] = 0;
			
			patternsX[BJ] = new Array(-1,-1, 0, 1);
			patternsY[BJ] = new Array( 1, 0, 0, 0);
			//bodyColor[BJ] = new 0xFF00FF;
			spriteoffset[BJ] = Tetris.BLOCK_WIDTH;
			
			patternsX[BB] = new Array(-1,-1, 0, 0);
			patternsY[BB] = new Array( 0, 1, 0, 1);
			//bodyColor[BB] = new 0xFF0000;
			spriteoffset[BB] = 2 * Tetris.BLOCK_WIDTH;
			
			patternsX[BZ] = new Array(-1, 0, 0, 1);
			patternsY[BZ] = new Array( 1, 1, 0, 0);
			//bodyColor[BZ] = new 0x66CCCC;
			spriteoffset[BZ] = 3 * Tetris.BLOCK_WIDTH;
			
			patternsX[BS] = new Array(-1, 0, 0, 1);
			patternsY[BS] = new Array( 0, 0, 1, 1);
			//bodyColor[BS] = new 0x00FF00;
			spriteoffset[BS] = 4 * Tetris.BLOCK_WIDTH;
			
			patternsX[BC] = new Array(-1, 0, 0, 1);
			patternsY[BC] = new Array( 0, 0, 1, 0);
			//bodyColor[BC] = new 0xFFFF00;
			spriteoffset[BC] = 5 * Tetris.BLOCK_WIDTH;
			
			patternsX[BI] = new Array(-1, 0, 1, 2);
			patternsY[BI] = new Array( 0, 0, 0, 0);	
			//bodyColor[BI] = new 0xFF6600;
			spriteoffset[BI] = 6 * Tetris.BLOCK_WIDTH;
		
			xp = _xp;
			yp = _yp;
			
			//this is obviously a very simple randomization. For a high quality game, you might have logic to make sure
			//the same body doesn't occur more than 2 or 3 times in a row. I don't know what the "Official" standards
			//are on this.
			var type:int = Math.random() * 700;
			
			if(type <= 100) 	 bodyType = 0;
			else if(type <= 200) bodyType = 1;
			else if(type <= 300) bodyType = 2;
			else if(type <= 400) bodyType = 3;
			else if(type <= 500) bodyType = 4;
			else if(type <= 600) bodyType = 5;
			else if(type <= 700) bodyType = 6;
			
			block = new Array();
			
			//every body in tetris consists of 4 blocks, so indexes are hard coded in. The only reason you wouldn't want
			//to do this is if you wanted to do some funky random shapes with more or less than 4 blocks.
			block[0] = new Block(patternsX[bodyType][0] * Tetris.BLOCK_WIDTH, patternsY[bodyType][0] * Tetris.BLOCK_WIDTH, spriteoffset[bodyType]);
			block[1] = new Block(patternsX[bodyType][1] * Tetris.BLOCK_WIDTH, patternsY[bodyType][1] * Tetris.BLOCK_WIDTH, spriteoffset[bodyType]);
			block[2] = new Block(patternsX[bodyType][2] * Tetris.BLOCK_WIDTH, patternsY[bodyType][2] * Tetris.BLOCK_WIDTH, spriteoffset[bodyType]);
			block[3] = new Block(patternsX[bodyType][3] * Tetris.BLOCK_WIDTH, patternsY[bodyType][3] * Tetris.BLOCK_WIDTH, spriteoffset[bodyType]);
		}
		
		public function Move(_xp:int, _yp:int):void {
			
			//save the old values, in case the body needs to rewind.
			xpPrev = xp;
			ypPrev = yp;
			
			xp += _xp;
			yp += _yp;
			
		}
		
		public function Rewind():void {
			
			xp = xpPrev;
			yp = ypPrev;
		}
		
		
		public function CollisionCheck(_block:Block):Boolean {			
		
			//checks all of the body's blocks against the passed block, to detect collision.
			for(var ii:int = 0; ii < block.length; ii++) {
				if(xp + block[ii].xp == _block.xp && yp + block[ii].yp ==  _block.yp) {
					return true;
					
				}
			}		
			
			return false;
		}
		
		public function Rotate() : void
		{
			var tempX:int;
			var tempY:int;
			
			for (var ii:int = 0; ii < block.length; ii++) {
				
				//if the rotation causes a collision, StoreState gives us something to rewind to.
				block[ii].StoreState();
				
				tempX = block[ii].xp;
				tempY = block[ii].yp;
				
				block[ii].xp = -tempY;
				block[ii].yp = tempX;
			}
		}
		
		// A rotate causes each block to store it's own position, incase the rotation needs to be rewound.
		public function RewindRotate() : void
		{
			for (var ii:int = 0; ii < block.length; ii++) {
				block[ii].Rewind();
			}
		}
			
		//this function returns the true center of the body's bounding box. This is used soley to position the body correctly
		//in the preview pane.
		public function GetCenter():Point {
			
				var xMax:Number = 0;
				var yMax:Number = 0;
				var xMin:Number = 0;
				var yMin:Number = 0;
				
				for(var ii:int = 0; ii < block.length; ii++) {
					xMax = Math.max(block[ii].xp, xMax);
					yMax = Math.max(block[ii].yp, yMax);
					xMin = Math.min(block[ii].xp, xMin);
					yMin = Math.min(block[ii].yp, yMin);
				}

				return new Point((xMax + xMin) / 2, (yMax + yMin) / 2);
		}
	}
}

