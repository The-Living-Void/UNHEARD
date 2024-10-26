import hypermedia.net.*;
import dmxP512.*;
import processing.serial.*;
// osc
import oscP5.*;
import netP5.*;
//timer?
import java.util.Timer;
import java.util.TimerTask;
//
import cc.arduino.*;

OscP5 oscP5;
NetAddress ableton;
Arduino arduino;


boolean useOsc=true;
boolean useDmx=false;
boolean useArduino=false;
float lightMultiply = 0.7;
float signMultLight = 175;

//2do list:
//make action Go when sign is seen  X
//do ableton linking with outputs   X
//cap the outputs                   X
//dmx outputs                       X
//arduino outputs                   
//add timer for to stop same signs triggereing multiple times


//receivePy port
int port = 5005;  // The port number should match the Python script
float xR = 0;
float yR = 0;
float xL = 0;
float yL = 0;
boolean rightHand = false;
boolean leftHand = false;
float heightHandR = 0;
float heightHandL = 0;

hypermedia.net.UDP udp;


boolean sendToDataCollect = true;
hypermedia.net.UDP udp2;
String ipS = "127.0.0.1"; // IP address of the receiver (localhost)
int portS = 12348; // Port to send the data

//dmx
DmxP512 dmxOutput;
int universeSize=128;
boolean DMXPRO=true;
String DMXPRO_PORT="/dev/cu.usbserial-EN160517";//case matters ! on windows port must be upper cased.
int DMXPRO_BAUDRATE=115000;


float x1R, y1R;   // mouse position
float vxR, vyR;   
float x1L, y1L;   // mouse position
float vxL, vyL; 
float turnR=0,turnL=0;
float maxSpeed  = 2;   // speed threshold
int[] directionCountsR  = new int[4];   // counts for each direction (TopLeft, TopRight, BottomRight, BottomLeft)
int[] directionCountsL  = new int[4];   // counts for each direction (TopLeft, TopRight, BottomRight, BottomLeft)
color bgColorR,bgColorL;   // background color
boolean isMovingR  = false;   // flag to track if the mouse is moving
boolean isMovingL  = false;   // flag to track if the mouse is moving
int velocityR, velocity1R,velocity2R,velocity3R,velocity4R = 0;
int velocityL, velocity1L,velocity2L,velocity3L,velocity4L = 0;
int directionR=0,directionL=0;


boolean triggeredUpL = false;
boolean triggeredDownL = false;
boolean triggeredUpR = false;
boolean triggeredDownR = false;
float prevHeightHandL = 0;
float prevHeightHandR = 0;

//timer
long[] cooldownTimers = new long[2]; // Initialize cooldown timers for both hands

float [] highestValues = {0, 0};
float declineRate = 0.13; // Adjust this value to control the decline rate
float smoothingFactor = 0.95; // Adjust this value to control the smoothing

float fill1, fill2, fill3, fill4; // Variables for rectangle fills
float decayRate = 2.0; // Adjust this value to change how fast the fills decay

PImage leftHandImg,rightHandImg;

//udp receive
hypermedia.net.UDP udpPyReceive;
int pythonReceivePort = 12349; 


OscMessage msg1,msg2,msg3,msg4,msg5,msg6,msg7,msg8,msg9;
OscBundle bundle;
int moduloOsc = 2;
boolean runSampleSet=false;

float maxAllowedDistance = 350.0; 
float plate1Tone = 0.0,plate2Tone = 0.0,plate3Tone = 0.0;
float decayPlates = 0.0025;


// Timer variables
long previousTime1 = 0;
long previousTime2 = 0;
long previousTime3 = 0;
long previousGlobalTime = 0;

// Timeout durations
final int TIMEOUT_INDIVIDUAL = 3000;  // 3 seconds
final int TIMEOUT_GLOBAL = 1000;      // 1 second

// State variables
boolean canTrigger1 = true;
boolean canTrigger2 = true;
boolean canTrigger3 = true;
boolean canTriggerGlobal = true;


