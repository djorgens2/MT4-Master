//+------------------------------------------------------------------+
//|                                                  fractal_lib.mqh |
//|                                                 Dennis Jorgenson |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property strict

#include <stdutil.mqh>
#include <Class/Event.mqh>

#define FiboCorrection   0.764
#define FiboRetrace      0.500
#define FiboRecovery     0.236

  //--- Public fractal enums
  enum             FractalState       // Fractal States
                   {
                     NoState,         // No State Assignment
                     Rally,           // Advancing fractal
                     Pullback,        // Declining fractal
                     Retrace,         // Pegged retrace (>Rally||Pullack)
                     Correction,      // Fractal max stress point/Market Correction
                     Recovery,        // Trend resumption post-correction
                     Breakout,        // Fractal Breakout
                     Reversal,        // Fractal Reversal
                     FractalStates
                   };
  
  enum             FractalPoint       // Fractal Price Points
                   {
                     fpOrigin,        // Origin
                     fpBase,          // Base
                     fpRoot,          // Root
                     fpExpansion,     // Expansion
                     fpRetrace,       // Retrace
                     fpRecovery,      // Recovery
                     FractalPoints    // All Points
                   };

  enum             FractalType        // Fractal Type
                   {
                     //-- Geometric Types
                     Origin,
                     Trend,
                     Term,
                     Prior,
                     Base,
                     Root,
                     Expansion,
                     //-- Linear Types
                     Divergent,
                     Convergent,
                     Inversion,
                     Conversion,
                     Lead,
                     FractalTypes     // None
                   };

  enum             PivotType
                   {
                     Support,
                     Resistance
                   };

  enum             FiboLevel
                   {
                     FiboRoot,
                     Fibo23,
                     Fibo38,
                     Fibo50,
                     Fibo61,
                     Fibo100,
                     Fibo161,
                     Fibo261,
                     Fibo423,
                     Fibo823,
                     FiboLevels
                   };             

  //-- Canonical Fractal Rec
  struct FractalRec
         {
           int           Direction;                //-- Direction based on Last Breakout/Reversal (Trend)
           int           Lead;                     //-- Bias based on Last Pivot High/Low hit
           int           Bias;                     //-- Active Bias derived from Close[] to Pivot.Open  
           FractalState  State;                    //-- State
           EventType     Event;                    //-- Current Tick Event; disposes on next tick
           double        Price;                    //-- Last Pivot Price
           bool          Peg;                      //-- Retrace peg
           bool          Trap;                     //-- Trap flag (not yet implemented)
           double        Point[FractalPoints];     //-- Fractal Points (Prices)
         };

  //-- Canonical Pivot Rec
  struct PivotRec
         {
           int           Direction;                //-- Direction [Immutable, once assigned]
           FractalState  State;                    //-- State [Immutable, once assigned]
           int           Lead;                     //-- Action set by last NewHigh/NewLow event
           int           Bias;                     //-- Action set by Close[] - Pivot.Open
           EventType     Event;                    //-- Current Tick Event; disposes on next tick
           datetime      Time;                     //-- Pivot Open Time
           double        Open;                     //-- Open Price set on NewPivot [Immutable, once assigned]
           double        High;                     //-- Updated on NewHigh
           double        Low;                      //-- Updated on NewLow
           double        Close;                    //-- Updated on Update [once per tick]
         };

  //-- Canonical Fibonacci Pivot
  struct FibonacciRec
         {
           PivotRec      Pivot;                    //-- Fractal Pivot
           FiboLevel     Level;                    //-- Fibo Level Now
           double        Percent;                  //-- Actual Fibonacci Percentage
           double        Forecast;                 //-- Calculated Fibonacci Price
         };

static const string    FractalTag[FractalTypes]     = {"(o)","(tr)","(tm)","(p)","(b)","(r)","(e)","(d)","(c)","(iv)","(cv)","(l)"};

//+------------------------------------------------------------------+
//| Color - Returns the color assigned to a specific Fractal Event   |
//+------------------------------------------------------------------+
color Color(FractalState State)
  {
    static const color  statecolor[FractalStates]  = {clrNONE,clrGreen,clrFireBrick,clrGoldenrod,clrWhite,clrSteelBlue,clrYellow,clrRed};

    return statecolor[State];
  }

