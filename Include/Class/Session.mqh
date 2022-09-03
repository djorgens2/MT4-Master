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
             //-- Fractal Types
             enum SessionFractalType
             {
               sftCorrection        = 4,
               SessionFractalTypes  = 5
             };

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
             int              SessionHour(int Measure=Now);
             bool             IsOpen(void);
             
             double           Price(FractalType Type, FractalPoint FP);
             double           Pivot(const PeriodType Type);                          //--- Mid/Mean by Period Type
             int              Bias(double Price);                                    //--- Active Bias 
             int              Age(void)                          {return(sBarFE);}   //--- Number of periods since the last fractal event
             
             double           Retrace(FractalType Type, int Measure, int Format=InDecimal);    //--- returns fibonacci retrace
             double           Expansion(FractalType Type, int Measure, int Format=InDecimal);  //--- returns fibonacci expansion
             double           Forecast(FractalType Type, int Method, FiboLevel Fibo);          //--- returns extended fibo price

             string           CommentStr(void);
             string           FractalStr(void);
             string           SessionStr(PeriodType Type);

             SessionRec       operator[](const SessionFractalType Type) {return(sfractal[Type]);}
             SessionRec       operator[](const FractalType Type)        {return(sfractal[Type]);}
             SessionRec       operator[](const PeriodType Type)         {return(srec[Type]);}
                                 
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
             
             SessionRec       sfractal[SessionFractalTypes];
             
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
             void             OpenSession(void);
             void             CloseSession(void);

             void             UpdateSession(void);
             void             UpdateBias(void);
             void             UpdateTerm(void);
             void             UpdateTrend(void);
             void             UpdateOrigin(void);
             void             UpdateCorrection(void);

             void             UpdateBuffers(void);
             void             UpdateFractalBuffer(int Direction, double Value);

             void             LoadHistory(void);
  };

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
        if (IsLower(srec[ActiveSession].High,sfractal[Term].High,NoUpdate))
          state                      = Trap;
        else
          state                      = Breakout;
          
       statehigh                     = state;  //--- Retain for multiple boundary correction
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
        if (IsHigher(srec[ActiveSession].Low,sfractal[Term].Low,NoUpdate))
          state                      = Trap;
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
    
    if (NewState(srec[ActiveSession].State,state))
      SetEvent(FractalEvent(state),Nominal);
  }

//+------------------------------------------------------------------+
//| UpdateBias - Updates the fractal & session trade biases          |
//+------------------------------------------------------------------+
void CSession::UpdateBias(void)
  {  
    if (NewAction(srec[ActiveSession].Bias,this.Bias(BoolToDouble(IsOpen(),Pivot(OffSession),Pivot(PriorSession)))))
      SetEvent(NewBias,Nominal);
      
    if (NewAction(sfractal[Term].Bias,this.Bias(fdiv(Pivot(OffSession)+Pivot(PriorSession),2,Digits))))
      SetEvent(NewBias,Minor);
      
    if (NewAction(sfractal[Trend].Bias,this.Bias(Pivot(PriorSession))))
      SetEvent(NewBias,Major);

    if (sfractal[Origin].Direction==DirectionUp)
      if (NewAction(sfractal[Origin].Bias,this.Bias(Price(Fibo23,fmax(sfractal[Origin].High,sfractal[Origin].Resistance),sfractal[Origin].Support,Retrace))))
        SetEvent(NewBias,Critical);

    if (sfractal[Origin].Direction==DirectionDown)
      if (NewAction(sfractal[Origin].Bias,this.Bias(Price(Fibo23,sfractal[Origin].Support,fmax(sfractal[Origin].High,sfractal[Origin].Resistance),Retrace))))
        SetEvent(NewBias,Critical);       
  }