void setup() {
  size(900,900);
  udp = new hypermedia.net.UDP(this, port);
  //udp.log(true);  // Enable logging to see incoming messages
  udp.listen(true);  // Start listening to incoming messages

  if (sendToDataCollect) {
  udp2 = new hypermedia.net.UDP(this, 6000); // Specify a different port for the local client
  udp2.log(false); // Will print activity to console  
  }
  
  //udp receive stuff
  udpPyReceive = new hypermedia.net.UDP(this, pythonReceivePort);
  udpPyReceive.listen(true);

  leftHandImg = loadImage("handL.png");
  rightHandImg = loadImage("handR.png");

  // frameRate(40);

  //dmx
  if (useDmx) {      
  dmxOutput=new DmxP512(this,universeSize,false);
  if(DMXPRO){
    dmxOutput.setupDmxPro(DMXPRO_PORT,DMXPRO_BAUDRATE);
  }
  }
  //osc ableton
  if (useOsc) {
    oscP5 = new OscP5(this, 11001); // Initialize oscP5, listening on port 12000
    ableton = new NetAddress("127.0.0.1", 11000); // Ableton Live's IP and port
  }

  if(useArduino){
    println(Arduino.list());
    
    // Modify this line, by changing the "0" to the index of the serial
    // port corresponding to your Arduino board (as it appears in the list
    // printed by the line above).
    arduino = new Arduino(this, Arduino.list()[3], 57600);
  }

  // xR  = mouseX;
  // yR  = mouseY;
  vxR  = 0;
  vyR  = 0;
  vxL  = 0;
  vyL  = 0;

  for (int i  = 0; i < directionCountsR.length; i++) {
    directionCountsR[i]  = 0;
  }
  for (int i  = 0; i < directionCountsL.length; i++) {
    directionCountsL[i]  = 0;
  }
  bgColorR  = color(255);   // initial white background
  bgColorL  = color(255);   // initial white background
}

void draw() {
  // The draw loop is left emptyR as we're only listening for UDP messages
  if (frameCount%moduloOsc==0) {
  bundle = new OscBundle();
  }
  // println(frameRate);
  
  long currentTime = millis();
  
  // Update individual timers
  if (!canTrigger1 && (currentTime - previousTime1 >= TIMEOUT_INDIVIDUAL)) {
    canTrigger1 = true;
  }
  if (!canTrigger2 && (currentTime - previousTime2 >= TIMEOUT_INDIVIDUAL)) {
    canTrigger2 = true;
  }
  if (!canTrigger3 && (currentTime - previousTime3 >= TIMEOUT_INDIVIDUAL)) {
    canTrigger3 = true;
  }
  
  // Update global timer
  if (!canTriggerGlobal && (currentTime - previousGlobalTime >= TIMEOUT_GLOBAL)) {
    canTriggerGlobal = true;
  }

  // trackVel(xL,yL);
  if (useDmx) {
  runDmx();  
  }
  
  trackVel(xR,yR,xL,yL);
  // background(bgColor);

  fill(230,10);
  noStroke();
  rect(0, 0, width, height);

  fill(220,255);
  rect(10, 10, 100, 100);
  rect(width-110, 10, 100, 100);

  fill(bgColorR);
  rect(width-20, height-20, 20, 20);
  fill(bgColorL);
  rect(width-40, height-20, 20, 20);

  int runSendCheck = int(map(mouseX,0,width,0,255));
  testSendSet(runSendCheck);



  // println("fill1: "+fill1);
  fill(fill1*1.5);
  rect(0, height-100, 100, 100); // Rectangle 3 (left hand left movement) 3=1 4=2 1=3 2=4

  fill(fill2*1.5);
  rect(100, height-100, 100, 100); // Rectangle 4 (left hand right movement)

  
  
  fill(fill3*1.5);
  rect(width-200, height-100, 100, 100); // Rectangle 1 (right hand left movement) 
  
  fill(fill4*1.5);
  rect(width-100, height-100, 100, 100); // Rectangle 2 (right hand right movement)

  // println("velocityR: "+velocityR);
  
  runVelocity(velocityL,1);
  runVelocity(velocityR,2);
  runVolumePlate();
  turnDownTHePlates();
  
  
  fill(0,50,200);
  ellipseMode(CENTER);

  // println("leftHand: "+leftHand);
  // println("rightHand: "+rightHand);

  if (leftHand) {    
  image(leftHandImg, 10, 10, 100, 100);
  ellipse(xL,yL,heightHandL,heightHandL);  
  }  
  fill(200,50,0);
  if (rightHand) {
  image(rightHandImg, width-100-10, 10, 100, 100);
  ellipse(xR,yR,heightHandR,heightHandR);  
  }

  if (leftHand==false&&rightHand==false) {
    background(heightHandR);
  }else {
    
  }
  if (sendToDataCollect) {
    runDataSend();
  }    

  if(runSampleSet){
  if (leftHand) {checkVelocityAndTrigger(heightHandL, prevHeightHandL, 3.5, this::leftHandUp, this::leftHandDown, new boolean[]{triggeredUpL, triggeredDownL}, cooldownTimers, 0);  }
  if (rightHand) {checkVelocityAndTrigger(heightHandR, prevHeightHandR, 3.5, this::rightHandUp, this::rightHandDown, new boolean[]{triggeredUpR, triggeredDownR}, cooldownTimers, 1);}
  }
  // prevHeightHand = heightHand;
  prevHeightHandL = heightHandL;
  prevHeightHandR = heightHandR;

  if (frameCount%moduloOsc==0) {
  sendOsc();  
  }

  if (useArduino) {
  runArduino();  
  }
  
  
  
}

