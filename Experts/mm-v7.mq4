//+------------------------------------------------------------------+
//|                                                        mm-v7.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\PipFractal.mqh>
#include <Class\TrendRegression.mqh>
#include <manual.mqh>

input string prHeader                = "";    //+---- Regression Inputs -----+
input int    inpDegree               = 6;     // Degree of poly regression
input int    inpPipPeriods           = 200;   // Pip history regression periods
input int    inpTrendPeriods         = 24;    // Trend regression periods
input int    inpSmoothFactor         = 3;     // Moving Average smoothing factor
input double inpTolerance            = 0.5;   // Trend change sensitivity

input string fractalHeader           = "";    //+------ Fractal Inputs ------+
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpRangeMin             = 60;    // Minimum fractal pip range

input string mmv7Header              = "";    //+----- Management Inputs ----+
input double inpTargetBuffer         = 2.0;   // New order target buffer pips
input double inpGeneralTrail         = 2.0;   // Profit/Contrarian open trail pips
input int    inpTermLotMod           = 2;     // Term LotSize risk adjustment
input int    inpTrendLotMod          = 4;     // Trend LotSize risk adjustment
input int    inpMaxContrarianDeficit = 5.0;   // Max drawdown for contrarian trades

//--- Class defs
  CFractal         *fractal          = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal         = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);  
  CTrendRegression *trend            = new CTrendRegression(inpDegree,inpTrendPeriods,inpSmoothFactor);  


  int        pfTrendDirChanged       = false;         //--- junior trend change
  int        pfTermDirChanged        = false;         //--- junior term change
  
  double     pfTargetPrice[2]        = {0.00,0.00};   //--- junior targets (buy, sell)
  double     fTargetPrice[2]         = {0.00,0.00};   //--- senior targets (buy, sell)
  
  double     mmTargetBuffer          = Pip(inpTargetBuffer,InPoints);

  double     mmProfitHold            = 0.00;
  int        mmProfitLevel           = Fibo161;

  int        mmAction                = OP_NO_ACTION;  
  int        mmPriceDir              = DirectionNone;
  int        mmTradeDir              = DirectionNone;
  
  int        mmOrderLevel            = Fibo161;
  int        mmLotModifier[2]        = {0.00,0.00}; 
  
