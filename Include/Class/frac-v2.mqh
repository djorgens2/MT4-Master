//+------------------------------------------------------------------+
//|                                                      Fractal.mqh |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict

#define   FiboCorrection   0.764
#define   FiboRetrace      0.500
#define   FiboDivergent    0.236

#include <Class\Event.mqh>

class CFractal : public CEvent
  {

protected:

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
           FiboLevel     Level;                    //-- Fibo Level Now
           double        Open;                     //-- Fibonacci Event Price
           double        Forecast;                 //-- Calculated Fibonacci Price
           double        Percent;                  //-- Actual Fibonacci Percentage
         };

  //-- Canonical Fractal Rec
  struct FractalRec
         {
           //FractalType   Type;                     //-- Type
           FractalState  State;                    //-- State
           int           Direction;                //-- Direction based on Last Breakout/Reversal (Trend)
           EventType     Event;                    //-- Last Event; disposes on next tick
           AlertType     Alert;                    //-- Last Alert; disposes on next tick
           bool          Peg;                      //-- Retrace peg
           FibonacciRec  Extension;                //-- Fibo Extension Pivot
           FibonacciRec  Retrace;                  //-- Fibo Retrace Pivot
           double        Fractal[FractalPoints];     //-- Fractal Points (Prices)
           datetime      Updated;                  //-- Last Update;
         };


private:

        int          fBar;
        int          fBars;
        int          fDirection;

        double       fbuf[];
        int          fbufBar;
        int          fbufDirection;

        double       fSupport;
        double       fResistance;
        double       fPivot;
        double       fHigh;
        double       fLow;
        double       fClose;
        
        string       fObjectStr;

        FractalRec   frec[FractalTypes];
        PivotRec     prec[];

        EventType    Event(FractalState State);
        EventType    Event(FractalType Type);
        AlertType    Alert(FractalType Type);
        
        void         SetBuffer(void);
        void         UpdateBuffer(void);

        bool         NewState(FractalState &State, FractalState Change, bool Force=false, bool Update=true);
        bool         IsChanged(FractalState &Check, FractalState Change, bool Update=true);
        bool         IsEqual(FractalState &State1, FractalState State2) {return State1==State2;};

        bool         NewFibonacci(FibonacciRec &Compare, FibonacciRec &Change, bool Update=true);
        bool         IsChanged(FiboLevel &Check, FiboLevel Change, bool Update=true);
        bool         IsEqual(FiboLevel &Level1, FiboLevel Level2) {return Level1==Level2;};

        void         InitFractal(void);
        void         SetFractal(void);
        void         UpdateTerm(void);
        void         UpdateTrend(void);
        void         UpdateOrigin(void);


public:
                     CFractal(void);
                    ~CFractal();
                    
        void         UpdateFractal(double Support, double Resistance, double Pivot, int Bar);
        void         Fractal(double &Buffer[]) {ArrayCopy(Buffer,fbuf);}
        FractalRec   Fractal(FractalType Type) {return frec[Type];};

        double       Extension(FractalType Type, MeasureType Measure, int Format=InDecimal);    //--- returns expansion fibonacci
        double       Retrace(FractalType Type, MeasureType Measure, int Format=InDecimal);      //--- returns retrace fibonacci
        double       Correction(FractalType Type, MeasureType Measure, int Format=InDecimal);   //--- returns recovery fibonacci
        double       Recovery(FractalType Type, MeasureType Measure, int Format=InDecimal);     //--- returns recovery fibonacci
        double       Forecast(FractalType Type, FractalState Method, FiboLevel Level=FiboRoot);

        string       PointStr(double &Fractal[]);
        string       FractalStr(FractalType Type);
        string       PivotStr(string Title, PivotRec &Pivot);
  };

//+------------------------------------------------------------------+
//| NewState - Returns true on change to a Fractal State             |
//+------------------------------------------------------------------+
bool CFractal::NewState(FractalState &State, FractalState Change, bool Force=false, bool Update=true)
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
//| IsChanged - Compares FractalStates to detect changes             |
//+------------------------------------------------------------------+
bool CFractal::IsChanged(FractalState &Check, FractalState Change, bool Update=true)
  {
    if (IsEqual(Check,Change))
      return (false);
      
    if (Update)
      Check      = Change;

    return (true);
  }

//+------------------------------------------------------------------+
//| NewFibonacci - Compares Fibonacci to detect changes              |
//+------------------------------------------------------------------+
bool CFractal::NewFibonacci(FibonacciRec &Compare, FibonacciRec &Change, bool Update=true)
  {
    if (IsEqual(Compare.Level,Change.Level))
      return false;
    
    Compare = Change;
    return true;
  }