//+------------------------------------------------------------------+
//| Color - Returns the color assigned to a specific Fractal Type    |
//+------------------------------------------------------------------+
color Color(FractalType Type)
  {
    static const color     fractalcolor[FractalTypes]  = {clrWhite,clrRed,clrRed,clrDarkGray,clrYellow,clrForestGreen,clrFireBrick,clrGoldenrod,clrSteelBlue,clrGoldenrod,clrSteelBlue,clrDarkGray};

    return fractalcolor[Type];
  }

//+------------------------------------------------------------------+
//| Color - Returns the color assigned to a specific Fractal Point   |
//+------------------------------------------------------------------+
color Color(FractalPoint Fractal)
  {
    static const color     fractalcolor[FractalPoints]  = {clrWhite,clrYellow,clrForestGreen,clrFireBrick,clrGoldenrod,clrSteelBlue};

    return fractalcolor[Fractal];
  }

//+------------------------------------------------------------------+
//| Style - Returns the linestyle assigned to a specific Fractal Type|
//+------------------------------------------------------------------+
ENUM_LINE_STYLE Style(FractalType Type)
  {
    static const ENUM_LINE_STYLE style[FractalTypes]   = {STYLE_SOLID,STYLE_SOLID,STYLE_DASH,STYLE_DOT,STYLE_SOLID,STYLE_SOLID,STYLE_SOLID,STYLE_SOLID,STYLE_SOLID,STYLE_DOT,STYLE_DOT,STYLE_SOLID};

    return style[Type];
  }

//+------------------------------------------------------------------+
//| Style - Returns linestyle for supplie Fractal Point              |
//+------------------------------------------------------------------+
ENUM_LINE_STYLE Style(FractalPoint Fractal)
  {
    static const ENUM_LINE_STYLE style[FractalPoints]  = {STYLE_SOLID,STYLE_SOLID,STYLE_DASH,STYLE_SOLID,STYLE_DOT,STYLE_DOT};

    return style[Fractal];
  }

//+------------------------------------------------------------------+
//| FractalAlert - Returns Alert Level for supplied Fractal Type     |
//+------------------------------------------------------------------+
AlertLevel FractalAlert(FractalType Type)
  {
    static const AlertLevel alertlevel[FractalTypes]    = {Critical,Major,Minor,Nominal,Warning,Nominal,Warning,Notify,Notify,Notify,Notify,Notify};

    return alertlevel[Type];
  }

//+------------------------------------------------------------------+
//| FractalEvent - Returns the Fractal Event on change in State      |
//+------------------------------------------------------------------+
EventType FractalEvent(FractalState State)
  {
    static const EventType FractalEvent[FractalStates]  = {NoEvent,NewRally,NewPullback,NewRetrace,NewCorrection,NewRecovery,NewBreakout,NewReversal};
  
    return (FractalEvent[State]);
  }

//+------------------------------------------------------------------+
//| FractalEvent - Returns the Fractal Event on change in Type       |
//+------------------------------------------------------------------+
EventType FractalEvent(FractalType Type)
  {
    switch (Type)
    {
      case Origin:       return(NewOrigin);
      case Trend:        return(NewTrend);
      case Term:         return(NewTerm);
      case Base:         return(NewBase);
      case Expansion:    return(NewExpansion);
      case Divergent:    return(NewDivergence);
      case Convergent:   return(NewConvergence);
      case Inversion:    return(NewInversion);
      case Conversion:   return(NewConversion);
      case Lead:         return(NewLead);
    };
    
    return (NoEvent);
  }

//+------------------------------------------------------------------+
//| Level - Returns the FiboLevel based on extended fibonacci        |
//+------------------------------------------------------------------+
FiboLevel Level(double Percent)
  {
    for (FiboLevel level=Fibo823;level>FiboRoot;level--)
      if (fabs(Percent)>Percent(level))
        return (level);

    return (FiboRoot);
  }

//+------------------------------------------------------------------+
//| Price - Returns price for supplied fibonacci level               |
//+------------------------------------------------------------------+
double Price(FiboLevel Level, double Root, double Reference, int Method)
  {
    if (Method == Retrace)     
      return (NormalizeDouble(Reference-((Reference-Root)*Percent(Level)),Digits));

    return (NormalizeDouble(Root+((Reference-Root)*Percent(Level)),Digits));
  }

