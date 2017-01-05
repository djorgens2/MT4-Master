//+------------------------------------------------------------------+
//|                                                    polyMA-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window

#include <std_utility.mqh>
#include <Class\PolyRegression.mqh>

//--- plot poly
#property indicator_label1    "indPoly"
#property indicator_type1     DRAW_LINE
#property indicator_color1    clrFireBrick
#property indicator_style1    STYLE_SOLID
#property indicator_width1    2
#property indicator_buffers   1
#property indicator_plots     1

//--- Input params
input int    inpDegree        = 6;        // Degree of the regression
input int    inpPeriods       = 120;      // MA Regression periods
input int    inpMAPeriods     = 3;        // MA Smoothing periods

double    indPolyBuffer[];
string    indShortName        = "polyMA-v2 ("+IntegerToString(inpDegree)+":"+IntegerToString(inpPeriods)+":"+IntegerToString(inpMAPeriods)+")";

CPolyRegression *pregr = new CPolyRegression(inpDegree,inpPeriods,inpMAPeriods);

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
    pregr.UpdateBuffer(indPolyBuffer);
    
    if (pregr.State()==Max)
      SetIndexStyle(0,DRAW_SECTION,STYLE_SOLID,2,BoolToInt(pregr.Direction(Polyline)==DirectionUp,clrYellow,clrRed));
    else
    if (pregr.State()==Min)
      SetIndexStyle(0,DRAW_SECTION,STYLE_DOT,1,BoolToInt(pregr.Direction(Polyline)==DirectionUp,clrYellow,clrRed));
    else
    if (pregr.State()==Minor)
      SetIndexStyle(0,DRAW_SECTION,STYLE_DASHDOTDOT,1,BoolToInt(pregr.Direction(Polyline)==DirectionUp,clrYellow,clrRed));
    else
    if (pregr.State()==Major)
      SetIndexStyle(0,DRAW_SECTION,STYLE_SOLID,1,BoolToInt(pregr.Direction(Polyline)==DirectionUp,clrYellow,clrRed));
    
    UpdateLine("prPolyMean("+IntegerToString(inpPeriods)+")",pregr.Poly(Mean));
    UpdateLabel("prPolyData",EnumToString(pregr.State())+" ("+proper(DirText((int)pregr.Poly(Direction)))+")",clrGray,12);
    
    return(rates_total);
  }   

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    SetIndexBuffer(0,indPolyBuffer);
    SetIndexEmptyValue(0,0.00);
    ArrayInitialize(indPolyBuffer,0.00);

    IndicatorShortName(indShortName);
    
    NewLabel("prPolyData","",5,5,clrGray,SCREEN_LR);
    NewLine("prPolyMean("+IntegerToString(inpPeriods)+")");

    return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pregr;
  }