//+------------------------------------------------------------------+
//| SetFiboArrow - paints the pipMA zero arrow                       |
//+------------------------------------------------------------------+
void SetFiboArrow(int Direction)
  {
    static string    arrowName      = "";
    static int       arrowDir       = DirectionNone;
    static double    arrowPrice     = 0.00;
           uchar     arrowCode      = SYMBOL_DASH;
           
    if (IsChanged(arrowDir,Direction))
    {
      arrowPrice                    = Close[0];
      arrowName                     = NewArrow(arrowCode,DirColor(arrowDir,clrYellow),DirText(arrowDir),arrowPrice);
    }
     
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboLevel(Fibo823))
      arrowCode                     = SYMBOL_POINT4;
    else
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboLevel(Fibo423))
      arrowCode                     = SYMBOL_POINT3;
    else
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboLevel(Fibo261))
      arrowCode                     = SYMBOL_POINT2;
    else  
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboLevel(Fibo161))
      arrowCode                     = SYMBOL_POINT1;
    else
    if (pfractal.Fibonacci(Term,Direction,Expansion,Max)>FiboLevel(Fibo100))
      arrowCode                     = SYMBOL_CHECKSIGN;
    else
      arrowCode                     = SYMBOL_DASH;

    switch (Direction)
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
//| GetData - retrieve and organize operational data                 |
//+------------------------------------------------------------------+
void GetData(void)
  {
    static int gdTrendDir       = DirectionNone;
    static int gdTermDir        = DirectionNone;
    
    fractal.Update();
    pfractal.Update();
    trend.Update();
        
    pfTrendDirChanged           = false;
    pfTermDirChanged            = false;
    
    if (gdTrendDir == DirectionNone)
    {
      gdTrendDir                = pfractal[Trend].Direction;
      gdTermDir                 = pfractal[Term].Direction;
    }
    else  
    if (IsChanged(gdTrendDir,pfractal[Trend].Direction))
    {
      pfTrendDirChanged         = true;
      mmAction                  = DirectionAction(pfractal[Trend].Direction);
    }

    if (IsChanged(gdTermDir,pfractal[Term].Direction))
    {
      pfTermDirChanged          = true;
      
      mmOrderLevel              = Fibo161;
      mmProfitLevel             = Fibo161;
    }
    
    if (pfractal[Trend].Direction == DirectionDown)
      if (IsChanged(pfTargetPrice[OP_SELL],FibonacciPrice(mmProfitLevel,pfractal[Trend].Base,pfractal[Trend].Root)))
        UpdatePriceLabel("pfSTrend161",FibonacciPrice(mmProfitLevel,pfractal[Trend].Base,pfractal[Trend].Root),clrMaroon);
    
    if (pfractal[Trend].Direction == DirectionUp)
      if (IsChanged(pfTargetPrice[OP_BUY],FibonacciPrice(mmProfitLevel,pfractal[Trend].Base,pfractal[Trend].Root)))
        UpdatePriceLabel("pfLTrend161",FibonacciPrice(mmProfitLevel,pfractal[Trend].Base,pfractal[Trend].Root),clrForestGreen);
    
    if (fractal[Expansion].Direction == DirectionDown)
      if (IsChanged(fTargetPrice[OP_SELL],FibonacciPrice(Fibo161,fractal[Base].Price,fractal[Root].Price)))
        UpdatePriceLabel("fSExpansion161",fTargetPrice[OP_SELL],clrRed);

    if (fractal[Expansion].Direction == DirectionUp)
      if (IsChanged(fTargetPrice[OP_BUY],FibonacciPrice(Fibo161,fractal[Base].Price,fractal[Root].Price)))
        UpdatePriceLabel("fLExpansion161",fTargetPrice[OP_BUY],clrLawnGreen);

    if (pfractal.Trendline(Head)>trend.Trendline(Head))
    {
      mmPriceDir                 = DirectionUp;
      UpdatePriceLabel("pipMA",pfractal.Trendline(Head),clrYellow);
    }

    if (pfractal.Trendline(Head)<trend.Trendline(Head))
    {
      mmPriceDir                 = DirectionDown;
      UpdatePriceLabel("pipMA",pfractal.Trendline(Head),clrRed);
    }
    
    UpdateLine("pfBase",pfractal[Trend].Base,STYLE_DOT,clrGoldenrod);
    UpdateLine("pfRoot",pfractal[Trend].Root,STYLE_DOT,clrRed);

    SetFiboArrow(pfractal[Term].Direction);
    SetTradingStrategy();

    
    Comment("\nTrade Action: "+BoolToStr(mmAction==OP_NO_ACTION,"Pending",ActionText(mmAction))
           +"  "+BoolToStr(mmPriceDir==DirectionDown," Regr Over Pip","Pip Over Regr")
           +"\nProfit Level: "+DoubleToStr(FiboLevel(mmProfitLevel,InPercent),1)+"%"
           +"  "+BoolToStr(IsEqual(mmProfitHold,0.00,Digits),"","TP "+proper(ActionText(mmAction))+" @ "+DoubleToStr(mmProfitHold,Digits))
           +"  Order Level: "+DoubleToStr(FiboLevel(mmOrderLevel,InPercent),1)+"%"
           +"\nTerm: "+BoolToStr(pfractal[Term].Direction==DirectionUp,"Long","Short")
           +"  "+DoubleToStr(pfractal.Fibonacci(Term,pfractal.Direction(Term),Expansion,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(pfractal.Fibonacci(Term,pfractal.Direction(Term),Expansion,Max,InPercent),1)+"%"
           +"\nTrend: "+BoolToStr(pfractal[Trend].Direction==DirectionUp,"Long","Short")
           +"  "+DoubleToStr(pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Expansion,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(pfractal.Fibonacci(Trend,pfractal.Direction(Trend),Expansion,Max,InPercent),1)+"%"
           +"\nFractal: "+BoolToStr(fractal[Expansion].Direction==DirectionUp,"Long","Short")
           +"  "+DoubleToStr(fractal.Fibonacci(Expansion,Expansion,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(fractal.Fibonacci(Expansion,Expansion,Max,InPercent),1)+"%"
           +"\nInversion: "+DoubleToStr(fractal.Fibonacci(Expansion,Inversion,Now,InPercent),1)+"%"
           +"  "+DoubleToStr(fractal.Fibonacci(Expansion,Inversion,Max,InPercent),1)+"%"
           +"  Root: "+DoubleToStr(fractal.Fibonacci(Root,Inversion,Now,InPercent),1)+"%"
           );
  }

//+------------------------------------------------------------------+
//| SetTradingStrategy - anaylyzes market data; set trade params     |
//+------------------------------------------------------------------+
void SetTradingStrategy(void)
  {
    mmTradeDir                   = fractal[Expansion].Direction;
    
    mmLotModifier[OP_BUY]        = inpTermLotMod;
    mmLotModifier[OP_SELL]       = inpTermLotMod;
    
    if (mmTradeDir == DirectionUp)
      if (pfractal.Count(Trend)>1)
        mmLotModifier[OP_BUY]    = inpTrendLotMod;

    if (mmTradeDir == DirectionDown)
      if (pfractal.Count(Trend)>1)
        mmLotModifier[OP_SELL]   = inpTrendLotMod;
  }
  
//+------------------------------------------------------------------+
//| InTheBuffer - compares price to target; true when within range   |
//+------------------------------------------------------------------+
bool InTheBuffer(int Action)
{
  static double mbLastBuffer = 0.00;
  static int    mbResult     = IDTRYAGAIN;
  
  if (Action == OP_NO_ACTION)
    return (false);
  
  if (mbResult!=IDCANCEL)
  {
    if (IsChanged(mbLastBuffer,pfTargetPrice[Action]))
      mbResult              = IDTRYAGAIN;
    
    if (mbResult != IDCONTINUE)
      mbResult = Pause("In the Buffer!","Buffer Hit",MB_CANCELTRYCONTINUE|MB_ICONEXCLAMATION|MB_DEFBUTTON3);
  }
    
  return(IsBetween(pfTargetPrice[Action],Close[0]+mmTargetBuffer,Close[0]-mmTargetBuffer,Digits));
}

//+------------------------------------------------------------------+
//| Execute - Execute adaptive strategy                              |
//+------------------------------------------------------------------+
void ExecLevelOpen(int Action)
  {
    double eloLotSize   = LotSize()*mmLotModifier[Action];
    
    if (IsEqual(LotCount(),0.00))
      eloLotSize        = HalfLot();

    if (InTheBuffer(Action))
    {
      if (LotValue(Action,Net,InEquity,InContrarian)>-inpMaxContrarianDeficit)
      {
        if (Action == OP_BUY)
          OpenLimitOrder(OP_SELL,pfTargetPrice[Action],pfractal.Range(Bottom),eloLotSize,mmTargetBuffer,"Contrarian");

        if (Action == OP_SELL)
          OpenLimitOrder(OP_BUY,pfTargetPrice[Action],pfractal.Range(Top),eloLotSize,mmTargetBuffer,"Contrarian");
      }
    }
    else
    if (OpenOrder(Action,"LevelOpen",eloLotSize))
      mmOrderLevel++;
  }
  
//+------------------------------------------------------------------+
//| Execute - Execute adaptive strategy                              |
//+------------------------------------------------------------------+
void SetTrendConfirm(int Direction)
  {
    if (Close[0]>=fTargetPrice[OP_BUY])
      SetTrendConfirm(DirectionUp);      
    if (Close[0]<=fTargetPrice[OP_SELL])
      SetTrendConfirm(DirectionDown);

  }

//+------------------------------------------------------------------+
//| Execute - Execute adaptive strategy                              |
//+------------------------------------------------------------------+
void ExecLevelClose(int Action)
  {
    static bool eclTakeProfit        = false;
    
    if (Action == OP_NO_ACTION)
      return;
      
    //--- Address non-profit, no open positions
    if (pfTrendDirChanged || IsEqual(LotCount(Action),0.00,ordLotPrecision))
      mmProfitHold           = 0.00;

    //--- In the buffer target profit
    else
    if (InTheBuffer(Action))
    {
      if (IsEqual(mmProfitHold,0.00))
        mmProfitHold         = pfractal[Term].Root;
      
      if (Close[0]>pfTargetPrice[Action])
      {
        eclTakeProfit        = true;
        mmProfitHold         = pfTargetPrice[Action];
        mmProfitLevel++;
      }      
    }
    
    //--- Out-of-Buffer target adjustment (due to modified profit directives)
//    else
//    if (eclTakeProfit)
//      mmProfitHold           = pfTargetPrice[Action];
    

    //--- Execute profit taking
    if (eclTakeProfit)
      switch (Action)
      {
        case OP_BUY:    if (Close[0]<=mmProfitHold)
                          if (CloseOrders(CLOSE_CONDITIONAL,Action,"Close @"+DoubleToStr(FiboLevel(mmProfitLevel,InPercent),1)+"%"))
                          {
                            mmProfitLevel++;
                            eclTakeProfit     = false;
                          }
                        break;
                      
        case OP_SELL:   if (Close[0]>=mmProfitHold)
                          if (CloseOrders(CLOSE_CONDITIONAL,Action,"Close @"+DoubleToStr(FiboLevel(mmProfitLevel,InPercent),1)+"%"))
                          {
                            mmProfitLevel++;
                            eclTakeProfit     = false;
                          }
      }
  }

//+------------------------------------------------------------------+
//| Execute - Execute adaptive strategy                              |
//+------------------------------------------------------------------+
void Execute()
  {    
    //--- Order Management
    if (OrderFulfilled())
      mmOrderLevel++;
    
    if (!OrderPending())
      if (pfractal.Fibonacci(Term,pfractal[Term].Direction,Expansion,Now)>=FiboLevel(mmOrderLevel))
        ExecLevelOpen(mmAction);


    //--- Profit Management
    ExecLevelClose(mmAction);
  }
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    string otParams[];
    
    GetData();
    
    GetManualRequest();

    if (AppCommand(otParams))
    {
      //--- do something
    };

    OrderMonitor();
    
    if (pfractal.Event(HistoryLoaded))
    {
      Execute();
    }
    
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();
    
//    mmTargetBuffer = Pip(inpTargetBuffer,InPoints);
    
    NewPriceLabel("pipMA");

    NewPriceLabel("pfSTrend161");
    NewPriceLabel("pfLTrend161");
    NewPriceLabel("fSExpansion161");
    NewPriceLabel("fLExpansion161");

    NewLine("pfBase");
    NewLine("pfRoot");
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }