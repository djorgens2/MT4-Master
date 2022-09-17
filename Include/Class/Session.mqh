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
#include <fractal_lib.mqh>

//+------------------------------------------------------------------+
//| Session Class - Collects session data, states, and events        |
//+------------------------------------------------------------------+
class CSession : public CEvent 
  {

public:
             //-- Period Types
             enum PeriodType
             {
               PriorSession,  // Prior (Closed) Session
               ActiveSession, // Active (Open) Session
               OffSession,    // Off-Session
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

             //-- Session Record Definition
             struct SessionRec
             {
               int            Direction;
               int            BreakoutDir;     //--- Direction of the last breakout or reversal
               int            Bias;            //--- Current session Bias in action
               FractalState   State;
               double         High;            //--- High/Low store daily/session high & low
               double         Low;
               double         Support;         //--- Support/Resistance determines reversal, breakout & continuation
               double         Resistance;
             };
             
             CSession(SessionType Type, int HourOpen, int HourClose, int HourOffset);
            ~CSession();

             SessionType      Type(void)                         {return (sType);}

             void             Update(void);
             void             Update(double &OffSessionBuffer[], double &PriorMidBuffer[], double &FractalBuffer[]);

             datetime         ServerTime(int Bar=0);
             int              SessionHour(EventType Event=NoEvent);
             bool             IsOpen(void);
             
             double           Price(FractalType Type, FractalPoint FP);
             double           Pivot(const PeriodType Type);                          //--- Mid/Mean by Period Type
             int              Age(void)                          {return(sBarFE);}   //--- Number of periods since the last fractal event
             
             double           Retrace(FractalType Type, MeasureType Measure, int Format=InDecimal);    //--- returns fibonacci retrace
             double           Expansion(FractalType Type, MeasureType Measure, int Format=InDecimal);  //--- returns fibonacci expansion
             double           Forecast(FractalType Type, int Method, FiboLevel Fibo=FiboRoot);         //--- returns extended fibo price

             string           FractalStr(void);
             string           SessionStr(PeriodType Type);

             SessionRec       operator[](const FractalState)     {return(sCorrection);}
             SessionRec       operator[](const FractalType Type) {return(sfractal[Type]);}
             SessionRec       operator[](const PeriodType Type)  {return(srec[Type]);}
                                 
private:

             //--- Private Class properties
             SessionType      sType;
             
             bool             sSessionIsOpen;

             int              sHourOpen;
             int              sHourClose;
             int              sHourOffset;
             int              sBar;
             int              sBars;
             int              sBarDay;
             int              sBarHour;
             
             SessionRec       sfractal[FractalTypes];
             SessionRec       sCorrection;
             
             int              sBarFE;          //--- Fractal Expansion Bar
             int              sDirFE;          //--- Fractal Direction (Painted)

             //--- Private class collections
             SessionRec       srec[PeriodTypes];
             FiboLevel        fEventFibo[FractalTypes];
             
             CArrayDouble    *sOffMidBuffer;
             CArrayDouble    *sPriorMidBuffer;
             CArrayDouble    *sFractalBuffer;
             CArrayDouble    *sSessionRange;
             
             //--- Private Methods
             FractalState     CalcState(FractalState State, int Direction, double Fibonacci, bool Reversal, bool Breakout);
             int              CalcBias(double Price);    //--- Active Bias 

             void             OpenSession(void);
             void             CloseSession(void);

             void             UpdateSession(void);
             void             UpdateTerm(void);
             void             UpdateTrend(void);
             void             UpdateOrigin(void);
             void             UpdateFibonacci(void);

             void             UpdateBuffers(void);
             void             UpdateFractalBuffer(int Direction, double Value);

             void             LoadHistory(void);         //--- History Load/Init
  };

//+------------------------------------------------------------------+
//| CalcState - Computes FractalState based on supplied params       |
//+------------------------------------------------------------------+
FractalState CSession::CalcState(FractalState State, int Direction, double Fibonacci, bool ReversalEvent, bool BreakoutEvent)
  {
    if (ReversalEvent)
      return (Reversal);
    else
    if (BreakoutEvent)
      return (Breakout);
    else
    if (IsEqual(State,Correction))
    {
      if (Fibonacci<=FiboRecovery)
        return (Recovery);
    }
    else
    if (Fibonacci>=FiboCorrection)
      return (Correction);
    else
    if (Fibonacci>=FiboRetrace)
      return (Retrace);
    else
    if (Fibonacci>=FiboRecovery)
      return (FractalState)(BoolToInt(IsEqual(Direction,DirectionUp),Pullback,Rally));
      
    return (State);
  }

//+------------------------------------------------------------------+
//| CalcBias - Returns Active Bias(Action) relative to supplied price|
//+------------------------------------------------------------------+
int CSession::CalcBias(double Price)
  {
    if (Pivot(ActiveSession)>Price)
      return (OP_BUY);

    if (Pivot(ActiveSession)<Price)
      return (OP_SELL);
  
    return (Action(srec[ActiveSession].Direction,InDirection));
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
    srec[ActiveSession].Resistance        = fmax(srec[PriorSession].High,srec[OffSession].High);
    srec[ActiveSession].Support           = fmin(srec[PriorSession].Low,srec[OffSession].Low);
    srec[ActiveSession].High              = Open[sBar];
    srec[ActiveSession].Low               = Open[sBar];

    //<--- Check for offsession reversals
    if (IsHigher(srec[ActiveSession].High,srec[PriorSession].High,NoUpdate))
      if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionUp,NoUpdate))
        srec[ActiveSession].High          = fdiv(srec[PriorSession].High+High[sBar],2,Digits);

    if (IsLower(srec[ActiveSession].Low,srec[PriorSession].Low,NoUpdate))
      if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionDown,NoUpdate))
       srec[ActiveSession].Low            = fdiv(srec[PriorSession].Low+Low[sBar],2,Digits);

    SetEvent(SessionOpen,Notify);
  }

