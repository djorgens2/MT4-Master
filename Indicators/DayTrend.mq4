//+------------------------------------------------------------------+
//|                                                     DayTrend.mq4 |
//|                                 Copyright 2017, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window

#property indicator_buffers   2
#property indicator_plots     2

#include <stdutil.mqh>
#include <std_utility.mqh>

//--- plot poly Major
#property indicator_label1  "indLTTrend"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "indSTTrend"
#property indicator_type2   DRAW_LINE;
#property indicator_color2  clrYellow;
#property indicator_style2  STYLE_DOT;
#property indicator_width2  1

double indBufferLT[];
double indBufferST[];

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input string DayTrendHeader          = "";        //+---- Day Trend -------+
input int    inpNewDayHour           = 0;         // New Day Hour

//+------------------------------------------------------------------+
//| Operational Variables                                            |
//+------------------------------------------------------------------+
int          dtCloseSessionHour      = BoolToInt(inpNewDayHour==0,23,inpNewDayHour-1);
int          dtSessionOpenHour       = BoolToInt(inpNewDayHour==23,0,inpNewDayHour+1);
int          dtSessionLastHour       = BoolToInt(dtCloseSessionHour==0,23,dtCloseSessionHour-1);

double       dtSessionHigh           = 0.00;
double       dtSessionLow            = 0.00;
double       dtSessionAggregate      = 0.00;
double       dtSessionMA             = 0.00;
int          dtSessionAggFactor      = 0;
int          dtDayBar                = NoValue;
int          dtPeriodBar             = NoValue;

bool         dtNewDay                = false;
bool         dtNewPeriod             = false;
bool         dtNewHigh               = false;
bool         dtNewLow                = false;

void CalcSTBuffer(int Bar, double Value)
  {
    static int paintBar  = 980;
    indBufferST[Bar] = Value;
    
    if (Bar==979)
    {
//      if (dtNewHigh)
        paintBar--;
        ObjectCreate("Bar:"+IntegerToString(paintBar),OBJ_ARROW,0,Time[paintBar],High[paintBar]+Pip(10,InPoints));
    }

  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
void CalcBuffer(int Bar=0)
  {
    static datetime cbPeriod    = NoValue;
    static int      cbHour      = NoValue;
    
    double cbBuffer             = 0.00;
    int    cbOffset             = 0;

    if (IsChanged(cbPeriod,Time[Bar]))
    {
      dtNewPeriod               = true;
      
      if (IsChanged(cbHour,TimeHour(Time[Bar])))
      {
        if (cbHour==dtSessionOpenHour)
        {          
          dtNewDay              = true;
          dtSessionHigh         = High[Bar];
          dtSessionLow          = Low[Bar];
          dtSessionAggregate    = 0.00;
          dtSessionAggFactor    = 0;
          
          for (cbOffset=1;TimeHour(Time[Bar+cbOffset])!=dtSessionLastHour;cbOffset++)
          {
            if (Bar+cbOffset>=Bars)
              return;
            
            if (TimeHour(Time[Bar+cbOffset])==inpNewDayHour)
              dtDayBar          = Bar+cbOffset;

            cbBuffer           += High[Bar+cbOffset]+Low[Bar+cbOffset];
          }

          dtPeriodBar           = dtDayBar;

          indBufferLT[dtDayBar] = fdiv(cbBuffer,(cbOffset-1)*2,Digits);
          CalcSTBuffer(dtDayBar,indBufferLT[dtDayBar]);
        }
      }
      
      if (!dtNewDay)
      {
        dtDayBar++;
        dtPeriodBar++;
      }      
    }
    
    if (IsHigher(High[Bar],dtSessionHigh))
      dtNewHigh              = true;
      
    if (IsLower(Low[Bar],dtSessionLow))
      dtNewLow               = true;

      string stText="";  
      stText += BoolToStr(dtNewDay,"Day");
      Append(stText,BoolToStr(dtNewHigh,"High"));
      Append(stText,BoolToStr(dtNewLow,"Low"));
      Append(stText,BoolToStr(dtNewPeriod,"Period"));
      stText += "\n";
      stText += "Bars ("+IntegerToString(dtDayBar)+","+IntegerToString(dtPeriodBar)+")"
             +  " ("+dtSessionAggFactor
             +  ":"+DoubleToStr(dtSessionLow,Digits)
             +  ":"+DoubleToStr(dtSessionHigh,Digits)
             +  ":"+DoubleToStr(dtSessionAggregate,Digits)+")\n";

    if (dtNewHigh||dtNewLow)
    {
//      indBufferST[dtPeriodBar] = fdiv(dtSessionAggregate,dtSessionAggFactor,Digits);

      dtSessionAggFactor += 2;
      dtSessionAggregate += dtSessionHigh+dtSessionLow;

//      if (Bar<35&&Bar>0)
        stText += " After ("+dtSessionAggFactor+":"+DoubleToStr(dtSessionLow,Digits)+":"+DoubleToStr(dtSessionHigh,Digits)+":"+DoubleToStr(dtSessionAggregate,Digits)+")";
//      indBufferST[dtPeriodBar] = fdiv(dtSessionAggregate,dtSessionAggFactor,Digits);
        CalcSTBuffer(dtPeriodBar,fdiv(dtSessionAggregate,dtSessionAggFactor,Digits));
    }
    
    ObjectSet("lblDay",OBJPROP_TIME1,Time[dtDayBar]);
    ObjectSet("lblDay",OBJPROP_PRICE1,Close[dtDayBar]);
    Comment (stText);
  }
  
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
    InitializeFlags();
    
    if(prev_calculated==0)
      InitializeAll();
    else 
      CalcBuffer();

    return(rates_total);
  }

//+------------------------------------------------------------------+
//| InititalizeFlags                                                 |
//+------------------------------------------------------------------+
void InitializeFlags(void)
  {
    dtNewDay                 = false;
    dtNewPeriod              = false;
    dtNewHigh                = false;
    dtNewLow                 = false;    
  }
  
//+------------------------------------------------------------------+
//| InititalizeAll                                                   |
//+------------------------------------------------------------------+
void InitializeAll(void)
  {
    ArrayInitialize(indBufferLT,0.00);
    ArrayInitialize(indBufferST,0.00);

    for (int bar=Bars-1;bar>0;bar--)
      CalcBuffer(bar);    
  }
  
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    ObjectCreate("lblDay",OBJ_ARROW_RIGHT_PRICE,0,0,0);
    SetIndexBuffer(0,indBufferLT);
    SetIndexEmptyValue(0, 0.00);   
    SetIndexStyle(0,DRAW_SECTION);

    SetIndexBuffer(1,indBufferST);
    SetIndexEmptyValue(1, 0.00);   
    SetIndexStyle(1,DRAW_SECTION);

    if (IsBetween(inpNewDayHour,0,23))
      return (INIT_SUCCEEDED);
      
    return (INIT_FAILED);
  }
