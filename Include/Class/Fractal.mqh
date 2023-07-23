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
         double          fHigh;
         double          fLow;
         double          fClose;
         int             fPeriod;
         
         string          fObjectStr;
         FractalType     fShowFlags;

         FractalRec      frec[FractalTypes];
         double          fpoint[FractalPoints];

         bool            NewState(FractalRec &Fractal, bool PrintLog=false);

         void            InitPivot(PivotRec &Pivot, EventLog &Log);
         void            InitFractal(void);

         void            UpdateFibonacci(FibonacciRec &Extension, FibonacciRec &Retrace, double &Fractal[], bool Reset);
         void            UpdatePivot(PivotRec &Pivot);
         void            UpdateFractal(FractalType Type, double Support, double Resistance);
         void            ManageFractal(void);

         void            UpdateBuffer(void);
         void            ManageBuffer(void);

public:
                         CFractal(int TimeFrame, FractalType ShowFlags);
                        ~CFractal();
                    
        void             UpdateFractal(double Support, double Resistance, double Pivot, int Bar);

        void             Flag(FractalType Type, bool FlagEvent=false);
        void             SetDisplayOptions(FractalType Type)  {fShowFlags=Type;};

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
        string           FibonacciStr(FibonacciRec &Fibonacci);
        string           PivotStr(PivotRec &Pivot);
        string           FractalStr(FractalType Type);
  };

//+------------------------------------------------------------------+
//| Flag - Creates a Flag on Fibonacci Events                        |
//+------------------------------------------------------------------+
void CFractal::Flag(FractalType Type, bool FlagEvent=false)
  {
    if (FlagEvent)
    {
      string name    = fObjectStr+EnumToString(Type)+":"+EnumToString(frec[Type].Event);
      int    shift   = iBarShift(Symbol(),Period(),iTime(Symbol(),fPeriod,fBar));
    
      if (IsEqual(frec[Type].State,Extension))
        Flag(name+" ["+DoubleToStr(percent(frec[Type].Extension.Level,InPercent),1)+"%]",Color(Type,NewDirection),shift,frec[Type].Pivot.Price,FlagEvent);
      else
      if (IsEqual(frec[Type].State,Reversal))
        Flag(name,Color(frec[Type].Direction),shift,frec[Type].Pivot.Price,FlagEvent);
      else
      if (IsEqual(frec[Type].State,Breakout))
        Flag(name,Color(Type,NewDirection),shift,frec[Type].Pivot.Price,FlagEvent);
      else
      if (IsEqual(frec[Type].State,Recovery))
        Flag(name,clrSteelBlue,shift,frec[Type].Pivot.Price,FlagEvent);
      else
      if (IsEqual(frec[Type].State,Correction))
        Flag(name,clrWhite,shift,frec[Type].Pivot.Price,FlagEvent);
      else
        Flag(name+" ["+DoubleToStr(percent(frec[Type].Retrace.Level,InPercent),1)+"%]",clrDarkGray,shift,frec[Type].Pivot.Price,FlagEvent);
    }
  }