//+------------------------------------------------------------------+
//| CloseSession - Closes active session start values on close       |
//+------------------------------------------------------------------+
void CSession::CloseSession(void)
  {        
    //-- Update Prior Record, range history, and Indicator Buffer
    sSessionRange.Insert(0,srec[ActiveSession].High-srec[ActiveSession].Low);

    srec[PriorSession]                    = srec[ActiveSession];
    sPriorMidBuffer.SetValue(sBar,Pivot(PriorSession));

    //-- Reset Active Record
    srec[ActiveSession].Resistance        = srec[PriorSession].High;
    srec[ActiveSession].Support           = srec[PriorSession].Low;
    srec[ActiveSession].High              = Open[sBar];
    srec[ActiveSession].Low               = Open[sBar];

    SetEvent(SessionClose,Notify);
  }

//+------------------------------------------------------------------+
//| UpdateSession - Sets active state, bounds and alerts on the tick |
//+------------------------------------------------------------------+
void CSession::UpdateSession(void)
  {
    FractalState  state              = NoState;
    FractalState  statehigh          = NoState;
    FractalState  statelow           = NoState;

    if (IsHigher(High[sBar],srec[ActiveSession].High))
    {
      SetEvent(NewHigh,Nominal);
      SetEvent(NewBoundary,Nominal);

      if (NewDirection(srec[ActiveSession].Direction,DirectionUp))
        SetEvent(NewDirection,Nominal);

      state                          = Rally;

      if (IsHigher(srec[ActiveSession].High,srec[PriorSession].High,NoUpdate))
        if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionUp))
          state                      = Reversal;
        else
          state                      = Breakout;
                 
      statehigh                      = state;  //--- Retain for multiple boundary correction
    }
            
    if (IsLower(Low[sBar],srec[ActiveSession].Low))
    {
      SetEvent(NewLow,Nominal);
      SetEvent(NewBoundary,Nominal);

      if (NewDirection(srec[ActiveSession].Direction,DirectionDown))
        SetEvent(NewDirection,Nominal);

      state                          = Pullback;

      if (IsLower(srec[ActiveSession].Low,srec[PriorSession].Low,NoUpdate))
        if (NewDirection(srec[ActiveSession].BreakoutDir,DirectionDown))
          state                      = Reversal;
        else
          state                      = Breakout;

      statelow                      = state;  //--- Retain for multiple boundary correction
    }

    //-- Apply historical corrections on multiple new boundary events
    if (Event(NewHigh)&&Event(NewLow))
    {
      if (IsEqual(statehigh,Reversal)||IsEqual(statelow,Reversal))
      {
        //--- axiom: at no time shall a breakout occur without first having a same direction reversal following a prior opposite reversal/breakout;
        //--- axiom: given a high reversal, a low breakout is not possible;
        //--- axiom: The simultaneous occurrence of both high and low reversals is possible; each of which must be processed in sequence;
      
        if (IsEqual(statehigh,Reversal)&&IsEqual(statelow,Reversal)) //--- double outside reversal?
        {
          Print(TimeToStr(Time[sBar])+":Double Outside reversal; check results");
        
          //--- Process the 'original' reversal        
        
        }
        else
        if (IsEqual(statehigh,Reversal))
        {
          if (IsEqual(state,Breakout))
            Print("Axiom violation: High Reversal/Low Breakout not possible");

          ClearEvent(NewLow);
          state                         = statehigh;
        }
        else
        {
          ClearEvent(NewHigh);
          state                         = statelow;
        }
        
        srec[ActiveSession].Direction = srec[ActiveSession].BreakoutDir;
      }
      else
      {
        //--- Resolve pullback vs rally
        if (IsChanged(srec[ActiveSession].Direction,Direction(Close[sBar]-Open[sBar])))   //--- does not work all the time; fuzzy guess; self-correcting
        {
          ClearEvent(NewLow);
          state                         = statehigh;  //-- Outside bar reversal; use retained high
        }
        else
        {
          ClearEvent(NewHigh);
          state                         = statelow;  //-- Outside bar reversal; use retained high
        }
      }
    }

    if (IsEqual(state,Reversal))                     //-- catch double/triple+ outside reversals
        SetEvent(NewReversal,Nominal);

    if (NewAction(srec[ActiveSession].Bias,CalcBias(BoolToDouble(IsOpen(),Pivot(OffSession),Pivot(PriorSession)))))
      SetEvent(NewBias,Nominal);

    if (NewState(srec[ActiveSession].State,state))
      SetEvent(FractalEvent(state),Nominal);
  }

