//+------------------------------------------------------------------+
//|                                                      Fractal.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class\ArrayDouble.mqh>
#include <stdutil.mqh>
#include <std_utility.mqh>

//+------------------------------------------------------------------+
//| CFractal Class Methods and Properties                            |
//+------------------------------------------------------------------+
class CFractal
  {

private:

       struct FractalRec
       {
         int           Direction;
         int           Bar;
         double        Price;
         bool          Peg;
         bool          Reversal;
         bool          Breakout;
         datetime      Updated;
       };
       
       struct OriginRec
       {
         int           Direction;
         int           Bar;
         double        Price;
         double        Top;
         double        Bottom;
         ReservedWords State;
         datetime      Updated;
       };

       FractalRec    f[RetraceTypeMembers];
       FractalRec    fOrigin;               //--- Actual origin data
       OriginRec     dOrigin;               //--- Derived origin data

       CArrayDouble *fBuffer;


       //--- Input parameter conversions
       double        fRange;                //--- inpRange converted to points
       double        fRangeMin;             //--- inpRangeMin converted to points


       //--- Private fractal methods
       void          InitFractal();                          //--- initializes the fractal
       void          CalcFractal(void);                      //--- computes the fractal on the tick
       void          UpdateFractal(int Direction);           //--- Updates fractal leg direction changes
       void          InsertFractal(FractalRec &Fractal);     //--- inserts a new fractal leg
       
       void          CalcRetrace(void);                                             //--- calculates retraces on the tick
       void          UpdateRetrace(RetraceType Type, int Bar, double Price=0.00);   //--- Updates interior fractal changes
       void          BarUpdate(void);                                               //--- handles buffer period shifts

       void          CalcOrigin(void);      //--- calculates origin derivatives on the tick
       
       //--- Fractal leg properties
       int           fDirection;            //--- Current fractal leg direction
       int           fBarNow;               //--- Currently executing bar id fractal leg direction
       int           fBarHigh;              //--- Fractal top
       int           fBarLow;               //--- Fractal bottom
       double        fRetracePrice;         //--- Current fractal leg retrace price

       RetraceType   fStateNow;             //--- Current leg state
       RetraceType   fStateMajor;           //--- Most recent major leg
       RetraceType   fStateMinor;           //--- Most recent minor leg
       RetraceType   fDominantTrend;        //--- Current dominant trend; largest fractal leg
       RetraceType   fDominantTerm;         //--- Current dominant term; last leg greater tha RangeMax
       
       bool          fEvents[EventTypes];

public:

       //--- Fractal constructor/destructor
                     CFractal(int Range, int MinRange);
                    ~CFractal(void);
                    

       //--- Fractal refresh methods
       void          Update(void);
       void          UpdateBuffer(double &Fractal[]);
       void          RefreshScreen(void);

       int           Origin(const ReservedWords Measure);
       int           Direction(RetraceType Type=Expansion, bool Contrarian=false, int Format=InDirection);
       
       double        Price(RetraceType Type, ReservedWords Measure=Now);                             //--- Current retrace type price by measure
       double        Price(ReservedWords Type, ReservedWords Measure=Now);                           //--- Current origin price by measure

       double        Range(RetraceType Type, ReservedWords Measure=Max, int Format=InPoints);        //--- For each retrace type
       double        Range(ReservedWords Type, ReservedWords Measure=Max, int Format=InPoints);      //--- For Origin
       
       double        Fibonacci(RetraceType Type, int Method, int Measure, int Format=InDecimal);     //--- For each retrace type
       double        Fibonacci(ReservedWords Type, int Method, int Measure, int Format=InDecimal);   //--- For Origin

       RetraceType   Next(RetraceType Type)          { return((RetraceType)fmin(Actual,Type+1)); }   //--- enum typecast for the Next element
       RetraceType   Previous(RetraceType Type)      { return((RetraceType)fmax(Trend,Type-1)); }    //--- enum typecast for the Prior element
       RetraceType   Dominant(RetraceType TimeRange) { if (TimeRange == Trend) return (fDominantTrend); return (fDominantTerm); }

       RetraceType   State(ReservedWords Level=Now);

       bool          IsMajor(const RetraceType Type);
       bool          IsMinor(const RetraceType Type);
       
       bool          IsDivergent(void)               { if (this.IsMajor(Divergent))   return (true); return (false); }
       bool          IsConvergent(void)              { if (this.IsMajor(Convergent))  return (true); return (false); }
       bool          IsInvergent(void)               { if (this.IsMajor(Inversion))   return (true); return (false); }
       
       bool          IsReversal(void)                { if (this[Base].Reversal) return (true); return (false); }
       bool          IsBreakout(void)                { if (this[Base].Breakout) return (true); return (false); }

       bool          Event(const EventType Type)     { return (fEvents[Type]); }
       void          EventClear(void)                { ArrayInitialize(fEvents,false); }
       
       FractalRec operator[](const RetraceType Type) const { return(f[Type]); }
  };


//+------------------------------------------------------------------+
//| BarUpdate - updates bar pointers                                 |
//+------------------------------------------------------------------+
void CFractal::BarUpdate(void)
  {
    fBarHigh++;
    fBarLow++;
    
    for (RetraceType type=Trend;type<RetraceTypeMembers;type++)
      if (f[type].Bar>NoValue)
        f[type].Bar++;
              
    if (fOrigin.Bar>NoValue)
      fOrigin.Bar++;

    dOrigin.Bar++;
    
    fBuffer.Insert(0,0.00);
  }
  
//+------------------------------------------------------------------+
//| Origin - returns integer measures for the Origin                 |
//+------------------------------------------------------------------+
int CFractal::Origin(const ReservedWords Measure)
  {
    switch (Measure)
    {
      case Age:          return (dOrigin.Bar);
      case Bar:          return (fOrigin.Bar);
      case Direction:    return (dOrigin.Direction);
      case State:        return (dOrigin.State);
    }
    
    return (NoValue);
  }
  
