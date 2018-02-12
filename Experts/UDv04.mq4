//+------------------------------------------------------------------+
//|                                                        UDv04.mq4 |
//|                                 Copyright 2017, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <Class\PipFractal.mqh>

input string EAHeader                = "";    //+---- Application Options -------+
input int    inpMaxVolume            = 30;    // Maximum volume
input double inpDailyTarget          = 3.6;   // Daily target

input string fractalHeader           = "";    //+------ Fractal Options ---------+
input int    inpRangeMin             = 60;    // Minimum fractal pip range
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpPeriodsLT            = 240;   // Long term regression periods

input string RegressionHeader        = "";    //+------ Regression Options ------+
input int    inpDegree               = 6;     // Degree of poly regression
input int    inpSmoothFactor         = 3;     // MA Smoothing factor
input double inpTolerance            = 0.5;   // Directional sensitivity
input int    inpPipPeriods           = 200;   // Trade analysis periods (PipMA)
input int    inpRegrPeriods          = 24;    // Trend analysis periods (RegrMA)

//--- Class defs
  CFractal           *fractal        = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal       = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);
  CTrendRegression   *tregr          = new CTrendRegression(inpDegree,inpRegrPeriods,inpSmoothFactor);


//--- Operational Const
  enum TradeState
       {
         tsPivot,
         tsEntry,
         tsExit,
         tsHold,
         tsPend,
         tsRisk,
         tsCover,
         TradStates
       };

//--- Operational Vars
  int        opTradeDir              = DirectionNone;
  int        opTradeAction           = OP_NO_ACTION;
  int        opRiskDir               = DirectionNone;
  int        opRiskAction            = OP_NO_ACTION;
  int        opEventDir              = DirectionNone;
  int        opEventAction           = OP_NO_ACTION;
  int        opPriceDir              = DirectionNone;
  
  
  TradeState opLastEvent             = tsHold;
  
  double     opLevel[2][TradStates];
  TradeState opStrategy[2]           = {tsHold,tsHold};
  int        opMajorAge              = NoValue;
  
//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    static int rsArrowId    = 0;
    int        rsArrowCode;
    string     rsComment    = "";
  
    if (pfractal.Event(NewAggregate))
    {
      switch (opLastEvent)
      {
        case tsPivot:  rsArrowCode = BoolToInt(opTradeDir==DirectionUp,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN);
                       break;
        case tsPend:   rsArrowCode = SYMBOL_CHECKSIGN;
                       break;
        case tsExit:   rsArrowCode = SYMBOL_STOPSIGN;
                       break;
        default:       rsArrowCode = SYMBOL_DASH;
      }
      
      NewArrow(rsArrowCode,DirColor(opEventDir),"Event:"+IntegerToString(rsArrowId++));      
    }
    
    rsComment    = "Trade Direction: "+proper(DirText(opTradeDir))+"\n";
    rsComment   += BoolToStr(opRiskAction==OP_NO_ACTION,"","Risk Direction: "+proper(DirText(opRiskDir))+"\n");
    rsComment   += "Last Event ("+IntegerToString(rsArrowId)+") "+proper(DirText(opEventDir))
                  +" "+StringSubstr(EnumToString(opLastEvent),2)
                  +" @"+DoubleToStr(opLevel[opEventAction][opLastEvent],Digits)+"\n";
    rsComment   += "Strategy:  (L):"+StringSubstr(EnumToString(opStrategy[OP_BUY]),2)
                                    +BoolToStr(AtRisk(OP_BUY)," @Risk")+"\n"
                  +"               (S):"+StringSubstr(EnumToString(opStrategy[OP_SELL]),2)
                                        +BoolToStr(AtRisk(OP_SELL)," @Risk")+"\n";
      
    Comment(rsComment);

    UpdateLine("pfRangeHigh",pfractal.Range(Top),STYLE_SOLID,DirColor(pfractal.Direction(RangeHigh)));
    UpdateLine("pfRangeLow",pfractal.Range(Bottom),STYLE_SOLID,DirColor(pfractal.Direction(RangeLow)));
    UpdateLine("pfRangeMid",pfractal.Range(Mid),STYLE_DOT,DirColor(pfractal.Direction(Range)));
    
    UpdateRay("tMajorTrend",tregr.Trendline(Tail),opMajorAge,tregr.Trendline(Head),0);

    if (opStrategy[OP_BUY]==tsPend||opStrategy[OP_BUY]==tsEntry)
      UpdatePriceLabel("tLongPend",opLevel[OP_BUY][tsPend],DirColor(DirectionUp));
    else
      UpdatePriceLabel("tLongPend",opLevel[OP_BUY][tsPend],clrLightGray);

    if (opStrategy[OP_SELL]==tsPend||opStrategy[OP_SELL]==tsEntry)
      UpdatePriceLabel("tShortPend",opLevel[OP_SELL][tsPend],DirColor(DirectionDown));
    else
      UpdatePriceLabel("tShortPend",opLevel[OP_SELL][tsPend],clrLightGray);
  }
  
//+------------------------------------------------------------------+
//| AtRisk - Returns true on pend(entry) less than the action pivot  |
//+------------------------------------------------------------------+
bool AtRisk(int Action=OP_NO_ACTION)
  {
    if (Action==OP_BUY||Action==OP_SELL)
      return (opLevel[Action][tsPend]==opLevel[Action][tsRisk]);
      
    return (false);
  }


