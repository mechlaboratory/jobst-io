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

const char* ssid     = "CIAsurveillancevan#53";
const char* password = "illuminati";

//const char* ssid     = "datalogger";
//const char* password = "logger147741";

const char * host = "192.168.0.131";
const uint16_t port = 4000;


byte buffrik[MSG_LEN+1] = {0};
char buffrikString[MSG_LEN+1] = "";

WiFiClient client;

void setup()
{
    buffrikString[MSG_LEN] = '\0';
    Serial.begin(1000000);
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

}

int value = 0;

void loop(){
  if (!client.connect(host, port)) {
    Serial.println("Connection to host failed");
    Serial.println("Going to sleep now");
  }else{                         
    Serial.println("Connected to Server.");          // print a message out the serial port
    String currentLine = "";                // make a String to hold incoming data from the client
    while (client.connected()) {            // loop while the client's connected
      if (client.available() >= MSG_LEN){   // if there's bytes to read from the client,
        
        //Serial.println(client.available());
        int k = 0;
        client.read(buffrik, MSG_LEN);
        digitalWrite(5,LOW);
        //Serial.println("MSG read");
//        for(k = 0; k<MSG_LEN; k++){
//          buffrikString[k] = buffrik[k];
//          
//        }
        client.write(buffrik, MSG_LEN);
        //client.print(buffrikString);
        //client.flush();
        Serial.println(buffrik[MSG_LEN-2], DEC); //CR
        digitalWrite(5,HIGH);
      }//else{
//        Serial.print("Nemam byty voe! :");
//        Serial.println(client.available());
//        delay(200);
//      }
    }
    // close the connection:
    client.stop();
    Serial.println("Client Disconnected.");
  }
}
