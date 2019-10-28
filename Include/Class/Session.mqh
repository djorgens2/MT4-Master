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
             //-- Fractal Types
             enum FractalType
             {
               ftOrigin,
               ftTrend,
               ftTerm,
               ftPrior,
               FractalTypes
             };

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
             string        ActiveEventText(const bool WithHeader=true)
                                                            {return (sEvent.ActiveEventText(WithHeader));};
             
             datetime      ServerTime(int Bar=0);
             
             double        Pivot(const PeriodType Type);
             int           Bias(void);
             double        Retrace(FractalType Type, int Measure, int Format=InDecimal);       //--- returns fibonacci retrace
             double        Expansion(FractalType Type, int Measure, int Format=InDecimal);     //--- returns fibonacci expansion

             void          Update(void);
             void          Update(double &OffSessionBuffer[], double &PriorMidBuffer[], double &FractalBuffer[]);
             void          RefreshScreen(void);

             string        SessionText(PeriodType Type);
             
             SessionRec    operator[](const PeriodType Type) {return(srec[Type]);}
             SessionRec    Fractal(const FractalType Type)   {return(sfractal[Type]);}
             
                                 
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
             
             SessionRec    sfractal[FractalTypes];
             int           sBarFE;          //--- Fractal Expansion Bar
             
             //--- Private class collections
             SessionRec    srec[PeriodTypes];
             
             CArrayDouble *sOffMidBuffer;
             CArrayDouble *sPriorMidBuffer;
             CArrayDouble *sFractalBuffer;
             CArrayDouble *sSessionRange;
             
             CEvent       *sEvent;
             
             //--- Private Methods
             void          OpenSession(void);
             void          CloseSession(void);
             void          UpdateSession(void);
                          
             void          UpdateBuffers(void);

             void          LoadHistory(void);
             
             bool          NewDirection(int &Direction, int NewDirection, bool Update=true);
             bool          NewState(ReservedWords &State, ReservedWords NewState, EventType EventTrigger);

             void          UpdateTerm(void);
             void          UpdateTrend(void);
             void          UpdateOrigin(void);
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
        {
          State                    = Correction;
          Print(TimeToStr(Time[sBar])+": Corrected reversal");
        }
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
        case Retrace:     sEvent.SetEvent(NewRetrace);
                          break;
        case Recovery:    sEvent.SetEvent(NewRecovery);
                          break;
        case Resume:      sEvent.SetEvent(NewResume);
                          break;
        case Correction:  sEvent.SetEvent(NewCorrection);
                          break;
      }
      
      return(true);
    }
      
    return(false);
  }

