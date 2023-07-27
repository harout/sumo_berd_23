import controlP5.*;
import java.util.*;
import processing.serial.*;
import java.nio.charset.StandardCharsets;


static final int PACKET_LENGTH = 32;
static final byte PREFIX_BYTE = 0x00;
static final byte SUFFIX_BYTE = (byte) 0xff;
static final int NUM_PREFIX_SUFFIX_BYTES = 3;
static final int SEND_TEXT_MESSAGE_COMMAND = 0x03;

static final int SERIAL_PORT_BAUD_RATE = 115200;

static final int CELL_SIZE = 10;

Serial serialPort = null;

byte[] relayedMessageBytes;


void setup() {
  size(50, 50);
  background(0);
  
  String serialDevPath = null;
  for (String path : Serial.list())
  {
    if (path.contains("SLAB"))
    {
      serialDevPath = path;
      break;
    }
  }
  
  
  if (serialDevPath == null) {
    List<String> serialPaths = Arrays.asList(Serial.list());
    Collections.reverse(serialPaths);
    for (String path : serialPaths)
    {
      if (path.contains("usbserial"))
      {
        serialDevPath = path;
        break;
      }
    }
  }
  
  serialPort = new Serial(this, serialDevPath, SERIAL_PORT_BAUD_RATE);
  
  PImage img = loadImage("army.jpeg");
  image(img, 0, 0);
}

public void setPixel(byte[] buffer,
                     int pixelNumber,
                     int r,
                     int g,
                     int b)
{
  // prefix length + command type length + start x length + start y length 
  int messageOffset = NUM_PREFIX_SUFFIX_BYTES + 1 + 2;
  int pixelOffset = pixelNumber * 3;
  int offset = messageOffset + pixelOffset;
  
  buffer[offset] = (byte) r;
  buffer[offset + 1] = (byte) g;
  buffer[offset + 2] = (byte) b;
}


public void setStartingPoint(byte[] buffer, int x, int y)
{
  // prefix length + command type length
  int offset = NUM_PREFIX_SUFFIX_BYTES + 1;
  buffer[offset] = (byte) x;
  buffer[offset + 1] = (byte) y;
}

public void canvasToBuffer(int sx, int sy)
{
  int messageLength = PACKET_LENGTH + (NUM_PREFIX_SUFFIX_BYTES * 2) + 1;
  byte[] m = new byte[messageLength];
  for (int i = 0; i < NUM_PREFIX_SUFFIX_BYTES; i++)
  {
    m[i] = PREFIX_BYTE;
    m[messageLength - i - 1] = SUFFIX_BYTE;
  }
  m[NUM_PREFIX_SUFFIX_BYTES] = SEND_TEXT_MESSAGE_COMMAND;
  
  setStartingPoint(m, sx, sy);
  for (int i = 0; i < 10; i++) {
    color c = get(sx + i, sy);
    setPixel(m, i, (int) red(c) & 0xff, (int) green(c) & 0xff, (int) blue(c) & 0xff);
    //setPixel(m, i, 255, 255, 255);
  }
  
  for (int i = 0; i < messageLength; i++)
  {
    int val = (int) m[i];
    val = val & 0xff;
    print(val + " ");
  }
  println();
  serialPort.write(m); 
}

public void sendMessage()
{
  for (int x = 0; x < 50; x += 10) {
    for (int y = 0; y < 50; y++){
       canvasToBuffer(x, y);
       delay(100);
    }
  }
}

void draw() {
  sendMessage();
  delay(1000);
}
