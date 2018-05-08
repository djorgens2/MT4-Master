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
//| SessionArray Class - Collects session data, states, and events   |
//+------------------------------------------------------------------+
class CSessionArray
  {

public:

             //-- Session Record Definition
             struct TrendRec
             {
               int            TrendDir;
               int            OriginDir;
               int            Age;
               ReservedWords  State;
               double         Support;
               double         Resistance;
               double         Pullback;
               double         Rally;
             };

             //-- Session Record Definition
             struct SessionRec
             {
               int            TermDir;
               int            TermAge;
               double         TermHigh;
               double         TermLow;
               double         Support;
               double         Resistance;
               double         PriorMid;
               double         OffMid;
               ReservedWords  State;
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
             TrendRec      Trend(void)           {return (srTrend);}

             void          Update(void);
             void          Update(double &OffMidBuffer[], double &PriorMidBuffer[]);

             double        ActiveMid(void);

             int           TradeBias(void);
             int           Direction(RetraceType Type);
             ReservedWords State(RetraceType Type);
                                 
private:

             //--- Private Class properties
             SessionType   sType;
             
             bool          sSessionIsOpen;

             int           sOffDir;

             int           sHourOpen;
             int           sHourClose;
             int           sBar;
             int           sBars;
             int           sBarHour;
             
             datetime      sStartTime;

             //--- Private class collections
             SessionRec    srActive;
             SessionRec    srHistory[];
             
             TrendRec      srTrend;
             
             CArrayDouble *sOffMidBuffer;
             CArrayDouble *sPriorMidBuffer;
             
             CEvent       *sEvent;
             
             //--- Private Methods
             void          OpenSession(void);
             void          CloseSession(void);
             void          SetTrendState(ReservedWords State);
             void          CalcEvents(void);
             void          ProcessEvents(void);
             void          LoadHistory(void);
             void          UpdateBuffers(void);

             //--- Private Properties
             bool          HistoryIsLoaded(void) {return (ArraySize(srHistory)>0);}
  };

//+------------------------------------------------------------------+
//| SetTrendState - Sets trend state and updates support/resistance  |
//+------------------------------------------------------------------+
void CSessionArray::SetTrendState(ReservedWords State)
  {
    srTrend.State           = State;
    
    switch (State)
    {
      case Breakout:   
      case Reversal:  srTrend.Age             = srActive.TermAge;
    
                      if (srTrend.TrendDir==DirectionUp)
                      {
                        srTrend.Support       = srTrend.Pullback;
                        srTrend.Rally         = ActiveMid();
                      }
                      
                      if (srTrend.TrendDir==DirectionDown)
                      {
                        srTrend.Resistance    = srTrend.Rally;
                        srTrend.Pullback      = ActiveMid();
                      }
                      break;
                      
       case Rally:
       case Pullback: if (srTrend.TrendDir==DirectionUp)
                        srTrend.Rally         = ActiveMid();

                      if (srTrend.TrendDir==DirectionDown)
                        srTrend.Pullback      = ActiveMid();
     }
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

    //-- Reset term range and open session flag
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
    SessionRec uhHistory[];

    ArrayCopy(uhHistory,srHistory);
    ArrayResize(srHistory,ArraySize(srHistory)+1);
    ArrayCopy(srHistory,uhHistory,1);

    srHistory[0]              = srActive;
    
    if (sEvent[NewTrend])
      srActive.TermAge        = 0;

    if (sEvent[NewBreakout])
      SetTrendState(Breakout);
    else
    if (sEvent[NewReversal])
      SetTrendState(Reversal);
    else
    if (sEvent[NewRally])
      SetTrendState(Rally);
    else
    if (sEvent[NewPullback])
      SetTrendState(Pullback);
      
    srActive.Resistance       = srActive.TermHigh;
    srActive.Support          = srActive.TermLow;

    srActive.TermHigh         = High[sBar];
    srActive.TermLow          = Low[sBar];

    srActive.TermAge++;
    srTrend.Age++;
    
    sSessionIsOpen            = false;
    
    if (sType==Asia)
    {
      string csEvent="";
      for (EventType event=0;event<EventTypes;event++)
        if (sEvent[event])
          Append(csEvent,EnumToString(event),":");
        
      Print("The close at "+TimeToStr(Time[sBar])
             +" s: "+DoubleToStr(srTrend.Support,Digits)
             +" r: "+DoubleToStr(srTrend.Resistance,Digits)
             +" pb: "+DoubleToStr(srTrend.Pullback,Digits)
             +" rl: "+DoubleToStr(srTrend.Rally,Digits)
             +" Events ("+csEvent+")"
             +" Trend:"+BoolToStr(srTrend.TrendDir==DirectionUp,"Long","Short")
           );
    }
  }

//+------------------------------------------------------------------+
//| ProcessEvents - Reviews active events; updates critical elements |
//+------------------------------------------------------------------+
void CSessionArray::ProcessEvents(void)
  {
    if (sEvent[SessionOpen])
      OpenSession();
    else
    if (sEvent[SessionClose])
      CloseSession();
    else
    {
      if (sEvent[NewBreakout])
        srActive.State        = Breakout;
        
      if (sEvent[NewReversal])
        srActive.State        = Reversal;      
        
      if (sEvent[NewRally])
        srActive.State        = Rally;      
        
      if (sEvent[NewPullback])
        srActive.State        = Pullback;      
    }
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
            sEvent.SetEvent(NewDivergence);
        
        if (IsHigher(ActiveMid(),srActive.OffMid))
          if (IsChanged(sOffDir,DirectionUp))
            sEvent.SetEvent(NewDivergence);
      }
      else
      {
        sEvent.SetEvent(SessionClose);

        if (IsLower(ActiveMid(),srActive.PriorMid))
          if (IsChanged(srTrend.TrendDir,DirectionDown))
            sEvent.SetEvent(NewTrend);
        
        if (IsHigher(ActiveMid(),srActive.PriorMid))
          if (IsChanged(srTrend.TrendDir,DirectionUp))
            sEvent.SetEvent(NewTrend);
            
        if (srTrend.TrendDir==DirectionUp)
          if (IsHigher(ActiveMid(),srTrend.Resistance))
            if (IsChanged(srTrend.OriginDir,srTrend.TrendDir))
              sEvent.SetEvent(NewReversal);
            else
              sEvent.SetEvent(NewBreakout);
          else
            sEvent.SetEvent(NewRally);

        if (srTrend.TrendDir==DirectionDown)
          if (IsLower(ActiveMid(),srTrend.Support))
            if (IsChanged(srTrend.OriginDir,srTrend.TrendDir))
              sEvent.SetEvent(NewReversal);
            else
              sEvent.SetEvent(NewBreakout);
          else
            sEvent.SetEvent(NewPullback);
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
        if (IsHigher(High[sBar],srActive.Resistance) || IsLower(Low[sBar],srActive.Support))
        {
          sEvent.SetEvent(NewState);
          
          if (srActive.TermDir==srTrend.TrendDir)
            sEvent.SetEvent(NewBreakout);
          else
            sEvent.SetEvent(NewReversal);
        }
        else

        //--- Test Rallys/Pullbacks
        {
          double cePivotPrice   = srActive.PriorMid;
            
          if (sSessionIsOpen)
            cePivotPrice        = srActive.OffMid;

          if (sEvent[NewHigh])
            if (IsHigher(High[sBar],cePivotPrice,NoUpdate))
            {
              sEvent.SetEvent(NewState);
              sEvent.SetEvent(NewRally);
            }
          
          if (sEvent[NewLow])
            if (IsLower(Low[sBar],cePivotPrice,NoUpdate))
            {
              sEvent.SetEvent(NewState);
              sEvent.SetEvent(NewPullback);
            }
        }
      }
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
    
    //--- Initialize period operationals
    sBar                      = lhCloseBar;
    sBarHour                  = NoValue;
    sStartTime                = Time[sBar];
    sBars                     = Bars;
    sOffDir                   = DirectionNone;
        
    //--- Initialize session record
    srActive.TermDir          = DirectionNone;
    srActive.TermHigh         = High[sBar];
    srActive.TermLow          = Low[sBar];
    srActive.Support          = srActive.TermLow;
    srActive.Resistance       = srActive.TermHigh;
    srActive.PriorMid         = ActiveMid();
    srActive.OffMid           = ActiveMid();
    srActive.State            = NoState;

    //--- Initialize Trend record
    srTrend.TrendDir          = DirectionNone;
    srTrend.OriginDir         = DirectionNone;
    srTrend.Age               = 0;
    srTrend.Support           = srActive.Support;
    srTrend.Resistance        = srActive.Resistance;
    srTrend.Rally             = ActiveMid();
    srTrend.Pullback          = ActiveMid();
    
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
    sType                        = Type;
    sHourOpen                    = HourOpen;
    sHourClose                   = HourClose;
    
    sEvent                       = new CEvent();

    sOffMidBuffer                = new CArrayDouble(Bars);
    sOffMidBuffer.Truncate       = false;
    sOffMidBuffer.AutoExpand     = true;    
    sOffMidBuffer.SetPrecision(Digits);
    sOffMidBuffer.Initialize(0.00);
    
    sPriorMidBuffer              = new CArrayDouble(Bars);
    sPriorMidBuffer.Truncate     = false;
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
      return (srTrend.TrendDir);
      
    if (Type==Term)
      return (srActive.TermDir);
      
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| State - Returns the trend state based on the last active event   |
//+------------------------------------------------------------------+
ReservedWords CSessionArray::State(RetraceType Type)
  {    
    switch (Type)
    {
      case Trend:      return(srTrend.State);
      case Term:       return(srActive.State);
    }
    
    return (NoState);
  }
