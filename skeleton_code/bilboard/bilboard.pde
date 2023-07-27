import controlP5.*;
import java.util.*;
import processing.serial.*;
import java.nio.charset.StandardCharsets;


static final int PACKET_LENGTH = 32;
static final byte PREFIX_BYTE = 0x00;
static final byte SUFFIX_BYTE = (byte) 0xff;
static final int NUM_PREFIX_SUFFIX_BYTES = 3;

static final int INCOMING_RECEIVE_RELAYED_MESSAGE_COMMAND = 0x01;
static final int SERIAL_PORT_BAUD_RATE = 115200;

static final int NUM_CELL_DIVISIONS = 20;

String serialPortPath = null;
Serial serialPort = null;

byte[] relayedMessageBytes;


void setup() {
  size(800, 800);
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
    for (String path : Serial.list())
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


void draw() {
  checkIncomingMessage();
}


public void checkIncomingMessage()
{
  int messageLength = PACKET_LENGTH + (NUM_PREFIX_SUFFIX_BYTES * 2) + 1;
  if (serialPort == null || serialPort.available() < messageLength)
  {
    return;
  }
  
  byte[] m = serialPort.readBytes(messageLength);
  
  for (int i = 0; i < NUM_PREFIX_SUFFIX_BYTES; i++)
  {
    if (m[i] != PREFIX_BYTE || m[messageLength - 1 - i] != SUFFIX_BYTE)
    {
      return;
    }
  }
  
  int offset = NUM_PREFIX_SUFFIX_BYTES;
  int command = m[offset++];
  if (command == INCOMING_RECEIVE_RELAYED_MESSAGE_COMMAND)
  {
    byte[] message = new byte[PACKET_LENGTH];
    System.arraycopy(m, offset, message, 0, PACKET_LENGTH);
    
    int row = message[0];
    int column = message[1];
    
    int cellWidth = (width / NUM_CELL_DIVISIONS);
    int cellHeight = (height / NUM_CELL_DIVISIONS);
    int rectX = column * cellWidth;
    int rectY = row * cellHeight;
    
    rectMode(CORNER);
    noStroke();
    
    for (int i = 0; i < (PACKET_LENGTH - 2) / 3; i++)
    {
      int r = message[2 + i * 3] & 0xff;
      int g = message[2 + i * 3 + 1] & 0xff;
      int b = message[2 + i * 3 + 2] & 0xff;
      
      fill(r, g, b);
      rect(rectX, rectY, cellWidth, cellHeight);
      
      rectX += cellWidth;
    }
  }
}