//+------------------------------------------------------------------+
//| UpdateTerm - Updates term fractal bounds and buffers             |
//+------------------------------------------------------------------+
void CSession::UpdateTerm(void)
  {
    FractalState  state            = NoState;

    //--- Check for term changes
    if (NewDirection(sfractal[Term].Direction,srec[ActiveSession].BreakoutDir))
    {
      sfractal[Term].BreakoutDir   = sfractal[Term].Direction;

      SetEvent(NewDirection,Minor);
      SetEvent(NewTerm,Minor);
    }

    //--- Check for term boundary changes
    if (sfractal[Term].Direction==DirectionUp)
    {
      if (Event(NewTerm))
      {
        sfractal[Term].Resistance  = srec[PriorSession].High;
        sfractal[Term].Support     = sfractal[Term].Low;
        sfractal[Term].Low         = Close[sBar];
      }

      if (IsHigher(High[sBar],sfractal[Term].High))
      {
        sfractal[Term].Low         = Close[sBar];        

        UpdateFractalBuffer(DirectionUp,High[sBar]);
        SetEvent(NewExpansion,Minor);
      }
      else sfractal[Term].Low      = fmin(BoolToDouble(sBar==0,Close[sBar],Low[sBar]),sfractal[Term].Low);
    }
    else
    {
      if (Event(NewTerm))
      {
        sfractal[Term].Support     = srec[PriorSession].Low;
        sfractal[Term].Resistance  = sfractal[Term].High;
        sfractal[Term].High        = Close[sBar];
      }

      if (IsLower(Low[sBar],sfractal[Term].Low))
      {
        sfractal[Term].High        = Close[sBar];

        UpdateFractalBuffer(DirectionDown,Low[sBar]);
        SetEvent(NewExpansion,Minor);
      }
      else sfractal[Term].High     = fmax(BoolToDouble(sBar==0,Close[sBar],High[sBar]),sfractal[Term].High);
    }

    //--- Check for term state changes
    if (Event(NewTerm))
      state                        = Reversal;
    else
    if (Event(NewExpansion,Minor))
      state                        = Breakout;
    else
    {
      if (sfractal[Term].Direction==DirectionUp)
        if (Price(Term,fpRetrace)<Pivot(PriorSession))
          state                    = Pullback;

      if (sfractal[Term].Direction==DirectionDown)
        if (Price(Term,fpRetrace)>Pivot(PriorSession))
          state                    = Rally;
    }

    if (NewState(sfractal[Term].State,state))
    {
      SetEvent(BoolToEvent(NewAction(sfractal[Term].Bias,(FractalState)BoolToInt(Event(NewTerm)||Event(NewExpansion,Minor),
                                    Action(sfractal[Term].Direction),Action(sfractal[Term].Direction,InDirection,InContrarian))),NewBias),Minor);
      SetEvent(NewState,Minor);
    }
  }

