//+------------------------------------------------------------------+
//|                                                      Fractal.mqh |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict

#include <Class\Event.mqh>

class CFractal : public CEvent
  {

protected:

#define FiboCorrection   0.764
#define FiboRetrace      0.500
#define FiboDivergent    0.236

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
                     fpClose,         // Close
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
                     Running,
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
           FractalType   Type;                     //-- Type
           PivotRec      Pivot;                    //-- Fractal Pivot
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
           int           Lead;                     //-- Bias based on Last Pivot High/Low hit
           int           Bias;                     //-- Active Bias derived from Close[] to Pivot.Open  
           EventType     Event;                    //-- Last Event; disposes on next tick
           AlertLevel    Alert;                    //-- Last Alert; disposes on next tick
           bool          Peg;                      //-- Retrace peg
           FibonacciRec  Extension;                //-- Fibo Extension Pivot
           datetime      Updated;                  //-- Last Update;
           double        Point[FractalPoints];     //-- Fractal Points (Prices)
         };

//static const string    FractalTag[FractalTypes]     = {"(o)","(tr)","(tm)","(p)","(b)","(r)","(e)","(d)","(c)","(iv)","(cv)","(l)"};

private:

        FractalRec   frec[FractalTypes];
        AlertLevel   Alert(FractalType Type);
        EventType    Event(FractalState State);
        EventType    Event(FractalType Type);

public:
                     CFractal(void);
                    ~CFractal();
                    
         void        Update(FractalType Type, int Direction, double Price, int Bar=0);

         double      Expansion(FractalType Type, MeasureType Measure, int Format=InDecimal);  //--- returns expansion fibonacci
         double      Retrace(FractalType Type, MeasureType Measure, int Format=InDecimal);    //--- returns retrace fibonacci
         double      Recovery(FractalType Type, MeasureType Measure, int Format=InDecimal);   //--- returns recovery fibonacci
         double      Forecast(FractalType Type, int Method, FiboLevel Fibo=FiboRoot);         //--- returns extended fibo price
  };


//+------------------------------------------------------------------+
//| Alert - Returns Alert Level for supplied Fractal Type            |
//+------------------------------------------------------------------+
AlertLevel CFractal::Alert(FractalType Type)
  {
    static const AlertLevel level[FractalTypes]  = {Critical,Major,Minor,Nominal,Warning,Nominal,Warning,
                                                    Notify,Notify,Notify,Notify,Notify};

    return level[Type];
  }

//+------------------------------------------------------------------+
//| FractalEvent - Returns the Fractal Event on change in State      |
//+------------------------------------------------------------------+
EventType CFractal::Event(FractalState State)
  {
    static const EventType event[FractalStates]  = {NoEvent,NewRally,NewPullback,NewRetrace,NewCorrection,NewRecovery,NewBreakout,NewReversal,
                                                    NewExtension,NewFlatline,NewConsolidation,NewParabolic,NewChannel};
  
    return event[State];
  }

