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
#include <std_utility.mqh>

//+------------------------------------------------------------------+
//| SessionArray Class - Collects session data, states, and events   |
//+------------------------------------------------------------------+
class CSession
  {

public:             
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

             //-- Session Record Definition
             struct FiboRec
             {
               int            Direction;
               ReservedWords  State;
               int            BreakoutDir;
               double         Retrace;
               double         Expansion;
               double         Base;
               double         Root;
             };

             CSession(SessionType Type, int HourOpen, int HourClose);
            ~CSession();

             SessionType   Type(void)                       {return (sType);}
             int           SessionHour(int Measure=Now);
             bool          IsOpen(void);
             
             bool          Event(EventType Type)            {return (sEvent[Type]);}
             bool          ActiveEvent(void)                {return (sEvent.ActiveEvent());}
             string        ActiveEventText(void)            {return (sEvent.ActiveEventText());};
             void          ShowDirArrow(bool Show)          {sShowDirArrow=Show;};
             
             double        Pivot(const int Type);
             int           Bias(void);

             void          Update(void);
             void          Update(double &OffSessionBuffer[], double &PriorMidBuffer[]);

             string        SessionText(int Type);
             
             FiboRec       Fibo(int Type);
             SessionRec    operator[](const int Type)       {return(srec[RecordType(Type)]);}
             
                                 
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
             bool          sShowDirArrow;

             //--- Private class collections
             SessionRec    srec[6];
             
             CArrayDouble *sOffMidBuffer;
             CArrayDouble *sPriorMidBuffer;
             
             CEvent       *sEvent;
             
             //--- Private Methods
             int           RecordType(int Type);

             void          OpenSession(void);
             void          CloseSession(void);

             void          UpdateSession(void);
             void          UpdateFractal(void);
             void          UpdateActive(void);
             void          UpdateBuffers(void);

             void          CalcFractal(void);
             void          LoadHistory(void);
             
             bool          NewDirection(int &Direction, int NewDirection);
             bool          NewState(ReservedWords &State, ReservedWords NewState);
  };

//+------------------------------------------------------------------+
//| RecordType - Returns the translated Reserved Word Type code      |
//+------------------------------------------------------------------+
int CSession::RecordType(int Type)
  { 
    switch (Type)
    {
      case Origin:      return(0);
      case Trend:       return(1);
      case Term:        return(2);
      case Prior:       return(3);
      case OffSession:  return(4);
      case Active:      return(5);
    };

    return (NoValue);
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
        case Correction:  sEvent.SetEvent(MarketCorrection);
                          break;
      }
      
      return(true);
    }
      
    return(false);
  }

//+------------------------------------------------------------------+
//| CalcFractal - Updates fibonacci points and states                |
//+------------------------------------------------------------------+
void CSession::CalcFractal(void)
  {
     sEvent.SetEvent(NewTerm);
     
     if (srec[Term].Direction==DirectionUp)
       srec[Term].Support             = srec[Term].Low;
       
     if (srec[Term].Direction==DirectionDown)
       srec[Term].Resistance          = srec[Term].High;
  };

//+------------------------------------------------------------------+
//| UpdateFractal - Sets active state, bounds and alerts on the tick |
//+------------------------------------------------------------------+
void CSession::UpdateFractal(void)
  {
    if (sEvent[NewBoundary])
    {
      if (sEvent[NewReversal])
        CalcFractal();    
      
      for (int fibo=0;fibo<Prior;fibo++)
      {
        srec[fibo].High      = fmax(High[sBar],srec[fibo].High);
        srec[fibo].Low       = fmin(Low[sBar],srec[fibo].Low);
      }
      
    }
  }

//+------------------------------------------------------------------+
//| UpdateActive - Sets active state, bounds and alerts on the tick  |
//+------------------------------------------------------------------+
void CSession::UpdateActive(void)
  {
    ReservedWords usState              = NoState;
    ReservedWords usHighState          = NoState;

    SessionRec    usLastSession        = srec[RecordType(Active)];

    if (IsHigher(High[sBar],srec[RecordType(Active)].High))
    {
      sEvent.SetEvent(NewHigh);
      sEvent.SetEvent(NewBoundary);

      if (NewDirection(srec[RecordType(Active)].Direction,DirectionUp))
        usState                        = Rally;

      if (IsHigher(srec[RecordType(Active)].High,srec[RecordType(Prior)].High,NoUpdate))
        if (!sSessionIsOpen)
          usState                      = Trap;
              
      if (IsHigher(srec[RecordType(Active)].High,srec[RecordType(Active)].Resistance,NoUpdate))
        if (NewDirection(srec[RecordType(Active)].BreakoutDir,DirectionUp))
          usState                      = Reversal;
        else
          usState                      = Breakout;
          
      usHighState                      = usState;   //-- Retain high on outside reversal
    }
            
    if (IsLower(Low[sBar],srec[RecordType(Active)].Low))
    {
      sEvent.SetEvent(NewLow);
      sEvent.SetEvent(NewBoundary);

      if (NewDirection(srec[RecordType(Active)].Direction,DirectionDown))
        usState                        = Pullback;

      if (IsLower(srec[RecordType(Active)].Low,srec[RecordType(Prior)].Low,NoUpdate))
        if (!sSessionIsOpen)
          usState                      = Trap;
      
      if (IsLower(srec[RecordType(Active)].Low,srec[RecordType(Active)].Support,NoUpdate))
        if (NewDirection(srec[RecordType(Active)].BreakoutDir,DirectionDown))
          usState                      = Reversal;
        else
          usState                      = Breakout;
    }
        
    //-- Apply outside reversal correction possible only during historical analysis
    if (sEvent[NewHigh] && sEvent[NewLow])
    {
      if (IsChanged(srec[RecordType(Active)].Direction,Direction(Close[sBar]-Open[sBar])))
        if (srec[RecordType(Active)].Direction==DirectionUp)
        {
          usState                      = usHighState;  //-- Outside reversal; use retained high
          sEvent.ClearEvent(NewLow);
        }
        else
          sEvent.ClearEvent(NewHigh);
    }
    
    if (NewState(srec[RecordType(Active)].State,usState))
      if (usState==Reversal || usState==Breakout)
        if (sShowDirArrow)
        {
          if (sEvent[NewHigh])
            NewArrow(SYMBOL_ARROWUP,clrYellow,EnumToString(sType)+"-"+EnumToString(usState),usLastSession.Resistance,sBar);

          if (sEvent[NewLow])
            NewArrow(SYMBOL_ARROWDOWN,clrRed,EnumToString(sType)+"-"+EnumToString(usState),usLastSession.Support,sBar);
        }
  }
  
