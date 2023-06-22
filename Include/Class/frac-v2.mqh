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
           FiboLevel     Level;                    //-- Fibo Level Now
           double        Open;                     //-- Calculated Fibonacci Price
           double        Forecast;                 //-- Calculated Fibonacci Price
           double        Percent;                  //-- Actual Fibonacci Percentage
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
           double        Point[FractalPoints];     //-- Fractal Points (Prices)
           datetime      Updated;                  //-- Last Update;
         };

  struct BufferRec
         {
           double        Point[];
         };


private:

        int          fbar;
        int          fdirection;
        double       fsupport;
        double       fresistance;
        double       fpivot;


        FractalRec   frec[FractalTypes];
        PivotRec     prec[];

        AlertLevel   Alert(FractalType Type);
        EventType    Event(FractalState State);
        EventType    Event(FractalType Type);
        
        double       Price(FractalState State, int Direction, int Bar);

        void         CalcFractal(FractalRec &Fractal, int Direction, double &Points[]);
        void         UpdateTerm(void);
        void         UpdateTrend(void);
        void         UpdateOrigin(void);


public:
                     CFractal(void);
                    ~CFractal();
                    
        void         UpdateFractal(double Support, double Resistance, double Pivot, int Bar);

        double       Extension(FractalType Type, MeasureType Measure, int Format=InDecimal);    //--- returns expansion fibonacci
        double       Retrace(FractalType Type, MeasureType Measure, int Format=InDecimal);      //--- returns retrace fibonacci
        double       Correction(FractalType Type, MeasureType Measure, int Format=InDecimal);   //--- returns recovery fibonacci
        double       Recovery(FractalType Type, MeasureType Measure, int Format=InDecimal);     //--- returns recovery fibonacci
        double       Forecast(FractalType Type, FractalState Method, FiboLevel Level=FiboRoot);

        string       PivotStr(string Title, PivotRec &Pivot);
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
//| Event(State) - Returns the Event on change in Fractal State      |
//+------------------------------------------------------------------+
EventType CFractal::Event(FractalState State)
  {
    static const EventType event[FractalStates]  = {NoEvent,NewRally,NewPullback,NewRetrace,NewCorrection,NewRecovery,NewBreakout,NewReversal,
                                                    NewExtension,NewFlatline,NewConsolidation,NewParabolic,NewChannel};
    return event[State];
  }

//+------------------------------------------------------------------+
//| Event(Type) - Returns the Event on change in Fractal Type        |
//+------------------------------------------------------------------+
EventType CFractal::Event(FractalType Type)
  {
    static const EventType event[FractalTypes]   = {NewOrigin,NewTrend,NewTerm,NewRetrace,NewBase,NewReversal,NewExpansion,
                                                    NewDivergence,NewConvergence,NewInversion,NewConversion,NewLead};
    return event[Type];
  }

//+------------------------------------------------------------------+
//| UpdateOrigin - Calc Origin fractal                               |
//+------------------------------------------------------------------+
void CFractal::UpdateOrigin(void)
  {
  }

//+------------------------------------------------------------------+
//| UpdateTrend - Calc Trend fractal                                 |
//+------------------------------------------------------------------+
void CFractal::UpdateTrend(void)
  {
  }

//+------------------------------------------------------------------+
//| UpdateTerm - Calc Term Fractal                                   |
//+------------------------------------------------------------------+
void CFractal::CalcFractal(FractalRec &Fractal, int Direction, double &Points[])
  {
  }

