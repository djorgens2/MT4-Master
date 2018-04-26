//+------------------------------------------------------------------+
//|                                                 SessionArray.mqh |
//|                                 Copyright 2018, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class/Event.mqh>
#include <Class/ArrayDouble.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSessionArray
  {

public:

             //-- Session Record Definition
             struct SessionRec
             {
               int         TermDir;
               double      TermHigh;
               double      TermLow;
               double      Support;
               double      Resistance;
               double      PriorMid;
               double      OffMid;
             };

             //-- Session Types
             enum SessionType
             {
               Asia,
               Europe,
               US,
               Daily,
               SessionTypes
             };

             CSessionArray(SessionType Type, int HourOpen, int HourClose);
            ~CSessionArray();

             bool          SessionIsOpen(void);
             bool          Event(EventType Type) {return (sEvent[Type]);}
             bool          ActiveEvent(void)     {return (sEvent.ActiveEvent());}

             SessionRec    Active(void)          {return (srActive);}
             SessionRec    History(int Shift)    {return (srHistory[Shift]);}

             void          Update(void);
             void          Update(double &OffMidBuffer[], double &PriorMidBuffer[]);

             double        ActiveMid(void);
             int           TradeBias(void);
             int           Direction(RetraceType Type);
             ReservedWords State(void);
                                 
private:

             //--- Private Class properties
             SessionType   sType;
             
             bool          sSessionIsOpen;

             int           sTrendDir;             
             int           sOffDir;

             EventType     sEventState;

             int           sHourOpen;
             int           sHourClose;
             int           sBar;
             int           sBars;
             int           sBarHour;
             
             datetime      sStartTime;
             
             
             //--- Private class collections
             SessionRec    srActive;
             SessionRec    srHistory[];
             CArrayDouble *sOffMidBuffer;
             CArrayDouble *sPriorMidBuffer;
             
             CEvent       *sEvent;
             
             //--- Private Methods
             void          OpenSession(void);
             void          CloseSession(void);
             void          CalcEvents(void);
             void          ProcessEvents(void);
             void          LoadHistory(void);
             void          UpdateHistory(void);
             void          UpdateBuffers(void);

             //--- Private Properties
             bool          HistoryIsLoaded(void) {return (ArraySize(srHistory)>0);}
  };

//+------------------------------------------------------------------+
//| UpdateHistory - Manages history changes and the history array    |
//+------------------------------------------------------------------+
void CSessionArray::UpdateHistory(void)
  {
    SessionRec uhHistory[];

    ArrayCopy(uhHistory,srHistory);
    ArrayResize(srHistory,ArraySize(srHistory)+1);
    ArrayCopy(srHistory,uhHistory,1);

    srHistory[0]                    = srActive;  
  }

