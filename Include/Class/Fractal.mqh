//+------------------------------------------------------------------+
//|                                                      Fractal.mqh |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict

const double fibonacci[11] = {0.00,0.236,0.382,0.500,0.618,0.764,1.0,1.618,2.618,4.236,8.236};
const string tag[12] = {"(o)","(tr)","(tm)","(p)","(b)","(r)","(e)","(d)","(c)","(iv)","(cv)","(l)"};
const string fp[7]   = {"(o)","(b)","(r)","(e)","(rt)","(rc)","(cl)"};

#define   format(f) BoolToDouble(f==InDecimal,1,BoolToDouble(f==InPercent,100))
#define   percent(p,f) fibonacci[p]*format(f)
#define   fext(b,r,e,f) fdiv(e-r,b-r)*format(f)
#define   fret(r,e,rt,f) fdiv(rt-e,r-e)*format(f)
#define   fprice(b,r,p) ((b-r)*fibonacci[p])+r

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

  enum             FibonacciType
                   {
                     FiboRoot,
                     Fibo23,
                     Fibo38,
                     Fibo50,
                     Fibo61,
                     FiboCorrection,
                     Fibo100,
                     Fibo161,
                     Fibo261,
                     Fibo423,
                     Fibo823,
                     FibonacciTypes
                   };             

  //-- Pivot Record
  struct PivotRec
         {
           EventType     Event;                    //-- Event last updating the Pivot
           int           Lead;                     //-- Action of last Boundary Hit
           int           Bias;                     //-- Bias 
           double        Price;                    //-- Last Event Pivot (Fibonacci)
           double        Open;                     //-- Close price at time of Event
           double        High;                     //-- Pivot High
           double        Low;                      //-- Pivot Low
         };

  //-- Fibonacci Record
  struct FibonacciRec
         {
           EventType     Event;                    //-- Event related to State Changed tick cleared
           FibonacciType Level;                    //-- Current Fibonacci Level
           double        Pivot;                    //-- Fibonacci Pivot from Last Event
           double        Percent[MeasureTypes];    //-- Actual Fibonacci Percents by Measure
         };

  //-- Fractal Record
  struct FractalRec
         {
           FractalType   Type;                     //-- Type
           FractalState  State;                    //-- State
           int           Direction;                //-- Direction based on Last Breakout/Reversal (Trend)
           EventType     Event;                    //-- Last Event; disposes on next tick
           PivotRec      Pivot;
           FibonacciRec  Extension;                //-- Fibo Extension Rec
           FibonacciRec  Retrace;                  //-- Fibo Retrace Rec
           double        Fractal[FractalPoints];   //-- Fractal Points (Prices)
         };


private:

         int             fBar;
         int             fBars;
         int             fDirection;

         double          fbuf[];
         int             fbufBar;
         int             fbufDirection;

         double          fSupport;
         double          fResistance;
         double          fPivot;
         double          fHigh;
         double          fLow;
         double          fClose;
         
         string          fObjectStr;
         bool            fShowFlags;

         FractalRec      frec[FractalTypes];
         double          fpoint[FractalPoints];

         void            Flag(FractalType Type);
         bool            NewState(FractalRec &Fractal);

         void            InitPivot(PivotRec &Pivot, EventLog &Log);
         void            InitFractal(void);

         void            UpdateFibonacci(FibonacciRec &Extension, FibonacciRec &Retrace, double &Fractal[], bool Reset);
         void            UpdatePivot(PivotRec &Pivot);
         void            UpdateTerm(void);
         void            UpdateTrend(void);
         void            UpdateOrigin(void);
         void            UpdateFractal(void);

         void            UpdateBuffer(void);
         void            ManageBuffer(void);

