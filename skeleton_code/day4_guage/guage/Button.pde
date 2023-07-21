class Button{
  private final int xPos;
  private final int yPos;
  private final String label;
  private final int buttonWidth;
  private final int buttonHeight;
  
  public Button(int x, int y, String label, int w, int h)
  {
    this.xPos = x;  
    this.yPos = y;
    this.label = label;
    this.buttonWidth = w;
    this.buttonHeight = h;
  }
  
  public void draw()
  {
    push();
    
    rectMode(CORNER);
    fill(0, 0, 100);
    stroke(0, 0, 0);
    strokeWeight(3);
    rect(this.xPos, this.yPos, this.buttonWidth, this.buttonHeight);
    
    fill(255, 255, 255);
    textSize(25);
    text(this.label, this.xPos + 10, this.yPos + 5, this.buttonWidth, this.buttonHeight);
    
    pop();
  }
  
  public boolean isClickInside(int x, int y)
  {
    if (x < this.xPos)
    {
      return false;  
    }
    
    if (y < this.yPos)
    {
       return false; 
    }
    
    if (x > this.xPos + this.buttonWidth)
    {
       return false; 
    }
    
    if (y > this.yPos + this.buttonHeight)
    {
       return false; 
    }
    
    return true;
  }
}