//+------------------------------------------------------------------+
//| CalcOrigin - computes origin derivatives                         |
//+------------------------------------------------------------------+
void CFractal::CalcOrigin(void)
  {
    //--- Boundary calc vars
    RetraceType coTopLeg       = Trend;
    RetraceType coBottomLeg    = Trend;
    
    //--- Compute Origin Boundaries
    for (RetraceType leg=Trend;leg<=Expansion;leg++)
      if (f[leg].Bar==NoValue)
      {
        coTopLeg               = this.Next(leg);
        coBottomLeg            = this.Next(leg);
      }
      else
      {
        if (this.Price(leg)>=this.Price(coTopLeg,Top))
          coTopLeg                  = leg;

        if (this.Price(leg)<=this.Price(coBottomLeg,Bottom))
          coBottomLeg               = leg;
      };

    //--- New Origin?
    if (fStateMajor==Expansion)
      if (Event(NewFractal))
        if (f[Expansion].Price>fmax(dOrigin.Top,dOrigin.Price) || f[Expansion].Price<fmin(dOrigin.Bottom,dOrigin.Price))
          fEvents[NewOrigin]        = true;
        else
          fEvents[InsideReversal]   = true;
      else
      if (f[Expansion].Direction!=dOrigin.Direction)
      {
        if (f[Expansion].Direction==DirectionUp && f[Expansion].Price>dOrigin.Price)
          fEvents[NewOrigin]        = true;
    
        if (f[Expansion].Direction==DirectionDown && f[Expansion].Price<dOrigin.Price)
          fEvents[NewOrigin]        = true;
      }

    if ((Event(NewMajor)&&fStateMajor==Divergent) || Event(NewOrigin) || Event(InsideReversal))
    {
      Print("Before:   Bar Now "+IntegerToString(fBarNow)+" "+TimeToStr(Time[fBarNow])+" "+BoolToStr(Event(NewOrigin),"Origin","Major")+BoolToStr(Event(InsideReversal)," Reversal")+" "+DirText(dOrigin.Direction));
      Print("      --> Origin: "+IntegerToString(dOrigin.Bar)+" (o)T:"+DoubleToStr(dOrigin.Top,Digits)+" (o)B:"+DoubleToStr(dOrigin.Bottom,Digits)+" (o)P:"+DoubleToStr(dOrigin.Price,Digits));
      Print("      --> Expansion: "+IntegerToString(f[Expansion].Bar)+" (e)T:"+DoubleToStr(Price(Expansion,Top),Digits)+" (e)B:"+DoubleToStr(Price(Expansion,Bottom),Digits)+" (e)P:"+DoubleToStr(f[Expansion].Price,Digits));

      Print("      --> Top Leg: "+EnumToString(coTopLeg)+" @"+IntegerToString(f[coTopLeg].Bar)+" (p):"+DoubleToStr(f[coTopLeg].Price,Digits));
      Print("      --> Bottom Leg: "+EnumToString(coBottomLeg)+" @"+IntegerToString(f[coBottomLeg].Bar)+" (p):"+DoubleToStr(f[coBottomLeg].Price,Digits));
    }

    if (Event(InsideReversal))
    {
      Print("      --> New Inside Reversal");

      if (dOrigin.State == Retrace)
        dOrigin.State            = Trap;
      else
        if (f[Expansion].Direction == dOrigin.Direction)
          dOrigin.State          = Continuation;
        else
          dOrigin.State          = Reversal;
    }
    else
    
    if (Event(NewOrigin))
    {
      Print("      --> New Origin");

      if (IsChanged(dOrigin.Direction,fDirection))
      {
        Print("      --> Origin Reversal");
        dOrigin.State            = Reversal;
      
        if (f[Expansion].Direction == DirectionUp)
        {
          dOrigin.Bar            = f[coBottomLeg].Bar;
          dOrigin.Price          = f[coBottomLeg].Price;
        }

        if (f[Expansion].Direction == DirectionDown)
        {
          dOrigin.Bar            = f[coTopLeg].Bar;
          dOrigin.Price          = f[coTopLeg].Price;
        }
      }
      else
      {
        Print("      --> Origin Breakout");
        dOrigin.State            = Breakout;
      }      
    }

    if (Event(NewFractal))
      if (f[Expansion].Reversal)
      {
        Print("      --> (e)Reversal: New Origin Top & Bottom");
        dOrigin.Top              = fmax(f[Base].Price,f[Root].Price);
        dOrigin.Bottom           = fmin(f[Base].Price,f[Root].Price);
      }
      else
      {
        Print("      --> (e)Breakout: New Origin Top OR Bottom");
        if (f[Expansion].Direction == DirectionUp)
          dOrigin.Top            = f[Base].Price;
        
        if (f[Expansion].Direction == DirectionDown)
          dOrigin.Bottom         = f[Base].Price;
      }
    else
        
    if (Event(NewMajor))
    {
      if (fStateMajor==Divergent)
      {
        Print("      --> Origin Peg (Divergent)");
        if (f[Expansion].Direction == dOrigin.Direction)
          dOrigin.State          = Retrace;
        else
          dOrigin.State          = Recovery;
          
        Print("      --> Origin is in "+EnumToString(dOrigin.State));
        if (f[Expansion].Direction == DirectionUp)
          dOrigin.Top            = f[Expansion].Price;
        
        if (f[Expansion].Direction == DirectionDown)
          dOrigin.Bottom         = f[Expansion].Price;
      }
      
      if (fStateMajor==Convergent)
      {
        Print("      --> Origin Peg (Convergent)");
        if (f[Expansion].Direction == dOrigin.Direction)
          dOrigin.State          = Continuation;
        else
          dOrigin.State          = Retrace;      
      }
    }
    
    if (dOrigin.State == Trap)
    {
      if (this.Fibonacci(Base,Expansion,Max)>FiboPercent(Fibo23)+1)
        dOrigin.State            = Reversal;
    }
    
    if ((Event(NewMajor)&&fStateMajor==Divergent) || Event(NewOrigin) || Event(InsideReversal))
    {
//      ObjectCreate("v"+TimeToStr(Time[fBarNow]),OBJ_VLINE,0,Time[fBarNow],0.00);
      Print("After @: "+EnumToString(dOrigin.State)+" "+DirText(Origin(Direction)));
      Print("      --> "+IntegerToString(dOrigin.Bar)+" (o)T:"+DoubleToStr(dOrigin.Top,Digits)+" (o)B:"+DoubleToStr(dOrigin.Bottom,Digits)+" (o)P:"+DoubleToStr(dOrigin.Price,Digits));
      Print("      --> "+EnumToString(coTopLeg)+" Top @:"+IntegerToString(f[coTopLeg].Bar)+" "+DoubleToStr(f[coTopLeg].Price,Digits)+" (a) "+DoubleToStr(Price(coTopLeg,Top),Digits));
      Print("      --> "+EnumToString(coBottomLeg)+" Bottom @:"+IntegerToString(f[coBottomLeg].Bar)+" "+DoubleToStr(f[coBottomLeg].Price,Digits)+" (a) "+DoubleToStr(Price(coBottomLeg,Bottom),Digits));
    }
  }
        
