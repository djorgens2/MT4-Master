//+------------------------------------------------------------------+
//|                                                  Sessions-v4.mq4 |
//|                                      Written by Dennis Jorgenson |
//|                                                                  |
//|                                                                  |
//|  02.19.2018  Adapted from i-Sessions.mq4                         |
//|              Orig. Author: KimIV from http://www.kimiv.ru        |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "(c) 2018, Dennis Jorgenson"
#property version   "4.0"
#property strict
#property indicator_chart_window

#property indicator_buffers   2
#property indicator_plots     2

#include <stdutil.mqh>
#include <std_utility.mqh>
#include <Class/Session.mqh>

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

enum DataPosition
  {
    dpNone    = None,     //None
    dpFirst   = First,    //First
    dpSecond  = Second,   //Second
    dpThird   = Third,    //Third
    dpFourth  = Fourth    //Fourth
  };

//--- Operational Inputs
input SessionType    inpType            = SessionTypes;    // Indicator session
input int            inpHourOpen        = NoValue;         // Session Opening Hour
input int            inpHourClose       = NoValue;         // Session Closing Hour
input bool           inpShowRange       = true;            // Display session ranges?
input bool           inpShowBuffer      = true;            // Display trend lines?
input bool           inpShowPriceLines  = true;            // Show price Lines?
input DataPosition   inpShowData        = dpNone;          // Indicator data position

const color          AsiaColor          = C'0,32,0';       // Asia session box color
const color          EuropeColor        = C'48,0,0';       // Europe session box color
const color          USColor            = C'0,0,56';       // US session box color
const color          DailyColor         = C'64,64,0';      // US session box color

CSession           *session            = new CSession(inpType,inpHourOpen,inpHourClose);

bool                 sessionOpen        = false;
int                  sessionRange       = 0;
const int            sessionEOD         = 0;               // Session End-of-Day hour

