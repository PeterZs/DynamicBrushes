//
//  StylusManager.swift
//  DynamicBrushes
//
//  Created by JENNIFER MARY JACOBS on 1/30/18.
//  Copyright © 2018 pixelmaid. All rights reserved.
//

import Foundation
import SwiftyJSON

//feeds stylus live or pre-recorded data depending on state of system
final class StylusManager{
    
    static let stylusUp = Float(0.0);
    static let stylusMove = Float(1.0);
    static let stylusDown = Float(2.0);
    static private var isLive = true;
    static private var currentRecordingPackage:StylusRecordingPackage!
    static private var currentLoopingPackage:StylusRecordingPackage!
    static private var playbackTimer:Timer!
    //todo: get rid of this and use linked list structure
    static private var recordingPackages = [String:StylusRecordingPackage]()
    static var layerId:String!
    static private var currentStartDate:Date!
    //producer consumer props
    static private let queue = DispatchQueue(label: "stylus-queue")
    static private var producer = StylusDataProducer()
    static private var consumer = StylusDataConsumer()
    static private var samples = [Sample]();
    static private var usedSamples = [Sample]();
    static private var firstRecording:String!
    static private var lastRecording:String!

    //events
    static public let eraseEvent = Event<(String,[String:[String]])>();
    static public let recordEvent = Event<(String,StylusRecordingPackage)>();
    static public let layerEvent = Event<(String,String)>();

    
    init(){
        
    }
    
    
    
    static private func beginRecording(start:Date)->StylusRecordingPackage{
        
        let rPackage = StylusRecordingPackage(id: NSUUID().uuidString,start:start,targetLayer:StylusManager.layerId)
        if(firstRecording == nil){
            firstRecording = rPackage.id;
        }
        lastRecording = rPackage.id;
        recordingPackages[rPackage.id] = rPackage;
        
        if(currentRecordingPackage != nil){
            currentRecordingPackage.store(next: rPackage);
        }
        
        currentRecordingPackage = rPackage;
        return currentRecordingPackage;
        
    }
    
    static private func endRecording()->StylusRecordingPackage?{
        if(currentRecordingPackage != nil){
            currentRecordingPackage.endRecording();
            recordEvent.raise(data:("END_RECORDING",currentRecordingPackage));
            return currentRecordingPackage;
        }
        return nil
    }
    
    
    @objc static private func advanceRecording(){
        /*if buffer < size {*/
        
        queue.sync {
            if(samples.count>0){
                let currentSample = samples.remove(at: 0);
                
                self.consumer.consume(sample:currentSample);
                
                //  print(currentSample.stylusEvent,"sample hash, last hash",currentSample.hash,currentSample.lastHash)
                usedSamples.append(currentSample);
                if(currentSample.isLastinRecording){
                    samples.append(contentsOf:usedSamples);
                    usedSamples.removeAll();
                    eraseEvent.raise(data:("ERASE_REQUEST",currentLoopingPackage.resultantStrokes));
                }
            }
        }
        
    }
    
    static func setToLastRecording(){
        if(firstRecording != nil){
            print("set to recording",firstRecording!,lastRecording!)
            setToRecording(idStart: firstRecording!, idEnd: lastRecording!)
        }
    }
    
    static func liveStatus()->Bool{
        return self.isLive
    }
    
    static func setToLive(){
        self.isLive = true;
        if playbackTimer != nil {
            playbackTimer.invalidate()
            playbackTimer = nil
            
            samples.removeAll();
            usedSamples.removeAll();
            
        }
        
    }
    
