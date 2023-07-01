//+------------------------------------------------------------------+
//|                                                   Session-v2.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict
#property indicator_chart_window

#property indicator_buffers   3
#property indicator_plots     3

#include <Class/sess-v2.mqh>

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
input int            inpHourOpen        = NoValue;         // Session Opening Hour
input int            inpHourClose       = NoValue;         // Session Closing Hour
input int            inpHourOffset      = 0;               // Time offset EOD NY 5:00pm
input YesNoType      inpShowRange       = No;              // Show Session Ranges
input ShowOptions    inpShowOption      = ShowNone;        // Show Boundary Options

CSession            *s                  = new CSession(inpType,inpHourOpen,inpHourClose,inpHourOffset,false);

PeriodType    ShowSession = PeriodTypes; 
FractalType   ShowFractal = FractalTypes;
string        sObjectStr  = "[s2]";

//+------------------------------------------------------------------+
//| RefreshScreen - Repaint screen elements                          |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string text    = "";
    
    Append(text,EnumToString(inpType));
    Append(text,BoolToStr(s.IsOpen(),BoolToStr(TimeHour(s.ServerTime())>inpHourClose-3,"Late",BoolToStr(TimeHour(s.ServerTime())>3,"Mid","Early"))+" Session","Session Closed"));
    Append(text,(string)s.SessionHour()," [");
    Append(text,DirText(s[ActiveSession].Direction),"]\n");
    Append(text,ActionText(s[ActiveSession].Lead));
    Append(text,BoolToStr(s[ActiveSession].Lead==s[ActiveSession].Bias,"","Hedge ["+DirText(s[ActiveSession].Bias,InAction)+"]"));
    Append(text,s.ActiveEventStr(),"\n\n");
    
    Comment(text);

    if (ShowSession<PeriodTypes)
    {
      UpdateLine(sObjectStr+"lnS_ActiveMid:"+EnumToString(inpType),s.Pivot(ShowSession),STYLE_SOLID,clrGoldenrod);
      UpdateLine(sObjectStr+"lnS_Low:"+EnumToString(inpType),s[ShowSession].Low,STYLE_DOT,clrMaroon);
      UpdateLine(sObjectStr+"lnS_High:"+EnumToString(inpType),s[ShowSession].High,STYLE_DOT,clrForestGreen);
      //UpdateLine("lnS_Support:"+EnumToString(inpType),s[ShowSession].Support,STYLE_SOLID,clrMaroon);
      //UpdateLine("lnS_Resistance:"+EnumToString(inpType),s[ShowSession].Resistance,STYLE_SOLID,clrForestGreen);
    }
    else
    if (ShowFractal<FractalTypes)
    {
      UpdateLine(sObjectStr+"lnS_Origin:"+EnumToString(inpType),s[ShowFractal].Fractal[fpOrigin],STYLE_DOT,clrWhite);
      UpdateLine(sObjectStr+"lnS_Base:"+EnumToString(inpType),s[ShowFractal].Fractal[fpBase],STYLE_SOLID,clrYellow);
      UpdateLine(sObjectStr+"lnS_Root:"+EnumToString(inpType),s[ShowFractal].Fractal[fpRoot],STYLE_SOLID,
                             BoolToInt(IsEqual(s[ShowFractal].Direction,DirectionUp),clrRed,clrLawnGreen));
      UpdateLine(sObjectStr+"lnS_Expansion:"+EnumToString(inpType),s[ShowFractal].Fractal[fpExpansion],STYLE_SOLID,
                             BoolToInt(IsEqual(s[ShowFractal].Direction,DirectionUp),clrLawnGreen,clrRed));
      UpdateLine(sObjectStr+"lnS_Retrace:"+EnumToString(inpType),s[ShowFractal].Fractal[fpRetrace],STYLE_DOT,clrGoldenrod);      
      UpdateLine(sObjectStr+"lnS_Recovery:"+EnumToString(inpType),s[ShowFractal].Fractal[fpRecovery],STYLE_DOT,clrSteelBlue);

      for (FiboLevel fl=Fibo161;fl<FiboLevels;fl++)
        UpdateLine(sObjectStr+"lnS_"+EnumToString(fl)+":"+EnumToString(inpType),s.Forecast(ShowFractal,Extension,fl),STYLE_SOLID,clrDarkGray);

//      Append(alert,BoolToStr(s[ShowFractal].Event>NoEvent||s[Origin].Event>NoEvent,s.ActiveEventStr()+"\n\n"));
    }

    //if (s[NewDirection])
    //  Arrow("[sv2]Direction"+TimeToStr(TimeCurrent()),(ArrowType)BoolToInt(s[ActiveSession].Direction==DirectionUp,ArrowUp,ArrowDown),Color(s[ActiveSession].Direction,IN_CHART_DIR));
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
//    Print(DoubleToStr(extension(s[Origin].Fractal[fpBase],s[Origin].Fractal[fpRoot],s[Origin].Fractal[fpExpansion],InPercent),1)+"%");
    s.Update(indPriorBuffer,indOffBuffer);
    s.Fractal(indFractalBuffer);

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

        NewLine(sObjectStr+"lnS_Origin:"+EnumToString(inpType));
        NewLine(sObjectStr+"lnS_Base:"+EnumToString(inpType));
        NewLine(sObjectStr+"lnS_Root:"+EnumToString(inpType));    
        NewLine(sObjectStr+"lnS_Expansion:"+EnumToString(inpType));
        NewLine(sObjectStr+"lnS_Retrace:"+EnumToString(inpType));
        NewLine(sObjectStr+"lnS_Recovery:"+EnumToString(inpType));
      }

      for (FiboLevel fl=Fibo161;fl<FiboLevels;fl++)
        NewLine(sObjectStr+"lnS_"+EnumToString(fl)+":"+EnumToString(inpType));
    }

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete s;
  }
