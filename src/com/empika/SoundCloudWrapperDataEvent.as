package com.empika
{
// import normal
	import flash.events.Event;
	
	public class SoundCloudWrapperDataEvent extends Event 
	{
		public static const LOADED:String 		= 'loaded';
		public static const ERROR:String 		= 'error';
		public static const ERROR_XML:String 	= 'errorXml';
		public static const ERROR_JSON:String 	= 'errorXml';
		
		private var _json:Object;
		private var _error:String;
		private var _data:String;
		
		// constructor
		public function SoundCloudWrapperDataEvent($type:String, $bubbles:Boolean = false, $cancelable:Boolean = false):void 
		{
			super($type, $bubbles, $cancelable);
		}
		
		public function get json():Object
		{
			return _json;
		}
		
		public function set json( json:Object):void 
		{
			_json = json;
		}

		public function get data():String
		{
			return _data;
		}
		
		public function set data( data:String):void 
		{
			_data = data;
		}
		
		public function get error():String
		{
			return _error;
		}
		
		public function set error( error:String):void
		{
			_error = error;
		}
		
	}
}