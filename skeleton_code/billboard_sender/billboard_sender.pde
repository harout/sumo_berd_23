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
  size(500, 500);
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


public void sendMessage()
{
  int messageLength = PACKET_LENGTH + (NUM_PREFIX_SUFFIX_BYTES * 2) + 1;
  byte[] m = new byte[messageLength];
  for (int i = 0; i < NUM_PREFIX_SUFFIX_BYTES; i++)
  {
    m[i] = PREFIX_BYTE;
    m[messageLength - i - 1] = SUFFIX_BYTE;
  }
  m[NUM_PREFIX_SUFFIX_BYTES] = SEND_TEXT_MESSAGE_COMMAND;
  
  setStartingPoint(m, 5, 5);
  setPixel(m, 0, 255, 0, 0);
  setPixel(m, 1, 0, 0, 255);
  setPixel(m, 2, 242, 168, 0);

  serialPort.write(m); 
}

void draw() {
  sendMessage();
  delay(500);
}
