//+------------------------------------------------------------------+
//|                                                   PipFractal.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\PipRegression.mqh>
#include <Class\Fractal.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CPipFractal : public CPipRegression
  {

    private:
    
          struct     PipFractalRec
                     {
                       //--- Fractal term working elements
                       int        Direction;            //--- Current fractal direction
                       double     PriceHigh;            //--- Highest active price
                       double     PriceLow;             //--- Lowest active price
                       
                       //--- Fractal time points
                       datetime   RootTime;             //--- Time stamp of the active root
                       datetime   ExpansionTime;        //--- Time stamp of the active expansion
                          
                       //--- Fractal price points
                       double     Prior;                //--- Historical base
                       double     Base;                 //--- Current base
                       double     Root;                 //--- Current root
                       double     Expansion;            //--- Current expansion
                       double     Retrace;              //--- Current retrace
                     };
    
          //--- Operational variables
          int        pfOriginDir;                       //--- Direction of Origin computed from last root reversal
          double     pfOrigin;                          //--- Fractal origin at trend start
          double     pfPrior;                           //--- Maximum inversion at trend start          
          bool       pfPeg;                             //--- Pegs on trend/term divergence
          double     pfPegMax;                          //--- Max price after peg
          double     pfPegMin;                          //--- Min price after peg
          double     pfPegExpansion;                    //--- Expansion price at peg      
          int        pfTrendCount;                      //--- Counts trend continuations
          int        pfTermCount;                       //--- Counts term changes
                     
          double     NewFractalRoot(RetraceType Type);  //--- Updates fractal price points
          void       UpdateFractal(RetraceType Type, int Direction);
          void       CalcPipFractal(void);
          void       CalcFiboChange(void);
          

    public:
                     CPipFractal(int Degree, int Periods, double Tolerance, CFractal &Fractal);
                    ~CPipFractal();
                             
       virtual
          void       UpdateBuffer(double &MA[], double &PolyBuffer[], double &TrendBuffer[]);
       
       virtual
          void       Update(void);                                              //--- Update method; updates fractal data
          
          //--- Fractal Properties
       virtual
          int        Direction(int Type=Term, bool Contrarian=false);

       virtual   
          int        Count(int Counter);
          double     Price(int TimeRange, int Measure=Expansion);
          double     Fibonacci(int Type, int Method, int Measure, int Format=InDecimal);                                        
          bool       IsPegged(void)  {return (pfPeg); }
          
          void       RefreshScreen(void);
          void       ShowFiboArrow(void);
   
          PipFractalRec operator[](const RetraceType Type) const { return(pf[Type]); };
             
    protected:
    
         PipFractalRec pf[2];
  };

//+------------------------------------------------------------------+
//| CalcFiboChange - Calculates major/minor fractal events           |
//+------------------------------------------------------------------+
void CPipFractal::CalcFiboChange(void)
  {
    static int cfcFiboLevel     = FiboRoot;
    static int cfcFiboDir       = DirectionNone;
           int cfcFiboLevelNow  = fabs(FiboLevel(Fibonacci(Term,Expansion,Max),Signed));
    
    ClearEvent(NewMajor);
    ClearEvent(NewMinor);

    if (IsChanged(cfcFiboDir,this.Direction(Term)))
      cfcFiboLevel              = FiboRoot;
    
    if (cfcFiboLevelNow>cfcFiboLevel)
    {
      cfcFiboLevel              = cfcFiboLevelNow;
      
      if (cfcFiboLevel>Fibo100)
        SetEvent(NewMajor);
      else
      if (cfcFiboLevel==Fibo100)
        SetEvent(NewMinor);
    }
  }
  
//+------------------------------------------------------------------+
//| NewFractalRoot - creates a new fractal root                      |
//+------------------------------------------------------------------+
double CPipFractal::NewFractalRoot(RetraceType Type)
  {
    pf[Type].Prior              = pf[Type].Base;
    pf[Type].Base               = pf[Type].Root;
    pf[Type].Root               = pf[Type].Expansion;
    
    pf[Type].Expansion          = Close[0];
    pf[Type].Retrace            = Close[0];
    
    pf[Type].RootTime           = pf[Type].ExpansionTime;
    pf[Type].ExpansionTime      = Time[0];

    switch (Type)
    {
      case Trend: pfTrendCount  = 1;
                  pfTermCount   = 0;
                  break;

      case Term:  pfTermCount++;
    }
    
    return (pf[Type].Root);
  }

