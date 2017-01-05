//+------------------------------------------------------------------+
//|                                                       man-v4.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.01"
#property strict

#include <Class\PipFractal.mqh>
#include <Class\TrendRegression.mqh>
#include <manual.mqh>

input string appHeader               = "";    //+------ App Inputs -------+
input bool   inpShowFiboLines        = false; // Display Fibonacci Lines
input double inpTrendWane            = 3.6;   // Trend wane retention factor
input double inpTrailFactor          = 3.6;   // Trailing factor for Stops/Limits/MITs

input string prHeader                = "";    //+---- Regression Inputs -----+
input int    inpDegree               = 6;     // Degree of poly regression
input int    inpSTPeriods            = 200;   // Short Term (Pip) periods
input int    inpMTPeriods            = 60;    // Mid Term (Trend) periods
input int    inpLTPeriods            = 120;   // Long Term (Trend) periods
input int    inpSmoothFactor         = 3;     // Moving Average smoothing factor
input double inpTolerance            = 0.5;   // Trend change sensitivity

input string fractalHeader           = "";    //+------ Fractal inputs ------+
input int    inpRangeMax             = 30;    // Maximum fractal pip range
input int    inpRangeMin             = 15;    // Minimum fractal pip range

//--- Class defs
  CFractal         *fractal          = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal         = new CPipFractal(inpDegree,inpSTPeriods,inpTolerance,fractal);
  CTrendRegression *trendLT          = new CTrendRegression(inpDegree,inpLTPeriods,inpSmoothFactor);
  CTrendRegression *trendMT          = new CTrendRegression(inpDegree,inpMTPeriods,inpSmoothFactor);

//--- Screen data show/hide flags
  string rsComment                   = "";
  bool   rsShowFractalData           = false;
  bool   rsShowPipMAData             = false;
  
//--- Operational variables
  int    alStdDevDir                 = DirectionNone;
  double alStdDevPrice               = 0.00;
  double alStdDevLevel               = 0.00;
  double alStdDevTop                 = 0.00;
  double alStdDevBottom              = 0.00;

  double alPolyCrossPrice[2]         = {0.00,0.00};
  int    alPolyCrossDir              = DirectionNone;
  int    alTradeDir                  = DirectionNone;
  bool   alCounterTrend              = false;
  bool   alCounterPush               = false;
  bool   alAlertTrendWane            = false;
  bool   alAlertTrendDir             = false;
   
  bool   pmProfitTakes[RetraceTypeMembers];
  int    pmProfitDir                 = DirectionNone;
  int    pmProfitAction              = OP_NO_ACTION;
  bool   pmProfitMode                = false;

  int    omTradeDir                  = DirectionNone;
  int    omTradeAction               = OP_NO_ACTION;
  bool   omOrderMode                 = false;
  
  bool   rmStopsOn                   = true;

  
//+------------------------------------------------------------------+
//| ShowStdDevChannel                                                |
//+------------------------------------------------------------------+
void ShowStdDevChannel(void)
  {
    static string steArrowName  = "";
    static double steArrowPrice = Close[0];
    static int    steArrowCode  = SYMBOL_CHECKSIGN;
    static int    steStdDevDir  = DirectionNone;
    
    if (IsChanged(steStdDevDir,alStdDevDir))
    {
      steArrowPrice     = Close[0];
      steArrowCode      = BoolToInt(alStdDevDir==DirectionDown,SYMBOL_ARROWDOWN,SYMBOL_ARROWUP);
      steArrowName      = NewArrow(steArrowCode,DirColor(steStdDevDir),DirText(steStdDevDir),steArrowPrice);
    }    
  }