//+------------------------------------------------------------------+
//| UpdateRetrace - Updates the fractal record                       |
//+------------------------------------------------------------------+
void CFractal::UpdateRetrace(RetraceType Type, int Bar, double Price=0.00)
  {
    double lastRangeTrend    = 0.0;
    double lastRangeTerm     = fRange;
  
    for (RetraceType type=Type;type<RetraceTypeMembers;type++)
    {    
      //--- Initialize retrace data by type
      f[type].Direction      = DirectionNone;
      f[type].Bar            = NoValue;
      f[type].Price          = 0.00;
      f[type].Updated        = 0;

      if (type!=Expansion)
      {
        f[type].Peg          = false;
        f[type].Breakout     = false;
        f[type].Reversal     = false;
      }
    }
    
    if (Bar == NoValue)
      return;
      
    f[Type].Direction        = this.Direction(Type);
    f[Type].Bar              = Bar;
    f[Type].Price            = Price;
    f[Type].Updated          = Time[Bar];
    
    fRetracePrice            = Price;

    //--- Compute dominant legs
    for (RetraceType leg=Trend;leg<=Actual;leg++)
    {
      if (IsHigher(fabs(this.Price(leg,Previous)-this.Price(leg)),lastRangeTrend))
        fDominantTrend            = leg;

      if (IsHigher(fabs(this.Price(leg,Previous)-this.Price(leg)),lastRangeTerm,NoUpdate))
        fDominantTerm             = leg;      
    }              
  }
  
//+------------------------------------------------------------------+
//| CalcRetrace - calculates all interior retrace legs               |
//+------------------------------------------------------------------+
void CFractal::CalcRetrace(void)
  {
    RetraceType crStateMajor    = Expansion;
    RetraceType crStateMinor    = Expansion;
    
    //--- calc interior retraces    
    for (RetraceType type=Expansion;type<RetraceTypeMembers;type++)
    {
      if (this.Direction(type) == DirectionUp)
        if (f[type].Bar == NoValue)
          UpdateRetrace(type,fBarNow,High[fBarNow]);
        else
        if (IsHigher(High[fBarNow],f[type].Price))
          UpdateRetrace(type,fBarNow,High[fBarNow]);
      
      if (this.Direction(type) == DirectionDown)
        if (f[type].Bar == NoValue)
          UpdateRetrace(type,fBarNow,Low[fBarNow]);
        else
        if (IsLower(Low[fBarNow],f[type].Price))
          UpdateRetrace(type,fBarNow,Low[fBarNow]);
          
      if (this.IsMajor(type))
        crStateMajor            = type;

      if (this.IsMinor(type))
        crStateMinor            = type;

      if (f[type].Bar == fBarNow||type == Actual)
      {
        fStateNow               = type;
        
        if (this.Direction(fStateNow) == DirectionUp)
          fRetracePrice         = fmin(fRetracePrice,Close[fBarNow]);

        if (this.Direction(fStateNow) == DirectionDown)
          fRetracePrice         = fmax(fRetracePrice,Close[fBarNow]);

        break;
      }     

      if (type>Expansion)
        if (IsHigher(fabs(f[Previous(type)].Price-f[type].Price),fRange,false))
          f[Previous(type)].Peg = true;
    }

    //--- Calc fractal change events
    if (IsChanged(fStateMinor,crStateMinor))
      fEvents[NewMinor]         = true;
      
    if (IsChanged(fStateMajor,crStateMajor))
      fEvents[NewMajor]         = true;
  }

  
//+------------------------------------------------------------------+
//| InsertFractal - inserts a new fractal node                       |
//+------------------------------------------------------------------+
void CFractal::InsertFractal(FractalRec &Fractal)
  {
    Fractal.Peg            = false;
    Fractal.Breakout       = false;
    Fractal.Reversal       = false;
        
    fOrigin                = f[Trend];
    f[Trend]               = f[Term];
    f[Term]                = f[Prior];
    f[Prior]               = f[Base];
    f[Base]                = f[Root];
    f[Root]                = f[Expansion];
    f[Expansion]           = Fractal;
  }

//+------------------------------------------------------------------+
//| UpdateFractal - computes fractal legs and updates buffers        |
//+------------------------------------------------------------------+
void CFractal::UpdateFractal(int Direction)
  {
    f[Expansion].Peg           = false;
    
    InsertFractal(f[Divergent]);
    
    if (IsChanged(fDirection,Direction))
      f[Expansion].Reversal    = true;

    else
    {
      InsertFractal(f[Convergent]);
      
      f[Expansion].Breakout    = true;
      f[Root].Peg              = true;
    }

    fEvents[NewFractal]        = true;  //--- set new fractal alert
  }

