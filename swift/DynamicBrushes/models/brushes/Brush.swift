//
//  Brush.swift
//  Palette-Knife
//
//  Created by JENNIFER MARY JACOBS on 5/5/16.
//  Copyright © 2016 pixelmaid. All rights reserved.
//
import Foundation
import SwiftyJSON

struct DeltaStorage{
    var dX = Float(0)
    var dY = Float(0)
       //var pX = Float(0)
    //var pY = Float(0)
    //var oX = Float(0)
    //var oY = Float(0)
    var r = Float(0)
    var sX = Float(0)
    var sY = Float(0)
    var rX = Float(0)
    var rY = Float(0)
    var d = Float(0)
    var h = Float(0)
    var s = Float(0)
    var l = Float(0)
    var a = Float(0)
    var dist = Float(0);
    var xDist = Float(0);
    var yDist = Float(0);
    var pX = Float(0);
    var pY = Float(0);
    var time = Float(0);
    var i = Float(0);
    var sC = Float(0);
    var lV = Float(0);
}

class Brush: TimeSeries, Hashable{
    
    //hierarcical data
    var children = [Brush]();
    var parent: Brush!
    
    //dictionary to store expressions for emitter->action handlers
    var states = [String:State]();
    var transitions = [String:StateTransition]();
    var currentState:String
    
    //geometric/stylistic properties
    let bPosition:Point //actual position
    
    let position:LinkedPoint //settable positon
    let x:Observable<Float>
    let y:Observable<Float>
    
    let polarPosition:LinkedPoint //settable position for polar coordinates
    let theta:Observable<Float>
    let radius:Observable<Float>

    let delta:LinkedPoint
    let dx:Observable<Float>
    let dy:Observable<Float>
    
    let origin:Point;
    let ox:Observable<Float>
    let oy:Observable<Float>
    
    let scaling:Point;
    let sx:Observable<Float>
    let sy:Observable<Float>
    
    let reflectY:Observable<Float>
    let reflectX:Observable<Float>
    let rotation:Observable<Float>
    
    let distance:Observable<Float>
    let xDistance:Observable<Float>
    let yDistance:Observable<Float>
    
    
    var time:Observable<Float>
    let intersections:Observable<Float>
    let index:Observable<Float>
    let level:Observable<Float>

    let siblingcount:Observable<Float>
    
    let diameter:Observable<Float>
    let alpha:Observable<Float>
    let hue:Observable<Float>
    let lightness:Observable<Float>
    let saturation:Observable<Float>
    
  /*  let xBuffer:CircularBuffer
    let yBuffer:CircularBuffer
    let weightBuffer:CircularBuffer
    let bufferLimitX:Observable<Float>
    let bufferLimitY:Observable<Float>*/
    
    //list of obeservables (for later disposal)
    
    var currentCanvas:Canvas?
    var currentStroke:Stroke?
    
    //Events
    var geometryModified = Event<(Geometry,String,String)>()
    var dieEvent = Event<(String)>()
    var signalEvent = Event<(String,String,DeltaStorage)>()
    //Events
    
    
   
    var behavior_id:String?
    var behaviorDef:BehaviorDefinition?
    var matrix = Matrix();
    var deltaKey = NSUUID().uuidString;
    
