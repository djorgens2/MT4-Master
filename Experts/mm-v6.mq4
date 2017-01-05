//+------------------------------------------------------------------+
//|                                                        mm-v6.mq4 |
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

input string fractalHeader           = "";    //+----- Fractal inputs -----+
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpRangeMin             = 60;    // Minimum fractal pip range

input string inpMMHeader             = "";    //+----- MM inputs -----+
input double inpMaxLotDeficit        = 2.0;   // Maximum lots in drawdown


//--- Class definitions
  CFractal         *fractal          = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal         = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);  
  CTrendRegression *trend            = new CTrendRegression(inpDegree,inpTrendPeriods,inpSmoothFactor);


//--- enums

  enum TradeStates {
                     Hold,
                     Triggered,
                     Pegged,
                     Execute,
                     Fulfilled,
                     Confirmed
                   };
  
//--- Operataional variables

//---
  int            mmTermDir           = DirectionNone;
  int            mmTrendDir          = DirectionNone;
  int            mmTriggerAction     = OP_NO_ACTION;

  double         mmLotSize           = 0.00;
  double         mmTradePivot        = 0.00;
  
  TradeStates    mmTradeState        = Hold;
  TradeStates    mmTradeStateChanged = false;

  int            mmTradeLevel        = Fibo100;
  bool           mmTradeAlert        = false;
  bool           mmHedging           = false;

  int            omAction            = OP_NO_ACTION;
  double         omExecutePrice      = 0.00;
  
//+------------------------------------------------------------------+
//| GetData - retrieve and organize operational data                 |
//+------------------------------------------------------------------+
void GetData(void)
  {    
    fractal.Update();
    pfractal.Update();
    trend.Update();
    
    //--- Term direction
    if (trend.Trendline(Head)>pfractal.Trendline(Head))
      mmTermDir     = DirectionDown;
    
    if (trend.Trendline(Head)<pfractal.Trendline(Head))
      mmTermDir     = DirectionUp;
    
    //--- Trend direction
    mmTrendDir      = fractal.Direction(Expansion);
    mmHedging       = false;
    
    if (pfractal.Direction(Trend)==mmTrendDir)
    {
      if (pfractal.Direction(Term)==mmTrendDir)
        mmLotSize     = LotSize();
      else
        mmLotSize     = LotSize()*pfractal.Count(Trend);
        
      SetActionHold(OP_NO_ACTION);
    }
    else
    {
      SetActionHold(DirectionAction(mmTrendDir));
      
      mmLotSize       = LotSize();
      mmHedging       = true;
    }
  }

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
//| RefreshScreen- Updates screen data and visuals                   |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    if (mmTradeState==Hold)
      UpdatePriceLabel("pipMA",pfractal.Trendline(Head),clrGray);
    else
    if (mmTradeState==Execute)
      UpdatePriceLabel("pipMA",pfractal.Trendline(Head),clrDodgerBlue);
    else
    if (mmTermDir == DirectionUp)
      UpdatePriceLabel("pipMA",pfractal.Trendline(Head),clrYellow);
    else
      UpdatePriceLabel("pipMA",pfractal.Trendline(Head),clrRed);

    SetFiboArrow(pfractal.Direction(Term));

    Comment("Trade State: "+EnumToString(mmTradeState)
              +BoolToStr(mmTradeAlert," Alert!")+"\n"
              +"Fibonacci: "+DoubleToStr(pfractal.Fibonacci(Term,mmTermDir,Expansion,Now,InPercent),1)+"%"
              +"  "+DoubleToStr(pfractal.Fibonacci(Term,mmTermDir,Expansion,Max,InPercent),1)+"%"
              +"  Trade: "+IntegerToString(mmTradeLevel)+" ("+DoubleToStr(FiboLevel(mmTradeLevel,InPercent),1)+"%)\n"
              +"LotSize: "+DoubleToStr(mmLotSize,ordLotPrecision)+BoolToStr(mmHedging," Hedging!")
           );
  }
  