//+------------------------------------------------------------------+
//| UpdateTrend - Updates trend fractal bounds and state             |
//+------------------------------------------------------------------+
void CSession::UpdateTrend(void)
  {
    //--- Check for trend changes      
    if (Event(NewTerm))        //--- After a term reversal
      if (sfractal[Term].Direction==DirectionUp)
      {
        sCorrection.Low              = BoolToDouble(sfractal[Trend].Direction==DirectionUp,sfractal[Trend].Support,sfractal[Trend].Low,Digits);
        sfractal[Trend].Support      = sfractal[Term].Support;
      }
      else
      {
        sCorrection.High             = BoolToDouble(sfractal[Trend].Direction==DirectionDown,sfractal[Trend].Resistance,sfractal[Trend].High,Digits);
        sfractal[Trend].Resistance   = sfractal[Term].Resistance;
      }

    //--- Check for upper trend boundary changes
    if (sfractal[Trend].Direction==DirectionUp)
    {
      //--- Check for new Expansion (Breakout)
      if (IsHigher(High[sBar],sfractal[Trend].High))
        SetEvent(NewExpansion,Major);

      //--- Check for inside reversal
      if (IsLower(Low[sBar],sfractal[Trend].Support,NoUpdate))
        if (NewDirection(sfractal[Trend].Direction,DirectionDown))
        {
          sfractal[Trend].Low          = Low[sBar];
          SetEvent(NewTrend,Major);
        }

      //--- Check for linear reversal
      if (IsLower(Low[sBar],sCorrection.Low,NoUpdate))
        if (NewDirection(sfractal[Trend].BreakoutDir,DirectionDown))
          SetEvent(NewTrend,Critical);
    }


    //--- Check for lower trend boundary changes
    if (sfractal[Trend].Direction==DirectionDown)
    {
      //--- Check for new Expansion (Breakout)
      if (IsLower(Low[sBar],sfractal[Trend].Low))
        SetEvent(NewExpansion,Major);

      //--- Check for inside reversal
      if (IsHigher(High[sBar],sfractal[Trend].Resistance,NoUpdate))
        if (NewDirection(sfractal[Trend].Direction,DirectionUp))
        {
          sfractal[Trend].High         = High[sBar];
          SetEvent(NewTrend,Major);
        }

      //--- Check for linear reversal
      if (IsHigher(High[sBar],sCorrection.High,NoUpdate))
        if (NewDirection(sfractal[Trend].BreakoutDir,DirectionUp))
          SetEvent(NewTrend,Critical);
    }

    SetEvent(BoolToEvent(Event(NewTrend),NewDirection),Major);
    SetEvent(BoolToEvent(NewAction(sfractal[Trend].Bias,Action(sfractal[Term].Direction)),NewBias),Major);

    if (NewState(sfractal[Trend].State,CalcState(sfractal[Trend].State,sfractal[Trend].Direction,Retrace(Trend,Now),Event(NewTrend),Event(NewExpansion,Major))))
    {
      SetEvent(NewState,Major);
      SetEvent(FractalEvent(sfractal[Trend].State),Major);
    }
  }
  