    var drawKey = NSUUID().uuidString;
    var bufferKey = NSUUID().uuidString;
    let childDieHandlerKey = NSUUID().uuidString;
    var deltaChangeBuffer = [DeltaStorage]();
    var undergoing_transition = false;
    var transitionEvents = [Disposable]();
    var transitionDelayTimer: Timer!;
    init(name:String, behaviorDef:BehaviorDefinition?, parent:Brush?, canvas:Canvas){
        
        //==BEGIN OBSERVABLES==//
        self.bPosition = Point(x:0,y:0)
        self.position = LinkedPoint(x:0,y:0)
        self.x = self.position.x;
        self.y = self.position.y;
        self.x.printname = "brush_position_x"
        self.y.printname = "brush_position_y"

        self.position.name = "brush_position";
        
        self.polarPosition = LinkedPoint(x:0,y:0)
        self.radius = self.polarPosition.x;
        self.theta = self.polarPosition.y;
        self.radius.printname = "brush_radius"
        self.theta.printname = "brush_theta"
        
        self.polarPosition.name = "brush_polarPosition";
        
        self.delta = LinkedPoint(x:0,y:0)
        self.dx = delta.x;
        self.dy = delta.y
        self.dx.printname = "brush_delta_x"
        self.dy.printname = "brush_delta_y"

        self.origin = Point(x:0,y:0)
        self.ox = origin.x;
        self.oy = origin.y;
        
        self.scaling = Point(x:100,y:100)
        self.sx = scaling.x;
        self.sy = scaling.y;
        
        self.reflectY = Observable<Float>(0)
        self.reflectX = Observable<Float>(0)
        self.rotation = Observable<Float>(0)
        
        self.distance = Observable<Float>(0)
        self.xDistance = Observable<Float>(0)
        self.yDistance = Observable<Float>(0)
        
        self.index = Observable<Float>(0)
        self.level = Observable<Float>(0)
        self.siblingcount = Observable<Float>(0)
        self.intersections = Observable<Float>(0)
        self.time = Observable<Float>(0)
        
        self.diameter = Observable<Float>(1)
        self.diameter.printname = "brush_diameter"
        self.alpha = Observable<Float>(100)
        self.hue = Observable<Float>(100)
        self.lightness = Observable<Float>(100)
        self.saturation = Observable<Float>(100)
        
        /*self.xBuffer = CircularBuffer(id:id+"_xBuffer")
        self.yBuffer = CircularBuffer(id:id+"_yBuffer")
        self.weightBuffer = CircularBuffer(id:id+"_weightBuffer")
 
       self.bufferLimitX = Observable<Float>(0)
        self.bufferLimitY = Observable<Float>(0)*/
        //==END OBSERVABLES==//
        
        
        self.currentState = "start";
        
        super.init()
        
        //TODO: this code is annoying because KVC assigment issues. Find a fix?
        self.time = _time
        
        self.kvcDictionary["x"] = self.x;
        self.kvcDictionary["y"] = self.y;
        self.kvcDictionary["theta"] = self.theta;
        self.kvcDictionary["radius"] = self.radius;
        self.kvcDictionary["dx"] = self.dx;
        self.kvcDictionary["dy"] = self.dy;
        self.kvcDictionary["ox"] = self.ox;
        self.kvcDictionary["oy"] = self.oy;
        self.kvcDictionary["sx"] = self.sx;
        self.kvcDictionary["sy"] = self.sy;
        self.kvcDictionary["reflectX"] = self.reflectX;
        self.kvcDictionary["reflectY"] = self.reflectY;
        self.kvcDictionary["rotation"] = self.rotation;
        self.kvcDictionary["distance"] = self.distance;
        self.kvcDictionary["xDistance"] = self.xDistance;
        self.kvcDictionary["yDistance"] = self.yDistance;
        self.kvcDictionary["time"] = self.time;
        self.kvcDictionary["intersections"] = self.intersections;
        self.kvcDictionary["index"] = self.index;
        self.kvcDictionary["level"] = self.level;
        self.kvcDictionary["siblingcount"] = self.siblingcount;
        self.kvcDictionary["diameter"] = self.diameter;
        self.kvcDictionary["alpha"] = self.alpha;
        self.kvcDictionary["hue"] = self.hue;
        self.kvcDictionary["lightness"] = self.lightness;
        self.kvcDictionary["saturation"] = self.saturation;
        
        
        //==BEGIN APPEND OBSERVABLES==//
        observables.append(bPosition)
        observables.append(delta)
        observables.append(position)
        observables.append(polarPosition)

        observables.append(origin)
        observables.append(scaling)
        
        observables.append(reflectY);
        observables.append(reflectX);
        observables.append(rotation);
        
        observables.append(distance)
        observables.append(xDistance)
        observables.append(yDistance)
        
        observables.append(index)
        observables.append(siblingcount)
        observables.append(level)

        
        observables.append(diameter)
        observables.append(alpha)
        observables.append(hue)
        observables.append(lightness)
        observables.append(saturation)
        
       /* observables.append(xBuffer);
        observables.append(yBuffer);
        observables.append(weightBuffer);
        
        observables.append(bufferLimitX)
        observables.append(bufferLimitY)*/
        //==END APPØEND OBSERVABLES==//
        
        
        self.behavior_id = behaviorDef!.id;
        self.behaviorDef = behaviorDef;
        
        
        self.name = name;
        
     
        
        
        //setup listener for delta observable
        _ = self.delta.didChange.addHandler(target: self, handler:Brush.deltaChange, key:deltaKey)
        _ = self.position.didChange.addHandler(target: self, handler:Brush.positionChange, key:deltaKey)
        _ = self.polarPosition.didChange.addHandler(target: self, handler:Brush.polarPositionChange, key:deltaKey)

       // _ = self.xBuffer.bufferEvent.addHandler(target: self, handler: Brush.deltaBufferLimitReached, key: bufferKey)
        
        
        self.setCanvasTarget(canvas: canvas)
        self.parent = parent
        
        //setup behavior
        if(behaviorDef != nil){
            behaviorDef?.addBrush(targetBrush: self)
        }
        self.delta.name = "delta_"+self.id;
    }
    
    
    func storeInitialValues(){
        let sendDs = DeltaStorage(dX:0,dY:0,r:0,sX:self.sx.getSilent(),sY:self.sy.getSilent(),rX:0,rY:0,d:1,h:100,s:100,l:100,a:100,dist:0,xDist:self.xDistance.getSilent(),yDist:self.yDistance.getSilent(),pX:0,pY:0,time:0,i:self.index.getSilent(),sC:self.siblingcount.getSilent(),lV:self.level.getSilent());
        
        self.signalEvent.raise(data: (self.behavior_id!,self.id,sendDs));
    }
 