//+------------------------------------------------------------------+
//| UpdateTerm - Updates term fractal bounds and buffers             |
//+------------------------------------------------------------------+
void CSession::UpdateTerm(void)
  {
    double        expansion          = 0.00;
    FractalState  state              = NoState;

    //--- Check for term changes
    if (NewDirection(sfractal[Term].Direction,srec[ActiveSession].BreakoutDir))
    {
      SetEvent(NewTerm,Minor);

      if (sfractal[Term].Direction==DirectionUp)
      {
        sfractal[Term].Resistance    = srec[PriorSession].High;
        sfractal[Term].Support       = sfractal[Term].Low;
        sfractal[Term].High          = sfractal[Term].Low;   //-- Force NewExpansion Event
        sfractal[Term].Low           = Close[sBar];
      }

      if (sfractal[Term].Direction==DirectionDown)
      {
        sfractal[Term].Support       = srec[PriorSession].Low;
        sfractal[Term].Resistance    = sfractal[Term].High;
        sfractal[Term].Low           = sfractal[Term].High;  //-- Force NewExpansion Event
        sfractal[Term].High          = Close[sBar];
      }
    }

    //--- Check for term boundary changes
    if (sfractal[Term].Direction==DirectionUp)
      if (IsHigher(High[sBar],sfractal[Term].High))
      {
        SetEvent(NewExpansion,Minor);
        UpdateFractalBuffer(DirectionUp,High[sBar]);

        sfractal[Term].Low           = Close[sBar];        
        expansion                    = sfractal[Term].High;
      }
      else sfractal[Term].Low        = BoolToDouble(sBar==0,fmin(Close[sBar],sfractal[Term].Low),fmin(Low[sBar],sfractal[Term].Low),Digits);

    if (sfractal[Term].Direction==DirectionDown)
      if (IsLower(Low[sBar],sfractal[Term].Low))
      {
        SetEvent(NewExpansion,Minor);
        UpdateFractalBuffer(DirectionDown,Low[sBar]);

        sfractal[Term].High          = Close[sBar];
        expansion                    = sfractal[Term].Low;
      }
      else sfractal[Term].High       = BoolToDouble(sBar==0,fmax(Close[sBar],sfractal[Term].High),fmax(High[sBar],sfractal[Term].High),Digits);

    //--- Check for term state changes
    if (Event(NewExpansion,Minor))
    {
      if (IsBetween(expansion,sfractal[Prior].Support,sfractal[Prior].Resistance))
        if (sfractal[Term].Direction==sfractal[Term].BreakoutDir)
          state                      = Recovery;
        else
          state                      = Retrace;
      else
      if (IsBetween(expansion,sfractal[Term].Support,sfractal[Term].Resistance))
        if (sfractal[Term].Direction==DirectionUp)
          state                      = Rally;
        else
          state                      = Pullback;
      else
      {
        if (sfractal[Term].Direction==DirectionUp)
        {
          if (IsLower(expansion,sfractal[Prior].Support,NoUpdate))
            state                    = Rally;
              
          if (IsHigher(expansion,sfractal[Prior].Resistance,NoUpdate))
            if (NewDirection(sfractal[Term].BreakoutDir,sfractal[Term].Direction))
              state                  = Reversal;
            else
              state                  = Breakout;
        }
        else
        {
          if (IsHigher(expansion,sfractal[Prior].Resistance,NoUpdate))
            state                    = Pullback;

          if (IsLower(expansion,sfractal[Prior].Support,NoUpdate))
            if (NewDirection(sfractal[Term].BreakoutDir,sfractal[Term].Direction))
              state                  = Reversal;
            else
              state                  = Breakout;
        }
      }
      
      if (NewState(sfractal[Term].State,state))
      {
        SetEvent(NewState,Minor);
        if (sBar==0) Pause("New Term State, "+EnumToString(state),"Term.State() Check");
      }
    }
  }

