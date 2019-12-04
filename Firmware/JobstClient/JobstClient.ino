/* Jobst client v1.2
 * - Fixed freezing of jobst when connecting more than 2 IMUs
 * 
 * 
 *  Author: Vojtech Mlynar
 * 
 *  www.jobst.io
 * 
 */

  #define FIRMWARE_VERSION 12

//debug mode
  //#define DEBUG //debugging leds
  /* LED 4 - serial desync
   * LED 1 - Cube frequency indicator
   * LED 3 - Inner
   * 
   */
 
//Motor A
  #define PWMA 8
  #define DIRA 4
  #define ENCAa 2
  #define ENCAb 39
  #define CURA A2
//Motor B
  #define PWMB 10   //9
  #define DIRB 6    //5
  #define ENCBa 19  //3
  #define ENCBb 41  //38
  #define CURB A4   //A1
//Motor C
  #define PWMC 12   //10
  #define DIRC 45   //6
  #define ENCCa 21  //19
  #define ENCCb 43  //41
  #define CURC A6   //A4
//Motor D
  #define PWMD 9    //11
  #define DIRD 5    //7
  #define ENCDa 3   //18
  #define ENCDb 38  //40
  #define CURD A1   //A3
//Motor E
  #define PWME 11   //12
  #define DIRE 7    //45
  #define ENCEa 18  //21
  #define ENCEb 40  //43
  #define CURE A3   //A6
//Motor F
  #define PWMF 44
  #define DIRF 46
  #define ENCFa 20
  #define ENCFb 42
  #define CURF A5
//Battery 
  #define VBATPIN A0
  
//Onboard peripheries
  #define IMUCS 29
  #define MAGCS 25
  #define TEMPPIN A9
  #define BUT1PIN 22
  #define BUT2PIN 33
  #define BUT3PIN 37
  #define BUT4PIN 48
  #define LED1PIN 49
  #define LED2PIN 36
  #define LED3PIN 35
  #define LED4PIN 23

//Sensors chip select
  #define S1CS 27
  #define S2CS 28
  #define S3CS 32
  #define S4CS 26
  #define S5CS 30
  #define S6CS 31
  #define SEN_NUM 6

//Misc. constants
  #define SENSOR_LENGTH 12
  #define SENSOR_FIRST 45  

#define SYNCPIN 35
#define statusLED 36

//Protocol message lengths
#define MSGOUT_LEN 121
#define MSGIN_LEN 27

#define HEX_IMU 0xEA   //0x71 MPU .. OLD
#define HEX_ULTRASONIC 0x74
#define HEX_RGB 0x75
#define HEX_BUTTON 0x76
#define HEX_NONE 0x00

#include "SPI_Registers.h"
#include "LegoMotor.h"
#include "Sensors.h"
#include "Encoder.h"



LegoMotor motorA(PWMA,DIRA,CURA,ENCAa,ENCAb);
LegoMotor motorB(PWMB,DIRB,CURB,ENCBa,ENCBb);
LegoMotor motorC(PWMC,DIRC,CURC,ENCCa,ENCCb);
LegoMotor motorD(PWMD,DIRD,CURD,ENCDa,ENCDb);
LegoMotor motorE(PWME,DIRE,CURE,ENCEa,ENCEb);
LegoMotor motorF(PWMF,DIRF,CURF,ENCFa,ENCFb);


bool led = 1;

int loops = 1;
int curVal1;
int curVal3;
long ticks[6];
long diff[6];
int corruptedTicks = 0;
byte reconnect = 1;
unsigned long timeout = 100000; 

byte messageOut[MSGOUT_LEN];
byte messageIn[MSGIN_LEN];
byte g_sensorTypes[7] = {0, 0, 0, 0, 0, 0}; // {HEX_IMU, HEX_IMU, HEX_IMU,HEX_IMU, HEX_IMU, HEX_IMU,0};
byte g_slaveSelects[7] = {S1CS, S2CS, S3CS, S4CS, S5CS, S6CS};
byte g_sensor1Vals[13];
byte g_sensor2Vals[13];
byte g_sensor3Vals[13];
byte g_sensor4Vals[13];
byte g_sensor5Vals[13];
byte g_sensor6Vals[13];