//+------------------------------------------------------------------+
//| Price - Returns price for supplied Bar, Direction, Fractal State |
//+------------------------------------------------------------------+
double Price(FractalState State, int Direction, int Bar)
  {
    double price          = NoValue;

    if (IsEqual(Bar,0))
      price               = Close[0];
    else
    
    //--- Note: Not perfect - long bar historical pricing (retrace, correction, rally/pullback(On Close?) missing;
    if (IsEqual(State,Rally))
      price               = BoolToDouble(IsEqual(Direction,DirectionUp),High[Bar],Close[Bar],Digits);
    else
    if (IsEqual(State,Pullback))
      price               = BoolToDouble(IsEqual(Direction,DirectionUp),Close[Bar],Low[Bar],Digits);
    else
    if (IsBetween(State,Retrace,Correction))
      price               = BoolToDouble(IsEqual(Direction,DirectionUp),Low[Bar],Close[Bar],Digits);
    else
    if (IsBetween(State,Recovery,Reversal))
      price               = BoolToDouble(IsEqual(Direction,DirectionUp),High[Bar],Close[Bar],Digits);

    return NormalizeDouble(price,Digits);
  }

//+------------------------------------------------------------------+
//| Expansion - returns the Fibo expansion for supplied points       |
//+------------------------------------------------------------------+
double Expansion(double Base, double Root, double Expansion, int Format=InDecimal)
  {
    double feExpansion    = fdiv(fabs(Expansion-Root),fabs(Base-Root),3);

    switch (Format)
    {
      case InDecimal:    return (NormalizeDouble(feExpansion,3));
      case InPercent:    return (NormalizeDouble(feExpansion*100,3));
    }
            
    return(0.00);
  }

//+------------------------------------------------------------------+
//| Retrace - returns the linear Fibo retrace for supplied points    |
//+------------------------------------------------------------------+
double Retrace(double Root, double Expansion, double Retrace, int Format=InDecimal)
  {
    double frRetrace      = fdiv(fabs(Expansion-Retrace),fabs(Expansion-Root),3);

    switch (Format)
    {
      case InDecimal:    return (NormalizeDouble(frRetrace,3));
      case InPercent:    return (NormalizeDouble(frRetrace*100,3));
    }
            
    return(0.00);
  }

//+------------------------------------------------------------------+
//| Percent - returns the Fibo percent for the supplied level        |
//+------------------------------------------------------------------+
double Percent(FiboLevel Level, int Format=InPoints)
  {
    const double percent[FiboLevels] = {0.00,0.236,0.382,0.500,0.618,1.0,1.618,2.618,4.236,8.236};

    if (IsBetween(Level,FiboRoot,Fibo823))
      return (BoolToDouble(IsEqual(Format,InPoints),percent[Level],percent[Level]*100,3));

    return (NoValue);
  }

//+------------------------------------------------------------------+
//| UpdatePivot - updates Pivot details on the tick                  |
//+------------------------------------------------------------------+
void UpdatePivot(PivotRec &Pivot, int Direction, int Bar=0)
  {
    double price        = Price(Pivot.State,Direction,Bar);
    
    Pivot.Close         = price;
    Pivot.Event         = BoolToEvent(NewBias(Pivot.Bias,Action(price-Pivot.Open)),NewBias);
    
    if (IsHigher(price,Pivot.High))
      Pivot.Event       = NewHigh;

    if (IsLower(price,Pivot.Low))
      Pivot.Event       = NewLow;

    if (Pivot.Event>NoEvent)
      if (NewAction(Pivot.Lead,BoolToInt(IsEqual(Pivot.Event,NewHigh),OP_BUY,OP_SELL)))
        Pivot.Event     = NewLead;
  }

//+------------------------------------------------------------------+
//| GetPivot - Returns requested Pivot for supplied State from Start |
//+------------------------------------------------------------------+
PivotRec GetPivot(PivotRec &Pivot[], FractalState State, int Start=0, MeasureType Measure=Now)
  {
    PivotRec pivot       = {NoDirection,NoState,NoAction,NoBias,NoEvent,NoValue,NoValue,NoValue,NoValue,NoValue};

    int      size        = ArraySize(Pivot);
    double   low,high;
    
    if (size>Start)
    {
      pivot              = Pivot[0];
      
      for (int node=Start;node<size;node++)
      {
        if (IsEqual(Measure,Now))
          pivot          = Pivot[node];
        else
        {
          if (IsEqual(Measure,Max))
          {
            low          = fmin(pivot.Low,Pivot[node].Low);
            high         = fmax(pivot.High,Pivot[node].High);
          }
          else
          {
            low          = fmax(pivot.Low,Pivot[node].Low);
            high         = fmin(pivot.High,Pivot[node].High);
          }

          pivot          = Pivot[node];
          pivot.Low      = low;
          pivot.High     = high;
        }

        if (IsEqual(State,Pivot[node].State))
          return pivot;

        if (IsEqual(Pivot[node].State,Reversal))
          if (IsEqual(State,Breakout))
            return pivot;
      }
    }

    return pivot;
  }

