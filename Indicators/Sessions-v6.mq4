//+------------------------------------------------------------------+
//|                                                  Sessions-v6.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//|  02.19.2018  Adapted from i-Sessions.mq4                         |
//|              Orig. Author: KimIV from http://www.kimiv.ru        |
//|                                                                  |
//|  09.27.2019  Enhancement: Fibonacci/Fractal calculations         |
//+------------------------------------------------------------------+
#property copyright "(c) 2018, Dennis Jorgenson"
#property version   "6.0"
#property strict
#property indicator_chart_window

#property indicator_buffers   3
#property indicator_plots     3

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

#property indicator_label3  "indFractal"
#property indicator_type3   DRAW_LINE;
#property indicator_color3  clrWhite;
#property indicator_style3  STYLE_SOLID;
#property indicator_width3  1

double indPriorMidBuffer[];
double indOffMidBuffer[];
double indFractalBuffer[];

enum DataPosition
  {
    dpNone    = None,     //None
    dpFirst   = First,    //First
    dpSecond  = Second,   //Second
    dpThird   = Third,    //Third
    dpFourth  = Fourth    //Fourth
  };

//--- Indicator Inputs
input SessionType    inpType            = SessionTypes;    // Indicator session
input int            inpHourOpen        = NoValue;         // Session Opening Hour
input int            inpHourClose       = NoValue;         // Session Closing Hour
input int            inpHourOffset      = 0;               // Time offset EOD NY 5:00pm
input YesNoType      inpShowRange       = No;              // Display session ranges?
input YesNoType      inpShowBuffer      = No;              // Display trend lines?
input YesNoType      inpShowPriceLines  = No;              // Show price Lines?
input YesNoType      inpShowOriginLines = No;              // Show Origin Lines?
input DataPosition   inpShowData        = dpNone;          // Indicator data position

const color          AsiaColor          = C'0,32,0';       // Asia session box color
const color          EuropeColor        = C'48,0,0';       // Europe session box color
const color          USColor            = C'0,0,56';       // US session box color
const color          DailyColor         = C'64,64,0';      // Daily session box color;

CSession            *session            = new CSession(inpType,inpHourOpen,inpHourClose,inpHourOffset);

