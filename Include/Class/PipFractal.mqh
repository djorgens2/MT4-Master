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

//+------------------------------------------------------------------+
//| PipFractal: Fractal Class derived from Poly(6) trend algorithm   |
//+------------------------------------------------------------------+
class CPipFractal : public CPipRegression
  {

    protected:
    
         enum       PipFractalType
                    {
                      pftOrigin,
                      pftTrend,
                      pftTerm,
                      PipFractalTypes
                    };

    
         //--- Fractal point data
         struct     PipFractalRec
                     {
                       int        Direction;                //--- Current fractal direction                       
                       double     Base;                     //--- Current base
                       double     Root;                     //--- Current root
                       double     Expansion;                //--- Current expansion
                       double     Retrace;                  //--- Current retrace
                       double     Recovery;                 //--- Current recovery
                     };


         PipFractalRec pf[PipFractalTypes];
         PipFractalRec operator[](const PipFractalType Type) const {return(pf[Type]);};


    private:
          //--- Data buffer
          double         pfMap[];

          //--- Operational Bar variables
          int            pfBar;                             //--- Bar now processing
          int            pfBars;                            //--- Total Bars in Chart
          int            pfHiBar;                           //--- Current Term High Bar
          int            pfLoBar;                           //--- Current Term Low Bar
          
          double         pfTermHi;                          //--- Term hi/lo root price
          double         pfTermLo;                          //--- Term hi/lo root price
          
          //--- Operational flags
          bool           pfTerm161;                         //--- Term fibo 161 switch
          bool           pfReversal;                        //--- Set on Trend Reversals
          
          ReservedWords  pfState;                           //--- Current state of the fractal

          //--- Display flag operationals
          string         arrowName;
          int            arrowDir;
          double         arrowPrice;
          int            arrowIdx;
          
          //--- Internal use methods
          void           UpdateRetrace(PipFractalType Type);        //--- Update Retrace by Type
          void           UpdateTerm(int Direction, double Price);   //--- Updates Term Fractal on change
          void           UpdateTrend(void);                         //--- Updates Trend Fractal on change
          void           UpdateOrigin(void);                        //--- Updates Origin Fractal on change
          void           UpdateNodes(void);
          void           CalcState(void);
          

    public:
                         CPipFractal(int Degree, int Periods, double Tolerance, double AggFactor, int IdleTime);
                        ~CPipFractal();
                             
       virtual
          void           UpdateBuffer(double &MA[], double &PolyBuffer[], double &TrendBuffer[]);
       
       virtual
          void           Update(void);                      //--- Update method; updates fractal data
          
          //--- Fractal Properties
       virtual
          int            Direction(int Type, bool Contrarian=false);

          double         Price(PipFractalType Type, int Measure=Expansion);
          double         Fibonacci(PipFractalType Type, int Method, int Measure, int Format=InDecimal);
          ReservedWords  State(void) {return (pfState);};
          
          void           RefreshScreen(void);
          void           ShowFiboArrow(double Price=0.00);
  };

//+------------------------------------------------------------------+
//| CalcState - updates the pfractal state                           |
//+------------------------------------------------------------------+
void CPipFractal::CalcState(void)
  {
    //-- Origin State
    
    
    
  }

//+------------------------------------------------------------------+
//| UpdateRetrace - updates retrace data based on supplied type      |
//+------------------------------------------------------------------+
void CPipFractal::UpdateRetrace(PipFractalType Type)
  {    
    if (IsChanged(pf[Type].Retrace,BoolToDouble(pf[Type].Direction==DirectionUp,
                           fmin(BoolToDouble(pfBar==0,Close[pfBar],Low[pfBar]),pf[Type].Retrace),
                           fmax(BoolToDouble(pfBar==0,Close[pfBar],High[pfBar]),pf[Type].Retrace),Digits)))
      pf[Type].Recovery = pf[Type].Retrace;
    else
      pf[Type].Recovery = BoolToDouble(pf[Type].Direction==DirectionUp,
                           fmax(BoolToDouble(pfBar==0,Close[pfBar],High[pfBar]),pf[Type].Recovery),
                           fmin(BoolToDouble(pfBar==0,Close[pfBar],Low[pfBar]),pf[Type].Recovery),Digits);
                           
    if (IsChanged(pf[Type].Expansion,BoolToDouble(Direction(Type)==DirectionUp,
                           fmax(BoolToDouble(pfBar==0,Close[pfBar],High[pfBar]),pf[Type].Expansion),
                           fmin(BoolToDouble(pfBar==0,Close[pfBar],Low[pfBar]),pf[Type].Expansion),Digits)))
    {
      pf[Type].Retrace  = pf[Type].Expansion;
      pf[Type].Recovery = pf[Type].Expansion;
      
      SetEvent(NewExpansion,Minor);
      ShowFiboArrow(pf[Type].Expansion);
    }                           
  }