void setup() {
    //TCCR0B = (TCCR0B & 0xF8) | 0x02 ; //Verify if it's possible to change Timer 0, cause it is used for delay fucntions and could interfere with SPI/Serial/whatever
    TCCR1B = (TCCR1B & 0xF8) | 0x02 ; //Set Timer 1 to 3,9kHz... copied from: http://sobisource.com/arduino-mega-pwm-pin-and-frequency-timer-control/
    TCCR2B = (TCCR2B & 0xF8) | 0x02 ; //Set Timer 2 to 3,9kHz
    TCCR3B = (TCCR3B & 0xF8) | 0x02 ; //Set Timer 3 to 3,9kHz
    TCCR4B = (TCCR4B & 0xF8) | 0x02 ; //Set Timer 4 to 3,9kHz
    TCCR5B = (TCCR5B & 0xF8) | 0x02 ; //Set Timer 5 to 3,9kHz
  
  pinMode(LED1PIN,OUTPUT);
  pinMode(LED2PIN,OUTPUT);
  pinMode(LED3PIN,OUTPUT);
  pinMode(LED4PIN,OUTPUT);
  pinMode(VBATPIN,INPUT);
  pinMode(BUT1PIN,INPUT);
  pinMode(BUT2PIN,INPUT);
  pinMode(BUT3PIN,INPUT);
  pinMode(BUT4PIN,INPUT);
  pinMode(TEMPPIN,INPUT);
  
  for(int i = 0; i <= SEN_NUM-1; i++){
    pinMode(g_slaveSelects[i], OUTPUT);
    digitalWrite(g_slaveSelects[i], HIGH);
  }
  pinMode(IMUCS,OUTPUT);
  digitalWrite(IMUCS,HIGH);
  pinMode(MAGCS,OUTPUT);
  digitalWrite(MAGCS,HIGH);

  
  digitalWrite(LED3PIN,LOW);
  
  for(int i = 0; i <= 12; i++){
    g_sensor1Vals[i] = 0;
    g_sensor2Vals[i] = 0;
    g_sensor3Vals[i] = 0;
    g_sensor4Vals[i] = 0;
    g_sensor5Vals[i] = 0;
    g_sensor6Vals[i] = 0;
  }

  //Initialize SPI
  SPI.begin();
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE3));
  delay(150);
  
  messageOut[0] = 0xAA;
  for(int i = 1; i <= MSGOUT_LEN-3; i++){
     messageOut[i] = 0;
  }
  messageOut[MSGOUT_LEN-3] = 0;
  messageOut[MSGOUT_LEN-2] = MSGOUT_LEN;
  messageOut[MSGOUT_LEN-1] = 0xCC;
////  digitalWrite(LED1PIN,HIGH);
////  digitalWrite(LED2PIN,HIGH);
////  digitalWrite(LED3PIN,HIGH);
////  digitalWrite(LED4PIN,HIGH);


  pingSensors();
//  for(int i = 0; i <=5;i++){
//    initSensor(g_sensorTypes[i],g_slaveSelects[i]);
//  }
  
     
  Serial.begin(1000000);
  digitalWrite(LED2PIN,HIGH); 
  while(!Serial);
  digitalWrite(LED2PIN,LOW);
  //delay(100);
  //Serial.write(messageOut,MSGOUT_LEN);
//  digitalWrite(LED1PIN,LOW);
//  digitalWrite(LED2PIN,LOW);
//  digitalWrite(LED3PIN,LOW);
//  digitalWrite(LED4PIN,LOW);
  #ifdef DEBUG
    digitalWrite(LED1PIN,led);
  #endif
}