//+------------------------------------------------------------------+
//| UpdateOrigin - Updates origin fractal bounds and state           |
//+------------------------------------------------------------------+
void CSession::UpdateOrigin(void)
  {
    if (Event(NewTrend))
      if (sfractal[Trend].Direction==DirectionUp)
      {
        sfractal[Origin].Support      = fmin(sfractal[Trend].Support,sfractal[Trend].Low);
        sfractal[Origin].Low          = sfractal[Trend].Support;
      }
      else
      {
        sfractal[Origin].Resistance   = fmax(sfractal[Trend].Resistance,sfractal[Trend].High);
        sfractal[Origin].High         = sfractal[Trend].Resistance;
      }

    if (IsHigher(sfractal[Trend].High,sfractal[Origin].High))
    {
      if (sfractal[Origin].Direction==sfractal[Term].Direction)
        SetEvent(NewExpansion,Critical);

      if (NewDirection(sfractal[Origin].Direction,DirectionUp))
        SetEvent(NewOrigin,Major);

      if (IsHigher(sfractal[Trend].High,sfractal[Origin].Resistance,NoUpdate))
        if (NewDirection(sfractal[Origin].BreakoutDir,DirectionUp))
          SetEvent(NewOrigin,Critical);
    }

    if (IsLower(sfractal[Trend].Low,sfractal[Origin].Low))
    {
      if (sfractal[Origin].Direction==sfractal[Term].Direction)
        SetEvent(NewExpansion,Critical);

      if (NewDirection(sfractal[Origin].Direction,DirectionDown))
        SetEvent(NewOrigin,Major);

      if (IsLower(sfractal[Trend].Low,sfractal[Origin].Support,NoUpdate))
        if (NewDirection(sfractal[Origin].BreakoutDir,DirectionDown))
          SetEvent(NewOrigin,Critical);
    }
    
    if (sfractal[Origin].Direction==DirectionUp)
      if (NewAction(sfractal[Origin].Bias,CalcBias(Price(Fibo23,fmax(sfractal[Origin].High,sfractal[Origin].Resistance),sfractal[Origin].Support,Retrace))))
        SetEvent(NewBias,Critical);

    if (sfractal[Origin].Direction==DirectionDown)
      if (NewAction(sfractal[Origin].Bias,CalcBias(Price(Fibo23,sfractal[Origin].Support,fmax(sfractal[Origin].High,sfractal[Origin].Resistance),Retrace))))
        SetEvent(NewBias,Critical);       
    
    if (NewState(sfractal[Origin].State,CalcState(sfractal[Origin].State,sfractal[Origin].Direction,Retrace(Origin,Now),Event(NewOrigin),Event(NewExpansion,Critical))))
    {
      SetEvent(FractalEvent(sfractal[Origin].State),Critical);
      SetEvent(NewState,Critical);
    }
  }

//+------------------------------------------------------------------+
//| UpdateFibonacci - Sets/Fires Fibo Expansion alerts               |
//+------------------------------------------------------------------+
void CSession::UpdateFibonacci(void)
  {
    //-- Test/Reset for Expansion Fibos/Events
    for (FractalType type=Origin;type<=Term;type++)
    {
      if (Event(NewTerm))
        fEventFibo[type]                  = fmax(Level(Expansion(type,Max))+1,Fibo161);

      if (Percent(fmin(fEventFibo[type],Fibo823))<Expansion(type,Now))
        if (IsChanged(fEventFibo[type],fmin(fEventFibo[type]+1,Fibo823)))
          SetEvent(NewFibonacci,FractalAlert(type));
    }
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
        sFractalBuffer.Insert(0,0.00);
        sBarFE++;
      }
  }

