#include <SPI.h>
#include <Wire.h>
#include <Ticker.h>
#include <U8g2lib.h>
#include <RadioLib.h>

#define OLED_SDA                17
#define OLED_SCL                18
#define OLED_RST                21

#define RADIO_SCLK_PIN          9
#define RADIO_MISO_PIN          11
#define RADIO_MOSI_PIN          10
#define RADIO_CS_PIN            8
#define RADIO_DIO1_PIN          14
#define RADIO_RST_PIN           12
#define RADIO_BUSY_PIN          13

#define DEFAULT_FREQUENCY       912
#define MAX_RADIO_OUTPUT_POWER  22
#define MIN_SPREADING_FACTOR		5
#define MAX_SPREADING_FACTOR		12
#define MAX_CODING_RATE				  8
#define RADIO_BANDWIDTH				  500

#define BOARD_LED               35
#define LED_ON                  HIGH

#define PACKET_LENGTH 32
#define VIBRATION_SENSOR_PIN 46
#define MY_ID 1

SX1262 radio = NULL;
U8G2_SSD1306_128X64_NONAME_F_HW_I2C *u8g2 = nullptr;
Ticker ledTicker;

uint8_t message[PACKET_LENGTH];

uint8_t spreadingFactor = MIN_SPREADING_FACTOR;
uint8_t codingRate = MAX_CODING_RATE;
float bandwidth = RADIO_BANDWIDTH;
int8_t outputPower = MAX_RADIO_OUTPUT_POWER;

bool vibrationSensed = false;


void initBoard()
{
    SPI.begin(RADIO_SCLK_PIN, RADIO_MISO_PIN, RADIO_MOSI_PIN);
    Wire.begin(OLED_SDA, OLED_SCL);
    Serial.begin(115200);
    delay(2000);

    pinMode(BOARD_LED, OUTPUT);
    ledTicker.attach_ms(350, []() {
        static bool level;
        digitalWrite(BOARD_LED, level);
        level = !level;
    });

    #if OLED_RST
    pinMode(OLED_RST, OUTPUT);
    
    digitalWrite(OLED_RST, HIGH);
    delay(50);

    digitalWrite(OLED_RST, LOW);
    delay(200);

    digitalWrite(OLED_RST, HIGH);
    delay(50);    
    #endif

    delay(1000);

    Wire.beginTransmission(0x3C);
    if (Wire.endTransmission() == 0) {
        u8g2 = new U8G2_SSD1306_128X64_NONAME_F_HW_I2C(U8G2_R0, OLED_RST);
        u8g2->begin();
        u8g2->clearBuffer();
        u8g2->setFlipMode(0);
        u8g2->setFontMode(1); // Transparent
        u8g2->setDrawColor(1);
        u8g2->setFontDirection(0);
        u8g2->setFont(u8g2_font_t0_11_t_all);

        u8g2->drawStr(0, 10, "TUMO");
        u8g2->drawStr(0, 30, "Vibration Alarm");
        u8g2->sendBuffer();
        delay(2000);
    }
}

void debugOutput(String lineOne,
                 String lineTwo = "",
                 String lineThree = "",
                 String lineFour = "",
                 String lineFive = "",
                 String lineSix = "")
{
  if (u8g2)
  {
    u8g2->setFont(u8g2_font_6x10_tf);
    u8g2->clearBuffer();
    u8g2->drawStr(0, 10, lineOne.c_str());
    u8g2->drawStr(0, 20, lineTwo.c_str());
    u8g2->drawStr(0, 30, lineThree.c_str());
    u8g2->drawStr(0, 40, lineFour.c_str());
    u8g2->drawStr(0, 50, lineFive.c_str());
    u8g2->drawStr(0, 60, lineSix.c_str());
    u8g2->sendBuffer();
  }
}

#if defined(ESP8266) || defined(ESP32)
  ICACHE_RAM_ATTR
#endif
void setVibrationSensed(void)
{
  vibrationSensed = true;
}


void setupRadio()
{
  radio = new Module(RADIO_CS_PIN,
                     RADIO_DIO1_PIN,
                     RADIO_RST_PIN,
                     RADIO_BUSY_PIN);

  int state = radio.begin();
  if (state == RADIOLIB_ERR_NONE)
  {
    debugOutput("Radio up.");
  }
  else
  {
    debugOutput("Failed!", "Radio not online.");
    while (true)
      ;
  }

  radio.implicitHeader(PACKET_LENGTH);

  if (radio.setFrequency(DEFAULT_FREQUENCY) != RADIOLIB_ERR_NONE)
  {
    debugOutput("Failed!", "Freq. not set.");
    while (true)
      ;
  }

  if (radio.setOutputPower(outputPower) != RADIOLIB_ERR_NONE)
  {
    debugOutput("Failed!", "Invalid power level.");
    while (true)
      ;
  }

  // set spreading factor
  if (radio.setSpreadingFactor(spreadingFactor) != RADIOLIB_ERR_NONE) {
      debugOutput("Failed!", "Bad spreading factor.");
      while (true);
  }

  if (radio.setCodingRate(codingRate) != RADIOLIB_ERR_NONE) {
      debugOutput("Failed!", "Bad coding rate.");
      while (true);
  }

  if (radio.setBandwidth(bandwidth) != RADIOLIB_ERR_NONE) {
    debugOutput("Failed!", "Bad bandwidth.");
    while (true);
  }
}


void setup()
{
  initBoard();

  // When the power is turned on, a delay is required.
  delay(1500);

  for (size_t i = 0; i < PACKET_LENGTH; i++)
  {
    message[i] = 0xaa;
  }

  message[0] = MY_ID;
  

  debugOutput("Starting up.", "Will bring up radio.");
  delay(1000);

  setupRadio();

  pinMode(VIBRATION_SENSOR_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(VIBRATION_SENSOR_PIN),
                  setVibrationSensed,
                  CHANGE);
}


void txMessage(){
  int status = radio.transmit(message, PACKET_LENGTH);
  radio.finishTransmit();
}


void loop()
{
  if (vibrationSensed) 
  {
    vibrationSensed = false;
    
    txMessage();

    debugOutput("vibration sensed");
    delay(400);
    debugOutput("");
  }
}






