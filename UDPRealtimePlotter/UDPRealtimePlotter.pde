import hypermedia.net.*;

// import libraries
import java.awt.Frame;
import java.awt.BorderLayout;
import controlP5.*; // http://www.sojamo.de/libraries/controlP5/
import processing.serial.*;

// interface stuff
ControlP5 cp5;

// Sensor values
int numberOfValues = 7; // The config file plotter_config.json should be edited to accomodate all the values. The default config supports up to 7 values, edit it to add support for more.
float[] sValues = new float[numberOfValues]; // First four are quaternions (w, x, y, z) and the last three are linear accelerations (x, y, z);
long time;
long lastTime;

// Settings for the plotter are saved in this file
JSONObject plotterConfigJSON;

// plots
int samplesInWindow = 200;
Graph LineGraph = new Graph(225, 70, 600, 400, color (20, 20, 200));
float[][] lineGraphValues = new float[numberOfValues][samplesInWindow];
float[] lineGraphSampleNumbers = new float[samplesInWindow];
color[] graphColors = new color[numberOfValues];

// helper for saving the executing path
String topSketchPath = "";

// Networking
UDP udp; // define the UDP object
int port = 18111;


void setup() {
  surface.setTitle("Realtime plotter");
  size(890, 620);
  
  // create a new datagram connection on defined port
  // and wait for incomming message
  udp = new UDP(this, port);
  //udp.log( true );     // <-- printout the connection activity
  udp.listen( true );

  // settings save file
  topSketchPath = sketchPath();
  plotterConfigJSON = loadJSONObject(topSketchPath+"/plotter_config.json");

  // gui
  cp5 = new ControlP5(this);

  // init charts
  setChartSettings();

  // build x axis values for the line graph
  for (int i=0; i<lineGraphValues.length; i++) {
    for (int k=0; k<lineGraphValues[0].length; k++) {
      lineGraphValues[i][k] = 0;
      if (i==0)
        lineGraphSampleNumbers[k] = k;
    }
  }
 
  // build the gui
  int x = 170;
  int y = 60;
  
  ControlFont.sharp();
  ControlFont cf = new ControlFont(createFont("Superclarendon-Light",20, true));
  cp5.addTextarea("UDP").setText("Waiting for UDP packet.").setFont(cf).setPosition(x=400, y=200).setColorForeground(color(0,0,0)).setColor(color(28)).setSize(400,200);
  
  cp5.addTextlabel("label").setText("on/off").setPosition(x=13, y=20).setColor(0);
  cp5.addTextlabel("value").setText("value").setPosition(x=55, y).setColor(0);
  
  x=60;
  y=-10;
  for (int i = 1; i-1 < numberOfValues; i++) {
    
    cp5.addTextfield("Line " + i).setPosition(x, y=y+40).setText(getPlotterConfigString("lgValue" + i)).setColorCaptionLabel(0).setWidth(40).setAutoClear(false);  
  }
  
  // Set line graph colors from config file
  for (int i = 0; i < numberOfValues; i++) {
    String sColor = getPlotterConfigString("lineColor" + (i + 1));
    String[] colors = split(sColor, ',');
    graphColors[i] = color(Integer.parseInt(colors[0]), Integer.parseInt(colors[1]), Integer.parseInt(colors[2]));
  } 
  
  x=x-50;
  y=-10;
  for (int i = 1; i-1 < numberOfValues; i++) {    
    cp5.addToggle("lgVisible" + i).setPosition(x, y=y+40).setValue(int(getPlotterConfigString("lgVisible" + i))).setMode(ControlP5.SWITCH).setColorActive(graphColors[i-1]);
  }
  
}


void draw() {
  if (lastTime != time) {
    cp5.get(Textarea.class, "UDP").setVisible(false); // This message is no longer needed since a UDP packet has arrived.
    //float[] nums = new float[]{sValues[4], sValues[5], sValues[6]};

    int numberOfInvisibleLineGraphs = 0;
    for (int i=0; i<6; i++) {
      if (int(getPlotterConfigString("lgVisible"+(i+1))) == 0) {
        numberOfInvisibleLineGraphs++;
      }
    }
    for (int i=0; i<sValues.length; i++) {
      // update line graph
      try {
        if (i<lineGraphValues.length) {
          for (int k=0; k<lineGraphValues[i].length-1; k++) {
            lineGraphValues[i][k] = lineGraphValues[i][k+1];
          }

          lineGraphValues[i][lineGraphValues[i].length-1] = sValues[i];//*float(getPlotterConfigString("lgMultiplier"+(i+1)));
        }
      }
      catch (Exception e) {
      }
      
      // Update values
      if (int(getPlotterConfigString("lgVisible"+(i+1))) == 1) {
        cp5.get(Textfield.class, "Line " + (i+1)).setText(String.format("%.3f", sValues[i]));
      }
    }
    


    // draw the bar chart
    background(255); 

    // draw the line graphs
    LineGraph.DrawAxis();
    for (int i=0; i<lineGraphValues.length; i++) {
      LineGraph.GraphColor = graphColors[i];
      if (int(getPlotterConfigString("lgVisible"+(i+1))) == 1)
        LineGraph.LineGraph(lineGraphSampleNumbers, lineGraphValues[i]);
    }
  }
}

// called each time the chart settings are changed by the user 
void setChartSettings() {
  LineGraph.xLabel=" Samples ";
  LineGraph.yLabel="Value";
  LineGraph.Title="";  
  LineGraph.xDiv=20;  
  LineGraph.xMax=0; 
  LineGraph.xMin=-100;  
  LineGraph.yMax=float(getPlotterConfigString("lgMaxY")); 
  LineGraph.yMin=float(getPlotterConfigString("lgMinY"));
}

// Receive udp packet and handle data
void receive(byte[] data) {  // <-- extended handler
  data = subset(data, 0, data.length-2);
  String message = new String( data ); // Comma separated values in a string
  String[] values = split(message, ',');
  
  // Fill upp sensor values array. If the message contain more values than the array can hold, the rest will be truncated.
  for (int i = 0; i < values.length; i++) {
    if (!(i < numberOfValues)) break;
    sValues[i] = Float.parseFloat(values[i]);  
  }
  time = Long.parseLong(values[7]);  // In this example the sensor also sends time, which is a long int. This value is truncated in the previous for-loop.
}

// handle gui actions
void controlEvent(ControlEvent theEvent) {
  if (theEvent.isAssignableFrom(Textfield.class) || theEvent.isAssignableFrom(Toggle.class) || theEvent.isAssignableFrom(Button.class)) {
    String parameter = theEvent.getName();
    String value = "";
    if (theEvent.isAssignableFrom(Textfield.class))
      value = theEvent.getStringValue();
    else if (theEvent.isAssignableFrom(Toggle.class) || theEvent.isAssignableFrom(Button.class))
      value = theEvent.getValue()+"";

    plotterConfigJSON.setString(parameter, value);
    saveJSONObject(plotterConfigJSON, topSketchPath+"/plotter_config.json");
  }
  setChartSettings();
}

// get gui settings from settings file
String getPlotterConfigString(String id) {
  String r = "";
  try {
    r = plotterConfigJSON.getString(id);
  } 
  catch (Exception e) {
    r = "";
  }
  return r;
}