//+------------------------------------------------------------------+
//| IsChanged - Compares FiboLevels to detect changes                |
//+------------------------------------------------------------------+
bool CFractal::IsChanged(FiboLevel &Compare, FiboLevel Change, bool Update=true)
  {
    if (Compare==Change)
      return false;
      
    Compare = Change;
    return true;
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
//| Alert - Returns Alert Level for supplied Fractal Type            |
//+------------------------------------------------------------------+
AlertType CFractal::Alert(FractalType Type)
  {
    static const AlertType alert[FractalTypes]  = {Critical,Major,Minor,Nominal,Warning,Nominal,Warning,
                                                    Notify,Notify,Notify,Notify,Notify};
    return alert[Type];
  }

//+------------------------------------------------------------------+
//| UpdateBuffer - Apply changes to the Fractal Buffer               |
//+------------------------------------------------------------------+
void CFractal::UpdateBuffer(void)
  {
    if (IsEqual(frec[Term].Direction,fbufDirection))
    {
      fbuf[fbufBar]       = 0.00;
      fbufBar             = fBar;
      fbuf[fbufBar]       = frec[Term].Fractal[fpExpansion];
    }
    else  
    if (IsChanged(fbufBar,fBar))
    {
      fbuf[fbufBar]       = frec[Term].Fractal[fpExpansion];
      fbufDirection       = frec[Term].Direction;
    }
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
//| UpdateTerm - Updates term fractal bounds and buffers             |
//+------------------------------------------------------------------+
void CFractal::UpdateTerm(void)
  {
    FractalRec    term                 = frec[Term];
    FractalState  state                = NoState;

    int           direction            = Direction(BoolToInt(fClose<fSupport,DirectionDown,
                                                   BoolToInt(fClose>fResistance,DirectionUp,
                                                   term.Direction)));
    frec[Term].Event                   = NoEvent;

    //--- Check for Term Reversals
    if (NewDirection(frec[Term].Direction,direction))
    {
      frec[Term].Fractal[fpOrigin]     = term.Fractal[fpRoot];
      frec[Term].Fractal[fpBase]       = term.Fractal[fpRoot];
      frec[Term].Fractal[fpRoot]       = term.Fractal[fpExpansion];

      SetEvent(NewTerm,Minor,term.Fractal[fpRoot]);
    }

    //--- Check for Term Upper Boundary changes
    if (IsEqual(frec[Term].Direction,DirectionUp))
      if (IsHigher(fHigh,frec[Term].Fractal[fpExpansion]))
      {
        frec[Term].Fractal[fpRetrace]  = frec[Term].Fractal[fpExpansion];
        frec[Term].Fractal[fpRecovery] = frec[Term].Fractal[fpExpansion];

        SetEvent(NewExpansion,Minor,frec[Term].Fractal[fpExpansion]);

        UpdateBuffer();
      }
      else 
      if (IsLower(fLow,frec[Term].Fractal[fpRetrace]))
        frec[Term].Fractal[fpRecovery] = frec[Term].Fractal[fpRetrace];
      else
        frec[Term].Fractal[fpRecovery] = fmax(fHigh,frec[Term].Fractal[fpRecovery]);
    else

    //--- Check for Term Lower Boundary changes
      if (IsLower(fClose,frec[Term].Fractal[fpExpansion]))
      {
        frec[Term].Fractal[fpRetrace]  = frec[Term].Fractal[fpExpansion];
        frec[Term].Fractal[fpRecovery] = frec[Term].Fractal[fpExpansion];

        SetEvent(NewExpansion,Minor,frec[Term].Fractal[fpExpansion]);

        UpdateBuffer();
      }
      else
      if (IsHigher(fHigh,frec[Term].Fractal[fpRetrace]))
        frec[Term].Fractal[fpRecovery] = frec[Term].Fractal[fpRetrace];
      else
        frec[Term].Fractal[fpRecovery] = fmin(fLow,frec[Term].Fractal[fpRecovery]);

    //--- Check for term state changes
    if (Event(NewTerm))
      state                            = Reversal;
    else
    if (Event(NewExpansion,Minor))
      state                            = Breakout;
    else
    {
      if (frec[Term].Direction==DirectionUp)
        if (frec[Term].Fractal[fpRetrace]<Forecast(Term,Retrace,Fibo23))
          state                        = Pullback;

      if (frec[Term].Direction==DirectionDown)
        if (frec[Term].Fractal[fpRetrace]>Forecast(Term,Retrace,Fibo23))
          state                        = Rally;
    }

    if (NewState(frec[Term].State,state))
    {
      frec[Term].Event                 = Event(state);

      SetEvent(frec[Term].Event,Minor,BoolToDouble(state==Breakout,term.Fractal[fpExpansion],
                                      BoolToDouble(state==Reversal,term.Fractal[fpRoot],
                                      Forecast(Term,Retrace,Fibo23))));
      SetEvent(NewState,Minor,fClose);
    }
  }

//+------------------------------------------------------------------+
//| SetFractal - Apply Corrections to Term Fractal prior to Update   |
//+------------------------------------------------------------------+
void CFractal::SetFractal(void)
  {
    fLow      = BoolToDouble(fBar==0,Close[fBar],Low[fBar]);
    fHigh     = BoolToDouble(fBar==0,Close[fBar],High[fBar]);
    fClose    = BoolToDouble(frec[Term].Direction==DirectionUp,fHigh,fLow);

    //-- Push Buffer post Zero Bar Outside Reversal Anomaly
    if (fBar<fbufBar)
      if (IsChanged(fbufDirection,frec[Term].Direction,NoUpdate))
        UpdateBuffer();

    //-- Handle Anomalies; set effective Fractal prices
    if (High[fBar]>fResistance)
    {
      if (Low[fBar]<fSupport)
      {
        //-- Handle Outside Reversal Anomalies
        if (Event(NewHigh)&&Event(NewLow))
        {
          fClose   = BoolToDouble(IsEqual(fDirection,DirectionUp),Low[fBar],High[fBar]);

          UpdateTerm();
          UpdateTrend();
          UpdateOrigin();

          fClose   = BoolToDouble(IsEqual(fDirection,DirectionUp),High[fBar],Low[fBar]);
        }
        else
        
        //-- Handle Hard Outside Anomaly Uptrend
        if (Event(NewHigh))
            fClose = High[fBar];
        else

        //-- Handle Hard Outside Anomaly Downtrend
        if (Event(NewLow))
          fClose = Low[fBar];
      }
      else

      //-- Handle Normal Uptrend Expansions
      if (Event(NewHigh))
        fClose   = fHigh;
    }
    else

    //-- Handle Normal Downtrend Expansions
    if (Low[fBar]<fSupport)
      if (Event(NewLow))
        fClose   = fLow;
  }

//+------------------------------------------------------------------+
//| InitFractal - Initialize Fractal history; ends on first NewTerm  |
//+------------------------------------------------------------------+
void CFractal::InitFractal(void)
  {
    fHigh    = fmax(fHigh,High[fBar]);
    fLow     = fmin(fLow,Low[fBar]);

    if (fBar<Bars-1)
    {
      if (Event(NewHigh)&&Event(NewLow))
        return;

      for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
      {
        frec[type].Event       = Event(type);
        frec[type].Alert       = Alert(type);
        frec[type].Peg         = false;
        frec[type].State       = Breakout;
        frec[type].Updated     = TimeCurrent();

        frec[type].Fractal[fpRetrace]     = Close[fBar];
        frec[type].Fractal[fpRecovery]    = Close[fBar];
        frec[type].Fractal[fpClose]       = Close[fBar];

        if (Event(NewHigh))
        {
          frec[type].Direction   = DirectionUp;

          frec[type].Fractal[fpOrigin]    = fLow;
          frec[type].Fractal[fpBase]      = fResistance;
          frec[type].Fractal[fpRoot]      = fLow;
          frec[type].Fractal[fpExpansion] = fHigh;
        }

        if (Event(NewLow))
        {
          frec[type].Direction   = DirectionDown;

          frec[type].Fractal[fpOrigin]    = fHigh;
          frec[type].Fractal[fpBase]      = fSupport;
          frec[type].Fractal[fpRoot]      = fHigh;
          frec[type].Fractal[fpExpansion] = fLow;
        }
      }

      fbuf[fBar+1]    = frec[Term].Fractal[fpRoot];
      fbuf[fBar]      = frec[Term].Fractal[fpExpansion];
      
      fbufBar         = fBar;
      fbufDirection   = frec[Term].Direction;
    }
  }

//+------------------------------------------------------------------+
//| SetBuffer - NewBar Buffer maintenance; adds nodes; pluses index  |
//+------------------------------------------------------------------+
void CFractal::SetBuffer(void)
  {
    for (fBars=fBars;fBars<Bars;fBars++)
    {
      ArrayResize(fbuf,fBars,10);
      ArrayCopy(fbuf,fbuf,1,0,WHOLE_ARRAY);
        
      fbuf[0]                        = 0.00;
      fbufBar++;
    }
  }
  
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFractal::CFractal(void)
  {
    fBar                             = Bars-1;
    fBars                            = Bars;

    fHigh                            = High[fBar];
    fLow                             = Low[fBar];
    
    fObjectStr                       = "[fractal]";

    fbufBar                          = 0;
    fbufDirection                    = NewDirection;
    frec[Term].Direction             = NewDirection;
    
    ArrayResize(fbuf,Bars);
    ArrayInitialize(fbuf,0.00);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFractal::~CFractal()
  {
    RemoveChartObjects(fObjectStr);
  }

//+------------------------------------------------------------------+
//| UpdateFractal - Updates fractal Term based on supplied values    |
//+------------------------------------------------------------------+
void CFractal::UpdateFractal(double Support, double Resistance, double Pivot, int Bar)
  {
    fBar                         = Bar;
    fDirection                   = Direction(Close[Bar]-Pivot);

    fSupport                     = Support;
    fResistance                  = Resistance;
    fPivot                       = Pivot;

    SetBuffer();
    
    if (IsEqual(frec[Term].Direction,NewDirection))
      InitFractal();
    else
    {
      SetFractal();

      UpdateTerm();
      UpdateTrend();
      UpdateOrigin();
    }
  }

//+------------------------------------------------------------------+
//| Retrace - Calcuates fibo retrace % for supplied Type             |
//+------------------------------------------------------------------+
double CFractal::Retrace(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
    double format       = BoolToDouble(Format==InDecimal,1,BoolToDouble(Format==InPercent,100));

    switch (Measure)
    {
      case Now: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpClose],frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],3)*format;
      case Min: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRecovery],frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],3)*format;
      case Max: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRetrace],frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],3)*format;
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
      case Now: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],frec[Type].Fractal[fpClose]-frec[Type].Fractal[fpRoot],3)*format;
      case Min: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],frec[Type].Fractal[fpRetrace]-frec[Type].Fractal[fpRoot],3)*format;
      case Max: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],3)*format;
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
      case Now: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],frec[Type].Fractal[fpClose]-frec[Type].Fractal[fpRoot],3)*format;
      case Min: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],frec[Type].Fractal[fpRetrace]-frec[Type].Fractal[fpRoot],3)*format;
      case Max: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],frec[Type].Fractal[fpRecovery]-frec[Type].Fractal[fpRoot],3)*format;
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
      case Now: return fdiv(frec[Type].Fractal[fpRoot]-frec[Type].Fractal[fpClose],frec[Type].Fractal[fpRoot]-frec[Type].Fractal[fpBase],3)*format;
      case Max: return fdiv(frec[Type].Fractal[fpRoot]-frec[Type].Fractal[fpExpansion],frec[Type].Fractal[fpRoot]-frec[Type].Fractal[fpBase],3)*format;
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
      case Retrace:     return NormalizeDouble(frec[Type].Fractal[fpExpansion]-((frec[Type].Fractal[Base]-frec[Type].Fractal[fpRoot])*percent[Level]),Digits);
      case Correction:  return NormalizeDouble(frec[Type].Fractal[fpRoot]+((frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot])*percent[Level]),Digits);
      case Recovery:    return Forecast(Type,Retrace,Fibo23);
      case Extension:   return NormalizeDouble(frec[Type].Fractal[fpRoot]+((frec[Type].Fractal[fpBase]-frec[Type].Fractal[fpRoot])*percent[Level]),Digits);
      default:          return NoValue;
    }
  }

//+------------------------------------------------------------------+
//| PointStr - Returns formatted Points for supplied Fractal         |
//+------------------------------------------------------------------+
string CFractal::PointStr(double &Fractal[])
  {
    string text    = "";

    for (int point=0;point<FractalPoints;point++)
      Append(text,DoubleToStr(Fractal[point],Digits),"|");

    return (text);
  }

//+------------------------------------------------------------------+
//| FractalStr - Returns formatted Fractal prices by supplied Type   |
//+------------------------------------------------------------------+
string CFractal::FractalStr(FractalType Type)
  {
    string text    = "";

           //FibonacciRec  Extension;                //-- Fibo Extension Pivot
           //FibonacciRec  Retrace;                  //-- Fibo Retrace Pivot

    Append(text,EnumToString(Type));
    Append(text,DirText(frec[Type].Direction),"|");
    Append(text,EnumToString(frec[Type].State),"|");
    Append(text,EnumToString(frec[Type].Event),"|");
    Append(text,EnumToString(frec[Type].Alert),"|");
    Append(text,BoolToStr(frec[Type].Peg,InYesNo),"|");
    Append(text,PointStr(frec[Type].Fractal),"|");
    Append(text,TimeToStr(frec[Type].Updated),"|");

    return (text);
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

