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


//--- Operational Inputs
input int            inpAsiaOpen     = 1;            // Asia Session Opening Hour
input int            inpAsiaClose    = 10;           // Asia Session Closing Hour
input int            inpEuropeOpen   = 8;            // Europe Session Opening Hour
input int            inpEuropeClose  = 18;           // Europe Session Closing Hour
input int            inpUSOpen       = 14;           // US Session Opening Hour
input int            inpUSClose      = 23;           // US Session Closing Hour
input int            inpGMTOffset    = 0;            // Offset from GMT+3
input YesNoType      inpShowTOLines  = No;           // Display Trend Origin Lines
input YesNoType      inpShowSRLines  = No;           // Display Support/Resistance Lines
input YesNoType      inpShowMidLines = No;           // Display Mid-Price Lines

const color          AsiaColor       = C'0,32,0';    // Asia session box color
const color          EuropeColor     = C'48,0,0';    // Europe session box color
const color          USColor         = C'0,0,56';    // US session box color
const color          DailyColor      = C'64,64,0';   // US session box color

struct SessionData
  {
     bool            IsOpen;
     int             Range;
     datetime        OpenTime;
     double          PriceHigh;
     double          PriceLow;
  };
  
const int            sessionEOD      = 0;            // Session End-of-Day hour
const int            sessionOffset   = 40;           // Display offset

CSession            *session[SessionTypes];
SessionData          data[SessionTypes];