//+------------------------------------------------------------------+
//| NewPivot - Inserts a new Fractal Pivot record                    |
//+------------------------------------------------------------------+
void NewPivot(PivotRec &Pivot[], double Price, FractalState State, int Direction, int Bar)
  {
    int      size            = ArraySize(Pivot);

    ArrayResize(Pivot,size+1,32768);
    
    if (size>0)
    {
      ArrayCopy(Pivot,Pivot,1,0,size);
      
      Pivot[0].Direction     = Direction(Price-Pivot[1].Open);
    }
    else Pivot[0].Direction  = NoDirection;

    Direction                = BoolToInt(IsEqual(State,Retrace),Direction(Direction,InDirection,InContrarian),Direction);

    Pivot[0].Bias            = Action(Direction);
    Pivot[0].State           = State;
    Pivot[0].Time            = BoolToDate(IsEqual(Bar,0),TimeCurrent(),Time[Bar]);
    Pivot[0].Open            = Price;
    Pivot[0].High            = BoolToDouble(IsEqual(Direction,DirectionUp),High[Bar],Price(State,Direction,Bar),Digits);
    Pivot[0].Low             = BoolToDouble(IsEqual(Direction,DirectionUp),Price(State,Direction,Bar),Low[Bar],Digits);
    Pivot[0].Close           = Close[Bar];
  }

