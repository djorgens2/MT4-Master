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
class CSession
  {

public:

             //-- Trend Record Definition
             struct TrendRec
             {
               int            Direction;
               int            Age;
               ReservedWords  State;
               double         Base;
               double         Root;
             };
             
             //-- Session Record Definition
             struct SessionRec
             {
               int            Direction;
               int            Age;
               ReservedWords  State;
               int            BreakoutDir;
               double         High;
               double         Low;
               double         Support;
               double         Resistance;
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

             //-- Session Record Types
             enum SessionRecType
             {
               ActiveSession,
               OffSession,
               PriorSession,
               SessionRecTypes
             };

             CSession(SessionType Type, int HourOpen, int HourClose);
            ~CSession();

             SessionType   Type(void)                       {return (sType);}
             int           SessionHour(int Measure=Now);
             bool          IsOpen(void);
             
             bool          Event(EventType Type)            {return (sEvent[Type]);}
             bool          ActiveEvent(void)                {return (sEvent.ActiveEvent());}

             void          Update(void);
             void          Update(double &OffSessionBuffer[], double &PriorMidBuffer[]);

             double        ActiveMid(void);
             double        PriorMid(void);
             double        OffMid(void);
             
             TrendRec      Trend(int Type);

             int           TradeBias(int Format=InAction);
             void          PrintSession(int Type);
             
             SessionRec    operator[](const int Type) const {return(srec[Type]);}
             
                                 
private:

             //-- Trend Record Types
             enum TrendRecType
             {
               trTerm,
               trTrend,
               trOrigin,
               TrendRecTypes
             };

             //--- Private Class properties
             SessionType   sType;
             
             bool          sSessionIsOpen;
             int           sTradeBias;

             int           sHourOpen;
             int           sHourClose;
             int           sBar;
             int           sBars;
             int           sBarDay;
             int           sBarHour;
             

             //--- Private class collections
             SessionRec    srec[SessionRecTypes];
             TrendRec      trec[TrendRecTypes];
                          
             CArrayDouble *sOffMidBuffer;
             CArrayDouble *sPriorMidBuffer;
             
             CEvent       *sEvent;
             
             //--- Private Methods
             void          OpenSession(void);
             void          CloseSession(void);
             void          UpdateSession(void);
             void          UpdateBuffers(void);

             void          LoadHistory(void);

             void          SetTradeBias(void);
             void          SetActiveState(void);
             void          SetTermState(void);
             void          SetTrendState(void);
             void          SetOriginState(void);
             
             bool          NewDirection(int &Direction, int NewDirection);
             bool          NewState(ReservedWords &State, ReservedWords NewState);
  };


//+------------------------------------------------------------------+
//| NewDirection - Tests for new direction events                    |
//+------------------------------------------------------------------+
bool CSession::NewDirection(int &Direction, int ChangeDirection)
  {
    if (ChangeDirection==DirectionNone)
      return(false);
     
    if (Direction==DirectionNone)
      Direction                   = ChangeDirection;
    else
    if (IsChanged(Direction,ChangeDirection))
    {
      sEvent.SetEvent(NewDirection);
      return(true);
    }
      
    return(false);
  }
    
//+------------------------------------------------------------------+
//| NewState - Tests for new state events                            |
//+------------------------------------------------------------------+
bool CSession::NewState(ReservedWords &State, ReservedWords ChangeState)
  {
    if (ChangeState==NoState)
      return(false);
     
    if (State==NoState)
      State                       = ChangeState;

    if (State==Reversal && ChangeState==Breakout)
      ChangeState                 = State;
      
    if (IsChanged(State,ChangeState))
    {
      sEvent.SetEvent(NewState);
      
      switch (State)
      {
        case Reversal:    sEvent.SetEvent(NewReversal);
                          break;
        case Breakout:    sEvent.SetEvent(NewBreakout);
                          break;
        case Rally:       sEvent.SetEvent(NewRally);
                          break;
        case Pullback:    sEvent.SetEvent(NewPullback);
                          break;
      }
      
      return(true);
    }
      
    return(false);
  }
    
//+------------------------------------------------------------------+
//| SetTradeBias - returns the trade bias based on Time Period       |
//+------------------------------------------------------------------+
void CSession::SetTradeBias(void)
  {
    int stbTradeBias        = sTradeBias;
  
    if (ActiveMid()>PriorMid())
      stbTradeBias          = OP_BUY;

    if (ActiveMid()<PriorMid())
      stbTradeBias          = OP_SELL;
      
    if (IsChanged(sTradeBias,stbTradeBias))
      sEvent.SetEvent(MarketCorrection);
  }

//+------------------------------------------------------------------+
//| SetOriginState - Sets Origin state on changes to Trend State     |
//+------------------------------------------------------------------+
void CSession::SetOriginState(void)
  {
  }

//+------------------------------------------------------------------+
//| SetTrendState - Sets trend state and updates support/resistance  |
//+------------------------------------------------------------------+
void CSession::SetTrendState(void)
  {
  }
  
//+------------------------------------------------------------------+
//| SetTermState - Sets Term state based on changes to Active State  |
//+------------------------------------------------------------------+
void CSession::SetTermState(void)
  {
    if (IsChanged(trec[trTerm].Direction,Direction(ActiveMid()-PriorMid())))
    {
      trec[trTerm].Age             = 0;
      
      if (trec[trTerm].Direction==DirectionUp)
        if (IsHigher(ActiveMid(),trec[trTerm].Base))
          trec[trTerm].State       = Reversal;
        else
          trec[trTerm].State       = Rally;
        
      if (trec[trTerm].Direction==DirectionDown)
        if (IsLower(ActiveMid(),trec[trTerm].Base))
          trec[trTerm].State       = Reversal;
        else
          trec[trTerm].State       = Pullback;
      
      trec[trTerm].Base            = PriorMid();
      
      sEvent.SetEvent(NewTerm);
    }
    else
    {
      trec[trTerm].State           = Breakout;
    }

    trec[trTerm].Age++;
    trec[trTerm].Root              = ActiveMid();
  }

//+------------------------------------------------------------------+
//| SetActiveState - Sets active state and alerts on change          |
//+------------------------------------------------------------------+
void CSession::SetActiveState(void)
  {
    ReservedWords stsState             = NoState;
    
    if (IsHigher(High[sBar],srec[ActiveSession].High))
    {
      sEvent.SetEvent(NewHigh);
      sEvent.SetEvent(NewBoundary);

      if (NewDirection(srec[ActiveSession].Direction,DirectionUp))
        stsState                       = Rally;

      if (IsHigher(srec[ActiveSession].High,srec[ActiveSession].Resistance,NoUpdate))
        if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionUp))
          stsState                     = Reversal;
        else
          stsState                     = Breakout;
    }
            
    if (IsLower(Low[sBar],srec[ActiveSession].Low))
    {
      sEvent.SetEvent(NewLow);
      sEvent.SetEvent(NewBoundary);

      if (NewDirection(srec[ActiveSession].Direction,DirectionDown))
        stsState                       = Pullback;

      if (IsLower(srec[ActiveSession].Low,srec[ActiveSession].Support,NoUpdate))
        if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionDown))
          stsState                     = Reversal;
        else
          stsState                     = Breakout;
    }
          
    if (NewState(srec[ActiveSession].State,stsState))
      sEvent.SetEvent(NewState);
  }
  