//+------------------------------------------------------------------+
//| UpdateOrigin - updates Origin fractal data                       |
//+------------------------------------------------------------------+
void CPipFractal::UpdateOrigin(void)
  {
    if (pfReversal)
    {
      if (NewDirection(pf[pftOrigin].Direction,pf[pftTrend].Direction))
        SetEvent(NewOrigin,Critical);

      pf[pftOrigin].Root         = pf[pftTrend].Root;
    }
    
    pf[pftOrigin].Base           = pf[pftTrend].Expansion;
    pf[pftOrigin].Retrace        = pf[pftTerm].Expansion;
    pf[pftOrigin].Recovery       = pf[pftTerm].Expansion;
      
    pf[pftOrigin].Expansion      = BoolToDouble(Direction(pftOrigin)==DirectionUp,
                                     fmax(pf[pftOrigin].Expansion,pf[pftTrend].Expansion),
                                     fmin(pf[pftOrigin].Expansion,pf[pftTrend].Expansion),Digits);
  }

//+------------------------------------------------------------------+
//| UpdateTrend - updates Trend fractal data                         |
//+------------------------------------------------------------------+
void CPipFractal::UpdateTrend(void)
  {
    pfReversal = (NewDirection(pf[pftTrend].Direction,pf[pftTerm].Direction));
    
    pf[pftTrend].Base           = Fibonacci(pftTerm,Forecast,Fibo161);
    pf[pftTrend].Root           = BoolToDouble(Direction(pftTrend)==DirectionUp,pfTermLo,pfTermHi,Digits);

    pf[pftTrend].Expansion      = pf[pftTerm].Expansion;
    pf[pftTrend].Retrace        = pf[pftTerm].Expansion;
    pf[pftTrend].Recovery       = pf[pftTerm].Expansion;
    
    SetEvent(NewTrend,Major);
  }

//+------------------------------------------------------------------+
//| UpdateTerm - updates Term fractal data                           |
//+------------------------------------------------------------------+
void CPipFractal::UpdateTerm(int Direction, double Price)
  {
//    ClearEvent(NewExpansion);  -- history load issue: Bar 1 on Expansion sets retrace to HIGH[pfBar]; s/b untouched.
    
    if (NewDirection(pf[pftTerm].Direction,Direction))
    {
      //-- Consider: We set expansion to retrace; confirm: on breakout resume, set root to divergent expansion;
      if (Direction==DirectionDown&&Price>pf[pftTerm].Retrace) NewArrow(SYMBOL_STOPSIGN,clrRed);
      if (Direction==DirectionUp&&Price<pf[pftTerm].Retrace) NewArrow(SYMBOL_STOPSIGN,clrYellow);

      pf[pftTerm].Base           = pf[pftTerm].Root;
      pf[pftTerm].Root           = pf[pftTerm].Expansion;
      pf[pftTerm].Expansion      = pf[pftTerm].Retrace;
      pf[pftTerm].Retrace        = pf[pftTerm].Recovery;
      pf[pftTerm].Recovery       = Price;
      
      if (IsChanged(pfTerm161,false))
      {
        pfTermHi                 = pf[pftTerm].Root;
        pfTermLo                 = pf[pftTerm].Root;
        
        SetEvent(NewOrigin,Minor);
      }

      pfTermHi                 = fmax(pfTermHi,pf[pftTerm].Root);
      pfTermLo                 = fmin(pfTermLo,pf[pftTerm].Root);
 
      SetEvent(NewTerm,Minor);
    }
  }

