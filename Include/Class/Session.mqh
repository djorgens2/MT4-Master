//+------------------------------------------------------------------+
//|                                                     CSession.mqh |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict

#include <Class/Fractal.mqh>

const color          AsiaColor       = C'0,32,0';    // Asia session box color
const color          EuropeColor     = C'48,0,0';    // Europe session box color
const color          USColor         = C'0,0,56';    // US session box color
const color          DailyColor      = C'64,64,0';   // US session box color

class CSession : public CFractal
  {

protected:

         //-- Period Types
         enum PeriodType
         {
           OffSession,    // Off-Session
           PriorSession,  // Prior (Closed) Session
           ActiveSession, // Active (Open) Session
           PeriodTypes    // None
         };

         //-- Session Types
         enum SessionType
         {
           Daily,
           Asia,
           Europe,
           US,
           SessionTypes  // None
         };

         struct SessionRec
         {
           int            Direction;
           int            Bias;
           int            Lead;
           double         High;
           double         Low;
         };

         struct BufferRec
         {
           double        Price[];
         };

private:

         //--- Panel Indicators
         string           indSN;
         int              indWinId;

         //--- Private Class properties
         SessionType      sType;

         bool             sIsOpen;
         bool             sShowRanges;
         string           sObjectStr;

         int              sHourOpen;
         int              sHourClose;
         int              sHourOffset;

         int              sBar;
         int              sBars;
         int              sBarDay;
         int              sBarHour;
         
         void             CreateRange(void);
         void             UpdateRange(void);
         void             UpdateBuffers(void);

         void             InitSession(EventType Event);
         void             UpdatePanel(void);
         void             UpdateSession(void);
         void             OpenSession(void);
         void             CloseSession(void);

         SessionRec       srec[PeriodTypes];
         BufferRec        sbuf[PeriodTypes];
         
public:

                          CSession(SessionType Type, int HourOpen, int HourClose, int HourOffset, bool ShowRange, FractalType ShowFlags);
                         ~CSession();

         void             Update(void);
         void             Update(double &PriorBuffer[], double &OffBuffer[]);

         datetime         ServerTime(void)  {return Time[sBar]+(PERIOD_H1*60*sHourOffset);};
         int              SessionHour(void) {return BoolToInt(IsOpen(),TimeHour(ServerTime())-sHourOpen+1,NoValue);};
         int              HourOpen(void)    {return sHourOpen;};
         int              HourClose(void)   {return sHourClose;};
      
         bool             IsOpen(void);
         bool             IsOpen(int HourOpen, int HourClose);
         color            Color(SessionType Type, GammaType Gamma);

         double           Pivot(const PeriodType Period)       {return fdiv(srec[Period].High+srec[Period].Low,2,Digits);};
         BufferRec        Buffer(PeriodType Period)            {return sbuf[Period];};

         SessionRec       operator[](const PeriodType Period)  {return srec[Period];};

         string           BufferStr(PeriodType Period);
         string           SessionStr(string Title="");
  };

//+------------------------------------------------------------------+
//| CreateRange - Creates active session frames on Session Open      |
//+------------------------------------------------------------------+
void CSession::CreateRange(void)
 {
   if (sShowRanges)
   {
     string range       = sObjectStr+EnumToString(sType)+":"+TimeToStr(Time[sBar],TIME_DATE);

     ObjectCreate(range,OBJ_RECTANGLE,0,Time[sBar],srec[ActiveSession].High,Time[sBar],srec[ActiveSession].Low);

     ObjectSet(range, OBJPROP_STYLE,STYLE_SOLID);
     ObjectSet(range, OBJPROP_COLOR,Color(sType,Dark));
     ObjectSet(range, OBJPROP_BACK,true);
   }
 }

//+------------------------------------------------------------------+
//| UpdateRange - Repaints active session frame                      |
//+------------------------------------------------------------------+
void CSession::UpdateRange(void)
  {
    if (sShowRanges)
    {
      string range       = sObjectStr+EnumToString(sType)+":"+TimeToStr(Time[sBar],TIME_DATE);

      if (Event(NewHour))
        if (sIsOpen||Event(SessionClose))
          ObjectSet(range,OBJPROP_TIME2,Time[sBar]);

      if (sIsOpen)
      {
        if (Event(NewHigh))
          ObjectSet(range,OBJPROP_PRICE1,srec[ActiveSession].High);

        if (Event(NewLow))
          ObjectSet(range,OBJPROP_PRICE2,srec[ActiveSession].Low);
      }
    }
  }

