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
               double         Correction;
               double         Hedge;
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

             //-- Record Types
             enum RecordType
             {
               ActiveRec,
               OffsessionRec,
               PriorRec,
               OriginRec,
               TrendRec,
               TermRec,
               RecordTypes
             };
             
             CSession(SessionType Type, int HourOpen, int HourClose);
            ~CSession();

             SessionType   Type(void)                  {return (sType);}
             int           SessionHour(int Measure=Now);
             bool          IsOpen(void);
             
             bool          Event(EventType Type)       {return (sEvent[Type]);}
             bool          ActiveEvent(void)           {return (sEvent.ActiveEvent());}

             void          Update(void);
             void          Update(double &OffSessionBuffer[], double &PriorMidBuffer[]);

             double        ActiveMid(void);
             double        PriorMid(void);
             double        OffsessionMid(void);

             int           TradeBias(void);
             void          PrintSession(int Type);
             
             SessionRec    operator[](const int Type) const {return(srec[Type]);}
             
                                 
private:

             //--- Private Class properties
             SessionType   sType;
             
             bool          sSessionIsOpen;

             int           sHourOpen;
             int           sHourClose;
             int           sBar;
             int           sBars;
             int           sBarDay;
             int           sBarHour;
             

             //--- Private class collections
             SessionRec    srec[6];
                          
             CArrayDouble *sOffMidBuffer;
             CArrayDouble *sPriorMidBuffer;
             
             CEvent       *sEvent;
             
             //--- Private Methods
             void          OpenSession(void);
             void          CloseSession(void);
             void          UpdateSession(void);
             void          UpdateBuffers(void);

             void          LoadHistory(void);
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
    else
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
//    srTrend.State           = State;
//    
//    switch (State)
//    {
//      case Breakout:   
//      case Reversal:  srTrend.Age             = srActive.Age;
//    
//                      if (srTrend.TrendDir==DirectionUp)
//                      {
//                        srTrend.Support       = srTrend.Pullback;
//                        srTrend.Rally         = ActiveMid();
//                      }
//                      
//                      if (srTrend.TrendDir==DirectionDown)
//                      {
//                        srTrend.Resistance    = srTrend.Rally;
//                        srTrend.Pullback      = ActiveMid();
//                      }
//                      break;
//                      
//       case Rally:
//       case Pullback: if (srTrend.TrendDir==DirectionUp)
//                        srTrend.Rally         = ActiveMid();
//
//                      if (srTrend.TrendDir==DirectionDown)
//                        srTrend.Pullback      = ActiveMid();
//     }
  }
  
//+------------------------------------------------------------------+
//| SetTermState - Sets Term state based on changes to Active State  |
//+------------------------------------------------------------------+
void CSession::SetTermState(void)
  {
  }

//+------------------------------------------------------------------+
//| SetActiveState - Sets active state and alerts on change          |
//+------------------------------------------------------------------+
void CSession::SetActiveState(void)
  {
    ReservedWords stsState             = NoState;
    
//      sEvent.SetEvent(NewTerm); //<---- here's where the term update happens
      
    if (IsHigher(High[sBar],srec[ActiveRec].High))
    {
      sEvent.SetEvent(NewHigh);
      sEvent.SetEvent(NewBoundary);

      if (IsHigher(srec[ActiveRec].High,srec[ActiveRec].Resistance,NoUpdate))
        if (NewDirection(srec[ActiveRec].BreakoutDir,DirectionUp))
          stsState                   = Reversal;
        else
          stsState                   = Breakout;
      else
        if (NewDirection(srec[ActiveRec].Direction,DirectionUp))
          stsState                   = Rally;
    }
            
    if (IsLower(Low[sBar],srec[ActiveRec].Low))
    {
      sEvent.SetEvent(NewLow);
      sEvent.SetEvent(NewBoundary);

      if (IsLower(srec[ActiveRec].Low,srec[ActiveRec].Support,NoUpdate))
        if (NewDirection(srec[ActiveRec].BreakoutDir,DirectionDown))
          stsState                   = Reversal;
        else
          stsState                   = Breakout;
      else
        if (NewDirection(srec[ActiveRec].Direction,DirectionDown))
          stsState                   = Pullback;
    }
          
    if (NewState(srec[ActiveRec].State,stsState))
      sEvent.SetEvent(NewState);
  }
  