void runDataSend(){

  String message = xR + "," + yR + "," + velocity1R + "," + heightHandR + "," + turnR + "," + xL + "," + yL + "," + velocity1L + "," + heightHandL + "," + turnL;
  udp2.send(message, ipS, portS);

}
void runDmx(){

  int dmxVal1 = int((plate1Tone*signMultLight)+(fill1*lightMultiply));
  int dmxVal2 = int((plate2Tone*signMultLight)+(fill2*lightMultiply));
  int dmxVal3 = int((plate2Tone*signMultLight)+(fill3*lightMultiply));
  int dmxVal4 = int((plate3Tone*signMultLight)+(fill4*lightMultiply));

  dmxVal1 = int(constrain(dmxVal1,0,255));
  dmxVal2 = int(constrain(dmxVal2,0,255));
  dmxVal3 = int(constrain(dmxVal3,0,255));
  dmxVal4 = int(constrain(dmxVal4,0,255));

  dmxOutput.set(1,dmxVal1);
  dmxOutput.set(2,dmxVal1);

  dmxOutput.set(3,dmxVal2);
  dmxOutput.set(4,dmxVal3);
  
  dmxOutput.set(5,dmxVal4);
  dmxOutput.set(6,dmxVal4);

  // if (velocity1R>255) {velocity1R=255;}
  // if (velocity2R>255) {velocity2R=255;}
  // if (velocity3R>255) {velocity3R=255;}
  // if (velocity4R>255) {velocity4R=255;}
    
  // dmxOutput.set(5,velocity1R);
  // dmxOutput.set(6,velocity1R);
  // dmxOutput.set(7,velocity1R);
  // dmxOutput.set(8,velocity1R);  
  
  // dmxOutput.set(1,velocity4R);  
  // dmxOutput.set(2,velocity4R);  

  // // dmxOutput.set(11,velocity2R);
  // dmxOutput.set(11,velocity2R);


  
}

float lerpAmount = 0.075; // Adjust this value to control the interpolation speed

