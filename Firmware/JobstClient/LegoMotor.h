

#ifndef LEGO_MOTOR_H_
#define LEGO_MOTOR_H_

#include "arduino.h"
#include "Encoder.h"


class LegoMotor
{
  public:
    LegoMotor(int PWMpin, int DIRpin, int CURpin, int ENCApin, int ENCBpin);
    void Set(byte pwm, byte dirByte, byte posByte);
    void ToPos(int pos);
    void SetRaw(byte pwm, byte dir);
    long GetTicks(void);
    int GetCurrent();
  private:
    int _PWMpin;
    int _DIRpin;
    int _CURpin;
    int _ENCApin;
    int _ENCBpin;;
    Encoder _encoder;
    
};


#endif
