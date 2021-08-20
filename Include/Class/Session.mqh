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
class CSession
  {

public:
             //-- Fractal Types
             enum SessionFractalType
             {
               sftOrigin,
               sftTrend,
               sftTerm,
               sftPrior,
               sftCorrection,
               SessionFractalTypes
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

             //-- FractalDetail
             struct FiboDetail
             {
               double Correction;
               double Retrace[5];
               double RetraceNow;
               double RetraceMax;
               double Expansion[10];
               double ExpansionNow;
               double ExpansionMax;
             };
             
             //-- Session Record Definition
             struct SessionRec
             {
               int            Direction;
               int            BreakoutDir;     //--- Direction of the last breakout or reversal
               int            Bias;            //--- Current session Bias in action
               ReservedWords  State;
               double         High;            //--- High/Low store daily/session high & low
               double         Low;
               double         Support;         //--- Support/Resistance determines reversal, breakout & continuation
               double         Resistance;
             };
             
             CSession(SessionType Type, int HourOpen, int HourClose, int HourOffset);
            ~CSession();

             SessionType      Type(void)                       {return (sType);}
             int              SessionHour(int Measure=Now);
             bool             IsOpen(void);
             
             bool             Event(EventType Type,AlertLevelType AlertLevel)
                                                               {return (sEvent.Event(Type,AlertLevel));}
             bool             Event(EventType Type)            {return (sEvent[Type]);}
             AlertLevelType   AlertLevel(EventType Type)       {return (sEvent.AlertLevel(Type));}
             bool             ActiveEvent(void)                {return (sEvent.ActiveEvent());}
             string           ActiveEventText(const bool WithHeader=true)
                                                               {return (sEvent.ActiveEventText(WithHeader));};
             
             datetime         ServerTime(int Bar=0);
             
             double           Pivot(const PeriodType Type);
             int              Bias(double Price);
             int              Age(void)                         {return(sBarFE);}   //--- Number of periods since the last fractal event
             
             FiboDetail       Fibonacci(SessionFractalType Type);
             double           Retrace(SessionFractalType Type, int Measure, int Format=InDecimal);       //--- returns fibonacci retrace
             double           Expansion(SessionFractalType Type, int Measure, int Format=InDecimal);     //--- returns fibonacci expansion

             void             Update(void);
             void             Update(double &OffSessionBuffer[], double &PriorMidBuffer[], double &FractalBuffer[]);
             void             RefreshScreen(void);

             string           FractalStr(void);
             string           SessionText(PeriodType Type);

             SessionRec       Fractal(const SessionFractalType Type)   {return(sfractal[Type]);}
             
             SessionRec       operator[](const PeriodType Type) {return(srec[Type]);}
                                 
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
             FiboDetail       sFibo[SessionFractalTypes];
             
             int              sBarFE;          //--- Fractal Expansion Bar
             int              sDirFE;          //--- Fractal Direction (Painted)

             //--- Private class collections
             SessionRec       srec[PeriodTypes];
             
             CArrayDouble    *sOffMidBuffer;
             CArrayDouble    *sPriorMidBuffer;
             CArrayDouble    *sFractalBuffer;
             CArrayDouble    *sSessionRange;
             
             CEvent          *sEvent;
             
             //--- Private Methods
             void             OpenSession(void);
             void             CloseSession(void);
             void             UpdateSession(void);
                          
             void             UpdateBuffers(void);
             void             UpdateFractalBuffer(int Direction, double Value);

             void             LoadHistory(void);
             
             bool             NewBias(int &Now, int New);
             bool             NewDirection(int &Direction, int NewDirection, bool Update=true);
             bool             NewState(ReservedWords &State, ReservedWords NewState, EventType EventTrigger);

             void             UpdateBias(void);
             void             UpdateTerm(void);
             void             UpdateTrend(void);
             void             UpdateOrigin(void);
             void             SetCorrectionState(void);
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
//| NewBias - Updates Trade Bias based on an actual change           |
//+------------------------------------------------------------------+
bool CSession::NewBias(int &Now, int New)
  {    
    if (New==OP_NO_ACTION)
      return (false);
      
    if (IsChanged(Now,New))
      return (true);
      
    return (false);
  }

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
      sEvent.SetEvent(NewDirection,Nominal);
      return(true);
    }
    
    return(false);
  }
    
