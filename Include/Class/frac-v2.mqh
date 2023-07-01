//+------------------------------------------------------------------+
//|                                                      Fractal.mqh |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict

const double fibonacci[10] = {0.00,0.236,0.382,0.500,0.618,1.0,1.618,2.618,4.236,8.236};
const string tag[12] = {"(o)","(tr)","(tm)","(p)","(b)","(r)","(e)","(d)","(c)","(iv)","(cv)","(l)"};

#define   format(f) BoolToDouble(f==InDecimal,1,BoolToDouble(f==InPercent,100))
#define   percent(p) fibonacci[p]
#define   extension(b,r,e,f) fdiv(e-r,b-r)*format(f)
#define   retrace(r,e,rt,f) fdiv(r-e,rt-e)*format(f)

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

  //-- Canonical Fibonacci Record
  struct FibonacciRec
         {
           FiboLevel     Level;                    //-- Current Fibonacci Level
           double        Pivot;                    //-- Fibonacci Pivot from Last Event
           double        Open;                     //-- Fibonacci Event Price
           double        High;                     //-- Fibonacci High Price
           double        Low;                      //-- Fibonacci Low Price
           double        Percent[MeasureTypes];    //-- Actual Fibonacci Percents by Measure
         };

  //-- Canonical Fractal Rec
  struct FractalRec
         {
           //FractalType   Type;                     //-- Type
           FractalState  State;                    //-- State
           int           Direction;                //-- Direction based on Last Breakout/Reversal (Trend)
           int           Bias;                     //-- Bias 
           EventType     Event;                    //-- Last Event; disposes on next tick
           bool          Peg;                      //-- Retrace peg
           FibonacciRec  Extension;                //-- Fibo Extension Rec
           FibonacciRec  Retrace;                  //-- Fibo Retrace Rec
           double        Fractal[FractalPoints];   //-- Fractal Points (Prices)
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


        EventType    Event(FractalState State);
        EventType    Event(FractalType Type);
        AlertType    Alert(FractalType Type);
        
        void         ManageBuffer(void);
        void         UpdateBuffer(void);

        bool         NewState(FractalState &State, FractalState Change, bool Force=false, bool Update=true);
        bool         IsChanged(FractalState &Check, FractalState Change, bool Update=true);
        bool         IsEqual(FractalState &State1, FractalState State2) {return State1==State2;};

        void         SetFibonacci(FractalRec &Fractal);
//        bool         NewFibonacci(double &Fractal[], FibonacciRec &Extension, FibonacciRec &Retrace, bool Update=true);
        bool         IsChanged(FiboLevel &Check, FiboLevel Change, bool Update=true);
        bool         IsEqual(FiboLevel &Level1, FiboLevel Level2) {return Level1==Level2;};
        FiboLevel    Level(double Percent);


        void         InitFractal(void);
        void         VerifyFractal(void);
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
//| SetFibonacci - Resets Extension/Retrace using supplied Fractal   |
//+------------------------------------------------------------------+
void SetFibonacci(FractalRec &Fractal)
  {
    //fext(
    //fret(
    //-- Fibonacci Extension
           //FiboLevel     Level;                    //-- Current Fibonacci Level
           //double        Pivot;                    //-- Fibonacci Pivot from Last Event
           //double        Open;                     //-- Fibonacci Event Price
           //double        High;                     //-- Fibonacci High Price
           //double        Low;                      //-- Fibonacci Low Price
           //double        Percent[MeasureTypes];    //-- Actual Fibonacci Percents by Measure

  }

//+------------------------------------------------------------------+
//| NewFibonacci - Returns refreshed Fibo rec                        |
//+------------------------------------------------------------------+
//bool NewFibonacci(double &Fractal, PivotRec &Pivot[], FractalState Method=Extension, bool Reversing=false, int Bar=0)
//  {
//    bool    reset      = false;
//    double  fibo       = BoolToDouble(IsEqual(Method,Extension),Expansion(Fractal.Point[fpBase],Fractal.Point[fpRoot],Fractal.Point[fpExpansion]),
//                         BoolToDouble(IsEqual(Method,Retrace),Retrace(Fractal.Point[fpRoot],Fractal.Point[fpExpansion],Fractal.Point[fpRetrace]),NoValue),Digits);
//
//    switch (Method)
//    {
//      case Extension:  reset  = Level(fibo)<Fractal.Extension.Level;
//                         //if (Fractal.Type==Origin&&Reversing)
//                         //  Flag("New "+EnumToString(Fractal.Type)+":"+EnumToString(Fractal.Extension.Level),
//                         //    BoolToInt(Fractal.Extension.Level==Fibo100,Color(Fractal.Direction),
//                         //    BoolToInt(Fractal.Extension.Level<Fibo100,clrDarkGray,clrWhite)),Bar,Fractal.Extension.Forecast);  
////                       if (IsChanged(Fractal.Extension.Level,Level(fibo))||Reversing) //-- Term Pivot
////                       if (IsChanged(Fractal.Extension.Level,Level(fibo))||Reversing)   //-- Trend Pivot
//                       if (IsChanged(Fractal.Extension.Level,Level(fibo))||Reversing)   //-- Origin Pivot
//                       {
//                         Fractal.Event       = NewFibonacci;
//                         Fractal.Updated     = BoolToDate(Bar>0,Time[Bar],TimeCurrent());
//                  
//                         Fractal.Extension.Percent    = fibo;
//                         Fractal.Extension.Forecast   = Price(Fractal.Extension.Level,Fractal.Point[fpRoot],BoolToDouble(IsEqual(Method,Extension),Fractal.Point[fpBase],Fractal.Point[fpExpansion]),Method);
//                         //if (Fractal.Type==Origin)
//                         //  Flag("New "+EnumToString(Fractal.Type)+":"+EnumToString(Fractal.Extension.Level),
//                         //    BoolToInt(Fractal.Extension.Level==Fibo100,Color(Fractal.Direction),
//                         //    BoolToInt(Fractal.Extension.Level<Fibo100,clrDarkGray,clrWhite)),Bar,Fractal.Extension.Forecast);  
//                         AddPivot(Pivot,Extension,Fractal.Direction,Fractal.Extension.Forecast,Bar);
//                  
//                         return true;
//                       }
//    }
//
//    return false;
//  }

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
//bool CFractal::NewFibonacci(FibonacciRec &Compare, FibonacciRec &Change, bool Update=true)
//  {
//    if (IsEqual(Compare.Level,Change.Level))
//      return false;
//    
//    Compare = Change;
//    return true;
//  }

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
//| Level - Returns the FiboLevel based on extended fibonacci        |
//+------------------------------------------------------------------+
FiboLevel CFractal::Level(double Percent)
  {
    for (FiboLevel level=Fibo823;level>FiboRoot;level--)
      if (fabs(Percent)>percent(level))
        return (level);

    return (FiboRoot);
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
//| UpdateTerm - Updates term fractal bounds and buffers             |
//+------------------------------------------------------------------+
void CFractal::UpdateTerm(void)
  {
    FractalRec    last                  = frec[Term];
    FractalState  state                 = NoState;

    int           direction             = Direction(BoolToInt(fClose<fSupport,DirectionDown,
                                                    BoolToInt(fClose>fResistance,DirectionUp,
                                                    last.Direction)));
    frec[Term].Event                    = NoEvent;
    frec[Term].Fractal[fpClose]         = fClose;

    //--- Check for Term Reversals
    if (NewDirection(frec[Term].Direction,direction))
    {
      frec[Term].Fractal[fpOrigin]      = last.Fractal[fpRoot];
      frec[Term].Fractal[fpBase]        = BoolToDouble(fClose<fSupport,fSupport,BoolToDouble(fClose>fResistance,fResistance));
      frec[Term].Fractal[fpRoot]        = last.Fractal[fpExpansion];

      SetEvent(NewTerm,Minor,last.Fractal[fpRoot]);
    }

    //--- Check for Term Upper Boundary changes
    if (IsEqual(frec[Term].Direction,DirectionUp))
      if (IsHigher(fHigh,frec[Term].Fractal[fpExpansion]))
      {
        frec[Term].Fractal[fpRetrace]   = frec[Term].Fractal[fpExpansion];
        frec[Term].Fractal[fpRecovery]  = frec[Term].Fractal[fpExpansion];

        SetEvent(NewExpansion,Minor,frec[Term].Fractal[fpExpansion]);

        UpdateBuffer();
      }
      else 
      if (IsLower(fLow,frec[Term].Fractal[fpRetrace]))
        frec[Term].Fractal[fpRecovery]  = frec[Term].Fractal[fpRetrace];
      else
        frec[Term].Fractal[fpRecovery]  = fmax(fHigh,frec[Term].Fractal[fpRecovery]);
    else

    //--- Check for Term Lower Boundary changes
      if (IsLower(fClose,frec[Term].Fractal[fpExpansion]))
      {
        frec[Term].Fractal[fpRetrace]   = frec[Term].Fractal[fpExpansion];
        frec[Term].Fractal[fpRecovery]  = frec[Term].Fractal[fpExpansion];

        SetEvent(NewExpansion,Minor,frec[Term].Fractal[fpExpansion]);

        UpdateBuffer();
      }
      else
      if (IsHigher(fHigh,frec[Term].Fractal[fpRetrace]))
        frec[Term].Fractal[fpRecovery]  = frec[Term].Fractal[fpRetrace];
      else
        frec[Term].Fractal[fpRecovery]  = fmin(fLow,frec[Term].Fractal[fpRecovery]);

    //--- Check for term state changes
    if (Event(NewTerm))
      state                             = Reversal;
    else
    if (Event(NewExpansion,Minor))
      state                             = Breakout;
    else
    {
      if (frec[Term].Direction==DirectionUp)
        if (frec[Term].Fractal[fpRetrace]<Forecast(Term,Retrace,Fibo23))
          state                         = Pullback;

      if (frec[Term].Direction==DirectionDown)
        if (frec[Term].Fractal[fpRetrace]>Forecast(Term,Retrace,Fibo23))
          state                         = Rally;
    }

    if (NewState(frec[Term].State,state))
    {
      frec[Term].Event                  = Event(state);

      SetEvent(frec[Term].Event,Minor,BoolToDouble(state==Breakout,last.Fractal[fpExpansion],
                                      BoolToDouble(state==Reversal,last.Fractal[fpRoot],
                                      Forecast(Term,Retrace,Fibo23))));
      SetEvent(NewState,Minor,fClose);
    }
  }

//+------------------------------------------------------------------+
//| UpdateTrend - Updates trend fractal bounds and state             |
//+------------------------------------------------------------------+
void CFractal::UpdateTrend(void)
  {
    FractalRec   last                   = frec[Trend];
    FractalState state                  = NoState;
    
    //--- Set Common Fractal Points
    frec[Trend].Event                   = NoEvent;
    frec[Trend].Fractal[fpRetrace]      = frec[Term].Fractal[fpRetrace];
    frec[Trend].Fractal[fpRecovery]     = frec[Term].Fractal[fpRecovery];

    //--- Handle Term Reversals 
    if (Event(NewTerm))        //--- After a term reversal
    {
      frec[Trend].Direction             = frec[Term].Direction;
      frec[Trend].Fractal[fpOrigin]     = frec[Term].Fractal[fpRoot];
      frec[Trend].Fractal[fpBase]       = frec[Term].Fractal[fpOrigin];
      frec[Trend].Fractal[fpRoot]       = frec[Term].Fractal[fpRoot];
    }

    //--- Handle Trend Interior States)
    if (IsBetween(frec[Term].Fractal[fpExpansion],frec[Trend].Fractal[fpRoot],frec[Trend].Fractal[fpBase]))
    {
      if (IsChanged(frec[Trend].Fractal[fpExpansion],frec[Term].Fractal[fpExpansion]))
        state                           = (FractalState)BoolToInt(IsEqual(frec[Trend].Direction,DirectionUp),Rally,Pullback);
      else
      if (Level(Extension(Trend,Max))>1&&Level(Retrace(Trend,Max))>1)
        state                           = (FractalState)BoolToInt(IsEqual(frec[Trend].Direction,DirectionUp),Pullback,Rally);
    }

    //--- Handle Trend Breakout/Reversal/Extension States)
    else
    {
      state                             = (FractalState)BoolToInt(NewDirection(frec[Origin].Direction,frec[Trend].Direction),Reversal,Breakout);

      if (IsChanged(frec[Trend].Fractal[fpExpansion],frec[Term].Fractal[fpExpansion]))
        SetEvent(NewExpansion,Major);
    }

    if (NewState(frec[Trend].State,state,IsEqual(state,Reversal)))
    {
      frec[Trend].Event                 = Event(state);

      SetEvent(NewState,Major);
      SetEvent(frec[Trend].Event,Major,BoolToDouble(state==Breakout,last.Fractal[fpExpansion],
                                       BoolToDouble(state==Reversal,last.Fractal[fpRoot],
                                       Forecast(Trend,Retrace,Fibo23)))); //<-- needs work, need to trap the last fibo crossed
      SetEvent(BoolToEvent(Event(NewReversal,Major),NewTrend),Major,last.Fractal[fpRoot]);
    }
  }

//+------------------------------------------------------------------+
//| UpdateOrigin - Updates origin fractal bounds and state           |
//+------------------------------------------------------------------+
void CFractal::UpdateOrigin(void)
  {
    FractalRec origin                   = frec[Origin];
    frec[Origin].Event                  = NoEvent;

    if (Event(NewTrend))
    {
      frec[Origin]                      = frec[Trend];
      frec[Origin].Fractal[fpOrigin]    = origin.Fractal[fpExpansion];
      frec[Origin].Fractal[fpRoot]      = origin.Fractal[fpExpansion];

      SetEvent(BoolToEvent(Event(NewReversal,Major),NewOrigin),Critical);
    }

    if (IsChanged(frec[Origin].Fractal[fpExpansion],BoolToDouble(IsEqual(frec[Origin].Direction,DirectionUp),
                                          fmax(frec[Origin].Fractal[fpExpansion],frec[Trend].Fractal[fpExpansion]),
                                          fmin(frec[Origin].Fractal[fpExpansion],frec[Trend].Fractal[fpExpansion]),Digits)))
    {
      frec[Origin].Fractal[fpRetrace]   = frec[Origin].Fractal[fpExpansion];
      frec[Origin].Fractal[fpRecovery]  = frec[Origin].Fractal[fpExpansion];
    }                                                    
    else
    if (IsChanged(frec[Origin].Fractal[fpRetrace],BoolToDouble(IsEqual(frec[Origin].Direction,DirectionUp),
                                          fmin(frec[Origin].Fractal[fpRetrace],frec[Trend].Fractal[fpRetrace]),
                                          fmax(frec[Origin].Fractal[fpRetrace],frec[Trend].Fractal[fpRetrace]),Digits)))
      frec[Origin].Fractal[fpRecovery]  = frec[Origin].Fractal[fpRetrace];
    else
      frec[Origin].Fractal[fpRecovery]  = BoolToDouble(IsEqual(frec[Origin].Direction,DirectionUp),
                                          fmax(frec[Origin].Fractal[fpRecovery],frec[Trend].Fractal[fpRecovery]),
                                          fmin(frec[Origin].Fractal[fpRecovery],frec[Trend].Fractal[fpRecovery]),Digits);
      

//    if (NewFractal(frec[Origin],prec,sBar,Event(NewOrigin),Always,Always))
//    {
////      Flag("[s6]"+EnumToString(sType)+":"+EnumToString(frec[Origin].Event),Color(frec[Origin].State),sBar,frec[Origin].Price,sShowFlags);
//
////      if (IsEqual(frec[Origin].State,Breakout)) Print(PivotStr(TimeToStr(BoolToDate(sBar>0,Time[sBar],TimeCurrent())),prec[0])+" "+EventStr());
//
//      if (NewState(frec[Origin].State,state,Event(NewOrigin)))
//      SetEvent(frec[Origin].Event,Critical);
//      SetEvent(NewState,Critical);
//    }
  }

//+------------------------------------------------------------------+
//| VerifyFractal - Check/Apply Corrections to Fractal before Update |
//+------------------------------------------------------------------+
void CFractal::VerifyFractal(void)
  {
    fLow      = BoolToDouble(fBar==0,Close[fBar],Low[fBar]);
    fHigh     = BoolToDouble(fBar==0,Close[fBar],High[fBar]);
    fClose    = BoolToDouble(frec[Term].Direction==DirectionUp,fHigh,fLow);

    //-- Push Buffer post Zero Bar after Outside Reversal Anomaly
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
    //-- Maintain high/low while finding entry
    fHigh    = fmax(fHigh,High[fBar]);
    fLow     = fmin(fLow,Low[fBar]);

    if (fBar<Bars-1)
    {
      if (Event(NewHigh)&&Event(NewLow))
        return;

      for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
      {
        frec[type].Event       = Event(type);
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

        SetFibonacci(frec[type]);
      }

      //-- Initialize Fractal Buffer
      fbuf[fBar+1]    = frec[Term].Fractal[fpRoot];
      fbuf[fBar]      = frec[Term].Fractal[fpExpansion];
      
      fbufBar         = fBar;
      fbufDirection   = frec[Term].Direction;
    }
  }

//+------------------------------------------------------------------+
//| ManageBuffer - Buffer maintenance; add nodes; manage index       |
//+------------------------------------------------------------------+
void CFractal::ManageBuffer(void)
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

    ManageBuffer();
    
    if (IsEqual(frec[Term].Direction,NewDirection))
      InitFractal();
    else
    {
      VerifyFractal();

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
    switch (Measure)
    {
      case Now: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpClose],frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],3)*format(Format);
      case Min: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRecovery],frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],3)*format(Format);
      case Max: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRetrace],frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],3)*format(Format);
    }

    return(0.00);
  }