//+------------------------------------------------------------------+
//| InitFractal - initialize Root and Expansion fractal legs         |
//+------------------------------------------------------------------+
void CFractal::InitFractal(void)
  {
    if (High[fBarHigh]-Low[fBarLow]>=fRange)
    {  
      if (fBarHigh<fBarLow)
      {
        fDirection            = DirectionUp;
      
        f[Root].Bar           = fBarLow;
        f[Root].Price         = Low[fBarLow];
      
        f[Expansion].Bar      = fBarHigh;
        f[Expansion].Price    = High[fBarHigh];

        dOrigin.Bar           = fBarLow;
        dOrigin.Price         = Low[fBarLow];
        dOrigin.Top           = dOrigin.Price+fRange;
        dOrigin.Bottom        = dOrigin.Price;
      }
    
      if (fBarHigh>fBarLow)
      {
        fDirection            = DirectionDown; 

        f[Root].Bar           = fBarHigh;
        f[Root].Price         = High[fBarHigh];

        f[Expansion].Bar      = fBarLow;
        f[Expansion].Price    = Low[fBarLow];

        dOrigin.Bar           = fBarHigh;
        dOrigin.Price         = High[fBarHigh];
        dOrigin.Top           = dOrigin.Price;
        dOrigin.Bottom        = dOrigin.Price-fRange;
      }
    
      dOrigin.Direction       = fDirection;
      dOrigin.State           = Breakout;
      dOrigin.Updated         = Time[fBarNow];

      f[Root].Direction       = fDirection*DirectionInverse;
      f[Root].Updated         = Time[fBarNow];

      f[Expansion].Direction  = fDirection;
      f[Expansion].Updated    = Time[fBarNow];
      f[Expansion].Breakout   = true;
    
      fBuffer.SetValue(fBarLow,NormalizeDouble(Low[fBarLow],Digits));
      fBuffer.SetValue(fBarHigh,NormalizeDouble(High[fBarHigh],Digits));
    }
  }

    
//+------------------------------------------------------------------+
//| CalcFractal - computes fractal legs and updates buffers          |
//+------------------------------------------------------------------+
void CFractal::CalcFractal(void)
  {
    int    lastBarHigh    = fBarHigh;
    int    lastBarLow     = fBarLow;
    bool   lastBasePeg    = f[Base].Peg;
    
    EventClear();         //--- reset Events on the tick
    
    //--- identify new high or new low
    if (NormalizeDouble(High[fBarNow],Digits)>NormalizeDouble(High[fBarHigh],Digits))
      fBarHigh            = fBarNow;
          
    if (NormalizeDouble(Low[fBarNow],Digits)<NormalizeDouble(Low[fBarLow],Digits))
      fBarLow             = fBarNow;

    //--- Handle initialization; Expansion, once set, is never unset
    if (f[Expansion].Bar==NoValue)
      InitFractal();
    else

    //--- Direction is known, process directional events
    {
      //--- Handle up-trends
      if (fDirection == DirectionUp)
      {
        //--- Check trend continuation
        if (fBarHigh == fBarNow)
        {            
          if (f[Expansion].Peg)
          {
            fBuffer.SetValue(f[Divergent].Bar,f[Divergent].Price);
            fBarLow            = f[Divergent].Bar;

            UpdateFractal(DirectionUp);
          }
          else
          if (lastBarHigh>fBarNow)
            fBuffer.SetValue(lastBarHigh,0.00);

          fBuffer.SetValue(fBarNow,High[fBarNow]);
        }
        else

        //--- Check trend change
        if (fBarLow == fBarNow)
        {
          fBuffer.SetValue(fBarNow,Low[fBarNow]);          
          UpdateFractal(DirectionDown);
        }
      }
      else

      //--- Handle down-trends
      if (fDirection == DirectionDown)
      {
        //--- Check trend continuation
        if (fBarLow == fBarNow)
        {
          if (f[Expansion].Peg)
          {
            fBuffer.SetValue(f[Divergent].Bar,f[Divergent].Price);
            fBarHigh         = f[Divergent].Bar;
            
            UpdateFractal(DirectionDown);
          }
          else
          if (lastBarLow>fBarNow)
            fBuffer.SetValue(lastBarLow,0.00);

          fBuffer.SetValue(fBarNow,Low[fBarNow]);
        }
        else

        //--- Check trend change
        if (fBarHigh == fBarNow)
        {
          fBuffer.SetValue(fBarNow,High[fBarNow]);

          UpdateFractal(DirectionUp);
        }
      }

      //--- Upgrade root peg
      if (this.Fibonacci(Base,Expansion,Max)>FiboPercent(Fibo161))
      {
        f[Root].Breakout      = true;
        f[Root].Reversal      = false;
      }
      
      //--- Calc retrace and origin
      CalcRetrace();
      CalcOrigin();
    }    
  }
    