//+------------------------------------------------------------------+
//| UpdateSession - Sets active state, bounds and alerts on the tick |
//+------------------------------------------------------------------+
void CSession::UpdateSession(void)
  {
    int direction          = Direction(Close[sBar]-BoolToDouble(IsOpen(),Pivot(OffSession),Pivot(PriorSession)));

    SessionRec session     = srec[ActiveSession];
    AlertType  alert       = (AlertType)BoolToInt(IsEqual(srec[ActiveSession].Direction,direction),Nominal,Notify);

    if (IsHigher(High[sBar],srec[ActiveSession].High))
    {
      SetEvent(NewHigh,alert,srec[ActiveSession].High);
      SetEvent(NewBoundary,alert,session.High);
    }

    if (IsLower(Low[sBar],srec[ActiveSession].Low))
    {
      SetEvent(NewLow,alert,srec[ActiveSession].Low);
      SetEvent(NewBoundary,alert,session.Low);
    }

    if (Event(NewBoundary))
    {
      if (DirectionChanged(srec[ActiveSession].Direction,Direction(Pivot(ActiveSession)-BoolToDouble(IsOpen(),Pivot(PriorSession),Pivot(OffSession)))))
        SetEvent(NewDirection,Nominal);
      
      if (Event(NewHigh)&&Event(NewLow))  //-- Only occurs in history
      {
        SetEvent(AdverseEvent,BoolToAlert(High[sBar]>srec[PriorSession].High&&Low[sBar]<srec[PriorSession].Low,Major,Minor),
          BoolToDouble(IsEqual(srec[ActiveSession].Lead,OP_BUY),srec[ActiveSession].High,srec[ActiveSession].Low,Digits));

        if (Event(AdverseEvent,Major))
          Print(TimeToStr(Time[sBar])+":"+sObjectStr+":"+EnumToString(Alert(AdverseEvent))+":Outside Reversal Anomaly; Please Verify");
      }
      else
        if (IsChanged(srec[ActiveSession].Lead,BoolToInt(Event(NewHigh),OP_BUY,OP_SELL)))
          SetEvent(NewLead,Nominal,BoolToDouble(Event(NewHigh),session.High,session.Low,Digits));
    }

    if (ActionChanged(srec[ActiveSession].Bias,Action(direction)))
    {
      SetEvent(NewBias,alert,BoolToDouble(IsOpen(),Pivot(PriorSession),Pivot(OffSession)));
      SetEvent(BoolToEvent(IsEqual(alert,Notify),NewDivergence,NewConvergence),alert,BoolToDouble(IsOpen(),Pivot(PriorSession),Pivot(OffSession)));
    }
  }

//+------------------------------------------------------------------+
//| UpdateBuffers - updates indicator buffer values                  |
//+------------------------------------------------------------------+
void CSession::UpdateBuffers(void)
  {
    for (sBars=sBars;sBars<Bars;sBars++)
    {
      for (PeriodType period=OffSession;period<PeriodTypes;period++)
      {
        ArrayResize(sbuf[period].Price,sBars,10);
        ArrayCopy(sbuf[period].Price,sbuf[period].Price,1,0,WHOLE_ARRAY);
        
        sbuf[period].Price[0]             = 0.00;
      }
    }
  }

