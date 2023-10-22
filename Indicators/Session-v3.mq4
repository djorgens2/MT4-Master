//+------------------------------------------------------------------+
//|                                                   Session-v3.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "3.00"
#property strict
#property indicator_chart_window

#property indicator_buffers   3
#property indicator_plots     3

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
#property indicator_color3  clrGoldenrod;
#property indicator_style3  STYLE_SOLID;
#property indicator_width3  1

double indPriorBuffer[];
double indOffBuffer[];
double indFractalBuffer[];

//-- Option Enums
enum ShowOptions
     {
       ShowNone,             // None
       ShowActiveSession,    // Active Session
       ShowPriorSession,     // Prior Session
       ShowOffSession,       // Off Session
       ShowOrigin,           // Origin
       ShowTrend,            // Trend
       ShowTerm              // Term
     };

//--- Indicator Inputs
input SessionType    inpType            = SessionTypes;    // Indicator session
input int            inpAsiaOpen        = 1;               // Asia Session Opening Hour
input int            inpAsiaClose       = 10;              // Asia Session Closing Hour
input int            inpEuropeOpen      = 8;               // Europe Session Opening Hour
input int            inpEuropeClose     = 18;              // Europe Session Closing Hour
input int            inpUSOpen          = 14;              // US Session Opening Hour
input int            inpUSClose         = 23;              // US Session Closing Hour
input int            inpHourOffset      = 0;               // Time offset EOD NY 5:00pm
input YesNoType      inpShowRange       = No;              // Show Session Ranges
input FractalType    inpShowFlags       = FractalTypes;    // Show Event Flags
input ShowOptions    inpShowOption      = ShowNone;        // Show Fibonacci/Session Pivots

CSession            *s[SessionTypes];

PeriodType    ShowSession = PeriodTypes; 
FractalType   ShowFractal = FractalTypes;
string        sObjectStr  = "[s3]";

