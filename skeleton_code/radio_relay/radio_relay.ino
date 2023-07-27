#include <Arduino.h>
#include <RadioLib.h>
#include <SPI.h>
#include <Wire.h>
#include <Ticker.h>
#include <U8g2lib.h>


#define BUILD_FOR                   "heltec"
#define OLED_SDA                     17
#define OLED_SCL                     18
#define OLED_RST                    21

#define RADIO_SCLK_PIN              9
#define RADIO_MISO_PIN              11
#define RADIO_MOSI_PIN              10
#define RADIO_CS_PIN                8
#define RADIO_DIO1_PIN              14
#define RADIO_RST_PIN               12
#define RADIO_BUSY_PIN              13

#define DEFAULT_FREQUENCY			912
#define MAX_RADIO_OUTPUT_POWER		22
#define MIN_SPREADING_FACTOR		5
#define MAX_SPREADING_FACTOR		12
#define MAX_CODING_RATE				8
#define RADIO_BANDWIDTH				500

#define BOARD_LED                   35
#define LED_ON                      HIGH

#define BUTTON_PIN                  0


#define PACKET_LENGTH 32
#define PACKETS_PER_BURST 100

#define PREFIX_BYTE 0x00
#define SUFFIX_BYTE 0xff
#define NUM_SENTINEL_BYTES 3

#define SET_RADIO_PARAMETERS_COMMAND 0x01
#define SEND_MESSAGE_BURST_COMMAND 0x02
#define SEND_TEXT_MESSAGE_COMMAND 0x03

#define RECEIVE_RELAYED_MESSAGE 0x01
#define RECEIVE_BURST_STATS 0x02

U8G2_SSD1306_128X64_NONAME_F_HW_I2C *u8g2 = nullptr;
Ticker ledTicker;


SX1262 radio = NULL;


// flag to indicate that a packet was sent or received
volatile bool operationDone = false;

// save transmission states between loops
int transmissionState = RADIOLIB_ERR_NONE;

// Is this module currently the transmitter or a receiver.
bool wasTransmitting = false;

uint8_t burstMessage[PACKET_LENGTH];

uint8_t spreadingFactorIndex = 0;
uint8_t spreadingFactor = MIN_SPREADING_FACTOR;
uint8_t codingRate = MAX_CODING_RATE;
float bandwidth = RADIO_BANDWIDTH;
int8_t outputPower = MAX_RADIO_OUTPUT_POWER;

double averageRSSI = 0.0;
double averageSNR = 0.0;
uint32_t packetsReceived = 0;

unsigned long lastTxEnded = 0;
uint64_t bps = 0;

unsigned long displayRxStatsAfterTime = 0;


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
      u8g2->drawStr(0, 30, "Radio Relay");
      u8g2->drawUTF8(0, 50, "Յարութ");
      u8g2->sendBuffer();
      //u8g2->setFont(u8g2_font_fur11_tf);
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



void displaySettings()
{
  String pwr = ("TX Powwer: " + std::to_string(outputPower)).c_str();

  String sf = "Spreading Factor: ";
  sf += std::to_string(spreadingFactor).c_str();

  String cr = "Coding Rate: ";
  cr += std::to_string(codingRate).c_str();

  String bw = "Bandwidth: ";
  bw += std::to_string(bandwidth).c_str();

  String freq = "Frequency: ";
  freq += std::to_string(DEFAULT_FREQUENCY).c_str();

  debugOutput(pwr, sf, cr, bw, freq);
}

// this function is called when a complete packet
// is transmitted or received by the module
// IMPORTANT: this function MUST be 'void' type
//            and MUST NOT have any arguments!
#if defined(ESP8266) || defined(ESP32)
  ICACHE_RAM_ATTR
#endif
void setFlag(void) {
  // we sent or received  packet, set the flag
  operationDone = true;
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

  // set the function that will be called
  // when packet transmission is finished
  radio.setDio1Action(setFlag);

  radio.startReceive(); 
}