//+------------------------------------------------------------------+
//| UpdateFractalBuffer - Updates the fractal buffer                 |
//+------------------------------------------------------------------+
void CSession::UpdateFractalBuffer(int Direction, double Value)
  {
    if (sDirFE==Direction)
    {
        sFractalBuffer.SetValue(sBarFE,0.00);
        sFractalBuffer.SetValue(sBar,Value);

        sBarFE                       = sBar;
      }
    else
    if (sBarFE!=sBar)
    {
      sFractalBuffer.SetValue(sBar,Value);

      sDirFE                       = Direction;
      sBarFE                       = sBar;
    }
  }

//+------------------------------------------------------------------+
//| LoadHistory - Loads history from the first session open          |
//+------------------------------------------------------------------+
void CSession::LoadHistory(void)
  {    
    int direction                    = DirectionNone;
          
    //--- Initialize period operationals
    sBar                             = Bars-1;
    sBars                            = Bars;
    sBarDay                          = NoValue;
    sBarHour                         = NoValue;
    
    sBarFE                           = sBar;
    sDirFE                           = DirectionNone;

    if (Close[sBar]<Open[sBar])
      direction                      = DirectionDown;
      
    if (Close[sBar]>Open[sBar])
      direction                      = DirectionUp;
    
    //--- Initialize session records
    for (int type=0;type<PeriodTypes;type++)
    {
      srec[type].Direction           = direction;
      srec[type].BreakoutDir         = DirectionNone;
      srec[type].State               = Breakout;
      srec[type].High                = High[sBar];
      srec[type].Low                 = Low[sBar];
      srec[type].Resistance          = High[sBar];
      srec[type].Support             = Low[sBar];
    }

    //--- Initialize Fibo records
    for (int type=Origin;type<FractalTypes;type++)
      sfractal[type]                 = srec[ActiveSession];
      
    sCorrection                      = srec[ActiveSession];

    ////--- *** May need to modify this if the sbar Open==Close
    //if (IsEqual(Open[sBar],Close[sBar]))
    //{
    //  Print ("Freak anomaly: aborting due to sbar(Open==Close)");
    //  ExpertRemove();
    //  return;
    //}

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
    
    sSessionRange                    = new CArrayDouble(0);
    sSessionRange.Truncate           = false;
    sSessionRange.AutoExpand         = true;    
    sSessionRange.SetPrecision(Digits);
    sSessionRange.Initialize(0.00);
    sSessionRange.SetAutoCompute(true);

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
    delete sOffMidBuffer;
    delete sPriorMidBuffer;
    delete sFractalBuffer;
    delete sSessionRange;
  }

//+------------------------------------------------------------------+
//| Update - Updates open session data and events                    |
//+------------------------------------------------------------------+
void CSession::Update(void)
  {
    UpdateBuffers();

    //--- Clear events
    ClearEvents();

    //--- Test for New Day; Force close
    if (IsChanged(sBarDay,TimeDay(ServerTime(sBar))))
    {
      SetEvent(NewDay,Notify);
      
      if (IsChanged(sSessionIsOpen,false))
        CloseSession();
    }
    
    if (IsChanged(sBarHour,TimeHour(ServerTime(sBar))))
      SetEvent(NewHour,Notify);

    //--- Calc events session open/close
    if (IsChanged(sSessionIsOpen,this.IsOpen()))
      if (sSessionIsOpen)
        OpenSession();
      else
        CloseSession();

    UpdateSession();
    UpdateTerm();
    UpdateTrend();
    UpdateOrigin();
    UpdateFibonacci();
  }
  