public:
                         CFractal(bool ShowFlags=false);
                        ~CFractal();
                    
        void             UpdateFractal(double Support, double Resistance, double Pivot, int Bar);

        EventType        Event(FractalType Type);
        EventType        Event(FractalState State);
        AlertType        Alert(FractalType Type);
        FractalState     State(EventType Event);
        FibonacciType    Level(double Percent);

        FractalRec       Fractal(FractalType Type) {return frec[Type];};
        void             Fractal(double &Buffer[]) {ArrayCopy(Buffer,fbuf);};

        double           Price(FibonacciType Level, FractalType Type, FractalState Method);
        double           Price(FibonacciType Level, double Root, double Reference, FractalState Method);

        string           BufferStr(int Node);
        string           PointStr(double &Fractal[]);
        string           FibonacciStr(FractalState State, FibonacciRec &Fibonacci);
        string           FractalStr(FractalType Type);
  };

//+------------------------------------------------------------------+
//| Flag - Creates a Flag on Fibonacci Events                        |
//+------------------------------------------------------------------+
void CFractal::Flag(FractalType Type)
  {
    string name    = fObjectStr+EnumToString(Type)+":"+EnumToString(frec[Type].Event);
    
    if (IsEqual(frec[Type].State,Extension))
      Flag(name+" ["+DoubleToStr(percent(frec[Type].Extension.Level,InPercent),1)+"%]",Color(frec[Type].Direction),fBar,frec[Type].Pivot.Price,fShowFlags);
    else
    if (IsBetween(frec[Type].State,Breakout,Reversal))
      Flag(name,Color(Type,NewDirection),fBar,frec[Type].Pivot.Price,fShowFlags);
    else
    if (IsEqual(frec[Type].State,Recovery))
      Flag(name,clrSteelBlue,fBar,frec[Type].Pivot.Price,fShowFlags);
    else
    if (IsEqual(frec[Type].State,Correction))
      Flag(name,clrWhite,fBar,frec[Type].Pivot.Price,fShowFlags);
    else
      Flag(name+" ["+DoubleToStr(percent(frec[Type].Retrace.Level,InPercent),1)+"%]",clrDarkGray,fBar,frec[Type].Pivot.Price,fShowFlags);
  }

//+------------------------------------------------------------------+
//| NewState - Returns true on detected change of Fibonacci State    |
//+------------------------------------------------------------------+
bool CFractal::NewState(FractalRec &Fractal)
  {
    if (IsBetween(Fractal.Extension.Event,NewRally,NewExtension))
    {
      Fractal.State        = State(Fractal.Extension.Event);
      Fractal.Event        = Fractal.Extension.Event;
      Fractal.Pivot.Price  = Fractal.Extension.Pivot;

      return true;
    }

    if (IsBetween(Fractal.Retrace.Event,NewRally,NewExtension))
    {
      Fractal.State        = State(Fractal.Retrace.Event);
      Fractal.Event        = Fractal.Retrace.Event;
      Fractal.Pivot.Price  = Fractal.Retrace.Pivot;

      return true;
    }

    return false;
  }

//+------------------------------------------------------------------+
//| InitPivot - Initializes Pivot from Last Event                    |
//+------------------------------------------------------------------+
void CFractal::InitPivot(PivotRec &Pivot, EventLog &Log)
  {
    Pivot.Event      = Log.Event;
    Pivot.Price      = Log.Price;
    Pivot.Open       = fClose;
    Pivot.High       = fmax(fClose,Pivot.Price);
    Pivot.Low        = fmin(fClose,Pivot.Price);
    Pivot.Lead       = Action(fClose-Pivot.Price);
    Pivot.Bias       = Pivot.Lead;
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
        frec[type].State       = Breakout;

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

      //-- Initialize Fractal Buffer
      fbuf[fBar+1]    = frec[Term].Fractal[fpRoot];
      fbuf[fBar]      = frec[Term].Fractal[fpExpansion];
      
      fbufBar         = fBar;
      fbufDirection   = frec[Term].Direction;
    }
  }

