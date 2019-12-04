#include "Arduino.h"
#include "LegoMotor.h"
#include "Encoder.h"

#define K_P 1

LegoMotor::LegoMotor(int PWMpin, int DIRpin, int CURpin, int ENCApin, int ENCBpin):_encoder(ENCApin,ENCBpin)
{
   _ENCApin = ENCApin;
   _ENCBpin = ENCBpin;
   //Encoder _encoder;
   _PWMpin = PWMpin;
   _DIRpin = DIRpin;
   _CURpin = CURpin;
   pinMode(_PWMpin, OUTPUT);
   pinMode(_DIRpin, OUTPUT);
   pinMode(_CURpin, INPUT);
}

void LegoMotor::Set(byte pwm, byte dirByte, byte posByte)
{
  if(posByte == 0){ //Raw input
    SetRaw(pwm, dirByte); 
  }else{ //position control
    ToPos(int((dirByte<<8)|posByte));
  }
}

void LegoMotor::ToPos(int pos){
  bool dir;
  long ticks = GetTicks();
  long error = pos - ticks;
  float action_value = error*K_P;
  byte action_value_byte = abs(constrain(action_value, -255,255));
  if(action_value > 0){
    dir = 0;
  }else{
    dir = 1;
  }
  SetRaw(action_value_byte,dir);
}

void LegoMotor::SetRaw(byte pwm, byte dir){
  if(dir == 0){
    analogWrite(_DIRpin,255-pwm);
    digitalWrite(_PWMpin,1);
  }else if(dir == 1){
    digitalWrite(_DIRpin,1);
    analogWrite(_PWMpin,255-pwm);
  }
}

long LegoMotor::GetTicks(void)
{
  return _encoder.read();
}

int LegoMotor::GetCurrent(void)
{
  return analogRead(_CURpin);
}
