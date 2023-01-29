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
                     Recovery,        // Trend resumption post-correction
                     Correction,      // Fractal max stress point/Market Correction
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
           int           Direction;
           int           Bias;
           FractalState  State;
           EventType     Event;
           double        Pivot;
           double        Point[FractalPoints];
         };

static const string    FractalTag[FractalTypes]     = {"(o)","(tr)","(tm)","(p)","(b)","(r)","(e)","(d)","(c)","(iv)","(cv)","(l)"};
static const EventType FractalEvent[FractalStates]  = {NoEvent,NewRally,NewPullback,NewRetrace,NewRecovery,NewCorrection,NewBreakout,NewReversal};

//+------------------------------------------------------------------+
//| Color - Returns the color assigned to a specific Fractal Event   |
//+------------------------------------------------------------------+
color Color(FractalState State)
  {
    static const color  statecolor[FractalStates]  = {clrNONE,clrLawnGreen,clrFireBrick,clrGoldenrod,clrSteelBlue,clrWhite,clrYellow,clrRed};

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
//| Price - Derived price for a variable fibonacci level             |
//+------------------------------------------------------------------+
double Price(FiboLevel Level, double Root, double Extension, int Method=Expansion)
  {
    if (Method == Retrace)     
      return (NormalizeDouble(Extension-((Extension-Root)*Percent(Level)),Digits));

    return (NormalizeDouble(Root+((Extension-Root)*Percent(Level)),Digits));
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
//| NewState - Returns true on change to a Fractal State             |
//+------------------------------------------------------------------+
bool NewState(FractalRec &Fractal, int Bar=0, bool Reversing=false)
  {
    double retrace       = Retrace(Fractal.Point[fpRoot],Fractal.Point[fpExpansion],Fractal.Point[fpRetrace]);
    double pivot         = NoValue;

    if (Reversing)
      return (NewState(Fractal.State,(FractalState)Reversal));
      
    if (retrace>FiboCorrection)
      if (Retrace(Fractal.Point[fpRoot],Fractal.Point[fpExpansion],Fractal.Point[fpRecovery])<FiboRecovery)
        return (NewState(Fractal.State,(FractalState)Recovery));
      else
        return (NewState(Fractal.State,(FractalState)Correction));

    if (retrace>FiboRetrace)
    {
      if (IsEqual(Fractal.Point[fpRecovery],BoolToDouble(IsEqual(Fractal.Direction,DirectionUp),High[Bar],Low[Bar]),Digits))
        if (Retrace(Fractal.Point[fpExpansion],Fractal.Point[fpRetrace],Fractal.Point[fpRecovery])>FiboRecovery)
        {
          if (Fractal.State!=(FractalState)BoolToInt(IsEqual(Fractal.Direction,DirectionUp),Rally,Pullback))
            Flag("Before:"+EnumToString(Fractal.State)+" After:"+EnumToString((FractalState)BoolToInt(IsEqual(Fractal.Direction,DirectionUp),Rally,Pullback)),clrGoldenrod,Bar,Close[Bar]);
          return (IsChanged(Fractal.State,(FractalState)BoolToInt(IsEqual(Fractal.Direction,DirectionUp),Rally,Pullback)));
        }
      
      if (IsEqual(Fractal.Point[fpRetrace],Fractal.Point[fpRecovery],Digits))
      {
        if (Fractal.State!=Retrace)
        Flag("NewRetrace",clrRed,Bar,Close[Bar]);
        return (NewState(Fractal.State,(FractalState)Retrace));
      }

//Print((string)Bar+": "+DoubleToStr(Retrace(Fractal.Point[fpRetrace],Fractal.Point[fpRecovery],BoolToDouble(IsEqual(Fractal.Direction,DirectionUp),Low[Bar],High[Bar]),InPercent),1)+"%  "+
//      DoubleToStr(Fractal.Point[fpRetrace],Digits)+"  "+DoubleToStr(Fractal.Point[fpRecovery],Digits)+"  "+DoubleToStr(BoolToDouble(IsEqual(Fractal.Direction,DirectionUp),Low[Bar],High[Bar]),Digits));

      if (Retrace(Fractal.Point[fpRoot],Fractal.Point[fpExpansion],Fractal.Point[fpRecovery])<FiboRecovery)
        if (Retrace(Fractal.Point[fpRetrace],Fractal.Point[fpRecovery],BoolToDouble(IsEqual(Fractal.Direction,DirectionUp),Low[Bar],High[Bar],Digits))>FiboRetrace)
        {
        if (Fractal.State!=(FractalState)BoolToInt(IsEqual(Fractal.Direction,DirectionUp),Pullback,Rally))
          Flag(EnumToString((FractalState)BoolToInt(IsEqual(Fractal.Direction,DirectionUp),Pullback,Rally)),clrYellow,Bar,Close[Bar]);
          return (IsChanged(Fractal.State,(FractalState)BoolToInt(IsEqual(Fractal.Direction,DirectionUp),Pullback,Rally)));
        }

      return (false);
    }

    if (retrace>FiboRecovery)
        {
        if (Fractal.State!=(FractalState)BoolToInt(IsEqual(Fractal.Direction,DirectionUp),Pullback,Rally))
          Flag(EnumToString((FractalState)BoolToInt(IsEqual(Fractal.Direction,DirectionUp),Pullback,Rally)),clrDarkGray,Bar,Close[Bar]);
      return (NewState(Fractal.State,(FractalState)BoolToInt(IsEqual(Fractal.Direction,DirectionUp),Pullback,Rally)));
      }
    return (NewState(Fractal.State,(FractalState)Breakout));
  }

//+------------------------------------------------------------------+
//| NewState - Returns true on change to a Fractal State             |
//+------------------------------------------------------------------+
bool NewState(FractalState &State, FractalState Change, bool Update=true)
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

    if (State==Retrace)
      if (Change==Reversal||Change==Breakout||Change==Correction)
        return(IsChanged(State,Change,Update));
      else return(false);

    if (Change==Recovery)
      return (false);

    return(IsChanged(State,Change,Update));
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