void trackVel(float xR, float yR, float xL, float yL) {
  // Check for sudden jumps in position
  float distanceR = dist(xR, yR, x1R, y1R);
  float distanceL = dist(xL, yL, x1L, y1L);
  
  // Calculate velocities
  if (distanceR > maxAllowedDistance) {
    // If jump detected, keep previous velocities
    vxR = 0;
    vyR = 0;
  } else {
    vxR = (xR - x1R) / 10.0;
    vyR = (yR - y1R) / 10.0;
  }
  
  if (distanceL > maxAllowedDistance) {
    // If jump detected, keep previous velocities
    vxL = 0;
    vyL = 0;
  } else {
    vxL = (xL - x1L) / 10.0;
    vyL = (yL - y1L) / 10.0;
  }
  
  // Calculate overall velocities including y-axis movement
  float newVelocityR = sqrt(sq(vxR) + sq(vyR));
  float newVelocityL = sqrt(sq(vxL) + sq(vyL));
  
  // Map to usable range
  
  // println("newVelocityR: "+newVelocityR);
  newVelocityR = map(newVelocityR, 0, 5, 0, 255);
  newVelocityL = map(newVelocityL, 0, 5, 0, 255);
  
  newVelocityL = constrain(newVelocityL,0,255);
  newVelocityR = constrain(newVelocityR,0,255);

  // Smooth the velocity changes
  velocityR = int(lerp(velocityR, newVelocityR, lerpAmount));
  velocityL = int(lerp(velocityL, newVelocityL, lerpAmount));
  
  // Calculate speeds for threshold checking
  float speedR = sqrt(sq(vxR) + sq(vyR));
  float speedL = sqrt(sq(vxL) + sq(vyL));
  
  // Right hand processing
  if (speedR > maxSpeed) {
    isMovingR = true;
    // Check if moving left or right (using x velocity)
    if (vxR < 0) { // Moving left
      fill3 = velocityR;
    } else {      // Moving right
      fill4 = velocityR;
    }
  } else if (isMovingR && speedR < maxSpeed) {
    isMovingR = false;
  }
  
  // Left hand processing
  if (speedL > maxSpeed) {
    isMovingL = true;
    // Check if moving left or right
    if (vxL < 0) { // Moving left
      fill1 = velocityL;
    } else {      // Moving right
      fill2 = velocityL;
    }
  } else if (isMovingL && speedL < maxSpeed) {
    isMovingL = false;
  }
  
  // Decay values
  fill1 = max(0, fill1 - decayRate);
  fill2 = max(0, fill2 - decayRate);
  fill3 = max(0, fill3 - decayRate);
  fill4 = max(0, fill4 - decayRate);
  
  // Store previous positions
  x1R = xR;
  y1R = yR;
  x1L = xL;
  y1L = yL;
}

void runArduino(){
  // red1     246
  // blue1    5
  // green1   246
  // red2     5
  // blue2    246
  // green2   5
  if (leftHand) {
    arduino.analogWrite(3, 246);
    arduino.analogWrite(5, 5);
    arduino.analogWrite(6, 246);
  }else {
    arduino.analogWrite(3, 0);
    arduino.analogWrite(5, 0);
    arduino.analogWrite(6, 0);
  }
  if (rightHand) {
    arduino.analogWrite(9, 5);
    arduino.analogWrite(10, 246);
    arduino.analogWrite(11, 5);  
  }else {
    arduino.analogWrite(9, 0);
    arduino.analogWrite(10, 0);
    arduino.analogWrite(11, 0);  
  }
  
  
}

void turnDownTHePlates(){

  
  plate1Tone = plate1Tone-decayPlates;
  plate2Tone = plate2Tone-decayPlates;
  plate3Tone = plate3Tone-decayPlates;

  if (plate1Tone<0){plate1Tone=0;}
  if (plate2Tone<0){plate2Tone=0;}
  if (plate3Tone<0){plate3Tone=0;}



  if (frameCount%moduloOsc==0) {
    msg7 = new OscMessage("/live/track/set/volume");
    msg7.add(5);    
    // msg7.add(int(fill4));    
    plate1Tone = constrain(plate1Tone, 0, 0.8);

    
    msg7.add(plate1Tone);
    bundle.add(msg7);

    msg8 = new OscMessage("/live/track/set/volume");
    msg8.add(6);    
    // msg8.add(int(fill4));
    
    plate2Tone = constrain(plate2Tone, 0, 0.8);
        
    msg8.add(plate2Tone);
    bundle.add(msg8);

    msg9 = new OscMessage("/live/track/set/volume");
    msg9.add(7);    
    // msg9.add(int(fill4));
    plate3Tone = constrain(plate3Tone, 0, 0.8);
    
    msg9.add(plate3Tone);
    bundle.add(msg9);
  }

}

