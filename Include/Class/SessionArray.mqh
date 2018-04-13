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
               int         ReversalCount;
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

             int           Direction(RetraceType Type);
             void          Update(void);
             void          Update(double &OffMidBuffer[], double &PriorMidBuffer[]);
             int           TradeBias(int TimePeriod=State);
                    
private:

             //--- Private Class properties
             SessionType   sType;
             
             bool          sSessionIsOpen;

             int           sTrendDir;
             StateType     sTrendState;
             bool          sTrendPeg[RetraceTypes];
             double        sFractal[RetraceTypes];
             RetraceType   sActiveFractal;
             int           sFractalDir;

             int           sHourOpen;
             int           sHourClose;
             int           sBar;
             int           sBarHour;
             
             datetime      sStartTime;
             
             double        ActiveMid(void);

             
             //--- Private class collections
             SessionRec    srActive;
             SessionRec    srHistory[];
             CArrayDouble *sOffMidBuffer;
             CArrayDouble *sPriorMidBuffer;
             
             CEvent       *sEvent;
             CArrayDouble *sFractalOrigin;
             
             //--- Private Methods
             void          OpenSession(void);
             void          CloseSession(void);
             void          CalcEvents(void);
             void          CalcState(void);
             void          CalcFractal(void);
             void          ProcessEvents(void);
             void          LoadHistory(void);
             void          UpdateHistory(void);
  };

//+------------------------------------------------------------------+
//| ActiveMid - returns the current active mid price (Fibo50)        |
//+------------------------------------------------------------------+
double CSessionArray::ActiveMid(void)
  {
    return(fdiv(srActive.TermHigh+srActive.TermLow,2,Digits));
  }
  
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
    srActive.OffMid                 = ActiveMid();
    srActive.Resistance             = srActive.TermHigh;
    srActive.Support                = srActive.TermLow;

    srActive.TermHigh               = High[sBar];
    srActive.TermLow                = Low[sBar];
    srActive.ReversalCount          = NoValue;

    sSessionIsOpen                  = True;
    
    if (sBar==0)
    {
      sOffMidBuffer.Add(srActive.OffMid);
      sPriorMidBuffer.Add(srActive.PriorMid);
    }
    else
    {
      sOffMidBuffer.SetValue(sBar,srActive.OffMid);
      sPriorMidBuffer.SetValue(sBar,srActive.PriorMid);
    }
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes active session start values on close       |
//+------------------------------------------------------------------+
void CSessionArray::CloseSession(void)
  {
    CalcFractal();
    
    srActive.PriorMid               = ActiveMid();
    srActive.Resistance             = srActive.TermHigh;
    srActive.Support                = srActive.TermLow;
     
    UpdateHistory();
    
    //--- Set Active to OffSession
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

    //--- Calc events based on opening, closing, off/active sessions
    if (this.SessionIsOpen())
    {

      //--- Handle Session Open
      if (IsChanged(sSessionIsOpen,this.SessionIsOpen()))
        sEvent.SetEvent(SessionOpen);
    }
    else

    {
      //--- Handle Session Close
      if (IsChanged(sSessionIsOpen,this.SessionIsOpen()))
        sEvent.SetEvent(SessionClose);
      else

      //--- Handle off/active session events
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
          if (IsHigher(High[sBar],srActive.Resistance) || IsLower(Low[sBar],srActive.Support))
            if (sEvent[NewDirection])
              sEvent.SetEvent(NewReversal);
            else
            if (srActive.ReversalCount==NoValue)
              sEvent.SetEvent(NewBreakout);
      }
    }
  }

//+------------------------------------------------------------------+
//| CalcState - Calculates the trend state                           |
//+------------------------------------------------------------------+
void CSessionArray::CalcState(void)
  {
  }