//+------------------------------------------------------------------+
//| UpdateFibonacci - Update Extension/Retrace using supplied Fractal|
//+------------------------------------------------------------------+
void CFractal::UpdateFibonacci(FibonacciRec &Extension,FibonacciRec &Retrace,double &Fractal[],bool Reset)
  {
    Extension.Event   = NoEvent;
    Retrace.Event     = NoEvent;

    //-- Handle Fractal Resets
    if (Reset)
    {
      //-- Reset Extension
      ArrayInitialize(Extension.Percent,fext(Fractal[fpBase],Fractal[fpRoot],Fractal[fpExpansion],InDecimal));
      Extension.Level          = Level(Extension.Percent[Max]);

      if (Extension.Percent[Max]>fibonacci[Fibo100])
      {
        Extension.Pivot        = Fractal[fpBase];
        Extension.Event        = BoolToEvent(fext(fpoint[fpBase],fpoint[fpRoot],fpoint[fpExpansion],InDecimal)>fibonacci[Fibo100],NewReversal,NewBreakout);

        Retrace.Level          = FiboRoot;
        Retrace.Pivot          = Fractal[fpExpansion];
      }      
      
      //-- Reset Retrace
      ArrayInitialize(Retrace.Percent,0.00);
      Retrace.Level            = FiboRoot;
    }
    else

    //-- Handle Interior Fractal Calcs
    {
      //-- Update Extension
      Extension.Percent[Now]   = fext(Fractal[fpBase],Fractal[fpRoot],Fractal[fpClose],InDecimal);
      Extension.Percent[Min]   = fext(Fractal[fpBase],Fractal[fpRoot],Fractal[fpRetrace],InDecimal);
      Extension.Percent[Max]   = fext(Fractal[fpBase],Fractal[fpRoot],Fractal[fpExpansion],InDecimal);

      if (IsHigher(Level(Extension.Percent[Max]),Extension.Level))
      {
        Extension.Event        = BoolToEvent(Extension.Level>Fibo100,NewExtension,NewFibonacci);
        Extension.Pivot        = fprice(Fractal[fpBase],Fractal[fpRoot],Extension.Level);
      }

      if (IsEqual(Extension.Percent[Min],Extension.Percent[Max],3))
      {
        //-- Handle Linear Breakouts
        if (Extension.Percent[Max]>fibonacci[Fibo100])
        {
          if (IsEqual(Extension.Event,NewFibonacci)||Retrace.Level>FiboRoot)
          {
            Extension.Pivot    = BoolToDouble(IsBetween(fpoint[fpExpansion],fpoint[fpRoot],fpoint[fpBase]),Fractal[fpBase],fpoint[fpExpansion]);
            Extension.Event    = NewBreakout;
          }

          Retrace.Level        = FiboRoot;
          Retrace.Pivot        = fClose;
        }

        //-- NewFibonacci Conflict Resolution (Event Merge)
        if (IsEqual(Extension.Event,NewFibonacci))
          if (IsEqual(Extension.Level,FiboCorrection))
            Extension.Event    = NewCorrection;
          else
          if (IsBetween(Extension.Level,Fibo50,Fibo61))
            Extension.Event    = NewRetrace;
          else
            Extension.Event    = BoolToEvent(IsEqual(Direction(Fractal[fpBase]-Fractal[fpRoot]),DirectionUp),NewRally,NewPullback);
      }

      //-- Update Retrace
      Retrace.Percent[Now]     = fret(Fractal[fpRoot],Fractal[fpExpansion],Fractal[fpClose],InDecimal);
      Retrace.Percent[Min]     = fret(Fractal[fpRoot],Fractal[fpExpansion],Fractal[fpRecovery],InDecimal);
      Retrace.Percent[Max]     = fret(Fractal[fpRoot],Fractal[fpExpansion],Fractal[fpRetrace],InDecimal);

      if (IsHigher(Level(Retrace.Percent[Max]),Retrace.Level))
      {
        Retrace.Event          = NewFibonacci;
        Retrace.Pivot          = fprice(Fractal[fpRoot],Fractal[fpExpansion],Retrace.Level);
      }

      //-- NewFibonacci Conflict Resolution (Event Merge)
      if (IsEqual(Retrace.Percent[Min],Retrace.Percent[Max],3))
        if (IsEqual(Retrace.Event,NewFibonacci))
          if (IsEqual(Retrace.Level,FiboCorrection))
            Retrace.Event      = BoolToEvent(Extension.Percent[Now]>fibonacci[FiboCorrection],NewRecovery,NewCorrection);
          else
          if (IsBetween(Retrace.Level,Fibo50,Fibo61))
            Retrace.Event      = NewRetrace;
          else
          if (IsBetween(Retrace.Level,Fibo23,Fibo38))
            Retrace.Event      = BoolToEvent(IsEqual(Direction(Fractal[fpBase]-Fractal[fpRoot]),DirectionUp),NewPullback,NewRally);
    }

    SetEvent(Extension.Event,Nominal,Extension.Pivot);
    SetEvent(Retrace.Event,Nominal,Retrace.Pivot);
  }

