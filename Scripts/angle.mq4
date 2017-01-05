//+------------------------------------------------------------------+
//|                                                        Angle.mq4 |
//|                                             Copyright 2014, SDC. |
//+------------------------------------------------------------------+
//| This script requires a trendline be already placed on the chart. |
//| the trendline should be named "trend1"                           |
//| Run the script and it will find the angle of that trendline      |
//| reletive to the x axis of the chart.                             |
//| To verify if the calculation is accurate, it will attempt to     |
//| place text at the same angle as the line.                        |
//| I used a trendline for convenience, the same code can be applied |
//| to any kind of a line with price time co-ordinates.              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, SDC."
#property version   "1.00"
#property strict
input string name = "trend1"; //Name of the Trendline
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   int x1=0,x2=0;
   int y1=0,y2=0;
   long chart = ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   long t1=ObjectGetInteger(0,name,OBJPROP_TIME,0);
   double p1=ObjectGetDouble(0,name,OBJPROP_PRICE,0);
   long t2=ObjectGetInteger(0,name,OBJPROP_TIME,1);
   double p2=ObjectGetDouble(0,name,OBJPROP_PRICE,1);
   ChartTimePriceToXY(0,0,t1,p1,x1,y1);
   ChartTimePriceToXY(0,0,t2,p2,x2,y2);
   int size = (int)chart;
   y1=size-y1;
   y2=size-y2;
   double angle =(MathArctan(((double)y2-(double)y1)/((double)x2-(double)x1))*180)/M_PI;
   string textangle = DoubleToStr(angle,1);
   string text = StringConcatenate("The Angle of This Line is ",textangle,"°");
   ObjectCreate(0,"sometext",OBJ_TEXT,0,0,0);
   ObjectSet("sometext",OBJPROP_TIME1,t1);
   ObjectSet("sometext",OBJPROP_PRICE1,p1);
   ObjectSetInteger(0,"sometext",OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
   ObjectSetString(0,"sometext",OBJPROP_TEXT,text);
   ObjectSetDouble(0,"sometext",OBJPROP_ANGLE,angle);
   ObjectSet("sometext",OBJPROP_COLOR,clrAqua);
   ObjectSet("sometext",OBJPROP_FONTSIZE,18);
  }
//+------------------------------------------------------------------+
