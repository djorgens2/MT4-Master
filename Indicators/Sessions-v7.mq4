//+------------------------------------------------------------------+
//|                                                  Sessions-v7.mq4 |
//|                                      Written by Dennis Jorgenson |
//|                                                                  |
//|                                                                  |
//|  02.19.2018  Adapted from i-Sessions.mq4                         |
//|              Orig. Author: KimIV from http://www.kimiv.ru        |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "(c) 2018, Dennis Jorgenson"
#property version   "7.0"
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


//--- Operational Inputs
input int            inpAsiaOpen     = 1;            // Asia Session Opening Hour
input int            inpAsiaClose    = 10;           // Asia Session Closing Hour
input int            inpEuropeOpen   = 8;            // Europe Session Opening Hour
input int            inpEuropeClose  = 18;           // Europe Session Closing Hour
input int            inpUSOpen       = 14;           // US Session Opening Hour
input int            inpUSClose      = 23;           // US Session Closing Hour
input int            inpGMTOffset    = 0;            // Offset from GMT+3
input PeriodType     inpShowMidLines = PeriodTypes;  // Display Mid-Price Lines
input SessionType    inpShowSession  = SessionTypes; // Display Session Comment
input YesNoType      inpShowData     = No;           // Display Session Data Labels

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
  
const int            sessionOffset   = 40;           // Display offset

CSession            *session[SessionTypes];

SessionData          data[SessionTypes];
string               dataDate[SessionTypes];

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
   string        crRangeId;
   
   if (IsChanged(data[Type].IsOpen,true))
   {
     crRangeId                = EnumToString(Type)+IntegerToString(++data[Type].Range);
     
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

   if (TimeHour(session[Type].ServerTime(Bar))==session[Type].SessionHour(SessionClose))
   {
     if (data[Type].IsOpen)
       ObjectSet(urRangeId,OBJPROP_TIME2,Time[Bar]);

     data[Type].IsOpen    = false;
   }

   if (IsChanged(dataDate[Type],TimeToStr(session[Type].ServerTime(Bar),TIME_DATE)))
   {
     data[Type].IsOpen        = false;

     if (TimeDayOfWeek(session[Type].ServerTime(Bar))<6)
       if (TimeHour(session[Type].ServerTime(Bar))>=session[Type].SessionHour(SessionOpen) && TimeHour(session[Type].ServerTime(Bar))<session[Type].SessionHour(SessionClose))
         CreateRange(Type, Bar);
   }
   else
   if (TimeHour(session[Type].ServerTime(Bar))==session[Type].SessionHour(SessionOpen))
     CreateRange(Type,Bar);
   else
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
      UpdateRange(type,Bar);

    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      UpdateLabel("lbSessionType"+EnumToString(type),EnumToString(type)+
                  " "+proper(ActionText(session[type][ActiveSession].Bias))+
                  " "+BoolToStr(session[type][ActiveSession].Bias==Action(session[type][ActiveSession].Direction,InDirection),"Hold","Hedge"),
                  BoolToInt(session[type].IsOpen(),clrWhite,clrDarkGray),16);

      UpdateDirection("lbActiveDir"+EnumToString(type),session[type][ActiveSession].Direction,DirColor(session[type][ActiveSession].Direction),20);
      UpdateDirection("lbActiveBrkDir"+EnumToString(type),session[type][ActiveSession].BreakoutDir,DirColor(session[type][ActiveSession].BreakoutDir));
      
      if (inpShowMidLines!=PeriodTypes)
        UpdateLine("lnMid"+EnumToString(type),session[type].Pivot(inpShowMidLines),STYLE_SOLID,SessionColor(type));
      
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
        UpdateLabel("lbActiveState"+EnumToString(type),EnumToString(session[type][ActiveSession].State),clrWhite);
      else
      if (session[type].Event(NewRally) || session[type].Event(NewPullback))
        UpdateLabel("lbActiveState"+EnumToString(type),EnumToString(session[type][ActiveSession].State),clrYellow);
      else
        UpdateLabel("lbActiveState"+EnumToString(type),EnumToString(session[type][ActiveSession].State),clrDarkGray);
    }
    
    if (inpShowSession!=SessionTypes)
      session[inpShowSession].RefreshScreen();
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
    session[Asia].Update();
    session[Europe].Update();
    session[US].Update();
    
    session[Daily].Update(indOffMidBuffer,indPriorMidBuffer,indFractalBuffer);

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

    session[Daily]        = new CSession(Daily,0,23,inpGMTOffset);
    session[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    session[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    session[US]           = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);
    
    DeleteRanges();
    
    if (inpShowData==Yes)
    {
      NewLabel("lbhSession","Session",120,240,clrGoldenrod,SCREEN_UR,0);
      NewLabel("lbhState","State",30,240,clrGoldenrod,SCREEN_UR,0);
      
      for (SessionType type=Daily;type<SessionTypes;type++)
      {
        data[type].IsOpen   = false;
        data[type].Range    = 0;
        dataDate[type]      = TimeToStr(session[type].ServerTime(Bars-1),TIME_DATE);
      
        NewLabel("lbSessionType"+EnumToString(type),"",100,250+(type*sessionOffset),clrDarkGray,SCREEN_UR,0);
        NewLabel("lbActiveDir"+EnumToString(type),"",30,250+(type*sessionOffset),clrDarkGray,SCREEN_UR,0);
        NewLabel("lbActiveBrkDir"+EnumToString(type),"",20,250+(type*sessionOffset),clrDarkGray,SCREEN_UR,0);
        NewLabel("lbSessionTime"+EnumToString(type),"",100,275+(type*sessionOffset),clrDarkGray,SCREEN_UR,0);
        NewLabel("lbActiveState"+EnumToString(type),"",25,275+(type*sessionOffset),clrDarkGray,SCREEN_UR,0);

        NewLine("lnMid"+EnumToString(type));
      }
    }
          
    for (int bar=Bars-1;bar>0;bar--)
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
