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
const color          DailyColor         = C'64,64,0';      // US session box color;

CSession            *session            = new CSession(inpType,inpHourOpen,inpHourClose);

bool                 sessionOpen        = false;
int                  sessionRange       = 0;
const int            sessionEOD         = 0;               // Session End-of-Day hour

datetime             sessionOpenTime;
double               sessionHigh;
double               sessionLow;
string               sessionIndex       = IntegerToString(inpShowData);
int                  sessionOffset      = inpShowData*60;

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
      UpdateLine("lnActiveMid",session.Pivot(Active),STYLE_SOLID,clrSteelBlue);
      UpdateLine("lnSupport",session[Active].Support,STYLE_SOLID,clrRed);
      UpdateLine("lnResistance",session[Active].Resistance,STYLE_SOLID,clrLawnGreen);
      UpdateLine("lnLow",session[Active].Low,STYLE_DOT,clrFireBrick);
      UpdateLine("lnHigh",session[Active].High,STYLE_DOT,clrForestGreen);

      UpdatePriceLabel("plBase",session[Active].Base,clrFireBrick);
      UpdatePriceLabel("plRoot",session[Active].Root,clrForestGreen);
    }
    
    if (inpShowData>dpNone)
    {
      UpdateLabel("lbSessionType"+sessionIndex,EnumToString(session.Type())+" "+proper(ActionText(session.Bias(Active,Pivot))),BoolToInt(session.IsOpen(),clrWhite,clrDarkGray),16);
      UpdateDirection("lbActiveDir"+sessionIndex,session[Active].Direction,DirColor(session[Active].Direction),20);
      UpdateLabel("lbActiveState"+sessionIndex,EnumToString(session[Active].State),DirColor(session[Active].Direction),8);
            
      UpdateDirection("lbTermDir"+sessionIndex,session[Term].Direction,DirColor(session[Term].Direction),20);
      UpdateLabel("lbTermState"+sessionIndex,EnumToString(session[Term].State),DirColor(session[Term].Direction),8);

      UpdateDirection("lbTrendDir"+sessionIndex,session[Trend].Direction,DirColor(session[Trend].Direction),20);
      UpdateLabel("lbTrendState"+sessionIndex,EnumToString(session[Trend].State),DirColor(session[Trend].Direction),8);

      UpdateDirection("lbOriginDir"+sessionIndex,session[Origin].Direction,DirColor(session[Origin].Direction),20);
      UpdateLabel("lbOriginState"+sessionIndex,EnumToString(session[Origin].State),DirColor(session[Origin].Direction),8);

      if (session.IsOpen())
        if (TimeHour(Time[0])>inpHourClose-3)
          UpdateLabel("lbSessionTime"+sessionIndex,"Late Session ("+IntegerToString(session.SessionHour())+")",clrRed);
        else
        if (session.SessionHour()>3)
          UpdateLabel("lbSessionTime"+sessionIndex,"Mid Session ("+IntegerToString(session.SessionHour())+")",clrYellow);
        else
          UpdateLabel("lbSessionTime"+sessionIndex,"Early Session ("+IntegerToString(session.SessionHour())+")",clrLawnGreen);
      else
        UpdateLabel("lbSessionTime"+sessionIndex,"Session Is Closed",clrDarkGray);

      UpdateDirection("lbActiveBrkDir"+sessionIndex,session[Active].BreakoutDir,DirColor(session[Active].BreakoutDir));
      UpdateDirection("lbTermBrkDir"+sessionIndex,session[Term].BreakoutDir,DirColor(session[Term].BreakoutDir));
      UpdateDirection("lbTrendBrkDir"+sessionIndex,session[Trend].BreakoutDir,DirColor(session[Trend].BreakoutDir));
      UpdateDirection("lbOriginBrkDir"+sessionIndex,session[Origin].BreakoutDir,DirColor(session[Origin].BreakoutDir));
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
      NewLine("lnSupport");
      NewLine("lnResistance");
      NewLine("lnHigh");
      NewLine("lnLow");

      NewPriceLabel("plBase");
      NewPriceLabel("plRoot");
    }
    
    if (inpShowData==dpFirst)
    {
      NewLabel("lbhSession","Session",280,160+sessionOffset,clrGoldenrod,SCREEN_UR,0);
      NewLabel("lbhActive","Active",180,160+sessionOffset,clrGoldenrod,SCREEN_UR,0);
      NewLabel("lbhTerm","Term",130,160+sessionOffset,clrGoldenrod,SCREEN_UR,0);
      NewLabel("lbhTrend","Trend",80,160+sessionOffset,clrGoldenrod,SCREEN_UR,0);
      NewLabel("lbhOrigin","Origin",30,160+sessionOffset,clrGoldenrod,SCREEN_UR,0);
    }
    
    if (inpShowData>dpNone)
    {
      NewLabel("lbActiveBrkDir"+sessionIndex,"",170,170+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbTermBrkDir"+sessionIndex,"",120,170+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbTrendBrkDir"+sessionIndex,"",70,170+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbOriginBrkDir"+sessionIndex,"",20,170+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbSessionType"+sessionIndex,"",260,170+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbActiveDir"+sessionIndex,"",180,170+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbTermDir"+sessionIndex,"",130,170+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbTrendDir"+sessionIndex,"",80,170+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbOriginDir"+sessionIndex,"",30,170+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbSessionTime"+sessionIndex,"",260,195+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbActiveState"+sessionIndex,"",180,195+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbTermState"+sessionIndex,"",125,195+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbTrendState"+sessionIndex,"",70,195+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbOriginState"+sessionIndex,"",15,195+sessionOffset,clrDarkGray,SCREEN_UR,0);
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
    ObjectDelete("lnSupport");
    ObjectDelete("lnResistance");
    ObjectDelete("lnHedge");
    ObjectDelete("lnCorrection");
    ObjectDelete("lnHigh");
    ObjectDelete("lnLow");
    
    ObjectDelete("lbActiveBrkDir"+sessionIndex);
    ObjectDelete("lbTermBrkDir"+sessionIndex);
    ObjectDelete("lbTrendBrkDir"+sessionIndex);
    ObjectDelete("lbOriginBrkDir"+sessionIndex);
    ObjectDelete("lbSessionType"+sessionIndex);
    ObjectDelete("lbActiveDir"+sessionIndex);
    ObjectDelete("lbTermDir"+sessionIndex);
    ObjectDelete("lbTrendDir"+sessionIndex);
    ObjectDelete("lbOriginDir"+sessionIndex);
    ObjectDelete("lbSessionTime"+sessionIndex);
    ObjectDelete("lbActiveState"+sessionIndex);
    ObjectDelete("lbTermState"+sessionIndex);
    ObjectDelete("lbTrendState"+sessionIndex);
    ObjectDelete("lbOriginState"+sessionIndex);

    ObjectDelete("lbhSession");
    ObjectDelete("lbhActive");
    ObjectDelete("lbhTerm");
    ObjectDelete("lbhTrend");
    ObjectDelete("lbhOrigin");
  }
