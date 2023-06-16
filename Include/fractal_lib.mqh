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
                     Extension,       // Fibonacci Extension
                     Flatline,        // Horizontal Trade/Idle market
                     Consolidation,   // Consolidating Range
                     Parabolic,       // Parabolic Expansion
                     Channel,         // Congruent Price Channel
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
                     Mean,
                     Support,
                     Resistance,
                     Active,
                     PivotTypes
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

  //-- Canonical Pivot Rec
  struct PivotRec
         {
           int           Direction;                //-- Direction [Immutable, once assigned]
           FractalState  State;                    //-- State [Immutable, once assigned]
           int           Lead;                     //-- Action set by last NewHigh/NewLow event
           int           Bias;                     //-- Action set by Close[] - Pivot.Open
           EventType     Event;                    //-- Current Tick Event; disposes on next tick
           double        Open;                     //-- Open Price set on NewPivot [Immutable, once assigned]
           double        High;                     //-- Updated on NewHigh
           double        Low;                      //-- Updated on NewLow
           double        Close;                    //-- Updated on Update [once per tick]
           datetime      Time;                     //-- Pivot Open Time
         };

  //-- Canonical Fibonacci Pivot
  struct FibonacciRec
         {
           FiboLevel     Level;                    //-- Fibo Level Now
           double        Percent;                  //-- Actual Fibonacci Percentage
           double        Forecast;                 //-- Calculated Fibonacci Price
         };

  //-- Canonical Fractal Rec
  struct FractalRec
         {
           FractalType   Type;                     //-- Type
           FractalState  State;                    //-- State
           int           Direction;                //-- Direction based on Last Breakout/Reversal (Trend)
           double        Price;                    //-- Event Price
           EventType     Event;                    //-- Last Event; disposes on next tick
           AlertLevel    Alert;                    //-- Last Alert; disposes on next tick
           bool          Peg;                      //-- Retrace peg
           FibonacciRec  Extension;                //-- Active Fibo Extension
           FibonacciRec  Retrace;                  //-- Active Fibo Retrace
           datetime      Updated;                  //-- Last Update;
           double        Point[FractalPoints];     //-- Fractal Points (Prices)
         };

static const string    FractalTag[FractalTypes]     = {"(o)","(tr)","(tm)","(p)","(b)","(r)","(e)","(d)","(c)","(iv)","(cv)","(l)"};