//MAIN LOOP
void loop() {
  
  #ifdef DEBUG  //loops%10 == 0
    //pingSensors();
    digitalWrite(LED1PIN,led);
    if(led == 1){
      led = 0;
    }else{
      led = 1;
    }
  #endif

  timeout = 100000;
  while(Serial.available() == 0) {
      delayMicroseconds(10);
      timeout--;
      if(timeout == 0){ //If it is 1 second since last command came in
        motorA.Set(0,0,0);
        motorB.Set(0,0,0);
        motorC.Set(0,0,0);
        motorD.Set(0,0,0);
        motorE.Set(0,0,0);
        motorF.Set(0,0,0);
        timeout = 100000;

//        if(reconnect > 0){ //try to wake up Matlab
//          Serial.flush(); //Wait for outgoing transmission to complete
//          Serial.write(messageOut,MSGOUT_LEN);
//          reconnect--;
//        }

      }
    }      // If anything comes in Serial (USB),

  reconnect = 1;
  #ifdef DEBUG
      digitalWrite(LED3PIN,HIGH);
  #endif

  
  
  Serial.readBytes(messageIn,MSGIN_LEN);
  if(messageIn[0] != 0xAA || messageIn[MSGIN_LEN-1] != 0xCC){ // || messageIn[MSGIN_LEN-2] != MSGIN_LEN
    if(messageIn[MSGIN_LEN-1] == 0xCD){ //Initialization sequence
      
      //pingSensors;
      for(int i = 0; i <=5;i++){
        initSensor(g_sensorTypes[i],g_slaveSelects[i]);
      }
      messageOut[3] = FIRMWARE_VERSION;
      int batt = analogRead(VBATPIN);
      parseIntToBytes(&messageOut[1],batt);
      for(int i = 0; i<=5; i++){
        messageOut[i+4] = g_sensorTypes[i];
      }
      //delay(1000);
      goto initSkipLabel; //Skip parsing data to avoid overwriting init message
    }else{ //Arduino is desynchronised
      #ifdef DEBUG
        digitalWrite(LED4PIN,HIGH);
      #endif
      syncSerial();
    }
  }
  //digitalWrite(SYNCPIN,LOW);
  if(checkCRC(messageIn, MSGIN_LEN-2,messageIn[MSGIN_LEN-2])){
    //Do if CRC is OK
    
    //INPUT section
    //Set motors
    motorA.Set(messageIn[5],messageIn[6],messageIn[7]);
    motorB.Set(messageIn[8],messageIn[9],messageIn[10]);
    motorC.Set(messageIn[11],messageIn[12],messageIn[13]);
    motorD.Set(messageIn[14],messageIn[15],messageIn[16]);
    motorE.Set(messageIn[17],messageIn[18],messageIn[19]);
    motorF.Set(messageIn[20],messageIn[21],messageIn[22]); //Check functionality!!
    //Set LEDs
    digitalWrite(LED1PIN,messageIn[1]);
    digitalWrite(LED2PIN,messageIn[2]);
    digitalWrite(LED3PIN,messageIn[3]);
    digitalWrite(LED4PIN,messageIn[4]);
    
    //OUTPUT section
    //Get sensor readings
    readSensorPort(g_sensorTypes[0],g_slaveSelects[0],g_sensor1Vals);
    readSensorPort(g_sensorTypes[1],g_slaveSelects[1],g_sensor2Vals);
    readSensorPort(g_sensorTypes[2],g_slaveSelects[2],g_sensor3Vals);
    readSensorPort(g_sensorTypes[3],g_slaveSelects[3],g_sensor4Vals);
    readSensorPort(g_sensorTypes[4],g_slaveSelects[4],g_sensor5Vals);
    readSensorPort(g_sensorTypes[5],g_slaveSelects[5],g_sensor6Vals);
    //parse sensor readings
    parseArray(&messageOut[SENSOR_FIRST],g_sensor1Vals,12); //+ SENSOR_LENGTH*0
    parseArray(&messageOut[SENSOR_FIRST + (SENSOR_LENGTH*1)],g_sensor2Vals,12);
    parseArray(&messageOut[SENSOR_FIRST + (SENSOR_LENGTH*2)],g_sensor3Vals,12);
    parseArray(&messageOut[SENSOR_FIRST + (SENSOR_LENGTH*3)],g_sensor4Vals,12);
    parseArray(&messageOut[SENSOR_FIRST + (SENSOR_LENGTH*4)],g_sensor5Vals,12);
    parseArray(&messageOut[SENSOR_FIRST + (SENSOR_LENGTH*5)],g_sensor6Vals,12);

    //parse encoder and motor current values
    parseIntToBytes(&messageOut[21],motorA.GetTicks());
    messageOut[24] = motorA.GetCurrent()>>2;
    parseIntToBytes(&messageOut[25],motorB.GetTicks());
    messageOut[28] = motorB.GetCurrent()>>2;
    parseIntToBytes(&messageOut[29],motorC.GetTicks());
    messageOut[32] = motorC.GetCurrent()>>2;
    parseIntToBytes(&messageOut[33],motorD.GetTicks());
    messageOut[36] = motorD.GetCurrent()>>2;
    parseIntToBytes(&messageOut[37],motorE.GetTicks());
    messageOut[40] = motorE.GetCurrent()>>2;
    parseIntToBytes(&messageOut[41],motorF.GetTicks());
    messageOut[44] = motorF.GetCurrent()>>2;
    

    //parse battery voltage
    int batt = analogRead(VBATPIN);
    parseIntToBytes(&messageOut[1],batt);

    //parse onboard button values
    messageOut[3] = digitalRead(BUT1PIN);
    messageOut[4] = digitalRead(BUT2PIN);
    messageOut[5] = digitalRead(BUT3PIN);
    messageOut[6] = digitalRead(BUT4PIN);

    //parse temperature values
    int temperature = analogRead(TEMPPIN);
    parseIntToBytes(&messageOut[7],temperature);
    
    //END of parsing 
  }
  else //wrong CRC
  {
    corruptedTicks++;
  }
  
  initSkipLabel: //Skip parsing data to avoid overwriting init message
  
  //General protocol bytes
  messageOut[MSGOUT_LEN-3] = messageIn[MSGIN_LEN-3]; //Pass through checkBit
  messageOut[MSGOUT_LEN-4] = corruptedTicks;
  
  messageOut[MSGOUT_LEN-2] = CalculateCRC(messageOut,MSGOUT_LEN-2); //Dont calculate end byte and CRC byte
  Serial.flush(); //Wait for outgoing transmission to complete
  //if(digitalRead(BUT1PIN) == 0){ //Debugging to block outgoing transmission  
  Serial.write(messageOut,MSGOUT_LEN);
  
  //}
  loops++;
  #ifdef DEBUG
    digitalWrite(LED3PIN,LOW);
  #endif
}