//+------------------------------------------------------------------+
//| UpdateFractal - updates fractal data for the supplied type       |
//+------------------------------------------------------------------+
void CPipFractal::UpdateFractal(RetraceType Type, int Direction)
  {
    double ufNewFractalRoot;
    
    if (Direction != DirectionNone)
    {
      if (IsChanged(pf[Type].Direction,Direction))
      {
        switch (Type)
        {
          case Term:  SetEvent(NewTerm);
                      break;
          case Trend: SetEvent(NewTrend);
                      break;
        }
        
        ufNewFractalRoot             = NewFractalRoot(Type);
        
        if (Direction == DirectionUp)
          pf[Type].PriceLow          = ufNewFractalRoot;

        if (Direction == DirectionDown)
          pf[Type].PriceHigh         = ufNewFractalRoot;
          
        if (Type == Trend)
        {
          pfPrior                    = pfOrigin;
          pfOrigin                   = ufNewFractalRoot;
          pfPeg                      = false;
        }

        if (Type == Term)
        {
          if (!this.IsPegged())
          {
            pfPegExpansion           = pf[Trend].Expansion;

            pfPegMax                 = fmax(pf[Trend].Expansion,pf[Trend].Retrace);
            pfPegMin                 = fmin(pf[Trend].Expansion,pf[Trend].Retrace);
          }

          pfPeg                      = true;
        }
      }
      
      if (Type == Trend)
      {
        if (this.IsPegged())
        {
          if (Direction == DirectionUp)
            pf[Trend].Root           = pfPegMin;

          if (Direction == DirectionDown)
            pf[Trend].Root           = pfPegMax;
            
          pf[Trend].Base             = pfPegExpansion;
          
          pfTrendCount++;
          pfTermCount                = 0;
        }

        pfPeg                        = false;
      }
    }
      
    if (pf[Type].Direction == DirectionUp)
      if (IsChanged(pf[Type].Expansion,fmax(pf[Type].Expansion,Close[0])))
      {
        pf[Type].Retrace             = Close[0];
        pf[Type].ExpansionTime       = Time[0];
      }
      else
        pf[Type].Retrace             = fmin(pf[Type].Retrace,Close[0]);
        
    if (pf[Type].Direction == DirectionDown)
      if (IsChanged(pf[Type].Expansion,fmin(pf[Type].Expansion,Close[0])))
      {
        pf[Type].Retrace             = Close[0];
        pf[Type].ExpansionTime       = Time[0];
      }
      else
        pf[Type].Retrace             = fmax(pf[Type].Retrace,Close[0]);
        
    if (this.IsPegged())
    {
      pfPegMax                       = fmax(pfPegMax,fmax(pf[Trend].Expansion,pf[Trend].Retrace));
      pfPegMin                       = fmin(pfPegMin,fmin(pf[Trend].Expansion,pf[Trend].Retrace));
    }
    else
    {
      pfPegMax                       = 0.00;
      pfPegMin                       = 0.00;
    }    
  }