datetime             sessionOpenTime;
double               sessionHigh;
double               sessionLow;
string               sessionIndex       = IntegerToString(inpShowData);
int                  sessionOffset      = inpShowData*40;

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
    if (inpShowRange)
    {
      if (TimeHour(Time[Bar])==inpHourOpen)
        CreateRange(Bar);

      UpdateRange(Bar);
    }

    if (inpShowPriceLines)
    {
      UpdateLine("lnActiveMid",session.ActiveMid(),STYLE_SOLID,clrSteelBlue);
    
      if (session.IsOpen())
      {
        UpdateLine("lnPriorMid",session.PriorMid(),STYLE_SOLID,clrGoldenrod);
        UpdateLine("lnOffsessionMid",session.OffsessionMid(),STYLE_SOLID,clrGray);
      }
      else
      {
        UpdateLine("lnPriorMid",session.PriorMid(),STYLE_DOT,clrGoldenrod);
        UpdateLine("lnOffsessionMid",session.OffsessionMid(),STYLE_DOT,clrGray);
      }    

      UpdateLine("lnSupport",session[ActiveRec].Support,STYLE_SOLID,clrFireBrick);
      UpdateLine("lnResistance",session[ActiveRec].Resistance,STYLE_SOLID,clrForestGreen);
//      UpdateLine("lnPullback",session.Trend().Pullback,STYLE_DOT,clrFireBrick);
//      UpdateLine("lnRally",session.Trend().Rally,STYLE_DOT,clrForestGreen);
    }
    
    if (inpShowData>dpNone)
    {
      UpdateLabel("lbSessionType"+sessionIndex,EnumToString(session.Type())+" "+proper(ActionText(session.TradeBias())),BoolToInt(session.IsOpen(),clrWhite,clrDarkGray),16);
      UpdateDirection("lbTermDir"+sessionIndex,session[ActiveRec].Direction,DirColor(session[ActiveRec].Direction),20);
//      UpdateDirection("lbTrendDir"+sessionIndex,session.Trend().TrendDir,DirColor(session.Trend().TrendDir),20);
//      UpdateDirection("lbOriginDir"+sessionIndex,session.Trend().OriginDir,DirColor(session.Trend().OriginDir),20);

//      if (session.IsOpen())
//        if (TimeHour(Time[0])>inpHourClose-3)
//          UpdateLabel("lbSessionTime"+sessionIndex,"Late Session ("+IntegerToString(session.SessionHour())+")",clrRed);
//        else
//        if (session.SessionHour()>3)
//          UpdateLabel("lbSessionTime"+sessionIndex,"Mid Session ("+IntegerToString(session.SessionHour())+")",clrYellow);
//        else
//          UpdateLabel("lbSessionTime"+sessionIndex,"Early Session ("+IntegerToString(session.SessionHour())+")",clrLawnGreen);
//      else
//        UpdateLabel("lbSessionTime"+sessionIndex,"Session Is Closed",clrDarkGray);
//
//      if (session.Event(NewBreakout) || session.Event(NewReversal))
//        UpdateLabel("lbTermState"+sessionIndex,EnumToString(session.State(Term)),clrYellow);
//      else
//      if (session.Event(NewRally) || session.Event(NewPullback))
//        UpdateLabel("lbTermState"+sessionIndex,EnumToString(session.State(Term)),clrWhite);
//      else
//        UpdateLabel("lbTermState"+sessionIndex,EnumToString(session.State(Term)),clrDarkGray);
//        
//      UpdateLabel("lbTrendState"+sessionIndex,EnumToString(session.State(Trend)),clrDarkGray);
    }
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
    if (inpShowBuffer)
      session.Update(indOffMidBuffer,indPriorMidBuffer);
    else
      session.Update();
    
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
    
    if (inpShowPriceLines)
    {
      NewLine("lnActiveMid");
      NewLine("lnPriorMid");
      NewLine("lnOffMid");
      NewLine("lnSupport");
      NewLine("lnResistance");
      NewLine("lnPullback");
      NewLine("lnRally");
    }
    
    if (inpShowData==dpFirst)
    {
      NewLabel("lbhSession","Session",280,160+sessionOffset,clrGoldenrod,SCREEN_UR,0);
      NewLabel("lbhTerm","Term",180,160+sessionOffset,clrGoldenrod,SCREEN_UR,0);
      NewLabel("lbhTrend","Trend",100,160+sessionOffset,clrGoldenrod,SCREEN_UR,0);
      NewLabel("lbhOrigin","Origin",20,160+sessionOffset,clrGoldenrod,SCREEN_UR,0);
    }
    
    if (inpShowData>dpNone)
    {
      NewLabel("lbSessionType"+sessionIndex,"",260,170+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbTermDir"+sessionIndex,"",150,170+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbTrendDir"+sessionIndex,"",70,170+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbOriginDir"+sessionIndex,"",10,170+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbSessionTime"+sessionIndex,"",260,195+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbTermState"+sessionIndex,"",150,195+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbTrendState"+sessionIndex,"",70,195+sessionOffset,clrDarkGray,SCREEN_UR,0);
    }
    
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

    ObjectDelete("lnActiveMid");
    ObjectDelete("lnPriorMid");
    ObjectDelete("lnOffMid");
    ObjectDelete("lnSupport");
    ObjectDelete("lnResistance");
    ObjectDelete("lnPullback");
    ObjectDelete("lnRally");
    
    ObjectDelete("lbhSession");
    ObjectDelete("lbhTerm");
    ObjectDelete("lbhTrend");
    ObjectDelete("lbhOrigin");
    ObjectDelete("lbSessionType"+sessionIndex);
    ObjectDelete("lbTermDir"+sessionIndex);
    ObjectDelete("lbTrendDir"+sessionIndex);
    ObjectDelete("lbOriginDir"+sessionIndex);
    ObjectDelete("lbSessionTime"+sessionIndex);
    ObjectDelete("lbTermState"+sessionIndex);
    ObjectDelete("lbTrendState"+sessionIndex);
  }
