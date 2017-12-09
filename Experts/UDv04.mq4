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
         TradStates
       };

//--- Operational Vars
  int        opTradeDir              = DirectionNone;
  int        opEventDir              = DirectionNone;
  int        opEventAction           = OP_NO_ACTION;
  
  
  TradeState opLastEvent             = tsHold;
  
  double     opLevel[2][TradStates];
  TradeState opStrategy[2]           = {tsHold,tsHold};
  int        opMajorAge              = NoValue;

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    fractal.Update();
    pfractal.Update();
    tregr.Update();
    
    if (IsChanged(opMajorAge,fractal[fractal.Previous(fractal.State(Major))].Bar))
    {
      delete tregr;
      tregr = new CTrendRegression(inpDegree,opMajorAge,inpSmoothFactor);
    }
    
    CalcStrategy();
  }

//+------------------------------------------------------------------+
//| ManageRisk                                                       |
//+------------------------------------------------------------------+
void ManageRisk(int Action)
  {
    opLevel[Action][tsRisk]   = Close[0];
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
        if (pfractal.Event(NewBoundary))
        {
          opTradeDir  = opEventDir;
          opLastEvent = tsPivot;
        }
        else
        {
          opLastEvent                     = tsPend;
          opStrategy[opEventAction]       = tsPend;
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
        ManageRisk(OP_BUY);
        
    if (opStrategy[OP_SELL]==tsPend)
      if (IsHigher(Close[0],opLevel[OP_SELL][tsPend]))
        opStrategy[OP_SELL]=tsEntry;

    if (opStrategy[OP_SELL]==tsEntry)
      if (IsHigher(Close[0],opLevel[OP_SELL][tsPend]))
        ManageRisk(OP_SELL);
  }

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
    rsComment   += "Last Event ("+IntegerToString(rsArrowId)+") "+proper(DirText(opEventDir))
                  +" "+StringSubstr(EnumToString(opLastEvent),2)
                  +" @"+DoubleToStr(opLevel[opEventAction][opLastEvent],Digits)+"\n";
    rsComment   += "Strategy:  Long:"+StringSubstr(EnumToString(opStrategy[OP_BUY]),2)
                  +" Short:"+StringSubstr(EnumToString(opStrategy[OP_SELL]),2);
      
    Comment(rsComment);

    UpdateLine("pfRangeHigh",pfractal.Range(Top),STYLE_SOLID,DirColor(pfractal.Direction(RangeHigh)));
    UpdateLine("pfRangeLow",pfractal.Range(Bottom),STYLE_SOLID,DirColor(pfractal.Direction(RangeLow)));
    UpdateLine("pfRangeMid",pfractal.Range(Mid),STYLE_DOT,DirColor(pfractal.Direction(Range)));
    
    UpdateRay("tMajorTrend",tregr.Trendline(Tail),opMajorAge,tregr.Trendline(Head),0);

    if (opStrategy[OP_BUY]==tsPend||opStrategy[OP_BUY]==tsEntry)
      UpdatePriceLabel("tLongPend",opLevel[OP_BUY][tsPend],DirColor(DirectionUp));

    if (opStrategy[OP_SELL]==tsPend||opStrategy[OP_SELL]==tsEntry)
      UpdatePriceLabel("tShortPend",opLevel[OP_SELL][tsPend],DirColor(DirectionDown));
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
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
    
    ArrayInitialize(opLevel,0.00);
    
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