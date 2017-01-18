//SocketController.js
'use strict';
define (['emitter'],

function(EventEmitter){
	var keepAlive = true;
	var SocketController = class{

		constructor(){
	    window.WebSocket = window.WebSocket || window.MozWebSocket;
  		this.HOST = 'ws://pure-beach-75578.herokuapp.com/';
  		this.connection = null;
  		this.emitter = new EventEmitter();
  		}
		

		connect(){
		var self = this;
      	this.connection = new WebSocket(this.HOST, "authoring");

      	this.connection.onopen = function() {
            console.log('connection opened');
            self.emitter.trigger("ON_CONNECTION");

            self.connection.send(JSON.stringify({
                name: 'authoring'
            }));
            if(keepAlive){
            	self.pingInterval = setInterval(function() {self.pingServer(self);}, 5000);
            }

        };

        this.connection.onerror = function(error) {
            console.log('connection error', error);

            // an error occurred when sending/receiving data
        };

        this.connection.onmessage = function(message) {
            // try to decode json (I assume that each message from server is json)
           // try {
            	
            	  console.log(message);

            	  if(message.data == "message received"){
            	  	 self.emitter.trigger("ON_MESSAGE_RECEIVED");

            	  	return;
            	  }
            	  else{
                	var data = JSON.parse(message.data);

                	console.log("data.type", data.type);

                	self.emitter.trigger("ON_MESSAGE",[data]);
                	return;
          	}
           // } catch (error) {
               // console.log("error:", error,message.data);
            //}
        };

        this.connection.onclose = function(){
        	console.log("disconnected");
        	    self.emitter.trigger("ON_DISCONNECT");
        	   clearInterval(self.pingInterval);
        };

	}

	addListener(name,listener){
		this.emitter.addListener(name,listener);
	}

	sendMessage(message){
		if(this.connection !== null){
			this.connection.send(JSON.stringify(message));
		}
	}


  	pingServer(self){
		var data = {type:"ping"};
         self.sendMessage(data);
	}

    };

    return SocketController;

});