    static func setToRecording(idStart:String,idEnd:String){
        self.isLive = false;
        
        currentStartDate = Date();
        currentLoopingPackage = recordingPackages[idStart];

            eraseEvent.raise(data:("ERASE_REQUEST",currentLoopingPackage.resultantStrokes));

        queue.sync {
            while (true){
                print("====advance recording start====",currentLoopingPackage.id);
            for i in 0..<Int(currentLoopingPackage.lastSample+1){
                let hash = i;
                let sample = producer.produce(hash: Float(hash), recordingPackage: currentLoopingPackage);
                if sample != nil{
                    samples.append(sample!);
                    print("advance recording", hash,samples.count);
                    
                }
            }
            print("====advance recording break====");
            //prevTime = elapsedTime;
                if(currentLoopingPackage.id == idEnd){
                    samples[samples.count-1].isLastinRecording = true;
                    break;

                }
                else{
                    currentLoopingPackage = currentLoopingPackage.next;
                }
            }
        }
        
        playbackTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(advanceRecording), userInfo: nil, repeats: true)
        
    }
    
   
    
    static func onStylusMove(x:Float,y:Float,force:Float,angle:Float){
        if(isLive){
            let currentTime = Date();
            let elapsedTime = Float(Int(currentTime.timeIntervalSince(currentStartDate!)*1000));
            
            let xLast = currentRecordingPackage.x.get(id:nil);
            let yLast = currentRecordingPackage.y.get(id:nil);
            let dx = x-xLast;
            let dy = y-yLast;
            
            currentRecordingPackage.addRecord(time:elapsedTime, dx: dx, dy: dy, x: x, y: y, force: force, angle: angle, stylusEvent: StylusManager.stylusMove)
            
            
            stylus.onStylusMove(x: x, y: y, force: force, angle: angle)
        }
    }
    
    static func onStylusUp(x:Float,y:Float,force:Float,angle:Float){
        if(isLive){
            let currentTime = Date();
            let elapsedTime = Float(Int(currentTime.timeIntervalSince(currentStartDate!)*1000));
            
            currentRecordingPackage.addRecord(time:elapsedTime, dx: 0, dy: 0, x: x, y: y, force: force, angle: angle,stylusEvent: StylusManager.stylusUp)
            _ = self.endRecording();
            stylus.onStylusUp();
            
        }
    }
    
    static func onStylusDown(x:Float,y:Float,force:Float,angle:Float){
        if(isLive){
            currentStartDate = Date();
            let currentTime = Date();
            let elapsedTime = Float(Int(currentTime.timeIntervalSince(currentStartDate!)*1000));
            let rPackage = beginRecording(start:currentStartDate);
            rPackage.addRecord(time:elapsedTime, dx: 0, dy: 0, x: x, y: y, force: force, angle: angle,stylusEvent: StylusManager.stylusDown)
            stylus.onStylusDown(x: x, y: y, force: force, angle: angle);
        }
    }
    static func addResultantStroke(layerId:String, strokeId:String){
        if(isLive){
            currentRecordingPackage.addResultantStroke(layerId: layerId, strokeId: strokeId);
        }
        else{
            currentLoopingPackage.addResultantStroke(layerId: layerId, strokeId: strokeId);
        }
    }
    
    static func setLayerId(layerId:String){
        StylusManager.layerId = layerId;
    }
    
    static func  handleDeletedLayer(deletedId: String){
        if(firstRecording != nil){
            var targetRecordingPackage = recordingPackages[firstRecording]
            while(true){
                if(targetRecordingPackage!.targetLayer == layerId ){
                    recordingPackages.removeValue(forKey:targetRecordingPackage!.id);

                    
                    if(targetRecordingPackage!.prev != nil){
                        targetRecordingPackage!.prev!.next = targetRecordingPackage!.next;
                    }
                    if(targetRecordingPackage!.next != nil){
                        targetRecordingPackage!.next!.prev = targetRecordingPackage!.prev;
                        targetRecordingPackage = targetRecordingPackage!.next
                    }
                    else{
                        break;
                    }
                    
                }
            }
            
        }
    }
   
}


class StylusDataProducer{
    
    
    func produce(hash:Float,recordingPackage:StylusRecordingPackage)->Sample?{
     
        let sample = recordingPackage.getRecording(hash:hash);
       // print("sample found at time",hash);
        return sample;
    }
    
}


class StylusDataConsumer{
    
