#include <Arduino.h>
#include <Adafruit_NeoPixel.h>
#ifdef __AVR__
  #include <avr/power.h>
#endif

#define POTENTIOMETER_IN A0
#define VIB_SENSOR_PIN 7
#define VIB_INDICATOR_PIN 0
#define NEOPIXEL_PIN 3

//#define PWM_OUT 3
//#define PWM_IN 16
//#define ANALOG_OUT_MAX_VALUE 255
#define ANALOG_IN_MAX_VALUE 1023.0
#define MAX_LED_COLOR 65535.0

bool didVibrate = false;
Adafruit_NeoPixel pixel = Adafruit_NeoPixel(1, NEOPIXEL_PIN, NEO_RGB + NEO_KHZ800);


void vibrated();

void setup() {
  pinMode(POTENTIOMETER_IN, INPUT);
  pinMode(VIB_SENSOR_PIN, INPUT_PULLUP);
  
  pinMode(A2, OUTPUT);
  pinMode(VIB_INDICATOR_PIN, OUTPUT);

  pixel.begin();
  pixel.setBrightness(200);
  uint32_t rgbcolor = pixel.ColorHSV(48000);
  pixel.setPixelColor(0, rgbcolor);
  pixel.show();  

  attachInterrupt(digitalPinToInterrupt(VIB_SENSOR_PIN), vibrated, CHANGE);

  Serial.begin(9600);
}

void loop() {
  if (Serial.available()) {
    byte b = Serial.read();
    int ledColor = (int) ((b / 100.0) * MAX_LED_COLOR);
    
    uint32_t rgbcolor = pixel.ColorHSV(ledColor);
    pixel.setPixelColor(0, rgbcolor);
    pixel.show();
  }

  // ??????????
  
  int percentage = 100 * (potentiometerValue / ANALOG_IN_MAX_VALUE);
  Serial.println(percentage);
  delay(10);

  digitalWrite(VIB_INDICATOR_PIN, didVibrate);
  didVibrate = false;
}

void vibrated()
{
  didVibrate = true;
}