//+------------------------------------------------------------------+
//| UpdatePivot - Updates Pivot on the Tick                          |
//+------------------------------------------------------------------+
void CFractal::UpdatePivot(PivotRec &Pivot)
  {
    Pivot.Event      = NoEvent;

    if (NewAction(Pivot.Bias,Action(fClose-Pivot.Price)))
      Pivot.Event    = NewBias;

    if (IsHigher(fClose,Pivot.High))
      if (NewAction(Pivot.Lead,OP_BUY))
        Pivot.Event  = NewLead;
      
    if (IsLower(fClose,Pivot.Low))
      if (NewAction(Pivot.Lead,OP_SELL))
        Pivot.Event  = NewLead;

    SetEvent(Pivot.Event,Nominal,fClose);
  }

//+------------------------------------------------------------------+
//| UpdateTerm - Updates term fractal bounds and buffers             |
//+------------------------------------------------------------------+
void CFractal::UpdateTerm(void)
  {
    //-- Hold copy for State comparisons
    ArrayCopy(fpoint,frec[Term].Fractal);

    int           direction             = Direction(BoolToInt(fClose<fSupport,DirectionDown,
                                                    BoolToInt(fClose>fResistance,DirectionUp,NoDirection)));
    frec[Term].Event                    = NoEvent;
    frec[Term].Fractal[fpClose]         = fClose;

    //--- Check for Term Reversals
    if (Event(NewBoundary))
      if (NewDirection(frec[Term].Direction,direction))
      {
        frec[Term].Fractal[fpOrigin]    = frec[Term].Fractal[fpRoot];
        //frec[Term].Fractal[fpBase]      = BoolToDouble(IsBetween(fClose,frec[Term].Fractal[fpRoot],frec[Term].Fractal[fpExpansion]),
        //                                  BoolToDouble(fClose<fSupport,fSupport,BoolToDouble(fClose>fResistance,fResistance)),frec[Term].Fractal[fpRoot]);
        frec[Term].Fractal[fpBase]      = BoolToDouble(IsEqual(direction,DirectionUp),fResistance,fSupport,Digits);  //<-- Better than ^^ but doesn't handle Triplet+ Period Reversals (see Quintuple issue"
        frec[Term].Fractal[fpRoot]      = frec[Term].Fractal[fpExpansion];

        SetEvent(NewTerm,Minor,frec[Term].Fractal[fpBase]);
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

    UpdateFibonacci(frec[Term].Extension,frec[Term].Retrace,frec[Term].Fractal,Event(NewTerm));
    UpdatePivot(frec[Term].Pivot);

    if (NewState(frec[Term]))
    {
      SetEvent(NewState,Minor,fClose);
      SetEvent(frec[Term].Event,Minor,frec[Term].Pivot.Price);

      InitPivot(frec[Term].Pivot,LastEvent());
      Flag(Term);      
    }
  }

//+------------------------------------------------------------------+
//| UpdateTrend - Updates trend fractal bounds and state             |
//+------------------------------------------------------------------+
void CFractal::UpdateTrend(void)
  {
    //-- Hold copy for State comparisons
    ArrayCopy(fpoint,frec[Trend].Fractal);

    //--- Set Common Fractal Points
    frec[Trend].Event                   = NoEvent;
    frec[Trend].Fractal[fpRetrace]      = frec[Term].Fractal[fpRetrace];
    frec[Trend].Fractal[fpRecovery]     = frec[Term].Fractal[fpRecovery];
    frec[Trend].Fractal[fpClose]        = frec[Term].Fractal[fpClose];

    //--- Handle Term Reversals 
    if (Event(NewTerm))
    {
      frec[Trend].Direction             = frec[Term].Direction;
      frec[Trend].Fractal[fpOrigin]     = frec[Term].Fractal[fpRoot];
      frec[Trend].Fractal[fpBase]       = frec[Term].Fractal[fpOrigin];
      frec[Trend].Fractal[fpRoot]       = frec[Term].Fractal[fpRoot];
    }

    //--- Handle Trend Interior States)
    if (IsChanged(frec[Trend].Fractal[fpExpansion],frec[Term].Fractal[fpExpansion]))
      if (fext(frec[Trend].Fractal[fpBase],frec[Trend].Fractal[fpRoot],frec[Trend].Fractal[fpExpansion],InDecimal)>fibonacci[Fibo100])
        if (NewDirection(frec[Origin].Direction,frec[Trend].Direction))
          SetEvent(NewTrend,Major,frec[Trend].Fractal[fpBase]);

    UpdateFibonacci(frec[Trend].Extension,frec[Trend].Retrace,frec[Trend].Fractal,Event(NewTerm)||Event(NewTrend));
    UpdatePivot(frec[Trend].Pivot);

    if (NewState(frec[Trend]))
    {
      SetEvent(NewState,Major,fClose);
      SetEvent(frec[Trend].Event,Major,frec[Trend].Pivot.Price);

      InitPivot(frec[Trend].Pivot,LastEvent());
      Flag(Trend);
    }
  }

//+------------------------------------------------------------------+
//| UpdateOrigin - Updates origin fractal bounds and state           |
//+------------------------------------------------------------------+
void CFractal::UpdateOrigin(void)
  {
    //-- Hold copy for State comparisons
    ArrayCopy(fpoint,frec[Origin].Fractal);

    frec[Origin].Event                  = NoEvent;
    frec[Origin].Fractal[fpClose]       = frec[Term].Fractal[fpClose];

    if (Event(NewTrend))
    {
      frec[Origin]                      = frec[Trend];
      frec[Origin].Fractal[fpOrigin]    = fpoint[fpExpansion];
      frec[Origin].Fractal[fpRoot]      = fpoint[fpExpansion];

      SetEvent(NewOrigin,Critical);
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
      
    UpdateFibonacci(frec[Origin].Extension,frec[Origin].Retrace,frec[Origin].Fractal,Event(NewOrigin));
    UpdatePivot(frec[Origin].Pivot);

    if (NewState(frec[Origin]))
    {
      SetEvent(NewState,Critical,fClose);
      SetEvent(frec[Origin].Event,Critical,frec[Origin].Pivot.Price);

      InitPivot(frec[Origin].Pivot,LastEvent());
      Flag(Origin);
    }
  }


//+------------------------------------------------------------------+
//| UpdateFractal - Check/Apply Corrections to Fractal before Update |
//+------------------------------------------------------------------+
void CFractal::UpdateFractal(void)
  {
    fLow      = BoolToDouble(fBar==0,Close[fBar],Low[fBar]);
    fHigh     = BoolToDouble(fBar==0,Close[fBar],High[fBar]);
    fClose    = BoolToDouble(frec[Term].Direction==DirectionUp,fHigh,fLow);

    if (IsEqual(frec[Term].Direction,NewDirection))
      InitFractal();
    else
    {
      //-- Handle Anomalies; set effective Fractal prices
      if (High[fBar]>fResistance)
      {
        if (Low[fBar]<fSupport)
        {
          //-- Handle Outside Reversal Anomalies (Historical only)
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
        
      UpdateTerm();
      UpdateTrend();
      UpdateOrigin();
    }
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

    //-- Push Buffer post Zero Bar after Outside Reversal Anomaly
    if (fBar<fbufBar)
      if (IsChanged(fbufDirection,frec[Term].Direction,NoUpdate))
        UpdateBuffer();
  }
  
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFractal::CFractal(bool ShowFlags=false)
  {
    fBar                             = Bars-1;
    fBars                            = Bars;

    fHigh                            = High[fBar];
    fLow                             = Low[fBar];
    
    fObjectStr                       = "[fractal]";
    fShowFlags                       = ShowFlags;

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
//| Update - Updates fractal Term based on supplied values           |
//+------------------------------------------------------------------+
void CFractal::UpdateFractal(double Support, double Resistance, double Pivot, int Bar)
  {
    fBar                         = Bar;
    fDirection                   = Direction(Close[Bar]-Pivot);

    fSupport                     = Support;
    fResistance                  = Resistance;
    fPivot                       = Pivot;

    ManageBuffer();
    UpdateFractal();
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
//| Event(State) - Returns the Event on change in Fractal State      |
//+------------------------------------------------------------------+
EventType CFractal::Event(FractalState State)
  {
    static const EventType event[FractalStates]  = {NoEvent,NewRally,NewPullback,NewRetrace,NewCorrection,NewRecovery,NewBreakout,NewReversal,
                                                    NewExtension,NewFlatline,NewConsolidation,NewParabolic,NewChannel};
    return event[State];
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
//| State - Returns the Fractal State of the supplied Event          |
//+------------------------------------------------------------------+
FractalState CFractal::State(EventType Event)
  {
    switch(Event)
    {
      case NewRally:       return Rally;
      case NewPullback:    return Pullback;
      case NewRetrace:     return Retrace;
      case NewCorrection:  return Correction;
      case NewRecovery:    return Recovery;
      case NewBreakout:    return Breakout;
      case NewReversal:    return Reversal;
      case NewExtension:   return Extension;
    }

    return NoState;
  }

//+------------------------------------------------------------------+
//| Level - Returns the FiboLevel based on extended fibonacci        |
//+------------------------------------------------------------------+
FibonacciType CFractal::Level(double Percent)
  {
    for (FibonacciType level=Fibo823;level>FiboRoot;level--)
      if (Percent>fibonacci[level])
        return (level);

    return (FiboRoot);
  }

//+------------------------------------------------------------------+
//| Price - Returns price for supplied Level/Type/State              |
//+------------------------------------------------------------------+
double CFractal::Price(FibonacciType Level, FractalType Type, FractalState Method)
  {
    switch (Method)
    {
      case Rally:       return Price(Fibo23,Type,Correction);
      case Pullback:    return Price(Fibo23,Type,Retrace);
      case Retrace:     return NormalizeDouble(frec[Type].Fractal[fpExpansion]-((frec[Type].Fractal[Base]-frec[Type].Fractal[fpRoot])*fibonacci[Level]),Digits);
      case Correction:  return NormalizeDouble(frec[Type].Fractal[fpRoot]+((frec[Type].Fractal[fpExpansion]-frec[Type].Fractal[fpRoot])*fibonacci[Level]),Digits);
      case Recovery:    return Price(Fibo23,Type,Retrace);
      case Extension:   return NormalizeDouble(frec[Type].Fractal[fpRoot]+((frec[Type].Fractal[fpBase]-frec[Type].Fractal[fpRoot])*fibonacci[Level]),Digits);
      default:          return NoValue;
    }
  }

//+------------------------------------------------------------------+
//| Price - Returns price from supplied level, Root/[Base|Expansion] |
//+------------------------------------------------------------------+
double CFractal::Price(FibonacciType Level, double Root, double Reference, FractalState Method)
  {
    switch (Method)
    {
      case Retrace:   return NormalizeDouble(Reference-((Reference-Root)*fibonacci[Level]),Digits);
      case Extension: return NormalizeDouble(Root+((Reference-Root)*fibonacci[Level]),Digits);
      default:        return NoValue;
    }
  }

//+------------------------------------------------------------------+
//| BufferStr - Returns formatted Buffer data for supplied Period    |
//+------------------------------------------------------------------+
string CFractal::BufferStr(int Node)
  {  
    string text            = "Fractal";

    Append(text,(string)Node,"|");
    Append(text,TimeToStr(Time[Node]),"|");
    Append(text,DoubleToStr(fbuf[Node],Digits),"|");

    return text;
  }

//+------------------------------------------------------------------+
//| PointStr - Returns formatted Points for supplied Fractal         |
//+------------------------------------------------------------------+
string CFractal::PointStr(double &Fractal[])
  {
    string text    = "";

    for (int point=0;point<FractalPoints;point++)
      Append(text,DoubleToStr(Fractal[point],Digits),"|");

    return text;
  }

//+------------------------------------------------------------------+
//| FibonacciStr - Returns formatted text for supplied Fibonacci     |
//+------------------------------------------------------------------+
string CFractal::FibonacciStr(FractalState State, FibonacciRec &Fibonacci)
  {
    string text    = "";

    Append(text,EnumToString(State));
    Append(text,EnumToString(Fibonacci.Level),"|");
    Append(text,DoubleToStr(Fibonacci.Pivot,Digits),"|");
    
    for (MeasureType measure=0;measure<MeasureTypes;measure++)
      Append(text,DoubleToStr(Fibonacci.Percent[measure]*100,1),"|");
    
    return text;
  }

//+------------------------------------------------------------------+
//| FractalStr - Returns formatted Fractal prices by supplied Type   |
//+------------------------------------------------------------------+
string CFractal::FractalStr(FractalType Type)
  {
    string text    = "";

    Append(text,EnumToString(Type));
    Append(text,DirText(frec[Type].Direction),"|");
    Append(text,EnumToString(frec[Type].State),"|");
    Append(text,EnumToString(frec[Type].Event),"|");
    Append(text,PointStr(frec[Type].Fractal),"|");
    Append(text,FibonacciStr(Extension,frec[Type].Extension),"|");
    Append(text,FibonacciStr(Retrace,frec[Type].Retrace),"|");

    return text;
  }
  

//-- General purpose functions

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(FractalType &Check, FractalType Compare, bool Update=true)
  {
    if (Check==Compare)
      return false;
   
    if (Update) 
      Check   = Compare;
  
    return true;
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(FractalState &Check, FractalState Compare, bool Update=true)
  {
    if (Check==Compare)
      return false;
   
    if (Update) 
      Check   = Compare;
  
    return true;
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(FibonacciType &Check, FibonacciType Compare, bool Update=true)
  {
    if (Check==Compare)
      return false;
   
    if (Update) 
      Check   = Compare;
  
    return true;
  }

//+------------------------------------------------------------------+
//| IsHigher - Returns true on higher FibonacciType                  |
//+------------------------------------------------------------------+
bool IsHigher(FibonacciType Check, FibonacciType &Change, bool Update=true)
  {
    if (Check>Change)
      return (IsChanged(Change,Check,Update));

    return (false);
  }

bool IsEqual(FractalType Source, FractalType Compare)     {return Source==Compare;};
bool IsEqual(FractalState Source, FractalState Compare)   {return Source==Compare;};
bool IsEqual(FibonacciType Source, FibonacciType Compare) {return Source==Compare;};
 
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

color Color(FractalType Type, int Direction=DirectionUp)
  {
    switch (Direction)
    {
      case NoDirection:    switch(Type)
                           {
                             case Origin: return C'64,128,250';
                             case Trend:  return C'64,128,200';
                             case Term:   return C'64,128,150';
                           }
      case DirectionUp:    switch(Type)
                           {
                             case Origin: return C'00,250,00';
                             case Trend:  return C'00,200,00';
                             case Term:   return C'00,150,00';
                           }
      case DirectionDown:  switch(Type)
                           {
                             case Origin: return C'250,00,00';
                             case Trend:  return C'200,00,00';
                             case Term:   return C'150,00,00';
                           }
      case NewDirection:   switch(Type)
                           {
                             case Origin: return C'250,250,00';
                             case Trend:  return C'200,200,00';
                             case Term:   return C'150,150,00';
                           }
    }
    
    return clrDarkGray;
  }