//+------------------------------------------------------------------+
//| OpenSession - Initializes active session start values on open    |
//+------------------------------------------------------------------+
void CSession::OpenSession(void)
  {    
    //-- Update Offsession Record
    srec[OffSession]                   = srec[ActiveSession];

    //-- Set support/resistance (ActiveSession is OffSession data)
    srec[ActiveSession].Resistance     = fmax(srec[ActiveSession].High,srec[PriorSession].High);
    srec[ActiveSession].Support        = fmin(srec[ActiveSession].Low,srec[PriorSession].Low);

    //-- Update indicator buffers
    sOffMidBuffer.SetValue(sBar,ActiveMid());
    sPriorMidBuffer.SetValue(sBar,PriorMid());

    //-- Reset Active Record
    srec[ActiveSession].High           = High[sBar];
    srec[ActiveSession].Low            = Low[sBar];

    //-- Set OpenSession flag
    sEvent.SetEvent(SessionOpen);
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes active session start values on close       |
//+------------------------------------------------------------------+
void CSession::CloseSession(void)
  {    
    //-- Set trend states
    SetTermState();
    SetTrendState();
    SetOriginState();
    
    //-- Update Prior Record
    srec[PriorSession]                     = srec[ActiveSession];

    //-- Reset Active Record
    srec[ActiveSession].Resistance     = srec[ActiveSession].High;
    srec[ActiveSession].Support        = srec[ActiveSession].Low;

    srec[ActiveSession].High           = High[sBar];
    srec[ActiveSession].Low            = Low[sBar];

    sEvent.SetEvent(SessionClose);
  }

//+------------------------------------------------------------------+
//| UpdateBuffers - updates indicator buffer values                  |
//+------------------------------------------------------------------+
void CSession::UpdateBuffers(void)
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
void CSession::LoadHistory(void)
  {    
    //--- Initialize period operationals
    sBar                             = Bars-1;
    sBars                            = Bars;
    sBarDay                          = NoValue;
    sBarHour                         = NoValue;

    //--- Initialize session records
    for (SessionRecType type=ActiveSession;type<SessionRecTypes;type++)
    {
      srec[type].Direction           = DirectionNone;
      srec[type].Age                 = 0;
      srec[type].State               = NoState;
      srec[type].BreakoutDir         = DirectionNone;      
      srec[type].High                = High[sBar];
      srec[type].Low                 = Low[sBar];
      srec[type].Resistance          = High[sBar];
      srec[type].Support             = Low[sBar];
    }

    //--- Initialize session records
    for (TrendRecType type=trTerm;type<TrendRecTypes;type++)
      trec[type]                     = Trend(NoValue);

    for(sBar=Bars-1;sBar>0;sBar--)
      Update();
  }

//+------------------------------------------------------------------+
//| Session Class Constructor                                        |
//+------------------------------------------------------------------+
CSession::CSession(SessionType Type, int HourOpen, int HourClose)
  {
    //--- Init global session values
    sType                           = Type;
    sHourOpen                       = HourOpen;
    sHourClose                      = HourClose;
    sSessionIsOpen                  = false;
    sTradeBias                      = NoValue;
    
    sEvent                          = new CEvent();

    sOffMidBuffer                   = new CArrayDouble(Bars);
    sOffMidBuffer.Truncate          = false;
    sOffMidBuffer.AutoExpand        = true;    
    sOffMidBuffer.SetPrecision(Digits);
    sOffMidBuffer.Initialize(0.00);
    
    sPriorMidBuffer                 = new CArrayDouble(Bars);
    sPriorMidBuffer.Truncate        = false;
    sPriorMidBuffer.AutoExpand      = true;
    sPriorMidBuffer.SetPrecision(Digits);
    sPriorMidBuffer.Initialize(0.00);
    
    LoadHistory();    
  }

//+------------------------------------------------------------------+
//| Session Class Destructor                                         |
//+------------------------------------------------------------------+
CSession::~CSession()
  {
    delete sEvent;
    delete sOffMidBuffer;
    delete sPriorMidBuffer;
  }

//+------------------------------------------------------------------+
//| Update - Updates open session data and events                    |
//+------------------------------------------------------------------+
void CSession::Update(void)
  {
    UpdateBuffers();
    
    //--- Clear events
    sEvent.ClearEvents();

    //--- Test for New Day; Force close
    if (IsChanged(sBarDay,TimeDay(Time[sBar])))
    {
      sEvent.SetEvent(NewDay);
      
      if (IsChanged(sSessionIsOpen,false))
        CloseSession();
    }
    
    if (IsChanged(sBarHour,TimeHour(Time[sBar])))
      sEvent.SetEvent(NewHour);

    //--- Calc events session open/close
    if (IsChanged(sSessionIsOpen,this.IsOpen()))
      if (sSessionIsOpen)
        OpenSession();
      else
        CloseSession();

    SetActiveState();
    SetTradeBias();
  }
  
//+------------------------------------------------------------------+
//| Update - Updates and returns buffer values                       |
//+------------------------------------------------------------------+
void CSession::Update(double &OffMidBuffer[], double &PriorMidBuffer[])
  {
    Update();
    
    sOffMidBuffer.Copy(OffMidBuffer);
    sPriorMidBuffer.Copy(PriorMidBuffer);
  }
  
//+------------------------------------------------------------------+
//| SessionIsOpen - Returns true if session is open for trade        |
//+------------------------------------------------------------------+
bool CSession::IsOpen(void)
  {
    if (TimeHour(Time[sBar])>=sHourOpen && TimeHour(Time[sBar])<sHourClose)
      return (true);
        
    return (false);
  }

//+------------------------------------------------------------------+
//| Trend - returns the requested trend record                       |
//+------------------------------------------------------------------+
TrendRec CSession::Trend(int Type)
  {
    static const TrendRec tRecord = {DirectionNone,NoValue,NoState,NoValue,NoValue};
    
    switch (Type)
    {
      case Term:          return (trec[trTerm]);
      case Trend:         return (trec[trTrend]);
      case Origin:        return (trec[trOrigin]);
    }
   
    return (tRecord);
  }
     
//+------------------------------------------------------------------+
//| TradeBias - returns the formatted current trade bias             |
//+------------------------------------------------------------------+
int CSession::TradeBias(int Format=InAction)
  {
    switch (Format)
    {
      case InAction:       return(sTradeBias);
      case InDirection:    return(Direction(sTradeBias,InAction));
    }
   
    return (NoValue);
  }
     
//+------------------------------------------------------------------+
//| ActiveMid - returns the current active mid price (Fibo50)        |
//+------------------------------------------------------------------+
double CSession::ActiveMid(void)
  {
    return(fdiv(srec[ActiveSession].High+srec[ActiveSession].Low,2,Digits));
  }
  
//+------------------------------------------------------------------+
//| PriorMid - returns the prior session mid price (Fibo50)          |
//+------------------------------------------------------------------+
double CSession::PriorMid(void)
  {
    return(fdiv(srec[PriorSession].High+srec[PriorSession].Low,2,Digits));
  }
  
//+------------------------------------------------------------------+
//| OffMid - returns the off session mid price (Fibo50)              |
//+------------------------------------------------------------------+
double CSession::OffMid(void)
  {
    return(fdiv(srec[OffSession].High+srec[OffSession].Low,2,Digits));
  }
  
//+------------------------------------------------------------------+
//| PrintSession - Prints Session Record details                     |
//+------------------------------------------------------------------+
void CSession::PrintSession(int Type)
  {  
    string psSessionInfo      = EnumToString(this.Type())+"|"
                              + TimeToStr(Time[sBar])+"|"
                              + BoolToStr(this.IsOpen(),"Open|","Closed|")
                              + BoolToStr(this.sSessionIsOpen,"Open|","Closed|")
                              + BoolToStr(srec[Type].Direction==DirectionUp,"Long|","Short|")
                              + IntegerToString(srec[Type].Age)+"|"
                              + EnumToString(srec[Type].State)+"|"
                              + DoubleToStr(srec[Type].High,Digits)+"|"
                              + DoubleToStr(srec[Type].Low,Digits)+"|"
                              + DoubleToStr(srec[Type].Resistance,Digits)+"|"
                              + DoubleToStr(srec[Type].Support,Digits);

    Print(psSessionInfo);
  }

//+------------------------------------------------------------------+
//| SessionHour - Returns the hour of open session trading           |
//+------------------------------------------------------------------+
int CSession::SessionHour(int Measure=Now)
  {    
    switch (Measure)
    {
      case SessionOpen:   return(sHourOpen);
      case SessionClose:  return(sHourClose);
      case Now:           if (sSessionIsOpen)
                            return (TimeHour(Time[sBar])-sHourOpen+1);
    }
    
    return (NoValue);
  }
