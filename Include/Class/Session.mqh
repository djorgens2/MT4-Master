//+------------------------------------------------------------------+
//|                                                      Session.mqh |
//|                                 Copyright 2018, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class/Event.mqh>
#include <Class/ArrayDouble.mqh>
#include <std_utility.mqh>

//+------------------------------------------------------------------+
//| Session Class - Collects session data, states, and events        |
//+------------------------------------------------------------------+
class CSession
  {

public:             
             //-- Period Types
             enum PeriodType
             {
               PriorSession,
               ActiveSession,
               OffSession,
               PeriodTypes
             };

             //-- Session Types
             enum SessionType
             {
               Daily,
               Asia,
               Europe,
               US,
               SessionTypes
             };

             //-- Session Record Definition
             struct SessionRec
             {
               int            Direction;
               ReservedWords  State;
               int            BreakoutDir;
               double         High;
               double         Low;
               double         Support;
               double         Resistance;
             };

             CSession(SessionType Type, int HourOpen, int HourClose, int GMTOffset);
            ~CSession();

             SessionType   Type(void)                       {return (sType);}
             int           SessionHour(int Measure=Now);
             bool          IsOpen(void);
             
             bool          Event(EventType Type)            {return (sEvent[Type]);}
             bool          ActiveEvent(void)                {return (sEvent.ActiveEvent());}
             string        ActiveEventText(void)            {return (sEvent.ActiveEventText());};
             
             datetime      ServerTime(int Bar=0);
             void          ShowDirArrow(bool Show)          {sShowDirArrow=Show;};
             
             double        Pivot(const PeriodType Type);
             int           Bias(void);

             void          Update(void);
             void          Update(double &OffSessionBuffer[], double &PriorMidBuffer[]);

             string        SessionText(PeriodType Type);
             
             SessionRec    operator[](const PeriodType Type) {return(srec[Type]);}
             
                                 
private:

             //--- Private Class properties
             SessionType   sType;
             
             bool          sSessionIsOpen;

             int           sHourOpen;
             int           sHourClose;
             int           sHourOffset;
             int           sBar;
             int           sBars;
             int           sBarDay;
             int           sBarHour;
             bool          sShowDirArrow;

             //--- Private class collections
             SessionRec    srec[6];
             
             CArrayDouble *sOffMidBuffer;
             CArrayDouble *sPriorMidBuffer;
             
             CEvent       *sEvent;
             
             //--- Private Methods
             void          OpenSession(void);
             void          CloseSession(void);

             void          UpdateSession(void);
             void          UpdateActive(void);
             void          UpdateBuffers(void);

             void          LoadHistory(void);
             
             bool          NewDirection(int &Direction, int NewDirection);
             bool          NewState(ReservedWords &State, ReservedWords NewState);
  };

//+------------------------------------------------------------------+
//| ServerTime - Returns the adjusted time based on server offset    |
//+------------------------------------------------------------------+
datetime CSession::ServerTime(int Bar=0)
  {
    //-- Time is set to reflect 5:00pm New York as end of trading day
    
    return(Time[Bar]+(PERIOD_H1*60*sHourOffset));
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

    if (State==Reversal)
      if (ChangeState==Breakout)
        ChangeState               = State;
      else
      if (ChangeState==Reversal && sEvent[NewDirection])
        State                     = Breakout;
      
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
        case Trap:        sEvent.SetEvent(NewTrap);
                          break;
      }
      
      return(true);
    }
      
    return(false);
  }