//+------------------------------------------------------------------+
//| CalcPipFractal - updates fractal data                            |
//+------------------------------------------------------------------+
void CPipFractal::CalcPipFractal(void)
  {
    int      uTermDir               = DirectionNone;
    int      uTrendDir              = DirectionNone;

    //--- Clear fractal events
    ClearEvent(NewTerm);
    ClearEvent(NewTrend);    

    //--- Detect term change
    if (Event(NewBoundary))
    {
      if (HistoryLoaded())
        if (IsEqual(FOC(Deviation),0.0,1))
        {
          if (Event(NewHigh))
            uTermDir               = DirectionUp;
          
          if (Event(NewLow))
            uTermDir               = DirectionDown;
        }

      if (IsChanged(pf[Term].PriceHigh,fmax(pf[Term].PriceHigh,Close[0])))
        uTermDir                   = DirectionUp;

      if (IsChanged(pf[Term].PriceLow,fmin(pf[Term].PriceLow,Close[0])))
        uTermDir                   = DirectionDown;
    }          
    
    UpdateFractal(Term,uTermDir);

    //--- Detect trend change
    if (Fibonacci(Term,Expansion,Max)>FiboPercent(Fibo161))
      uTrendDir                    = uTermDir;

    UpdateFractal(Trend,uTrendDir);

    //--- Detect origin change
    if (Fibonacci(Origin,Expansion,Max)>FiboPercent(Fibo100) ||
        Fibonacci(Origin,Expansion,Max)<FiboPercent(FiboRoot)
       )
      pfOriginDir                  = pf[Trend].Direction;  //<---- this may be broken (?)
  }

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPipFractal::CPipFractal(int Degree, int Periods, double Tolerance, CFractal &Fractal) : CPipRegression(Degree,Periods,Tolerance)
  {
    RetraceType   state        = Actual;
    
    //--- PipFractal Initialization
    state                      = Fractal.State();
    pf[Term].Direction         = Fractal[state].Direction;

    for (int idx=0;idx<5;idx++)
    {
      switch (idx)
      {
        case 0:  pf[Term].Retrace        = Fractal.Price(state,Next);
                 pf[Term].Expansion      = Fractal.Price(state);
                 pf[Term].ExpansionTime  = Fractal[Fractal.State()].Updated;
        case 1:  pf[Term].Root           = Fractal.Price(state);
                 pf[Term].RootTime       = Fractal[Fractal.State()].Updated;                                           
        case 2:  pf[Term].Base           = Fractal.Price(state);
                 pf[Term].Prior          = Fractal.Price(state);
        case 3:  pfOrigin                = Fractal.Price(state);
        case 4:  pfPrior                 = Fractal.Price(state);
      }

      state                  = Fractal.Previous(state);
    }
      
    pf[Term].PriceHigh       = fmax(pf[Term].Base,pf[Term].Root);
    pf[Term].PriceLow        = fmin(pf[Term].Base,pf[Term].Root);
    
    pf[Trend]                = pf[Term];
    
    //--- Initialize origin
    if (IsEqual(pfOrigin,this.Price(Origin,Bottom)))
      pfOriginDir            = DirectionDown;

    if (IsEqual(pfOrigin,this.Price(Origin,Top)))
      pfOriginDir            = DirectionUp;

    //--- Initialize peg values
    pfPegExpansion           = pf[Trend].Base;

    pfPeg                    = true;

    pfPegMax                 = fmax(pf[Trend].Root,pf[Trend].Base);
    pfPegMin                 = fmin(pf[Trend].Root,pf[Trend].Base);

    pfTrendCount             = 0;
    pfTermCount              = 0;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPipFractal::~CPipFractal()
  {
  }

//+------------------------------------------------------------------+
//|  UpdateBuffer - Updates data and returns buffer                  |
//+------------------------------------------------------------------+
void CPipFractal::UpdateBuffer(double &MA[], double &PolyBuffer[], double &TrendBuffer[])
  {    
    if (HistoryLoaded())
      UpdateBuffer(PolyBuffer,TrendBuffer);
    else
      CalcMA();
      
    CalcPipFractal();          
    CalcFiboChange();
    
    ArrayCopy(MA,maData,0,0,fmin(prPeriods,pipHistory.Count));
  }

//+------------------------------------------------------------------+
//| Update - Public interface to populate metrics                    |
//+------------------------------------------------------------------+
void CPipFractal::Update(void)
  {
    if (HistoryLoaded())
    {
      UpdatePoly();
      UpdateTrendline();
    }
    else
      CalcMA();
      
    CalcPipFractal();          
    CalcFiboChange();
  }
  
//+------------------------------------------------------------------+
//|  Count - returns the value for the supplied Counter              |
//+------------------------------------------------------------------+
int CPipFractal::Count(int Counter)
  {
    switch (Counter)
    {
      case Term:           return (pfTermCount);
      case Trend:          return (pfTrendCount);
      case History:        return (pipHistory.Count);
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| Price - Returns the price of the specified measure               |
//+------------------------------------------------------------------+
double CPipFractal::Price(int TimeRange, int Measure=Expansion)
  {
    switch (TimeRange)
    {
      case Origin:   switch (Measure)
                     {
                       case Top:        return(fmax(pfPrior,pfOrigin));
                       case Bottom:     return(fmin(pfPrior,pfOrigin));
                       case Origin:     return(pfOrigin);
                       case Prior:      return(pfPrior);
                       case Base:       if (pfOriginDir == DirectionUp)
                                          return(this.Price(Origin,Top));
                                        return(this.Price(Origin,Bottom));
                       case Root:       if (pfOriginDir == DirectionUp)
                                          return(this.Price(Origin,Bottom));
                                        return(this.Price(Origin,Top));
                       case Expansion:  if (pf[Trend].Direction == pfOriginDir)
                                          return(pf[Trend].Expansion);
                                        return(pf[Trend].Retrace);
                       case Retrace:    if (pf[Trend].Direction == pfOriginDir)
                                          return(pf[Trend].Retrace);
                                        return(pf[Trend].Expansion);
                     }
                     break;
                     
      case Term:
      case Trend:    switch (Measure)
                     {
                       case Top:        return(pf[TimeRange].PriceHigh);
                       case Bottom:     return(pf[TimeRange].PriceLow);
                       case Origin:     return(pfOrigin);
                       case Prior:      return(pf[TimeRange].Prior);
                       case Base:       return(pf[TimeRange].Base);
                       case Root:       return(pf[TimeRange].Root);
                       case Expansion:  return(pf[TimeRange].Expansion);
                       case Retrace:    return(pf[TimeRange].Retrace);
                     }
    }
    
    return (0.00);
  }          
  
//+------------------------------------------------------------------+
//| Fibonacci - Returns the fibonacci percentage for supplied params |
//+------------------------------------------------------------------+
double CPipFractal::Fibonacci(int TimeRange, int Method, int Measure, int Format=InDecimal)
  {
    int fFormat   = 1;
    
    if (Format == InPercent)
      fFormat     = 100;
      
    if (TimeRange==Origin)
      switch (Method)
      {
        case Retrace:   switch (Measure)
                        {
                          case Now: return (fdiv(this.Price(Origin,Base)-Close[0],this.Price(Origin,Base)-this.Price(Origin,Root),3)*fFormat);
                          case Max: return (fdiv(this.Price(Origin,Base)-this.Price(Origin,Retrace),this.Price(Origin,Base)-this.Price(Origin,Root),3)*fFormat);
                        }
                        return (0.00);
        case Expansion: switch (Measure)
                        {
                          case Now: return (fdiv(Close[0]-this.Price(Origin,Root),this.Price(Origin,Base)-this.Price(Origin,Root),3)*fFormat);
                          case Max: return (fdiv(this.Price(Origin,Expansion)-this.Price(Origin,Root),this.Price(Origin,Base)-this.Price(Origin,Root),3)*fFormat);
                        }
                        return (0.00);
      }
    
    if (TimeRange==Term || TimeRange==Trend)
      switch (Method)
      {
        case Retrace:   switch (Measure)
                        {
                          case Now: return (fabs(fdiv(Close[0]-pf[TimeRange].Expansion,pf[TimeRange].Root-pf[TimeRange].Expansion,3))*fFormat);
                          case Max: return (fabs(fdiv(pf[TimeRange].Retrace-pf[TimeRange].Expansion,pf[TimeRange].Root-pf[TimeRange].Expansion,3))*fFormat);
                        }
                        break;
                          
        case Expansion: switch (Measure)
                        {
                          case Now: return (fabs(fdiv(pf[TimeRange].Root-Close[0],pf[TimeRange].Root-pf[TimeRange].Base,3))*fFormat);
                          case Max: return (fabs(fdiv(pf[TimeRange].Root-pf[TimeRange].Expansion,pf[TimeRange].Root-pf[TimeRange].Base,3))*fFormat);
                        }
      }

    return (0.00);
  }

//+------------------------------------------------------------------+
//|  Direction - returns the direction for the supplied type         |
//+------------------------------------------------------------------+
int CPipFractal::Direction(int Type=Term, bool Contrarian=false)
  {
    int dContrary     = 1;
    
    if (Contrarian)
      dContrary       = DirectionInverse;

    switch (Type)
    {
      case Origin:        return (pfOriginDir*dContrary);
      case Trend:       
      case Term:          return (pf[Type].Direction*dContrary);
      case PolyAmplitude: return (prPolyAmpDirection*dContrary);      
      case Polyline:      return (prPolyDirection*dContrary);
      case Amplitude:     return (prAmpDirection*dContrary);
      case Trendline:     return (trTrendlineDir*dContrary);
      case Pivot:         return (trPivotDir*dContrary);
      case StdDev:        return (trStdDevDir*dContrary);
      case Range:         return (ptrRangeDir*dContrary);
      case RangeHigh:     return (ptrRangeDirHigh*dContrary);
      case RangeLow:      return (ptrRangeDirLow*dContrary);
      case Aggregate:     return (BoolToInt(ptrRangeDirHigh==ptrRangeDirLow,ptrRangeDirHigh*dContrary,DirectionNone));
      case Tick:          return (ptrTickDir*dContrary);
    }
    
    return (DirectionNone);
  }

//+------------------------------------------------------------------+
//| ShowFiboArrow - paints the pipMA fibo arrow                      |
//+------------------------------------------------------------------+
void CPipFractal::ShowFiboArrow(void)
  {
    static string    arrowName      = "";
    static int       arrowDir       = DirectionNone;
    static double    arrowPrice     = 0.00;
           uchar     arrowCode      = SYMBOL_DASH;

    if (IsChanged(arrowDir,this.Direction(Term)))
    {
      arrowPrice                    = Close[0];
      arrowName                     = NewArrow(arrowCode,DirColor(arrowDir,clrYellow),DirText(arrowDir),arrowPrice);
    }
     
    if (this.Fibonacci(Term,Expansion,Max)>FiboPercent(Fibo823))
      arrowCode                     = SYMBOL_POINT4;
    else
    if (this.Fibonacci(Term,Expansion,Max)>FiboPercent(Fibo423))
      arrowCode                     = SYMBOL_POINT3;
    else
    if (this.Fibonacci(Term,Expansion,Max)>FiboPercent(Fibo261))
      arrowCode                     = SYMBOL_POINT2;
    else  
    if (this.Fibonacci(Term,Expansion,Max)>FiboPercent(Fibo161))
      arrowCode                     = SYMBOL_POINT1;
    else
    if (this.Fibonacci(Term,Expansion,Max)>FiboPercent(Fibo100))
      arrowCode                     = SYMBOL_CHECKSIGN;
    else
      arrowCode                     = SYMBOL_DASH;

    switch (arrowDir)
    {
      case DirectionUp:    if (IsChanged(arrowPrice,fmax(arrowPrice,Close[0])))
                             UpdateArrow(arrowName,arrowCode,DirColor(arrowDir,clrYellow),arrowPrice);
                           break;
      case DirectionDown:  if (IsChanged(arrowPrice,fmin(arrowPrice,Close[0])))
                             UpdateArrow(arrowName,arrowCode,DirColor(arrowDir,clrYellow),arrowPrice);
                           break;
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Prints PipFractal metrics to comment             |
//+------------------------------------------------------------------+
void CPipFractal::RefreshScreen(void)
  { 
    Comment("\n*--- PipFractal ---*\n"
           +"  FOC: "+DoubleToStr(FOC(Now),1)+"/"+DoubleToStr(FOC(Deviation),1)+"  Pivot: "+DoubleToStr(Pip(Pivot(Deviation)),1)+"  Range: "+DoubleToStr(Pip(Range(Size)),1)+"\n\n"
           +"  Term: "+DirText(this.Direction(Term))+" ("+IntegerToString(this.Count(Term))+")\n"
           +"     Base: "+DoubleToStr(pf[Term].Base,Digits)+" Root: "+DoubleToStr(pf[Term].Root,Digits)+" Expansion: "+DoubleToStr(pf[Term].Expansion,Digits)+"\n"
           +"     Retrace: "+DoubleToStr(Fibonacci(Term,Retrace,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(Term,Retrace,Max,InPercent),1)+"%"
           +"   Expansion: "+DoubleToStr(Fibonacci(Term,Expansion,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(Term,Expansion,Max,InPercent),1)+"%\n\n"
           +"  Trend: "+DirText(this.Direction(Trend))+" ("+IntegerToString(this.Count(Trend))+")\n"
           +"     Base: "+DoubleToStr(pf[Trend].Base,Digits)+" Root: "+DoubleToStr(pf[Trend].Root,Digits)+" Expansion: "+DoubleToStr(pf[Trend].Expansion,Digits)+"\n"
           +"     Retrace: "+DoubleToStr(Fibonacci(Trend,Retrace,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(Trend,Retrace,Max,InPercent),1)+"%"
           +"   Expansion: "+DoubleToStr(Fibonacci(Trend,Expansion,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(Trend,Expansion,Max,InPercent),1)+"%\n\n"
           +"  Origin: "+DirText(Direction(Origin))+"\n"
           +"     Base: "+DoubleToStr(this.Price(Origin,Base),Digits)+" Root: "+DoubleToStr(this.Price(Origin,Root),Digits)+" Expansion: "+DoubleToStr(this.Price(Origin,Expansion),Digits)+"\n"       
           +"     Retrace: "+DoubleToStr(Fibonacci(Origin,Retrace,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(Origin,Retrace,Max,InPercent),1)+"%"
           +"   Expansion: "+DoubleToStr(Fibonacci(Origin,Expansion,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(Origin,Expansion,Max,InPercent),1)+"%\n");
  }

