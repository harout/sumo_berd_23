import processing.serial.*;


final float MAX_ANGLE = PI;
final float HALF_PI = PI / 2.0;
final float NEGATIVE_HALF_PI = -1 * HALF_PI;
final float PI_OVER_100 = PI / 100.0;

final int LF = 10;

Serial serialPort;
float percentage = 0.0;


void setup() {
  frameRate(1500);
  size(500, 300);
  
  String serialDevicePath = null;
  String[] serialDevicePaths = Serial.list();
  for (String path : serialDevicePaths)
  {
    if (path.contains("usbmodem") || path.contains("usbserial")) {
      serialDevicePath = path;
      break;
    }
  }
  
  if (serialDevicePath != null) 
  {
    serialPort = new Serial(this, serialDevicePath, 9600);
  }  
  else
  {
    println("Arduino not found.");
    exit();
  }
}


void draw() {
  background(0);
  
  // Draw the three circles used for 
  // making a color selecting
  noStroke();

  // Draws a red circle at 30, 30
  fill(255, 0, 0);
  circle(30, 30, 25);
  
  // Draw a blue circle at 80, 30
  // ????????????
  // ????????????
  
  // Draw an orange cirlce at 130, 30
  // ????????????
  // ????????????
  
  
  if (serialPort.available() != 0) 
  {
    String read = serialPort.readStringUntil(LF);
    if (read == null)
    {
      return;
    }
    
    read = read.replace("\n", "");
    read = read.replace("\r", "");
    try {
      percentage = Integer.parseInt(read);
    } catch (Exception e) {
      println("e " + read);  
    }
  }

  // Determine where the dial should go
  // Align it with the center of the canvas
  // and 30 pixels from the bottom
  // ???????????????????
  // ???????????????????

  push();
  fill(255, 0, 0);
  
  // Draw the dial in red
  // ?????????????????

  // Make the lines we draw for the dial have
  // stroke wieght of 3
  // ????????????????

  translate(dialX, dialY);
  circle(0, 0, 35);
  rotate(NEGATIVE_HALF_PI + PI_OVER_100 * percentage);
  line(-5, 0, 0, -200);
  line(5, 0, 0, -200);
  pop(); 
}


void mouseClicked()
{
  // Replace the question marks with the names of the
  // variables that tell us where the mouse is
  color c = intToColor(get(??????, ????????));

  byte h = (byte) (100.0 * (hue(c) / 255.0));
  serialPort.write(h);
}

color intToColor(int i) {
  int r = (i & (255 << 16)) >> 16;
  int g = (i & (255 << 8)) >> 8;
  int b = i & 255;
  return color(r,g,b);
}