//+------------------------------------------------------------------+
//| FractalEvent - Returns the Fractal Event on change in Type       |
//+------------------------------------------------------------------+
EventType CFractal::Event(FractalType Type)
  {
    static const EventType event[FractalTypes]   = {NewOrigin,NewTrend,NewTerm,NewRetrace,NewBase,NewReversal,NewExpansion,
                                                    NewDivergence,NewConvergence,NewInversion,NewConversion,NewLead};
    
    return event[Type];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CFractal::CFractal(void)
  {
    for (FractalType type=Origin;type<FractalTypes;type++)
    {
      frec[type].State               = NoState;
      frec[type].Direction           = BoolToInt(Close[Bars]<Open[Bars],DirectionDown,DirectionUp);
      frec[type].Price               = Open[Bars];
      frec[type].Lead                = NoBias;
      frec[type].Bias                = NoBias;
      frec[type].Event               = NoEvent;
      frec[type].Alert               = NoAlert;
      frec[type].Peg                 = false;
      frec[type].Updated             = Time[Bars];

      ArrayInitialize(frec[type].Point,Open[Bars]);
    }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CFractal::~CFractal()
  {
  }

//+------------------------------------------------------------------+
//| Update: Calc fractal by supplied fractal, direction and price    |
//+------------------------------------------------------------------+
void CFractal::Update(FractalType Type, int Direction, double Price, int Bar=0)
  {
    FractalState  state              = NoState;
    
    frec[Type].Event                 = NoEvent;
    frec[Type].Point[fpClose]        = Close[Bar];

    //--- Check for Reversals
    if (NewDirection(frec[Type].Direction,Direction))
    {
      frec[Type].Point[fpOrigin]     = frec[Type].Point[fpRoot];
      frec[Type].Point[fpRoot]       = frec[Type].Point[fpExpansion];
      frec[Type].Point[fpBase]       = Price;
      
      SetEvent(Event(Type),Alert(Type));
    }

    //--- Check for Term Upper Boundary changes
    if (IsEqual(Direction,DirectionUp))
      if (IsHigher(High[Bar],frec[Type].Point[fpExpansion]))
      {
        frec[Type].Point[fpRetrace]  = frec[Type].Point[fpExpansion];
        frec[Type].Point[fpRecovery] = frec[Type].Point[fpExpansion];

        SetEvent(NewExpansion,Alert(Type));

//        UpdateFractalBuffer(DirectionUp,High[Bar]);
      }
      else 
      if (IsLower(BoolToDouble(Bar==0,Close[Bar],Low[Bar]),frec[Type].Point[fpRetrace]))
        frec[Type].Point[fpRecovery] = frec[Type].Point[fpRetrace];
      else
        frec[Type].Point[fpRecovery] = fmax(BoolToDouble(Bar==0,Close[Bar],High[Bar]),frec[Type].Point[fpRecovery]);
    else

    //--- Check for Term Lower Boundary changes
      if (IsLower(Low[Bar],frec[Type].Point[fpExpansion]))
      {
        frec[Type].Point[fpRetrace]  = frec[Type].Point[fpExpansion];
        frec[Type].Point[fpRecovery] = frec[Type].Point[fpExpansion];

        SetEvent(NewExpansion,Alert(Type));

//        UpdateFractalBuffer(DirectionDown,Low[Bar]);
      }
      else
      if (IsHigher(BoolToDouble(Bar==0,Close[Bar],High[Bar]),frec[Type].Point[fpRetrace]))
        frec[Type].Point[fpRecovery] = frec[Type].Point[fpRetrace];
      else
        frec[Type].Point[fpRecovery] = fmin(BoolToDouble(Bar==0,Close[Bar],Low[Bar]),frec[Type].Point[fpRecovery]);

    //--- Check for state changes
    if (IsEqual(frec[Type].Point[fpRecovery],frec[Type].Point[fpExpansion],Digits))
      if (Event(Event(Type)))
        state                        = Reversal;
      else
        state                        = Breakout;
    else
    if (Retrace(Type,Max)>FiboCorrection)
      if (Recovery(Type,Max)>FiboCorrection)
        state                        = Recovery;
      else
        state                        = Correction;
    else
    if (Retrace(Type,Max)>FiboRetrace)
      state                          = Retrace;
    else
    if (Retrace(Type,Max)>FiboDivergent)
      state                          = (FractalState)BoolToInt(IsEqual(Direction,DirectionUp),Rally,Pullback);

//    if (NewState(frec[Type].State,state))
//    {
//      frec[Type].Event             = FractalEvent(state);
//      frec[Type].Price             = BoolToDouble(Event(NewTerm),frec[Type].Point[fpBase],Close[Bar]);
//
//      SetEvent(BoolToEvent(NewAction(frec[Type].Lead,(FractalState)BoolToInt(Event(NewTerm)||Event(NewExpansion,Minor),
//                              Action(frec[Type].Direction),Action(frec[Type].Direction,InDirection,InContrarian))),NewBias),Minor);
//      SetEvent(FractalEvent(state),Minor);
//      SetEvent(NewState,Minor);
//    }
//    
//    NewBias(frec[Type].Bias,Action(Close[Bar]-frec[Type].Price,InDirection));
  }

//+------------------------------------------------------------------+
//| Retrace - Calcuates fibo retrace % for supplied Type             |
//+------------------------------------------------------------------+
double CFractal::Retrace(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
    double retrace      = frec[Type].Point[fpExpansion]-frec[Type].Point[fpRoot];
    double format       = BoolToDouble(Format==InDecimal,1,BoolToDouble(Format==InPercent,100));

    switch (Measure)
    {
      case Now: return(fdiv(frec[Type].Point[fpExpansion]-frec[Type].Point[fpClose],retrace,3)*format);
      case Min: return(fdiv(frec[Type].Point[fpExpansion]-frec[Type].Point[fpRecovery],retrace,3)*format);
      case Max: return(fdiv(frec[Type].Point[fpExpansion]-frec[Type].Point[fpRetrace],retrace,3)*format);
    }

    return(0.00);
  }

//+------------------------------------------------------------------+
//| Expansion - Calcuates fibo expansion % for supplied Type         |
//+------------------------------------------------------------------+
double CFractal::Expansion(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
    //switch (Measure)
    //{
    //  case Now: return(Expansion(frec[Type].Point[fpBase],frec[Type].Point[fpRoot],Close[sBar],Format));
    //  case Min: return(Expansion(frec[Type].Point[fpBase],frec[Type].Point[fpRoot],frec[Type].Point[fpRetrace],Format));
    //  case Max: return(Expansion(frec[Type].Point[fpBase],frec[Type].Point[fpRoot],frec[Type].Point[fpExpansion],Format));
    //}

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Recovery - Calcuates fibo recovery% for supplied Type            |
//+------------------------------------------------------------------+
double CFractal::Recovery(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
    double recovery     = frec[Type].Point[fpRoot]-frec[Type].Point[fpBase];
    double format       = BoolToDouble(Format==InDecimal,1,BoolToDouble(Format==InPercent,100));

    switch (Measure)
    {
      case Now: return fdiv(frec[Type].Point[fpRoot]-frec[Type].Point[fpClose],recovery,3)*format;
//      case Min: return(BoolToInt(IsEqual(Format,InDecimal),1,100)-fabs(Retrace(Type,Max,Format)));
      case Max: return fdiv(frec[Type].Point[fpRoot]-frec[Type].Point[fpExpansion],recovery,3)*format;
    }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Forecast - Returns Forecast Price for supplied Fibo              |
//+------------------------------------------------------------------+
double CFractal::Forecast(FractalType Type, int Method, FiboLevel Fibo=FiboRoot)
  {
    //switch (Method)
    //{
    //  case Expansion:   return(NormalizeDouble(frec[Type].Point[fpRoot]+((frec[Type].Point[fpBase]-frec[Type].Point[fpRoot])*Percent(Fibo)),Digits));
    //  case Retrace:     return(NormalizeDouble(frec[Type].Point[fpExpansion]+((frec[Type].Point[fpRoot]-frec[Type].Point[fpExpansion])*Percent(Fibo)),Digits));
    //  case Recovery:    return(NormalizeDouble(frec[Type].Point[fpRoot]-((frec[Type].Point[fpRoot]-frec[Type].Point[fpRecovery])*Percent(Fibo)),Digits));
    //  case Correction:  return(NormalizeDouble(((frec[Type].Point[fpRoot]-frec[Type].Point[fpExpansion])*FiboCorrection)+frec[Type].Point[fpExpansion],Digits));
    //}

    return (0.00);
  }