    func setupTransition(){
        
        let setupTransition = self.getTransitionByName(name: "setup");
        if(setupTransition != nil && (setupTransition?.condition.evaluate())!){
            
            self.transitionToState(transition: setupTransition!)
        }
        else{
            #if DEBUG
                print("setup transition does not exist for \(self.id)");
            #endif
        }
    }
    
    //MARK: - Hashable
    var hashValue : Int {
        get {
            return "\(self.id)".hashValue
        }
    }
    
    //Event handlers
    //chains communication between brushes and view controller
    func brushDrawHandler(data:(Geometry,String,String),key:String){
        self.geometryModified.raise(data: data)
    }
    
    func createState(id:String,name:String){
        states[id] = State(id:id,name:name);
    }
    
    
    func deltaBufferLimitReached(data:(String), key:String){
       // bufferLimitX.set(newValue: 1)
    }
    
    func positionChange(data:(String,(Float,Float),(Float,Float)),key:String){
        #if DEBUG
           // print("position change called",self.index.get(id:nil),self.position.get(id: nil));
        #endif
        if(!self.undergoing_transition){
            let _delta = self.position.sub(point: self.bPosition)
            //let polarPos = MathUtil.cartToPolar(p1: self.bPosition, p2: self.position);
           // self.polarPosition.setSilent(newValue: (polarPos));
            self.calculateProperties(_delta:_delta)
        
        }
    }
    
    func polarPositionChange(data:(String,(Float,Float),(Float,Float)),key:String){
        
          #if DEBUG
            //print("polar change called");
        #endif
        if(!self.undergoing_transition){
            let t =  MathUtil.map(value: self.polarPosition.y.get(id: nil),low1: 0,high1: 100,low2: 0,high2: 360);
            let cartPos = MathUtil.polarToCart(r: self.polarPosition.x.get(id: nil),theta:t);
            let p = Point(x:cartPos.0+self.origin.x.get(id: nil),y:cartPos.1+self.origin.y.get(id: nil));
            let _delta = p.sub(point: self.bPosition)
            
            //print("polar change theta:",t,"rad:",self.polarPosition.x.get(id: nil),"cart point:",p.x.get(id:nil),p.y.get(id:nil),"delta",_delta.x.get(id:nil),_delta.y.get(id:nil))

            self.calculateProperties(_delta:_delta)
            
        }
        
        
    }

    
    