//+------------------------------------------------------------------+
//| OpenSession - Initializes active session start values on open    |
//+------------------------------------------------------------------+
void CSession::OpenSession(void)
  {    
    //-- Update Offsession Record
    srec[OffsessionRec]                = srec[ActiveRec];

    //-- Set support/resistance (ActiveRec is Offsession data)
    srec[ActiveRec].Resistance         = fmax(srec[ActiveRec].High,srec[PriorRec].High);
    srec[ActiveRec].Support            = fmin(srec[ActiveRec].Low,srec[PriorRec].Low);
    srec[ActiveRec].Hedge              = PriorMid();
    srec[ActiveRec].Correction         = ActiveMid();

    //-- Update indicator buffers
    sOffMidBuffer.SetValue(sBar,ActiveMid());
    sPriorMidBuffer.SetValue(sBar,PriorMid());

    //-- Reset Active Record
    srec[ActiveRec].High               = High[sBar];
    srec[ActiveRec].Low                = Low[sBar];
    
    PrintSession(PriorRec);

    //-- Set OpenSession flag
    sEvent.SetEvent(SessionOpen);
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes active session start values on close       |
//+------------------------------------------------------------------+
void CSession::CloseSession(void)
  {

//
//    srActive.Age++;
//    srTrend.Age++;
//    
      //--- Calc session close events
//
//        if (IsLower(ActiveMid(),srActive.PriorMid))
//          if (IsChanged(srTrend.TrendDir,DirectionDown))
//            sEvent.SetEvent(NewTrend);
//        
//        if (IsHigher(ActiveMid(),srActive.PriorMid))
//          if (IsChanged(srTrend.TrendDir,DirectionUp))
//            sEvent.SetEvent(NewTrend);
//            
//        if (srTrend.TrendDir==DirectionUp)
//          if (IsHigher(ActiveMid(),srTrend.Resistance))
//            if (IsChanged(srTrend.OriginDir,srTrend.TrendDir))
//              sEvent.SetEvent(NewReversal);
//            else
//              sEvent.SetEvent(NewBreakout);
//          else
//            sEvent.SetEvent(NewRally);
//
//        if (srTrend.TrendDir==DirectionDown)
//          if (IsLower(ActiveMid(),srTrend.Support))
//            if (IsChanged(srTrend.OriginDir,srTrend.TrendDir))
//              sEvent.SetEvent(NewReversal);
//            else
//              sEvent.SetEvent(NewBreakout);
//          else
//            sEvent.SetEvent(NewPullback);

    //-- Update Offsession Record
    srec[PriorRec]                     = srec[ActiveRec];

    srec[ActiveRec].Resistance         = srec[ActiveRec].High;
    srec[ActiveRec].Support            = srec[ActiveRec].Low;

    srec[ActiveRec].High               = High[sBar];
    srec[ActiveRec].Low                = Low[sBar];

    sEvent.SetEvent(SessionClose);
  }

//+------------------------------------------------------------------+
//| UpdateSession - Updates active pricing and sets range events     |
//+------------------------------------------------------------------+
void CSession::UpdateSession(void)
  {      
    SetActiveState();
    
    if (sEvent[NewState])
      SetTermState();
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
    for (RecordType type=ActiveRec;type<RecordTypes;type++)
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

    //--- Test for New Day/New Hour
    if (IsChanged(sBarDay,TimeDay(Time[sBar])))
    {
      if (sSessionIsOpen)
        CloseSession();

      sEvent.SetEvent(NewDay);
    }
    
    if (IsChanged(sBarHour,TimeHour(Time[sBar])))
      sEvent.SetEvent(NewHour);

    //--- Calc events session open/close
    if (IsChanged(sSessionIsOpen,this.IsOpen()))
      if (sSessionIsOpen)
        OpenSession();
      else
        CloseSession();

    UpdateSession();
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
//| TradeBias - returns the trade bias based on Time Period          |
//+------------------------------------------------------------------+
int CSession::TradeBias(void)
  {
    if (ActiveMid()>PriorMid())
      return(OP_BUY);

    if (ActiveMid()<PriorMid())
      return(OP_SELL);
      
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| ActiveMid - returns the current active mid price (Fibo50)        |
//+------------------------------------------------------------------+
double CSession::ActiveMid(void)
  {
    return(fdiv(srec[ActiveRec].High+srec[ActiveRec].Low,2,Digits));
  }
  
//+------------------------------------------------------------------+
//| PriorMid - returns the prior session mid price (Fibo50)          |
//+------------------------------------------------------------------+
double CSession::PriorMid(void)
  {
    return(fdiv(srec[PriorRec].High+srec[PriorRec].Low,2,Digits));
  }
  
//+------------------------------------------------------------------+
//| OffsessionMid - returns the offsession mid price (Fibo50)        |
//+------------------------------------------------------------------+
double CSession::OffsessionMid(void)
  {
    return(fdiv(srec[OffsessionRec].High+srec[OffsessionRec].Low,2,Digits));
  }
  
//+------------------------------------------------------------------+
//| PrintSession - Prints Session Record details                     |
//+------------------------------------------------------------------+
void CSession::PrintSession(int Type)
  {  
    string psSessionInfo      = EnumToString(this.Type())+"|"
                              + BoolToStr(srec[Type].Direction==DirectionUp,"Long|","Short|")
                              + IntegerToString(srec[Type].Age)+"|"
                              + EnumToString(srec[Type].State)+"|"
                              + DoubleToStr(srec[Type].High,Digits)+"|"
                              + DoubleToStr(srec[Type].Low,Digits)+"|"
                              + DoubleToStr(srec[Type].Resistance,Digits)+"|"
                              + DoubleToStr(srec[Type].Support,Digits)+"|"
                              + DoubleToStr(srec[Type].Correction,Digits)+"|"
                              + DoubleToStr(srec[Type].Hedge,Digits);

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
