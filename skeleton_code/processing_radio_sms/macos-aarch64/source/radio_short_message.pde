import controlP5.*;
import java.util.*;
import processing.serial.*;
import java.nio.charset.StandardCharsets;

enum RadioType{
  SX1280,
  SX1276
};
static final RadioType CURRENT_RADIO = RadioType.SX1276;

static final int PACKET_LENGTH = 32;
static final byte PREFIX_BYTE = 0x00;
static final byte SUFFIX_BYTE = (byte) 0xff;
static final int NUM_PREFIX_SUFFIX_BYTES = 3;

static final int SET_RADIO_PARAMETERS_COMMAND = 0x01;
static final int SEND_MESSAGE_BURST_COMMAND = 0x02;
static final int SEND_TEXT_MESSAGE_COMMAND = 0x03;

static final int INCOMING_RECEIVE_RELAYED_MESSAGE_COMMAND = 0x01;
static final int INCOMING_RECEIVE_BURST_STATS_COMMAND = 0x02;

static final String SELECT_SERIAL_PORT_LABEL = "";
static final int SERIAL_PORT_BAUD_RATE = 115200;


ControlP5 cp5;

PFont font;
ControlFont controlFont;

ScrollableList radioSelection;
ScrollableList serialPortSelection;
ScrollableList bandwidthSelection;
ScrollableList spreadingFactorSelection;
ScrollableList codingRateSelection;
ScrollableList powerLevelSelection;
Textfield textMessage;


String serialPortPath = null;
Serial serialPort = null;

String relayedMessage = "<No messages received>";
String statsSummary = "No burst received.";

float[] getBandwidthsForRadio(RadioType radio)
{
  if (radio == RadioType.SX1280)
  {
    return new float[] {203, 406, 812, 1625};
  }  
  
  return new float[] {7.8, 10.4, 15.6, 20.8, 31.25, 41.7, 62.5, 125.0, 250, 500};
}

int[] getSpreadingFactorsForRadio(RadioType radio)
{
  return new int[] {5, 6, 7, 8, 9, 10, 11, 12};
}

int[] getCodingRatesForRadio(RadioType radio)
{
  return new int[] {5, 6, 7, 8};  
}

int[] getPowerLevelsForRadio(RadioType radio)
{
  if (radio == RadioType.SX1280)
  {
    return new int[] {-18, -17, -16, -15, -14, -13, -12, -11, -10,
                        -9, -8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3};
  } 
  
  return new int[] {-9, -8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5,
                     6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22};
}

byte[] stringToBytes(String s, int maxBytes)
{
  s = s.substring(0, Math.min(s.length(), maxBytes));
  
  byte[] stringBytes = s.getBytes(StandardCharsets.UTF_8);
  while (stringBytes.length > maxBytes) 
  {
    s = s.substring(0, s.length() - 1);
    stringBytes = s.getBytes(StandardCharsets.UTF_8);
  }
  
  return stringBytes;
}

byte[] floatToByteArray(float value) {
  int wholePortion = (int) Math.floor((double) value);
  int fractionalPortion = (int) ((value - wholePortion) * 1000);
  println(fractionalPortion);
  return new byte[] 
    {
      (byte) (wholePortion >> 8), 
      (byte) (wholePortion), 
      (byte) (fractionalPortion >> 8), 
      (byte) (fractionalPortion) 
    };
}

