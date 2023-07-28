import java.util.*;

import processing.serial.*;
import processing.sound.*;

static final int PACKET_LENGTH = 32;
static final byte PREFIX_BYTE = 0x00;
static final byte SUFFIX_BYTE = (byte) 0xff;
static final int NUM_PREFIX_SUFFIX_BYTES = 3;

static final int INCOMING_RECEIVE_RELAYED_MESSAGE_COMMAND = 0x01;
static final int SERIAL_PORT_BAUD_RATE = 115200;

static final int NUM_ZONES = 2;

String serialPortPath = null;
Serial serialPort = null;

byte[] relayedMessageBytes;
long[] lastAlarmed = {0, 0};


SoundFile alarmSound;

void setup() {
  colorMode(RGB, 255);
  size(500, 500);
  background(0);
  
  alarmSound = new SoundFile(this, "alert.mp3");
  
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

void drawAlarmStatus()
{
  int drawHeight = height / NUM_ZONES;
  
  for (int i = 0; i < NUM_ZONES; i++) 
  {
    int offsetY = drawHeight * i;
    long timeSinceAlarm = System.currentTimeMillis() - lastAlarmed[i];
    if (timeSinceAlarm <= 5000)
    {
      fill(255, 0, 0);
    }
    else
    {
      fill(0, 255, 0);  
    }
    
    noStroke();
    rectMode(CORNER);
    rect(0, offsetY, width, drawHeight);
  }
}

void draw() {
  background(0);
  checkIncomingMessage();
  drawAlarmStatus();
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
    
    int senderId = message[0];
    int messageType = ((int) message[1]) & 0xFF;
    if (messageType != 0xAA) 
    {
      return; 
    }
    
    println("alarm " + senderId);
    
    alarmSound.play();
    lastAlarmed[senderId - 1] = System.currentTimeMillis();
  }
}
