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
	
	import flash.display.Sprite;

	public class Block {
		
		public var xp:int = 0;
		public var yp:int = 0;
		public var xpPrev:int;
		public var ypPrev:int;
		public var type:int;
		public var spriteoffset:int;
		
		public var sprite:Sprite;
		
		public function Block(_xp:int, _yp:int, _spriteoffset:int):void {
			
			xp = _xp;
			yp = _yp;
			spriteoffset = _spriteoffset;
		}
		
		public function Move(_xp:int, _yp:int):void {
			
			xpPrev = xp;
			ypPrev = yp;
			xp += _xp;
			yp += _yp;
		}
		
		public function StoreState() : void 
		{
			xpPrev = xp;
			ypPrev = yp;		
		}
		
		public function Rewind() : void 
		{
			xp = xpPrev;
			yp = ypPrev;
		}

	}
}