//+------------------------------------------------------------------+
//| ShowPipMAData                                                    |
//+------------------------------------------------------------------+
void ShowPipMAData(void)
  { 
    rsComment += "\n*--- PipFractal ---*\n"
           +"Term: "+DirText(pfractal[Term].Direction)
           +"  (rt): "+DoubleToStr(pfractal.Fibonacci(Term,pfractal.Direction(Term),Retrace,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(pfractal.Fibonacci(Term,pfractal.Direction(Term),Retrace,Max,InPercent),1)+"%"
           +"  (e): "+DoubleToStr(pfractal.Fibonacci(Term,pfractal.Direction(Term),Expansion,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(pfractal.Fibonacci(Term,pfractal.Direction(Term),Expansion,Max,InPercent),1)+"%\n"
           +"Trend: "+DirText(pfractal[Trend].Direction)
           +"  (rt): "+DoubleToStr(pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Retrace,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Retrace,Max,InPercent),1)+"%"
           +"  (e): "+DoubleToStr(pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Expansion,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Expansion,Max,InPercent),1)+"%\n"
           +"Origin: "+DirText(pfractal.Direction(Origin))
           +"  (rt): "+DoubleToStr(pfractal.Fibonacci(Origin,pfractal.Direction(Origin),Retrace,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(pfractal.Fibonacci(Origin,pfractal.Direction(Origin),Retrace,Max,InPercent),1)+"%"
           +"  (e): "+DoubleToStr(pfractal.Fibonacci(Origin,pfractal.Direction(Origin),Expansion,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(pfractal.Fibonacci(Origin,pfractal.Direction(Origin),Expansion,Max,InPercent),1)+"%\n";
    rsComment += "Age: "+IntegerToString(pfractal.Count(Range))+"\n";
  
  }

//+------------------------------------------------------------------+
//| ShowFractalData                                                  |
//+------------------------------------------------------------------+
void ShowFractalData(void)
  { 
    const string  rsSeg[RetraceTypeMembers] = {"tr","tm","p","b","r","e","d","c","iv","cv","a"};
 
    rsComment   += "\n--- Fractal ---";
    rsComment   += "\n  Origin:\n";
    rsComment   +="      (o): "+BoolToStr(fractal.Origin().Direction==DirectionUp,"Long","Short");

    Append(rsComment,BoolToStr(fractal.Origin().Peg,"Peg"));
    Append(rsComment,BoolToStr(fractal.Origin().Breakout,"Breakout"));
    Append(rsComment,BoolToStr(fractal.Origin().Reversal,"Reversal"));

    rsComment   +="  Bar: "+IntegerToString(fractal.Origin().Bar)
                +"  Top: "+DoubleToStr(fractal.Origin().Top,Digits)
                +"  Bottom: "+DoubleToStr(fractal.Origin().Bottom,Digits)
                +"  Price: "+DoubleToStr(fractal.Origin().Price,Digits)+"\n";
                   
    rsComment   +="             Retrace: "+DoubleToString(fractal.Origin(Now).Retrace*100,1)+"%"
                +" "+DoubleToString(fractal.Origin(Max).Retrace*100,1)+"%"
                +"  Expansion: " +DoubleToString(fractal.Origin(Now).Expansion*100,1)+"%"
                +" "+DoubleToString(fractal.Origin(Max).Expansion*100,1)+"%"
                +"  Leg: (c) "+DoubleToString(Pip(fractal.Origin().Range),1)+" (a) "+DoubleToString(Pip(fractal.Origin(Max).Range),1)+"\n";
      
    for (RetraceType type=Trend;type<=fractal.State();type++)
      if (fractal[type].Bar>NoValue)
      {
        if (type == fractal.Dominant(Trend))
          rsComment  += "\n  Trend:\n";
        else
        if (type == fractal.Dominant(Term))
          rsComment  += "\n  Term:\n";
        else
        if (type == fractal.State())
          if (type < Actual)
            rsComment+= "\n  Actual:\n";

        rsComment    +="      ("+rsSeg[type]+"): "+BoolToStr(fractal.Direction(type)==DirectionUp,"Long","Short")
                     +BoolToStr(fractal.Leg(type,Peg) == Tick,"","  "+EnumToString(fractal.Leg(type,Peg)));

        rsComment    +="  Bar: ";
        rsComment    += BoolToStr(type==Trend,IntegerToString(fractal.Origin(Actual).Bar),IntegerToString(fractal[type].Bar));

        rsComment    +="  Top: "+DoubleToStr(fractal.Range(type,Top),Digits)
                     +"  Bottom: "+DoubleToStr(fractal.Range(type,Bottom),Digits)
                     +"  Price: ";
                       
        rsComment    += BoolToStr(type==Trend,DoubleToStr(fractal.Origin(Actual).Price,Digits),DoubleToStr(fractal.Price(type),Digits))+"\n";
        rsComment    +="             Retrace: "+DoubleToString(fractal.Fibonacci(type,Retrace,Now,InPercent),1)+"%"
                     +" "+DoubleToString(fractal.Fibonacci(type,Retrace,Max,InPercent),1)+"%"
                     +"  Expansion: " +DoubleToString(fractal.Fibonacci(type,Expansion,Now,InPercent),1)+"%"
                     +" "+DoubleToString(fractal.Fibonacci(type,Expansion,Max,InPercent),1)+"%"
                     +"  Leg: (c) "+DoubleToString(fractal.Range(type,Now,InPips),1)+" (a) "+DoubleToString(fractal.Range(type,Max,InPips),1)+"\n";
      } else break;
  }
  
//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    rsComment   = "";
      
    rsComment     += "--- Alerts ---\n"
                  +  BoolToStr(fractal.Event(Trap23),"  Reversal (Fibo23)\n")
                  +  BoolToStr(fractal.Event(NewFractal),"  New Fractal\n")
                  +  BoolToStr(fractal.Event(NewMajor),"  New Major\n")
                  +  BoolToStr(fractal.Event(NewMinor),"  New Minor\n")
                  +  BoolToStr(alAlertTrendWane,"  Trend (Wane)\n")
                  +  BoolToStr(omOrderMode,"  Order Time! ("+DoubleToStr(fractal.Fibonacci(Expansion,Retrace,Now,InPercent),1)+"%)\n")
                  +  BoolToStr(pmProfitMode,"  Profit Time!\n");
                         
    if (rsShowFractalData)
      ShowFractalData();

    if (rsShowPipMAData)      
      ShowPipMAData();
      
    //--- Standard Deviation channel lines    
    UpdateRay("stdDevHigh",trendMT.Trendline(Tail)+trendMT.StdDev(Positive),inpMTPeriods-1,trendMT.Trendline(Head)+trendMT.StdDev(Positive),0,STYLE_DOT,clrYellow);
    UpdateRay("stdDevLow",trendMT.Trendline(Tail)+trendMT.StdDev(Negative),inpMTPeriods-1,trendMT.Trendline(Head)+trendMT.StdDev(Negative),0,STYLE_DOT,clrRed);

    //--- Poly Cross price labels
    //UpdatePriceLabel("alPolyCrossShort",alPolyCrossPrice[OP_SELL],BoolToInt(alPolyCrossDir==DirectionDown,clrRed,clrMaroon));
    //UpdatePriceLabel("alPolyCrossLong",alPolyCrossPrice[OP_BUY],BoolToInt(alPolyCrossDir==DirectionUp,clrLawnGreen,clrForestGreen));
    UpdatePriceLabel("alStdDevPrice",alStdDevPrice,DirColor(trendLT.Direction(StdDev)));
    UpdatePriceLabel("alLTMA",trendLT.MA(Mean),DirColor(trendLT.Direction(StdDev)));
    
    UpdateDirection("alStdDevDir",alStdDevDir,DirColor(alStdDevDir));
    UpdateDirection("alPolyCrossDir",alPolyCrossDir,DirColor(alPolyCrossDir));

    if (alCounterPush)
      UpdateLine("alCounterTrend",alStdDevLevel,STYLE_DASHDOTDOT,clrWhite);
    else
    if (alCounterTrend)
      UpdateLine("alCounterTrend",alStdDevLevel,STYLE_DASHDOTDOT,clrYellow);
    else
      UpdateLine("alCounterTrend",alStdDevLevel,STYLE_DASHDOTDOT,clrGray);

    UpdateLine("alTrendPivot",fractal.Price(Trend),STYLE_SOLID,clrGoldenrod);
    
    ShowStdDevChannel();

    Comment(rsComment);
  }

//+------------------------------------------------------------------+
//| AnalyzeMarket                                                    |
//+------------------------------------------------------------------+
void AnalyzeMarket(void)
  {
    static int amMinorDir = DirectionNone;

    alStdDevTop           = trendMT.Trendline(Head)+trendMT.StdDev(Positive);
    alStdDevBottom        = trendMT.Trendline(Head)+trendMT.StdDev(Negative);
    alStdDevPrice         = trendMT.Trendline(Head)+trendMT.StdDev(Now);
        
    //--- Pauses for testing
    if (fractal.Event(NewFractal))
      Pause("New Fractal!","Fractal.Event()");
    else
    
    if (fractal.Event(NewMajor))
      Pause("New Major!","Fractal.Event()");
    else
    
    if (fractal.Event(NewMinor))
      if (IsChanged(amMinorDir,fractal.Direction(fractal.State(Minor))))
        Pause("New Minor!","Fractal.Event()");
    //---------------------

    if (IsChanged(alStdDevDir,trendMT.Direction(StdDev)))
      if (trendMT.Direction(Trendline)==alStdDevDir)
      {
        alCounterTrend             = false;
        alCounterPush              = false;
      }
      else
      {
        alCounterTrend             = true;
        alStdDevLevel              = BoolToDouble(alStdDevDir==DirectionUp,alStdDevBottom,alStdDevTop);
      }
      
    if (alCounterTrend)
    {
      if (alStdDevDir==DirectionDown)
      {
        alStdDevLevel              = fmin(alStdDevTop,alStdDevLevel);
        
        if (IsHigher(Close[0],alStdDevLevel))
          alCounterPush            = true;
      }
      else
      if (alStdDevDir==DirectionUp)
      {
        alStdDevLevel              = fmax(alStdDevBottom,alStdDevLevel);

        if (IsLower(Close[0],alStdDevLevel))
          alCounterPush            = true;
      }
    }      
        
    if (trendMT.Direction(Polyline)==trendLT.Direction(Polyline))
    {
      alAlertTrendDir              = true;
      alTradeDir                   = trendMT.Direction(Polyline);

      if (IsChanged(alPolyCrossDir,trendMT.Direction(Polyline)))
        alPolyCrossPrice[DirAction(alPolyCrossDir)] = Close[0];
    }    
    else
    {
      if (alAlertTrendDir)
        alAlertTrendDir            = false;
      else
        alTradeDir                 = DirectionNone;
    }
    
    //--- Compute wane flags and trend alerts
    if (fabs(trendLT.FOC(Retrace))>FiboPercent(Fibo50))
      alAlertTrendWane               = true;
    
    if (fabs(trendLT.FOC(Retrace))<FiboPercent(Fibo38))
      alAlertTrendWane               = false;
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    fractal.Update();
    pfractal.Update();
    trendLT.Update();
    trendMT.Update();

    AnalyzeMarket();
  }

//+------------------------------------------------------------------+
//| NewOrder                                                         |
//+------------------------------------------------------------------+
void NewOrder(void)
  {
    static const double noTrail    = Pip(inpTrailFactor,InPoints);
  
    if (fractal.State(Major)==Divergent)
    {
      if (fractal.Direction(Divergent)==DirectionUp)
      {
        if (alStdDevTop>fractal.Price(Divergent))
          if (Close[0]<alStdDevPrice)
            OpenLimitOrder(OP_SELL,alStdDevPrice,0.00,0.00,noTrail,"Short(StdDev)");

        //if (trendMT.Direction(Polyline)==fractal.Direction())
        //  if (Close[0]<trendMT.Poly(Head))
        //    if (Close[0]<alStdDevPrice)
        //      OpenLimitOrder(OP_SELL,alStdDevPrice,0.00,0.00,noTrail,"Short(Poly)");
      }
      
      if (fractal.Direction(Divergent)==DirectionDown)
      {
        if (alStdDevBottom<fractal.Price(Divergent))
          if (Close[0]>alStdDevPrice)
            OpenLimitOrder(OP_BUY,alStdDevPrice,0.00,0.00,noTrail,"Long(StdDev)");

        if (trendMT.Direction(Polyline)==fractal.Direction())
          if (Close[0]>trendMT.Poly(Head))
            if (Close[0]>alStdDevPrice)
              OpenLimitOrder(OP_BUY,alStdDevPrice,0.00,0.00,noTrail,"Long(Poly)");
      }
    }
    else
    
    if (fractal.State(Major)==Convergent)
    {}
    
  }
  
//+------------------------------------------------------------------+
//| OrderManager                                                     |
//+------------------------------------------------------------------+
void OrderManager(void)
  {
    if (OrderFulfilled())
      omOrderMode      = false;
      
    if (fractal.Event(NewFractal))
      omOrderMode      = false;
    else
    
    if (fractal.Event(NewMajor))
      omOrderMode      = true;
    else
    
    if (fractal.Event(NewMinor))
    {
    }
    
    if (omOrderMode)
      NewOrder();
  }

//+------------------------------------------------------------------+
//| RiskManager                                                      |
//+------------------------------------------------------------------+
void RiskManager(void)
  {
    int           rmRiskAction      = fractal.Direction(Expansion,false,InAction);
    
    //--- Protective stop
    if (rmStopsOn)
    {
      if (fractal.Fibonacci(Base,Expansion,Now)>FiboPercent(Fibo100))
        SetStopPrice(rmRiskAction,FiboPrice(FiboRoot,fractal[Root].Price,fractal[Expansion].Price,Retrace));
    }
    else
    {
      SetStopPrice(OP_BUY);
      SetStopPrice(OP_SELL);
    }  
  }

//+------------------------------------------------------------------+
//| ExecuteTakeProfit                                                |
//+------------------------------------------------------------------+
void ShowTakeProfit(RetraceType Type, string ProfitReason="")
  {
    string etpComment    = "WTF?!? "+EnumToString(Type)+":"+ProfitReason+"\n";
          
    for (RetraceType flag=0;flag<Expansion; flag++)
      etpComment += EnumToString(flag)+": "
                   +BoolToStr(pmProfitTakes[flag],"Completed","Pending")
                   +" ("+DoubleToStr(fractal.Fibonacci(flag,Expansion,Now,InPercent),1)+"%)"
                   +"\n";
          
//    Pause(etpComment,"Why do I prematurely profit?");
  }

//+------------------------------------------------------------------+
//| ExecuteTakeProfit                                                |
//+------------------------------------------------------------------+
bool ExecuteTakeProfit(string ProfitReason="")
  {
    for (RetraceType type=0; type<Expansion; type++)
      if (fractal.Fibonacci(type,Expansion,Now)>FiboPercent(Fibo161))
        if (!pmProfitTakes[type])
        {
          pmProfitTakes[type]       = true;
          ShowTakeProfit(type, ProfitReason);
          return (CloseOrders(CloseConditional,pmProfitAction,ProfitReason));
        }            
        
    return (false);
  }
  
//+------------------------------------------------------------------+
//| ProfitManager                                                    |
//+------------------------------------------------------------------+
void ProfitManager(void)
  {
    pmProfitDir                     = fractal.Direction(Expansion);
    pmProfitAction                  = DirAction(pmProfitDir);
    
    if (fractal.Event(NewFractal))
    {
      ArrayInitialize(pmProfitTakes,false);

      for (RetraceType type=0; type<Expansion; type++)
        if (fractal.Fibonacci(type,Expansion,Max)>FiboPercent(Fibo161))
          pmProfitTakes[type]       = true;

      pmProfitMode                  = false;
    }
      
    for (RetraceType type=0; type<Expansion; type++)
      if (fractal.Fibonacci(type,Expansion,Now)>FiboPercent(Fibo161))
        if (!pmProfitTakes[type])
          if (!pmProfitMode)
            if (LotCount(pmProfitAction)>0.00)
              pmProfitMode            = true;
    
    if (trendLT.FOC(Deviation)<inpTrendWane)
    {
      if (pfractal.Event(TrendWane))
        ExecuteTakeProfit("Trend Hold");
    }
    else
      ExecuteTakeProfit("Trend Immediate");
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static int eOK    = IDOK;

    if (pfractal.Event(HistoryLoaded))
      if (eOK == IDOK)
        eOK    = Pause("PipMA History Loaded. Resume next tick?","History Load Complete",MB_ICONQUESTION|MB_OKCANCEL|MB_DEFBUTTON2);        

    OrderManager();
    RiskManager();
    ProfitManager();      
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    string eacComment = "";
    
    if (Command[0]=="SHOW")
    {
      if (Command[1]=="PROFIT")
      {
        if (Command[2]=="FLAGS")
        {
          for (RetraceType flag=0;flag<Expansion; flag++)
            eacComment += EnumToString(flag)+": "
                         +BoolToStr(pmProfitTakes[flag],"Completed","Pending")
                         +"\n";
          Pause(eacComment,"Profit Take Status");
        }
      }
      else

      if (InStr(Command[1],"FIB"))
        rsShowFractalData     = true;
      else
      
      if (InStr(Command[1],"PIP"))
        rsShowPipMAData       = true;
    }
    else

    if (Command[0]=="HIDE")
    {
      if (InStr(Command[1],"FIB"))
        rsShowFractalData     = false;
      else

      if (InStr(Command[1],"PIP"))
        rsShowPipMAData       = false;
    }
    else    

    if (StringSubstr(Command[0],0,3)=="ORD") //--- application order command
    {
      if (InStr(Command[1],"STOP"))
        rmStopsOn             = true;      
    }
    else    

    if (StringSubstr(Command[0],0,2)=="EN") //--- Enable command
    {
      if (InStr(Command[1],"STOP"))
        rmStopsOn             = true;      
    }
    else    

    if (StringSubstr(Command[0],0,3)=="DIS") //--- Disable command
    {
      if (InStr(Command[1],"STOP"))
        rmStopsOn             = false;      
    }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    string     otParams[];
  
    InitializeTick();

    GetManualRequest();

    while (AppCommand(otParams,6))
      ExecAppCommands(otParams);

    OrderMonitor();
    GetData(); 

    RefreshScreen();
    
    if (AutoTrade())
      Execute();
    
    ReconcileTick();        
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    ManualInit();
    
    NewRay("stdDevHigh",false);
    NewRay("stdDevLow",false);
    
    NewLine("alCounterTrend");
    NewLine("alTrendPivot");

//    NewPriceLabel("alPolyCrossShort");
//    NewPriceLabel("alPolyCrossLong");
    NewPriceLabel("alLTMA");
    NewPriceLabel("alStdDevPrice");
    
    NewLabel("StdDev:","StdDev:",25,16,clrLightGray,SCREEN_LR,0);
    NewLabel("PolyCross:","PolyCross:",25,5,clrLightGray,SCREEN_LR,0);

    NewLabel("alStdDevDir","",5,16,clrLightGray,SCREEN_LR,0);
    NewLabel("alPolyCrossDir","",5,5,clrLightGray,SCREEN_LR,0);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete trendMT;
    delete trendLT;
    delete pfractal;
  }