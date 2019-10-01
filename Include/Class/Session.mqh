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
               int            BreakoutDir; //--- Direction of the last breakout or reversal
               ReservedWords  State;
               double         High;        //--- High/Low store daily/session high & low
               double         Low;
               double         Support;     //--- Support/Resistance determines reversal, breakout & continuation
               double         Resistance;
             };

             CSession(SessionType Type, int HourOpen, int HourClose, int HourOffset);
            ~CSession();

             SessionType   Type(void)                       {return (sType);}
             int           SessionHour(int Measure=Now);
             bool          IsOpen(void);
             
             bool          Event(EventType Type)            {return (sEvent[Type]);}
             bool          ActiveEvent(void)                {return (sEvent.ActiveEvent());}
             string        ActiveEventText(void)            {return (sEvent.ActiveEventText());};
             
             datetime      ServerTime(int Bar=0);
             
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
             
             //--- Private class collections
             SessionRec    srec[PeriodTypes];
             
             CArrayDouble *sOffMidBuffer;
             CArrayDouble *sPriorMidBuffer;
             CArrayDouble *sFractalBuffer;
             
             CEvent       *sEvent;
             
             //--- Private Methods
             void          OpenSession(void);
             void          CloseSession(void);
             void          UpdateSession(void);
                          
             void          UpdateBuffers(void);

             void          LoadHistory(void);
             
             bool          NewDirection(int &Direction, int NewDirection, bool Update=true);
             bool          NewState(ReservedWords &State, ReservedWords NewState);
             void          AddFractal(void);
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
bool CSession::NewDirection(int &Direction, int ChangeDirection, bool Update=true)
  {
    if (ChangeDirection==DirectionNone)
      return(false);
     
    if (Direction==DirectionNone)
      Direction                   = ChangeDirection;
    else
    if (IsChanged(Direction,ChangeDirection,Update))
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
    {
      if (ChangeState==Breakout)
        return(false);
        
      if (ChangeState==Reversal)
        if (sEvent[NewDirection])
          State                    = Correction;
    }
      
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
//| AddFractal - Creates new fractal and validates existing states   |
//+------------------------------------------------------------------+
void CSession::AddFractal(void)
  {
  }

//+------------------------------------------------------------------+
//| UpdateSession - Sets active state, bounds and alerts on the tick |
//+------------------------------------------------------------------+
void CSession::UpdateSession(void)
  {    
    ReservedWords usState              = NoState;
    ReservedWords usHighState          = NoState;
    ReservedWords usLowState           = NoState;

    SessionRec    usLastSession        = srec[ActiveSession];

    int           usArrow;
    double        usArrowHigh          = fmax(srec[PriorSession].High,fmax(Open[sBar],usLastSession.High));
    double        usArrowLow           = fmin(srec[PriorSession].Low,fmin(Open[sBar],usLastSession.Low));

    if (IsHigher(High[sBar],srec[ActiveSession].High))
    {
      sEvent.SetEvent(NewHigh);
      sEvent.SetEvent(NewBoundary);

      if (NewDirection(srec[ActiveSession].Direction,DirectionUp))
      {
        usState                        = Rally;
        srec[ActiveSession].Resistance = usLastSession.High;
      }

      if (IsHigher(srec[ActiveSession].High,srec[PriorSession].High,NoUpdate))
        if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionUp))
          usState                      = Reversal;
        else
          usState                      = Breakout;
          
       usHighState                     = usState;  //--- Retain for multiple boundary correction
    }
            
    if (IsLower(Low[sBar],srec[ActiveSession].Low))
    {
      sEvent.SetEvent(NewLow);
      sEvent.SetEvent(NewBoundary);

      if (NewDirection(srec[ActiveSession].Direction,DirectionDown))
      {
        usState                        = Pullback;
        srec[ActiveSession].Support    = usLastSession.Low;
      }

      if (IsLower(srec[ActiveSession].Low,srec[PriorSession].Low,NoUpdate))
        if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionDown))
          usState                      = Reversal;
        else
          usState                      = Breakout;

       usLowState                      = usState;  //--- Retain for multiple boundary correction
    }

    //-- Apply corrections on multiple new boundary events: possible only during historical analysis
    if (sEvent[NewHigh] && sEvent[NewLow])
    {
      if (usHighState==Reversal || usLowState==Reversal)
      {
        //--- axiom: at no time shall a breakout occur without first having a same direction reversal following a prior opposite reversal/breakout;
        //--- axiom: given a high reversal, a low breakout is not possible;
        //--- axiom: The simultaneous occurrence of both high and low reversals is possible; each of which must be processed in sequence;
      
        if (usHighState==Reversal && usLowState==Reversal) //--- double outside reversal?
        {
          Print(TimeToStr(Time[sBar])+":Double Outside reversal; check results");
        
          //--- Process the 'original' reversal        
        
        }
        else
        if (usHighState==Reversal)
        {
          if (usState==Breakout)
            Print("Axiom violation: High Reversal/Low Breakout not possible");

          sEvent.ClearEvent(NewLow);
          usState                       = usHighState;
        }
        else
        {
          sEvent.ClearEvent(NewHigh);
          usState                       = usLowState;
        }
        
        srec[ActiveSession].Direction = srec[ActiveSession].BreakoutDir;
      }
      else
      {
        //--- Resolve pullback vs rally
        if (IsChanged(srec[ActiveSession].Direction,Direction(Close[sBar]-Open[sBar])))   //--- does not work all the time; fuzzy guess; self-correcting
        {
          sEvent.ClearEvent(NewLow);
          usState                       = usHighState;  //-- Outside bar reversal; use retained high
        }
        else
        {
          sEvent.ClearEvent(NewHigh);
          usState                       = usLowState;  //-- Outside bar reversal; use retained high
        }
      }
    }
    
    if (NewState(srec[ActiveSession].State,usState))
    {
      switch (usState)
      {
        case Breakout:   usArrow        = BoolToInt(sEvent[NewHigh],SYMBOL_ARROWUP,SYMBOL_ARROWDOWN);
                         break;
        case Reversal:   usArrow        = SYMBOL_CHECKSIGN;
                         AddFractal();
                         break;
        default:         usArrow        = SYMBOL_DASH;
                         usArrowHigh    = usLastSession.High;
                         usArrowLow     = usLastSession.Low;
      }
       
      if (sEvent[NewHigh])
        NewArrow(usArrow,clrYellow,EnumToString(sType)+"-"+EnumToString(usState),usArrowHigh,sBar);

      if (sEvent[NewLow])
        NewArrow(usArrow,clrRed,EnumToString(sType)+"-"+EnumToString(usState),usArrowLow,sBar);
    }
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
    srec[ActiveSession].Resistance        = Open[sBar];
    srec[ActiveSession].Support           = Open[sBar];
    srec[ActiveSession].High              = Open[sBar];
    srec[ActiveSession].Low               = Open[sBar];
    
    //<--- Check for offsession reversals
    if (IsHigher(srec[ActiveSession].High,srec[PriorSession].High,NoUpdate))    
      if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionUp,NoUpdate))
        srec[ActiveSession].High          = fdiv(srec[PriorSession].High+High[sBar],2,Digits);

    if (IsLower(srec[ActiveSession].Low,srec[PriorSession].Low,NoUpdate))
      if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionDown,NoUpdate))
       srec[ActiveSession].Low            = fdiv(srec[PriorSession].Low+Low[sBar],2,Digits);
    
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
    srec[ActiveSession].Resistance        = Open[sBar];
    srec[ActiveSession].Support           = Open[sBar];

    srec[ActiveSession].High              = Open[sBar];
    srec[ActiveSession].Low               = Open[sBar];
    
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
      srec[type].BreakoutDir         = DirectionNone;
      srec[type].State               = Breakout;
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
    
    sFractalBuffer                   = new CArrayDouble(Bars);
    sFractalBuffer.Truncate          = false;
    sFractalBuffer.AutoExpand        = true;
    sFractalBuffer.SetPrecision(Digits);
    sFractalBuffer.Initialize(0.00);
    
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
    delete sFractalBuffer;
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
    
//    if (Symbol()=="USDJPY") Print(SessionText(ActiveSession));
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
                                + DoubleToStr(Pivot(Type),Digits)+"|"
                                + BoolToStr(srec[Type].Direction==DirectionUp,"Long|","Short|")                              
                                + BoolToStr(srec[Type].BreakoutDir==DirectionUp,"Long|","Short|")                              
                                + EnumToString(srec[Type].State)+"|"
                                + DoubleToStr(srec[Type].High,Digits)+"|"
                                + DoubleToStr(srec[Type].Low,Digits)+"|"
                                + DoubleToStr(srec[Type].Resistance,Digits)+"|"
                                + DoubleToStr(srec[Type].Support,Digits)+"|";

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
