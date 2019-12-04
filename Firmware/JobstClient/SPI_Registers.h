#ifndef SPI_REGISTERS_H_
#define SPI_REGISTERS_H_

#include "arduino.h"
#include "SPI.h"

unsigned int readRegister(byte slaveSelect, byte thisRegister, int bytesToRead);

void readRegisterBuffer(byte slaveSelect, byte bfr[], byte thisRegister, byte bytesToRead);

void writeRegister(byte slaveSelect, byte thisRegister, byte thisValue);


#endif