//+------------------------------------------------------------------+
//| NewState - Returns true on detected change of Fibonacci State    |
//+------------------------------------------------------------------+
bool CFractal::NewState(FractalRec &Fractal, bool PrintLog=false)
  {
    if (IsBetween(Fractal.Extension.Event,NewRally,NewExtension))
    {
      Fractal.State        = State(Fractal.Extension.Event);
      Fractal.Event        = Fractal.Extension.Event;
      Fractal.Pivot.Price  = Fractal.Extension.Pivot;
      
      if (PrintLog) Print("|"+TimeToStr(Time[fBar])+"|Extension|"+FractalStr(Trend));
      return true;
    }

    if (IsBetween(Fractal.Retrace.Event,NewRally,NewExtension))
    {
      Fractal.State        = State(Fractal.Retrace.Event);
      Fractal.Event        = Fractal.Retrace.Event;
      Fractal.Pivot.Price  = Fractal.Retrace.Pivot;

      if (PrintLog) Print("|"+TimeToStr(Time[fBar])+"|Retrace|"+FractalStr(Trend));
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
    fHigh    = fmax(fHigh,iHigh(Symbol(),fPeriod,fBar));
    fLow     = fmin(fLow,iLow(Symbol(),fPeriod,fBar));

    if (fBar<Bars-1)
    {
      if (Event(NewHigh)&&Event(NewLow))
        return;

      for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
      {
        frec[type].Event       = Event(type);
        frec[type].State       = Breakout;

        frec[type].Fractal[fpRetrace]     = iClose(Symbol(),fPeriod,fBar);
        frec[type].Fractal[fpRecovery]    = iClose(Symbol(),fPeriod,fBar);
        frec[type].Fractal[fpClose]       = iClose(Symbol(),fPeriod,fBar);

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
      Extension.Pivot          = Fractal[fpBase];
      Extension.Event          = BoolToEvent(IsEqual(Fractal[fpRoot],fpoint[fpRoot]),NewBreakout,NewReversal);
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
        Extension.Event        = NewExtension;
        Extension.Pivot        = fprice(Fractal[fpBase],Fractal[fpRoot],Extension.Level);
      }

      //-- Handle New Extension
      if (IsEqual(Extension.Percent[Min],Extension.Percent[Max],3))
        if (Retrace.Level>FiboRoot)
        {
          Extension.Pivot    = BoolToDouble(IsBetween(fpoint[fpExpansion],fpoint[fpRoot],fpoint[fpBase]),Fractal[fpBase],fpoint[fpExpansion]);
          Extension.Event    = NewBreakout;
        }
    }
    
    //-- Reset Retrace
    if (Extension.Event>NoEvent)
    {
      ArrayInitialize(Retrace.Percent,0.00);
      Retrace.Level            = FiboRoot;
    }
    else
    
    //-- Update Retrace
    {
      FibonacciType min        = Level(Retrace.Percent[Min]);

      Retrace.Percent[Now]     = fret(Fractal[fpRoot],Fractal[fpExpansion],Fractal[fpClose],InDecimal);
      Retrace.Percent[Min]     = fret(Fractal[fpRoot],Fractal[fpExpansion],Fractal[fpRecovery],InDecimal);
      Retrace.Percent[Max]     = fret(Fractal[fpRoot],Fractal[fpExpansion],Fractal[fpRetrace],InDecimal);

      if (IsHigher(Level(Retrace.Percent[Max]),Retrace.Level))
      {
        if (IsEqual(Retrace.Level,FiboCorrection))
          Retrace.Event        = NewCorrection;
        else
        if (IsBetween(Retrace.Level,Fibo50,Fibo61))
          Retrace.Event        = NewRetrace;
        else
        if (IsBetween(Retrace.Level,Fibo23,Fibo38))
          Retrace.Event        = BoolToEvent(IsEqual(Direction(Fractal[fpBase]-Fractal[fpRoot]),DirectionUp),NewPullback,NewRally);

        Retrace.Pivot          = fprice(Fractal[fpRoot],Fractal[fpExpansion],Retrace.Level);
      }

      if (Retrace.Percent[Max]>fibonacci[FiboCorrection])
        if (IsLower(Level(Retrace.Percent[Min]),min))
          if (Retrace.Percent[Min]<fibonacci[Fibo23])
          {
            Retrace.Event      = NewRecovery;
            Retrace.Pivot      = fprice(Fractal[fpRoot],Fractal[fpExpansion],Fibo23);
          }
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
//| UpdateFractal - Updates fractal by Type                          |
//+------------------------------------------------------------------+
void CFractal::UpdateFractal(FractalType Type, double Support, double Resistance)
  {
    int direction                    = Direction(BoolToInt(fClose<Support,DirectionDown,
                                                 BoolToInt(fClose>Resistance,DirectionUp,NoDirection)));

    //-- Hold copy for State comparisons
    ArrayCopy(fpoint,frec[Type].Fractal);

    frec[Type].Event                 = NoEvent;
    frec[Type].Fractal[fpClose]      = fClose;

    //--- Handle Reversals
    if (NewDirection(frec[Type].Direction,direction))
    {
      frec[Type].Fractal[fpOrigin]    = frec[Type].Fractal[fpRoot];
      frec[Type].Fractal[fpBase]      = BoolToDouble(IsEqual(direction,DirectionUp),Resistance,Support,Digits);
      frec[Type].Fractal[fpRoot]      = frec[Type].Fractal[fpExpansion];

      //-- Handle *Special* Reversals
      if (Type==Trend)
        if (!IsEqual(frec[Origin].Direction,direction))
        {
          frec[Origin].Fractal[fpOrigin]    = frec[Origin].Fractal[fpRoot];
          frec[Origin].Fractal[fpRoot]      = fpoint[fpRoot];
          frec[Origin].Fractal[fpBase]      = fpoint[fpExpansion];
          frec[Origin].Fractal[fpExpansion] = fpoint[fpExpansion];
          frec[Origin].Fractal[fpRetrace]   = fClose;
          frec[Origin].Fractal[fpRecovery]  = fClose;
          frec[Origin].Extension.Level      = Fibo100;
        }

      SetEvent(Event(Type),Alert(Type),frec[Type].Fractal[fpBase]);
    }
    else
    
    //-- Handle *Special* Breakouts
    if (IsEqual(frec[Type].Direction,direction))
      if (Type==Trend)
        if (IsChanged(frec[Type].Fractal[fpBase],frec[Term].Fractal[fpOrigin]))
        {
          fpoint[fpExpansion]              = frec[Term].Fractal[fpOrigin];

          frec[Trend].Fractal[fpOrigin]    = frec[Trend].Fractal[fpRoot];
          frec[Trend].Fractal[fpRoot]      = frec[Term].Fractal[fpRoot];
          frec[Trend].Fractal[fpExpansion] = fpoint[fpExpansion];
          frec[Trend].Fractal[fpRetrace]   = fpoint[fpExpansion];
          frec[Trend].Fractal[fpRecovery]  = fpoint[fpExpansion];

          SetEvent(AdverseEvent,Minor,fClose);
        }

    //--- Check for Term Upper Boundary changes
    if (IsEqual(frec[Type].Direction,DirectionUp))
      if (IsHigher(fHigh,frec[Type].Fractal[fpExpansion]))
      {
        frec[Type].Fractal[fpRetrace]   = frec[Type].Fractal[fpExpansion];
        frec[Type].Fractal[fpRecovery]  = frec[Type].Fractal[fpExpansion];

        SetEvent(NewExpansion,Alert(Type),frec[Type].Fractal[fpExpansion]);
      }
      else 
      if (IsLower(fLow,frec[Type].Fractal[fpRetrace]))
        frec[Type].Fractal[fpRecovery]  = frec[Type].Fractal[fpRetrace];
      else
        frec[Type].Fractal[fpRecovery]  = fmax(fHigh,frec[Type].Fractal[fpRecovery]);
    else

    //--- Check for Type Lower Boundary changes
      if (IsLower(fClose,frec[Type].Fractal[fpExpansion]))
      {
        frec[Type].Fractal[fpRetrace]   = frec[Type].Fractal[fpExpansion];
        frec[Type].Fractal[fpRecovery]  = frec[Type].Fractal[fpExpansion];

        SetEvent(NewExpansion,Alert(Type),frec[Type].Fractal[fpExpansion]);
      }
      else
      if (IsHigher(fHigh,frec[Type].Fractal[fpRetrace]))
        frec[Type].Fractal[fpRecovery]  = frec[Type].Fractal[fpRetrace];
      else
        frec[Type].Fractal[fpRecovery]  = fmin(fLow,frec[Type].Fractal[fpRecovery]);

    UpdateFibonacci(frec[Type].Extension,frec[Type].Retrace,frec[Type].Fractal,!IsEqual(fpoint[fpRoot],frec[Type].Fractal[fpRoot]));
    UpdatePivot(frec[Type].Pivot);

    if (NewState(frec[Type]))
    {
      SetEvent(NewState,Alert(Type),fClose);
      SetEvent(frec[Type].Event,Alert(Type),frec[Type].Pivot.Price);

      InitPivot(frec[Type].Pivot,LastEvent());
      Flag(Type,Type==fShowFlags);
    }
  }

//+------------------------------------------------------------------+
//| UpdateFractal - Check/Apply Corrections to Fractal before Update |
//+------------------------------------------------------------------+
void CFractal::ManageFractal(void)
  {
    fLow      = BoolToDouble(fBar==0,iClose(Symbol(),fPeriod,fBar),iLow(Symbol(),fPeriod,fBar));
    fHigh     = BoolToDouble(fBar==0,iClose(Symbol(),fPeriod,fBar),iHigh(Symbol(),fPeriod,fBar));
    fClose    = BoolToDouble(frec[Term].Direction==DirectionUp,fHigh,fLow);

    if (IsEqual(frec[Term].Direction,NewDirection))
      InitFractal();
    else
    {
      //-- Handle Anomalies; set effective Fractal prices
      if (iHigh(Symbol(),fPeriod,fBar)>fResistance)
      {
        if (iLow(Symbol(),fPeriod,fBar)<fSupport)
        {
          //-- Handle Historical Outside Reversal Anomalies
          if (Event(NewHigh)&&Event(NewLow))
          {
            fClose   = BoolToDouble(IsEqual(fDirection,DirectionUp),fLow,fHigh);

            UpdateFractal(Term,fSupport,fResistance);
            UpdateFractal(Trend,fmin(frec[Term].Fractal[fpOrigin],frec[Term].Fractal[fpRoot]),fmax(frec[Term].Fractal[fpOrigin],frec[Term].Fractal[fpRoot]));
            UpdateFractal(Origin,fmin(frec[Origin].Fractal[fpRoot],frec[Origin].Fractal[fpBase]),fmax(frec[Origin].Fractal[fpRoot],frec[Origin].Fractal[fpBase]));
            UpdateBuffer();

            fClose   = BoolToDouble(IsEqual(fDirection,DirectionUp),fHigh,fLow);
          }
          else
        
          //-- Handle Hard Outside Anomaly Uptrend
          if (Event(NewHigh))
              fClose = fHigh;
          else

          //-- Handle Hard Outside Anomaly Downtrend
          if (Event(NewLow))
            fClose = fLow;
        }
        else

        //-- Handle Normal Uptrend Expansions
        if (Event(NewHigh))
          fClose   = fHigh;
      }
      else

      //-- Handle Normal Downtrend Expansions
      if (iLow(Symbol(),fPeriod,fBar)<fSupport)
        if (Event(NewLow))
          fClose   = fLow;

      UpdateFractal(Term,fSupport,fResistance);
      UpdateFractal(Trend,fmin(frec[Term].Fractal[fpOrigin],frec[Term].Fractal[fpRoot]),fmax(frec[Term].Fractal[fpOrigin],frec[Term].Fractal[fpRoot]));
      UpdateFractal(Origin,fmin(frec[Origin].Fractal[fpRoot],frec[Origin].Fractal[fpBase]),fmax(frec[Origin].Fractal[fpRoot],frec[Origin].Fractal[fpBase]));

      UpdateBuffer();
    }

    //if (Event(NewTrend))
    //  Print("|"+TimeToStr(Time[fBar])+"|"+FractalStr(Trend));    
  }

//+------------------------------------------------------------------+
//| UpdateBuffer - Apply changes to the Fractal Buffer               |
//+------------------------------------------------------------------+
void CFractal::UpdateBuffer(void)
  {
    if (Event(NewExpansion))
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
CFractal::CFractal(int TimeFrame, FractalType ShowFlags)
  {
    fBar                             = Bars-1;
    fBars                            = Bars;
    fPeriod                          = TimeFrame;
    
    fHigh                            = iHigh(Symbol(),fPeriod,fBar);
    fLow                             = iLow(Symbol(),fPeriod,fBar);

    fbufBar                          = 0;
    fbufDirection                    = NewDirection;
    frec[Term].Direction             = NewDirection;
    
    fObjectStr                       = "[fractal]";
    fShowFlags                       = ShowFlags;

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
    fDirection                   = Direction(iClose(Symbol(),fPeriod,fBar)-Pivot);

    fSupport                     = Support;
    fResistance                  = Resistance;

    ManageBuffer();
    ManageFractal();
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
string CFractal::FibonacciStr(FibonacciRec &Fibonacci)
  {
    string text    = "";

    Append(text,EnumToString(Fibonacci.Event));
    Append(text,EnumToString(Fibonacci.Level),"|");
    Append(text,DoubleToStr(Fibonacci.Pivot,Digits),"|");
    
    for (MeasureType measure=0;measure<MeasureTypes;measure++)
      Append(text,DoubleToStr(Fibonacci.Percent[measure]*100,1),"|");
    
    return text;
  }

//+------------------------------------------------------------------+
//| PivotStr - Returns formatted text for supplied Pivot             |
//+------------------------------------------------------------------+
string CFractal::PivotStr(PivotRec &Pivot)
  {
    string text    = "";

    Append(text,EnumToString(Pivot.Event));
    Append(text,ActionText(Pivot.Lead),"|");
    Append(text,ActionText(Pivot.Bias),"|");
    Append(text,DoubleToStr(Pivot.Price,Digits),"|");
    Append(text,DoubleToStr(Pivot.Open,Digits),"|");
    Append(text,DoubleToStr(Pivot.High,Digits),"|");
    Append(text,DoubleToStr(Pivot.Low,Digits),"|");

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
    Append(text,PivotStr(frec[Type].Pivot),"|");
    Append(text,FibonacciStr(frec[Type].Extension),"|");
    Append(text,FibonacciStr(frec[Type].Retrace),"|");
    Append(text,PointStr(frec[Type].Fractal),"|");

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

//+------------------------------------------------------------------+
//| IsLower - Returns true on lower FibonacciType                    |
//+------------------------------------------------------------------+
bool IsLower(FibonacciType Check, FibonacciType &Change, bool Update=true)
  {
    if (Check<Change)
      return (IsChanged(Change,Check,Update));

    return false;
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