//+------------------------------------------------------------------+
//| Extension - Calcuates fibo extension % for supplied Type         |
//+------------------------------------------------------------------+
double CFractal::Extension(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
    switch (Measure)
    {
      case Now: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],frec[Type].Fractal[fpClose]-frec[Type].Fractal[fpRoot],3)*format(Format);
      case Min: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],frec[Type].Fractal[fpRetrace]-frec[Type].Fractal[fpRoot],3)*format(Format);
      case Max: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],3)*format(Format);
    }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Correction - Calcuates fibo contrarian %  for supplied Type      |
//+------------------------------------------------------------------+
double CFractal::Correction(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
    switch (Measure)
    {
      case Now: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],frec[Type].Fractal[fpClose]-frec[Type].Fractal[fpRoot],3)*format(Format);
      case Min: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],frec[Type].Fractal[fpRetrace]-frec[Type].Fractal[fpRoot],3)*format(Format);
      case Max: return fdiv(frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot],frec[Type].Fractal[fpRecovery]-frec[Type].Fractal[fpRoot],3)*format(Format);
    }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Recovery - Calcuates fibo recovery % for supplied Type           |
//+------------------------------------------------------------------+
double CFractal::Recovery(FractalType Type, MeasureType Measure, int Format=InDecimal)
  {
    switch (Measure)
    {
      case Now: return fdiv(frec[Type].Fractal[fpRoot]-frec[Type].Fractal[fpClose],frec[Type].Fractal[fpRoot]-frec[Type].Fractal[fpBase],3)*format(Format);
      case Max: return fdiv(frec[Type].Fractal[fpRoot]-frec[Type].Fractal[fpExpansion],frec[Type].Fractal[fpRoot]-frec[Type].Fractal[fpBase],3)*format(Format);
    }

    return (0.00);
  }