//+------------------------------------------------------------------+
//| UpdateNodes - updates fractal nodes                              |
//+------------------------------------------------------------------+
void CPipFractal::UpdateNodes(void)
  {
    //--- Clear fractal events
    ClearEvent(NewExpansion);
    ClearEvent(NewTerm);
    ClearEvent(NewTrend);
    ClearEvent(NewOrigin);

    //--- Handle Term direction changes
    if (pfBar>0&&pfMap[pfBar]>0.00)
      UpdateTerm(BoolToInt(IsEqual(pfMap[pfBar],High[pfBar])==DirectionUp,DirectionUp,DirectionDown),pfMap[pfBar]);
    else
    if (Event(NewBoundary))
      if (IsEqual(FOC(Deviation),0.0,1))
        if (HistoryLoaded())
          UpdateTerm(BoolToInt(Event(NewHigh),DirectionUp,DirectionDown),Close[pfBar]);
        else
          UpdateTerm(BoolToInt(Close[pfBar]>pf[pftTerm].Root,DirectionUp,DirectionDown),Close[pfBar]);
 
    UpdateRetrace(pftTerm);
    
    //-- Manage Trend changes
    if (Fibonacci(pftTerm,Expansion,Max)>FiboPercent(Fibo161))
      if (IsChanged(pfTerm161,true))
        UpdateTrend();

    UpdateRetrace(pftTrend);    
    
    //-- Manage Origin changes
    if (EventAlert(NewOrigin,Minor))
      UpdateOrigin();
      
    UpdateRetrace(pftOrigin);
  }

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPipFractal::CPipFractal(int Degree, int Periods, double Tolerance, double AggFactor, int IdleTime) : CPipRegression(Degree,Periods,Tolerance,AggFactor,IdleTime)
  {
    //-- Initialize fibo graphics
    arrowName          = "";
    arrowDir           = DirectionNone;
    arrowPrice         = 0.00; 
    arrowIdx           = 0;

    int    pfSeed      = 14;
    int    pfDir       = DirectionChange;
    
    int    pfLastHi    = NoValue;
    int    pfLastLo    = NoValue;

    pfBar              = 0;
    pfBars             = Bars;
    pfHiBar            = NoValue;
    pfLoBar            = NoValue;
    
    ArrayResize(pfMap,Bars);
    ArrayInitialize(pfMap,0.00);
    
    //-- Build fractal map
    while (pfBar<Bars)
    {
      pfHiBar     = iHighest(Symbol(),Period(),MODE_HIGH,pfSeed,pfBar);
      pfLoBar     = iLowest(Symbol(),Period(),MODE_LOW,pfSeed,pfBar);
      
      if (NewDirection(pfDir,Direction(BoolToInt(pfHiBar==pfLoBar,pfDir,pfHiBar-pfLoBar),InDirection,false)))
      {
        if (pfDir==DirectionUp)
        {
          //-- Fixes outside reversals
          if (pfLastHi<iLowest(Symbol(),Period(),MODE_LOW,pfSeed+(pfBar-pfLastHi),pfLastHi))
            pfLoBar            = iLowest(Symbol(),Period(),MODE_LOW,pfSeed+(pfBar-pfLastHi),pfLastHi);
  
          pfMap[pfLoBar]       = Low[pfLoBar];
          pfLastLo             = pfLoBar;

          //-- Fixes inside reversals
          if (pfLastLo>NoValue&&pfLastHi>NoValue)
            if (iHighest(Symbol(),Period(),MODE_HIGH,pfLastLo-pfLastHi,pfLastHi)>pfLastHi)
            {
              pfMap[pfLastHi]  = 0.00;
              pfLastHi         = iHighest(Symbol(),Period(),MODE_HIGH,pfLastLo-pfLastHi,pfLastHi);
              pfMap[pfLastHi]  = High[pfLastHi];
            }
        }
        
        if (pfDir==DirectionDown)
        {
          //-- Fixes outside reversals
          if (pfLastLo<iHighest(Symbol(),Period(),MODE_HIGH,pfSeed+(pfBar-pfLastLo),pfLastLo))
            pfHiBar            = iHighest(Symbol(),Period(),MODE_HIGH,pfSeed+(pfBar-pfLastLo),pfLastLo);

          pfMap[pfHiBar]       = High[pfHiBar];
          pfLastHi             = pfHiBar;

          //-- Fixes inside reversals
          if (pfLastLo>NoValue&&pfLastHi>NoValue)
            if (iLowest(Symbol(),Period(),MODE_LOW,pfLastHi-pfLastLo,pfLastLo)>pfLastLo)
            {
              pfMap[pfLastLo]  = 0.00;
              pfLastLo         = iLowest(Symbol(),Period(),MODE_LOW,pfLastHi-pfLastLo,pfLastLo);
              pfMap[pfLastLo]  = Low[pfLastLo];
            }
        }
      }

      pfBar++;
    }

    //--- PipFractal Initialization
    pf[pftTerm].Direction          = DirectionChange;
    pf[pftTerm].Base               = NoValue;
    pf[pftTerm].Root               = NoValue;
    pf[pftTerm].Expansion          = NoValue;
    pf[pftTerm].Retrace            = NoValue;
    pf[pftTerm].Recovery           = NoValue;
    
    pf[pftTrend]                   = pf[pftTerm];
    pf[pftOrigin]                  = pf[pftTerm];
    
    for (pfBar=Bars-1;pfBar>0;pfBar--)
      UpdateNodes();
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
    {
      CalcMA();
      CalcWave();
    }

    for (pfBars=pfBars;pfBars<Bars;pfBars++)
    {
      pfHiBar++;
      pfLoBar++;
    }

    UpdateNodes();
    CalcState();
    
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
    {
      CalcMA();
      CalcWave();      
    }

    for (pfBars=pfBars;pfBars<Bars;pfBars++)
    {
      pfHiBar++;
      pfLoBar++;
    }
      
    UpdateNodes();
    CalcState();
  }