//+------------------------------------------------------------------+
//| CFractal - class constructor                                     |
//+------------------------------------------------------------------+
CFractal::CFractal(int Range, int MinRange)
  {
    fDirection            = DirectionNone;
    fStateMajor           = Expansion;
    fStateMinor           = Expansion;

    fRange                = Pip(Range,InPoints);
    fRangeMin             = Pip(MinRange,InPoints);
    
    fBarHigh              = Bars-1;
    fBarLow               = Bars-1;

    fBuffer               = new CArrayDouble(Bars);
    fBuffer.Initialize(0.00);
    fBuffer.AutoExpand    = true;
    
    f[Expansion].Peg      = false;
    f[Expansion].Breakout = false;
    f[Expansion].Reversal = false;

    dOrigin.Bar           = NoValue;
    dOrigin.Direction     = DirectionNone;
        
    for (RetraceType Type=Trend;Type<RetraceTypeMembers;Type++)
      UpdateRetrace(Type,NoValue);

    for (fBarNow=Bars-1; fBarNow>0; fBarNow--)
      CalcFractal();
  }
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CFractal::~CFractal(void)
  {
    delete fBuffer;
  }
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CFractal::Update(void)
  {
    if (NewBar())
      BarUpdate();
    
    CalcFractal();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CFractal::UpdateBuffer(double &Fractal[])
  {
    Update();
    
    fBuffer.Copy(Fractal);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
RetraceType CFractal::State(ReservedWords Level=Now)
  {
    switch(Level)
    {
      case Now:     return(fStateNow);
      case Major:   return(fStateMajor);
      case Minor:   return(fStateMinor);
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| Price - Returns the origin derived price                         |
//+------------------------------------------------------------------+
double CFractal::Price(ReservedWords Type, ReservedWords Measure=Now)
  {
    if (Type==Origin)
    {
      switch (Measure)
      {
        case Now:       return (NormalizeDouble(dOrigin.Price,Digits));
        case Top:       return (NormalizeDouble(dOrigin.Top,Digits));
        case Bottom:    return (NormalizeDouble(dOrigin.Bottom,Digits));
        case Max:       return (NormalizeDouble(fmax(fmax(dOrigin.Top,f[Expansion].Price),dOrigin.Price),Digits));
        case Min:       return (NormalizeDouble(fmin(fmin(dOrigin.Bottom,f[Expansion].Price),dOrigin.Price),Digits));
        case Retrace:   if (dOrigin.Direction==f[fStateMajor].Direction)
                          if (fStateNow == fStateMajor)
                            return (NormalizeDouble(fRetracePrice,Digits));
                          else
                            return (NormalizeDouble(this.Price(Next(fStateMajor)),Digits));
                        else
                          return (NormalizeDouble(this.Price(fStateMajor),Digits));
      }
    }
    
    return (0.00);
  }
  
//+------------------------------------------------------------------+
//| Price - Returns the price relative to the data point root        |
//+------------------------------------------------------------------+
double CFractal::Price(RetraceType Type, ReservedWords Measure=Now)
  {
    switch (Measure)
    {
      case Top:    switch(Type)
                   {
                     case Trend:  return (NormalizeDouble(fmax(this.Price(Trend,Previous),fmax(f[Trend].Price,this.Price(Term,Top))),Digits));
                     case Term:   return (NormalizeDouble(fmax(f[Term].Price,this.Price(Prior,Top)),Digits));
                     case Prior:  if (f[Prior].Direction == DirectionUp)
                                    return (NormalizeDouble(fmax(f[Prior].Price,f[Root].Price),Digits));
                                  if (f[Prior].Direction == DirectionDown)
                                    return (NormalizeDouble(fmax(f[Base].Price,f[Expansion].Price),Digits));
                                  return (NormalizeDouble(0.00,Digits));
                     case Base:
                     case Root:   return (NormalizeDouble(fmax(f[Root].Price,f[Expansion].Price),Digits));
                     default:     return (NormalizeDouble(fmax(this.Price(Type),this.Price(Type,Previous)),Digits));
                   }
                   break;
                   
      case Bottom: switch(Type)
                   {
                     case Trend:  return (NormalizeDouble(fmin(this.Price(Trend,Previous),fmin(f[Trend].Price,this.Price(Term,Bottom))),Digits));
                     case Term:   return (NormalizeDouble(fmin(f[Term].Price,this.Price(Prior,Bottom)),Digits));
                     case Prior:  if (f[Prior].Direction == DirectionUp)
                                    return (NormalizeDouble(fmin(f[Base].Price,f[Expansion].Price),Digits));
                                  if (f[Prior].Direction == DirectionDown)
                                    return (NormalizeDouble(fmin(f[Prior].Price,f[Root].Price),Digits));
                                  return (NormalizeDouble(0.00,Digits));
                     case Base:
                     case Root:   return (NormalizeDouble(fmin(f[Root].Price,f[Expansion].Price),Digits));
                     default:     return (NormalizeDouble(fmin(this.Price(Type),this.Price(Type,Previous)),Digits));
                   }
                   break;
                   
      case Previous:  if (Type == Trend)
                        if (IsEqual(fOrigin.Price,0.00))
                        {
                          if (f[Trend].Direction==DirectionDown)
                            return (NormalizeDouble(High[Bars-1],Digits));

                          if (f[Trend].Direction==DirectionUp)
                            return (NormalizeDouble(Low[Bars-1],Digits));
                        }
                        else
                          return(NormalizeDouble(fOrigin.Price,Digits));

                      return(NormalizeDouble(f[Previous(Type)].Price,Digits));
                    
      case Now:       if (IsEqual(f[Type].Price,0.00))
                        if (IsEqual(this.Price(Type,Previous),0.00))
                          return (NormalizeDouble(0.00,Digits));
                        else
                          return (NormalizeDouble(fRetracePrice,Digits));
                      else
                        return (NormalizeDouble(f[Type].Price,Digits));

      case Next:      if (Type == fStateNow)
                        return(NormalizeDouble(fRetracePrice,Digits));

                      return(NormalizeDouble(f[Next(Type)].Price,Digits));
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| Direction - Returns the direction for the supplied type          |
//+------------------------------------------------------------------+
int CFractal::Direction(RetraceType Type=Expansion, bool Contrarian=false, int Format=InDirection)
  {
    int dDirection = fDirection;

    if (IsEqual(fmod(Type,2),0.00))
      dDirection   = fDirection*DirectionInverse;

    if (Contrarian||Type==Trend)
      dDirection  *= DirectionInverse;
      
    if (Format==InAction)
      switch(dDirection)
      {
        case DirectionUp:    return (OP_BUY);
        case DirectionDown:  return (OP_SELL);
        case DirectionNone:  return (NoValue);
      }
    
    return (dDirection);
  }

//+------------------------------------------------------------------+
//| Range - Returns the origin leg length for the supplied method    |
//+------------------------------------------------------------------+
double CFractal::Range(ReservedWords Type, ReservedWords Measure=Max, int Format=InPoints)
  {
    double range   = 0.00;

    if (Type==Origin)
    {
      switch (Measure)
      {
        case Now:      //-- Actual range now from origin start to current close
                       range   = fabs(Close[fBarNow]-dOrigin.Price);
                       break;

        case Max:      //-- Base-Root range where root is the origin start
                       switch (dOrigin.Direction)
                       {
                         case DirectionUp:   range = this.Price(Origin,Top)-dOrigin.Price;
                                             break;

                         case DirectionDown: range = dOrigin.Price-this.Price(Origin,Bottom);
                                             break;
                       }                         
                       break;

        case Active:   //-- Maximum range based on Major Fractal
                       if (dOrigin.Direction==f[fStateMajor].Direction)
                         range = fabs(this.Price(Origin)-this.Price(fStateMajor,Now));
                       else
                         range = fabs(this.Price(Origin)-this.Price(Next(fStateMajor),Now));
        
                       break;
      }
    }

    if (Type==Retrace)
    {
      switch (Measure)
      {
        case Now:      //-- Base-Current price
                       switch (dOrigin.Direction)
                       {
                         case DirectionUp:   range = this.Price(Origin,Top)-Close[fBarNow];
                                             break;

                         case DirectionDown: range = Close[fBarNow]-this.Price(Origin,Bottom);
                                             break;
                       }                         
                       break;

        case Max:      //-- Actual range now from origin expansion to retrace (linear retrace)
                       switch (dOrigin.Direction)
                       {
                         case DirectionUp:   range = this.Price(Origin,Max)-this.Price(Origin,Retrace);
                                             break;

                         case DirectionDown: range = this.Price(Origin,Retrace)-this.Price(Origin,Max);
                                             break;
                       }                         
                       break;

        case Active:   //-- Actual range now from origin base to retrace (geometric retrace)
                       switch (dOrigin.Direction)
                       {
                         case DirectionUp:   range = this.Price(Origin,Top)-this.Price(Origin,Retrace);
                                             break;

                         case DirectionDown: range = this.Price(Origin,Retrace)-this.Price(Origin,Bottom);
                                             break;
                       }                         
                       break;
      }
    }

    if (Format == InPips)
      return (Pip(range));

    if (Format == InPoints)
      return (NormalizeDouble(range,Digits));
      
    return (range);
  }
  
//+------------------------------------------------------------------+
//| Range - Returns the leg length for the supplied type             |
//+------------------------------------------------------------------+
double CFractal::Range(RetraceType Type, ReservedWords Measure=Max, int Format=InPoints)
  {
    double range   = 0.00;
    
    switch (Measure)
    {
      case Now:    if (this.Direction(Type) == DirectionUp)
                     if (this.Price(Type,Bottom)>0.0)
                       range  = Close[fBarNow]-this.Price(Type,Bottom);

                   if (this.Direction(Type) == DirectionDown)
                     if (this.Price(Type,Top)>0.0)
                       range  = this.Price(Type,Top)-Close[fBarNow];
                   break;

      case Max:    if (Type == Trend)
                     range    = this.Price(Trend,Top)-this.Price(Trend,Bottom);
                   else
                   {
                     if (this.Direction(Type) == DirectionUp)
                       range  = this.Price(Type)-this.Price(Type,Bottom);
                     if (this.Direction(Type) == DirectionDown)
                       range  = this.Price(Type,Top)-this.Price(Type);
                   }
    }

    if (Format == InPips)
      return (Pip(range));
      
    if (Format == InPoints)
      return (NormalizeDouble(range,Digits));
      
    return (0.00);
  }

//+------------------------------------------------------------------+
//| IsMajor - Returns the state of the leg based on length           |
//+------------------------------------------------------------------+
bool CFractal::IsMajor(RetraceType Type)
  {
    if (f[Type].Bar>NoValue)
      if (IsHigher(this.Range(Type),fRange,false))
        return (true);
        
    return (false);
  }

//+------------------------------------------------------------------+
//| IsMinor - Returns the state of the leg based on length           |
//+------------------------------------------------------------------+
bool CFractal::IsMinor(RetraceType Type)
  {
    if (!IsMajor(Type))
      if (IsHigher(this.Range(Type),fRangeMin,false))
        return (true);
    
    return (false);
  }
  
//+------------------------------------------------------------------+
//| Fibonacci - Calcuates fibo % for the Origin Type and Method      |
//+------------------------------------------------------------------+
double CFractal::Fibonacci(ReservedWords Type, int Method, int Measure, int Format=InDecimal)
  {
    double fibonacci     = 0.00;

    if (dOrigin.Bar == NoValue)
      return (0.00);

    if (Type == Origin)
      switch (Method)
      {
        case Retrace:   switch (Measure)
                        {
                          case Now: fibonacci = fdiv(this.Range(Retrace,Now),this.Range(Origin,Max));
                                    break;
                          
                          case Max: fibonacci = fdiv(this.Range(Retrace,Active),this.Range(Origin,Max));
                                    break;
                        }
                        break;

        case Expansion: switch (Measure)
                        {
                          case Now: fibonacci = fdiv(this.Range(Origin,Now),this.Range(Origin,Max));
                                    break;
                            
                          case Max: fibonacci = fdiv(this.Range(Origin,Active),this.Range(Origin,Max));
                                    break;
                        }
                        break;
      }  

    if (Format == InPercent)
      return (NormalizeDouble(fibonacci*100,3));
    
    return (NormalizeDouble(fibonacci,3));
  }

//+------------------------------------------------------------------+
//| Fibonacci - Calcuates fibo % for supplied type Type and Method   |
//+------------------------------------------------------------------+
double CFractal::Fibonacci(RetraceType Type, int Method, int Measure, int Format=InDecimal)
  {
    double fibonacci  = 0.00;

    if (Type > this.State(Now))
      return (0.00);
      
    switch (Method)
    {
      case Retrace:     switch (Measure)
                        {
                          case Now:  if (this.Direction(Expansion) == DirectionUp)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(this.Price(Trend,Previous)-Close[fBarNow],this.Price(Trend,Previous)-this.Price(Trend,Bottom),3);
                                                           break;

                                         case Term:
                                         case Base:
                                         case Expansion:   
                                         case Convergent:
                                         case Conversion:  fibonacci = fdiv(f[Type].Price-Close[fBarNow],f[Type].Price-this.Price(Type,Bottom),3);
                                                           break;

                                         default:          fibonacci = fdiv(f[Type].Price-Close[fBarNow],f[Type].Price-this.Price(Type,Top),3);
                                                           break;
                                       }
                                     
                                     if (this.Direction(Expansion) == DirectionDown)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(this.Price(Trend,Previous)-Close[fBarNow],this.Price(Trend,Previous)-this.Price(Trend,Top),3);
                                                           break;

                                         case Term:
                                         case Base:
                                         case Expansion:   
                                         case Convergent:
                                         case Conversion:  fibonacci = fdiv(f[Type].Price-Close[fBarNow],f[Type].Price-this.Price(Type,Top),3);
                                                           break;

                                         default:          fibonacci = fdiv(f[Type].Price-Close[fBarNow],f[Type].Price-this.Price(Type,Bottom),3);
                                                           break;
                                       }
                                     break;
                                     
                          case Max:  if (this.Direction(Expansion) == DirectionUp)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(this.Price(Trend,Previous)-this.Price(Divergent),this.Price(Trend,Previous)-this.Price(Trend,Bottom),3);
                                                           break;

                                         case Term:
                                         case Base:
                                         case Expansion:   fibonacci = fdiv(f[Type].Price-this.Price(Divergent),f[Type].Price-this.Price(Type,Bottom),3);
                                                           break;

                                         case Convergent:
                                         case Conversion:  fibonacci = fdiv(f[Type].Price-this.Price(Next(Type),Bottom),f[Type].Price-this.Price(Type,Bottom),3);
                                                           break;

                                         case Prior:
                                         case Root:        if (this.Price(Convergent)>0.00)
                                                             fibonacci = fdiv(f[Type].Price-this.Price(Convergent),f[Type].Price-f[Expansion].Price,3);
                                                           else
                                                             fibonacci = FiboPercent(Fibo100);
                                                           break;
                                                           
                                         default:          fibonacci = fdiv(f[Type].Price-this.Price(Next(Type),Top),f[Type].Price-this.Price(Type,Top),3);
                                                           break;
                                       }
                                     else

                                     if (this.Direction(Expansion) == DirectionDown)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(this.Price(Trend,Previous)-this.Price(Divergent),this.Price(Trend,Previous)-this.Price(Trend,Top),3);
                                                           break;

                                         case Term:
                                         case Base:
                                         case Expansion:   fibonacci = fdiv(f[Type].Price-this.Price(Divergent),f[Type].Price-this.Price(Type,Top),3);
                                                           break;

                                         case Convergent:
                                         case Conversion:  fibonacci = fdiv(f[Type].Price-this.Price(Next(Type),Top),f[Type].Price-this.Price(Type,Top),3);
                                                           break;

                                         case Prior:
                                         case Root:        if (this.Price(Convergent)>0.00)
                                                             fibonacci = fdiv(f[Type].Price-this.Price(Convergent),f[Type].Price-f[Expansion].Price,3);
                                                           else
                                                             fibonacci = FiboPercent(Fibo100);
                                                           break;
                                                           
                                         default:          fibonacci = fdiv(f[Type].Price-this.Price(Next(Type),Bottom),f[Type].Price-this.Price(Type,Bottom),3);
                                                           break;
                                       }
                        }
                        break;

      case Expansion:   switch (Measure)
                        {
                          case Now:  if (this.Direction(Expansion) == DirectionUp)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(Close[fBarNow]-this.Price(Trend,Bottom),this.Price(Trend,Previous)-this.Price(Trend,Bottom),3);
                                                           break;
                                         case Term:
                                         case Base:
                                         case Expansion:   fibonacci = fdiv(Close[fBarNow]-this.Price(Type,Bottom),this.Price(Type)-this.Price(Type,Bottom),3);
                                                           break;

                                         case Prior:
                                         case Root:        fibonacci = fdiv(f[Expansion].Price-Close[fBarNow],f[Expansion].Price-f[Type].Price,3);
                                                           break;

                                         default:          fibonacci = fdiv(this.Range(Type,Now),this.Range(Previous(Type),Max),3);
                                                           break;
                                       }
                                     
                                     if (this.Direction(Expansion) == DirectionDown)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(this.Price(Trend,Top)-Close[fBarNow],this.Price(Trend,Top)-this.Price(Trend,Previous),3);
                                                           break;

                                         case Term:
                                         case Base:
                                         case Expansion:   fibonacci = fdiv(this.Price(Type,Top)-Close[fBarNow],this.Price(Type,Top)-this.Price(Type),3);
                                                           break;
                                         case Prior:
                                         case Root:        fibonacci = fdiv(Close[fBarNow]-f[Expansion].Price,f[Type].Price-f[Expansion].Price,3);
                                                           break;

                                         default:          fibonacci = fdiv(this.Range(Type,Now),this.Range(Previous(Type),Max),3);
                                                           break;
                                       }
                                     break;
                                     
                          case Max:  if (this.Direction(Expansion) == DirectionUp)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(f[Expansion].Price-this.Price(Trend,Bottom),this.Price(Trend,Previous)-this.Price(Trend,Bottom),3);
                                                           break;
                                         case Term:
                                         case Base:        fibonacci = fdiv(f[Expansion].Price-this.Price(Type,Bottom),f[Type].Price-this.Price(Type,Bottom),3);
                                                           break;

                                         case Expansion:   if (this.Price(Convergent)>0.00)
                                                             fibonacci = fdiv(f[Root].Price-this.Price(Convergent),f[Root].Price-f[Expansion].Price,3);
                                                           else
                                                             fibonacci = FiboPercent(Fibo100);
                                                           break;
                                         case Prior:       
                                         case Root:        fibonacci = fdiv(f[Expansion].Price-this.Price(Divergent),f[Expansion].Price-this.Price(Type,Bottom),3);
                                                           break;

                                         default:          fibonacci = fdiv(this.Range(Type),this.Range(Previous(Type)),3);
                                                           break;
                                       }

                                     if (this.Direction(Expansion) == DirectionDown)
                                       switch (Type)
                                       {
                                         case Trend:       fibonacci = fdiv(this.Price(Trend,Top)-f[Expansion].Price,this.Price(Trend,Top)-this.Price(Trend,Previous),3);
                                                           break;
                                         case Term:
                                         case Base:        fibonacci = fdiv(this.Price(Type,Top)-f[Expansion].Price,this.Price(Type,Top)-f[Type].Price,3);
                                                           break;

                                         case Expansion:   if (this.Price(Convergent)>0.00)
                                                             fibonacci = fdiv(f[Root].Price-this.Price(Convergent),f[Root].Price-f[Expansion].Price,3);
                                                           else
                                                             fibonacci = FiboPercent(Fibo100);
                                                           break;
                                         case Prior:       
                                         case Root:        fibonacci = fdiv(f[Expansion].Price-this.Price(Divergent),f[Expansion].Price-this.Price(Type,Top),3);
                                                           break;

                                         default:          fibonacci = fdiv(this.Range(Type),this.Range(Previous(Type)),3);
                                                           break;
                                       }
                        }
    }
    
    if (Format == InPercent)
      return (NormalizeDouble(fibonacci*100,3));
    
    return (NormalizeDouble(fibonacci,3));
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints screen objects, data                    |
//+------------------------------------------------------------------+
void CFractal::RefreshScreen(void)
  {
    string           rsReport    = "";
    string           rsFlag      = "";
    const  string    rsSeg[RetraceTypeMembers] = {"tr","tm","p","b","r","e","d","c","iv","cv","a"};
    
    if (dOrigin.Bar == NoValue)
      rsReport   += "\n  Origin: No Long Term Data\n";
     
    else
    {
      rsReport   += "\n  Origin:\n";
      rsReport   +="      (o): "+BoolToStr(dOrigin.Direction==DirectionUp,"Long","Short");

      Append(rsReport,EnumToString(dOrigin.State));

      rsReport  +="  Bar: "+IntegerToString(dOrigin.Bar)
                 +"  Top: "+DoubleToStr(this.Price(Origin,Top),Digits)
                 +"  Bottom: "+DoubleToStr(this.Price(Origin,Bottom),Digits)
                 +"  Price: "+DoubleToStr(this.Price(Origin),Digits)+"\n";
                 
      rsReport  +="             Retrace: "+DoubleToString(this.Fibonacci(Origin,Retrace,Now,InPercent),1)+"%"
                 +" "+DoubleToString(this.Fibonacci(Origin,Retrace,Max,InPercent),1)+"%"
                 +"  Leg: (c) "+DoubleToString(this.Range(Retrace,Now,InPips),1)
                 +" (a) "+DoubleToString(this.Range(Retrace,Active,InPips),1)
                 +" (m) "+DoubleToString(this.Range(Retrace,Max,InPips),1)+"\n";

      rsReport  +="             Expansion: " +DoubleToString(this.Fibonacci(Origin,Expansion,Now,InPercent),1)+"%"
                 +" "+DoubleToString(this.Fibonacci(Origin,Expansion,Max,InPercent),1)+"%"
                 +"  Leg: (c) "+DoubleToString(this.Range(Origin,Now,InPips),1)
                 +" (a) "+DoubleToString(this.Range(Origin,Active,InPips),1)
                 +" (m) "+DoubleToString(this.Range(Origin,Max,InPips),1)+"\n";
    }
      
    for (RetraceType type=Trend;type<=this.State();type++)
    {
      if (this[type].Bar>NoValue)
      {
        if (type == this.Dominant(Trend))
          rsReport  += "\n  Trend:\n";
        else
        if (type == this.Dominant(Term))
          rsReport  += "\n  Term:\n";
        else
        if (type == this.State())
          if (type < Actual)
            rsReport+= "\n  Actual:\n";

        rsReport    +="      ("+rsSeg[type]+"): "+BoolToStr(this.Direction(type)==DirectionUp,"Long","Short");

        Append(rsReport,BoolToStr(this[type].Peg,"Peg"));
        Append(rsReport,BoolToStr(this[type].Breakout,"Breakout"));
        Append(rsReport,BoolToStr(this[type].Reversal,"Reversal"));

        if (type==Trend)
        {
          rsReport   +="  Bar: "+BoolToStr(fOrigin.Bar==NoValue,IntegerToString(dOrigin.Bar),IntegerToString(fOrigin.Bar));
          rsReport   +="  Top: "+DoubleToStr(this.Price(type,Top),Digits)
                      +"  Bottom: "+DoubleToStr(this.Price(type,Bottom),Digits)
                      +"  Price: "+BoolToStr(type==Trend,DoubleToStr(dOrigin.Price,Digits),DoubleToStr(fOrigin.Price,Digits))+"\n";
        }
        else
        {
          rsReport   +="  Bar: "+IntegerToString(this[type].Bar);
          rsReport   +="  Top: "+DoubleToStr(this.Price(type,Top),Digits)
                      +"  Bottom: "+DoubleToStr(this.Price(type,Bottom),Digits)
                      +"  Price: "+DoubleToStr(this.Price(type),Digits)+"\n";
        }
        
        rsReport    +="             Retrace: "+DoubleToString(this.Fibonacci(type,Retrace,Now,InPercent),1)+"%"
                     +" "+DoubleToString(this.Fibonacci(type,Retrace,Max,InPercent),1)+"%"
                     +"  Expansion: " +DoubleToString(this.Fibonacci(type,Expansion,Now,InPercent),1)+"%"
                     +" "+DoubleToString(this.Fibonacci(type,Expansion,Max,InPercent),1)+"%"
                     +"  Leg: (c) "+DoubleToString(this.Range(type,Now,InPips),1)+" (a) "+DoubleToString(this.Range(type,Max,InPips),1)+"\n";
      };
    }
    
    Comment(rsReport);
  }