//+------------------------------------------------------------------+
//| OpenSession - Initializes active session start values on open    |
//+------------------------------------------------------------------+
void CSessionArray::OpenSession(void)
  {    
    //-- Set support/resistance
    if (HistoryIsLoaded())
    {
      srActive.Resistance           = fmax(srActive.TermHigh,srHistory[0].TermHigh);
      srActive.Support              = fmin(srActive.TermLow,srHistory[0].TermLow);
    }

    //-- Reset support/resistance and open session flag
    srActive.TermHigh               = High[sBar];
    srActive.TermLow                = Low[sBar];

    sSessionIsOpen                  = True;
    
    //-- Update indicator buffers
    sOffMidBuffer.SetValue(sBar,srActive.OffMid);
    sPriorMidBuffer.SetValue(sBar,srActive.PriorMid);
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes active session start values on close       |
//+------------------------------------------------------------------+
void CSessionArray::CloseSession(void)
  {
    UpdateHistory();

    srActive.TermHigh               = High[sBar];
    srActive.TermLow                = Low[sBar];

    sSessionIsOpen                  = false;
  }

//+------------------------------------------------------------------+
//| CalcEvents - Updates active pricing and sets events              |
//+------------------------------------------------------------------+
void CSessionArray::CalcEvents(void)
  {
    const  int ndNewDay    = 0;

    //--- Clear events
    sEvent.ClearEvents();

    //--- Test for New Day
    if (IsChanged(sBarHour,TimeHour(Time[sBar])))
      if (sBarHour==ndNewDay)
        sEvent.SetEvent(NewDay);

    //--- Calc events session open/close
    if (IsChanged(sSessionIsOpen,this.SessionIsOpen()))
      if (sSessionIsOpen)
      {
        sEvent.SetEvent(SessionOpen);

        if (IsLower(ActiveMid(),srActive.OffMid))
          if (IsChanged(sOffDir,DirectionDown))
            sEvent.SetEvent(NewOffSessionPivot);
        
        if (IsHigher(ActiveMid(),srActive.OffMid))
          if (IsChanged(sOffDir,DirectionUp))
            sEvent.SetEvent(NewOffSessionPivot);
      }
      else
      {
        sEvent.SetEvent(SessionClose);

        if (IsLower(ActiveMid(),srActive.PriorMid))
          if (IsChanged(sTrendDir,DirectionDown))
            sEvent.SetEvent(NewTrend);
        
        if (IsHigher(ActiveMid(),srActive.PriorMid))
          if (IsChanged(sTrendDir,DirectionUp))
            sEvent.SetEvent(NewTrend);
      }
    else
    
    //--- Calc boundary events
    {
      //--- Test for session high
      if (IsHigher(High[sBar],srActive.TermHigh))
      {
        sEvent.SetEvent(NewHigh);
        sEvent.SetEvent(NewBoundary);

        if (IsChanged(srActive.TermDir,DirectionUp))
        {
          sEvent.SetEvent(NewDirection);
          sEvent.SetEvent(NewTerm);
        }
      }
        
      //--- Test for session low
      if (IsLower(Low[sBar],srActive.TermLow))
      {
        sEvent.SetEvent(NewLow);
        sEvent.SetEvent(NewBoundary);

        if (IsChanged(srActive.TermDir,DirectionDown))
        {
          sEvent.SetEvent(NewDirection);
          sEvent.SetEvent(NewTerm);
        }
      }

      //--- Test boundary breakouts
      if (sEvent[NewBoundary])
      {
        if (IsHigher(Close[sBar],srActive.Resistance) || IsLower(Close[sBar],srActive.Support))
          if (srActive.TermDir==sTrendDir)
            sEvent.SetEvent(NewBreakout);
          else
            sEvent.SetEvent(NewReversal);
        else

        //--- Test Rallys/Pullbacks
        {
            double cePivotPrice   = srActive.PriorMid;
            
          if (sSessionIsOpen)
            cePivotPrice        = srActive.OffMid;

          if (sEvent[NewHigh])
            if (IsHigher(Close[sBar],cePivotPrice,NoUpdate))
              sEvent.SetEvent(NewRally);
          
          if (sEvent[NewLow])
            if (IsLower(Close[sBar],cePivotPrice,NoUpdate))
              sEvent.SetEvent(NewPullback);
        }
      }
    }
  }

//+------------------------------------------------------------------+
//| State - Returns the trend state based on the last active event   |
//+------------------------------------------------------------------+
ReservedWords CSessionArray::State(void)
  {
    //--- Long session states
    if (sTrendDir==DirectionUp)
      switch (sEventState)
      {
        case NewReversal:     return(Reversal);
        case NewBreakout:     return(Breakout);
        case NewRally:        return(Rally);
        case NewPullback:     return(Pullback);
      }
    else
    
    //--- Short session states
    if (sTrendDir==DirectionDown)
      switch (sEventState)
      {
        case NewReversal:     return(Reversal);
        case NewBreakout:     return(Breakout);
        case NewRally:        return(Rally);
        case NewPullback:     return(Pullback);
      }
      
    return (NoState);
  }

//+------------------------------------------------------------------+
//| ProcessEvents - Reviews active events; updates critical elements |
//+------------------------------------------------------------------+
void CSessionArray::ProcessEvents(void)
  {    
    for (EventType event=NewDirection;event<EventTypes;event++)
      if (sEvent[event])
        switch (event)
        {
          case NewRally:
          case NewPullback:
          case NewBreakout:
          case NewReversal:     sEventState  = event;
                                break;
          case NewHigh:
          case NewLow:
          case NewBoundary:     break;

          case SessionOpen:     OpenSession();
                                break;

          case SessionClose:    CloseSession();
                                break;
        }
  }

//+------------------------------------------------------------------+
//| UpdateBuffers - updates indicator buffer values                  |
//+------------------------------------------------------------------+
void CSessionArray::UpdateBuffers(void)
  {
    if (Bars<sBars)
      Print("History exception; need to reload");
    else
      for (sBars=sBars;sBars<Bars;sBars++)
      {
        sOffMidBuffer.Insert(0,0.00);
        sPriorMidBuffer.Insert(0,0.00);
      }
  }

//+------------------------------------------------------------------+
//| LoadHistory - Loads history from the first session open          |
//+------------------------------------------------------------------+
void CSessionArray::LoadHistory(void)
  {    
    int lhOpenBar   = iBarShift(Symbol(),PERIOD_H1,StrToTime(TimeToStr(Time[Bars-24], TIME_DATE)+" "+lpad(IntegerToString(sHourOpen),"0",2)+":00"));
    int lhCloseBar  = Bars-1;
    
    sEvent.ClearEvents();
    
    sBar                      = lhCloseBar;
    sBarHour                  = NoValue;
    sStartTime                = Time[sBar];
    
    srActive.TermDir          = DirectionNone;
    srActive.TermHigh         = High[sBar];
    srActive.TermLow          = Low[sBar];
    srActive.Support          = srActive.TermLow;
    srActive.Resistance       = srActive.TermHigh;
    srActive.PriorMid         = ActiveMid();
    srActive.OffMid           = ActiveMid();

    sTrendDir                 = DirectionNone;
    sOffDir                   = DirectionNone;
    
    for (sBar=lhCloseBar;sBar>lhOpenBar;sBar--)
      if (SessionIsOpen())
        continue;
      else
      if (srActive.TermDir==DirectionNone)
      {
        if (Open[sBar]>Close[sBar])
          srActive.TermDir    = DirectionUp;
          
        if (Open[sBar]<Close[sBar])
          srActive.TermDir    = DirectionDown;
          
        srActive.TermHigh         = High[sBar];
        srActive.TermLow          = Low[sBar];
      }
      else
      {
        if (IsHigher(High[sBar],srActive.TermHigh))
          srActive.TermDir    = DirectionUp;
          
        if (IsLower(Low[sBar],srActive.TermLow))
          srActive.TermDir    = DirectionDown;
      }
    
    srActive.Support          = srActive.TermLow;
    srActive.Resistance       = srActive.TermHigh;

    for (sBar=lhOpenBar;sBar>0;sBar--)
      Update();
  }

//+------------------------------------------------------------------+
//| Session Class Constructor                                        |
//+------------------------------------------------------------------+
CSessionArray::CSessionArray(SessionType Type, int HourOpen, int HourClose)
  {
    //--- Init global session values
    sType                     = Type;
    sTrendDir                 = DirectionNone;
    sBars                     = Bars;
    
    sHourOpen                 = HourOpen;
    sHourClose                = HourClose;
    
    sEvent                    = new CEvent();

    sOffMidBuffer             = new CArrayDouble(Bars);
    sOffMidBuffer.Truncate    = false;
    sOffMidBuffer.AutoExpand  = true;    
    sOffMidBuffer.SetPrecision(Digits);
    sOffMidBuffer.Initialize(0.00);
    
    sPriorMidBuffer           = new CArrayDouble(Bars);
    sPriorMidBuffer.Truncate  = false;
    sPriorMidBuffer.AutoExpand   = true;
    sPriorMidBuffer.SetPrecision(Digits);
    sPriorMidBuffer.Initialize(0.00);
    
    LoadHistory();    
  }

//+------------------------------------------------------------------+
//| Session Class Destructor                                         |
//+------------------------------------------------------------------+
CSessionArray::~CSessionArray()
  {
    delete sEvent;
    delete sOffMidBuffer;
    delete sPriorMidBuffer;
  }

//+------------------------------------------------------------------+
//| Update - Updates open session data and events                    |
//+------------------------------------------------------------------+
void CSessionArray::Update(void)
  {
    UpdateBuffers();
    CalcEvents();
    ProcessEvents();
  }
  
//+------------------------------------------------------------------+
//| Update - Updates and returns buffer values                       |
//+------------------------------------------------------------------+
void CSessionArray::Update(double &OffMidBuffer[], double &PriorMidBuffer[])
  {
    Update();
    
    sOffMidBuffer.Copy(OffMidBuffer);
    sPriorMidBuffer.Copy(PriorMidBuffer);
  }
  
//+------------------------------------------------------------------+
//| SessionIsOpen - Returns true if session is open for trade        |
//+------------------------------------------------------------------+
bool CSessionArray::SessionIsOpen(void)
  {
    if (TimeHour(Time[sBar])>=sHourOpen && TimeHour(Time[sBar])<sHourClose)
      return (true);
        
    return (false);
  }
  
//+------------------------------------------------------------------+
//| TradeBias - returns the trade bias based on Time Period          |
//+------------------------------------------------------------------+
int CSessionArray::TradeBias(void)
  {    
    if (sSessionIsOpen)
    {
      if (IsHigher(srActive.OffMid,srActive.PriorMid,NoUpdate,Digits))
        return(OP_BUY);
      if (IsLower(srActive.OffMid,srActive.PriorMid,NoUpdate,Digits))
        return(OP_SELL);
    }
    else
    {
      if (IsHigher(ActiveMid(),srActive.PriorMid,NoUpdate,Digits))
        return(OP_BUY);
      if (IsLower(ActiveMid(),srActive.PriorMid,NoUpdate,Digits))
        return(OP_SELL);
    }
      
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| ActiveMid - returns the current active mid price (Fibo50)        |
//+------------------------------------------------------------------+
double CSessionArray::ActiveMid(void)
  {
    return(fdiv(srActive.TermHigh+srActive.TermLow,2,Digits));
  }
  
//+------------------------------------------------------------------+
//| Direction - returns the current direction by type                |
//+------------------------------------------------------------------+
int CSessionArray::Direction(RetraceType Type)
  {
    if (Type==Trend)
      return (sTrendDir);
      
    if (Type==Term)
      return (srActive.TermDir);
      
    return (NoValue);
  }