void setup() {
  size(340, 600);
  
  CallbackListener toFront = new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      theEvent.getController().bringToFront();
      // ((ScrollableList)theEvent.getController()).open();
    }
  };
  
  
  font = loadFont("HelveticaNeue-14.vlw");
  controlFont = new ControlFont(font,14);
  textFont(font);
  
  cp5 = new ControlP5(this);  
       
  //
  // Serial Port Selection
  // 
  serialPortSelection = cp5.addScrollableList("sp")
     .setPosition(20, 60)
     .setSize(300, 400)
     .setBarHeight(25)
     .setItemHeight(25)
     .onEnter(toFront)
     .close();
  
  serialPortSelection.addItem("", "");
  for (String path : Serial.list())
  {
    serialPortSelection.addItem(path, path);
  }
  
  setScrollableListFont(serialPortSelection);
  serialPortSelection.setValue(0);
  
  //
  // Bandwidth Selection
  //
  bandwidthSelection = cp5.addScrollableList("bw")
     .setPosition(20, 115)
     .setSize(300, 100)
     .setBarHeight(25)
     .setItemHeight(25)     
     .onEnter(toFront)
     .close();
  
  float[] bandwidths = getBandwidthsForRadio(CURRENT_RADIO);
  for (float bw : bandwidths)
  {
    bandwidthSelection.addItem(String.valueOf(bw), bw);  
  }
 
  setScrollableListFont(bandwidthSelection);
  bandwidthSelection.setValue(bandwidths.length - 1);
  
  //
  // Spreading Factor Selection
  //
  spreadingFactorSelection = cp5.addScrollableList("sf")
     .setPosition(20, 170)
     .setSize(300, 100)
     .setBarHeight(25)
     .setItemHeight(25)     
     .onEnter(toFront)
     .close();
     
  int[] spreadingFactors = getSpreadingFactorsForRadio(CURRENT_RADIO);
  for (int sf : spreadingFactors)
  {
    spreadingFactorSelection.addItem(String.valueOf(sf), sf);
  }
  
  setScrollableListFont(spreadingFactorSelection);
  spreadingFactorSelection.setValue(0);  
  
  //
  // Coding Rate Selection
  //
  codingRateSelection = cp5.addScrollableList("cr")
     .setPosition(20, 225)
     .setSize(300, 100)
     .setBarHeight(25)
     .setItemHeight(25)     
     .onEnter(toFront)
     .close();
     
  int[] codingRates = getCodingRatesForRadio(CURRENT_RADIO);
  for (int cr : codingRates)
  {
    codingRateSelection.addItem(String.valueOf(cr), cr);
  }
  
  setScrollableListFont(codingRateSelection);
  codingRateSelection.setValue(0);
  
  //
  // Power Level Selection
  //
  powerLevelSelection = cp5.addScrollableList("pl")
     .setPosition(20, 280)
     .setSize(300, 100)
     .setBarHeight(25)
     .setItemHeight(25)     
     .onEnter(toFront)
     .close();
     
  int[] powerLevels = getPowerLevelsForRadio(CURRENT_RADIO);
  for (int pl : powerLevels)
  {
    powerLevelSelection.addItem(String.valueOf(pl), pl);
  }
  
  setScrollableListFont(powerLevelSelection);
  powerLevelSelection.setValue(powerLevels.length - 1);
   
   //
   // Text Message
   //
   textMessage = cp5.addTextfield("textMessage")
     .setPosition(20, 335)
     .setSize(300, 25);
   textMessage.getValueLabel()
     .setFont(controlFont)
     .toUpperCase(false)
     .setSize(14);
   textMessage.getCaptionLabel().setText("");
   
   //
   // Send Burst
   //
   Button b = cp5.addButton("Send Burst")   
     .setPosition(20,390)   
     .setSize(300,25)   
     .setValue(0)   
     .activateBy(ControlP5.RELEASE);
   b.getCaptionLabel()
   .setFont(controlFont)
   .toUpperCase(false)
   .setSize(14); 
}


void setScrollableListFont(controlP5.ScrollableList l)
{
  l.getCaptionLabel()
   .setFont(controlFont)
   .toUpperCase(false)
   .setSize(14);
   
  l.getValueLabel()
   .setFont(controlFont)
   .toUpperCase(false)
   .setSize(14);
}

void draw() {
  background(0);
  
  textSize(14);
  fill(255);
  
  text("Select Serial Port", 20, 55); 
  text("Select Bandwidth", 20, 110);
  text("Select Spreading Factor", 20, 165);
  text("Select Coding Rate", 20, 220);
  text("Select Power Level", 20, 275);
  text("Short Message", 20, 330);
  
  text(relayedMessage, 20, 450);
  text(statsSummary, 20, 480);
  checkIncomingMessage();
}

public void handleSendBurstRequest()
{
  int messageLength = PACKET_LENGTH + (NUM_PREFIX_SUFFIX_BYTES * 2) + 1;
  byte[] m = new byte[messageLength];
  m[0] = PREFIX_BYTE;
  m[1] = PREFIX_BYTE;
  m[2] = PREFIX_BYTE;
  m[3] = SEND_MESSAGE_BURST_COMMAND;
  m[messageLength - 1] = SUFFIX_BYTE;
  m[messageLength - 2] = SUFFIX_BYTE;
  m[messageLength - 3] = SUFFIX_BYTE;
  serialPort.write(m); 
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
    println("relayed message received");
    String encoding = StandardCharsets.UTF_8.name();
    byte[] sliceArray = new byte[PACKET_LENGTH];
    System.arraycopy(m, offset, sliceArray, 0, PACKET_LENGTH);
    try 
    {
      relayedMessage = new String(sliceArray, encoding);
    } 
    catch (Exception e)
    {
    }
  }
  else if (command == INCOMING_RECEIVE_BURST_STATS_COMMAND)
  {
    println("Received burst statistics.");
    int packetsReceived = (m[offset++] << 24) + 
                          (m[offset++] << 16) +
                          (m[offset++] << 8) +
                          m[offset++];
    float avgRSSI = (m[offset++] << 8) + (m[offset++]) + ((m[offset++] + m[offset++]) / 1000.0);
    float avgSNR = (m[offset++] << 8) + (m[offset++]) + ((m[offset++] + m[offset++]) / 1000.0);
    statsSummary = "Packets Recevied: " + packetsReceived + System.lineSeparator();
    statsSummary += "Average RSSI: " + avgRSSI + System.lineSeparator();
    statsSummary += "Average SNR: " + avgSNR;                      
  }
}