    func deltaChange(data:(String,(Float,Float),(Float,Float)),key:String){
        
        
            self.calculateProperties(_delta: self.delta)
        
        
    }
    
    func calculateProperties(_delta:Point){
        
        let dX = _delta.x.get(id:nil);
        let dY = _delta.y.get(id:nil);
        
        
        let r =  MathUtil.map(value: self.rotation.get(id:nil), low1: 0.0, high1: 100.0, low2: 0.0, high2: 360.0)
        
        let sX = self.scaling.x.get(id:nil)
        let sY = self.scaling.y.get(id:nil)
        
        let rX = self.reflectX.get(id:nil)
        let rY = self.reflectY.get(id:nil)
        
        let mapped_diameter = pow(1.03,self.diameter.get(id:nil))*0.54
        let d = mapped_diameter
        
        
        let h =   MathUtil.map(value: self.hue.get(id:nil), low1: 0.0, high1: 100.0, low2: 0.0, high2: 1.0)
        
        let s = MathUtil.map(value: self.saturation.get(id:nil), low1: 0.0, high1: 100.0, low2: 0.0, high2: 1.0)
        
        let l = MathUtil.map(value: self.lightness.get(id:nil), low1: 0.0, high1: 100.0, low2: 0.0, high2: 1.0)
        let mapped_alpha = pow(1.054,self.alpha.get(id:nil))*0.54
        let a = MathUtil.map(value: mapped_alpha, low1: 0.0, high1: 100.0, low2: 0.0, high2: 1.0)
        
        let dist = self.distance.get(id:nil);
        let xDist = self.xDistance.get(id:nil);
        let yDist = self.yDistance.get(id:nil);
        
        let ds = DeltaStorage(dX:dX,dY:dY,r:r,sX:sX,sY:sY,rX:rX,rY:rY,d:d,h:h,s:s,l:l,a:a,dist:dist,xDist:xDist,yDist:yDist,pX:0,pY:0,time:self.time.getSilent(),i:self.index.getSilent(),sC:self.siblingcount.getSilent(),lV:self.level.getSilent());
        self.deltaChangeBuffer.append(ds);
        self.processDeltaBuffer();
    }

    
    func processDeltaBuffer(){
        var ds:DeltaStorage! = nil
        
        if deltaChangeBuffer.count>0 {
            ds = deltaChangeBuffer.remove(at: 0)
        }
        if(ds != nil){
        let centerX = self.origin.x.get(id:nil)
        let centerY =  self.origin.y.get(id:nil)
        
        self.matrix.reset();
        if(self.parent != nil){
            self.matrix.prepend(mx: self.parent!.matrix)
        }
        var xScale = ds.sX
        
        if(ds.rX == 1){
            
            xScale *= -1.0;
        }
        var yScale = ds.sY
        if(ds.rY == 1){
            yScale *= -1.0;
        }
        let r = ds.r
        self.matrix.scale(x: xScale/100, y: yScale/100, centerX: centerX, centerY: centerY);
        self.matrix.rotate(_angle: r, centerX: centerX, centerY: centerY)
        
        let xDelt = ds.dX
        let yDelt = ds.dY
        
        let _dx = self.bPosition.x.get(id:nil) + xDelt;
        let _dy = self.bPosition.y.get(id:nil) + yDelt;
        let transformedCoords = self.matrix.transformPoint(x: _dx, y: _dy)
        
        self.distance.set(newValue: ds.dist + sqrt(pow(xDelt,2)+pow(yDelt,2)));
        self.xDistance.set(newValue: ds.xDist + abs(xDelt));
        self.yDistance.set(newValue: ds.yDist + abs(yDelt));
        
        // xBuffer.push(v: xDelt);
        // yBuffer.push(v: yDelt);
        
        //bufferLimitX.set(newValue: 0)
       // bufferLimitY.set(newValue: 0)
        
        let cweight = ds.d;
          
        //weightBuffer.push(v: cweight);
        
        let color = Color(h: ds.h, s: ds.s, l: ds.l, a: 1)
        
        self.currentCanvas!.addSegmentToStroke(parentID: self.id, point:Point(x:transformedCoords.0,y:transformedCoords.1),weight:cweight , color: color,alpha:ds.a)
        
        self.bPosition.x.setSilent(newValue: _dx)
        self.bPosition.y.setSilent(newValue:_dy)
    
       // self.distanceIntervalCheck();
        //self.intersectionCheck();
       let sendDs = DeltaStorage(dX:ds.dX,dY:ds.dY,r:ds.r,sX:ds.sX,sY:ds.sY,rX:ds.rX,rY:ds.rY,d:ds.d,h:ds.h,s:ds.s,l:ds.l,a:ds.a,dist:self.distance.getSilent(),xDist:self.xDistance.getSilent(),yDist:self.yDistance.getSilent(),pX:transformedCoords.0,pY:transformedCoords.1,time:ds.time,i:ds.i,sC:ds.sC,lV:ds.lV);
       self.signalEvent.raise(data: (self.behavior_id!,self.id,sendDs));

        }
    }
    