//+------------------------------------------------------------------+
//| Price - Returns the price of the specified measure               |
//+------------------------------------------------------------------+
double CPipFractal::Price(PipFractalType Type, int Measure=Expansion)
  {
     switch (Measure)
     {
       case Base:       return(pf[Type].Base);
       case Root:       return(pf[Type].Root);
       case Expansion:  return(pf[Type].Expansion);
       case Retrace:    return(pf[Type].Retrace);
       case Recovery:   return(pf[Type].Recovery);
     }
    
    return (0.00);
  }

//+------------------------------------------------------------------+
//| Fibonacci - Returns fibo percent or Price for supplied params    |
//+------------------------------------------------------------------+
double CPipFractal::Fibonacci(PipFractalType Type, int Method, int Measure, int Format=InDecimal)
  {
    int fFormat   = 1;
    
    if (Format == InPercent)
      fFormat     = 100;
      
    switch (Method)
    {
      case Retrace:   switch (Measure)
                      {
                        case Now: return (fdiv(Close[0]-pf[Type].Expansion,pf[Type].Root-pf[Type].Expansion,3)*fFormat);
                        case Max: return (fdiv(pf[Type].Retrace-pf[Type].Expansion,pf[Type].Root-pf[Type].Expansion,3)*fFormat);
                        case Min: return (fdiv(pf[Type].Recovery-pf[Type].Expansion,pf[Type].Root-pf[Type].Expansion,3)*fFormat);
                      }
                      break;
                       
      case Expansion: switch (Measure)
                      {
                        case Now: return (fdiv(Close[0]-pf[Type].Root,pf[Type].Base-pf[Type].Root,3)*fFormat);
                        case Max: return (fdiv(pf[Type].Expansion-pf[Type].Root,pf[Type].Base-pf[Type].Root,3)*fFormat);
                        case Min: return (fdiv(pf[Type].Retrace-pf[Type].Root,pf[Type].Base-pf[Type].Root,3)*fFormat);
                      }
      case Forecast:  return(NormalizeDouble(pf[Type].Root+((pf[Type].Base-pf[Type].Root)*FiboPercent(Measure)),Digits));
    }
    
    return (0.00);
  }