//+------------------------------------------------------------------+
//| UpdateTerm - Updates term fractal bounds and buffers             |
//+------------------------------------------------------------------+
void CSession::UpdateTerm(void)
  {
    int           ufDoubleReversalBar   = NoValue;
    double        ufExpansion           = 0.00;
    ReservedWords ufState               = NoState;
    SessionRec    ufPrior               = sfractal[ftTerm];
    
    //--- Check for term changes
    if (sEvent[NewReversal])
      if (NewDirection(sfractal[ftTerm].Direction,srec[ActiveSession].Direction))
      {
        sBarFE                          = sBar;
        sfractal[ftPrior]               = ufPrior;
        sEvent.SetEvent(NewTerm);        
                
        if (sfractal[ftTerm].Direction==DirectionUp)
        {
          sfractal[ftTerm].Resistance   = srec[PriorSession].High;
          sfractal[ftTerm].Support      = sfractal[ftTerm].Low;
          sfractal[ftTerm].High         = sfractal[ftTerm].Low;   //-- Force NewFractal Event
          sfractal[ftTerm].Low          = Close[sBar];
        }

        if (sfractal[ftTerm].Direction==DirectionDown)
        {
          sfractal[ftTerm].Support      = srec[PriorSession].Low;
          sfractal[ftTerm].Resistance   = sfractal[ftTerm].High;
          sfractal[ftTerm].Low          = sfractal[ftTerm].High;  //-- Force NewFractal Event
          sfractal[ftTerm].High         = Close[sBar];
        }
      }
      else
      {
        //--- occurs on outside reversals; requires analysis
        ufDoubleReversalBar             = sBar;
      }
    
    //--- Check for term boundary changes
    if (sfractal[ftTerm].Direction==DirectionUp)
      if (IsHigher(High[sBar],sfractal[ftTerm].High))
      {
        sEvent.SetEvent(NewFractal);
        sFractalBuffer.Delete(sBarFE);
        sFractalBuffer.Insert(sBar,High[sBar]);

        sfractal[ftTerm].Low            = Close[sBar];
        
        ufExpansion                     = sfractal[ftTerm].High;
        sBarFE                          = sBar;
      }
      else
      if (sBar==0)
        sfractal[ftTerm].Low            = fmin(Close[sBar],sfractal[ftTerm].Low);
      else
        sfractal[ftTerm].Low            = fmin(Low[sBar],sfractal[ftTerm].Low);
            
    if (sfractal[ftTerm].Direction==DirectionDown)
      if (IsLower(Low[sBar],sfractal[ftTerm].Low))
      {
        sEvent.SetEvent(NewFractal);
        sFractalBuffer.Delete(sBarFE);
        sFractalBuffer.Insert(sBar,Low[sBar]);

        sfractal[ftTerm].High           = Close[sBar];

        ufExpansion                     = sfractal[ftTerm].Low;
        sBarFE                          = sBar;
      }
      else
      if (sBar==0)
        sfractal[ftTerm].High           = fmax(Close[sBar],sfractal[ftTerm].High);
      else
        sfractal[ftTerm].High           = fmax(High[sBar],sfractal[ftTerm].High);
      
    if (sEvent[NewFractal])
    {
      if (IsBetween(ufExpansion,sfractal[ftPrior].Support,sfractal[ftPrior].Resistance))
        if (sfractal[ftTerm].Direction==sfractal[ftTerm].BreakoutDir)
          ufState                       = Recovery;
        else
          ufState                       = Retrace;
      else
      if (IsBetween(ufExpansion,sfractal[ftTerm].Support,sfractal[ftTerm].Resistance))
        if (sfractal[ftTerm].Direction==DirectionUp)
          ufState                     = Rally;
        else
          ufState                     = Pullback;
      else
      {
        if (sfractal[ftTerm].Direction==DirectionUp)
        {
          if (IsLower(ufExpansion,sfractal[ftPrior].Support,NoUpdate))
            ufState                   = Rally;
              
          if (IsHigher(ufExpansion,sfractal[ftPrior].Resistance,NoUpdate))
            if (NewDirection(sfractal[ftTerm].BreakoutDir,sfractal[ftTerm].Direction))
              ufState                 = Reversal;
            else
              ufState                 = Breakout;
        }
        else
        {
          if (IsHigher(ufExpansion,sfractal[ftPrior].Resistance,NoUpdate))
            ufState                   = Pullback;

          if (IsLower(ufExpansion,sfractal[ftPrior].Support,NoUpdate))
            if (NewDirection(sfractal[ftTerm].BreakoutDir,sfractal[ftTerm].Direction))
              ufState                 = Reversal;
            else
              ufState                 = Breakout;
        }
      }
      
      if (NewState(sfractal[ftTerm].State,ufState,NewTerm))
        sEvent.SetEvent(NewTermState);
    }
  }