//+------------------------------------------------------------------+
//| UpdateTerm - Calc Term Fractal                                   |
//+------------------------------------------------------------------+
void CFractal::UpdateTerm(void)
  {
    frec[Term].Point[fpBase]     = BoolToDouble(frec[Term].Direction==DirectionUp,fresistance,fsupport,Digits);
    frec[Term].Point[fpRoot]     = BoolToDouble(frec[Term].Direction==DirectionUp,fsupport,fresistance,Digits);

    if (High[fbar]>fresistance)
      if (Low[fbar]<fsupport)
      {
        //-- Handle Outside Reversal Anomalies
        if (Event(NewHigh))

          //-- Handle Hard Outside Anomaly Downtrend
          if (Event(NewLow))
          {
            Print(TimeToStr(Time[fbar])+":"+DoubleToStr(Close[fbar],Digits)+":"+DoubleToStr(fsupport,Digits)+":"+DoubleToStr(fresistance,Digits));
            if (IsBetween(Close[fbar],fsupport,fresistance))
              Flag("[fr3]Interior Close",clrGoldenrod,fbar,Close[fbar],Always);
            else
              Flag("[fr3]Exterior Close",clrDodgerBlue,fbar,Close[fbar],Always);

            Flag("[fr3]Outside Support",clrRed,fbar,fsupport,Always);
            Flag("[fr3]Outside Resisance",clrYellow,fbar,fresistance,Always);
            Arrow("[fr3]Outside Pivot:"+TimeToStr(Time[fbar]),(ArrowType)BoolToInt(fdirection==DirectionUp,ArrowUp,ArrowDown),clrWhite,fbar,fpivot);
          }

          //-- Handle Hard Outside Anomaly Uptrend
          else
          {
            //if (NewDirection(frec[Term].Direction,DirectionUp))
            //{
            //  Print(TimeToStr(Time[fbar])+":"+(string)fbar+":"+DoubleToStr(Close[fbar],Digits)+":"+DoubleToStr(Resistance,Digits));
            //  Flag("[fr3]Anomaly Resistance",Color(DirectionUp,IN_CHART_DIR),fbar,Resistance,Always);
            //}
          }
        else

        //-- Handle Outside Anomaly Downtrend
        if (Event(NewLow))
        {
          //if (NewDirection(frec[Term].Direction,DirectionDown))
          //{
          //  Print(TimeToStr(Time[fbar])+":"+(string)fbar+":"+DoubleToStr(Close[fbar],Digits)+":"+DoubleToStr(Support,Digits));
          //  Flag("[fr3]Anomaly Support",Color(DirectionDown,IN_CHART_DIR),fbar,Support,Always);   
          //}
        }

        //-- Handle Outside Anomaly Rally/Pullback
        else
        {
//          Flag("[fr3]Anomaly Interior",clrGoldenrod,Bar,Close[Bar],Always);
        }
      }


      else

      //-- Handle Normal Uptrend Expansions
      {
        if (Event(NewHigh))
        {
          //if (NewDirection(frec[Term].Direction,DirectionUp))
          //{
          //  Print(TimeToStr(Time[fbar])+":"+(string)fbar+":"+DoubleToStr(Close[fbar],Digits)+":"+DoubleToStr(Resistance,Digits));
          //  Flag("[fr3]Anomaly Resistance",Color(DirectionUp,IN_CHART_DIR),fbar,Resistance,Always);
          //}
        }
        else
        if (Event(NewLow))
        {
        }
        else
        {
        }
      }
    else

    //-- Handle Normal Downtrend Expansions
    if (Low[fbar]<Support)
      if (Event(NewHigh))
      {
      }
      else
      if (Event(NewLow))
      {
        //if (NewDirection(frec[Term].Direction,DirectionDown))
        //{
        //  Print(TimeToStr(Time[fbar])+":"+(string)fbar+":"+DoubleToStr(Close[fbar],Digits)+":"+DoubleToStr(Support,Digits));
        //  Flag("[fr3]Anomaly Support",Color(DirectionDown,IN_CHART_DIR),fbar,Support,Always);   
        //}
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
//| UpdateFractal - Updates fractal Term based on supplied values    |
//+------------------------------------------------------------------+
void CFractal::UpdateFractal(double Support, double Resistance, double Pivot, int Bar)
  {
    fbar                         = Bar;
    fdirection                   = Direction(Close[Bar]-Pivot);

    fsupport                     = Support;
    fresistance                  = Resistance;
    fpivot                       = Pivot;
    
    UpdateTerm();
    UpdateTrend();
    UpdateOrigin();
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
//| Retrace - Calcuates fibo retrace % for supplied Type             |
//+------------------------------------------------------------------+
double CFractal::Retrace(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
    double format       = BoolToDouble(Format==InDecimal,1,BoolToDouble(Format==InPercent,100));

    switch (Measure)
    {
      case Now: return fdiv(frec[Type].Point[fpExpansion]-frec[Type].Point[fpClose],frec[Type].Point[fpExpansion]-frec[Type].Point[fpRoot],3)*format;
      case Min: return fdiv(frec[Type].Point[fpExpansion]-frec[Type].Point[fpRecovery],frec[Type].Point[fpExpansion]-frec[Type].Point[fpRoot],3)*format;
      case Max: return fdiv(frec[Type].Point[fpExpansion]-frec[Type].Point[fpRetrace],frec[Type].Point[fpExpansion]-frec[Type].Point[fpRoot],3)*format;
    }

    return(0.00);
  }

//+------------------------------------------------------------------+
//| Extension - Calcuates fibo extension % for supplied Type         |
//+------------------------------------------------------------------+
double CFractal::Extension(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
    double format       = BoolToDouble(Format==InDecimal,1,BoolToDouble(Format==InPercent,100));

    switch (Measure)
    {
      case Now: return fdiv(frec[Type].Point[fpExpansion]-frec[Type].Point[fpRoot],frec[Type].Point[fpClose]-frec[Type].Point[fpRoot],3)*format;
      case Min: return fdiv(frec[Type].Point[fpExpansion]-frec[Type].Point[fpRoot],frec[Type].Point[fpRetrace]-frec[Type].Point[fpRoot],3)*format;
      case Max: return fdiv(frec[Type].Point[fpExpansion]-frec[Type].Point[fpRoot],frec[Type].Point[fpExpansion]-frec[Type].Point[fpRoot],3)*format;
    }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Correction - Calcuates fibo contrarian %  for supplied Type      |
//+------------------------------------------------------------------+
double CFractal::Correction(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
    double format       = BoolToDouble(Format==InDecimal,1,BoolToDouble(Format==InPercent,100));

    switch (Measure)
    {
      case Now: return fdiv(frec[Type].Point[fpExpansion]-frec[Type].Point[fpRoot],frec[Type].Point[fpClose]-frec[Type].Point[fpRoot],3)*format;
      case Min: return fdiv(frec[Type].Point[fpExpansion]-frec[Type].Point[fpRoot],frec[Type].Point[fpRetrace]-frec[Type].Point[fpRoot],3)*format;
      case Max: return fdiv(frec[Type].Point[fpExpansion]-frec[Type].Point[fpRoot],frec[Type].Point[fpRecovery]-frec[Type].Point[fpRoot],3)*format;
    }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Recovery - Calcuates fibo recovery % for supplied Type           |
//+------------------------------------------------------------------+
double CFractal::Recovery(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
    double format       = BoolToDouble(Format==InDecimal,1,BoolToDouble(Format==InPercent,100));

    switch (Measure)
    {
      case Now: return fdiv(frec[Type].Point[fpRoot]-frec[Type].Point[fpClose],frec[Type].Point[fpRoot]-frec[Type].Point[fpBase],3)*format;
      case Max: return fdiv(frec[Type].Point[fpRoot]-frec[Type].Point[fpExpansion],frec[Type].Point[fpRoot]-frec[Type].Point[fpBase],3)*format;
    }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Forecast - Returns price for supplied Type/State/Level           |
//+------------------------------------------------------------------+
double CFractal::Forecast(FractalType Type, FractalState Method, FiboLevel Level=FiboRoot)
  {
    const double percent[FiboLevels] = {0.00,0.236,0.382,0.500,0.618,1.0,1.618,2.618,4.236,8.236};

    switch (Method)
    {
      case Rally:       return Forecast(Type,Correction,Fibo23);
      case Pullback:    return Forecast(Type,Retrace,Fibo23);
      case Retrace:     return NormalizeDouble(frec[Type].Point[fpExpansion]-((frec[Type].Point[Base]-frec[Type].Point[fpRoot])*percent[Level]),Digits);
      case Correction:  return NormalizeDouble(frec[Type].Point[fpRoot]+((frec[Type].Point[fpExpansion]-frec[Type].Point[fpRoot])*percent[Level]),Digits);
      case Recovery:    return Forecast(Type,Retrace,Fibo23);
      case Extension:   return NormalizeDouble(frec[Type].Point[fpRoot]+((frec[Type].Point[fpBase]-frec[Type].Point[fpRoot])*percent[Level]),Digits);
      default:          return NoValue;
    }
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

