/*
 WiFi Web Server LED Blink

 A simple web server that lets you blink an LED via the web.
 This sketch will print the IP address of your WiFi Shield (once connected)
 to the Serial monitor. From there, you can open that address in a web browser
 to turn on and off the LED on pin 5.

 If the IP address of your shield is yourAddress:
 http://yourAddress/H turns the LED on
 http://yourAddress/L turns it off

 This example is written for a network using WPA encryption. For
 WEP or WPA, change the Wifi.begin() call accordingly.

 Circuit:
 * WiFi shield attached
 * LED attached to pin 5

 created for arduino 25 Nov 2012
 by Tom Igoe

ported for sparkfun esp32 
31.01.2017 by Jan Hendrik Berlin
 
 */

#include <WiFi.h>

#define MSG_LEN 150

//const char* ssid     = "CIAsurveillancevan#53";
//const char* password = "illuminati";

const char* ssid     = "datalogger";
const char* password = "logger147741";


byte buffrik[MSG_LEN+1] = {0};
char buffrikString[MSG_LEN+1] = "";


WiFiServer server(80);

void setup()
{
    buffrikString[MSG_LEN] = '\0';
    Serial.begin(115200);
    pinMode(5, OUTPUT);      // set the LED pin mode

    delay(10);

    // We start by connecting to a WiFi network

    Serial.println();
    Serial.println();
    Serial.print("Connecting to ");
    Serial.println(ssid);

    WiFi.begin(ssid, password);

    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }

    Serial.println("");
    Serial.println("WiFi connected.");
    Serial.println("IP address: ");
    Serial.println(WiFi.localIP());
    
    server.begin();

}

int value = 0;

void loop(){
 WiFiClient client = server.available();   // listen for incoming clients

  if (client) {                             // if you get a client,
    Serial.println("New Client.");          // print a message out the serial port
    String currentLine = "";                // make a String to hold incoming data from the client
    while (client.connected()) {            // loop while the client's connected
      if (client.available() >= MSG_LEN){   // if there's bytes to read from the client,
        //Serial.println(client.available());
        int k = 0;
        client.read(buffrik, MSG_LEN);
//        Serial.write(buffrik, );
        for(k = 0; k<MSG_LEN; k++){
          buffrikString[k] = buffrik[k];
        }
        client.print(buffrikString);
//        for(k = 0; k<MSG_LEN; k++){
//          //char c = client.read();
//          client.write(buffrik[k]); 
//          //Serial.print(buffrik[k], DEC);                   // read a byte, then
//          //Serial.print(c, DEC);                  // print it out the serial monitor
//          //Serial.print(' ');
//          //client.print(c);  
//        }
        //Serial.println(0x13); //CR
      }
    }
    // close the connection:
    client.stop();
    Serial.println("Client Disconnected.");
  }
}

void syncWifiStream(void){
  byte garbage;
  byte garbageBuffer[MSG_LEN+1];
  unsigned int i = 0;

  while(1){
      do{
        //Serial.readBytes(garbage,1);
        garbage = Serial.read();
        garbageBuffer[0] = garbage;
      }while(garbageBuffer[0] != 0xAA);
      
      for(i = 1; i<MSG_LEN; i++){
        //Serial.readBytes(garbage,1);
        garbage = Serial.read();
        garbageBuffer[i] = garbage;
      }
          
      if(garbageBuffer[0] == 0xAA && garbageBuffer[MSG_LEN-1] == 0xCC && garbageBuffer[MSG_LEN] == 0xAA){
        for(i = 1; i < MSG_LEN-1; i++){
          //Serial.readBytes(garbage,1);
          garbage = Serial.read();
        }
        break;
      }  
    }
}