void runVolumePlate(){

  if (frameCount%moduloOsc==0) {
        msg3 = new OscMessage("/live/track/set/send");
        // msg3.add(4);
        msg3.add(0);
        msg3.add(1);
        // msg3.add(int(fill1));        
        float plate1 = map(fill1,0,255,0,0.8);
        plate1 = constrain(plate1, 0, 0.8);

        msg3.add(plate1);
        bundle.add(msg3);
        
        msg4 = new OscMessage("/live/track/set/send");
        msg4.add(0);
        msg4.add(2);
        // msg4.add(int(fill2/2+fill3/2));

        float plate2 = map(fill2,0,255,0,0.8);
        plate2 = constrain(plate2, 0, 0.8);
        
        msg4.add(plate2);
        bundle.add(msg4);

        msg5 = new OscMessage("/live/track/set/send");
        msg5.add(1);
        msg5.add(3);
        // msg5.add(int(fill4));
        float plate3 = map(fill3,0,255,0,0.8);
        plate3 = constrain(plate3, 0, 0.8);
        
        msg5.add(plate3);
        bundle.add(msg5);

        msg6 = new OscMessage("/live/track/set/send");
        msg6.add(1);
        msg6.add(4);
        // msg6.add(int(fill4));
        float plate4 = map(fill4,0,255,0,0.8);
        plate4 = constrain(plate4, 0, 0.8);
        
        msg6.add(plate4);
        bundle.add(msg6);

    }
}


void testSendSet(int input){
    // OscMessage msg = new OscMessage("/live/track/set/volume");
    // msg.add(5);    
    // msg.add(fill1);
    // oscP5.send(msg, ableton);
    // msg.clear();
}

void receive(byte[] data, String ip, int port) {
    
    String message = new String(data);    
    // println("Received message on port " + port + ": " + message); // Debug print
    
  // This function is called whenever a new message is received
    
    if (message.startsWith("ACTION_")) {
        // println("Handling as Python message");  // Debug print
        handlePythonMessage(message);
    } else {
        try {
            String[] parts = split(message, ':');
            if (parts.length >= 2) {
                int controlNumber = int(parts[0]);
                int controlValue = int(parts[1]);
                
                //right
                if(controlNumber == 3){
                    heightHandR = map(controlValue,0,127,0,100);    
                }
                if(controlNumber == 5){
                    xR = map(controlValue,0,127,0,width);    
                }
                if(controlNumber == 6){
                    yR = map(controlValue,0,127,0,width);    
                }
                if(controlNumber == 7){
                    turnR = map(controlValue,0,127,0,100);    
                }
                if(controlNumber == 0){      
                    if (controlValue>10) {
                        rightHand=true;  
                    } else {
                        rightHand=false;
                    }
                }
                
                //left
                if(controlNumber == 13){
                    heightHandL = map(controlValue,0,127,0,100);    
                }
                if(controlNumber == 15){
                    xL = map(controlValue,0,127,0,width);    
                }
                if(controlNumber == 16){
                    yL = map(controlValue,0,127,0,width);    
                }
                if(controlNumber == 17){
                    turnL = map(controlValue,0,127,0,100);    
                }
                if(controlNumber == 10){      
                    if (controlValue>10) {
                        leftHand=true;  
                    } else {
                        leftHand=false;
                    }
                }
            } else {
                println("Invalid message format: " + message);
            }
        } catch (Exception e) {
            println("Error processing message: " + message);
            println("Error details: " + e.getMessage());
        }
    }
    
   }


int getCornerDirection(float vxR, float vyR) {
  if (vxR > 0 && vyR < 0) return 2;   // TopRight
  else if (vxR < 0 && vyR < 0) return 1;   // TopLeft
  else if (vxR > 0 && vyR > 0) return 3;   // BottomRight
  else if (vxR < 0 && vyR > 0) return 4;   // BottomLeft
  else return 0;   // no direction
}