//+------------------------------------------------------------------+
//| UpdateTrend - Updates trend fractal bounds and state             |
//+------------------------------------------------------------------+
void CSession::UpdateTrend(void)
  {
    FractalState  utState              = sfractal[Trend].State;

    //--- Check for trend changes      
    if (Event(NewTerm))        //--- After a term reversal
    {
      if (sfractal[Term].Direction==DirectionUp)
      {
        if (sfractal[Trend].Direction==DirectionUp)
          sfractal[sftCorrection].Low   = sfractal[Trend].Support;
        else
          sfractal[sftCorrection].Low   = sfractal[Trend].Low;

        sfractal[Trend].Support      = sfractal[Term].Support;
      }
      else
      {
        if (sfractal[Trend].Direction==DirectionDown)
          sfractal[sftCorrection].High  = sfractal[Trend].Resistance;
        else
          sfractal[sftCorrection].High  = sfractal[Trend].High;

        sfractal[Trend].Resistance   = sfractal[Term].Resistance;
      }
        
      if (sfractal[Term].Direction==sfractal[Trend].Direction)
        utState                        = Recovery;
      else
        utState                        = Retrace;
    }

    //--- Check for upper trend boundary changes
    if (sfractal[Trend].Direction==DirectionUp)
      sfractal[Trend].High           = fmax(High[sBar],sfractal[Trend].High);

    if (IsHigher(High[sBar],sfractal[Trend].Resistance,NoUpdate))
      if (NewDirection(sfractal[Trend].Direction,DirectionUp))
      {
        SetEvent(NewTrend,Major);
        sfractal[Trend].High         = High[sBar];
        utState                        = Reversal;
      }
      else
      {
        utState                        = Breakout;

        //--- Check for linear reversal
        if (IsHigher(High[sBar],sfractal[sftCorrection].High,NoUpdate))
          if (NewDirection(sfractal[Trend].BreakoutDir,DirectionUp))
            SetEvent(NewTrend,Major);
      }

    //--- Check for lower trend boundary changes
    if (sfractal[Trend].Direction==DirectionDown)
      sfractal[Trend].Low            = fmin(Low[sBar],sfractal[Trend].Low);

    if (IsLower(Low[sBar],sfractal[Trend].Support,NoUpdate))
      if (NewDirection(sfractal[Trend].Direction,DirectionDown))
      {
        SetEvent(NewTrend,Major);
        sfractal[Trend].Low          = Low[sBar];
        utState                        = Reversal;
      }
      else
      {
        utState                        = Breakout;
        
        //--- Check for linear reversal
        if (IsLower(Low[sBar],sfractal[sftCorrection].Low,NoUpdate))
          if (NewDirection(sfractal[Trend].BreakoutDir,DirectionDown))
            SetEvent(NewTrend,Major);
      }

    //--- Check for critical fibo price points
    if (Level(Expansion(Trend,Now))==FiboRoot)
      utState                          = Correction;
            
    if (NewState(sfractal[Trend].State,utState))
    {
      if (sfractal[Trend].State==Breakout)
        if (!NewDirection(sfractal[Trend].BreakoutDir,sfractal[Trend].Direction))
          SetEvent(NewExpansion,Major);   //--- Continuation breakout; strong trend

      SetEvent(NewState,Major);
    }
  }

//+------------------------------------------------------------------+
//| UpdateOrigin - Updates origin fractal bounds and state           |
//+------------------------------------------------------------------+
void CSession::UpdateOrigin(void)
  {
    FractalState  uoState               = NoState;
    
    if (Event(NewTrend))
    {
      if (sfractal[Trend].Direction==DirectionDown)
      {
        sfractal[Origin].Resistance   = fmax(sfractal[Trend].Resistance,sfractal[Trend].High);
        sfractal[Origin].High         = sfractal[Trend].Resistance;
      }
      else
      {
        sfractal[Origin].Support      = fmin(sfractal[Trend].Support,sfractal[Trend].Low);
        sfractal[Origin].Low          = sfractal[Trend].Support;
      }
    }

    if (Event(NewExpansion,Major))
    {
      if (sfractal[Trend].Direction==DirectionDown)
      {
        sfractal[Origin].High         = sfractal[Trend].Resistance;
        sfractal[Origin].Low          = sfractal[Trend].Low;
      }
      else
      {
        sfractal[Origin].Low          = sfractal[Trend].Support;
        sfractal[Origin].High         = sfractal[Trend].High;
      }
    }
    
    if (IsHigher(High[sBar],sfractal[Origin].High))
    {
      if (NewDirection(sfractal[Origin].Direction,DirectionUp))
        if (sfractal[Origin].Direction==sfractal[Origin].BreakoutDir)
          uoState                       = Recovery;
        else
          uoState                       = Correction;
        
      if (IsHigher(High[sBar],sfractal[Origin].Resistance,NoUpdate))
        if (NewDirection(sfractal[Origin].BreakoutDir,DirectionUp))
        {
          SetEvent(NewOrigin,Critical);
          uoState                       = Reversal;
        }
        else
          uoState                       = Breakout;
    }

    if (IsLower(Low[sBar],sfractal[Origin].Low))
    {
      if (NewDirection(sfractal[Origin].Direction,DirectionDown))
        if (sfractal[Origin].Direction==sfractal[Origin].BreakoutDir)
          uoState                       = Recovery;
        else
          uoState                       = Correction;

      if (IsLower(Low[sBar],sfractal[Origin].Support,NoUpdate))
        if (NewDirection(sfractal[Origin].BreakoutDir,DirectionDown))
        {
          SetEvent(NewOrigin,Critical);
          uoState                       = Reversal;
        }
        else
          uoState                       = Breakout;
    }

    if (uoState==NoState)
    {
      if (Level(Retrace(Origin,Now))<Fibo23)
        if (sfractal[Origin].State==Retrace)
          uoState                       = Recovery;

      if (sfractal[Origin].State==Recovery)
        if (Level(Retrace(Origin,Now))>Fibo23)
          uoState                       = NoState;
        else
          uoState                       = Recovery;
                
      if (uoState==NoState)
      {
        if (sfractal[Origin].State!=Retrace)
          if (Level(Retrace(Origin,Now))>FiboRoot)
            if (sfractal[Origin].Direction==DirectionUp)
              uoState                    = Pullback;
            else
              uoState                    = Rally;

        if (Level(Retrace(Origin,Now))>Fibo38)
          uoState                        = Retrace;
      }
    }
    
    if (NewState(sfractal[Origin].State,uoState))
      SetEvent(NewOrigin,Critical);
  }