//+------------------------------------------------------------------+
//| Forecast - Returns price for supplied Type/State/Level           |
//+------------------------------------------------------------------+
double CFractal::Forecast(FractalType Type, FractalState Method, FiboLevel Level=FiboRoot)
  {
    switch (Method)
    {
      case Rally:       return Forecast(Type,Correction,Fibo23);
      case Pullback:    return Forecast(Type,Retrace,Fibo23);
      case Retrace:     return NormalizeDouble(frec[Type].Fractal[fpExpansion]-((frec[Type].Fractal[Base]-frec[Type].Fractal[fpRoot])*percent(Level)),Digits);
      case Correction:  return NormalizeDouble(frec[Type].Fractal[fpRoot]+((frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot])*percent(Level)),Digits);
      case Recovery:    return Forecast(Type,Retrace,Fibo23);
      case Extension:   return NormalizeDouble(frec[Type].Fractal[fpRoot]+((frec[Type].Fractal[fpBase]-frec[Type].Fractal[fpRoot])*percent(Level)),Digits);
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
    Append(text,BoolToStr(frec[Type].Peg,InYesNo),"|");
    Append(text,PointStr(frec[Type].Fractal),"|");
    Append(text,TimeToStr(frec[Type].Updated),"|");

    return (text);
  }