//+------------------------------------------------------------------+
//| CalcStrategy                                                     |
//+------------------------------------------------------------------+
void CalcStrategy(void)
  {
    if (pfractal.Event(NewAggregate))
    {
      opEventDir      = pfractal.Direction(Range);
      opEventAction   = DirAction(opEventDir);
      
      if (pfractal.Direction(RangeHigh)==pfractal.Direction(RangeLow))
      {
        if (IsChanged(opPriceDir,opEventDir))
        {
          switch (opPriceDir)
          {
            case DirectionUp:   opStrategy[OP_BUY]        = tsHold;
                                opStrategy[OP_SELL]       = tsCover;
                                break;
            case DirectionDown: opStrategy[OP_BUY]        = tsHold;
                                opStrategy[OP_SELL]       = tsCover;
                                break;
          }
          
          opLevel[OP_BUY][opStrategy[OP_BUY]]   = Close[0];
          opLevel[OP_SELL][opStrategy[OP_SELL]] = Close[0];
        }
        
        if (pfractal.Event(NewBoundary))
        {
          opTradeDir  = opEventDir;
          opRiskDir   = DirAction(opTradeDir,InContrarian);
          opLastEvent = tsPivot;
          
          opLevel[opRiskDir][tsRisk] = Close[0];
        }
        else
        {
          opLastEvent                     = tsPend;
          opStrategy[opEventAction]       = tsPend;
        }
      }
      else
      {
        opLastEvent                       = tsExit;
        opStrategy[opEventAction]         = tsExit;
      }
      
      opLevel[opEventAction][opLastEvent] = Close[0];
    }
  
    if (opStrategy[OP_BUY]==tsPend)
      if (IsLower(Close[0],opLevel[OP_BUY][tsPend]))
        opStrategy[OP_BUY]=tsEntry;
        
    if (opStrategy[OP_BUY]==tsEntry)
      if (IsLower(Close[0],opLevel[OP_BUY][tsPend]))
        SetOpen(OP_BUY);
        
    if (IsLower(Close[0],opLevel[OP_BUY][tsRisk]))
      SetRisk(OP_BUY);
                
    if (opStrategy[OP_SELL]==tsPend)
      if (IsHigher(Close[0],opLevel[OP_SELL][tsPend]))
        opStrategy[OP_SELL]=tsEntry;

    if (opStrategy[OP_SELL]==tsEntry)
      if (IsHigher(Close[0],opLevel[OP_SELL][tsPend]))
        SetOpen(OP_SELL);

    if (IsHigher(Close[0],opLevel[OP_SELL][tsRisk]))
      SetRisk(OP_SELL);
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    //--- Update indicators
    fractal.Update();
    pfractal.Update();
    tregr.Update();
    
    //--- Recalc regrMA
    if (IsChanged(opMajorAge,fractal[fractal.Previous(fractal.State(Major))].Bar))
    {
      delete tregr;
      tregr = new CTrendRegression(inpDegree,opMajorAge,inpSmoothFactor);
    }
    
    CalcStrategy();
  }
  
//+------------------------------------------------------------------+
//| ExecTradeOpen - Manages opening trade restrictions               |
//+------------------------------------------------------------------+
bool ExecTradeOpen(int Action)
  {
   // Pause("Order","ExecTradeOpen()");
    return (OpenOrder(Action,"Trade Manager "+ActionText(Action)));
  }


//+------------------------------------------------------------------+
//| ManageRisk                                                       |
//+------------------------------------------------------------------+
void ManageRisk()
  {
    
  }
  
//+------------------------------------------------------------------+
//| ManageExit                                                       |
//+------------------------------------------------------------------+
void ManageExit()
  {
    
  }
  
//+------------------------------------------------------------------+
//| ManageOpen                                                       |
//+------------------------------------------------------------------+
void ManageOpen()
  { 
    int moMarketDir  = pfractal.Direction(Tick);
       
    switch (opTradeAction)
    {
      case OP_BUY:     if (moMarketDir==DirectionUp)
                         if (pfractal.Poly(Deviation)>0.00)
                           if (ExecTradeOpen(OP_BUY))
                             opTradeAction  = OP_NO_ACTION;
                       break;
      
      case OP_SELL:    if (moMarketDir==DirectionDown)
                         if (pfractal.Poly(Deviation)<0.00)
                           if (ExecTradeOpen(OP_SELL))
                             opTradeAction  = OP_NO_ACTION;
                       break;
    }
  }
  
//+------------------------------------------------------------------+
//| SetRisk                                                          |
//+------------------------------------------------------------------+
void SetRisk(int Action)
  {
    opRiskAction   = Action;
  }
  
//+------------------------------------------------------------------+
//| SetExit                                                          |
//+------------------------------------------------------------------+
void SetExit(int Action)
  {
    
  }
  
//+------------------------------------------------------------------+
//| SetOpen                                                          |
//+------------------------------------------------------------------+
void SetOpen(int Action)
  {
    opTradeAction  = Action;
  }
  
//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    ManageRisk();
    ManageExit();
    ManageOpen();
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
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
    
    ArrayInitialize(opLevel,Close[0]);
    
    NewLine("pfRangeHigh");
    NewLine("pfRangeLow");
    NewLine("pfRangeMid");
   
    NewRay("tMajorTrend",false);
   
    NewPriceLabel("tLongPend");
    NewPriceLabel("tShortPend");
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete pfractal;
    delete tregr;
  }