//+------------------------------------------------------------------+
//| UpdatePanel - updates control panel if loaded                    |
//+------------------------------------------------------------------+
void CSession::UpdatePanel(void)
  {
    static FractalType pivot  = Term;

    indSN     = "CPanel-v2";
    indWinId  = ChartWindowFind(0,indSN);

    if (Event(NewFibonacci))
      pivot                   = (FractalType)BoolToInt(Event(NewFibonacci,Critical),Origin,
                                             BoolToInt(Event(NewFibonacci,Major),Trend,Term));

    if (indWinId>NoValue)
    {
      if (IsEqual(sType,Daily))
      {
        UpdateDirection("tmaSessionTrendDir"+(string)indWinId,frec[Trend].Direction,Color(frec[Trend].Direction),16);
        UpdateDirection("tmaSessionTermDir"+(string)indWinId,frec[Term].Direction,Color(frec[Term].Direction),32);
        UpdateLabel("tmaSessionState"+(string)indWinId,rpad(EnumToString(frec[Trend].State)," ",20),Color(frec[Trend].Direction),12,"Noto Sans Mono CJK HK");
        UpdateLabel("tmaSessionFractalState"+(string)indWinId,rpad(EnumToString(pivot)+" "+EnumToString(frec[pivot].State)," ",20),Color(frec[pivot].Direction),12,"Noto Sans Mono CJK HK");
        UpdateLabel("tmaSessionPivotRet"+(string)indWinId,StringSubstr(EnumToString(frec[pivot].Retrace.Level),4,4),Color(Direction(frec[pivot].Pivot.Lead,InAction)),10,"Noto Sans Mono CJK HK");
        UpdateLabel("tmaSessionPivotExt"+(string)indWinId,StringSubstr(EnumToString(frec[pivot].Extension.Level),4),Color(Direction(frec[pivot].Pivot.Bias,InAction)),10,"Noto Sans Mono CJK HK");
        UpdateDirection("tmaSessionPivotLead"+(string)indWinId,Direction(frec[pivot].Pivot.Lead,InAction),Color(Direction(frec[pivot].Pivot.Lead,InAction)),16);
        UpdateDirection("tmaSessionPivotBias"+(string)indWinId,Direction(frec[pivot].Pivot.Bias,InAction),Color(Direction(frec[pivot].Pivot.Bias,InAction)),16);
      }

      //-- Update Control Panel (Session)
       if (ObjectGet("bxhAI-Session"+EnumToString(sType),OBJPROP_BGCOLOR)==clrBoxOff||Event(NewTerm)||Event(NewHour))
       {
         UpdateBox("bxhAI-Session"+EnumToString(sType),Color(frec[Term].Direction,IN_DARK_DIR));
         UpdateBox("bxbAI-OpenInd"+EnumToString(sType),BoolToInt(IsOpen(),clrYellow,clrBoxOff));
       }
    }
  }

//+------------------------------------------------------------------+
//| InitSession - Handle session changeovers; Open->Close;Close->Open|
//+------------------------------------------------------------------+
void CSession::InitSession(EventType Event)
  {
    //-- Catch session changeover Boundary Events
    UpdateSession();

    //-- Set ActiveSession support/resistance
    srec[ActiveSession].High              = Open[sBar];
    srec[ActiveSession].Low               = Open[sBar];

    SetEvent(Event,Notify);
  }

