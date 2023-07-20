#include <Adafruit_NeoPixel.h>

#define NEOPIXEL_PIN 3
#define MAX_LED_COLOR 65535.0


Adafruit_NeoPixel pixel = Adafruit_NeoPixel(1, NEOPIXEL_PIN, NEO_RGB + NEO_KHZ800);
float pixelColor = 0.0;

void setup() {
  pixel.begin();
  pixel.setBrightness(200);
  uint32_t rgbcolor = pixel.ColorHSV(pixelColor);
  pixel.setPixelColor(0, rgbcolor);
  pixel.show();  

  Serial.begin(9600);
}

void loop() {
  uint32_t rgbcolor = pixel.ColorHSV(pixelColor);
  pixel.setPixelColor(0, rgbcolor);
  pixel.show();
  pixelColor += 2.0;
  if (pixelColor >= MAX_LED_COLOR) {
    pixelColor = 0.0;
  }
}