//+------------------------------------------------------------------+
//|  Direction - returns the direction for the supplied type         |
//+------------------------------------------------------------------+
int CPipFractal::Direction(int Type, bool Contrarian=false)
  {
    int dContrary     = 1;
    
    if (Contrarian)
      dContrary       = DirectionInverse;

    switch (Type)
    {
      case pftOrigin:
      case pftTrend:       
      case pftTerm:       return (pf[Type].Direction*dContrary);
      case PolyTrend:     return (prPolyTrendDir*dContrary);
      case Polyline:      return (prPolyDirection*dContrary);
      case Trendline:     return (trTrendlineDir*dContrary);
      case Pivot:         return (trPivotDir*dContrary);
      case StdDev:        return (trStdDevDir*dContrary);
      case Range:         return (ptrRangeDir*dContrary);
      case RangeHigh:     return (ptrRangeDirHigh*dContrary);
      case RangeLow:      return (ptrRangeDirLow*dContrary);
      case Boundary:      if ((ptrRangeAgeLow-ptrRangeAgeHigh)*dContrary>0) return (DirectionUp);
                          if ((ptrRangeAgeLow-ptrRangeAgeHigh)*dContrary<0) return (DirectionDown);
                          return (this.Direction(Range));
      case Aggregate:     return (BoolToInt(ptrRangeDirHigh==ptrRangeDirLow,ptrRangeDirHigh*dContrary,DirectionNone));
      case Tick:          return (ptrTickDir*dContrary);
    }
    
    return (DirectionNone);
  }

