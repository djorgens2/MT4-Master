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
input int    inpSessionCloseHour     = 23;        // Session Closing Hour
input int    inpSessionOpenHour      = 1;         // Session Opening Hour
input int    inpSessionLastHour      = 22;        // Last Trading Hour
input bool   inpIncludeLastPeriod    = false;     // Include Last Trading Period

//+------------------------------------------------------------------+
//| Operational Variables                                            |
//+------------------------------------------------------------------+
double       dtSessionAgg            = 0.00;
int          dtSessionFactor         = 0;

double       dtOffSessionAgg         = 0.00;
int          dtOffSessionFactor      = 0;

double       dtDayHigh               = 0.00;
double       dtDayLow                = 0.00;
int          dtDayBar                = 0;

int          dtBarNow                = NoValue;

//--- Price Flags
bool         dtNewHigh               = false;
bool         dtNewLow                = false;
bool         dtNewBoundary           = false;
bool         dtNewPeriodBoundary     = false;

//--- Time Flags
bool         dtNewDay                = false;
bool         dtNewPeriod             = false;
bool         dtNewHour               = false;
bool         dtLastHour              = false;

//--- Session State Flags
bool         dtSessionOpen           = false;
bool         dtSessionChange         = false;

//+------------------------------------------------------------------+
//| RefreshIndScreen                                                 |
//+------------------------------------------------------------------+
void RefreshIndScreen(void)
  {
    string risText  = BoolToStr(dtSessionOpen,"Open","Closed")
                    + BoolToStr(dtNewBoundary," - Session expanding")+"\n";

    risText += BoolToStr(dtNewDay,"Day");

    Append(risText,BoolToStr(dtNewHigh,"High"));
    Append(risText,BoolToStr(dtNewLow,"Low"));
    Append(risText,BoolToStr(dtNewPeriod,"Period"));

    risText += "\n";
//    risText += "Bars ("+IntegerToString(dtDayBar)+":"+IntegerToString(dtSessionBar)+")"
//            +  " Day ("+DoubleToStr(dtDayLow,Digits)
//            +  ":"+DoubleToStr(dtDayHigh,Digits)+")"
//            +  " Session ("+IntegerToString(dtSessionFactor)
//            +  " (ag):"+DoubleToStr(dtSessionAgg,Digits)
//            +  " (lo):"+DoubleToStr(dtSessionLow,Digits)
//            +  " (hi):"+DoubleToStr(dtSessionHigh,Digits)+")\n";

    ObjectSet("lblDay",OBJPROP_TIME1,Time[dtDayBar]);
    ObjectSet("lblDay",OBJPROP_PRICE1,Close[dtDayBar]);
    
    Comment (risText);    
  }
  
//+------------------------------------------------------------------+
//| CalcPriceFlags - sets price flags                                |
//+------------------------------------------------------------------+
void CalcPriceFlags(void)
  {
    //--- Reset Price flags
    dtNewHigh                   = false;
    dtNewLow                    = false;
    dtNewBoundary               = false;

    if (IsHigher(High[dtBarNow],dtDayHigh))
      dtNewHigh                 = true;

    if (IsLower(Low[dtBarNow],dtDayLow))
      dtNewLow                  = true;
      
    if (dtNewHigh||dtNewLow)
      dtNewBoundary             = true;
  }

//+------------------------------------------------------------------+
//| CalcTimeFlags - sets time flags                                  |
//+------------------------------------------------------------------+
void CalcTimeFlags(void)
  {
    static datetime cbPeriod    = NoValue;
    static int      cbHour      = NoValue;

    //--- Reset Time flags
    dtNewDay                    = false;
    dtNewPeriod                 = false;
    dtNewHour                   = false;
    dtSessionChange             = false;
    dtLastHour                  = false;

    if (IsChanged(cbPeriod,Time[dtBarNow]))
    {
      dtNewPeriod               = true;
      
      if (IsChanged(cbHour,TimeHour(Time[dtBarNow])))
      {
        dtNewHour               = true;
        
        if (cbHour==inpNewDayHour)
          dtNewDay              = true;

        if (cbHour==inpSessionCloseHour)
          if (IsChanged(dtSessionOpen,false))
            dtSessionChange     = true;

        if (cbHour==inpSessionOpenHour)
          if (IsChanged(dtSessionOpen,true))
            dtSessionChange     = true;
      }
      
      if (cbHour==inpSessionLastHour)
        dtLastHour              = true;
    }
  }

