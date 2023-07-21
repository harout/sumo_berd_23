import processing.serial.*;


final float MAX_ANGLE = PI;
final float HALF_PI = PI / 2.0;
final float NEGATIVE_HALF_PI = -1 * HALF_PI;
final float PI_OVER_100 = PI / 100.0;

final int LF = 10;

Serial serialPort;
float percentage = 0.0;

Button animationAButton;
Button animationBButton;


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
    //exit();
  }
  
  animationAButton = new Button(10, 50, "Play Animation A", 200, 50);
  animationBButton = new Button(230, 50, "Play Animation B", 200, 50);
}


void draw() {
  background(0);
  
  animationAButton.draw();
  animationBButton.draw();
  
  // Draw the three circles used for selecting
  // a color
  noStroke();
  fill(255, 0, 0);
  circle(30, 30, 25);
  
  fill(0, 0, 255);
  circle(80, 30, 25);
  
  fill(255, 165, 0);
  circle(130, 30, 25);
  
  
  if (serialPort != null && serialPort.available() != 0) 
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

  int dialX = (int) (width / 2);
  int dialY = height - 30;
  
  
  push();
  fill(255, 0, 0);
  stroke(255, 0, 0);
  strokeWeight(3);
  translate(dialX, dialY);
  circle(0, 0, 35);
  rotate(NEGATIVE_HALF_PI + PI_OVER_100 * percentage);
  line(-5, 0, 0, -200);
  line(5, 0, 0, -200);
  pop(); 
}

void playAnimationA()
{
  
}

void playAnimationB()
{
  
}


void mouseClicked()
{
  if (animationAButton.isClickInside(mouseX, mouseY)) 
  {
    println("Playing Animation A.");
    return;
  }

  if (animationBButton.isClickInside(mouseX, mouseY)) 
  {
    println("Playing Animation B.");
    return;
  }
  
  color c = intToColor(get(mouseX, mouseY));
  byte h = (byte) (100.0 * (hue(c) / 255.0));
  if (serialPort != null)
  {
    serialPort.write(h);  
  }
}

color intToColor(int i) {
  int r = (i & (255 << 16)) >> 16;
  int g = (i & (255 << 8)) >> 8;
  int b = i & 255;
  return color(r,g,b);
}