//+------------------------------------------------------------------+
//| NewState - Returns true on change to a Fractal State             |
//+------------------------------------------------------------------+
bool NewState(FractalRec &Fractal, PivotRec &Pivot[], int Bar, bool Reversing, bool Update=true, bool Force=true)
  {
    FractalRec frec          = Fractal;
    frec.Event               = NoEvent;
    
    double     retrace       = Retrace(Fractal.Point[fpRoot],Fractal.Point[fpExpansion],Fractal.Point[fpRetrace]);

    //-- Handle Reversals
    if (Reversing)
    {
      frec.State             = Reversal;
      frec.Price             = Fractal.Point[fpBase];
      frec.Peg               = false;
    }

    //-- Handle Correction/Recovery
    else    
    if (retrace>FiboCorrection)
      if (Retrace(Fractal.Point[fpRoot],Fractal.Point[fpExpansion],Fractal.Point[fpRecovery])<FiboRecovery)
      {
        frec.State           = Recovery;
        frec.Price           = Price(Fibo23,Fractal.Point[fpRoot],Fractal.Point[fpExpansion],Retrace);
      }
      else
      {
        frec.State           = Correction;
        frec.Price           = Price(Fibo23,Fractal.Point[fpExpansion],Fractal.Point[fpRoot],Retrace);
      }
    else

    //-- Handle Retraces
    if (retrace>FiboRetrace)
    {
      frec.State             = NoState;

      if (IsEqual(Fractal.Point[fpRetrace],BoolToDouble(IsEqual(Bar,0),Fractal.Point[fpRecovery],
                               BoolToDouble(IsEqual(Fractal.Direction,DirectionUp),fmin(Fractal.Point[fpRecovery],Low[Bar]),
                                                                                   fmax(Fractal.Point[fpRecovery],High[Bar])),Digits)))
      {
        frec.State           = Retrace;
        frec.Price           = BoolToDouble(IsChanged(frec.Peg,true),Price(Fibo50,Fractal.Point[fpExpansion],Fractal.Point[fpRoot],Retrace),
                               BoolToDouble(IsEqual(Fractal.Direction,DirectionUp),GetPivot(Pivot,Retrace,0).Low,GetPivot(Pivot,Retrace,0).High),Digits);
      }
      else
      if (IsEqual(Fractal.Point[fpRecovery],BoolToDouble(IsEqual(Fractal.Direction,DirectionUp),High[Bar],Low[Bar]),Digits))
      {
        if (Retrace(Fractal.Point[fpExpansion],Fractal.Point[fpRetrace],Fractal.Point[fpRecovery])>FiboRetrace&&
           ((IsEqual(Fractal.Direction,DirectionUp)&&Fractal.Point[fpRecovery]>fmax(Fractal.Point[fpBase],GetPivot(Pivot,Breakout,0).High))||
            (IsEqual(Fractal.Direction,DirectionDown)&&Fractal.Point[fpRecovery]<fmin(Fractal.Point[fpBase],GetPivot(Pivot,Breakout,0).Low))))
        {
          frec.State         = Breakout;
          frec.Price         = BoolToDouble(IsEqual(GetPivot(Pivot,Breakout,0).State,Reversal),GetPivot(Pivot,Breakout,0).Open,
                               BoolToDouble(IsEqual(Fractal.Direction,DirectionUp),GetPivot(Pivot,Breakout,0).High,GetPivot(Pivot,Breakout,0).Low),Digits);
          frec.Peg           = false;
        }
        else
        if (Retrace(Fractal.Point[fpExpansion],Fractal.Point[fpRetrace],Fractal.Point[fpRecovery])>FiboRecovery)
        {
          if (IsEqual(Fractal.State,Retrace))
          {
            frec.State       = (FractalState)BoolToInt(IsEqual(Fractal.Direction,DirectionUp),Rally,Pullback);
            frec.Price       = Price(Fibo23,Fractal.Point[fpExpansion],Fractal.Point[fpRetrace],Retrace);
          }
        }
      }
      else
      if (Retrace(Fractal.Point[fpRoot],Fractal.Point[fpExpansion],Fractal.Point[fpRecovery])<FiboRecovery)
        if (Retrace(Fractal.Point[fpRetrace],Fractal.Point[fpRecovery],BoolToDouble(IsEqual(Fractal.Direction,DirectionUp),Low[Bar],High[Bar],Digits))>FiboRetrace)
        {
          frec.State         = (FractalState)BoolToInt(IsEqual(Fractal.Direction,DirectionUp),Pullback,Rally);
          frec.Price         = Price(Fibo50,Fractal.Point[fpRetrace],Fractal.Point[fpRecovery],Retrace);
        }
    }
    else

    //-- Handle Rally/Pullback after Breakout/Reversal
    if (retrace>FiboRecovery)
    {
      frec.State             = (FractalState)BoolToInt(IsEqual(Fractal.Direction,DirectionUp),Pullback,Rally);
      frec.Price             = Price(Fibo23,Fractal.Point[fpRoot],Fractal.Point[fpExpansion],Retrace);
    }
    else

    //-- Handle Breakout
    {
      frec.State             = Breakout;
      frec.Price             = BoolToDouble(IsEqual(Fractal.Direction,DirectionUp),GetPivot(Pivot,Breakout,0).High,GetPivot(Pivot,Breakout,0).Low,Digits);
      frec.Peg               = false;
    }

    if (NewState(Fractal.State,frec.State,Update,Force))
    {
      NewPivot(Pivot,frec.Price,frec.State,frec.Direction,Bar);

      frec.Event             = FractalEvent(frec.State);
      Fractal                = frec;

      return true;
    }

    UpdatePivot(Pivot[0],Fractal.Direction,Bar);
    
    if (Bar>0)
    {
      Fractal.Lead           = BoolToInt(IsHigher(High[Bar],Pivot[0].High),OP_BUY,Fractal.Lead);
      Fractal.Lead           = BoolToInt(IsLower(Low[Bar],Pivot[0].Low),OP_SELL,Fractal.Lead);
    } 
    else Fractal.Lead        = Pivot[0].Lead;
    
    Fractal.Bias             = Pivot[0].Bias;

    return false;
  }

//+------------------------------------------------------------------+
//| NewState - Returns true on change to a Fractal State             |
//+------------------------------------------------------------------+
bool NewState(FractalState &State, FractalState Change, bool Update=true, bool Force=false)
  {
    if (Change==NoState)
      return(false);

    if (Change==Breakout)
      if (State==Reversal)
        return(false);

    if (Change==Reversal&&State==Reversal)
      return(true);

    if (State==Correction)
      if (Change==Reversal||Change==Breakout||Change==Recovery)
        return(IsChanged(State,Change,Update));
      else return(false);

    if (Change==Recovery)
      return (false);

    if (State==Retrace)
      if (Force||Change==Reversal||Change==Breakout||Change==Correction)
        return(IsChanged(State,Change,Update));
      else return(false);

    return(IsChanged(State,Change,Update));
  }