//+------------------------------------------------------------------+
//| CalcSessionOpen - Sets values in both the LT and ST buffers      |
//+------------------------------------------------------------------+
void CalcSessionOpen(void)
  {
    dtSessionAgg            = 0.00;
    dtSessionFactor         = 0;

//    indBufferST[dtDayBar]   = fdiv(dtOffSessionAgg,dtOffSessionFactor);
  }
  
//+------------------------------------------------------------------+
//| CalcSessionClose - Sets values in both the LT and ST buffers     |
//+------------------------------------------------------------------+
void CalcSessionClose(void)
  {
    dtOffSessionAgg         = 0.00;
    dtOffSessionFactor      = 0;
  }

//+------------------------------------------------------------------+
//| CalcDay - Calculates the end of day buffer values                |
//+------------------------------------------------------------------+
void CalcDay(void)
  {
    dtDayBar                = dtBarNow;

    indBufferLT[dtDayBar]   = (dtDayHigh+dtDayLow)/2;
    indBufferST[dtDayBar]   = Open[dtDayBar];
    
    dtDayLow                = Open[dtDayBar];
    dtDayHigh               = Open[dtDayBar];
  }

//+------------------------------------------------------------------+
//| CalcPeriod - Calculates the end of period values                 |
//+------------------------------------------------------------------+
void CalcPeriod(void)
  {
    if (dtNewPeriod)
    {
//      if (dtNewPeriodBoundary)
      {
        if (dtSessionOpen)
        {
          dtSessionAgg        += (Low[dtBarNow]+High[dtBarNow]);
          dtSessionFactor     += 2;
        }
        else
        {
          dtOffSessionAgg     += (Low[dtBarNow]+High[dtBarNow]);
          dtOffSessionFactor  += 2;
        Print (dtBarNow+":"+DoubleToStr(Low[dtBarNow],Digits)+":"+DoubleToStr(High[dtBarNow],Digits)+":"+DoubleToStr(dtSessionAgg,Digits)+":"+dtSessionFactor);
        }

      } 
   
      dtNewPeriodBoundary      = false;
      dtDayBar++;
    }
    
    if (dtNewBoundary)
      dtNewPeriodBoundary      = true;    
  }

//+------------------------------------------------------------------+
//| CalcBuffer - Main calc routine                                   |
//+------------------------------------------------------------------+
void CalcBuffer(void)
  {
    CalcTimeFlags();
    CalcPriceFlags();

    if (dtNewDay)
      CalcDay();
    else
      CalcPeriod();

    if (dtSessionChange)
      if (dtSessionOpen)
        CalcSessionOpen();
      else
        CalcSessionClose();
      
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
    if(prev_calculated==0)
      InitializeAll();
    else 
      CalcBuffer();
      
    RefreshIndScreen();

    return(rates_total);
  }
  
//+------------------------------------------------------------------+
//| InititalizeAll                                                   |
//+------------------------------------------------------------------+
void InitializeAll(void)
  {
    dtSessionOpen = true;
    ArrayInitialize(indBufferLT,0.00);
    ArrayInitialize(indBufferST,0.00);

    dtDayHigh         = High[Bars-1];
    dtDayLow          = Low[Bars-1];
    
    for (dtBarNow=Bars-1;dtBarNow>0;dtBarNow--)
      CalcBuffer();
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
      
    if (Period()<PERIOD_D1)
      return (INIT_SUCCEEDED);
      
    return (INIT_FAILED);
  }