//+------------------------------------------------------------------+
//| CalcFractal - Calculates selected fractals for fibo analysis     |
//+------------------------------------------------------------------+
void CSessionArray::CalcFractal(void)
  {
    int    cfFractalDir           = sFractalDir;
    
    if (sEvent[SessionClose])
    //--- On session close calcs
    {
      //--- Initialization Pass
      if (sFractalDir==DirectionNone)
      {
        sFractal[Root]            = srActive.PriorMid;
        sFractal[Expansion]       = ActiveMid();

        sFractalOrigin.Insert(0,sFractal[Root]);
        
        if (IsHigher(sFractal[Expansion],sFractal[Root],NoUpdate,Digits))
          sFractalDir             = DirectionUp;

        if (IsLower(sFractal[Expansion],sFractal[Root],NoUpdate,Digits))
          sFractalDir             = DirectionDown;
      }
      else
      
      //--- Continuation pass
      {
      }
    }
    
    //--- Non-opening (active) calcs
    else
    {};
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
          case NewBreakout:
          case NewReversal:     srActive.ReversalCount++;
                                break;
          case NewBoundary:     break;
          case SessionOpen:     OpenSession();
                                break;
          case SessionClose:    CloseSession();
                                break;
        }
  }

//+------------------------------------------------------------------+
//| LoadHistory - Loads history from the first session open          |
//+------------------------------------------------------------------+
void CSessionArray::LoadHistory(void)
  {    
    int lhOpenBar   = iBarShift(Symbol(),PERIOD_H1,StrToTime(TimeToStr(Time[Bars-24], TIME_DATE)+" "+lpad(IntegerToString(sHourOpen),"0",2)+":00"));
    int lhCloseBar  = Bars-1;
    
    sEvent                    = new CEvent();
    sEvent.ClearEvents();
    
    sBar                      = lhCloseBar;
    sStartTime                = Time[sBar];
    
    srActive.TermDir          = DirectionNone;
    srActive.TermHigh         = High[sBar];
    srActive.TermLow          = Low[sBar];
    srActive.Support          = srActive.TermLow;
    srActive.Resistance       = srActive.TermHigh;
    srActive.PriorMid         = ActiveMid();
    srActive.OffMid           = ActiveMid();
    srActive.ReversalCount    = NoValue;
    
    sActiveFractal            = Expansion;
    sFractal[sActiveFractal]  = ActiveMid();
    sBarHour                  = NoValue;

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
    sTrendState               = NoState;
    
    sHourOpen                 = HourOpen;
    sHourClose                = HourClose;
    
    ArrayInitialize(sFractal,0.00);
    ArrayInitialize(sTrendPeg,false);
    
    sFractalDir               = DirectionNone;
    sFractalOrigin            = new CArrayDouble(0);
    sFractalOrigin.Truncate   = false;
    sFractalOrigin.AutoExpand = true;
    sFractalOrigin.SetPrecision(Digits);
    
    sOffMidBuffer             = new CArrayDouble(Bars);
    sOffMidBuffer.Truncate    = false;
    sOffMidBuffer.SetPrecision(Digits);
    sOffMidBuffer.Initialize(0.00);
    
    sPriorMidBuffer           = new CArrayDouble(Bars);
    sPriorMidBuffer.Truncate  = false;
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
    delete sFractalOrigin;
  }

//+------------------------------------------------------------------+
//| Update - Updates open session data and events                    |
//+------------------------------------------------------------------+
void CSessionArray::Update(void)
  {
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
int CSessionArray::TradeBias(int TimePeriod=State)
  {    
    switch (TimePeriod)
    {
      case State:   if (IsHigher(srActive.OffMid,srActive.PriorMid,NoUpdate,Digits))
                      return(OP_BUY);
                    if (IsLower(srActive.OffMid,srActive.PriorMid,NoUpdate,Digits))
                      return(OP_SELL);
                    break;
      case Active:  if (IsHigher(ActiveMid(),srActive.PriorMid,NoUpdate,Digits))
                      return(OP_BUY);
                    if (IsLower(ActiveMid(),srActive.PriorMid,NoUpdate,Digits))
                      return(OP_SELL);
                    break;
    }
      
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| Direction - Returns the direction for the supplied type          |
//+------------------------------------------------------------------+
int CSessionArray::Direction(RetraceType Type)
  {    
    switch (Type)
    {
      case Trend:   return (sTrendDir);
      case Term:    return (srActive.TermDir);
      case Prior:   return (srHistory[0].TermDir);
//      case Expansion: return
    }
    
    return (DirectionNone);
  }