//+------------------------------------------------------------------+
//| NewState - Tests for new state events                            |
//+------------------------------------------------------------------+
bool CSession::NewState(ReservedWords &State, ReservedWords ChangeState, EventType EventTrigger)
  {
    if (ChangeState==NoState)
      return(false);
     
    if (State==NoState)
      State                       = ChangeState;

    if (sEvent[EventTrigger])
    {
      if (ChangeState==Reversal)
        if (State==Reversal)
          State                    = Correction;
     }
     else
     if (ChangeState==Breakout)
     {
       if (State==Reversal)
         return(false);
     }
     else
     if (State==Recovery)
     {
       if (ChangeState!=Correction)
         return(false);
     }
     else
     if (State==Correction)
       if (ChangeState!=Recovery)
         return(false);

    if (IsChanged(State,ChangeState))
    { 
      switch (State)
      {
        case Reversal:    sEvent.SetEvent(NewFractal,(AlertLevelType)BoolToInt(IsEqual(EventTrigger,NewOrigin),Critical,
                                                                     BoolToInt(IsEqual(EventTrigger,NewTrend),Major,Minor)));
                          sEvent.SetEvent(NewReversal,Major);
                          break;
        case Breakout:    sEvent.SetEvent(NewFractal,(AlertLevelType)BoolToInt(IsEqual(EventTrigger,NewOrigin),Critical,
                                                                     BoolToInt(IsEqual(EventTrigger,NewTrend),Major,Minor)));
                          sEvent.SetEvent(NewBreakout,Major);
                          break;
        case Rally:       sEvent.SetEvent(NewRally,Nominal);
                          break;
        case Pullback:    sEvent.SetEvent(NewPullback,Nominal);
                          break;
        case Trap:        sEvent.SetEvent(NewTrap,Nominal);
                          break;
        case Retrace:     sEvent.SetEvent(NewRetrace,Minor);
                          break;
        case Recovery:    sEvent.SetEvent(NewRecovery,Minor);
                          break;
        case Resume:      sEvent.SetEvent(NewResume,Minor);
                          break;
        case Correction:  sEvent.SetEvent(NewCorrection,Major);
                          break;
      }
      
      return(true);
    }
      
    return(false);
  }