//+------------------------------------------------------------------+
//| Update - Updates and returns buffer values                       |
//+------------------------------------------------------------------+
void CSession::Update(double &OffMidBuffer[], double &PriorMidBuffer[], double &FractalBuffer[])
  {
    Update();
    
    sOffMidBuffer.Copy(OffMidBuffer);
    sPriorMidBuffer.Copy(PriorMidBuffer);
    sFractalBuffer.Copy(FractalBuffer);
  }
  
//+------------------------------------------------------------------+
//| ServerTime - Returns the adjusted time based on server offset    |
//+------------------------------------------------------------------+
datetime CSession::ServerTime(int Bar=0)
  {
    //-- Time is set to reflect 5:00pm New York as end of trading day
    
    return(Time[Bar]+(PERIOD_H1*60*sHourOffset));
  };

//+------------------------------------------------------------------+
//| SessionHour - Returns the hour of open session trading           |
//+------------------------------------------------------------------+
int CSession::SessionHour(EventType Event)
  {    
    switch (Event)
    {
      case SessionOpen:   return(sHourOpen);
      case SessionClose:  return(sHourClose);
      default:            if (sSessionIsOpen)
                            return (TimeHour(ServerTime(sBar))-sHourOpen+1);
    }
    
    return (NoValue);
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
//| Price - Returns the Price for the supplied Fractal Point         |
//+------------------------------------------------------------------+
double CSession::Price(FractalType Type, FractalPoint FP)
  {
    switch (FP)
    {
      case fpBase:      return(BoolToDouble(IsEqual(sfractal[Type].Direction,DirectionUp),sfractal[Type].Resistance,sfractal[Type].Support,Digits));
      case fpRoot:      return(BoolToDouble(IsEqual(sfractal[Type].Direction,DirectionUp),sfractal[Type].Support,sfractal[Type].Resistance,Digits));
      case fpExpansion: return(BoolToDouble(IsEqual(sfractal[Type].Direction,DirectionUp),sfractal[Type].High,sfractal[Type].Low,Digits));
      case fpRetrace:   return(BoolToDouble(IsEqual(sfractal[Type].Direction,DirectionUp),sfractal[Term].Low,sfractal[Term].High,Digits));
      case fpRecovery:  return(BoolToDouble(IsEqual(sfractal[Type].Direction,DirectionUp),srec[ActiveSession].High,srec[ActiveSession].Low,Digits));
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| Retrace - Calcuates fibo retrace % for supplied Type             |
//+------------------------------------------------------------------+
double CSession::Retrace(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
      switch (Measure)
      {
        case Now: return(Retrace(Price(Type,fpRoot),Price(Type,fpExpansion),Close[sBar],Format));
        case Min: return(BoolToInt(IsEqual(Format,InDecimal),1,100)-fabs(Retrace(Type,Max,Format)));
        case Max: return(Retrace(Price(Type,fpRoot),Price(Type,fpExpansion),Price(Type,fpRetrace),Format));
      }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Expansion - Calcuates fibo expansion % for supplied Type         |
//+------------------------------------------------------------------+
double CSession::Expansion(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
    switch (Measure)
    {
      case Now: return(Expansion(Price(Type,fpBase),Price(Type,fpRoot),Close[sBar],Format));
      case Min: return(BoolToInt(IsEqual(Format,InDecimal),1,100)-fabs(Retrace(Type,Max,Format)));
      case Max: return(Expansion(Price(Type,fpBase),Price(Type,fpRoot),BoolToDouble(IsEqual(Price(Type,fpBase),Price(Type,fpExpansion)),
                                 Price(Type,fpRecovery),Price(Type,fpExpansion),Digits),Format));
    }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Forecast - Returns Forecast Price for supplied Fibo              |
//+------------------------------------------------------------------+
double CSession::Forecast(FractalType Type, int Method, FiboLevel Fibo=FiboRoot)
  {
    switch (Method)
    {
      case Expansion:   return(NormalizeDouble(Price(Type,fpRoot)+((Price(Type,fpBase)-Price(Type,fpRoot))*Percent(Fibo)),Digits));
      case Retrace:     return(NormalizeDouble(Price(Type,fpExpansion)+((Price(Type,fpRoot)-Price(Type,fpExpansion))*Percent(Fibo)),Digits));
      case Recovery:    return(NormalizeDouble(Price(Type,fpRoot)-((Price(Type,fpRoot)-Price(Type,fpRecovery))*Percent(Fibo)),Digits));
      case Correction:  return(NormalizeDouble(((Price(Type,fpRoot)-Price(Type,fpExpansion))*FiboCorrection)+Price(Type,fpExpansion),Digits));
    }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| FractalStr - Returns Screen formatted Fibonacci Detail           |
//+------------------------------------------------------------------+
string CSession::FractalStr(void)
  {  
    string text            = "*---------- "+EnumToString(this.Type())+" ["+BoolToStr(IsOpen(),"Open","Closed")+"] Session Fractal ----------*\n"+
        "Term State: "+EnumToString(sfractal[Term].State)+" ["+ActionText(sfractal[Term].Bias)+"] Direction: "+DirText(sfractal[Term].Direction)+"/"+DirText(sfractal[Term].BreakoutDir)+"\n"+
                       " (r) "+DoubleToStr(Retrace(Term,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(Term,Max,InPercent),1)+"%"+"\n"+
                       " (e) "+DoubleToStr(Expansion(Term,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(Term,Max,InPercent),1)+"%  "+DoubleToStr(Expansion(Term,Min,InPercent),1)+"%\n"+
        "Trend State: "+EnumToString(sfractal[Trend].State)+" Direction: "+DirText(sfractal[Trend].Direction)+"/"+DirText(sfractal[Trend].BreakoutDir)+"\n"+
                       " (r) "+DoubleToStr(Retrace(Trend,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(Trend,Max,InPercent),1)+"%"+"\n"+
                       " (e) "+DoubleToStr(Expansion(Trend,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(Trend,Max,InPercent),1)+"%  "+DoubleToStr(Expansion(Trend,Min,InPercent),1)+"%\n"+
        "Origin State:  "+EnumToString(sfractal[Origin].State)+" Direction: "+DirText(sfractal[Origin].Direction)+"/"+DirText(sfractal[Origin].BreakoutDir)+"\n"+
                       " (r) "+DoubleToStr(Retrace(Origin,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(Origin,Max,InPercent),1)+"%"+"\n"+
                       " (e) "+DoubleToStr(Expansion(Origin,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(Origin,Max,InPercent),1)+"%  "+DoubleToStr(Expansion(Origin,Min,InPercent),1)+"%\n"+
        "\n"+EnumToString(sType)+" Active "+ActiveEventStr();
        
    return (text);
  }

//+------------------------------------------------------------------+
//| SessionStr - Returns formatted Session data for supplied type    |
//+------------------------------------------------------------------+
string CSession::SessionStr(PeriodType Type)
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
//| IsChanged - Compares SessionType to detect if a change occurred  |
//+------------------------------------------------------------------+
bool IsChanged(SessionType &Compare, SessionType Value)
  {
    if (Compare==Value)
      return (false);
      
    Compare = Value;
    return (true);
  }

//+------------------------------------------------------------------+
//| Color - Returns the color for session ranges                     |
//+------------------------------------------------------------------+
color Color(SessionType Type, DisplayColor Display=Dark)
  {
    switch (Type)
    {
      case Asia:    return((color)BoolToInt(Display==Dark,AsiaColor,clrForestGreen));
      case Europe:  return((color)BoolToInt(Display==Dark,EuropeColor,clrFireBrick));
      case US:      return((color)BoolToInt(Display==Dark,USColor,clrSteelBlue));
      case Daily:   return((color)BoolToInt(Display==Dark,DailyColor,clrDarkGray));
    }
    
    return (clrBlack);
  }