//+------------------------------------------------------------------+
//| ShowFiboArrow - paints the pipMA fibo arrow                      |
//+------------------------------------------------------------------+
void CPipFractal::ShowFiboArrow(double Price=0.00)
  {
    uchar     sfaArrowCode      = SYMBOL_DASH;
    double    sfaExpansion      = Fibonacci(pftTerm,Expansion,Max);
           
    if (sfaExpansion>FiboPercent(Fibo823))
      sfaArrowCode              = SYMBOL_POINT4;
    else
    if (sfaExpansion>FiboPercent(Fibo423))
      sfaArrowCode              = SYMBOL_POINT3;
    else
    if (sfaExpansion>FiboPercent(Fibo261))
      sfaArrowCode              = SYMBOL_POINT2;
    else  
    if (sfaExpansion>FiboPercent(Fibo161))
      sfaArrowCode              = SYMBOL_POINT1;
    else
    if (sfaExpansion>FiboPercent(Fibo100))
      sfaArrowCode              = SYMBOL_CHECKSIGN;
    else
      sfaArrowCode              = SYMBOL_DASH;

    if (IsChanged(arrowDir,Direction(pftTerm)))
    {
      arrowPrice                = BoolToDouble(IsEqual(Price,0.00),Close[pfBar],Price,Digits);
      arrowName                 = NewArrow(sfaArrowCode,DirColor(arrowDir,clrYellow),DirText(arrowDir)+(string)arrowIdx++,arrowPrice,pfBar);
      
      if (Direction(pftTerm)==DirectionUp)   pfHiBar = pfBar;
      if (Direction(pftTerm)==DirectionDown) pfLoBar = pfBar;

      if (pfHiBar>NoValue&&pfLoBar>NoValue)
      {
        NewRay("r:"+(string)arrowIdx,false);
        UpdateRay("r:"+(string)arrowIdx,High[pfHiBar],pfHiBar,Low[pfLoBar],pfLoBar,STYLE_SOLID,Color(pfLoBar-pfHiBar,IN_DARK_DIR));
      }

    }
     
    switch (arrowDir)
    {
      case DirectionUp:    if (IsChanged(arrowPrice,fmax(arrowPrice,High[pfBar])))
                           {
                             pfHiBar = pfBar;
                             
                             UpdateArrow(arrowName,sfaArrowCode,DirColor(arrowDir,clrYellow),arrowPrice);
                             UpdateRay("r:"+(string)arrowIdx,High[pfHiBar],pfHiBar,Low[pfLoBar],pfLoBar,STYLE_SOLID,Color(pfLoBar-pfHiBar,IN_DARK_DIR));
                           }
                           break;
      case DirectionDown:  if (IsChanged(arrowPrice,fmin(arrowPrice,Low[pfBar])))
                           {
                             pfLoBar = pfBar;
                             
                             UpdateArrow(arrowName,sfaArrowCode,DirColor(arrowDir,clrYellow),arrowPrice);
                             UpdateRay("r:"+(string)arrowIdx,High[pfHiBar],pfHiBar,Low[pfLoBar],pfLoBar,STYLE_SOLID,Color(pfLoBar-pfHiBar,IN_DARK_DIR));
                           }
                           break;
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Prints PipFractal metrics to comment             |
//+------------------------------------------------------------------+
void CPipFractal::RefreshScreen(void)
  { 
    Comment("\n*--- PipFractal ---*\n"
           +"  FOC: "+DirText(FOCDirection(trTrendlineTolerance))+" "+DoubleToStr(FOC(Now),1)+"/"+DoubleToStr(FOC(Deviation),1)
           +"  Pivot: "+DoubleToStr(Pip(Pivot(Deviation)),1)+"/"+DoubleToStr(Pip(Pivot(Max)),1)
           +"  Range: "+DoubleToStr(Pip(Range(Size)),1)+"\n"
           +"  Poly: "+EnumToString(prPolyState)+"  ("+DirText(Direction(Polyline))+"/"+DirText(Direction(PolyTrend))+")\n"
           +"  Std Dev: "+DoubleToStr(Pip(StdDev(Now)),1)
               +" x:"+DoubleToStr(fmax(Pip(StdDev(Positive)),fabs(Pip(StdDev(Negative)))),1)
               +" p:"+DoubleToStr(Pip(StdDev()),1)
               +" +"+DoubleToStr(Pip(StdDev(Positive)),1)
               +" "+DoubleToStr(Pip(StdDev(Negative)),1)+"\n\n"
           +"  Term: "+DirText(Direction(pftTerm))+"\n"
           +"     Base: "+DoubleToStr(pf[pftTerm].Base,Digits)+" Root: "+DoubleToStr(pf[pftTerm].Root,Digits)+" Expansion: "+DoubleToStr(pf[pftTerm].Expansion,Digits)+"\n"
           +"     Retrace: "+DoubleToStr(Fibonacci(pftTerm,Retrace,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(pftTerm,Retrace,Max,InPercent),1)+"%"
           +"   Expansion: "+DoubleToStr(Fibonacci(pftTerm,Expansion,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(pftTerm,Expansion,Max,InPercent),1)+"%\n\n"
           +"  Trend: "+DirText(Direction(pftTrend))+"\n"
           +"     Base: "+DoubleToStr(pf[pftTrend].Base,Digits)+" Root: "+DoubleToStr(pf[pftTrend].Root,Digits)+" Expansion: "+DoubleToStr(pf[pftTrend].Expansion,Digits)+"\n"
           +"     Retrace: "+DoubleToStr(Fibonacci(pftTrend,Retrace,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(pftTrend,Retrace,Max,InPercent),1)+"%"
           +"   Expansion: "+DoubleToStr(Fibonacci(pftTrend,Expansion,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(pftTrend,Expansion,Max,InPercent),1)+"%\n\n"
           +"  Origin: "+DirText(Direction(pftOrigin))+"\n"
           +"     Base: "+DoubleToStr(pf[pftOrigin].Base,Digits)+" Root: "+DoubleToStr(pf[pftOrigin].Root,Digits)+" Expansion: "+DoubleToStr(pf[pftOrigin].Expansion,Digits)+"\n"       
           +"     Retrace: "+DoubleToStr(Fibonacci(pftOrigin,Retrace,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(pftOrigin,Retrace,Max,InPercent),1)+"%"
           +"   Expansion: "+DoubleToStr(Fibonacci(pftOrigin,Expansion,Now,InPercent),1)+"% "+DoubleToStr(Fibonacci(pftOrigin,Expansion,Max,InPercent),1)+"%\n"
           +"\nPipMA Active "+ActiveEventText());
  }