    func intersectionCheck(){
       // let bpx = bPosition.x.get(id: nil);
       // let bpy = bPosition.y.get(id: nil);
        
        
        if((keyStorage["INTERSECTION"]!.count)>0){
            if(self.parent != nil){
                let hit = self.currentCanvas!.parentHitTest(point: self.bPosition, threshold: 5, id:self.id, parentId:self.parent!.id);
            if(hit != nil){
                self.intersections.set(newValue: self.intersections.getSilent()+1);
                for key in keyStorage["INTERSECTION"]!
                {
                    if(key.1 != nil){
                        let condition = key.1;
                        let evaluation = condition?.evaluate();
                        if(evaluation == true){
                            NotificationCenter.default.post(name: NSNotification.Name(rawValue: key.0), object: self, userInfo: ["emitter":self,"key":key.2.id,"event":"INTERSECTION"])
                        }
                    }
                    else{
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: key.0), object: self, userInfo: ["emitter":self,"key":key.2.id,"event":"INTERSECTION"])
                    }
                    
                }
            }
         }
        }
            
    }
    
    func distanceIntervalCheck()
    {
        
        for key in keyStorage["DISTANCE_INTERVAL"]!
        {
            if(key.1 != nil){
                let condition = key.1;
                let evaluation = condition?.evaluate();
                if(evaluation == true){
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: key.0), object: self, userInfo: ["emitter":self,"key":key.2.id,"event":"DISTANCE_INTERVAL"])
                }
            }
            else{
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: key.0), object: self, userInfo: ["emitter":self,"key":key.2.id,"event":"DISTANCE_INTERVAL"])
            }
            
        }
        
    }
    
    
  
        
    func setOrigin(x:Float,y:Float){
        self.origin.set(x:x,y:y);
        let pol = MathUtil.cartToPolar(x1: 0, y1: 0, x2: x, y2: y)
        self.polarPosition.x.setSilent(newValue: pol.0);
        self.polarPosition.y.setSilent(newValue: pol.1);
        self.position.x.setSilent(newValue: self.origin.x.get(id: nil))
        self.position.y.setSilent(newValue: self.origin.y.get(id: nil))
        self.bPosition.x.setSilent(newValue: self.origin.x.get(id: nil))
        self.bPosition.y.setSilent(newValue: self.origin.y.get(id: nil))
        #if DEBUG
            //print("origin set =",stylus.x.get(id:nil),p.x.get(id: nil),p.y.get(id:nil));
        #endif
        
    }
    
    func stateTransitionHandler(data:(String),key:String){
        guard let stateTransition = validateTransitionMapping(key:key) else{
            return;
        }
        self.transitionToState(transition: stateTransition)

    }
    func validateTransitionMapping(key:String)->StateTransition?{
        let mapping = states[currentState]?.getTransitionMapping(key: key)
        if(mapping != nil){
            let stateTransition = mapping
            return stateTransition;
        }
        return nil
        
    }
    
    func transitionToState(transition:StateTransition){
        
        if(states[transition.toStateId]?.name == "die"){
            self.die();
            return;
        }
        print("transition to state ID", transition.toStateId);
        var transmitData:JSON = [:]
        let fromState = currentState;
        transmitData["type"] = JSON("state_transition");
        transmitData["behaviorId"] = JSON(self.behaviorDef!.id);
        transmitData["toState"] = JSON(transition.toStateId);
        transmitData["fromState"] = JSON(fromState);
        transmitData["transitionId"] = JSON(transition.id);
        
        let socketRequest = Request(target: "socket", action: "send_inspector_data", data: transmitData, requester: RequestHandler.sharedInstance)
        //RequestHandler.addRequest(requestData: socketRequest)
         #if DEBUG
        //print("transitioning from state:\(currentState) to state: \(transition.toStateId)");
        #endif
       
        if(states[currentState] != nil){
            let constraint_mappings =  states[currentState]!.constraint_mappings
            for (_, value) in constraint_mappings{
                
         
                value.relativeProperty.constrained = false;
                
            }
        }
        self.currentState = transition.toStateId;
        if(states[currentState] != nil){
        self.executeTransitionMethods(methods: transition.methods)
        
      
        //execute methods
        //check constraints
     
            
            
        //trigger state complete after functions are executed
            if(transitionDelayTimer != nil){
                transitionDelayTimer.invalidate();
            }
       transitionDelayTimer  = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(Brush.completeCallback), userInfo: nil, repeats: false)
     
            
        }
        
    }
    

    @objc func completeCallback(){
        let constraint_mappings =  states[currentState]!.constraint_mappings
        for (_, value) in constraint_mappings{
            value.relativeProperty.constrained = true;
            self.setConstraint(constraint: value);

        }
        for (key,tTransition) in self.transitions{
            
            let validate = self.validateTransitionMapping(key:key)
            let evaluate =  tTransition.condition.evaluate()
            if validate != nil && evaluate == true {
                
                self.transitionToState(transition: tTransition)
                return;
                
            }
        }
    }
    
    
    
    func executeTransitionMethods(methods:[Method]){
        
        for i in 0..<methods.count{
            let method = methods[i];
            let methodName = method.fieldName;
            
            #if DEBUG
               // print("executing method:\(method.fieldName,self.id,self.name,method.arguments)");
            #endif
            switch (methodName){
            case "newStroke",
                 "setOrigin":
                let xArg = method.arguments[0];
                let yArg = method.arguments[1];
                let x = xArg.calculateValue();
                let y = yArg.calculateValue();
                if(x != nil && y != nil){
                    self.setOrigin(x:x!, y: y!)
                }
                if(methodName == "newStroke"){
                    self.newStroke();
                }
                break;
            case "startTimer":
                self.startInterval();
                break;
            case "stopTimer":
                self.stopInterval();
                break;
            case "destroy":
                self.destroy();
                break;
            case "spawn":
                let behaviorArg = method.arguments[0] as! DropdownExpression;
                let countArg = method.arguments[1];
                let arg_string = behaviorArg.getSelectedId();
                let behavior = BehaviorManager.getBehaviorById(id:arg_string);
                
                let count = countArg.calculateValue();
                if(count != nil){
                    self.spawn(behavior:behavior!,num:Int(count!));
                }
                
                break;
            default:
                break;
            }
        }
        
    }
    
    override func startInterval(){
        #if DEBUG
           // print("start interval")
        #endif
        self.stopInterval();

        intervalTimer  = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(Brush.timerIntervalCallback), userInfo: nil, repeats: true)
        
    }
    
    override func stopInterval() {
    
            #if DEBUG
                // print("stop interval")
            #endif
            
            if(intervalTimer != nil){
                #if DEBUG
                    // print("invalidate timer")
                #endif
                intervalTimer.invalidate();
            }
        timer = NSDate();
        self.time.set(newValue: 0);

        

    }
    
    @objc override func timerIntervalCallback()
    {
        
        let currentTime = NSDate();
        //TODO: Fix how this is calucated to deal with lag..
        let t = Float(currentTime.timeIntervalSince(timer as Date))
        self.time.set(newValue: t*1000);
        #if DEBUG
            //print("current time is",self.time.getSilent());
        #endif
        
        //todo: create persistent storage of values
        let sendDs = DeltaStorage(dX:self.dx.getSilent(),dY:self.dy.getSilent(),r:self.rotation.getSilent(),sX:self.sx.getSilent(),sY:self.sy.getSilent(),rX:self.reflectX.getSilent(),rY:self.reflectY.getSilent(),d:self.diameter.getSilent(),h:self.hue.getSilent(),s:self.saturation.getSilent(),l:self.lightness.getSilent(),a:self.alpha.getSilent(),dist:self.distance.getSilent(),xDist:self.xDistance.getSilent(),yDist:self.yDistance.getSilent(),pX:self.position.x.getSilent(),pY:self.position.y.getSilent(),time:self.time.getSilent(),i:self.index.getSilent(),sC:self.siblingcount.getSilent(),lV:self.level.getSilent());
        self.signalEvent.raise(data: (self.behavior_id!,self.id,sendDs));
    }
    
    //sets canvas target to output geometry into
    func setCanvasTarget(canvas:Canvas){
        self.currentCanvas = canvas;
    }
    
    
    /* addConstraint
     //adds a property mapping constraint.
     //property mappings can take two forms, active and passive
     //active: when reference changes, relative is updated to reflect change. This is for properties which are updated manually by the artist
     //like the stylus properties, or properties with an internal interval, like a timed buffer
     //passive: this for constraints which are not actively modifed by an interval or an external change. This can include constants
     //or generators and buffers which will return a new value each time they are accessed
     */
    func addConstraint(id:String,reference:Observable<Float>, relative:Observable<Float>, stateId:String){
       
        /*#if DEBUG
            if let expref = reference as? TextExpression{
                for (_, val) in expref.operandList{
                print("reference,relative",val.printname,relative.printname)
                }
            }
        #endif*/
        let active = reference.isLive()
        let type:String
        if(active){
           type = "active"
            _ = reference.didChange.addHandler(target: self, handler:  Brush.setHandler, key:id)
        }
            
        else{
            type = "passive"
            relative.passiveConstrain(target: reference);
        }
        
        states[stateId]!.addConstraintMapping(key: id,reference:reference,relativeProperty: relative,type:type)
    }
    
    
    
    
    
    //setHandler: triggered when constraint is changed, evaluates if brush is in correct state to encact constraint
    func setHandler(data:(String,Float,Float),stateKey:String){
        // let reference = notification.userInfo?["emitter"] as! Emitter
        
        
        let mapping = states[currentState]?.getConstraintMapping(key: stateKey)
        
        if(mapping != nil){
            
            //let constraint = mapping as! Constraint
            self.setConstraint(constraint: mapping!)
        }
        
    }
    
    func childDieHandler(data:(String),key:String){
        let id = data;
        for c in children.reversed(){
            if c.id == id{
               // _ = self.removeChildAt(index: Int(c.index.get(id: nil)))
            }
        }
        for i in 0..<children.count{
            //self.children[i].index.set(newValue: Float(i));
        }
    }
    
    
    func setConstraint(constraint:Constraint){
        #if DEBUG
          // print("calling set constraint on",  constraint.relativeProperty.name,constraint.relativeProperty,constraint.reference.get(id: self.id))
        #endif
        constraint.relativeProperty.set(newValue: constraint.reference.get(id: self.id));
        
        
        
    }
    
    func addStateTransition(id:String, name:String, condition:Condition, fromStateId: String, toStateId:String){
        
        let transition:StateTransition
        let state = self.states[fromStateId]
        transition = state!.addStateTransitionMapping(id: id,name:name,condition: condition, toStateId:toStateId);
        self.transitions[id] = transition;
        let transitionEvent = transition.didTrigger.addHandler(target: self, handler: Brush.stateTransitionHandler, key: id);
        self.transitionEvents.append(transitionEvent);
    }
    
    func removeStateTransition(data:(Brush, String, Emitter),key:String){
        NotificationCenter.default.removeObserver(data.0, name: NSNotification.Name(rawValue: data.1), object: data.2)
        data.2.removeKey(key: data.1)
    }
    
    func addMethod(transitionId:String, methodId:String, fieldName:String, arguments:[Expression]){
        let transition = transitions[transitionId];

        if (transition != nil) {
            (transition!).addMethod(id: methodId, fieldName:fieldName, arguments:arguments)
        }
        
        
    }
    
    func getTransitionByName(name:String)->StateTransition?{
        for(_,transition) in self.transitions{
            if(transition.name == name){
                return transition;
            }
        }
        return nil
    }
    
    func getStateByName(name:String)->State?{
        for(_,state) in self.states{
            if(state.name == name){
                return state;
            }
        }
        return nil
    }
    
    
    func removeTransition(key:String){
        for (key,val) in states {
            if(val.hasTransitionKey(key: key)){
                let transition =  val.removeTransitionMapping(key: key)!
                transition.destroy();
                break
            }
        }
    }
    
    func resetDistance(){
        self.distance.set(newValue: 0);
        self.xDistance.set(newValue: 0);
        self.yDistance.set(newValue: 0)
        
      
    }
    
    
    
    //===============METHODS AVAILABLE TO USER===============//
    
    
    
    func newStroke(){
        self.currentCanvas!.currentDrawing!.retireCurrentStrokes(parentID: self.id)
        self.currentStroke = self.currentCanvas!.currentDrawing!.newStroke(parentID: self.id);
        self.resetDistance();
    }
    
    //creates number of clones specified by num and adds them as childre    n
    func spawn(behavior:BehaviorDefinition,num:Int) {

        if(num > 0){
            for _ in 0...num-1{
                let child = Brush(name:name, behaviorDef: behavior, parent:self, canvas:self.currentCanvas!)
                self.children.append(child);
              
                child.index.set(newValue: Float(self.children.count-1));
                #if DEBUG
                    print("spawn called, new index is:",child.index.get(id:nil),"of",(self.children.count))
                #endif
                child.level.set(newValue: Float(self.level.get(id: nil)+1));
               
                behavior.initBrushBehavior(targetBrush: child);
                _ = child.dieEvent.addHandler(target: self, handler: Brush.childDieHandler, key: childDieHandlerKey)
            }
            
            for c in children{
                c.siblingcount.set(newValue: Float(self.children.count))
            }
            
            
        }
    }
    
    //=============END METHODS AVAILABLE TO USER==================//
    
    
    
    
    //========= CLEANUP METHODS ==================//
    //removes child at an index and returns it
    // removes listener on child, but does not destroy it
    func removeChildAt(index:Int)->Brush{
        let child = self.children.remove(at: index)
        return child
    }
    
    
    func die(){
        self.dieEvent.raise(data:(self.id));
        self.destroy();
    }
    
    
    func destroyChildren(){
        for child in self.children as [Brush] {
            child.destroy();
            
        }
        self.children.removeAll();
    }
    
    func clearBehavior(){
        for (_,state) in self.states{
            let removedTransitions = state.removeAllTransitions();
            for i in 0..<removedTransitions.count{
                let transition = removedTransitions[i]
                transition.destroy();
            }
            
            state.removeAllConstraintMappings(brush:self);
        }
        self.transitions.removeAll();
        self.states.removeAll();
    }
    
    
    func clearAllEventHandlers(){
        self.geometryModified.removeAllHandlers()
        self.signalEvent.removeAllHandlers();
        self.dieEvent.removeAllHandlers()
        for t in transitionEvents{
            t.dispose();
        }
    }
    
    override func destroy() {
        self.stopInterval();
        if(transitionDelayTimer != nil){
            transitionDelayTimer.invalidate();
        }
        #if DEBUG
            print("destroying brush: \(self.id)");
        #endif
        currentCanvas!.currentDrawing!.retireCurrentStrokes(parentID: self.id)
        self.clearBehavior();
        self.clearAllEventHandlers();
        super.destroy();
    }
    //========= END CLEANUP METHODS ==================//
    
}


// MARK: Equatable
func ==(lhs:Brush, rhs:Brush) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}