//+------------------------------------------------------------------+
//| StrategyManager - Updates trading strategy on the tick           |
//+------------------------------------------------------------------+
void StrategyManager(void)
  {
    TradeStates smLastTradeState     = mmTradeState;
    mmTradeStateChanged              = false;
    
    if (mmTermDir == mmTrendDir)
    {
      mmTradeState           = Hold;
      mmTriggerAction        = OP_NO_ACTION;
    }
    else
    {
      if (mmTradeState == Hold)
      {
        mmTradeAlert         = false;
        mmTriggerAction      = OP_NO_ACTION;
      
        if (fractal.Fibonacci(Expansion,Retrace,Now)>FiboLevel(Fibo23))
        {
          if (mmTrendDir == DirectionUp)
            if (pfractal.Event(NewLow))
              mmTradeState   = Triggered;
            
          if (mmTrendDir == DirectionDown)
            if (pfractal.Event(NewHigh))
              mmTradeState   = Triggered;
        }
      }
      else
      
      //--- Handle trigger events
      if (mmTradeState == Triggered)
      {
        mmTriggerAction    = DirectionAction(mmTrendDir);
      
        if (mmTrendDir == DirectionUp)
          if (Close[0]>pfractal.Trendline(Head))
            mmTradeState   = Pegged;
            
        if (mmTrendDir == DirectionDown)
          if (Close[0]<pfractal.Trendline(Head))
            mmTradeState   = Pegged;
            
        if (mmTradeState == Pegged)
          if (mmTradeAlert)
          {
            mmTradeLevel   = FibonacciLevel(pfractal.Fibonacci(Term,mmTermDir,Expansion,Max));
            mmTradeState   = Execute;
          }
      }
      else
      
      //--- Handle pegged events      
      if (mmTradeState == Pegged)
      {
        if (mmTrendDir == DirectionUp)
        {
          if (Close[0]>trend.Trendline(Head))
            mmTradeState   = Hold;

          if (pfractal.Event(NewLow))
            mmTradeState   = Execute;
        }
        
        if (mmTrendDir == DirectionDown)
        {
          if (Close[0]<trend.Trendline(Head))
            mmTradeState   = Hold;

          if (pfractal.Event(NewHigh))
            mmTradeState   = Execute;
        }       
      }
      
      //--- Handle execute events
      else
      if (mmTradeState == Execute)
      {
        if (OrderFulfilled())
        {
          mmTradeState     = Fulfilled;

          if (mmTrendDir == DirectionUp)
            mmTradePivot   = pfractal.Range(Bottom);

          if (mmTrendDir == DirectionDown)
            mmTradePivot   = pfractal.Range(Top);
        }
      }
      else
      
      //--- Handle fulfillment events
      if (mmTradeState == Fulfilled)
      {
        if (mmTrendDir == DirectionUp)
        {
          if (pfractal.Event(NewHigh))
            mmTradeState   = Confirmed;
        }
        else
        if (mmTrendDir == DirectionDown)
        {
          if (pfractal.Event(NewLow))
            mmTradeState   = Confirmed;
        }
        
        if (pfractal.Fibonacci(Term,mmTermDir,Expansion,Now)>FiboLevel(mmTradeLevel))
        {
          mmTradeState     = Triggered;
          mmTradeAlert     = true;
        }
      }
      else
      
      //--- Handle confirmation events
      if (mmTradeState == Confirmed)
      {
        if (mmTrendDir == DirectionUp)
          if (pfractal.Event(NewLow))
            mmTradeState   = Triggered;

        if (mmTrendDir == DirectionDown)
          if (pfractal.Event(NewHigh))
            mmTradeState   = Triggered;
      }
    }
    
    if (mmTradeState!=smLastTradeState)
      mmTradeStateChanged  = true;
  }
  
//+------------------------------------------------------------------+
//| StrategyManager - Updates trading strategy on the tick           |
//+------------------------------------------------------------------+
void OrderManager(void)
  {
    if (mmTradeState == Execute)
    {
      if (mmTradeStateChanged)
      {
        omExecutePrice = pfractal.Trendline(Head);
        omAction       = mmTriggerAction;
      }

      if (omAction == OP_BUY)
        omExecutePrice = fmin(omExecutePrice,pfractal.Trendline(Head));

      if (omAction == OP_SELL)
        omExecutePrice = fmax(omExecutePrice,pfractal.Trendline(Head));

      OpenMITOrder(DirectionAction(mmTrendDir),omExecutePrice,0.00,mmLotSize,0.00,"Auto-MIT");
    }
  }
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    string otParams[];
    
    GetData();
    RefreshScreen();    
    GetManualRequest();

    if (AppCommand(otParams))
    {
      //--- do something
    };

    if (pfractal.Event(HistoryLoaded))
    {
      StrategyManager();
      OrderManager();
    }
    OrderMonitor();
    
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();
    
    NewPriceLabel("pipMA");

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }