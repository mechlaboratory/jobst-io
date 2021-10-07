/*

 */

#include <SPI.h>
#include <WiFi.h>
#include <WiFiUdp.h>

#define MSG_LEN 150

const char* ssid     = "CIAsurveillancevan#53";
const char* password = "illuminati";

char buffrik[MSG_LEN] = {0};

char packetBuffer[255]; //buffer to hold incoming packet
char AckString[] = "acknowledged"; 
uint8_t ReplyBuffer[MSG_LEN];  
unsigned int localPort = 2390;      // local port to listen on

WiFiUDP Udp;

void setup()
{

    for(int i = 0; i<=strlen(AckString); i++){
      ReplyBuffer[i] = byte(AckString[i]);
    }
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
    
    Udp.begin(localPort);

}

int value = 0;

void loop(){
  // if there's data available, read a packet
  int packetSize = Udp.parsePacket();
  if (packetSize) {
//    Serial.print("Received packet of size ");
//    Serial.println(packetSize);
//    Serial.print("From ");
    IPAddress remoteIp = Udp.remoteIP();
//    Serial.print(remoteIp);
//    Serial.print(", port ");
//    Serial.println(Udp.remotePort());
    // read the packet into packetBufffer
    int len = Udp.read(packetBuffer, 150);
    if (len > 0) {
      packetBuffer[len] = 0;
    }
//    Serial.println("Contents:");
//    Serial.println(packetBuffer);
    
    for(int i = 0; i<MSG_LEN;i++){
      ReplyBuffer[i] = byte(packetBuffer[i]); 
    }
    Serial.println(ReplyBuffer[148]);
    // send a reply, to the IP address and port that sent us the packet we received
    Udp.beginPacket(Udp.remoteIP(), Udp.remotePort());
    Udp.write(ReplyBuffer, MSG_LEN);
    Udp.endPacket();
  }
}
