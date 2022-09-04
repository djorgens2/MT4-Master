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
input FractalType    inpFractalLines    = FractalTypes;    // Fractal line to show?
input YesNoType      inpShowComment     = No;              // Show session data in comment?
input DataPosition   inpShowData        = dpNone;          // Indicator data position

CSession            *session            = new CSession(inpType,inpHourOpen,inpHourClose,inpHourOffset);

bool                 sessionOpen        = false;
int                  sessionRange       = 0;

datetime             sessionOpenTime;
double               sessionHigh;
double               sessionLow;
string               sessionIndex       = IntegerToString(inpShowData);
int                  sessionOffset      = inpShowData*40;

//+------------------------------------------------------------------+
//| CreateRange - Paints the session boxes                           |
//+------------------------------------------------------------------+
void CreateRange(int Bar=0)
 {
   string        crRangeId;

   if (IsChanged(sessionOpen,true))
   {
     crRangeId          = EnumToString(inpType)+IntegerToString(++sessionRange);
     
     sessionOpenTime    = Time[Bar];
     sessionHigh        = High[Bar];
     sessionLow         = Low[Bar];
   
     ObjectCreate(crRangeId,OBJ_RECTANGLE,0,sessionOpenTime,sessionHigh,sessionOpenTime,sessionLow);
   
     ObjectSet(crRangeId, OBJPROP_STYLE,STYLE_SOLID);
     ObjectSet(crRangeId, OBJPROP_COLOR,Color(inpType,Dark));
     ObjectSet(crRangeId, OBJPROP_BACK,true);     
   }
 }

