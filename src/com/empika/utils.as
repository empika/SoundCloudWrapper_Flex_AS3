// ActionScript file
package com.empika
{
	public class utils
	{
		public function utils()
		{
			//trace("created");
		}
		public function genNonce(length:int):String {
		        var chars:String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXTZabcdefghiklmnopqrstuvwxyz";
		        var result:String = "";
		        var i:int;
		        for ( i = 0; i < length; i++ ) {
		            var rnum:Number = Math.floor(Math.random() * chars.length);
		            result += chars.substring(rnum, rnum+1);
		        }
		        return result;
		}
	}
}
//OAuth.nonce.CHARS = 