//END OF MAIN LOOP


byte CalculateCRC(byte str[], byte len){
  byte c = 0;
  int i = 0;
  while(i < len){
    c = c^str[i];
    i++;
  }
  return c;
}

byte checkCRC(byte str[], byte len, byte crc){
  if(crc == CalculateCRC(str,len)){
    return 1;
  }else{
    return 0;
  }
}

int readBatteryVoltage(void){
  return analogRead(VBATPIN);
}

int readOnboardTemperature(void){
  return analogRead(TEMPPIN);
}

void readOnboardIMU(int chipselect, int arr[]){
  //to be finished
  return;
}

void pingSensors(void){
  for(int i = 0; i <= SEN_NUM-1; i++){
     g_sensorTypes[i] = checkSensorType(g_slaveSelects[i]);
  }
}

void syncSerial(void){
  byte garbage;
  byte garbageBuffer[MSGIN_LEN+1];
  unsigned int i = 0;
  #ifdef DEBUG
    digitalWrite(LED4PIN,HIGH);
  #endif
  
  motorA.Set(0,0,0);
  motorB.Set(0,0,0);
  motorC.Set(0,0,0);
  motorD.Set(0,0,0);
  motorE.Set(0,0,0);
  motorF.Set(0,0,0);
  
  while(1){
      do{
        //Serial.readBytes(garbage,1);
        garbage = Serial.read();
        garbageBuffer[0] = garbage;
      }while(garbageBuffer[0] != 0xAA);
      
      for(i = 1; i<MSGIN_LEN; i++){
        //Serial.readBytes(garbage,1);
        garbage = Serial.read();
        garbageBuffer[i] = garbage;
      }
          
      if(garbageBuffer[0] == 0xAA && garbageBuffer[MSGIN_LEN-1] == 0xCC && garbageBuffer[MSGIN_LEN] == 0xAA){
        for(i = 1; i < MSGIN_LEN-1; i++){
          //Serial.readBytes(garbage,1);
          garbage = Serial.read();
        }
        break;
      }  
    }
    
    #ifdef DEBUG
      digitalWrite(LED4PIN,LOW);
    #endif
}

void parseIntToBytes(byte byteArray[], int intToParse){
  byteArray[0] = highByte(intToParse);
  byteArray[1] = lowByte(intToParse);
  return;
}

void parseArray(byte arrayPointer[], byte arrayToParse[], byte bytesToParse){
    for(int i = 0; i <= bytesToParse; i++){
      *arrayPointer = arrayToParse[i];
      arrayPointer++;
    }
}
