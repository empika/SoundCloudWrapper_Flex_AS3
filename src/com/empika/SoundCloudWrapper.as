package com.empika
{
	// flash and flex imports
	
	import flash.data.*;
	import flash.display.Sprite;
	import flash.errors.*;
	import flash.events.*;
	import flash.filesystem.File;
	import flash.net.*;
	
	import org.iotashan.oauth.*;
	import org.iotashan.utils.*;
	
	public class SoundCloudWrapper extends Sprite
	{
		
		// public variables
		// ----------------
		// consumer key and secret
		private var consumerKey: String;
		private var consumerSecret: String;
		
		// private variables
		// -----------------
		
		// Soundcloud specific variables
		// These are the end points used to get data from SC
		private var soundCloudLiveURL:String		= "http://api.soundcloud.com/";
		private var soundCloudSandboxURL:String	= "http://api.sandbox-soundcloud.com/";
		private var soundCloudURL:String;
		private var requestTokenURL:String		= "oauth/request_token";
		private var userAuthorizationURL:String = "oauth/authorize";
		private var accessTokenURL:String		= "oauth/access_token";
		private var usingSandbox:Boolean		= false;
		
		// Some OAuth bits
		private var tokenSecret:String;
		private var oauth_timestamp:String;
		private var oauth_nonce:String;
		private var oauth_signature:String;
		private var signatureMethod:String	= "HMAC-SHA1";
		
		private var oaConsumerToken: OAuthConsumer = new OAuthConsumer( consumerKey, consumerSecret );
		private var oaAuthToken: OAuthToken = new OAuthToken();
		private var oaAccessToken: OAuthToken = new OAuthToken();
		private var oaSignatureMethod: OAuthSignatureMethod_HMAC_SHA1 = new OAuthSignatureMethod_HMAC_SHA1();
		private var strResult: String = "header";
		private var strHeader: String = "";
		
		private var hasAccess: Boolean = false;
		
		// Some misc bits
		private var conn: SQLConnection = new SQLConnection;
		private var sqlStatement:SQLStatement = new SQLStatement();
		private var sqliteFile: File = File.applicationStorageDirectory.resolvePath( "soundcloud_access.db" );
		
		public function SoundCloudWrapper( consumerKey: String = "", consumerSecret: String = "", useSandbox: Boolean = false )
		{
			this.oaConsumerToken.key = consumerKey;
			this.oaConsumerToken.secret = consumerSecret;
			
			if( !useSandbox ){
				soundCloudURL = soundCloudLiveURL;
			}
			else{
				soundCloudURL = soundCloudSandboxURL;
			}
			this.usingSandbox = useSandbox;
			// localsave is on! lets try and create our SQLite DB
			//conn.addEventListener(SQLEvent.OPEN, connOpenHandler);
			sqlStatement.sqlConnection = conn;
			try{
				trace ( sqliteFile.nativePath );
				conn.open( sqliteFile );
				trace( "opened SQLite database" );
			}
			catch( error: SQLError ){
				trace( "error opening SQLite database" );
				trace( "error: " + error.message );
				trace( "details: " + error.details );
				return;
			}
			
			// lets see if we have our access token
			// have a look at this.has_access to see if we have it or not
			this.checkAccessToken();
			
		}
		
		/*
		 * Send request to get our AUTH token
		 */
		private function requestAuthToken():void {
			// set up our auth request
			var oaAuthRequest: OAuthRequest = new OAuthRequest( "get",
															this.soundCloudURL + this.requestTokenURL,
															null,
															this.oaConsumerToken,
															this.oaAuthToken );
			// generate our url
			var strRequsetURL:String = oaAuthRequest.buildRequest( this.oaSignatureMethod, "url", this.strHeader );
			trace( "strRequsetURL: " + strRequsetURL );

			// create our url request
			var authURLRequest: URLRequest = new URLRequest( strRequsetURL );
			authURLRequest.method = URLRequestMethod.GET;
			// create our url loader
			var authURLLoader: URLLoader = new URLLoader();
			// set up our event listeners for the url loader
			authURLLoader.addEventListener( HTTPStatusEvent.HTTP_RESPONSE_STATUS, trcHTTP );
			authURLLoader.addEventListener( Event.COMPLETE, this.authorizeUser );
			authURLLoader.dataFormat = URLLoaderDataFormat.VARIABLES;
			// try to load our request
			try{
				authURLLoader.load( authURLRequest );
			}
			catch( error:Error ){
				trace("requestAuthToken() : Unable to load requested document.");
			}
		}
		
		/*
		 * We get our AUTH token and then send the use to Soundcloud to authenticate
		 */
		private function authorizeUser( event: Event ):void {
			trace( "authorizeUser() : Got the AUTH token" );
			var recievedData:URLLoader = event.target as URLLoader;
			this.oaAuthToken.key = recievedData.data['oauth_token'];
			this.oaAuthToken.secret = recievedData.data['oauth_token_secret'];
			trace( "authorizeUser() : oaAuthToken.key : " + this.oaAuthToken.key );
			trace( "authorizeUser() : oaAuthToken.secret : " + this.oaAuthToken.secret );
			var strUserAuthorizationURL: String = this.soundCloudURL + this.userAuthorizationURL + "?oauth_token=" + oaAuthToken.key
			var userAuthReq: URLRequest = new URLRequest( strUserAuthorizationURL );
			navigateToURL( userAuthReq );
		}
		
		/*
		 * Check to see if we have an access token.
		 * Called during the instantiation of the class
		 */
		private function checkAccessToken():void {
			trace("requestAccessToken() : retrieving local access token");
			// lets try and get our access token if it is already saved
			sqlStatement.addEventListener(SQLEvent.RESULT, checkAccessTokenResult);
			sqlStatement.text = "SELECT * FROM access_tokens WHERE using_sandbox = " + this.usingSandbox;

			try{
				sqlStatement.execute();
			}
			catch( error: SQLError )
			{
				trace( "requestAccessToken() : error executing : " + sqlStatement.text );
				trace( "error: " + error.message );
				trace( "details: " + error.details );
				return;
			}
		}
		
		/*
		 * handler for our SQLite statement in checkAccessToken
		 */
		private function checkAccessTokenResult( event:SQLEvent ):void{
			this.sqlStatement.removeEventListener(SQLEvent.RESULT, this.requestAccessToken);
			
			// get our result
			var sqlResult:SQLResult = this.sqlStatement.getResult();
			if (sqlResult.data == null){
				this.hasAccess = false;
			}
			else{
				this.oaAccessToken.key = sqlResult.data[0].accessKey;
				this.oaAccessToken.secret = sqlResult.data[0].accessSecret;
				
				trace( "requestAccessToken() : w00t, got our token from 'access_tokens'" );
				trace( "requestAccessToken() : oaAccessToken.key : " + this.oaAccessToken.key);
				trace( "requestAccessToken() : oaAccessToken.secret : " + this.oaAccessToken.secret);
				
				this.hasAccess = true;
				
			}
		}
		
		/*
		 * if you dont have an access token already, run this to get one
		 */
		private function requestAccessToken( ):void{
			
			trace("requestAccessToken() : requesting access token");
			var oaAccessRequest: OAuthRequest = new OAuthRequest( "get",
															this.soundCloudURL + this.accessTokenURL,
															null,
															this.oaConsumerToken,
															this.oaAuthToken );
			var strRequestURL:String = oaAccessRequest.buildRequest(this.oaSignatureMethod, "post", this.strHeader);
			var accessURLRequest: URLRequest = new URLRequest(this.soundCloudURL + this.accessTokenURL + "?" + strRequestURL );
			trace( "requestAccessToken() : strRequestURL : " + strRequestURL );
			accessURLRequest.method = URLRequestMethod.GET;
			var accessURLLoader: URLLoader = new URLLoader( accessURLRequest );
			accessURLLoader.dataFormat = URLLoaderDataFormat.VARIABLES;
			
			accessURLLoader.addEventListener(Event.COMPLETE, requestAccessTokenComplete);
			accessURLLoader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, trcHTTP);
			try{
				accessURLLoader.load( accessURLRequest);
			}
			catch( error:Error ){
				trace("requestAccessToken() : Unable to load requested document.");
			}
				
		}
		
		private function requestAccessTokenComplete( event: Event ):void{
			// get our tokens from our returned data
			var urlLoadData:URLLoader = event.target as URLLoader;
			this.oaAccessToken.key = urlLoadData.data['oauth_token'];
			this.oaAccessToken.secret = urlLoadData.data['oauth_token_secret'];
			this.sqlStatement.text =
				"CREATE TABLE IF NOT EXISTS access_tokens (" +
				"	accessId INTEGER PRIMARY KEY AUTOINCREMENT, " +
				"	accessKey TEXT, " +
				"	accessSecret TEXT, " +
				"   using_sandbox BOOL " +
				" ) ";
			try{
				this.sqlStatement.execute();
				trace( "requestAccessTokenComplete() : created SQLite table 'access_tokens'" );
			}
			catch( error: SQLError )
			{
				trace( "requestAccessTokenComplete() : error creating table" );
				trace( "error: " + error.message );
				trace( "details: " + error.details );
				return;
			}
			
			this.sqlStatement.text = "DELETE FROM access_tokens WHERE using_sandbox = " + this.usingSandbox;
			try{
				this.sqlStatement.execute();
				trace( "requestAccessTokenComplete() : deleted existing access token" );
			}
			catch( error: SQLError )
			{
				trace( "error deleting data" );
				trace( "error: " + error.message );
				trace( "details: " + error.details );
				return;
			}
			
			this.sqlStatement.text = "INSERT INTO access_tokens (accessKey, accessSecret, using_sandbox)" +
				"	VALUES ( '" + this.oaAccessToken.key + "', '" + this.oaAccessToken.secret + "'," + this.usingSandbox + ") ";
			try{
				this.sqlStatement.execute();
				trace( "requestAccessTokenComplete() : inserted access_token" );
			}
			catch( error: SQLError )
			{
				trace( "requestAccessTokenComplete() : error inserting access_token" );
				trace( "error: " + error.message );
				trace( "details: " + error.details );
				return;
			}
		}
		
		/*
		 * Helper function to check our access token exists
		 * returns:
		 *		true - if we do have an access token
		 *		false - if we dont have an access token
		 */
		public function has_access():Boolean{
			return this.hasAccess;
		}
		
		public function getResource( strResource: String = "", type: String = "xml" ):void{
			if( !this.oaAccessToken.isEmpty && strResource != "" ){
				trace("getResource() : " + strResource);
				if( type == "xml" || type == "json" ){
					var strRes:String;
					var strPattern: RegExp = /\//;
					strRes = this.soundCloudURL + strResource.replace(strPattern, "") + "." + type;
					
					var resourceRequest: OAuthRequest = new OAuthRequest( "get",
																	strRes,
																	null,
																	this.oaConsumerToken,
																	this.oaAccessToken );
					var resourceURL:String = resourceRequest.buildRequest(this.oaSignatureMethod, "url", this.strHeader);
					trace( resourceURL );
					var resourceURLRequest: URLRequest = new URLRequest( resourceURL );
					var resourceURLLoader: URLLoader = new URLLoader( resourceURLRequest );
					resourceURLLoader.addEventListener(Event.COMPLETE, gotResource);
					resourceURLLoader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, trcHTTP);
					resourceURLLoader.load( resourceURLRequest );
				}
				else{
					var scwEvent: SoundCloudWrapperDataEvent = new SoundCloudWrapperDataEvent(SoundCloudWrapperDataEvent.ERROR);
					scwEvent.error = "*ERROR* - SoundCloudWrapper.getResource() : Type was not 'xml' or 'json'";
					dispatchEvent(scwEvent);		
				}
			}
		}
		
		private function gotResource( event: Event):void{
			trace("gotResource() : got given resource");
			var theLoader: URLLoader = event.currentTarget as URLLoader;
			var scwEvent: SoundCloudWrapperDataEvent = new SoundCloudWrapperDataEvent(SoundCloudWrapperDataEvent.LOADED);
			scwEvent.data = theLoader.data;
			dispatchEvent(scwEvent);
		}
		
		public function postResource( strResource: String = "", strGetData: String = "", fileReference: FileReference = null):void{
			trace("got some auth");
				var strRes:String;
				strRes = this.soundCloudURL + strResource;

				var theRequest: OAuthRequest = new OAuthRequest( "post",
																strRes,
																null,
																this.oaConsumerToken,
																this.oaAccessToken );
				var resourceURL: String = theRequest.buildRequest(this.oaSignatureMethod, "url", this.strHeader);
				//var urlVars: URLVariables = new URLVariables( );
				//var header: URLRequestHeader = new URLRequestHeader();
				
				var resourceURLRequest: URLRequest = new URLRequest( resourceURL );
				
				/*
			    *  track[title], string, the title of the track
			    * track[asset_data], file, the original asset file
			    * track[description], string, a description
			    * track[downloadable], true|false
			    * track[sharing], public|private
			    * track[bpm], float, beats per minute

			    */
				var params:URLVariables = new URLVariables();
				var paramArray:Array = new Array();
				resourceURLRequest.method = URLRequestMethod.POST;							
				// convert our string of params to AS3 happy params
				params.decode( strGetData );
				resourceURLRequest.data = params;
				// gwaarn, send that track and data!
				if( fileReference ){
					//fileReference.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, trcHTTPUpload );
					fileReference.addEventListener(ProgressEvent.PROGRESS, progressHandler);
					fileReference.addEventListener(DataEvent.UPLOAD_COMPLETE_DATA, postedResource);
					//fileReference.addEventListener(Event.COMPLETE, eventComplete);
					fileReference.upload( resourceURLRequest, "track[asset_data]" );
				}
				else{
					var resourceURLLoader: URLLoader = new URLLoader( resourceURLRequest );
					resourceURLLoader.addEventListener(Event.COMPLETE, postedResource);
					resourceURLLoader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, trcHTTP);
					resourceURLLoader.load( resourceURLRequest );
				}
			
		}
		
		private function postedResource( event: DataEvent):void{
			trace("postedResource() : posted given resource");
			//var theLoader: URLLoader = event.currentTarget as URLLoader;
			var scwEvent: SoundCloudWrapperDataEvent = new SoundCloudWrapperDataEvent(SoundCloudWrapperDataEvent.LOADED);
			scwEvent.data = event.data;
			dispatchEvent(scwEvent);
		}
		
		private function eventComplete( event: DataEvent):void{
			trace("hallo");	
		
		}
		
		public function progressHandler( event:ProgressEvent ):void
		{
			// bloop bloop bloop BLOOP!
			trace( event.bytesLoaded + " / " + event.bytesTotal );
		}
			
		
		/*
		 * Wrapper function to kick off the authentication process 
		 * using the functions in this class
		 */
		public function authenticate():void{
			this.requestAuthToken();
		}
		
		public function getAccess():void{
			this.requestAccessToken();
		}
		
		public function getMe():void{
			this.getResource();
		}
		
		
		/*
		 * Helper function to trace out some data about our HTTP upload
		 */
		public function trcHTTPUpload( event:HTTPStatusEvent ):void
		{
			//trace( event.responseHeaders );
			for each( var ar: URLRequestHeader in event.responseHeaders )
			{
				trace( ar.name + " : " + ar.value );
				if( ar.name == "Location" )
				{
					var arrayT: Array = ar.value.split( /.*\// );
					trace( arrayT[1] );
					//postTrackAsset( arrayT[1] );
				}
			}
		}
		
		/*
		 * Helper function to trace out some data about our HTTP request
		 */	
		public function trcHTTP( event:HTTPStatusEvent ):void
		{
			//trace( event.responseHeaders );
			for each( var ar: URLRequestHeader in event.responseHeaders ){
				trace( ar.name + " : " + ar.value );
			}
		}
		

	}
}