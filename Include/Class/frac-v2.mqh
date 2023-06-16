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
           EventType     Event;                    //-- Last Event; disposes on next tick
           AlertLevel    Alert;                    //-- Last Alert; disposes on next tick
           bool          Peg;                      //-- Retrace peg
           FibonacciRec  Extension;                //-- Fibo Extension Pivot
           datetime      Updated;                  //-- Last Update;
           double        Point[FractalPoints];     //-- Fractal Points (Prices)
         };

  struct BufferRec
         {
           double        Point[];
         };


private:

        int          fbar;

        FractalRec   frec[FractalTypes];
        PivotRec     prec[];

        AlertLevel   Alert(FractalType Type);
        EventType    Event(FractalState State);
        EventType    Event(FractalType Type);

        double       Price(FiboLevel Level, double Root, double Reference, FractalState Method);
        double       Price(FractalState State, int Direction, int Bar);

        void         UpdateTerm(double Support, double Resistance);
        void         UpdateTrend(void);
        void         UpdateOrigin(void);


public:
                     CFractal(void);
                    ~CFractal();
                    
         void        Calc(FractalType Type, int Direction, double Price, int Bar=0);
         void        Update(double Support, double Resistance, int Bar);
         double      Expansion(FractalType Type, MeasureType Measure, int Format=InDecimal);  //--- returns expansion fibonacci
         double      Retrace(FractalType Type, MeasureType Measure, int Format=InDecimal);    //--- returns retrace fibonacci
         double      Recovery(FractalType Type, MeasureType Measure, int Format=InDecimal);   //--- returns recovery fibonacci
         double      Forecast(FractalType Type, int Method, FiboLevel Fibo=FiboRoot);         //--- returns extended fibo price
         string      PivotStr(string Title, PivotRec &Pivot);
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
//| Price - Returns price from supplied level, Root/[Base|Expansion] |
//+------------------------------------------------------------------+
double CFractal::Price(FiboLevel Level, double Root, double Reference, FractalState Method)
  {
    const double percent[FiboLevels] = {0.00,0.236,0.382,0.500,0.618,1.0,1.618,2.618,4.236,8.236};

    switch (Method)
    {
      case Retrace:   return NormalizeDouble(Reference-((Reference-Root)*percent[Level]),Digits);
      case Extension: return NormalizeDouble(Root+((Reference-Root)*percent[Level]),Digits);
      default:        return NoValue;
    }
  }

//+------------------------------------------------------------------+
//| Price - Returns historical price of supplied State,Direction,Bar |
//+------------------------------------------------------------------+
double CFractal::Price(FractalState State, int Direction, int Bar)
  {
    if (IsEqual(Bar,0))
      return Close[0];
      
    //--- Note: Not perfect - long bar historical pricing (retrace, correction, rally/pullback(On Close?) missing;
    switch (State)
    {
      case Rally:                 return BoolToDouble(IsEqual(Direction,DirectionUp),High[Bar],Close[Bar],Digits);
      case Pullback:              return BoolToDouble(IsEqual(Direction,DirectionUp),Close[Bar],Low[Bar],Digits);
      case Retrace:
      case Correction:            return BoolToDouble(IsEqual(Direction,DirectionUp),Low[Bar],Close[Bar],Digits);
      case Recovery:
      case Breakout:
      case Reversal:
      case Extension:             return BoolToDouble(IsEqual(Direction,DirectionUp),High[Bar],Close[Bar],Digits);
    }

    return Close[Bar];
  }

//+------------------------------------------------------------------+
//| UpdateOrigin: Calc Origin fractal                                |
//+------------------------------------------------------------------+
void CFractal::UpdateOrigin(void)
  {
  }

//+------------------------------------------------------------------+
//| UpdateOrigin: Calc Trend fractal                                 |
//+------------------------------------------------------------------+
void CFractal::UpdateTrend(void)
  {
  }