//+------------------------------------------------------------------+
//| NewBias - Returns true on bias change; Force allows NoBias       |
//+------------------------------------------------------------------+
bool NewBias(int &Check, int Change, bool Force=false)
  {
    if (IsBetween(Change,NoBias,OP_SELL))
    {
      if (Force)
        return IsChanged(Check,Change);

      if (IsEqual(Change,NoBias))
        return false;

      return IsChanged(Check,Change);
    }
    
    return false;
  }

//+------------------------------------------------------------------+
//| NewFibonacci - Returns refreshed Fibo rec                        |
//+------------------------------------------------------------------+
bool NewFibonacci(FractalRec &Fractal, FibonacciRec &Fibo, int Method=Expansion, int Bar=0)
  {
    double  fibo             = BoolToDouble(IsEqual(Method,Expansion),
                                 Expansion(Fractal.Point[fpBase],Fractal.Point[fpRoot],Fractal.Point[fpExpansion]),
                                 Retrace(Fractal.Point[fpRoot],Fractal.Point[fpExpansion],Fractal.Point[fpRetrace]),Digits);

    Fibo.Pivot.Event         = NoEvent;
    
    if (IsChanged(Fibo.Level,Level(fibo)))
    {
      Fractal.Event          = NewFibonacci;

      Fibo.Percent           = fibo;
      Fibo.Forecast          = Price(Fibo.Level,Fractal.Point[fpRoot],BoolToDouble(IsEqual(Method,Expansion),Fractal.Point[fpBase],Fractal.Point[fpExpansion]),Method);
  
      Fibo.Pivot.Event       = NewFibonacci;
      Fibo.Pivot.Direction   = Fractal.Direction;
      Fibo.Pivot.State       = Fractal.State;
      Fibo.Pivot.Lead        = Action(Fractal.Direction);
      Fibo.Pivot.Bias        = Action(Fractal.Direction);
      Fibo.Pivot.Time        = BoolToDate(IsEqual(Bar,0),TimeCurrent(),Time[Bar]);
      Fibo.Pivot.Open        = BoolToDouble(IsEqual(Bar,0),Close[0],Fibo.Forecast,Digits);
      Fibo.Pivot.High        = BoolToDouble(IsEqual(Fractal.Direction,DirectionUp),High[Bar],fmax(Close[Bar],Fibo.Forecast),Digits);
      Fibo.Pivot.Low         = BoolToDouble(IsEqual(Fractal.Direction,DirectionUp),fmin(Close[Bar],Fibo.Forecast),Low[Bar],Digits);
      Fibo.Pivot.Close       = Price(Fractal.State,Fractal.Direction,Bar);

      return true;
    }

    UpdatePivot(Fibo.Pivot,Fractal.Direction,Bar);

    return false;
  }

//+------------------------------------------------------------------+
//| IsLower - returns true if compare value lower than check         |
//+------------------------------------------------------------------+
bool IsLower(FiboLevel Compare, FiboLevel &Check, bool Update=true)
  {
    if (Compare < Check)
    {
      if (Update)
        Check    = Compare;

      return (true);
    }
    
    return (false);
  }

//+------------------------------------------------------------------+
//| IsHigher - returns true if compare value higher than check       |
//+------------------------------------------------------------------+
bool IsHigher(FiboLevel Compare, FiboLevel &Check, bool Update=true)
  {
    if (Compare > Check)
    {
      if (Update)
        Check    = Compare;

      return (true);
    }
    
    return (false);
  }

//+------------------------------------------------------------------+
//| IsChanged - Compares FractalStates to detect changes             |
//+------------------------------------------------------------------+
bool IsChanged(FractalState &Check, FractalState Change, bool Update=true)
  {
    if (IsEqual(Check,Change))
      return (false);
      
    if (Update)
      Check      = Change;

    return (true);
  }

//+------------------------------------------------------------------+
//| IsChanged - Compares FiboLevels to detect changes                |
//+------------------------------------------------------------------+
bool IsChanged(FiboLevel &Compare, FiboLevel Value)
  {
    if (Compare==Value)
      return (false);
      
    Compare = Value;
    return (true);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(FractalType &Check, FractalType Change, bool Update=true)
  {
    if (IsEqual(Check,Change))
      return (false);
      
    if (Update)
      Check      = Change;

    return (true);
  }