//+------------------------------------------------------------------+
//| UpdateCorrection - Detects market corrections; sets the state    |
//+------------------------------------------------------------------+
void CSession::UpdateCorrection(void)
  {
    FractalState state                       = sfractal[sftCorrection].State;
    sfractal[sftCorrection].Direction        = sfractal[Term].Direction;
    
    if (IsBetween(Close[sBar],sfractal[sftCorrection].High,sfractal[sftCorrection].Low))
    {
//      sfractal[sftCorrection].State          = (FractalState)BoolToInt(IsEqual(sfractal[sftCorrection].Direction,DirectionUp),Rally,Pullback);
      sfractal[sftCorrection].State          = Retrace;

      if (sfractal[sftCorrection].Direction==DirectionUp)
        if (IsBetween(Close[sBar],sfractal[sftCorrection].Support,sfractal[sftCorrection].Low))
          sfractal[sftCorrection].State      = Rally;

      if (sfractal[sftCorrection].Direction==DirectionDown)
        if (IsBetween(Close[sBar],sfractal[sftCorrection].Resistance,sfractal[sftCorrection].High))
          sfractal[sftCorrection].State      = Pullback;
    }
    else
    {
      sfractal[sftCorrection].State          = Breakout;

      if (NewDirection(sfractal[sftCorrection].BreakoutDir,Direction(Close[sBar]-sfractal[sftCorrection].Low)))
      {
        if (sfractal[sftCorrection].BreakoutDir==DirectionUp)
          sfractal[sftCorrection].Resistance = sfractal[sftCorrection].High;
        else
          sfractal[sftCorrection].Support    = sfractal[sftCorrection].Low;        

        sfractal[sftCorrection].State        = Reversal;
      }
    }
    
    if (NewState(state,sfractal[sftCorrection].State))
      SetEvent(FractalEvent(state),Critical);
  }

//+------------------------------------------------------------------+
//| UpdateFibo - Sets/Fires Fibo Expansion alerts                    |
//+------------------------------------------------------------------+
//void CSession::UpdateFibo(void)
//  {    
    //-- Test/Reset for Expansion Fibos/Events