void mouseStopped(int hand) {
  // find the direction with the highest count
  if (hand==0) {
    int maxDirection  = 0;
    int maxCount  = 0;
    for (int i  = 0; i < directionCountsR.length; i++) {
      if (directionCountsR[i] > maxCount) {
        maxDirection  = i + 1;
        maxCount  = directionCountsR[i];
      }
    }

    // update background color based on the most common direction
    if (maxDirection == 1) bgColorR  = color(255, 0, 0);   // red for TopLeft
    else if (maxDirection == 2) bgColorR  = color(0, 255, 0);   // green for TopRight
    else if (maxDirection == 3) bgColorR  = color(0, 0, 255);   // blue for BottomRight
    else if (maxDirection == 4) bgColorR  = color(255, 255, 0);   // yellow for BottomLeft

    // reset direction counts
    for (int i  = 0; i < directionCountsR.length; i++) {
      directionCountsR[i]  = 0;
    }
  }
    if (hand==1) {

      int maxDirection  = 0;
      int maxCount  = 0;
      for (int i  = 0; i < directionCountsL.length; i++) {
        if (directionCountsL[i] > maxCount) {
          maxDirection  = i + 1;
          maxCount  = directionCountsL[i];
        }
    }

    // update background color based on the most common direction
    if (maxDirection == 1) bgColorL  = color(255, 0, 0);   // red for TopLeft
    else if (maxDirection == 2) bgColorL  = color(0, 255, 0);   // green for TopRight
    else if (maxDirection == 3) bgColorL  = color(0, 0, 255);   // blue for BottomRight
    else if (maxDirection == 4) bgColorL  = color(255, 255, 0);   // yellow for BottomLeft

    // reset direction counts
    for (int i  = 0; i < directionCountsL.length; i++) {
      directionCountsL[i]  = 0;
    }
  }
  
}

void checkVelocityAndTrigger(float heightHand, float prevHeightHand, float threshold, Runnable actionUp, Runnable actionDown, boolean[] triggered, long[] cooldownTimers, int hand) {
    float velocity = heightHand - prevHeightHand;

    // println("velocity: "+velocity);
    if (velocity > threshold && !triggered[0] && cooldownTimers[hand] <= System.currentTimeMillis()) {
        actionUp.run();
        triggered[0] = true;
        // cooldownTimers[hand] = System.currentTimeMillis() + 50; // 1 second cooldown
    } else if (velocity < -threshold && !triggered[1] && cooldownTimers[hand] <= System.currentTimeMillis()) {
        actionDown.run();
        triggered[1] = true;
        cooldownTimers[hand] = System.currentTimeMillis() + 100; // 1 second cooldown
    } else if (Math.abs(velocity) < threshold) {
        triggered[0] = false;
        triggered[1] = false;
    }

    prevHeightHand = heightHand;
}

void fireClip(int channel,int clip){
  
  OscMessage msg = new OscMessage("/live/clip/fire"); // OSC address pattern for playing a clip
  msg.add(channel); // Track index (0-based, so 2 means track 3)  
  msg.add(clip); // Clip slot index (0-based, so 2 means third row)    
  oscP5.send(msg, ableton);
  msg.clear();

}

void sendOsc(){

  oscP5.send(bundle, ableton);
  msg1.clear();
  msg2.clear();
  msg3.clear();
  msg4.clear();
  msg5.clear();
  msg6.clear();
  msg7.clear();
  msg8.clear();
  msg9.clear();
  bundle.clear();
}