bool                 sessionOpen        = false;
int                  sessionRange       = 0;
const int            sessionEOD         = 23;               // Session End-of-Day hour

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

   if (TimeHour(session.ServerTime(Bar))==sessionEOD)
     sessionOpen          = false;
     
   if (TimeHour(session.ServerTime(Bar))==inpHourClose)
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
    if (inpShowRange==Yes)
    {
      if (TimeHour(session.ServerTime(Bar))==inpHourOpen)
        CreateRange(Bar);

      UpdateRange(Bar);
    }

    if (inpShowPriceLines==Yes)
    {
      FractalType show=ftOrigin;
      UpdateLine("lnS_ActiveMid",session.Pivot(ActiveSession),STYLE_SOLID,clrSteelBlue);
      UpdateLine("lnS_Support",session.Fractal(show).Support,STYLE_SOLID,clrRed);
      UpdateLine("lnS_Resistance",session.Fractal(show).Resistance,STYLE_SOLID,clrLawnGreen);
      UpdateLine("lnS_Low",session.Fractal(show).Low,STYLE_DOT,clrFireBrick);
      UpdateLine("lnS_High",session.Fractal(show).High,STYLE_DOT,clrForestGreen);
//      UpdateLine("lnS_PriorLow",session.Fractal(ftPrior).Support,STYLE_DOT,clrFireBrick);
//      UpdateLine("lnS_PriorHigh",session.Fractal(ftPrior).Resistance,STYLE_DOT,clrForestGreen);
    }

    if (inpShowOriginLines==Yes)
    {
      UpdateLine("lnS_Top",session.Fractal(ftOrigin).Resistance,STYLE_DASH,clrLawnGreen);
      UpdateLine("lnS_Bottom",session.Fractal(ftOrigin).Support,STYLE_DASH,clrRed);
    }
    
    if (inpShowData>dpNone)
    {
      UpdateLabel("lbSessionType"+sessionIndex,EnumToString(session.Type())+" "+proper(ActionText(session.Bias())),BoolToInt(session.IsOpen(),clrWhite,clrDarkGray),16);
      UpdateDirection("lbActiveDir"+sessionIndex,session[ActiveSession].Direction,DirColor(session[ActiveSession].Direction),20);
      UpdateLabel("lbActiveState"+sessionIndex,EnumToString(session[ActiveSession].State),DirColor(session[ActiveSession].Direction),8);
            
      if (session.IsOpen())
        if (TimeHour(session.ServerTime(Bar))>inpHourClose-3)
          UpdateLabel("lbSessionTime"+sessionIndex,"Late Session ("+IntegerToString(session.SessionHour())+")",clrRed);
        else
        if (session.SessionHour()>3)
          UpdateLabel("lbSessionTime"+sessionIndex,"Mid Session ("+IntegerToString(session.SessionHour())+")",clrYellow);
        else
          UpdateLabel("lbSessionTime"+sessionIndex,"Early Session ("+IntegerToString(session.SessionHour())+")",clrLawnGreen);
      else
        UpdateLabel("lbSessionTime"+sessionIndex,"Session Is Closed",clrDarkGray);

      UpdateDirection("lbActiveBrkDir"+sessionIndex,session[ActiveSession].BreakoutDir,DirColor(session[ActiveSession].BreakoutDir));
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
    if (inpShowBuffer==Yes)
      session.Update(indOffMidBuffer,indPriorMidBuffer,indFractalBuffer);
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
    
    SetIndexBuffer(2,indFractalBuffer);
    SetIndexEmptyValue(2, 0.00);
    SetIndexStyle(2,DRAW_SECTION);
    
    if (inpShowPriceLines==Yes)
    {
      NewLine("lnS_ActiveMid");
      NewLine("lnS_Support");
      NewLine("lnS_Resistance");
      NewLine("lnS_High");
      NewLine("lnS_Low");
      NewLine("lnS_PriorHigh");
      NewLine("lnS_PriorLow");
    }
    
    if (inpShowOriginLines==Yes)
    {
      NewLine("lnS_Top");
      NewLine("lnS_Bottom");
    }
    
    if (inpShowData>dpNone)
    {
      NewLabel("lbhSession","Session",120,220,clrGoldenrod,SCREEN_UR,0);
      NewLabel("lbhActive","State",30,220,clrGoldenrod,SCREEN_UR,0);
    
      NewLabel("lbSessionType"+sessionIndex,"",100,190+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbActiveDir"+sessionIndex,"",30,190+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbActiveBrkDir"+sessionIndex,"",20,190+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbSessionTime"+sessionIndex,"",100,215+sessionOffset,clrDarkGray,SCREEN_UR,0);
      NewLabel("lbActiveState"+sessionIndex,"",25,215+sessionOffset,clrDarkGray,SCREEN_UR,0);
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

    ObjectDelete("lnS_ActiveMid");
    ObjectDelete("lnS_Support");
    ObjectDelete("lnS_Resistance");
    ObjectDelete("lnS_High");
    ObjectDelete("lnS_Low");
    ObjectDelete("lnS_PriorTop");
    ObjectDelete("lnS_PriorBottom");
    ObjectDelete("lnS_Top");
    ObjectDelete("lnS_Bottom");
    
    
    ObjectDelete("lbActiveBrkDir"+sessionIndex);
    ObjectDelete("lbSessionType"+sessionIndex);
    ObjectDelete("lbActiveDir"+sessionIndex);
    ObjectDelete("lbSessionTime"+sessionIndex);
    ObjectDelete("lbActiveState"+sessionIndex);

    ObjectDelete("lbhSession");
    ObjectDelete("lbhActive");
  }
