#ifndef SENSORS_H_
#define SENSORS_H_

#include "arduino.h"
#include "SPI_Registers.h"

byte checkSensorType(byte slaveSelect);
void initSensor(byte type, byte slaveSelect);
void readSensorPort(byte type, byte slaveSelect, byte bfr[]);

#endif
