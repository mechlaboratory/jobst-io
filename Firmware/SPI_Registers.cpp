
#include "SPI_Registers.h"

#define USDELAY 15 //100 is definitely safe, 30 should be

//if there are problems with PIC boards, make sure their internal clock is 32MHz (load with latest firmware),
//otherwise increase this delay (has significant effect on resulting frequency of system!)


const byte READ = 0b10000000;     
const byte WRITE = 0b00000000;   

unsigned int readRegister(byte slaveSelect, byte thisRegister, int bytesToRead) {
  byte inByte = 0;           // incoming byte from the SPI
  unsigned int result = 0;   // result to return

  byte dataToSend = thisRegister | READ; // now combine the address and the command into one byte
  
  digitalWrite(slaveSelect, LOW); // take the chip select low to select the device:
  SPI.transfer(dataToSend); // send the device the register you want to read:
  delayMicroseconds(USDELAY); // delay needed for communicating with PIC 
  result = SPI.transfer(0x00); // send a value of 0 to read the first byte returned: 
  bytesToRead--;// decrement the number of bytes left to read:
  if (bytesToRead > 0) { // if you still have another byte to read:
    result = result << 8; // shift the first byte left, then get the second byte:
    inByte = SPI.transfer(0x00);
    result = result | inByte; // combine the byte you just got with the previous one:
    bytesToRead--; // decrement the number of bytes left to read:
  }
  digitalWrite(slaveSelect, HIGH);// take the chip select high to de-select:
  return (result); // return the result:
}





void readRegisterBuffer(byte slaveSelect, byte bfr[], byte thisRegister, byte bytesToRead){
  byte i = 0;           // incoming byte from the SPI
  unsigned int result = 0;   // result to return
  
  byte dataToSend = thisRegister | READ; // now combine the address and the command into one byte
  
  digitalWrite(slaveSelect, LOW); // take the chip select low to select the device:
  SPI.transfer(dataToSend); // send the device the register you want to read:
  while(bytesToRead > 0){
    delayMicroseconds(USDELAY);
    bfr[i] = SPI.transfer(0x00);
    i++;
    bytesToRead--;
  }
  digitalWrite(slaveSelect, HIGH);  // take the chip select high to de-select:
}




void writeRegister(byte slaveSelect, byte thisRegister, byte thisValue) {
  byte dataToSend = thisRegister | WRITE; // now combine the register address and the command into one byte
  digitalWrite(slaveSelect, LOW); // take the chip select low to select the device:
  SPI.transfer(dataToSend); //Send register location
  delayMicroseconds(USDELAY); // delay needed for communicating with PIC
  SPI.transfer(thisValue);  //Send value to record into register
  digitalWrite(slaveSelect, HIGH); // take the chip select high to de-select:
}