//+------------------------------------------------------------------+
//| SessionColor - Returns the color for session ranges              |
//+------------------------------------------------------------------+
color SessionColor(SessionType Type)
  {
    switch (Type)
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
void CreateRange(SessionType Type, int Bar=0)
 {
   string crRangeId;
   
   if (data[Type].IsOpen)
     return;
   else
   {
     crRangeId                = EnumToString(Type)+IntegerToString(++data[Type].Range);
     
     data[Type].IsOpen        = true;
     data[Type].OpenTime      = Time[Bar];
     data[Type].PriceHigh     = High[Bar];
     data[Type].PriceLow      = Low[Bar];
   
     ObjectCreate(crRangeId,OBJ_RECTANGLE,0,data[Type].OpenTime,data[Type].PriceHigh,data[Type].OpenTime,data[Type].PriceLow);
   
     ObjectSet(crRangeId, OBJPROP_STYLE, STYLE_SOLID);
     ObjectSet(crRangeId, OBJPROP_COLOR, SessionColor(Type));
     ObjectSet(crRangeId, OBJPROP_BACK, true);
   }
 }

//+------------------------------------------------------------------+
//| UpdateRange - Repaints the session box                           |
//+------------------------------------------------------------------+
void UpdateRange(SessionType Type, int Bar=0)
 {
   string urRangeId       = EnumToString(Type)+IntegerToString(data[Type].Range);

   if (TimeHour(session[Type].ServerTime(Bar))==sessionEOD)
     data[Type].IsOpen    = false;
     
   if (TimeHour(session[Type].ServerTime(Bar))==session[Type].SessionHour(SessionClose))
   {
     if (data[Type].IsOpen)
       ObjectSet(urRangeId,OBJPROP_TIME2,Time[Bar]);

     data[Type].IsOpen    = false;
   }

   if (data[Type].IsOpen)
   {
     if (IsHigher(High[Bar],data[Type].PriceHigh))
       ObjectSet(urRangeId,OBJPROP_PRICE1,data[Type].PriceHigh);
     
     if (IsLower(Low[Bar],data[Type].PriceLow))
       ObjectSet(urRangeId,OBJPROP_PRICE2,data[Type].PriceLow);

     ObjectSet(urRangeId,OBJPROP_TIME1,data[Type].OpenTime);
     ObjectSet(urRangeId,OBJPROP_TIME2,Time[Bar]);
   }
 }

//+------------------------------------------------------------------+
//| DeleteRanges - Removes all objects created by the indicator      |
//+------------------------------------------------------------------+
void DeleteRanges()
  {
    for (SessionType type=Daily;type<SessionTypes;type++)
      for (int doRangeId=0;doRangeId<=data[type].Range;doRangeId++)
        ObjectDelete(EnumToString(type)+IntegerToString(doRangeId));
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints on screen information                   |
//+------------------------------------------------------------------+
void RefreshScreen(int Bar=0)
  {
    for (SessionType type=Asia;type<SessionTypes;type++)
    {
      if (TimeHour(session[type].ServerTime(Bar))==session[type].SessionHour(SessionOpen))
        CreateRange(type,Bar);

      UpdateRange(type,Bar);
    }

    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      UpdateLabel("lbSessionType"+EnumToString(type),EnumToString(type)+
                  " "+proper(ActionText(session[type].Bias()))+
                  " "+BoolToStr(session[type].Bias()==Action(session[type][ActiveSession].TermDir,InDirection),"Hold","Hedge"),
                  BoolToInt(session[type].IsOpen(),clrWhite,clrDarkGray),16);

      UpdateDirection("lbActiveDir"+EnumToString(type),session[type][ActiveSession].Direction,DirColor(session[type][ActiveSession].Direction),20);
      UpdateDirection("lbActiveBrkDir"+EnumToString(type),session[type][ActiveSession].TermDir,DirColor(session[type][ActiveSession].TermDir));
      
      if (session[type].IsOpen())
        if (TimeHour(session[type].ServerTime(Bar))>session[type].SessionHour(SessionClose)-3)
          UpdateLabel("lbSessionTime"+EnumToString(type),"Late Session ("+IntegerToString(session[type].SessionHour())+")",clrRed);
        else
        if (session[type].SessionHour()>3)
          UpdateLabel("lbSessionTime"+EnumToString(type),"Mid Session ("+IntegerToString(session[type].SessionHour())+")",clrYellow);
        else
          UpdateLabel("lbSessionTime"+EnumToString(type),"Early Session ("+IntegerToString(session[type].SessionHour())+")",clrLawnGreen);
      else
        UpdateLabel("lbSessionTime"+EnumToString(type),"Session Is Closed",clrDarkGray);

      if (session[type].Event(NewBreakout) || session[type].Event(NewReversal))
        UpdateLabel("lbActiveState"+EnumToString(type),EnumToString(session[type][ActiveSession].TermState),clrWhite);
      else
      if (session[type].Event(NewRally) || session[type].Event(NewPullback))
        UpdateLabel("lbActiveState"+EnumToString(type),EnumToString(session[type][ActiveSession].TermState),clrYellow);
      else
      if (session[type][ActiveSession].TermState==Trap)
        UpdateLabel("lbActiveState"+EnumToString(type),BoolToStr(session[type][ActiveSession].Direction==DirectionUp,"Bull","Bear")+
                     " "+EnumToString(session[type][ActiveSession].TermState),clrYellow);
      else
        UpdateLabel("lbActiveState"+EnumToString(type),EnumToString(session[type][ActiveSession].TermState),clrDarkGray);
    }

    if (inpShowTOLines==Yes)
    {
      UpdateLine("lnTop",session[Daily][ActiveSession].Top,STYLE_SOLID,clrForestGreen);
      UpdateLine("lnBottom",session[Daily][ActiveSession].Bottom,STYLE_SOLID,clrFireBrick);
    }
    
    if (inpShowSRLines==Yes)
    {
      UpdateLine("lnSupport",session[Daily][ActiveSession].Support,STYLE_SOLID,clrFireBrick);
      UpdateLine("lnResistance",session[Daily][ActiveSession].Resistance,STYLE_SOLID,clrForestGreen);
    }

    if (inpShowMidLines==Yes)
    {
      UpdateLine("lnActiveMid",session[Daily].Pivot(ActiveSession),STYLE_DOT,clrSteelBlue);
      UpdateLine("lnPriorMid",session[Daily].Pivot(PriorSession),STYLE_SOLID,clrGoldenrod);
      UpdateLine("lnOffMid",session[Daily].Pivot(OffSession),STYLE_SOLID,clrSteelBlue);
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
    session[Daily].Update(indOffMidBuffer,indPriorMidBuffer);
    session[Asia].Update();
    session[Europe].Update();
    session[US].Update();
    
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
    NewLine("lnPriorMid");
    NewLine("lnOffMid");
    
    NewLine("lnSupport");
    NewLine("lnResistance");
    
    NewLine("lnTop");
    NewLine("lnBottom");
    
    session[Daily]        = new CSession(Daily,0,23,inpGMTOffset);
    session[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    session[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    session[US]           = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);
    
    DeleteRanges();
    
    NewLabel("lbhSession","Session",120,240,clrGoldenrod,SCREEN_UR,0);
    NewLabel("lbhState","State",30,240,clrGoldenrod,SCREEN_UR,0);
      
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      data[type].IsOpen   = false;
      data[type].Range    = 0;
      
      NewLabel("lbSessionType"+EnumToString(type),"",100,250+(type*sessionOffset),clrDarkGray,SCREEN_UR,0);
      NewLabel("lbActiveDir"+EnumToString(type),"",30,250+(type*sessionOffset),clrDarkGray,SCREEN_UR,0);
      NewLabel("lbActiveBrkDir"+EnumToString(type),"",20,250+(type*sessionOffset),clrDarkGray,SCREEN_UR,0);
      NewLabel("lbSessionTime"+EnumToString(type),"",100,275+(type*sessionOffset),clrDarkGray,SCREEN_UR,0);
      NewLabel("lbActiveState"+EnumToString(type),"",25,275+(type*sessionOffset),clrDarkGray,SCREEN_UR,0);
    }
    
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
    
    ObjectDelete("lnActiveMid");
    ObjectDelete("lnPriorMid");
    ObjectDelete("lnOffMid");

    ObjectDelete("lnSupport");
    ObjectDelete("lnResistance");

    ObjectDelete("lbhSession");
    ObjectDelete("lbhState");
    
    ObjectDelete("lnTop");
    ObjectDelete("lnBottom");
    
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      delete session[type];

      ObjectDelete("lbSessionType"+EnumToString(type));
      ObjectDelete("lbSessionTime"+EnumToString(type));
      ObjectDelete("lbActiveDir"+EnumToString(type));
      ObjectDelete("lbActiveBrkDir"+EnumToString(type));
      ObjectDelete("lbActiveState"+EnumToString(type));
    }
  }