//+------------------------------------------------------------------+
//| OpenSession - Initializes active session start values on open    |
//+------------------------------------------------------------------+
void CSession::OpenSession(void)
  {
    //-- Update OffSession Record and Indicator Buffer      
    srec[OffSession]                      = srec[ActiveSession];
    sbuf[OffSession].Price[sBar]          = Pivot(OffSession);

    InitSession(SessionOpen);    
    CreateRange();
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes active session start values on close       |
//+------------------------------------------------------------------+
void CSession::CloseSession(void)
  {        
    //-- Update Prior Record, range history, and Indicator Buffer
    srec[PriorSession]                    = srec[ActiveSession];
    sbuf[PriorSession].Price[sBar]        = Pivot(PriorSession);

    InitSession(SessionClose);
  }

//+------------------------------------------------------------------+
//| CSession Constructor                                             |
//+------------------------------------------------------------------+
CSession::CSession(SessionType Type, int HourOpen, int HourClose, int HourOffset, bool ShowRanges=false, FractalType ShowFlags=FractalTypes) : CFractal (ShowFlags)
  {
    double high[];
    double low[];

    //--- Initialize period operationals
    sBar                             = InitHistory(Period(),Bars-1)-1;
    sBars                            = Bars;
    sBarDay                          = TimeDay(ServerTime());
    sBarHour                         = NoValue;

    sType                            = Type;
    sHourOpen                        = HourOpen;
    sHourClose                       = HourClose;
    sHourOffset                      = HourOffset;

    sIsOpen                          = IsOpen();
    sShowRanges                      = ShowRanges;
    sObjectStr                       = "[session]";

    CopyHigh(NULL,PERIOD_D1,Time[sBar]+1,1,high);
    CopyLow(NULL,PERIOD_D1,Time[sBar]+1,1,low);

    //--- Initialize session records
    for (PeriodType period=OffSession;period<PeriodTypes;period++)
    {
      srec[period].Direction         = NewDirection;
      srec[period].High              = high[0];
      srec[period].Low               = low[0];

      ArrayResize(sbuf[period].Price,Bars);
      ArrayInitialize(sbuf[period].Price,0.00);
    }

    if (sIsOpen)
      CreateRange();

    for (sBar=sBar;sBar>0;sBar--)
      Update();
  }

//+------------------------------------------------------------------+
//| CSession Destructor                                              |
//+------------------------------------------------------------------+
CSession::~CSession()
  {
    RemoveChartObjects(sObjectStr);
  }

//+------------------------------------------------------------------+
//| Update - Computes fractal using supplied fractal and price       |
//+------------------------------------------------------------------+
void CSession::Update(void)
  {
    //--- Tick Setup
    ClearEvents();
    UpdateBuffers();

    //--- Test for New Day; Force close
    if (IsChanged(sBarDay,TimeDay(ServerTime())))
    {
      SetEvent(NewDay,Notify);
      
      if (IsChanged(sIsOpen,false))
        CloseSession();
    }
    
    if (IsChanged(sBarHour,TimeHour(ServerTime())))
      SetEvent(NewHour,Notify);

    //--- Calc events session open/close
    if (IsChanged(sIsOpen,IsOpen()))
      if (sIsOpen)
        OpenSession();
      else
        CloseSession();
        
    UpdateSession();
    UpdateRange();
    UpdateFractal(srec[PriorSession].Low,srec[PriorSession].High,Pivot(OffSession),sBar);
    UpdatePanel();
  }

//+------------------------------------------------------------------+
//| Update - Computes fractal using supplied fractal and price       |
//+------------------------------------------------------------------+
void CSession::Update(double &PriorBuffer[], double &OffBuffer[])
  {
    Update();

    ArrayCopy(PriorBuffer,sbuf[PriorSession].Price,0,0,WHOLE_ARRAY);
    ArrayCopy(OffBuffer,sbuf[OffSession].Price,0,0,WHOLE_ARRAY);
  }

//+------------------------------------------------------------------+
//| IsOpen - Returns true if session is open for trade               |
//+------------------------------------------------------------------+
bool CSession::IsOpen(void)
  {
    if (TimeDayOfWeek(ServerTime())<6)
      if (TimeHour(ServerTime())>=sHourOpen && TimeHour(ServerTime())<sHourClose)
        return (true);

    return (false);
  }

//+------------------------------------------------------------------+
//| IsOpen - Returns true if a session is open during supplied hours |
//+------------------------------------------------------------------+
bool CSession::IsOpen(int HourOpen, int HourClose)
  {
    if (TimeDayOfWeek(ServerTime())<6)
      if (TimeHour(ServerTime())>=HourOpen && TimeHour(ServerTime())<HourClose)
        return (true);

    return (false);
  }

//+------------------------------------------------------------------+
//| Color - Returns the color for session ranges                     |
//+------------------------------------------------------------------+
color CSession::Color(SessionType Type, GammaType Gamma)
  {
    switch (Type)
    {
      case Asia:    return (color)BoolToInt(Gamma==Dark,AsiaColor,clrForestGreen);
      case Europe:  return (color)BoolToInt(Gamma==Dark,EuropeColor,clrFireBrick);
      case US:      return (color)BoolToInt(Gamma==Dark,USColor,clrSteelBlue);
      case Daily:   return (color)BoolToInt(Gamma==Dark,DailyColor,clrDarkGray);
    }

    return (clrBlack);
  }

//+------------------------------------------------------------------+
//| BufferStr - Returns formatted Buffer data for supplied Period    |
//+------------------------------------------------------------------+
string CSession::BufferStr(PeriodType Period)
  {  
    string text            = EnumToString(Period);

    for (int bar=0;bar<Bars;bar++)
      if (sbuf[Period].Price[bar]>0.00)
      {
        Append(text,(string)bar,"|");
        Append(text,TimeToStr(Time[bar]),"|");
        Append(text,DoubleToStr(sbuf[Period].Price[bar],Digits),"|");
      }

    return(text);
  }

//+------------------------------------------------------------------+
//| SessionStr - Returns formatted Session data for supplied type    |
//+------------------------------------------------------------------+
string CSession::SessionStr(string Title="")
  {  
    string text            = Title;

    Append(text,EnumToString(sType),"|");
    Append(text,BoolToStr(IsOpen(),"Open","Closed"),"|");
    Append(text,BoolToStr(IsOpen(),BoolToStr(ServerTime()>sHourClose-3,"Late",BoolToStr(ServerTime()>3,"Mid","Early")),"Closed"),"|");
    Append(text,(string)SessionHour(),"|");
    Append(text,BufferStr(PriorSession),"|");
    Append(text,BufferStr(OffSession),"|");

    return(text);
  }