//+------------------------------------------------------------------+
//| UpdateRange - Repaints the session box                           |
//+------------------------------------------------------------------+
void UpdateRange(int Bar=0)
  {
    static string urLastRange   = TimeToStr(session.ServerTime(Bars-1),TIME_DATE);
    string        urRangeId     = EnumToString(inpType)+IntegerToString(sessionRange);

    if (TimeHour(session.ServerTime(Bar))==inpHourClose)
    {
      if (sessionOpen)
        ObjectSet(urRangeId,OBJPROP_TIME2,Time[Bar]);

      sessionOpen                = false;
    }

    if (IsChanged(urLastRange,TimeToStr(session.ServerTime(Bar),TIME_DATE)))
    {
      sessionOpen               = false;
              
      if (TimeDayOfWeek(session.ServerTime(Bar))<6)
        if (TimeHour(session.ServerTime(Bar))>=inpHourOpen && TimeHour(session.ServerTime(Bar))<inpHourClose)
          CreateRange(Bar);
    }
    else
    if (TimeHour(session.ServerTime(Bar))==inpHourOpen)
      CreateRange(Bar);
    else
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
      UpdateRange(Bar);

    if (inpFractalLines!=FractalTypes)
    {
      UpdateLine("lnS_ActiveMid:"+sessionIndex,session.Pivot(ActiveSession),STYLE_SOLID,clrGoldenrod);
      UpdateLine("lnS_Low:"+sessionIndex,session[inpFractalLines].Low,STYLE_DOT,clrFireBrick);
      UpdateLine("lnS_High:"+sessionIndex,session[inpFractalLines].High,STYLE_DOT,clrForestGreen);
      UpdateLine("lnS_Base:"+sessionIndex,session.Price(inpFractalLines,fpBase),STYLE_SOLID,
                             BoolToInt(IsEqual(session[inpFractalLines].Direction,DirectionUp),clrLawnGreen,clrRed));
      UpdateLine("lnS_Root:"+sessionIndex,session.Price(inpFractalLines,fpRoot),STYLE_SOLID,
                             BoolToInt(IsEqual(session[inpFractalLines].Direction,DirectionUp),clrRed,clrLawnGreen));
      UpdateLine("lnS_Expansion:"+sessionIndex,session.Price(inpFractalLines,fpExpansion),STYLE_DOT,clrGoldenrod);
      UpdateLine("lnS_Retrace:"+sessionIndex,session.Price(inpFractalLines,fpRetrace),STYLE_DOT,clrSteelBlue);      
      UpdateLine("lnS_Support:"+sessionIndex,session[ActiveSession].Support,STYLE_SOLID,clrMaroon);
      UpdateLine("lnS_Resistance:"+sessionIndex,session[ActiveSession].Resistance,STYLE_SOLID,clrForestGreen);
      UpdateLine("lnS_pSupport:"+sessionIndex,session[PriorSession].Support,STYLE_DASH,clrMaroon);
      UpdateLine("lnS_pResistance:"+sessionIndex,session[PriorSession].Resistance,STYLE_DASH,clrForestGreen);
      //UpdateLine("lnS_Support:"+sessionIndex,session[sftCorrection].Support,STYLE_SOLID,clrMaroon);
      //UpdateLine("lnS_Resistance:"+sessionIndex,session[sftCorrection].Resistance,STYLE_SOLID,clrForestGreen);
      //UpdateLine("lnS_CorrectionHi:"+sessionIndex,session[sftCorrection].High,STYLE_DASH,clrWhite);
      //UpdateLine("lnS_CorrectionLo:"+sessionIndex,session[sftCorrection].Low,STYLE_DASH,clrWhite);
      
      //for (FiboLevel fl=Fibo161;fl<FiboLevels;fl++)
      //  UpdateLine("lnS_"+EnumToString(fl)+":"+sessionIndex,session.Forecast(inpFractalLines,Expansion,fl),STYLE_DASH,clrYellow);
    }
    
    if (inpShowData>dpNone)
    {
      UpdateLabel("lbSessionType"+sessionIndex,EnumToString(session.Type())+" "+proper(ActionText(session[ActiveSession].Bias))+" "+
        BoolToStr(session[ActiveSession].Bias==Action(session[ActiveSession].Direction,InDirection),"Hold","Hedge"),BoolToInt(session.IsOpen(),clrWhite,clrDarkGray),16);
      UpdateDirection("lbActiveDir"+sessionIndex,session[ActiveSession].Direction,Color(session[ActiveSession].Direction),20);
      
      if (session[ActiveSession].State==Trap)
        UpdateLabel("lbActiveState"+sessionIndex,BoolToStr(session[ActiveSession].Direction==DirectionUp,"Bull Trap","Bear Trap"),clrYellow ,8);
      else
        UpdateLabel("lbActiveState"+sessionIndex,EnumToString(session[ActiveSession].State),Color(session[ActiveSession].Direction),8);
            
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

      UpdateDirection("lbActiveBrkDir"+sessionIndex,session[ActiveSession].BreakoutDir,Color(session[ActiveSession].BreakoutDir));
    }
    
    if (inpShowComment==Yes)
      Comment(session.CommentStr());
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
void TestEvent(EventType Event)
  {
    string text         = "";

    if (session[Event]&&session[NewBreakout])
//    if (session.ActiveEvent())
      Append(text,EnumToString(inpType)+" "+session.ActiveEventStr(),"\n");

    if (StringLen(text)>0)
      Pause("ActiveEvent("+EnumToString(Event)+")\n\n"+text,"Event Check()");
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

    TestEvent(NewTerm);

    return(rates_total);
  }
  
       
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    IndicatorShortName("Sessions-v6:"+EnumToString(session.Type()));
    
    SetIndexBuffer(0,indPriorMidBuffer);
    SetIndexEmptyValue(0, 0.00);
    SetIndexStyle(0,DRAW_SECTION);

    SetIndexBuffer(1,indOffMidBuffer);
    SetIndexEmptyValue(1, 0.00);
    SetIndexStyle(1,DRAW_SECTION);
    
    SetIndexBuffer(2,indFractalBuffer);
    SetIndexEmptyValue(2, 0.00);
    SetIndexStyle(2,DRAW_SECTION);
    
    if (inpType!=Daily)
    {
      SetIndexStyle(0,DRAW_SECTION,STYLE_SOLID,1,clrMaroon);
      SetIndexStyle(1,DRAW_SECTION,STYLE_DOT,1,clrMaroon);
      SetIndexStyle(2,DRAW_SECTION,STYLE_SOLID,1,clrDodgerBlue);
    }
    
    NewLine("lnS_ActiveMid:"+sessionIndex);
    NewLine("lnS_High:"+sessionIndex);
    NewLine("lnS_Low:"+sessionIndex);    
    NewLine("lnS_Base:"+sessionIndex);
    NewLine("lnS_Root:"+sessionIndex);    
    NewLine("lnS_Expansion:"+sessionIndex);
    NewLine("lnS_Retrace:"+sessionIndex);
    NewLine("lnS_Support:"+sessionIndex);
    NewLine("lnS_Resistance:"+sessionIndex);
    NewLine("lnS_pSupport:"+sessionIndex);
    NewLine("lnS_pResistance:"+sessionIndex);
    NewLine("lnS_CorrectionHi:"+sessionIndex);
    NewLine("lnS_CorrectionLo:"+sessionIndex);
    
    for (FiboLevel fl=Fibo161;fl<FiboLevels;fl++)
      NewLine("lnS_"+EnumToString(fl)+":"+sessionIndex);
    
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

    delete session;    

    ObjectDelete("lnS_ActiveMid:"+sessionIndex);
    ObjectDelete("lnS_High:"+sessionIndex);
    ObjectDelete("lnS_Low:"+sessionIndex);
    ObjectDelete("lnS_Base:"+sessionIndex);
    ObjectDelete("lnS_Root:"+sessionIndex);
    ObjectDelete("lnS_Expansion:"+sessionIndex);
    ObjectDelete("lnS_Retrace:"+sessionIndex);
    ObjectDelete("lnS_Support:"+sessionIndex);
    ObjectDelete("lnS_Resistance:"+sessionIndex);
    ObjectDelete("lnS_CorrectionHi:"+sessionIndex);
    ObjectDelete("lnS_CorrectionLo:"+sessionIndex);    

    for (FiboLevel fl=Fibo161;fl<FiboLevels;fl++)
      ObjectDelete("lnS_"+EnumToString(fl)+":"+sessionIndex);

    ObjectDelete("lbActiveBrkDir"+sessionIndex);
    ObjectDelete("lbSessionType"+sessionIndex);
    ObjectDelete("lbActiveDir"+sessionIndex);
    ObjectDelete("lbSessionTime"+sessionIndex);
    ObjectDelete("lbActiveState"+sessionIndex);

    ObjectDelete("lbhSession");
    ObjectDelete("lbhActive");
  }
