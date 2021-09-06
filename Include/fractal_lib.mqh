//+------------------------------------------------------------------+
//|                                                  fractal_lib.mqh |
//|                                                 Dennis Jorgenson |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property strict

#include <stdutil.mqh>
#include <Class/Event.mqh>

  //--- Public fractal enums
  enum             FractalState       // Fractal States
                   {
                     NoState,
                     Rally,
                     Pullback,
                     Retrace,
                     Recovery,
                     Correction,
                     Trap,
                     Breakout,
                     Reversal,
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

  //--- Fibo Defines
  enum             FiboFormat
                   {
                     Unsigned,
                     Signed,
                     Extended
                   };

  enum             FibonacciLevel
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
                     Fibo823
                   };                     

  //-- Canonical Fractal Rec
  struct           FiboCalcRec
                   {
                     FibonacciLevel  Level;
                     double          Min;
                     double          Max;
                     double          Now;
                   };
  
  struct           FractalDetail
                   {
                     FractalType     Type;
                     FractalState    State;
                     int             Direction;
                     int             BreakoutDir;
                     int             Bias;
                     double          Age;
                     EventType       Event;
                     bool            Trigger;
                     FiboCalcRec     Range;
                     FiboCalcRec     Expansion;
                     FiboCalcRec     Retrace;
                     double          Points[FractalPoints];
                   };

static const double    FiboLevels[10] = {0.00,0.236,0.382,0.500,0.618,1.0,1.618,2.618,4.236,8.236};
static const EventType FractalEvent[FractalStates]  = {NoEvent,NewRally,NewPullback,NewRetrace,NewRecovery,NewCorrection,NewTrap,NewBreakout,NewReversal};

//+------------------------------------------------------------------+
//| FractalEvent - Returns the event associated by Fractal Event     |
//+------------------------------------------------------------------+
EventType FractalEvent(FractalState State)
  {
    return (FractalEvent[State]);
  }

//+------------------------------------------------------------------+
//| FractalEvent - Returns the event associated by Fractal Event     |
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
      case Convergent:   return(NewConvergence);
      case Divergent:    return(NewDivergence);
    };
    
    return (NoEvent);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(FractalType &Check, FractalType Compare, bool Update=true)
  {
    if (Check == Compare)
      return (false);
  
    if (Update)
      Check   = Compare;
  
    return (true);
  }

//+------------------------------------------------------------------+
//| FiboExt - Converts signed fibos to extended                      |
//+------------------------------------------------------------------+
int FiboExt(int Level)
  {
    if (Level<0)
    {
      Level  = fabs(Level);
      
      if (Level<10)
        Level += 10;
    }

    return (Level);
  }

//+------------------------------------------------------------------+
//| FiboSign - Converts extended fibos to signed                     |
//+------------------------------------------------------------------+
int FiboSign(int Level)
  {
    if (Level>10)
      return ((Level-10)*DirectionInverse);

    return (Level);
  }

//+------------------------------------------------------------------+
//| FiboPrice - linear fibonacci price for the supplied level        |
//+------------------------------------------------------------------+
double FiboPrice(FibonacciLevel Level, double Base, double Root, int Method=Expansion)
  {
    if (Level == 0 || fabs(Level) == 10)
    {
      if (Method == Retrace)     
        return (NormalizeDouble(Base,Digits));
        
      return (NormalizeDouble(Root,Digits));
    }  

    if (Method == Retrace)     
      return (NormalizeDouble(Base-((Base-Root)*FiboPercent(Level)),Digits));

    return (NormalizeDouble(Root+((Base-Root)*FiboPercent(Level)),Digits));
  }

//+------------------------------------------------------------------+
//| FiboPrice - Derived price for a variable fibonacci level         |
//+------------------------------------------------------------------+
double FiboPrice(double Fibo, double Base, double Root, int Method=Expansion)
  {
    if (Method == Retrace)     
      return (NormalizeDouble(Base-((Base-Root)*Fibo),Digits));

    return (NormalizeDouble(Root+((Base-Root)*Fibo),Digits));
  }

//+------------------------------------------------------------------+
//| FiboLevel - returns the level id for the supplied fibo value     |
//+------------------------------------------------------------------+
int FiboLevel(double Fibonacci, FiboFormat Format=Extended)
  {
    int    flFibo;
    
    for (flFibo=-Fibo823;flFibo<10;flFibo++)
      if (Fibonacci<FiboPercent(flFibo))
        break;

    if (Fibonacci<0.00)
      switch (Format)
      {
        case Unsigned:  flFibo = 0;
                        break;
        case Signed:    flFibo++;
                        break;
        case Extended:  if (flFibo != -Fibo823)
                          flFibo   = fabs(flFibo)+11;
      }
    else
      flFibo--;
    
    return(flFibo);
  }

//+------------------------------------------------------------------+
//| FiboExpansion - returns the Fibo expansion for supplied points   |
//+------------------------------------------------------------------+
double FiboExpansion(double Base, double Root, double Expansion, int Format=InDecimal)
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
//| FiboRetrace - returns the linear Fibo retrace for supplied points|
//+------------------------------------------------------------------+
double FiboRetrace(double Root, double Expansion, double Retrace, int Format=InDecimal)
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
//| FiboPercent - returns the Fibo percent for the supplied level    |
//+------------------------------------------------------------------+
double FiboPercent(int Level, int Format=InPoints, bool Signed=true)
  {
    int fpSign = 1;
    
    if (Signed)
    {
      if (Level<0)
      {
        Level  = fabs(Level);
        fpSign = -1;
      }
      
      if (Level>10)
      {
        Level -= 10;
        fpSign = -1;
      }
    }
       
    if (Level>Fibo823)
      Level       = Fibo823;
      
    if (Format == InPoints)
      return (NormalizeDouble(FiboLevels[Level],3)*fpSign);
      
    return (NormalizeDouble(FiboLevels[Level]*100,1)*fpSign);
  }

//+------------------------------------------------------------------+
//| IsLower - returns true if compare value lower than check         |
//+------------------------------------------------------------------+
bool IsLower(FibonacciLevel Compare, FibonacciLevel &Check, bool Update=true)
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
bool IsHigher(FibonacciLevel Compare, FibonacciLevel &Check, bool Update=true)
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
bool IsChanged(FractalState &Compare, FractalState Value)
  {
    if (Compare==Value)
      return (false);
      
    Compare = Value;
    return (true);
  }