//+------------------------------------------------------------------+
//| UpdateTrend - Updates trend fractal bounds and state             |
//+------------------------------------------------------------------+
void CSession::UpdateTrend(void)
  {
    ReservedWords utState              = sfractal[ftTrend].State;

    //--- Check for trend changes      
    if (sEvent[NewReversal])
      if (sEvent[NewTerm])
      {
        if (sfractal[ftTerm].Direction==DirectionUp)
          sfractal[ftTrend].Support    = sfractal[ftTerm].Support;
        
        if (sfractal[ftTerm].Direction==DirectionDown)
          sfractal[ftTrend].Resistance = sfractal[ftTerm].Resistance;
        
        if (sfractal[ftTerm].Direction==sfractal[ftTrend].Direction)
          utState                      = Recovery;
        else
          utState                      = Retrace;
      }

    //--- Check for trend boundary changes
    if (sfractal[ftTrend].Direction==DirectionUp)
      sfractal[ftTrend].High           = fmax(High[sBar],sfractal[ftTrend].High);

    if (IsHigher(High[sBar],sfractal[ftTrend].Resistance,NoUpdate))
      if (NewDirection(sfractal[ftTrend].Direction,DirectionUp))
      {
        sEvent.SetEvent(NewTrend);

        sfractal[ftTrend].High         = Close[sBar];
        utState                        = Reversal;
      }
      else
      {
        utState                        = Breakout;
        
        if (IsHigher(High[sBar],sfractal[ftOrigin].Resistance,NoUpdate))
          if (NewDirection(sfractal[ftTrend].BreakoutDir,DirectionUp))
            sEvent.SetEvent(NewTrend);
      }

    if (sfractal[ftTrend].Direction==DirectionDown)
      sfractal[ftTrend].Low            = fmin(Low[sBar],sfractal[ftTrend].Low);

    if (IsLower(Low[sBar],sfractal[ftTrend].Support,NoUpdate))
      if (NewDirection(sfractal[ftTrend].Direction,DirectionDown))
      {
        sEvent.SetEvent(NewTrend);
              
        sfractal[ftTrend].Low          = Close[sBar];
        utState                        = Reversal;
      }
      else
      {
        utState                        = Breakout;
        
        if (IsLower(Low[sBar],sfractal[ftOrigin].Support,NoUpdate))
          if (NewDirection(sfractal[ftTrend].BreakoutDir,DirectionDown))
            sEvent.SetEvent(NewTrend);
      }

    if (NewState(sfractal[ftTrend].State,utState,NewTrend))
    {
      if (sfractal[ftTrend].State==Breakout)
        if (NewDirection(sfractal[ftTrend].BreakoutDir,sfractal[ftTrend].Direction))
          sEvent.SetEvent(NewBreakout);
        else
          sEvent.SetEvent(NewExpansion);   //--- Continuation breakout; strong trend

      sEvent.SetEvent(NewTrendState);
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
      if (sfractal[ftTrend].Direction==DirectionDown)
      {
        sfractal[ftOrigin].Resistance   = fmax(sfractal[ftTrend].Resistance,sfractal[ftTrend].High);
        sfractal[ftOrigin].High         = sfractal[ftTrend].Resistance;
      }
      else
      {
        sfractal[ftOrigin].Support      = fmin(sfractal[ftTrend].Support,sfractal[ftTrend].Low);
        sfractal[ftOrigin].Low          = sfractal[ftTrend].Support;
      }
    }

    if (sEvent[NewExpansion])
    {
      if (sfractal[ftTrend].Direction==DirectionDown)
      {
        sfractal[ftOrigin].High         = sfractal[ftTrend].Resistance;
        sfractal[ftOrigin].Low          = sfractal[ftTrend].Low;
      }
      else
      {
        sfractal[ftOrigin].Low          = sfractal[ftTrend].Support;
        sfractal[ftOrigin].High         = sfractal[ftTrend].High;
      }
    }
    
    if (IsHigher(High[sBar],sfractal[ftOrigin].High))
    {
      if (NewDirection(sfractal[ftOrigin].Direction,DirectionUp))
        if (sfractal[ftOrigin].Direction==sfractal[ftOrigin].BreakoutDir)
          uoState                       = Recovery;
        else
          uoState                       = Correction;
        
      if (IsHigher(High[sBar],sfractal[ftOrigin].Resistance,NoUpdate))
        if (NewDirection(sfractal[ftOrigin].BreakoutDir,DirectionUp))
        {
          sEvent.SetEvent(NewOrigin);
          uoState                       = Reversal;
        }
        else
          uoState                       = Breakout;
    }

    if (IsLower(Low[sBar],sfractal[ftOrigin].Low))
    {
      if (NewDirection(sfractal[ftOrigin].Direction,DirectionDown))
        if (sfractal[ftOrigin].Direction==sfractal[ftOrigin].BreakoutDir)
          uoState                       = Recovery;
        else
          uoState                       = Correction;

      if (IsLower(Low[sBar],sfractal[ftOrigin].Support,NoUpdate))
        if (NewDirection(sfractal[ftOrigin].BreakoutDir,DirectionDown))
        {
          sEvent.SetEvent(NewOrigin);
          uoState                       = Reversal;
        }
        else
          uoState                       = Breakout;
    }

    if (uoState==NoState)
    {
      if (FiboLevel(Retrace(ftOrigin,Now))<Fibo23)
        if (sfractal[ftOrigin].State==Retrace)
          uoState                       = Resume;

      if (sfractal[ftOrigin].State==Resume)
        if (FiboLevel(Retrace(ftOrigin,Now))>Fibo23)
          uoState                       = NoState;
        else
          uoState                       = Resume;
                
      if (uoState==NoState)
      {
        if (sfractal[ftOrigin].State!=Retrace)
          if (FiboLevel(Retrace(ftOrigin,Now))>FiboRoot)
            if (sfractal[ftOrigin].Direction==DirectionUp)
              uoState                    = Pullback;
            else
              uoState                    = Rally;

        if (FiboLevel(Retrace(ftOrigin,Now))>Fibo38)
          uoState                        = Retrace;
      }
    }
    
    if (NewState(sfractal[ftOrigin].State,uoState,NewOrigin))
    {
      sEvent.SetEvent(NewOriginState);
      
      if (sBar==0) 
        if (Pause("Origin State Changed to "+EnumToString(uoState),"Origin Check",MB_ICONASTERISK|MB_OKCANCEL)==IDCANCEL)
        {
          int i=0;
          int j = 1/i;
        }
    }
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
    double        usArrowHigh;
    double        usArrowLow;

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
        if (IsLower(srec[ActiveSession].High,sfractal[ftTerm].High,NoUpdate))
          usState                      = Retrace;
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
        if (IsHigher(srec[ActiveSession].Low,sfractal[ftTerm].Low,NoUpdate))
          usState                      = Retrace;
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
    {
      switch (usState)
      {
        case Breakout:   usArrowHigh    = sfractal[ftTerm].High;
                         usArrowLow     = sfractal[ftTerm].Low;
                         usArrow        = BoolToInt(sEvent[NewHigh],SYMBOL_ARROWUP,SYMBOL_ARROWDOWN);
                         break;
        case Reversal:   usArrowHigh    = fmax(srec[PriorSession].High,fmax(Open[sBar],usLastSession.High));
                         usArrowLow     = fmin(srec[PriorSession].Low,fmin(Open[sBar],usLastSession.Low));
                         usArrow        = SYMBOL_CHECKSIGN;
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
    //-- Update Prior Record, range history, and Indicator Buffer
    sSessionRange.Insert(0,srec[ActiveSession].High-srec[ActiveSession].Low);
    
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
    for (int type=0;type<FractalTypes;type++)
      sfractal[type]                 = srec[ActiveSession];

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
    UpdateTerm();
    UpdateTrend();
    UpdateOrigin();
    
//    RefreshScreen();    
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
//| Retrace - Calcuates fibo retrace % for supplied Type             |
//+------------------------------------------------------------------+
double CSession::Retrace(FractalType Type, int Measure, int Format=InDecimal)
  {
    int    fDirection     = sfractal[Type].Direction;

    if (Type==ftOrigin)  //--- Origin computes retrace from its extremities
      if (fDirection==DirectionUp)
        switch (Measure)
        {
          case Now: return(FiboRetrace(sfractal[Type].Support,fmax(sfractal[Type].High,sfractal[Type].Resistance),Close[sBar],Format));
          case Max: return(FiboRetrace(sfractal[Type].Support,fmax(sfractal[Type].High,sfractal[Type].Resistance),sfractal[ftTerm].Low,Format));
        }
      else
        switch (Measure)
        {
          case Now: return(FiboRetrace(sfractal[Type].Resistance,fmin(sfractal[Type].Low,sfractal[Type].Support),Close[sBar],Format));
          case Max: return(FiboRetrace(sfractal[Type].Resistance,fmin(sfractal[Type].Low,sfractal[Type].Support),sfractal[ftTerm].High,Format));
        }
    else  
    if (fDirection==DirectionUp)
      switch (Measure)
      {
        case Now: return(FiboRetrace(sfractal[Type].Support,sfractal[Type].High,Close[sBar],Format));
        case Max: return(FiboRetrace(sfractal[Type].Support,sfractal[Type].High,sfractal[ftTerm].Low,Format));
      }
    else
      switch (Measure)
      {
        case Now: return(FiboRetrace(sfractal[Type].Resistance,sfractal[Type].Low,Close[sBar],Format));
        case Max: return(FiboRetrace(sfractal[Type].Resistance,sfractal[Type].Low,sfractal[ftTerm].High,Format));
      }
      
    return (0.00);
  }

//+------------------------------------------------------------------+
//| Expansion - Calcuates fibo expansion % for supplied Type         |
//+------------------------------------------------------------------+
double CSession::Expansion(FractalType Type, int Measure, int Format=InDecimal)
  {
    int    fDirection     = sfractal[Type].Direction;

    if (fDirection==DirectionUp)
      switch (Measure)
      {
        case Now: return(FiboExpansion(sfractal[Type].Resistance,sfractal[Type].Support,Close[sBar],Format));
        case Max: if (Type==ftTrend)
                    return(FiboExpansion(sfractal[Type].Resistance,sfractal[Type].Support,sfractal[ftTerm].High,Format));
                      
                  return(FiboExpansion(sfractal[Type].Resistance,sfractal[Type].Support,sfractal[Type].High,Format));
      }
    else
      switch (Measure)
      {
        case Now: return(FiboExpansion(sfractal[Type].Support,sfractal[Type].Resistance,Close[sBar],Format));
        case Max: if (Type==ftTrend)
                    return(FiboExpansion(sfractal[Type].Support,sfractal[Type].Resistance,sfractal[ftTerm].Low,Format));

                  return(FiboExpansion(sfractal[Type].Support,sfractal[Type].Resistance,sfractal[Type].Low,Format));
      }
      
    return (0.00);
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Updates comment with fibonacci data              |
//+------------------------------------------------------------------+
void CSession::RefreshScreen(void)
  {  
    Comment("Prior State: "+EnumToString(sfractal[ftPrior].State)+" Direction: "+DirText(sfractal[ftPrior].Direction)+"/"+DirText(sfractal[ftPrior].BreakoutDir)+"\n"+
        "Term State: "+EnumToString(sfractal[ftTerm].State)+" Direction: "+DirText(sfractal[ftTerm].Direction)+"/"+DirText(sfractal[ftTerm].BreakoutDir)+
                       " (r) "+DoubleToStr(Retrace(ftTerm,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(ftTerm,Max,InPercent),1)+"%"+
                       " (e) "+DoubleToStr(Expansion(ftTerm,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(ftTerm,Max,InPercent),1)+"%\n"+
        "Trend State: "+EnumToString(sfractal[ftTrend].State)+" Direction: "+DirText(sfractal[ftTrend].Direction)+"/"+DirText(sfractal[ftTrend].BreakoutDir)+
                       " (r) "+DoubleToStr(Retrace(ftTrend,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(ftTrend,Max,InPercent),1)+"%"+
                       " (e) "+DoubleToStr(Expansion(ftTrend,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(ftTrend,Max,InPercent),1)+"%\n"+
        "Origin State:  "+EnumToString(sfractal[ftOrigin].State)+" Direction: "+DirText(sfractal[ftOrigin].Direction)+"/"+DirText(sfractal[ftOrigin].BreakoutDir)+
                       " (r) "+DoubleToStr(Retrace(ftOrigin,Now,InPercent),1)+"%  "+DoubleToStr(Retrace(ftOrigin,Max,InPercent),1)+"%"+
                       " (e) "+DoubleToStr(Expansion(ftOrigin,Now,InPercent),1)+"%  "+DoubleToStr(Expansion(ftOrigin,Max,InPercent),1)+"%\n");
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