void setup()
{
  // put your setup code here, to run once:
  // Serial.begin(9600);
  initBoard();

  // When the power is turned on, a delay is required.
  delay(1500);


  pinMode(BUTTON_PIN, INPUT);

  for (size_t i = 0; i < PACKET_LENGTH; i++)
  {
    burstMessage[i] = 0xff;
  }

  debugOutput("Starting up.", "Will bring up radio.");
  delay(1000);

  setupRadio();
}


void txMessage(uint8_t* buffer){
  int status = radio.transmit(buffer, PACKET_LENGTH);
  radio.finishTransmit();

  // The TX will trigger the operationDone interrupt,
  // and we would like to not have that appear to be 
  // a RX done event.
  operationDone = false;

  radio.startReceive();  
}


void doTxBurst()
{
  wasTransmitting = true;
  displaySettings();
  //fillScreen();

  unsigned long start = millis();
  for (int i = 0; i < PACKETS_PER_BURST; i++)
  {
    int status = radio.transmit(burstMessage, PACKET_LENGTH);
    radio.finishTransmit();

    if (status != RADIOLIB_ERR_NONE)
    {
      debugOutput("tx error");
    }
  }

  unsigned long fullTxTime = millis() - start;
  bps = ((float) PACKET_LENGTH * 8 * PACKETS_PER_BURST) / (fullTxTime / 1000.0);
  lastTxEnded = millis();
  
  // The TX will trigger the operationDone interrupt,
  // and we would like to not have that appear to be 
  // a RX done event.
  operationDone = false;

  radio.startReceive();
}


void handleSetRadioParametersCommand(uint8_t* b)
{
  size_t offset = 0;
  uint16_t bwWholePortion = (b[offset++] << 8) | b[offset++];
  uint16_t bwFractionalPortion = (b[offset++] << 8) | b[offset++];
  float desiredBandwidth = bwWholePortion + ((float) bwFractionalPortion / 1000.0);

  uint8_t desiredSpreadingFactor = b[offset++];
  uint8_t desiredCodingRate = b[offset++];

  int8_t desiredOutputPower = b[offset++];
  if (desiredOutputPower > MAX_RADIO_OUTPUT_POWER)
  {
    debugOutput("Failed!", "Invalid power level.");
    return;
  }

  if (radio.setBandwidth(desiredBandwidth) != RADIOLIB_ERR_NONE) {
    debugOutput("Failed!", "Bad bandwidth.");
    return;
  }
  bandwidth = desiredBandwidth;

  if (radio.setSpreadingFactor(desiredSpreadingFactor) != RADIOLIB_ERR_NONE) {
      debugOutput("Failed!", "Bad spreading factor.");
      return;
  }
  spreadingFactor = desiredSpreadingFactor;

  if (radio.setCodingRate(desiredCodingRate) != RADIOLIB_ERR_NONE) {
      debugOutput("Failed!", "Bad coding rate.");
      return;
  }
  codingRate = desiredCodingRate;

  if (radio.setOutputPower(desiredOutputPower) != RADIOLIB_ERR_NONE)
  {
    debugOutput("Failed!", "Invalid power level.");
    return;
  }
  outputPower = desiredOutputPower;
  displaySettings();
}


void checkCommands()
{
  // The packet format is <leading sentinel bytes> <command type> <packet> <trailing sentinel bytes>
  const int messageLength = NUM_SENTINEL_BYTES + 1 + PACKET_LENGTH + NUM_SENTINEL_BYTES;

  if (Serial.available() < messageLength)
  {
    return;
  }

  uint8_t b[messageLength];
  if (Serial.readBytes(b, messageLength) != messageLength)
  {
    Serial.flush();
    return;
  }

  for (int i = 0; i < NUM_SENTINEL_BYTES; i++)
  {
    if (b[i] != PREFIX_BYTE || b[messageLength - 1 - i] != SUFFIX_BYTE)
    {
      Serial.flush();
      return;
    }
  }

  int offset = NUM_SENTINEL_BYTES;

  uint8_t command = b[offset++];
  if (command == SET_RADIO_PARAMETERS_COMMAND)
  {
    handleSetRadioParametersCommand(&b[offset]);
    return;
  }
  else if (command == SEND_MESSAGE_BURST_COMMAND)
  {
    doTxBurst();
    return;
  }
  else if (command == SEND_TEXT_MESSAGE_COMMAND) 
  {
    displaySettings();
    txMessage(&b[offset]);
    //delay(1000);
    return;
  }
    
  debugOutput("Bad command.");
}