//+------------------------------------------------------------------+
//| FibonacciStr - Repaint screen elements                           |
//+------------------------------------------------------------------+
string FibonacciStr(string Type, FibonacciRec &Fibonacci)
  {
    string text    = Type;

    Append(text,EnumToString(Fibonacci.Level));
    Append(text,DoubleToStr(Fibonacci.Pivot,Digits));

//    Append(text,"      Now/Min/Max:   ","\n");
    Append(text,DoubleToStr(Fibonacci.Percent[Now]*100,1)+"%");
    Append(text,DoubleToStr(Fibonacci.Percent[Min]*100,1)+"%");
    Append(text,DoubleToStr(Fibonacci.Percent[Max]*100,1)+"%");

    return text;
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Repaint screen elements                          |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string text    = "";
    
    //-- Update Control Panel (Session)
    for (SessionType type=Daily;type<SessionTypes;type++)
      if (ObjectGet(sObjectStr+"bxh-Session"+EnumToString(type),OBJPROP_BGCOLOR)==clrBoxOff||s[type].Event(NewTerm)||s[type].Event(NewHour))
      {
        UpdateBox(sObjectStr+"bxh-Session"+EnumToString(type),Color(s[type][Term].Direction,IN_DARK_DIR));
        UpdateBox(sObjectStr+"bxb-OpenInd"+EnumToString(type),BoolToInt(s[type].IsOpen(),clrYellow,clrBoxOff));
      }

    if (ShowSession<PeriodTypes)
    {
      UpdateLine(sObjectStr+"lnS_ActiveMid:"+EnumToString(inpType),s[inpType].Pivot(ShowSession),STYLE_SOLID,clrGoldenrod);
      UpdateLine(sObjectStr+"lnS_Low:"+EnumToString(inpType),s[inpType][ShowSession].Low,STYLE_DOT,clrMaroon);
      UpdateLine(sObjectStr+"lnS_High:"+EnumToString(inpType),s[inpType][ShowSession].High,STYLE_DOT,clrForestGreen);
      
      if (IsEqual(ShowSession,ActiveSession))
      {
        UpdateLine(sObjectStr+"lnS_Support:"+EnumToString(inpType),s[inpType][PriorSession].Low,STYLE_SOLID,clrMaroon);
        UpdateLine(sObjectStr+"lnS_Resistance:"+EnumToString(inpType),s[inpType][PriorSession].High,STYLE_SOLID,clrForestGreen);
      }
    } 
    else
    if (ShowFractal<FractalTypes)
    {
      int bar      = 80;

      UpdateRay(sObjectStr+"lnS_Origin:"+EnumToString(inpType),bar,s[inpType][ShowFractal].Fractal[fpOrigin],-8);
      UpdateRay(sObjectStr+"lnS_Base:"+EnumToString(inpType),bar,s[inpType][ShowFractal].Fractal[fpBase],-8);
      UpdateRay(sObjectStr+"lnS_Root:"+EnumToString(inpType),bar,s[inpType][ShowFractal].Fractal[fpRoot],-8,0,
                             BoolToInt(IsEqual(s[inpType][ShowFractal].Direction,DirectionUp),clrRed,clrLawnGreen));
      UpdateRay(sObjectStr+"lnS_Expansion:"+EnumToString(inpType),bar,s[inpType][ShowFractal].Fractal[fpExpansion],-8,0,
                             BoolToInt(IsEqual(s[inpType][ShowFractal].Direction,DirectionUp),clrLawnGreen,clrRed));
      UpdateRay(sObjectStr+"lnS_Retrace:"+EnumToString(inpType),bar,s[inpType][ShowFractal].Fractal[fpRetrace],-8,0);
      UpdateRay(sObjectStr+"lnS_Recovery:"+EnumToString(inpType),bar,s[inpType][ShowFractal].Fractal[fpRecovery],-8,0);

      for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
      {
        UpdateRay(sObjectStr+"lnS_"+EnumToString(fibo)+":"+EnumToString(inpType),bar,s[inpType].Price(fibo,ShowFractal,Extension),-8,0,Color(s[inpType][ShowFractal].Direction,IN_DARK_DIR));
        UpdateText(sObjectStr+"lnT_"+EnumToString(fibo)+":"+EnumToString(inpType),"",s[inpType].Price(fibo,ShowFractal,Extension),-5,Color(s[inpType][ShowFractal].Direction,IN_DARK_DIR));
      }

      for (FractalPoint point=fpBase;IsBetween(point,fpBase,fpRecovery);point++)
        UpdateText(sObjectStr+"lnT_"+fp[point]+":"+EnumToString(inpType),"",s[inpType][ShowFractal].Fractal[point],-6);
    }

    if (inpType<SessionTypes)
    {
      Append(text,EnumToString(inpType));
      Append(text,BoolToStr(s[inpType].IsOpen(),BoolToStr(TimeHour(s[inpType].ServerTime())>s[inpType].HourClose()-3,"Late",
                                                BoolToStr(TimeHour(s[inpType].ServerTime())>3,"Mid","Early"))+" Session","Session Closed"));
      Append(text,(string)s[inpType].SessionHour()," [");
      Append(text,DirText(s[inpType][ActiveSession].Direction),"]");
      Append(text,ActionText(s[inpType][ActiveSession].Lead));
      Append(text,BoolToStr(s[inpType][ActiveSession].Lead==s[inpType][ActiveSession].Bias,"","Hedge ["+
                                                DirText(Direction(s[inpType][ActiveSession].Bias,InAction))+"]"));

      for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
      {
        Append(text,"------- Fibonacci ["+EnumToString(type)+"] ------------------------","\n\n");
        Append(text," "+DirText(s[inpType][type].Direction),"\n");
        Append(text,EnumToString(s[inpType][type].State));
        Append(text,"["+ActionText(s[inpType][type].Pivot.Lead)+"]");
        Append(text,BoolToStr(IsEqual(s[inpType][type].Pivot.Bias,s[inpType][type].Pivot.Lead),"","Hedge"));
        Append(text,BoolToStr(IsEqual(s[inpType][type].Event,NoEvent),""," **"+EventText(s[inpType][type].Event)));
        Append(text,FibonacciStr("   Ext: ",s[inpType][type].Extension),"\n");
        Append(text,FibonacciStr("   Ret: ",s[inpType][type].Retrace),"\n");
      }

      Append(text,s[inpType].ActiveEventStr(),"\n\n");

      Comment(text);
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
    for (SessionType type=Daily;type<SessionTypes;type++)
      if (IsEqual(type,inpType))
      {
        s[type].Update(indPriorBuffer,indOffBuffer);
        s[type].Fractal(indFractalBuffer);
      }
      else s[type].Update();

    RefreshScreen();

    return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    SetIndexBuffer(0,indPriorBuffer);
    SetIndexEmptyValue(0, 0.00);
    SetIndexStyle(0,DRAW_SECTION);

    SetIndexBuffer(1,indOffBuffer);
    SetIndexEmptyValue(1, 0.00);
    SetIndexStyle(1,DRAW_SECTION);
    
    SetIndexBuffer(2,indFractalBuffer);
    SetIndexEmptyValue(2, 0.00);
    SetIndexStyle(2,DRAW_SECTION);
    
    s[Daily]   = new CSession(Daily,0,23,inpHourOffset,false,(FractalType)BoolToInt(inpType==Daily,inpShowFlags,FractalTypes));
    s[Asia]    = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpHourOffset,inpShowRange==Yes,(FractalType)BoolToInt(inpType==Asia,inpShowFlags,FractalTypes));
    s[Europe]  = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpHourOffset,inpShowRange==Yes,(FractalType)BoolToInt(inpType==Europe,inpShowFlags,FractalTypes));
    s[US]      = new CSession(US,inpUSOpen,inpUSClose,inpHourOffset,inpShowRange==Yes,(FractalType)BoolToInt(inpType==US,inpShowFlags,FractalTypes));

    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      DrawBox(sObjectStr+"bxh-Session"+EnumToString(type),120*(SessionTypes-type),5,110,20,C'60,60,60',BORDER_RAISED,SCREEN_UR);
      DrawBox(sObjectStr+"bxb-OpenInd"+EnumToString(type),120*(SessionTypes-type)-4,9,7,12,C'60,60,60',BORDER_RAISED,SCREEN_UR);
      NewLabel(sObjectStr+"lbh-Session"+EnumToString(type),lpad(EnumToString(type)," ",4),(120*(SessionTypes-type))-70,7,clrWhite,SCREEN_UR);
    }

    if (inpShowOption>ShowNone)
    {
      if (inpShowOption<ShowOrigin)
      {
        if (inpShowOption==ShowActiveSession) ShowSession = ActiveSession;
        if (inpShowOption==ShowOffSession)    ShowSession = OffSession;
        if (inpShowOption==ShowPriorSession)  ShowSession = PriorSession;

        NewLine(sObjectStr+"lnS_ActiveMid:"+EnumToString(inpType));
        NewLine(sObjectStr+"lnS_High:"+EnumToString(inpType));
        NewLine(sObjectStr+"lnS_Low:"+EnumToString(inpType));    
        NewLine(sObjectStr+"lnS_Support:"+EnumToString(inpType));
        NewLine(sObjectStr+"lnS_Resistance:"+EnumToString(inpType));
      }
      else
      {    
        if (inpShowOption==ShowOrigin)        ShowFractal = Origin;
        if (inpShowOption==ShowTrend)         ShowFractal = Trend;
        if (inpShowOption==ShowTerm)          ShowFractal = Term;

        NewRay(sObjectStr+"lnS_Origin:"+EnumToString(inpType),STYLE_DOT,clrWhite,Never);
        NewRay(sObjectStr+"lnS_Base:"+EnumToString(inpType),STYLE_SOLID,clrYellow,Never);
        NewRay(sObjectStr+"lnS_Root:"+EnumToString(inpType),STYLE_SOLID,clrDarkGray,Never);
        NewRay(sObjectStr+"lnS_Expansion:"+EnumToString(inpType),STYLE_SOLID,clrDarkGray,Never);
        NewRay(sObjectStr+"lnS_Retrace:"+EnumToString(inpType),STYLE_DOT,clrGoldenrod,Never);
        NewRay(sObjectStr+"lnS_Recovery:"+EnumToString(inpType),STYLE_DOT,clrSteelBlue,Never);

        for (FractalPoint point=fpBase;IsBetween(point,fpBase,fpRecovery);point++)
          NewText(sObjectStr+"lnT_"+fp[point]+":"+EnumToString(inpType),fp[point]);

        for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
        {
          NewRay(sObjectStr+"lnS_"+EnumToString(fibo)+":"+EnumToString(inpType),STYLE_DOT,clrDarkGray,Never);
          NewText(sObjectStr+"lnT_"+EnumToString(fibo)+":"+EnumToString(inpType),DoubleToStr(fibonacci[fibo]*100,1)+"%");
        }
      }
    }

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    for (SessionType type=Daily;type<SessionTypes;type++)
      delete s[type];
  }