//+------------------------------------------------------------------+
//| UpdateActive - Sets active state, bounds and alerts on the tick  |
//+------------------------------------------------------------------+
void CSession::UpdateActive(void)
  {
    ReservedWords usState              = NoState;
    ReservedWords usHighState          = NoState;

    SessionRec    usLastSession        = srec[ActiveSession];

    if (IsHigher(High[sBar],srec[ActiveSession].High))
    {
      sEvent.SetEvent(NewHigh);
      sEvent.SetEvent(NewBoundary);

      if (NewDirection(srec[ActiveSession].Direction,DirectionUp))
//        if (this.Bias()==OP_BUY)
          usState                      = Rally;

      if (IsHigher(srec[ActiveSession].High,srec[PriorSession].High,NoUpdate))
        if (!sSessionIsOpen)
          usState                      = Trap;
              
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
//        if (this.Bias()==OP_SELL) - How to get this work
          usState                      = Pullback;

      if (IsLower(srec[ActiveSession].Low,srec[PriorSession].Low,NoUpdate))
        if (!sSessionIsOpen)
          usState                      = Trap;
      
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
    
    if (NewState(srec[ActiveSession].State,usState))
      if (usState==Reversal || usState==Breakout)
        if (sShowDirArrow)
        {
          if (sEvent[NewHigh])
            NewArrow(SYMBOL_ARROWUP,clrYellow,EnumToString(sType)+"-"+EnumToString(usState),fmax(usLastSession.High,usLastSession.Resistance),sBar);

          if (sEvent[NewLow])
            NewArrow(SYMBOL_ARROWDOWN,clrRed,EnumToString(sType)+"-"+EnumToString(usState),fmin(usLastSession.Low,usLastSession.Support),sBar);
        }
  }
  
//+------------------------------------------------------------------+
//| UpdateSession - Calls update procedures for each fractal group   |
//+------------------------------------------------------------------+
void CSession::UpdateSession(void)
  {
    UpdateActive();
  }
  
//+------------------------------------------------------------------+
//| OpenSession - Initializes active session start values on open    |
//+------------------------------------------------------------------+
void CSession::OpenSession(void)
  {
    //-- Update OffSession Record and Indicator Buffer
    srec[OffSession]                      = srec[ActiveSession];
    sOffMidBuffer.SetValue(sBar,Pivot(ActiveSession));

    //-- Set support/resistance (ActiveSession is OffSession data)
    srec[ActiveSession].Resistance        = fmax(srec[ActiveSession].High,srec[PriorSession].High);
    srec[ActiveSession].Support           = fmin(srec[ActiveSession].Low,srec[PriorSession].Low);
    srec[ActiveSession].High              = Close[fmin(Bars-1,sBar+1)];
    srec[ActiveSession].Low               = Close[fmin(Bars-1,sBar+1)];
    
    //-- Set OpenSession flag
    sEvent.SetEvent(SessionOpen);
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes active session start values on close       |
//+------------------------------------------------------------------+
void CSession::CloseSession(void)
  {        
    //-- Update Prior Record and Indicator Buffer
    srec[PriorSession]                    = srec[ActiveSession];
    sPriorMidBuffer.SetValue(sBar,Pivot(PriorSession));

    //-- Reset Active Record
    srec[ActiveSession].Resistance        = fmax(srec[ActiveSession].High,srec[OffSession].High);
    srec[ActiveSession].Support           = fmin(srec[ActiveSession].Low,srec[OffSession].Low);
    srec[ActiveSession].High              = Close[fmin(Bars-1,sBar+1)];
    srec[ActiveSession].Low               = Close[fmin(Bars-1,sBar+1)];
    
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
    int lhStartDir                   = DirectionNone;
    
    if (Close[sBar]<Open[sBar])
      lhStartDir                     = DirectionDown;
      
    if (Close[sBar]>Open[sBar])
      lhStartDir                     = DirectionUp;
      
    //--- Initialize period operationals
    sBar                             = Bars-1;
    sBars                            = Bars;
    sBarDay                          = NoValue;
    sBarHour                         = NoValue;
    
    //--- Initialize session records
    for (int type=0;type<ArraySize(srec);type++)
    {
      srec[type].Direction           = lhStartDir;
      srec[type].State               = Breakout;
      srec[type].BreakoutDir         = lhStartDir;      
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

    for(sBar=Bars-1;sBar>0;sBar--)
      Update();
  }

//+------------------------------------------------------------------+
//| Session Class Constructor                                        |
//+------------------------------------------------------------------+
CSession::CSession(SessionType Type, int HourOpen, int HourClose, int HourOffset)
  {
    //--- Init global session values
    sType                            = Type;
    sHourOpen                        = HourOpen;
    sHourClose                       = HourClose;
    sHourOffset                      = HourOffset;
    sSessionIsOpen                   = false;
    sShowDirArrow                    = true;
    
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
    
    Print("Server Time: "+TimeToString(ServerTime()));
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
    if (IsChanged(sBarDay,TimeDay(ServerTime(sBar))))
    {
      sEvent.SetEvent(NewDay);
      
      if (IsChanged(sSessionIsOpen,false))
        CloseSession();
    }
    
    if (IsChanged(sBarHour,TimeHour(ServerTime(sBar))))
      sEvent.SetEvent(NewHour);

    //--- Calc events session open/close
    if (IsChanged(sSessionIsOpen,this.IsOpen()))
      if (sSessionIsOpen)
        OpenSession();
      else
        CloseSession();

    UpdateSession();
    
//    if (sEvent[SessionClose])
//      Print(SessionText(Term));
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
    if (TimeDayOfWeek(ServerTime(sBar))<6)
      if (TimeHour(ServerTime(sBar))>=sHourOpen && TimeHour(ServerTime(sBar))<sHourClose)
        return (true);
        
    return (false);
  }

//+------------------------------------------------------------------+
//| Pivot - returns the mid price for the supplied type              |
//+------------------------------------------------------------------+
double CSession::Pivot(const PeriodType Type)
  {
    return(fdiv(srec[Type].High+srec[Type].Low,2,Digits));
  }

//+------------------------------------------------------------------+
//| Bias - returns the order action relative to the root             |
//+------------------------------------------------------------------+
int CSession::Bias(void)
  {
    if (IsOpen())
    {
      if (Pivot(ActiveSession)>Pivot(OffSession))
        return (OP_BUY);

      if (Pivot(ActiveSession)<Pivot(OffSession))
        return (OP_SELL);
    }      
    else
    {
      if (Pivot(ActiveSession)>Pivot(PriorSession))
        return (OP_BUY);

      if (Pivot(ActiveSession)<Pivot(PriorSession))
        return (OP_SELL);
    }
      
    return (Action(srec[ActiveSession].Direction,InDirection));
  }

//+------------------------------------------------------------------+
//| SessionText - Returns formatted Session data for supplied type   |
//+------------------------------------------------------------------+
string CSession::SessionText(PeriodType Type)
  {  
    string siSessionInfo        = EnumToString(this.Type())+"|"
                                + TimeToStr(Time[sBar])+"|"
                                + BoolToStr(this.IsOpen(),"Open|","Closed|")
                                + DoubleToStr(Pivot(ActiveSession),Digits)+"|"
                                + BoolToStr(srec[Type].Direction==DirectionUp,"Long|","Short|")                              
                                + EnumToString(srec[Type].State)+"|"
                                + DoubleToStr(srec[Type].High,Digits)+"|"
                                + DoubleToStr(srec[Type].Low,Digits)+"|"
                                + DoubleToStr(srec[Type].Resistance,Digits)+"|"
                                + DoubleToStr(srec[Type].Support,Digits)+"|"
                                + BoolToStr(srec[Type].BreakoutDir==DirectionUp,"Long|","Short|");

    return(siSessionInfo);
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
                            return (TimeHour(ServerTime(sBar))-sHourOpen+1);
    }
    
    return (NoValue);
  }