public void controlEvent(ControlEvent e) {
  if (serialPort != null && e.getName().equals("Send Burst"))
  {
    handleSendBurstRequest();
    return;
  }
  
  if(serialPort != null && e.getName().equals("textMessage")) {
    String userMessage = e.getStringValue();
    byte[] userMessageBytes = stringToBytes(userMessage, PACKET_LENGTH);
    byte[] prefix = {PREFIX_BYTE, PREFIX_BYTE, PREFIX_BYTE};
    byte[] suffix = {SUFFIX_BYTE, SUFFIX_BYTE, SUFFIX_BYTE};
    serialPort.write(prefix);
    serialPort.write((byte) SEND_TEXT_MESSAGE_COMMAND);
    serialPort.write(userMessageBytes);
    
    int paddingRequired = PACKET_LENGTH - userMessageBytes.length;
    for (int i = 0; i < paddingRequired; i++)
    {
      serialPort.write((byte) 0x00);
    }
    
    serialPort.write(suffix);
    println("wrote message");
    return;
  }
  
  int selectedIndex = (int) serialPortSelection.getValue();
  String selectedSerialPort = serialPortSelection.getItem(selectedIndex).get("name").toString();
  if (selectedSerialPort.equals(SELECT_SERIAL_PORT_LABEL))
  {
   return; 
  }

  if (!selectedSerialPort.equals(serialPortPath)) 
  {
    println("Selected a serial port.");
    if (serialPort != null)
    {
      serialPort.stop(); 
    }
    
    serialPortPath = selectedSerialPort;
    serialPort = new Serial(this, serialPortPath, SERIAL_PORT_BAUD_RATE);
  }

  if (serialPort == null)
  {
   return; 
  }

  selectedIndex = (int) bandwidthSelection.getValue();
  float selectedBandwidth = (float) bandwidthSelection.getItem(selectedIndex).get("value");
  println("Bandwidth: " + selectedBandwidth);
  
  selectedIndex = (int) spreadingFactorSelection.getValue();
  Integer v = (Integer) spreadingFactorSelection.getItem(selectedIndex).get("value");
  byte selectedSpreadingFactor = (byte) v.intValue();
  println("Spreading Factor: " + selectedSpreadingFactor);

  selectedIndex = (int) codingRateSelection.getValue();
  v = (Integer) codingRateSelection.getItem(selectedIndex).get("value");
  byte selectedCodingRate = (byte) v.intValue();
  println("Coding Rate: " + selectedCodingRate);
  
  selectedIndex = (int) powerLevelSelection.getValue();
  v = (Integer) powerLevelSelection.getItem(selectedIndex).get("value");
  byte selectedPowerlevel = (byte) v.intValue();
  println("Power Level: " + selectedPowerlevel);
  
  int messageLength = PACKET_LENGTH + (NUM_PREFIX_SUFFIX_BYTES * 2) + 1;
  byte[] m = new byte[messageLength];
  m[0] = PREFIX_BYTE;
  m[1] = PREFIX_BYTE;
  m[2] = PREFIX_BYTE;
  m[3] = SET_RADIO_PARAMETERS_COMMAND;
  m[messageLength - 1] = SUFFIX_BYTE;
  m[messageLength - 2] = SUFFIX_BYTE;
  m[messageLength - 3] = SUFFIX_BYTE;
  
  int offset = 4;
  byte[] bandwidthBytes = floatToByteArray(selectedBandwidth);
  m[offset++] = bandwidthBytes[0];
  m[offset++] = bandwidthBytes[1];
  m[offset++] = bandwidthBytes[2];
  m[offset++] = bandwidthBytes[3];
  
  m[offset++] = selectedSpreadingFactor;
  m[offset++] = selectedCodingRate;
  m[offset++] = selectedPowerlevel;
  
  serialPort.write(m);
  println("Sent message");
}