//+------------------------------------------------------------------+
//| UpdateSession - Calls update procedures for each fractal group   |
//+------------------------------------------------------------------+
void CSession::UpdateSession(void)
  {
    UpdateActive();
    UpdateFractal();
    //UpdateFractal(Trend,NewTrend);
    //UpdateFractal(Origin,NewOrigin);
  }
  
//+------------------------------------------------------------------+
//| OpenSession - Initializes active session start values on open    |
//+------------------------------------------------------------------+
void CSession::OpenSession(void)
  {
    //-- Update OffSession Record and Indicator Buffer
    srec[RecordType(OffSession)]          = srec[RecordType(Active)];
    sOffMidBuffer.SetValue(sBar,Pivot(Active));

    //-- Set support/resistance (ActiveSession is OffSession data)
    srec[RecordType(Active)].Resistance   = fmax(srec[RecordType(Active)].High,srec[RecordType(Prior)].High);
    srec[RecordType(Active)].Support      = fmin(srec[RecordType(Active)].Low,srec[RecordType(Prior)].Low);
    srec[RecordType(Active)].High         = Close[fmin(Bars-1,sBar+1)];
    srec[RecordType(Active)].Low          = Close[fmin(Bars-1,sBar+1)];
    
    //-- Set OpenSession flag
    sEvent.SetEvent(SessionOpen);
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes active session start values on close       |
//+------------------------------------------------------------------+
void CSession::CloseSession(void)
  {        
    //-- Update Prior Record and Indicator Buffer
    srec[RecordType(Prior)]                 = srec[RecordType(Active)];
    sPriorMidBuffer.SetValue(sBar,Pivot(Prior));

    //-- Reset Active Record
    srec[RecordType(Active)].Resistance   = fmax(srec[RecordType(Active)].High,srec[RecordType(OffSession)].High);
    srec[RecordType(Active)].Support      = fmin(srec[RecordType(Active)].Low,srec[RecordType(OffSession)].Low);
    srec[RecordType(Active)].High         = Close[fmin(Bars-1,sBar+1)];
    srec[RecordType(Active)].Low          = Close[fmin(Bars-1,sBar+1)];
    
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
CSession::CSession(SessionType Type, int HourOpen, int HourClose)
  {
    //--- Init global session values
    sType                            = Type;
    sHourOpen                        = HourOpen;
    sHourClose                       = HourClose;
    sSessionIsOpen                   = false;
    sShowDirArrow                    = false;
    
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
    if (TimeHour(Time[sBar])>=sHourOpen && TimeHour(Time[sBar])<sHourClose)
      return (true);
        
    return (false);
  }

//+------------------------------------------------------------------+
//| Pivot - returns the mid price for the supplied type              |
//+------------------------------------------------------------------+
double CSession::Pivot(const int Type)
  {
    return(fdiv(srec[RecordType(Type)].High+srec[RecordType(Type)].Low,2,Digits));
  }

//+------------------------------------------------------------------+
//| Bias - returns the order action relative to the root             |
//+------------------------------------------------------------------+
int CSession::Bias(void)
  {
    if (IsOpen())
    {
      if (Pivot(Active)>Pivot(OffSession))
        return (OP_BUY);

      if (Pivot(Active)<Pivot(OffSession))
        return (OP_SELL);
    }      
    else
    {
      if (Pivot(Active)>Pivot(Prior))
        return (OP_BUY);

      if (Pivot(Active)<Pivot(Prior))
        return (OP_SELL);
    }
      
    return (Action(srec[RecordType(Active)].Direction,InDirection));
  }

//+------------------------------------------------------------------+
//| SessionText - Returns formatted Session data for supplied type   |
//+------------------------------------------------------------------+
string CSession::SessionText(int Type)
  {  
    string siSessionInfo        = EnumToString(this.Type())+"|"
                                + TimeToStr(Time[sBar])+"|"
                                + BoolToStr(this.IsOpen(),"Open|","Closed|")
                                + DoubleToStr(Pivot(Active),Digits)+"|"
                                + BoolToStr(srec[RecordType(Type)].Direction==DirectionUp,"Long|","Short|")                              
                                + EnumToString(srec[RecordType(Type)].State)+"|"
                                + DoubleToStr(srec[RecordType(Type)].High,Digits)+"|"
                                + DoubleToStr(srec[RecordType(Type)].Low,Digits)+"|"
                                + DoubleToStr(srec[RecordType(Type)].Resistance,Digits)+"|"
                                + DoubleToStr(srec[RecordType(Type)].Support,Digits)+"|"
                                + BoolToStr(srec[RecordType(Type)].BreakoutDir==DirectionUp,"Long|","Short|");

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
                            return (TimeHour(Time[sBar])-sHourOpen+1);
    }
    
    return (NoValue);
  }