//+------------------------------------------------------------------+
//| Color - Returns the color assigned to a specific Fractal Event   |
//+------------------------------------------------------------------+
color Color(FractalState State)
  {
    static const color  statecolor[FractalStates]  = {clrNONE,clrGreen,clrFireBrick,clrGoldenrod,clrWhite,clrSteelBlue,clrYellow,clrRed,clrSkyBlue,clrNONE,clrNONE,clrNONE,clrNONE};

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
AlertLevel Alert(FractalType Type)
  {
    static const AlertLevel alertlevel[FractalTypes]    = {Critical,Major,Minor,Nominal,Warning,Nominal,Warning,Notify,Notify,Notify,Notify,Notify};

    return alertlevel[Type];
  }

//+------------------------------------------------------------------+
//| FractalEvent - Returns the Fractal Event on change in State      |
//+------------------------------------------------------------------+
EventType Event(FractalState State)
  {
    static const EventType FractalEvent[FractalStates]  = {NoEvent,NewRally,NewPullback,NewRetrace,NewCorrection,NewRecovery,NewBreakout,NewReversal,NewExtension,NewFlatline,NewConsolidation,NewParabolic,NewChannel};
  
    return (FractalEvent[State]);
  }

//+------------------------------------------------------------------+
//| FractalEvent - Returns the Fractal Event on change in Type       |
//+------------------------------------------------------------------+
EventType Event(FractalType Type)
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
//| Price - Returns price from supplied level, Root/[Base|Expansion] |
//+------------------------------------------------------------------+
double Price(FiboLevel Level, double Root, double Reference, FractalState Method)
  {
    switch (Method)
    {
      case Retrace:   return NormalizeDouble(Reference-((Reference-Root)*Percent(Level)),Digits);
      case Extension: return NormalizeDouble(Root+((Reference-Root)*Percent(Level)),Digits);
      default:        return NoValue;
    }
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
    if (IsBetween(State,Recovery,Extension))
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
//| Bias - returns the fractal bias from supplied state/direction    |
//+------------------------------------------------------------------+
int Bias(int Direction, FractalState State)
  {
    switch (State)
    {
      case Parabolic:       // Parabolic Expansion
      case Channel:         // Congruent Price Channel
      case Recovery:
      case Breakout:
      case Reversal:
      case Extension:   return Action(Direction);
      case Rally:       return OP_BUY;
      case Pullback:    return OP_SELL;
      case Retrace:
      case Correction:  return Action(Direction,InDirection,InContrarian);
    }

    return NoBias;
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
//| UpdatePivot - updates active Pivot on the stack each tick        |
//+------------------------------------------------------------------+
void UpdatePivot(PivotRec &Pivot[], int Direction, int Bar=0)
  {
    double price;
    int    size      = ArraySize(Pivot);
    
    for (int node=0;node<size;node++)
    {
      Pivot[node].Event          = NoEvent;

      if (IsEqual(node,0)||IsBetween(Pivot[node].State,Breakout,Reversal))
      {
        price                    = Price(Pivot[node].State,Direction,Bar);
    
        Pivot[node].Close       = price;
        Pivot[node].Event       = BoolToEvent(NewBias(Pivot[node].Bias,Action(price-Pivot[node].Open)),NewBias);
    
        if (IsHigher(price,Pivot[node].High))
          Pivot[node].Event     = NewHigh;

        if (IsLower(price,Pivot[node].Low))
          Pivot[node].Event     = NewLow;

        if (Pivot[node].Event>NoEvent)
          if (NewAction(Pivot[node].Lead,BoolToInt(IsEqual(Pivot[node].Event,NewHigh),OP_BUY,BoolToInt(IsEqual(Pivot[node].Event,NewLow),OP_SELL,Pivot[node].Lead))))
            Pivot[node].Event   = NewLead;
      }
      
      if (IsBetween(Pivot[node].State,Breakout,Reversal))
        break;
    }
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
//| AddPivot - Inserts a new Fractal Pivot record                    |
//+------------------------------------------------------------------+
void AddPivot(PivotRec &Pivot[], FractalState State, int Direction, double Price, int Bar=0)
  {
    int      size            = ArraySize(Pivot);
    
    if (IsEqual(size,0))
    {
      ArrayResize(Pivot,size+1,32768);

      Pivot[0].Direction     = NoDirection;
    }
    else
    {
      if (IsEqual(State,Extension)&&IsEqual(Pivot[0].State,Extension))
        Pivot[0].Direction   = Direction(Price-Pivot[0].Open);
      else
      {
        ArrayResize(Pivot,size+1,32768);
        ArrayCopy(Pivot,Pivot,1,0,size);
      
        Pivot[0].Direction   = Direction(Price-Pivot[1].Open);
      }
    }

    Direction                = BoolToInt(IsBetween(State,Retrace,Correction),Direction(Direction,InDirection,InContrarian),Direction);

    Pivot[0].Bias            = Action(Direction);
    Pivot[0].State           = State;
    Pivot[0].Open            = Price;
    Pivot[0].High            = BoolToDouble(IsEqual(Direction,DirectionUp),High[Bar],fmax(Price(State,Direction,Bar),Price),Digits);
    Pivot[0].Low             = BoolToDouble(IsEqual(Direction,DirectionUp),fmin(Price(State,Direction,Bar),Price),Low[Bar],Digits);
    Pivot[0].Close           = Close[Bar];
    Pivot[0].Time            = BoolToDate(IsEqual(Bar,0),TimeCurrent(),Time[Bar]);
  }

//+------------------------------------------------------------------+
//| NewFractal - Returns true on change to a Fractal State             |
//+------------------------------------------------------------------+
bool NewFractal(FractalRec &Fractal, PivotRec &Pivot[], int Bar, bool Reversing, bool Update=true, bool Force=true)
  {
    FractalRec frec          = Fractal;
    double     retrace       = Retrace(Fractal.Point[fpRoot],Fractal.Point[fpExpansion],Fractal.Point[fpRetrace]);

    frec.Event               = NoEvent;
    frec.Alert               = NoAlert;

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
      AddPivot(Pivot,frec.State,frec.Direction,frec.Price,Bar);

      frec.Event             = Event(frec.State);
      frec.Alert             = Alert(frec.Type);
      frec.Updated           = BoolToDate(Bar>0,Time[Bar],TimeCurrent());
      Fractal                = frec;

      return true;
    }

    UpdatePivot(Pivot,Fractal.Direction,Bar);
    
    return false;
  }

//+------------------------------------------------------------------+
//| NewState - Returns true on change to a Fractal State             |
//+------------------------------------------------------------------+
bool NewState(FractalState &State, FractalState Change, bool Force=false, bool Update=true)
  {
    if (Change==NoState)
      return(false);

    if (Change==Breakout)
      if (State==Reversal)
        return(false);

    //-- Outside Reversal Manager - force only on Direction Change
    if (Force&&Change==Reversal&&State==Reversal)
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
bool NewFibonacci(FractalRec &Fractal, PivotRec &Pivot[], FractalState Method=Extension, bool Reversing=false, int Bar=0)
  {
    bool    reset      = false;
    double  fibo       = BoolToDouble(IsEqual(Method,Extension),Expansion(Fractal.Point[fpBase],Fractal.Point[fpRoot],Fractal.Point[fpExpansion]),
                         BoolToDouble(IsEqual(Method,Retrace),Retrace(Fractal.Point[fpRoot],Fractal.Point[fpExpansion],Fractal.Point[fpRetrace]),NoValue),Digits);

    switch (Method)
    {
      case Extension:  reset  = Level(fibo)<Fractal.Extension.Level;
                         //if (Fractal.Type==Origin&&Reversing)
                         //  Flag("New "+EnumToString(Fractal.Type)+":"+EnumToString(Fractal.Extension.Level),
                         //    BoolToInt(Fractal.Extension.Level==Fibo100,Color(Fractal.Direction),
                         //    BoolToInt(Fractal.Extension.Level<Fibo100,clrDarkGray,clrWhite)),Bar,Fractal.Extension.Forecast);  
//                       if (IsChanged(Fractal.Extension.Level,Level(fibo))||Reversing) //-- Term Pivot
//                       if (IsChanged(Fractal.Extension.Level,Level(fibo))||Reversing)   //-- Trend Pivot
                       if (IsChanged(Fractal.Extension.Level,Level(fibo))||Reversing)   //-- Origin Pivot
                       {
                         Fractal.Event       = NewFibonacci;
                         Fractal.Updated     = BoolToDate(Bar>0,Time[Bar],TimeCurrent());
                  
                         Fractal.Extension.Percent    = fibo;
                         Fractal.Extension.Forecast   = Price(Fractal.Extension.Level,Fractal.Point[fpRoot],BoolToDouble(IsEqual(Method,Extension),Fractal.Point[fpBase],Fractal.Point[fpExpansion]),Method);
                         //if (Fractal.Type==Origin)
                         //  Flag("New "+EnumToString(Fractal.Type)+":"+EnumToString(Fractal.Extension.Level),
                         //    BoolToInt(Fractal.Extension.Level==Fibo100,Color(Fractal.Direction),
                         //    BoolToInt(Fractal.Extension.Level<Fibo100,clrDarkGray,clrWhite)),Bar,Fractal.Extension.Forecast);  
                         AddPivot(Pivot,Extension,Fractal.Direction,Fractal.Extension.Forecast,Bar);
                  
                         return true;
                       }
    }

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
