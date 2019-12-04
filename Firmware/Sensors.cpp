#include "Arduino.h"
#include "Sensors.h"

#define WHO_AM_I 0x00
#define HEX_IMU 0xEA //0x71 MPU9250 .. OLD
#define HEX_ULTRASONIC 0x74
#define HEX_RGB 0x75
#define HEX_BUTTON 0x76
#define HEX_NONE 0x00

#define IMU_REG 0x2D //ICM20948 PCB w/ logic converter
#define US_REG1 0x05 //SR05 PIC PCB
#define US_REG2 0x06 
#define RGB_REG 0x14 //TCS34725 PIC PCB
#define BUT_REG 0x01 //Button PIC PCB



byte checkSensorType(byte slaveSelect){
  byte r = 0;
  r = readRegister(slaveSelect, WHO_AM_I, 1);
  return lowByte(r);
}

void initSensor(byte type, byte slaveSelect){
  switch(type){
    case HEX_IMU:
      //SPI.transfer(0x00);
      writeRegister(slaveSelect,0x7F,0x00); //register bank 0
      writeRegister(slaveSelect,0x06,0x41); //reset
      delay(200); //wait for reset
      writeRegister(slaveSelect,0x7F,0x00); //register bank 0
      writeRegister(slaveSelect,0x06,0x01); //sleep off
      writeRegister(slaveSelect,0x03,0x10); //user control
      writeRegister(slaveSelect,0x05,0x40); //disable duty cycle mode
      writeRegister(slaveSelect,0x07,0x00); //accel + gyro enable
      writeRegister(slaveSelect,0x7F,0x02<<4); //register bank 2
      writeRegister(slaveSelect,0x14,0x00); //disable accel lowpass
      writeRegister(slaveSelect,0x00,0x05); //SMPLRT_DIV = 5
      writeRegister(slaveSelect,0x02,0x03); //Gyro 8x averaging
      writeRegister(slaveSelect,0x01,0x05); //enable gyro lowpass, set resolution to 500 DPS
      writeRegister(slaveSelect,0x7F,0x00); //register bank 0
      writeRegister(slaveSelect,0x07,0x00); //accel + gyro enable
    case HEX_RGB:
      writeRegister(slaveSelect,0x02,0xAA);
    break;
  }
}

void readSensorPort(byte type, byte slaveSelect, byte bfr[]){
  switch(type){
    case HEX_IMU:
      //SPI.transfer(0x00);
      readRegisterBuffer(slaveSelect,&bfr[0],IMU_REG,12);
      break;
    case HEX_ULTRASONIC:
      bfr[0] = readRegister(slaveSelect,US_REG1,1);
      bfr[1] = readRegister(slaveSelect,US_REG2,1);
      break;
    case HEX_RGB:
      readRegisterBuffer(slaveSelect,&bfr[0],RGB_REG,8);
      break;
    case HEX_BUTTON:
      bfr[0] = readRegister(slaveSelect,BUT_REG,1);
      break;
//    default:
//      for(int i = 0;i<=11;i++){
//        bfr[i] = 0;  
//      }
  }
}