void runVelocity(float velocityHere, int hand) {
    float volumeAble = 0;
    velocityHere = constrain(velocityHere, 0, 200);
    if (hand == 1 || hand == 2) {
        volumeAble = map(velocityHere, 0, 200, 0, 0.8);
        
        float previousValue = highestValues[hand - 1];
        
        // Only update if the new value is higher than the current highest value
        if (volumeAble > highestValues[hand - 1]) {
            highestValues[hand - 1] = volumeAble;
        } else {
            // Apply the decline only if we're not updating with a new higher value
            highestValues[hand - 1] = max(0, highestValues[hand - 1] - declineRate);
        }
        
        // Apply smoothing to the highest value
        highestValues[hand - 1] = lerp(previousValue, highestValues[hand - 1], 1 - smoothingFactor);
        
        // Use the smoothed highest value as the final volume
        volumeAble = highestValues[hand - 1];
        
        // Debugging output
        // println("Hand: " + hand + ", Velocity: " + velocityHere + ", Volume: " + volumeAble);
    }

    if (hand==1) {
    
    // oscP5.send(msg1, ableton);
    // msg1.clear();  
    if (frameCount%moduloOsc==0) {
      msg1 = new OscMessage("/live/track/set/volume");
      msg1.add(hand - 1);
      msg1.add(volumeAble);
      bundle.add(msg1);
    }
    
    }else if(hand==2){
    // oscP5.send(msg2, ableton);
    // msg2.clear();  
      if (frameCount%moduloOsc==0) {
        msg2 = new OscMessage("/live/track/set/volume");
        msg2.add(hand - 1);
        msg2.add(volumeAble);
        bundle.add(msg2); 
      }
    }

}

void leftHandUp() {
  // println("Left hand moved up!");
}

void leftHandDown() {
  // println("x L "+x1L);
  // println("y L "+y1L);
  if (y1L<500&&x1L<500) {
  fireClip(2,1);  
  }else if(y1L>500&&x1L>500) {
  fireClip(2,2);  
  }else if(y1L<500&&x1L>500) {
  fireClip(2,3);  
  }else if(y1L>500&&x1L<500) {
  fireClip(2,4);  
  }
  
}

void rightHandUp() {
  // println("Right hand moved up!");
}


// Add this new function to handle Python messages
void handlePythonMessage(String message) {
    // println("Processing Python message: " + message);  // Debug print
    long currentTime = millis();

    // "Data": "Data",
    // "Sign Language": "Sign Language",
    // "Representation": "Representation",        
    // "Still/Not Moving": "Still/Not Moving",

    switch(message.trim()) {
        case "ACTION_Data":
            if (canTrigger1 && canTriggerGlobal) {
              println(message);
              fireClip(2, 10);
              plate1Tone = 0.8;
              println("Trigger 1 activated!");
              // Your trigger 1 action here              
              previousTime1 = currentTime;
              previousGlobalTime = currentTime;
              canTrigger1 = false;
              canTriggerGlobal = false;
            }
            break;
        case "ACTION_Sign Language":
            if (canTrigger2 && canTriggerGlobal) {
              println("Trigger 2 activated!");
              // Your trigger 2 action here                            
              println(message);
              fireClip(3, 10);
              plate2Tone = 0.8;
            // fireClip(3, 1);
              previousTime2 = currentTime;
              previousGlobalTime = currentTime;
              canTrigger2 = false;
              canTriggerGlobal = false;            
            }

            break;
        case "ACTION_Representation":
            if (canTrigger3 && canTriggerGlobal) {
              println("Trigger 3 activated!");
              // Your trigger 3 action here
              println(message);
              fireClip(4, 10);
              plate3Tone = 0.8;

              previousTime3 = currentTime;
              previousGlobalTime = currentTime;
              canTrigger3 = false;
              canTriggerGlobal = false;
            }

            // fireClip(4, 1);
            break;
        case "ACTION_Still/Not Moving":
              // println("Still/Not Moving");
              // fireClip(4, 1);
              break;
        default:
            println("Unknown Python message: " + message);
            break;
    }
}
void rightHandDown() {
  // println("Right hand moved down!");
  // println("x R "+x1R);
  // println("y R "+y1R);
  if (y1R<500&&x1R<500) {
   fireClip(3,5);  
   }else if(y1R>500&&x1R>500) {
   fireClip(3,6);  
   }else if(y1R<500&&x1R>500) {
   fireClip(3,7);  
   }else if(y1R>500&&x1R<500) {
   fireClip(3,8);  
   }
}
