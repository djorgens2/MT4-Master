//+------------------------------------------------------------------+
//|                                                  Sessions-v3.mq4 |
//|                                      Written by Dennis Jorgenson |
//|                                                                  |
//|                                                                  |
//|  02.19.2018  Adapted from i-Sessions.mq4                         |
//|              Orig. Author: KimIV from http://www.kimiv.ru        |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "(c) 2018, Dennis Jorgenson"
#property version   "2.0"
#property strict
#property indicator_chart_window

#property indicator_buffers   2
#property indicator_plots     2

#include <stdutil.mqh>
#include <std_utility.mqh>
#include <Class/SessionArray.mqh>

//--- plot Off & Prior Session points
#property indicator_label1  "indPriorMid"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "indOffMid"
#property indicator_type2   DRAW_LINE;
#property indicator_color2  clrYellow;
#property indicator_style2  STYLE_DOT;
#property indicator_width2  1

double indPriorMidBuffer[];
double indOffMidBuffer[];


//--- Operational Inputs
input int            inpAsiaOpen     = 1;          // Asia Session Opening Hour
input int            inpAsiaClose    = 10;         // Asia Session Closing Hour
input int            inpEuropeOpen   = 8;          // Europe Session Opening Hour
input int            inpEuropeClose  = 18;         // Europe Session Closing Hour
input int            inpUSOpen       = 14;         // US Session Opening Hour
input int            inpUSClose      = 23;         // US Session Closing Hour
input SessionType    inpSessionBars  = SessionTypes;    // Indicator session


const color          AsiaColor       = C'0,32,0';       // Asia session box color
const color          EuropeColor     = C'48,0,0';       // Europe session box color
const color          USColor         = C'0,0,56';       // US session box color
const color          DailyColor      = C'64,64,0';      // US session box color

CSessionArray       *ca_asia         = new CSessionArray(Asia,inpAsiaOpen,inpAsiaClose);
CSessionArray       *ca_europe       = new CSessionArray(Europe,inpEuropeOpen,inpEuropeClose);
CSessionArray       *ca_us           = new CSessionArray(US,inpUSOpen,inpUSClose);
CSessionArray       *ca_daily        = new CSessionArray(Daily,inpAsiaOpen,inpUSClose);

bool                 sessionOpen     = false;
int                  sessionRange    = 0;
const int            sessionEOD      = 0;               // Session End-of-Day hour

datetime             sessionOpenTime;
double               sessionHigh;
double               sessionLow;

//+------------------------------------------------------------------+
//| SessionColor - Returns the color for session ranges              |
//+------------------------------------------------------------------+
color SessionColor(void)
  {
    switch (inpType)
    {
      case Asia:    return(AsiaColor);
      case Europe:  return(EuropeColor);
      case US:      return(USColor);
      case Daily:   return(DailyColor);
    }
    
    return (clrBlack);
  }

//+------------------------------------------------------------------+
//| CreateRange - Paints the session boxes                           |
//+------------------------------------------------------------------+
void CreateRange(int Bar=0)
 {
   string crRangeId;
   
   if (sessionOpen)
     return;
   else
   {
     crRangeId          = EnumToString(inpType)+IntegerToString(++sessionRange);
     
     sessionOpen        = true;
   
     sessionOpenTime    = Time[Bar];
     sessionHigh        = High[Bar];
     sessionLow         = Low[Bar];
   
     ObjectCreate(crRangeId,OBJ_RECTANGLE,0,sessionOpenTime,sessionHigh,sessionOpenTime,sessionLow);
   
     ObjectSet(crRangeId, OBJPROP_STYLE, STYLE_SOLID);
     ObjectSet(crRangeId, OBJPROP_COLOR, SessionColor());
     ObjectSet(crRangeId, OBJPROP_BACK, true);
   }
 }

//+------------------------------------------------------------------+
//| UpdateRange - Repaints the session box                           |
//+------------------------------------------------------------------+
void UpdateRange(int Bar=0)
 {
   string urRangeId       = EnumToString(inpType)+IntegerToString(sessionRange);

   if (TimeHour(Time[Bar])==sessionEOD)
     sessionOpen          = false;
     
   if (TimeHour(Time[Bar])==inpHourClose)
   {
     if (sessionOpen)
       ObjectSet(urRangeId,OBJPROP_TIME2,Time[Bar]);

     sessionOpen          = false;
   }

   if (sessionOpen)
   {
     if (IsHigher(High[Bar],sessionHigh))
       ObjectSet(urRangeId,OBJPROP_PRICE1,sessionHigh);
     
     if (IsLower(Low[Bar],sessionLow))
       ObjectSet(urRangeId,OBJPROP_PRICE2,sessionLow);

     ObjectSet(urRangeId,OBJPROP_TIME1,sessionOpenTime);
     ObjectSet(urRangeId,OBJPROP_TIME2,Time[Bar]);
   }
 }

//+------------------------------------------------------------------+
//| DeleteRanges - Removes all objects created by the indicator      |
//+------------------------------------------------------------------+
void DeleteRanges()
  {
    for (int doRangeId=0;doRangeId<=sessionRange;doRangeId++)
      ObjectDelete(EnumToString(inpType)+IntegerToString(doRangeId));
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints on screen information                   |
//+------------------------------------------------------------------+
void RefreshScreen(int Bar=0)
  {
    if (inpShowSession)
      if (TimeHour(Time[Bar])==inpHourOpen)
        CreateRange(Bar);
      else
        UpdateRange(Bar);
        
    UpdateLine("lnActiveMid",session.ActiveMid(),STYLE_SOLID,clrSteelBlue);
    UpdateLine("lnResistance",session.Active().Resistance,STYLE_DASHDOT,clrSteelBlue);
    UpdateLine("lnSupport",session.Active().Support,STYLE_DASHDOT,clrYellow);
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
    session.Update(indOffMidBuffer,indPriorMidBuffer);
    
    RefreshScreen();

    return(rates_total);
  }
  
       
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    SetIndexBuffer(0,indPriorMidBuffer);
    SetIndexEmptyValue(0, 0.00);
    SetIndexStyle(0,DRAW_SECTION);

    SetIndexBuffer(1,indOffMidBuffer);
    SetIndexEmptyValue(1, 0.00);
    SetIndexStyle(1,DRAW_SECTION);
    
    NewLine("lnActiveMid");
    NewLine("lnResistance");
    NewLine("lnSupport");
    
    DeleteRanges();

    for (int bar=Bars-24;bar>0;bar--)
      RefreshScreen(bar);
      
    if (Period()<PERIOD_D1)
      return (INIT_SUCCEEDED);

    return (INIT_FAILED);   
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    DeleteRanges();
    
    delete session;    
  }
