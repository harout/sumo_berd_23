#define LATCH_PIN 3
#define CLOCK_PIN 4
#define DATA_PIN 2
#define NUM_PATTERNS 4
#define NUM_BITS 8

uint8_t current = 0;

byte patterns[NUM_PATTERNS][8] = {  
   {1, 
      0, 
    0, 
      0, 
    0, 
      0, 
    0, 
      1},

   {0,
      1, 
    0, 
      0, 
    0, 
      0, 
    1, 
      0},

  {0,
      0, 
    0, 
      1, 
    1, 
      0, 
    0, 
      0},

  {0,
      0, 
    1, 
      0, 
    0, 
      1, 
    0, 
      0}              
};

void setup() {
  Serial.begin(9600);

  pinMode(LATCH_PIN, OUTPUT);
  pinMode(CLOCK_PIN, OUTPUT);
  pinMode(DATA_PIN, OUTPUT);
}

void loop() {
  digitalWrite(LATCH_PIN, LOW);
  
  uint8_t data = 0;
  for (size_t i = 0; i < NUM_BITS; i++)
  {
    data = (data << 1) | patterns[current][i];
  }
  
  shiftOut(DATA_PIN, CLOCK_PIN, MSBFIRST, data);
  
  // Setting the latch pin low above signaled to the
  // shift register that we were loading new data. 
  // How do we signal that we are done?
  // ??????

  // How do we advance the animation one frame 
  // and loop back to the start?
  // ?????
  // ?????


  delay(200);
}