//+------------------------------------------------------------------+
//| UpdateTerm: Calc Term fractal                                    |
//+------------------------------------------------------------------+
void CFractal::Calc(FractalType Type, int Direction, double Price, int Bar=0)
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
//| UpdateTerm: Calc Term Fractal                                    |
//+------------------------------------------------------------------+
void CFractal::UpdateTerm(double Support, double Resistance)
  {
    FractalState  state              = NoState;
    
    if (High[fbar]>Resistance)
      if (Low[fbar]<Support)
        if (Event(NewHigh))

          //-- Handle Outside Reversals
          if (Event(NewLow))
          {
            Print(TimeToStr(Time[fbar])+":"+DoubleToStr(Close[fbar],Digits)+":"+DoubleToStr(Support,Digits)+":"+DoubleToStr(Resistance,Digits));
            if (IsBetween(Close[fbar],Support,Resistance))
              Flag("[fr3]Interior Close",clrGoldenrod,fbar,Close[fbar],Always);
            else
              Flag("[fr3]Exterior Close",clrDodgerBlue,fbar,Close[fbar],Always);

            Flag("[fr3]Outside Support",clrRed,fbar,Support,Always);
            Flag("[fr3]Outside Resisance",clrYellow,fbar,Resistance,Always);
          }

          //-- Handle Outside Anomaly Uptrend
          else
          {
//            Flag("[fr3]Anomaly Resistance",clrWhite,Bar,High[Bar],Always);
          }
        else

        //-- Handle Outside Anomaly Downtrend
        if (Event(NewLow))
        {
//          Flag("[fr3]Anomaly Support",clrWhite,Bar,Low[Bar],Always);   
        }

        //-- Handle Outside Anomaly Rally/Pullback
        else
        {
//          Flag("[fr3]Anomaly Interior",clrGoldenrod,Bar,Close[Bar],Always);
        }
      else

      //-- Handle Uptrend Expansions
      {
      }
    else
    
    //-- Handle Downtrend Expansions
    if (Low[fbar]<Support)
      if (Event(NewHigh))
      {
      }
      else
      if (Event(NewLow))
      {
      }
      else
      {
      }
    
    //-- Handle Rally/Pullback
    else
    {
    }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CFractal::CFractal(void)
  {
    for (FractalType type=Origin;type<FractalTypes;type++)
    {
      frec[type].State               = NoState;
      frec[type].Direction           = BoolToInt(Close[Bars-1]<Open[Bars-1],DirectionDown,DirectionUp);
      frec[type].Price               = Open[Bars-1];
      frec[type].Event               = NoEvent;
      frec[type].Alert               = NoAlert;
      frec[type].Peg                 = false;
      frec[type].Updated             = Time[Bars-1];

      ArrayInitialize(frec[type].Point,Open[Bars-1]);
    }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CFractal::~CFractal()
  {
  }

//+------------------------------------------------------------------+
//| Update - Calculates the fractal based on Term Support/Resistance |
//+------------------------------------------------------------------+
void CFractal::Update(double Support, double Resistance, int Bar)
  {
    fbar                         = Bar;
    
    frec[Term].Point[fpBase]     = BoolToDouble(frec[Term].Direction==DirectionUp,Resistance,Support,Digits);
    frec[Term].Point[fpRoot]     = BoolToDouble(frec[Term].Direction==DirectionUp,Support,Resistance,Digits);
    
    UpdateTerm(Support,Resistance);
    UpdateTrend();
    UpdateOrigin();
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

//+------------------------------------------------------------------+
//| PivotStr - Returns Screen formatted Pivot Detail                 |
//+------------------------------------------------------------------+
string CFractal::PivotStr(string Title, PivotRec &Pivot)
  {  
    string text            = "";

    Append(text,Title,"\n");
    Append(text,DirText(Pivot.Direction));
    Append(text,ActionText(Pivot.Lead));
    Append(text,EnumToString(Pivot.State));
    Append(text,"["+ActionText(Pivot.Bias)+"]");
    Append(text,DoubleToStr(Pivot.Open,Digits));
    Append(text,DoubleToStr(Pivot.High,Digits));
    Append(text,DoubleToStr(Pivot.Low,Digits));
    Append(text,DoubleToStr(Pivot.Close,Digits));
        
    return (text);
  }

const string    FractalTag[FractalTypes]     = {"(o)","(tr)","(tm)","(p)","(b)","(r)","(e)","(d)","(c)","(iv)","(cv)","(l)"};