//    for (FractalType type=Origin;type<=Term;type++)
//    {
//      if (fBreakout||fReversal||Event(NewBreakout)||Event(NewReversal)||Event(NewDivergence))
//        fEventFibo[Type]                  = fmax(Level(Fibonacci(Type,Expansion,Max))+1,Fibo161);
//
//      if (Percent(fmin(fEventFibo[Type],Fibo823))<Fibonacci(Type,Expansion,Now))
//      {
//        fEventFibo[Type]++;
//        f[Type].Event                   = BoolToEvent(IsChanged(f[Type].Event,NewFibonacci),NewFibonacci,f[Type].Event);
//
//        SetEvent(f[Type].Event,alertlevel);
//      }
//    }
//  }

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
    int lhStartDir                   = DirectionNone;
          
    //--- Initialize period operationals
    sBar                             = Bars-1;
    sBars                            = Bars;
    sBarDay                          = NoValue;
    sBarHour                         = NoValue;
    
    sBarFE                           = sBar;
    sDirFE                           = DirectionNone;

    if (Close[sBar]<Open[sBar])
      lhStartDir                     = DirectionDown;
      
    if (Close[sBar]>Open[sBar])
      lhStartDir                     = DirectionUp;
    
    //--- Initialize session records
    for (int type=0;type<PeriodTypes;type++)
    {
      srec[type].Direction           = lhStartDir;
      srec[type].BreakoutDir         = DirectionNone;
      srec[type].State               = Breakout;
      srec[type].High                = High[sBar];
      srec[type].Low                 = Low[sBar];
      srec[type].Resistance          = High[sBar];
      srec[type].Support             = Low[sBar];
    }

    //--- Initialize Fibo record
    for (int type=0;type<SessionFractalTypes;type++)
      sfractal[type]                 = srec[ActiveSession];

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
    UpdateBias();
    UpdateTerm();
    UpdateTrend();
    UpdateOrigin();
    UpdateCorrection();
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
int CSession::Bias(double Price)
  {
    if (Pivot(ActiveSession)>Price)
      return (OP_BUY);

    if (Pivot(ActiveSession)<Price)
      return (OP_SELL);
  
    return (Action(srec[ActiveSession].Direction,InDirection));
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
      case fpExpansion: if (Type<Term)
                          return(BoolToDouble(IsEqual(sfractal[Type].Direction,DirectionUp),sfractal[Term].High,sfractal[Term].Low,Digits));
                        return(BoolToDouble(IsEqual(sfractal[Type].Direction,DirectionUp),sfractal[Type].High,sfractal[Type].Low,Digits));
      case fpRetrace:   if (IsEqual(sfractal[Type].Direction,sfractal[Term].Direction))
                          return(BoolToDouble(IsEqual(sfractal[Term].Direction,DirectionUp),sfractal[Term].Low,sfractal[Term].High,Digits));
                        return(Price(Term,fpExpansion));
      case fpRecovery:  return(Close[sBar]);
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| Retrace - Calcuates fibo retrace % for supplied Type             |
//+------------------------------------------------------------------+
double CSession::Retrace(FractalType Type, int Measure, int Format=InDecimal)
  {
      switch (Measure)
      {
        case Now: return(Retrace(Price(Type,fpRoot),Price(Type,fpExpansion),Close[sBar],Format));
        case Max: return(Retrace(Price(Type,fpRoot),Price(Type,fpExpansion),Price(Type,fpRetrace),Format));
      }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Expansion - Calcuates fibo expansion % for supplied Type         |
//+------------------------------------------------------------------+
double CSession::Expansion(FractalType Type, int Measure, int Format=InDecimal)
  {
    switch (Measure)
    {
      case Now: return(Expansion(Price(Type,fpBase),Price(Type,fpRoot),Close[sBar],Format));
      case Max: return(Expansion(Price(Type,fpBase),Price(Type,fpRoot),Price(Type,fpExpansion),Format));
    }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Forecast - Returns Forecast Price for supplied Fibo              |
//+------------------------------------------------------------------+
double CSession::Forecast(FractalType Type, int Method, FiboLevel Fibo)
  {
    switch (Method)
    {
      case Expansion:   return(NormalizeDouble(Price(Type,fpRoot)+((Price(Type,fpBase)-Price(Type,fpRoot))*Percent(Fibo)),Digits));
      case Retrace:     return(NormalizeDouble(Price(Type,fpExpansion)+((Price(Type,fpRoot)-Price(Type,fpExpansion))*Percent(Fibo)),Digits));
      case Recovery:    return(NormalizeDouble(Price(Type,fpRoot)-((Price(Type,fpRoot)-Price(Type,fpExpansion))*Percent(Fibo)),Digits));
    }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| CommentStr - Returns Screen formatted Fibonacci Detail           |
//+------------------------------------------------------------------+
string CSession::CommentStr(void)
  {  
    string text            = "*---------- "+EnumToString(this.Type())+" ["+BoolToStr(IsOpen(),"Open","Closed")+"] Session Fractal ----------*\n"+
        "Correction: "+EnumToString(sfractal[sftCorrection].State)+" Direction: "+DirText(sfractal[sftCorrection].Direction)+"/"+DirText(sfractal[sftCorrection].BreakoutDir)+"\n"+
        "Term State: "+EnumToString(sfractal[Term].State)+" Direction: "+DirText(sfractal[Term].Direction)+"/"+DirText(sfractal[Term].BreakoutDir)+"\n"+
                       " (r) "+DoubleToStr(Retrace(Term,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(Term,Max,InPercent),1)+"%"+"\n"+
                       " (e) "+DoubleToStr(Expansion(Term,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(Term,Max,InPercent),1)+"%\n"+
        "Trend State: "+EnumToString(sfractal[Trend].State)+" Direction: "+DirText(sfractal[Trend].Direction)+"/"+DirText(sfractal[Trend].BreakoutDir)+"\n"+
                       " (r) "+DoubleToStr(Retrace(Trend,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(Trend,Max,InPercent),1)+"%"+"\n"+
                       " (e) ["+EnumToString(Level(Expansion(Trend,Now)))+"]"+DoubleToStr(Expansion(Trend,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(Trend,Max,InPercent),1)+"%\n"+
        "Origin State:  "+EnumToString(sfractal[Origin].State)+" Direction: "+DirText(sfractal[Origin].Direction)+"/"+DirText(sfractal[Origin].BreakoutDir)+"\n"+
                       " (r) "+DoubleToStr(Retrace(Origin,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(Origin,Max,InPercent),1)+"%"+"\n"+
                       " (e) "+DoubleToStr(Expansion(Origin,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(Origin,Max,InPercent),1)+"%\n"+
        "\n"+EnumToString(sType)+" Active "+ActiveEventStr();
        
    return (text);
  }

//+------------------------------------------------------------------+
//| FractalStr - Formatted fibonacci data                            |
//+------------------------------------------------------------------+
string CSession::FractalStr(void)
  {
    return ("*---------- "+EnumToString(this.Type())+ " Session Fractal ----------*\n"+
        "Correction: "+EnumToString(sfractal[sftCorrection].State)+" Direction: "+DirText(sfractal[sftCorrection].Direction)+"/"+DirText(sfractal[sftCorrection].BreakoutDir)+"\n"+
        "Term State: "+EnumToString(sfractal[Term].State)+" Direction: "+DirText(sfractal[Term].Direction)+"/"+DirText(sfractal[Term].BreakoutDir)+
                       " (r) "+DoubleToStr(Retrace(Term,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(Term,Max,InPercent),1)+"%"+
                       " (e) "+DoubleToStr(Expansion(Term,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(Term,Max,InPercent),1)+"%\n"+
        "Trend State: "+EnumToString(sfractal[Trend].State)+" Direction: "+DirText(sfractal[Trend].Direction)+"/"+DirText(sfractal[Trend].BreakoutDir)+
                       " (r) "+DoubleToStr(Retrace(Trend,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(Trend,Max,InPercent),1)+"%"+
                       " (e) "+DoubleToStr(Expansion(Trend,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(Trend,Max,InPercent),1)+"%\n"+
        "Origin State:  "+EnumToString(sfractal[Origin].State)+" Direction: "+DirText(sfractal[Origin].Direction)+"/"+DirText(sfractal[Origin].BreakoutDir)+
                       " (r) "+DoubleToStr(Retrace(Origin,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(Origin,Max,InPercent),1)+"%"+
                       " (e) "+DoubleToStr(Expansion(Origin,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(Origin,Max,InPercent),1)+"%\n"+
        "\n"+EnumToString(sType)+" Active "+ActiveEventStr());
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
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(SessionFractalType &Check, SessionFractalType Compare, bool Update=true)
  {
    if (Check == Compare)
      return (false);
  
    if (Update)
      Check   = Compare;
  
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

