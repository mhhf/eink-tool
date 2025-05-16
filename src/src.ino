/* Includes ------------------------------------------------------------------*/
#include "DEV_Config.h"

#include "Web_App.h"
#include <stdlib.h>
#include <Wire.h>
#include <WiFi.h>

unsigned long previousMillis = 0;
unsigned long interval = 30000;

/* Entry point ----------------------------------------------------------------*/
void setup()
{
    // Serial port initialization
    Serial.begin(115200);
    delay(10);
    // SPI initialization
    DEV_ModuleInit();

    DEV_TestLED();
    Web_Init();
    
    // Initialization is complete
    Serial.println("\r\nOk!\r\n");
}

/* The main loop -------------------------------------------------------------*/
void loop()
{
   Web_Listen();
   unsigned long currentMillis = millis();
   if ((WiFi.status() != WL_CONNECTED) && (currentMillis - previousMillis >=interval)) {
       Serial.print(millis());
       Serial.println("Reconnecting to WiFi...");
       WiFi.disconnect();
       WiFi.reconnect();
       previousMillis = currentMillis;
   }
}