bool isBurstMessage(uint8_t* buffer)
{
  for (size_t i = 0; i < PACKET_LENGTH; i++)
  {
    if (buffer[i] != 0xff)
    {
      return false;
    }
  }

  return true;
}

void doRxWork()
{
  if (!operationDone)
  {
    return;
  }

  operationDone = false;

  uint8_t buffer[PACKET_LENGTH];
  int state = radio.readData(buffer, PACKET_LENGTH);
  uint8_t packetLength = radio.getPacketLength();
  
  if (state != RADIOLIB_ERR_NONE)
  {
    debugOutput("bad packet?");
    return;
  }

  if (packetLength != PACKET_LENGTH)
  {
    return;
  }

  if (isBurstMessage(buffer))
  {
    displayRxStatsAfterTime = millis() + 1000;
    packetsReceived += 1;
    averageRSSI = (averageRSSI * ((packetsReceived - 1.0) / packetsReceived)) + (radio.getRSSI() / packetsReceived);
    averageSNR = (averageSNR * ((packetsReceived - 1.0) / packetsReceived)) + (radio.getSNR() / packetsReceived);
    return;
  }

  
  for (size_t i = 0; i < NUM_SENTINEL_BYTES; i++)
  {
    Serial.write(PREFIX_BYTE);
  }

  Serial.write(RECEIVE_RELAYED_MESSAGE);
  Serial.write(buffer, PACKET_LENGTH);

  for (size_t i = 0; i < NUM_SENTINEL_BYTES; i++)
  {
    Serial.write(SUFFIX_BYTE);
  }

  debugOutput("relayed message");
}

void writeBurstStatsToSerial()
{
    for (size_t i = 0; i < NUM_SENTINEL_BYTES; i++)
    {
      Serial.write(PREFIX_BYTE);
    }

    Serial.write(RECEIVE_BURST_STATS);

    uint8_t b[PACKET_LENGTH];
    b[0] = (packetsReceived << 24);
    b[1] = (packetsReceived << 16);
    b[2] = (packetsReceived << 8);
    b[3] = packetsReceived;

    int16_t avrRSSIWhole = (int16_t) averageRSSI;
    int16_t avrRSSIFraction = (averageRSSI - ((int) averageRSSI)) * 1000;
    b[4] = (avrRSSIWhole << 8);
    b[5] = avrRSSIWhole;
    b[6] = (avrRSSIFraction << 8);
    b[7] = avrRSSIFraction;

    int16_t avrSNRWhole = (int16_t) averageSNR;
    int16_t avrSNRFraction = (averageSNR - ((int) averageSNR)) * 1000;
    b[8] = (avrSNRWhole << 8);
    b[9] = avrSNRWhole;
    b[10] = (avrSNRFraction << 8);
    b[11] = avrSNRFraction;

    Serial.write(b, PACKET_LENGTH);

    for (size_t i = 0; i < NUM_SENTINEL_BYTES; i++)
    {
      Serial.write(SUFFIX_BYTE);
    }
}

void displayRxStats()
{
  if (displayRxStatsAfterTime > millis())
  {
    return;
  }

  const int stringBufferLength = 32;
  char numPacketsBuf[stringBufferLength];
  snprintf(numPacketsBuf, sizeof(numPacketsBuf), "Packets Rcvd: %i", packetsReceived);

  char rssiBuf[stringBufferLength];
  snprintf(rssiBuf, sizeof(rssiBuf), "RSSI: %.2f dBm", averageRSSI);

  char snrBuf[stringBufferLength];
  snprintf(snrBuf, sizeof(snrBuf), "SNR: %.2f dB", averageSNR);

  debugOutput(numPacketsBuf, rssiBuf, snrBuf);

  displayRxStatsAfterTime = millis() + 1000;

  if (packetsReceived != 0)
  {
    writeBurstStatsToSerial();
  }
  
  packetsReceived = 0;
  averageRSSI = 0;
  averageSNR = 0;
}


void loop()
{
  checkCommands();
  doRxWork();
  displayRxStats();
}