//+------------------------------------------------------------------+
//| SetCorrectionState - Detects market corrections; sets the state  |
//+------------------------------------------------------------------+
void CSession::SetCorrectionState(void)
  {
    NewDirection(sfractal[sftCorrection].Direction,sfractal[sftTerm].Direction);
    
    if (IsBetween(Close[sBar],sfractal[sftCorrection].High,sfractal[sftCorrection].Low))
    {
      sfractal[sftCorrection].State          = Retrace;

      if (sfractal[sftCorrection].Direction==DirectionUp)
        if (IsBetween(Close[sBar],sfractal[sftCorrection].Support,sfractal[sftCorrection].Low))
          sfractal[sftCorrection].State        = Rally;

      if (sfractal[sftCorrection].Direction==DirectionDown)
        if (IsBetween(Close[sBar],sfractal[sftCorrection].Resistance,sfractal[sftCorrection].High))
          sfractal[sftCorrection].State        = Pullback;
    }
    else
    {
      if (NewDirection(sfractal[sftCorrection].BreakoutDir,Direction(Close[sBar]-sfractal[sftCorrection].Low)))
        if (sfractal[sftCorrection].BreakoutDir==DirectionUp)
          sfractal[sftCorrection].Resistance = sfractal[sftCorrection].High;
        else
          sfractal[sftCorrection].Support    = sfractal[sftCorrection].Low;        

      if (sfractal[sftCorrection].Direction==sfractal[sftCorrection].BreakoutDir)
        sfractal[sftCorrection].State        = Breakout;        
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
//| UpdateBias - Updates the fractal & session trade biases          |
//+------------------------------------------------------------------+
void CSession::UpdateBias(void)
  {  
    if (NewBias(srec[ActiveSession].Bias,this.Bias(BoolToDouble(IsOpen(),Pivot(OffSession),Pivot(PriorSession)))))
      sEvent.SetEvent(NewBias,Nominal);
      
    if (NewBias(sfractal[sftTerm].Bias,this.Bias(fdiv(Pivot(OffSession)+Pivot(PriorSession),2,Digits))))
      sEvent.SetEvent(NewBias,Minor);
      
    if (NewBias(sfractal[sftTrend].Bias,this.Bias(Pivot(PriorSession))))
      sEvent.SetEvent(NewBias,Major);

    if (sfractal[sftOrigin].Direction==DirectionUp)
      if (NewBias(sfractal[sftOrigin].Bias,this.Bias(FiboPrice(Fibo23,fmax(sfractal[sftOrigin].High,sfractal[sftOrigin].Resistance),sfractal[sftOrigin].Support,Retrace))))
        sEvent.SetEvent(NewBias,Critical);

    if (sfractal[sftOrigin].Direction==DirectionDown)
      if (NewBias(sfractal[sftOrigin].Bias,this.Bias(FiboPrice(Fibo23,sfractal[sftOrigin].Support,fmax(sfractal[sftOrigin].High,sfractal[sftOrigin].Resistance),Retrace))))
        sEvent.SetEvent(NewBias,Critical);       
  }

//+------------------------------------------------------------------+
//| UpdateTerm - Updates term fractal bounds and buffers             |
//+------------------------------------------------------------------+
void CSession::UpdateTerm(void)
  {
    double        ufExpansion          = 0.00;
    ReservedWords ufState              = NoState;
    
    //--- Check for term changes
    if (sEvent[NewReversal])
      if (NewDirection(sfractal[sftTerm].Direction,srec[ActiveSession].Direction))
      {
        sEvent.SetEvent(NewTerm,Minor);
                
        if (sfractal[sftTerm].Direction==DirectionUp)
        {
          sfractal[sftTerm].Resistance  = srec[PriorSession].High;
          sfractal[sftTerm].Support     = sfractal[sftTerm].Low;
          sfractal[sftTerm].High        = sfractal[sftTerm].Low;   //-- Force NewFractal Event
          sfractal[sftTerm].Low         = Close[sBar];
        }

        if (sfractal[sftTerm].Direction==DirectionDown)
        {
          sfractal[sftTerm].Support     = srec[PriorSession].Low;
          sfractal[sftTerm].Resistance  = sfractal[sftTerm].High;
          sfractal[sftTerm].Low         = sfractal[sftTerm].High;  //-- Force NewFractal Event
          sfractal[sftTerm].High        = Close[sBar];
        }
      }

    //--- Check for term boundary changes
    if (sfractal[sftTerm].Direction==DirectionUp)
      if (IsHigher(High[sBar],sfractal[sftTerm].High))
      {
        sEvent.SetEvent(NewFractal,Minor);
        UpdateFractalBuffer(DirectionUp,High[sBar]);

        sfractal[sftTerm].Low           = Close[sBar];        
        ufExpansion                    = sfractal[sftTerm].High;
      }
      else
      if (sBar==0)
        sfractal[sftTerm].Low           = fmin(Close[sBar],sfractal[sftTerm].Low);
      else
        sfractal[sftTerm].Low           = fmin(Low[sBar],sfractal[sftTerm].Low);
            
    if (sfractal[sftTerm].Direction==DirectionDown)
      if (IsLower(Low[sBar],sfractal[sftTerm].Low))
      {
        sEvent.SetEvent(NewFractal,Minor);
        UpdateFractalBuffer(DirectionDown,Low[sBar]);

        sfractal[sftTerm].High          = Close[sBar];
        ufExpansion                    = sfractal[sftTerm].Low;
      }
      else
      if (sBar==0)
        sfractal[sftTerm].High          = fmax(Close[sBar],sfractal[sftTerm].High);
      else
        sfractal[sftTerm].High          = fmax(High[sBar],sfractal[sftTerm].High);
      
    if (sEvent[NewFractal])
    {
      if (IsBetween(ufExpansion,sfractal[sftPrior].Support,sfractal[sftPrior].Resistance))
        if (sfractal[sftTerm].Direction==sfractal[sftTerm].BreakoutDir)
          ufState                      = Recovery;
        else
          ufState                      = Retrace;
      else
      if (IsBetween(ufExpansion,sfractal[sftTerm].Support,sfractal[sftTerm].Resistance))
        if (sfractal[sftTerm].Direction==DirectionUp)
          ufState                      = Rally;
        else
          ufState                      = Pullback;
      else
      {
        if (sfractal[sftTerm].Direction==DirectionUp)
        {
          if (IsLower(ufExpansion,sfractal[sftPrior].Support,NoUpdate))
            ufState                    = Rally;
              
          if (IsHigher(ufExpansion,sfractal[sftPrior].Resistance,NoUpdate))
            if (NewDirection(sfractal[sftTerm].BreakoutDir,sfractal[sftTerm].Direction))
              ufState                  = Reversal;
            else
              ufState                  = Breakout;
        }
        else
        {
          if (IsHigher(ufExpansion,sfractal[sftPrior].Resistance,NoUpdate))
            ufState                    = Pullback;

          if (IsLower(ufExpansion,sfractal[sftPrior].Support,NoUpdate))
            if (NewDirection(sfractal[sftTerm].BreakoutDir,sfractal[sftTerm].Direction))
              ufState                  = Reversal;
            else
              ufState                  = Breakout;
        }
      }
      
      if (NewState(sfractal[sftTerm].State,ufState,NewTerm))
        sEvent.SetEvent(NewState,Notify);
    }
  }

//+------------------------------------------------------------------+
//| UpdateTrend - Updates trend fractal bounds and state             |
//+------------------------------------------------------------------+
void CSession::UpdateTrend(void)
  {
    ReservedWords utState              = sfractal[sftTrend].State;

    //--- Check for trend changes      
    if (sEvent[NewTerm])        //--- After a term reversal
    {
      if (sfractal[sftTerm].Direction==DirectionUp)
      {
        if (sfractal[sftTrend].Direction==DirectionUp)
          sfractal[sftCorrection].Low   = sfractal[sftTrend].Support;
        else
          sfractal[sftCorrection].Low   = sfractal[sftTrend].Low;

        sfractal[sftTrend].Support      = sfractal[sftTerm].Support;
      }
      else
      {
        if (sfractal[sftTrend].Direction==DirectionDown)
          sfractal[sftCorrection].High  = sfractal[sftTrend].Resistance;
        else
          sfractal[sftCorrection].High  = sfractal[sftTrend].High;

        sfractal[sftTrend].Resistance   = sfractal[sftTerm].Resistance;
      }
        
      if (sfractal[sftTerm].Direction==sfractal[sftTrend].Direction)
        utState                        = Recovery;
      else
        utState                        = Retrace;
    }

    //--- Check for upper trend boundary changes
    if (sfractal[sftTrend].Direction==DirectionUp)
      sfractal[sftTrend].High           = fmax(High[sBar],sfractal[sftTrend].High);

    if (IsHigher(High[sBar],sfractal[sftTrend].Resistance,NoUpdate))
      if (NewDirection(sfractal[sftTrend].Direction,DirectionUp))
      {
        sEvent.SetEvent(NewTrend,Major);
        sfractal[sftTrend].High         = High[sBar];
        utState                        = Reversal;
      }
      else
      {
        utState                        = Breakout;

        //--- Check for linear reversal
        if (IsHigher(High[sBar],sfractal[sftCorrection].High,NoUpdate))
          if (NewDirection(sfractal[sftTrend].BreakoutDir,DirectionUp))
            sEvent.SetEvent(NewTrend,Major);
      }

    //--- Check for lower trend boundary changes
    if (sfractal[sftTrend].Direction==DirectionDown)
      sfractal[sftTrend].Low            = fmin(Low[sBar],sfractal[sftTrend].Low);

    if (IsLower(Low[sBar],sfractal[sftTrend].Support,NoUpdate))
      if (NewDirection(sfractal[sftTrend].Direction,DirectionDown))
      {
        sEvent.SetEvent(NewTrend,Major);
        sfractal[sftTrend].Low          = Low[sBar];
        utState                        = Reversal;
      }
      else
      {
        utState                        = Breakout;
        
        //--- Check for linear reversal
        if (IsLower(Low[sBar],sfractal[sftCorrection].Low,NoUpdate))
          if (NewDirection(sfractal[sftTrend].BreakoutDir,DirectionDown))
            sEvent.SetEvent(NewTrend,Major);
      }

    //--- Check for critical fibo price points
    if (FiboLevel(Expansion(sftTrend,Now))==FiboRoot)
      utState                          = Correction;
            
    if (NewState(sfractal[sftTrend].State,utState,NewTrend))
    {
      if (sfractal[sftTrend].State==Breakout)
        if (!NewDirection(sfractal[sftTrend].BreakoutDir,sfractal[sftTrend].Direction))
          sEvent.SetEvent(NewExpansion,Major);   //--- Continuation breakout; strong trend

      sEvent.SetEvent(NewState,Notify);
     }
  }

//+------------------------------------------------------------------+
//| UpdateOrigin - Updates origin fractal bounds and state           |
//+------------------------------------------------------------------+
void CSession::UpdateOrigin(void)
  {
    ReservedWords uoState               = NoState;
    
    if (sEvent[NewTrend])
    {
      if (sfractal[sftTrend].Direction==DirectionDown)
      {
        sfractal[sftOrigin].Resistance   = fmax(sfractal[sftTrend].Resistance,sfractal[sftTrend].High);
        sfractal[sftOrigin].High         = sfractal[sftTrend].Resistance;
      }
      else
      {
        sfractal[sftOrigin].Support      = fmin(sfractal[sftTrend].Support,sfractal[sftTrend].Low);
        sfractal[sftOrigin].Low          = sfractal[sftTrend].Support;
      }
    }

    if (sEvent[NewExpansion])
    {
      if (sfractal[sftTrend].Direction==DirectionDown)
      {
        sfractal[sftOrigin].High         = sfractal[sftTrend].Resistance;
        sfractal[sftOrigin].Low          = sfractal[sftTrend].Low;
      }
      else
      {
        sfractal[sftOrigin].Low          = sfractal[sftTrend].Support;
        sfractal[sftOrigin].High         = sfractal[sftTrend].High;
      }
    }
    
    if (IsHigher(High[sBar],sfractal[sftOrigin].High))
    {
      if (NewDirection(sfractal[sftOrigin].Direction,DirectionUp))
        if (sfractal[sftOrigin].Direction==sfractal[sftOrigin].BreakoutDir)
          uoState                       = Recovery;
        else
          uoState                       = Correction;
        
      if (IsHigher(High[sBar],sfractal[sftOrigin].Resistance,NoUpdate))
        if (NewDirection(sfractal[sftOrigin].BreakoutDir,DirectionUp))
        {
          sEvent.SetEvent(NewOrigin,Critical);
          uoState                       = Reversal;
        }
        else
          uoState                       = Breakout;
    }

    if (IsLower(Low[sBar],sfractal[sftOrigin].Low))
    {
      if (NewDirection(sfractal[sftOrigin].Direction,DirectionDown))
        if (sfractal[sftOrigin].Direction==sfractal[sftOrigin].BreakoutDir)
          uoState                       = Recovery;
        else
          uoState                       = Correction;

      if (IsLower(Low[sBar],sfractal[sftOrigin].Support,NoUpdate))
        if (NewDirection(sfractal[sftOrigin].BreakoutDir,DirectionDown))
        {
          sEvent.SetEvent(NewOrigin,Critical);
          uoState                       = Reversal;
        }
        else
          uoState                       = Breakout;
    }

    if (uoState==NoState)
    {
      if (FiboLevel(Retrace(sftOrigin,Now))<Fibo23)
        if (sfractal[sftOrigin].State==Retrace)
          uoState                       = Resume;

      if (sfractal[sftOrigin].State==Resume)
        if (FiboLevel(Retrace(sftOrigin,Now))>Fibo23)
          uoState                       = NoState;
        else
          uoState                       = Resume;
                
      if (uoState==NoState)
      {
        if (sfractal[sftOrigin].State!=Retrace)
          if (FiboLevel(Retrace(sftOrigin,Now))>FiboRoot)
            if (sfractal[sftOrigin].Direction==DirectionUp)
              uoState                    = Pullback;
            else
              uoState                    = Rally;

        if (FiboLevel(Retrace(sftOrigin,Now))>Fibo38)
          uoState                        = Retrace;
      }
    }
    
    if (NewState(sfractal[sftOrigin].State,uoState,NewOrigin))
      sEvent.SetEvent(NewState,Notify);
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

    //int           usArrow;
    //double        usArrowHigh;
    //double        usArrowLow;

    if (IsHigher(High[sBar],srec[ActiveSession].High))
    {
      sEvent.SetEvent(NewHigh,Nominal);
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
        if (IsLower(srec[ActiveSession].High,sfractal[sftTerm].High,NoUpdate))
          usState                      = Trap;
        else
          usState                      = Breakout;
          
       usHighState                     = usState;  //--- Retain for multiple boundary correction
    }
            
    if (IsLower(Low[sBar],srec[ActiveSession].Low))
    {
      sEvent.SetEvent(NewLow,Nominal);
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
        if (IsHigher(srec[ActiveSession].Low,sfractal[sftTerm].Low,NoUpdate))
          usState                      = Trap;
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
    
    if (NewState(srec[ActiveSession].State,usState,NewDirection))
      sEvent.SetEvent(NewState,Nominal);
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
    sEvent.SetEvent(SessionOpen,Notify);
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
    srec[ActiveSession].Resistance        = Open[sBar];
    srec[ActiveSession].Support           = Open[sBar];
    srec[ActiveSession].High              = Open[sBar];
    srec[ActiveSession].Low               = Open[sBar];
    
    sEvent.SetEvent(SessionClose,Notify);
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
    
    sEvent                           = new CEvent();

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
    delete sEvent;
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
    sEvent.ClearEvents();

    //--- Test for New Day; Force close
    if (IsChanged(sBarDay,TimeDay(ServerTime(sBar))))
    {
      sEvent.SetEvent(NewDay,Notify);
      
      if (IsChanged(sSessionIsOpen,false))
        CloseSession();
    }
    
    if (IsChanged(sBarHour,TimeHour(ServerTime(sBar))))
      sEvent.SetEvent(NewHour,Notify);

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
    SetCorrectionState();
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
//| Retrace - Calcuates fibo retrace % for supplied Type             |
//+------------------------------------------------------------------+
double CSession::Retrace(SessionFractalType Type, int Measure, int Format=InDecimal)
  {
    int    fDirection     = sfractal[Type].Direction;

    if (Type==sftOrigin)  //--- Origin computes retrace from its extremities
      if (fDirection==DirectionUp)
        switch (Measure)
        {
          case Now: return(FiboRetrace(sfractal[Type].Support,fmax(sfractal[Type].High,sfractal[Type].Resistance),Close[sBar],Format));
          case Max: return(FiboRetrace(sfractal[Type].Support,fmax(sfractal[Type].High,sfractal[Type].Resistance),sfractal[sftTerm].Low,Format));
        }
      else
        switch (Measure)
        {
          case Now: return(FiboRetrace(sfractal[Type].Resistance,fmin(sfractal[Type].Low,sfractal[Type].Support),Close[sBar],Format));
          case Max: return(FiboRetrace(sfractal[Type].Resistance,fmin(sfractal[Type].Low,sfractal[Type].Support),sfractal[sftTerm].High,Format));
        }
    else  
    if (fDirection==DirectionUp)
      switch (Measure)
      {
        case Now: return(FiboRetrace(sfractal[Type].Support,sfractal[Type].High,Close[sBar],Format));
        case Max: return(FiboRetrace(sfractal[Type].Support,sfractal[Type].High,sfractal[sftTerm].Low,Format));
      }
    else
      switch (Measure)
      {
        case Now: return(FiboRetrace(sfractal[Type].Resistance,sfractal[Type].Low,Close[sBar],Format));
        case Max: return(FiboRetrace(sfractal[Type].Resistance,sfractal[Type].Low,sfractal[sftTerm].High,Format));
      }
      
    return (0.00);
  }

//+------------------------------------------------------------------+
//| Expansion - Calcuates fibo expansion % for supplied Type         |
//+------------------------------------------------------------------+
double CSession::Expansion(SessionFractalType Type, int Measure, int Format=InDecimal)
  {
    int    fDirection     = sfractal[Type].Direction;

    if (fDirection==DirectionUp)
      switch (Measure)
      {
        case Now: return(FiboExpansion(sfractal[Type].Resistance,sfractal[Type].Support,Close[sBar],Format));
        case Max: if (Type==sftTrend)
                    return(FiboExpansion(sfractal[Type].Resistance,sfractal[Type].Support,sfractal[sftTerm].High,Format));
                      
                  return(FiboExpansion(sfractal[Type].Resistance,sfractal[Type].Support,sfractal[Type].High,Format));
      }
    else
      switch (Measure)
      {
        case Now: return(FiboExpansion(sfractal[Type].Support,sfractal[Type].Resistance,Close[sBar],Format));
        case Max: if (Type==sftTrend)
                    return(FiboExpansion(sfractal[Type].Support,sfractal[Type].Resistance,sfractal[sftTerm].Low,Format));

                  return(FiboExpansion(sfractal[Type].Support,sfractal[Type].Resistance,sfractal[Type].Low,Format));
      }
      
    return (0.00);
  }

//+------------------------------------------------------------------+
//| Fibonacci - Returns precalcuated Fibonacci sequences for Type    |
//+------------------------------------------------------------------+
FiboDetail CSession::Fibonacci(SessionFractalType Type)
  {
    FiboDetail fWork;
    
    fWork.RetraceNow           = Retrace(Type,Now);
    fWork.RetraceMax           = Retrace(Type,Max);
    fWork.ExpansionNow         = Expansion(Type,Now);
    fWork.ExpansionMax         = Expansion(Type,Max);

    if (sfractal[Type].Direction==DirectionUp)
      fWork.Correction         = FiboPrice(Fibo23,sfractal[Type].Support,fmax(sfractal[Type].High,sfractal[Type].Resistance),Retrace);
    else
      fWork.Correction         = FiboPrice(Fibo23,fmax(sfractal[Type].High,sfractal[Type].Resistance),sfractal[Type].Support,Retrace);

    for (FibonacciLevel fibo=FiboRoot;fibo<Fibo100;fibo++)
      if (sfractal[Type].Direction==DirectionUp)
        fWork.Retrace[fibo]    = FiboPrice(fibo,fmax(sfractal[Type].High,sfractal[Type].Resistance),sfractal[Type].Support,Retrace);
      else
        fWork.Retrace[fibo]    = FiboPrice(fibo,sfractal[Type].Support,fmax(sfractal[Type].High,sfractal[Type].Resistance),Retrace);
        
    for (FibonacciLevel fibo=FiboRoot;fibo<Fibo823;fibo++)
      if (sfractal[Type].Direction==DirectionUp)
        fWork.Expansion[fibo]  = FiboPrice(fibo,sfractal[Type].Resistance,sfractal[Type].Support,Expansion);
      else
        fWork.Expansion[fibo]  = FiboPrice(fibo,sfractal[Type].Support,sfractal[Type].Resistance,Expansion);
        
     return (fWork);
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Updates comment with fibonacci data              |
//+------------------------------------------------------------------+
void CSession::RefreshScreen(void)
  {  
    Comment("*---------- "+EnumToString(this.Type())+ " Session Fractal ----------*\n"+
        "Correction: "+EnumToString(sfractal[sftCorrection].State)+" Direction: "+DirText(sfractal[sftCorrection].Direction)+"/"+DirText(sfractal[sftCorrection].BreakoutDir)+"\n"+
        "Term State: "+EnumToString(sfractal[sftTerm].State)+" Direction: "+DirText(sfractal[sftTerm].Direction)+"/"+DirText(sfractal[sftTerm].BreakoutDir)+
                       " (r) "+DoubleToStr(Retrace(sftTerm,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(sftTerm,Max,InPercent),1)+"%"+
                       " (e) "+DoubleToStr(Expansion(sftTerm,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(sftTerm,Max,InPercent),1)+"%\n"+
        "Trend State: "+EnumToString(sfractal[sftTrend].State)+" Direction: "+DirText(sfractal[sftTrend].Direction)+"/"+DirText(sfractal[sftTrend].BreakoutDir)+
                       " (r) "+DoubleToStr(Retrace(sftTrend,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(sftTrend,Max,InPercent),1)+"%"+
                       " (e) "+DoubleToStr(Expansion(sftTrend,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(sftTrend,Max,InPercent),1)+"%\n"+
        "Origin State:  "+EnumToString(sfractal[sftOrigin].State)+" Direction: "+DirText(sfractal[sftOrigin].Direction)+"/"+DirText(sfractal[sftOrigin].BreakoutDir)+
                       " (r) "+DoubleToStr(Retrace(sftOrigin,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(sftOrigin,Max,InPercent),1)+"%"+
                       " (e) "+DoubleToStr(Expansion(sftOrigin,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(sftOrigin,Max,InPercent),1)+"%\n"+
        "\n"+EnumToString(sType)+" Active "+ActiveEventText());
  }

//+------------------------------------------------------------------+
//| FractalStr - Formatted fibonacci data                            |
//+------------------------------------------------------------------+
string CSession::FractalStr(void)
  {  
    return ("*---------- "+EnumToString(this.Type())+ " Session Fractal ----------*\n"+
        "Correction: "+EnumToString(sfractal[sftCorrection].State)+" Direction: "+DirText(sfractal[sftCorrection].Direction)+"/"+DirText(sfractal[sftCorrection].BreakoutDir)+"\n"+
        "Term State: "+EnumToString(sfractal[sftTerm].State)+" Direction: "+DirText(sfractal[sftTerm].Direction)+"/"+DirText(sfractal[sftTerm].BreakoutDir)+
                       " (r) "+DoubleToStr(Retrace(sftTerm,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(sftTerm,Max,InPercent),1)+"%"+
                       " (e) "+DoubleToStr(Expansion(sftTerm,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(sftTerm,Max,InPercent),1)+"%\n"+
        "Trend State: "+EnumToString(sfractal[sftTrend].State)+" Direction: "+DirText(sfractal[sftTrend].Direction)+"/"+DirText(sfractal[sftTrend].BreakoutDir)+
                       " (r) "+DoubleToStr(Retrace(sftTrend,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(sftTrend,Max,InPercent),1)+"%"+
                       " (e) "+DoubleToStr(Expansion(sftTrend,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(sftTrend,Max,InPercent),1)+"%\n"+
        "Origin State:  "+EnumToString(sfractal[sftOrigin].State)+" Direction: "+DirText(sfractal[sftOrigin].Direction)+"/"+DirText(sfractal[sftOrigin].BreakoutDir)+
                       " (r) "+DoubleToStr(Retrace(sftOrigin,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(sftOrigin,Max,InPercent),1)+"%"+
                       " (e) "+DoubleToStr(Expansion(sftOrigin,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(sftOrigin,Max,InPercent),1)+"%\n"+
        "\n"+EnumToString(sType)+" Active "+ActiveEventText());
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

