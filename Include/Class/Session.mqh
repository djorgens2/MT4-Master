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
               int            Days;
               ReservedWords  State;
               int            StateDir;
               double         Base;
               double         Root;
             };
             
             //-- Session Record Definition
             struct SessionRec
             {
               int            Direction;
               ReservedWords  State;
               int            BreakoutDir;
               double         ActiveOpen;
               double         ActiveClose;
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

             //-- Trend Record Types
             enum TrendRecType
             {
               trTerm,
               trTrend,
               trOrigin,
               TrendRecTypes
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
             
             TrendRec      Trend(TrendRecType Type);

             int           TrendBias(int Format=InAction);
             int           ActiveBias(int Format=InAction);

             void          PrintSession(int Type);
             void          PrintTrend(TrendRecType Type, int Measure=Active);
             
             SessionRec    operator[](const SessionRecType Type) const {return(srec[Type]);}
             
                                 
private:

             //--- Private Class properties
             SessionType   sType;
             
             bool          sSessionIsOpen;
             int           sTrendBias;             //--- Trend action
             int           sActiveBias;            //--- Active action

             int           sHourOpen;
             int           sHourClose;
             int           sBar;
             int           sBars;
             int           sBarDay;
             int           sBarHour;
             datetime      sStateTime;

             //--- Private class collections
             SessionRec    srec[SessionRecTypes];
             TrendRec      trec[TrendRecTypes];    //--- holds current trend data
             TrendRec      ptrec[TrendRecTypes];   //--- holds trend data from prior close;
                          
             CArrayDouble *sOffMidBuffer;
             CArrayDouble *sPriorMidBuffer;
             
             CEvent       *sEvent;
             
             //--- Private Methods
             void          OpenSession(void);
             void          CloseSession(void);
             void          UpdateSession(void);
             void          UpdateBuffers(void);

             void          LoadHistory(void);

             void          UpdateBiases(void);
             void          UpdateTrendState(TrendRecType Type);

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
//| UpdateBiases - returns the trade bias on the tick                |
//+------------------------------------------------------------------+
void CSession::UpdateBiases(void)
  {
    int stbTrendBias        = sTrendBias;
  
    if (ActiveMid()>PriorMid())
      stbTrendBias          = OP_BUY;

    if (ActiveMid()<PriorMid())
      stbTrendBias          = OP_SELL;
      
    if (IsChanged(sTrendBias,stbTrendBias))
      sEvent.SetEvent(MarketCorrection);
      
    if (IsChanged(sActiveBias,Action(srec[ActiveSession].ActiveClose-srec[ActiveSession].ActiveOpen,InDirection)))
      sEvent.SetEvent(NewTradeBias);
      
//    if (sBar>0)
//    {
//      if (sEvent[MarketCorrection])
//      {
//        ObjectCreate("Corr("+EnumToString(sType)+"):"+TimeToString(Time[sBar],TIME_DATE)+IntegerToString(sBarHour),OBJ_ARROW,0,Time[sBar],ActiveMid());
//        ObjectSet("Corr("+EnumToString(sType)+"):"+TimeToString(Time[sBar],TIME_DATE)+IntegerToString(sBarHour),OBJPROP_ARROWCODE,SYMBOL_RIGHTPRICE);
//        ObjectSet("Corr("+EnumToString(sType)+"):"+TimeToString(Time[sBar],TIME_DATE)+IntegerToString(sBarHour),OBJPROP_COLOR,BoolToInt(sTrendBias==OP_BUY,clrYellow,clrRed));
//      }
//
//      if (sEvent[NewTradeBias])
//      {
//        ObjectCreate("Hour("+EnumToString(sType)+"):"+TimeToString(Time[sBar],TIME_DATE)+IntegerToString(sBarHour),OBJ_ARROW,0,Time[sBar],ActiveMid());
//        ObjectSet("Hour("+EnumToString(sType)+"):"+TimeToString(Time[sBar],TIME_DATE)+IntegerToString(sBarHour),OBJPROP_ARROWCODE,BoolToInt(sActiveBias==OP_BUY,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN));
//        ObjectSet("Hour("+EnumToString(sType)+"):"+TimeToString(Time[sBar],TIME_DATE)+IntegerToString(sBarHour),OBJPROP_COLOR,BoolToInt(sActiveBias==OP_BUY,clrYellow,clrRed));
//      }
//    }
 
//    if (sEvent[NewHour])
//      PrintSession(ActiveSession);
  }

//+------------------------------------------------------------------+
//| SetOriginState - Sets Origin state on changes to Trend State     |
//+------------------------------------------------------------------+
void CSession::SetOriginState(void)
  {
    if (trec[trOrigin].State==NoState)
    {
      trec[trOrigin]                 = trec[trTerm];
      
    }
    else
    {}
  }

//+------------------------------------------------------------------+
//| SetTrendState - Sets trend state and updates support/resistance  |
//+------------------------------------------------------------------+
void CSession::SetTrendState(void)
  {
    ReservedWords stsState          = trec[trTrend].State;
    
    if (IsBetween(ActiveMid(),trec[trTrend].Base,trec[trTrend].Root,Digits))
    {
      //-- Set in bounds trade state
      if (trec[trTerm].Direction==DirectionUp)
      {
        stsState                    = Rally;
        trec[trTrend].StateDir      = DirectionUp; 
      }
      else
      {
        stsState                    = Pullback;
        trec[trTrend].StateDir      = DirectionDown; 
      }
    }
    else
    if (IsHigher(ActiveMid(),trec[trTrend].Root))
    {
      trec[trTrend].StateDir        = DirectionUp; 

      //-- Handle up trends
      if (IsChanged(trec[trTrend].Direction,DirectionUp))
        stsState                    = Reversal;
      else
        stsState                    = Breakout;
    }
    else
    if (IsLower(ActiveMid(),trec[trTrend].Root))
    {
      trec[trTrend].StateDir        = DirectionDown; 

      //-- Handle down trends
      if (IsChanged(trec[trTrend].Direction,DirectionDown))
        stsState                    = Reversal;
      else
        stsState                    = Breakout;
    }

//    if (trec[trTrend].State!=stsState)
//        Print("Should be a New State:"+EnumToString(stsState)+"|"+EnumToString(trec[trTrend].State));
    
    if (NewState(trec[trTrend].State,stsState))
    {
//        Print(BoolToStr(sEvent[NewState],"New State:","Not NS:")+EnumToString(stsState));
      if (stsState==Breakout||stsState==Reversal)
      {
        trec[trTrend].Root          = ActiveMid();
        trec[trTrend].Base          = trec[trTerm].Base;
      }
    }
          //PrintSession(ActiveSession);
          //PrintSession(PriorSession);
//          PrintTrend(trTerm);
//          PrintTrend(trTerm,Prior);

//          PrintTrend(trTrend);
//          PrintTrend(trTrend,Prior);
  }
  
//+------------------------------------------------------------------+
//| SetTermState - Sets Term on daily change to Active State         |
//+------------------------------------------------------------------+
void CSession::SetTermState(void)
  {
    if (IsChanged(trec[trTerm].Direction,TrendBias(InDirection)))
    {
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
      
      trec[trTerm].Days            = 0;      
      trec[trTerm].Base            = PriorMid();
      trec[trTerm].StateDir        = trec[trTerm].Direction;
      
      sEvent.SetEvent(NewTerm);
    }
    else
    {
      trec[trTerm].State           = Breakout;
    }

    trec[trTerm].Days++;
    trec[trTerm].Root              = ActiveMid();
  }

//+------------------------------------------------------------------+
//| UpdateTrendState - Tests for inter-session state changes         |
//+------------------------------------------------------------------+
void CSession::UpdateTrendState(TrendRecType Type)
  {
    EventType TrendEvent[TrendRecTypes] = {NewTerm,NewTrend,NewOrigin};
    
    if (sEvent[MarketCorrection])
      if (this.TrendBias(InDirection)==trec[Type].Direction)
      {
        trec[Type].State         = Recovery;
        trec[Type].StateDir      = trec[Type].Direction;
      }
      else
      {
        trec[Type].State         = Correction;
        trec[Type].StateDir      = Direction(trec[Type].Direction,InDirection,InContrarian);
      }
        
    if (trec[Type].Direction==DirectionUp)
    {
      if (IsLower(this.ActiveMid(),ptrec[Type].Base,NoUpdate))
//        if (NewDirection(trec[Type].Direction,
        if (NewState(trec[Type].State,Reversal))
          sEvent.SetEvent(TrendEvent[Type]);

      if (IsHigher(this.ActiveMid(),trec[Type].Root,NoUpdate))
        if (NewState(trec[Type].State,Breakout))
          sEvent.SetEvent(TrendEvent[Type]);
    }
        
    if (trec[Type].Direction==DirectionDown)
    {
      if (IsLower(this.ActiveMid(),trec[Type].Root,NoUpdate))
        if (NewState(trec[Type].State,Breakout))
          sEvent.SetEvent(TrendEvent[Type]);

      if (IsHigher(this.ActiveMid(),trec[Type].Base,NoUpdate))
        if (NewState(trec[Type].State,Reversal))
          sEvent.SetEvent(TrendEvent[Type]);        
    }
  }

//+------------------------------------------------------------------+
//| UpdateSession - Sets active state, bounds and alerts on the tick |
//+------------------------------------------------------------------+
void CSession::UpdateSession(void)
  {
    ReservedWords usState              = NoState;
    ReservedWords usHighState          = NoState;
    
    if (IsHigher(High[sBar],srec[ActiveSession].High))
    {
      sEvent.SetEvent(NewHigh);
      sEvent.SetEvent(NewBoundary);

      if (NewDirection(srec[ActiveSession].Direction,DirectionUp))
        usState                        = Rally;

      if (IsHigher(srec[ActiveSession].High,srec[ActiveSession].Resistance,NoUpdate))
        if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionUp))
          usState                      = Reversal;
        else
          usState                      = Breakout;
          
      usHighState                      = usState;   //-- Retain high on outside reversal
    }
            
    if (IsLower(Low[sBar],srec[ActiveSession].Low))
    {
      sEvent.SetEvent(NewLow);
      sEvent.SetEvent(NewBoundary);

      if (NewDirection(srec[ActiveSession].Direction,DirectionDown))
        usState                        = Pullback;

      if (IsLower(srec[ActiveSession].Low,srec[ActiveSession].Support,NoUpdate))
        if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionDown))
          usState                      = Reversal;
        else
          usState                      = Breakout;
    }
    
    //-- Apply outside reversal correction possible only during historical analysis
    if (sEvent[NewHigh] && sEvent[NewLow])
    {
      if (IsChanged(srec[ActiveSession].Direction,Direction(Close[sBar]-Open[sBar])))
        if (srec[ActiveSession].Direction==DirectionUp)
        {
          usState                      = usHighState;  //-- Outside reversal; use retained high
          sEvent.ClearEvent(NewLow);
        }
        else
          sEvent.ClearEvent(NewHigh);
    }
    
    if (sEvent[NewBoundary])          
      srec[ActiveSession].ActiveClose  = ActiveMid();

    if (NewState(srec[ActiveSession].State,usState))
      sStateTime                       = Time[sBar];
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
    srec[ActiveSession].ActiveOpen     = ActiveMid();
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
    srec[PriorSession]                 = srec[ActiveSession];

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
      srec[type].State               = NoState;
      srec[type].BreakoutDir         = DirectionNone;      
      srec[type].High                = High[sBar];
      srec[type].Low                 = Low[sBar];
      srec[type].Resistance          = High[sBar];
      srec[type].Support             = Low[sBar];
    }

    //--- Initialize session records
    //--- *** May need to modify this if the sbar Open==Close
    if (IsEqual(Open[sBar],Close[sBar]))
    {
      Print ("Freak anomaly: aborting due to sbar(Open==Close)");
      ExpertRemove();
      return;
    }
    else
    for (TrendRecType type=trTerm;type<TrendRecTypes;type++)
    {
      trec[type].State               = NoState;

      if (Close[sBar]<Open[sBar])
      {
        trec[type].Direction         = DirectionDown;
        trec[type].Days              = 0;
        trec[type].State             = Pullback;
        trec[type].StateDir          = DirectionDown;
        trec[type].Base              = High[sBar];
        trec[type].Root              = Low[sBar];
      }
      
      if (Close[sBar]>Open[sBar])
      {
        trec[type].Direction         = DirectionUp;
        trec[type].Days              = 0;
        trec[type].State             = Rally;
        trec[type].StateDir          = DirectionUp;
        trec[type].Base              = Low[sBar];
        trec[type].Root              = High[sBar];
      }
      
      ptrec[type]                    = trec[type];
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
    sType                            = Type;
    sHourOpen                        = HourOpen;
    sHourClose                       = HourClose;
    sSessionIsOpen                   = false;
    sTrendBias                       = NoValue;
    
    sEvent                           = new CEvent();

    sOffMidBuffer                    = new CArrayDouble(Bars);
    sOffMidBuffer.Truncate           = false;
    sOffMidBuffer.AutoExpand         = true;    
    sOffMidBuffer.SetPrecision(Digits);
    sOffMidBuffer.Initialize(0.00);
    
    sPriorMidBuffer                  = new CArrayDouble(Bars);
    sPriorMidBuffer.Truncate         = false;
    sPriorMidBuffer.AutoExpand       = true;
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

    UpdateSession();
    UpdateBiases();

    for (TrendRecType type=trTerm;type<TrendRecTypes;type++)
      UpdateTrendState(type);      
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
TrendRec CSession::Trend(TrendRecType Type)
  {    
    return (trec[Type]);
  }
     
//+------------------------------------------------------------------+
//| TradeBias - returns the formatted current trend bias             |
//+------------------------------------------------------------------+
int CSession::TrendBias(int Format=InAction)
  {
    switch (Format)
    {
      case InAction:       return(sTrendBias);
      case InDirection:    return(Direction(sTrendBias,InAction));
    }
   
    return (NoValue);
  }
     
//+------------------------------------------------------------------+
//| ActiveBias - returns the formatted current hourly bias           |
//+------------------------------------------------------------------+
int CSession::ActiveBias(int Format=InAction)
  {
    switch (Format)
    {
      case InAction:       return(sActiveBias);
      case InDirection:    return(Direction(sActiveBias,InAction));
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
                              + TimeToStr(sStateTime)+"|"
                              + DoubleToStr(ActiveMid(),Digits)+"|"
                              + BoolToStr(srec[Type].Direction==DirectionUp,"Long|","Short|")                              
                              + EnumToString(srec[Type].State)+"|"
                              + DoubleToStr(srec[Type].ActiveOpen,Digits)+"|"
                              + DoubleToStr(srec[Type].High,Digits)+"|"
                              + DoubleToStr(srec[Type].Low,Digits)+"|"
                              + DoubleToStr(srec[Type].ActiveClose,Digits)+"|"
                              + DoubleToStr(srec[Type].Resistance,Digits)+"|"
                              + DoubleToStr(srec[Type].Support,Digits)+"|"
                              + "(Bias/Hr/Brk):"+"|"
                              + BoolToStr(sTrendBias==OP_BUY,"Long|","Short|")
                              + BoolToStr(sActiveBias==OP_BUY,"Long|","Short|")
                              + BoolToStr(srec[Type].BreakoutDir==DirectionUp,"Long|","Short|");

    Print(psSessionInfo);
  }

//+------------------------------------------------------------------+
//| PrintTrend - Prints Trend Record details                         |
//+------------------------------------------------------------------+
void CSession::PrintTrend(TrendRecType Type, int Measure=Active)
  {
    TrendRec ptRec            = trec[Type];
    
    if (Measure==Prior)
      ptRec                   = trec[Type];
    
    string ptData             = EnumToString(this.Type())+"|"
                              + EnumToString(Type)+"|"
                              + TimeToStr(Time[sBar])+"|"
                              + BoolToStr(this.IsOpen(),"Open|","Closed|")
                              + BoolToStr(this.sSessionIsOpen,"Open|","Closed|")
                              + DoubleToStr(ActiveMid(),Digits)+"|"
                              + BoolToStr(ptRec.Direction==DirectionUp,"Long|","Short|")
                              + IntegerToString(ptRec.Days)+"|"
                              + EnumToString(ptRec.State)+"|"
                              + BoolToStr(ptRec.StateDir==DirectionUp,"Long|","Short|")
                              + DoubleToStr(ptRec.Base,Digits)+"|"
                              + DoubleToStr(ptRec.Root,Digits);

    Print(ptData);
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