    func consume(sample:Sample){
        
        
        
        switch(sample.stylusEvent){
        case StylusManager.stylusUp:
            stylus.onStylusUp();
            break;
        case StylusManager.stylusDown:
            StylusManager.layerEvent.raise(data:("REQUEST_CORRECT_LAYER",sample.targetLayer));
            stylus.onStylusDown(x: sample.x, y: sample.y, force: sample.force, angle: sample.angle);
            break;
        case StylusManager.stylusMove:
            stylus.onStylusMove(x: sample.x, y: sample.y, force: sample.force, angle: sample.angle);
            break;
        default:
            break
        }
        
    }
}
    
    
    class StylusRecordingPackage{
        var dx:Recording;
        var dy:Recording;
        var x:Recording;
        var y:Recording;
        var stylusEvent:EventRecording;
        var force:Recording;
        var angle:Recording;
        var id:String;
        var next:StylusRecordingPackage?
        var prev:StylusRecordingPackage?
        var samples:Set<Float> = [];
        var lastSample:Float = 0;
        var start:Date;
        var resultantStrokes = [String:[String]]();
        var targetLayer:String
        init(id:String,start:Date,targetLayer:String){
            self.id = id;
            dx = Recording(id: "dx_"+id);
            dy = Recording(id: "dy_"+id);
            x = Recording(id: "x_"+id);
            y = Recording(id: "y_"+id);
            force = Recording(id: "force_"+id);
            angle = Recording(id: "angle_"+id);
            stylusEvent = EventRecording(id: "events_"+id);
            self.start = start;
            self.targetLayer = targetLayer;
        }
        
        func addResultantStroke(layerId:String,strokeId:String){
            if(resultantStrokes[layerId] == nil){
                resultantStrokes[layerId] = [String]();
            }
            resultantStrokes[layerId]!.append(strokeId);
        }
        
        func removeResultantStrokes(){
            resultantStrokes.removeAll();
        }
        
        func addRecord(time:Float, dx:Float,dy:Float,x:Float,y:Float,force:Float,angle:Float,stylusEvent:Float){
            self.dx.pushValue(h: time, v: dx);
            self.dy.pushValue(h: time, v: dy);
            self.x.pushValue(h: time, v: x);
            self.y.pushValue(h: time, v: y);
            self.force.pushValue(h: time, v: force);
            self.angle.pushValue(h: time, v: angle);
            self.stylusEvent.pushValue(h: time, v: stylusEvent)
            self.samples.insert(time);
            lastSample = time;
            
        }
        
        func getRecording(hash:Float)->Sample?{
            if(self.samples.contains(hash)){
                dx.setHash(h: hash);
                dy.setHash(h: hash);
                x.setHash(h: hash);
                y.setHash(h: hash);
                force.setHash(h: hash);
                angle.setHash(h: hash);
                stylusEvent.setHash(h: hash);
                
                let sample = Sample(dx: dx.get(id:nil), dy: dy.get(id:nil), x: x.get(id:nil), y: y.get(id:nil), force: force.get(id:nil), angle: angle.get(id:nil), targetLayer:self.targetLayer, stylusEvent: stylusEvent.get(id:nil),hash:hash,lastHash:self.lastSample)
                return sample;
            }
            return nil;
        }
        
        
        
        func store(next:StylusRecordingPackage){
            self.next = next;
            next.prev = self;
            self.dx.setNext(r: next.dx);
            self.dy.setNext(r: next.dy);
            self.x.setNext(r: next.x);
            self.y.setNext(r: next.x);
            self.force.setNext(r: next.force);
            self.angle.setNext(r: next.angle);
            
            next.dx.setPrev(r: self.dx);
            next.dy.setPrev(r: self.dy);
            next.x.setPrev(r: self.x);
            next.y.setPrev(r: self.x);
            next.force.setPrev(r: self.force);
            next.angle.setPrev(r: self.angle);
            
            
        }
        
        func endRecording(){
            var sampleList = [Float:Float]();
            var hashValue:Float  = 0;
            while(hashValue <= self.lastSample){
                if(self.samples.contains(hashValue)){
                  stylusEvent.setHash(h: hashValue);
                let sE = stylusEvent.get(id:nil);
              
                    sampleList[hashValue] = sE;
                   print(" recording at:",hashValue,sE);
                }
                hashValue+=1.0;
            }
            
        }
        
        
    }
    
    
    struct Sample{
        let dx:Float
        let dy:Float
        let x:Float
        let y:Float
        let stylusEvent:Float
        let force:Float
        let angle:Float
        let hash:Float
        let lastHash:Float
        let targetLayer:String
        var isLastinRecording:Bool = false;
        
        init(dx:Float,dy:Float,x:Float,y:Float,force:Float,angle:Float,targetLayer:String,stylusEvent:Float, hash:Float, lastHash:Float){
            self.dx=dx;
            self.dy=dy;
            self.x=x;
            self.y=y;
            self.force=force;
            self.angle=angle;
            self.stylusEvent=stylusEvent;
            self.targetLayer = targetLayer;
            self.hash = hash;
            self.lastHash = lastHash;
        }
        
}