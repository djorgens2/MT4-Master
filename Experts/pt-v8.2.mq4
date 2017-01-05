//+------------------------------------------------------------------+
//|                                                      pt-v8.2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.google.com"
#property version   "8.20"
#property strict

#include <Class\PipRegression.mqh>
#include <Class\Fibonacci.mqh>

#include <manual.mqh>

//--- Effective Trade Range computed from fast regr
#define ETRLevels               5
#define ETRHighMax              0
#define ETRHigh                 1
#define ETRPivot                2
#define ETRLow                  3
#define ETRLowMax               4

//--- Fibo Dir Changes
#define FiboDirTypes            4
#define FiboTimeDir             0
#define FiboTimeAmpDir          1
#define FiboRangeDir            2
#define FiboRangeAmpDir         3

input int    inpDegree          =   6;  // Degree of the polynomial regression
input int    inpMAPeriod        =   3;  // Moving average period
input int    inpSTPeriod        =  24;  // Short term range
input int    inpLTPeriod        =  48;  // Long term range
input int    inpTrendPeriod     = 240;  // Trend range
input int    inpPipPeriod       = 200;  // Pip moving average period
input int    inpFiboRange       = 120;  // Fibonacci tolerance in pips
input int    inpFiboTolerance   =  10;  // Fibonacci direction change sensitivity
input double inpTrendTolerance  = 0.5;  // Regression trend tolerance

CPipRegression   *regrPip       = new CPipRegression(inpDegree,inpPipPeriod,inpTrendTolerance);
CTrendRegression *regrFast      = new CTrendRegression(inpDegree,inpSTPeriod,inpMAPeriod);
CTrendRegression *regrSlow      = new CTrendRegression(inpDegree,inpLTPeriod,inpMAPeriod);
CTrendRegression *regrTrend     = new CTrendRegression(inpDegree,inpTrendPeriod,inpMAPeriod);

CFibonacci       *fibo          = new CFibonacci(inpFiboRange,inpFiboTolerance);

//--- Trade range operational data
double    ETR[5];
int       ETRZone;

//--- Fibo operational data
int       FiboDir[FiboDirTypes];
int       lastFiboDir[FiboDirTypes];

int       FiboActive             = FiboDirTypes;
int       FiboActiveDir          = DIR_NONE;
bool      FiboHedge;
bool      LongHold;
bool      LongProfit;
bool      ShortHold;
bool      ShortProfit;

bool      TradeStop              = true;
int       TradeAction            = OP_PEND;
int       TradeQuota             = 0;

double    TradePivot             = 0.00;
int       TradePivotDir          = DIR_NONE;
double    TradePivotLow          = 0.00;
double    TradePivotHigh         = 0.00;

double    lotsAuthorized         = 0.00;


//+------------------------------------------------------------------+
//| GetData - retrieves indicator data                               |
//+------------------------------------------------------------------+
void GetData()
  {
    regrPip.Update();
    regrSlow.Update();
    regrTrend.Update();
  }

//+------------------------------------------------------------------+
//| BestEntryPrice - analyzes the best entry price                   |
//+------------------------------------------------------------------+
double BestEntryPrice(int Action)
  {
    if (Action == OP_BUY)
      return (fmin(Close[0]+point(spread()-ordMinTarget),regrFast.PolyHead+point(spread()-ordMinTarget)));
      
    if (Action == OP_SELL)
      return (fmax(Close[0]+point(ordMinTarget),regrFast.PolyHead+point(ordMinTarget)));
      
    return (-1);
  }


//+------------------------------------------------------------------+
//| ManageRisk - takes losses when appropriate (hopefully)           |
//+------------------------------------------------------------------+
void ManageRisk()
  {
    if (Close[0]>regrTrend.TrendNow)
      if (fabs(LotValue(LOT_SHORT_LOSS,IN_EQUITY))>ordMaxRisk)
      {
        SetDCA(OP_SELL,ordMaxRisk);
        SetEquityHold(OP_BUY);
      }
      else
      if (fabs(LotValue(LOT_SHORT_LOSS,IN_EQUITY))>ordMaxRisk*2)
        SetDCA(OP_SELL,LotValue(LOT_SHORT_LOSS,IN_EQUITY)/2);
    else
    if (Close[0]<regrTrend.TrendNow)
      if (fabs(LotValue(LOT_LONG_LOSS,IN_EQUITY))>ordMaxRisk)
      {
        SetDCA(OP_BUY,ordMaxRisk);
        SetEquityHold(OP_SELL);
      }
      else
      if (fabs(LotValue(LOT_LONG_LOSS,IN_EQUITY))>ordMaxRisk*2)
        SetDCA(OP_SELL,LotValue(LOT_LONG_LOSS,IN_EQUITY)/2);
    else
      SetEquityHold(OP_NO_ACTION);
  }

//+------------------------------------------------------------------+
//| ProcessesTickData                                                |
//+------------------------------------------------------------------+
void ExecuteProfit()
  {
    if (regrSlow.MeanAmplitudeDirection == DIR_DOWN)
      if (Close[0]>regrSlow.PolyPeak && regrSlow.AmplitudeDirection == DIR_DOWN)
        CloseOrders(CLOSE_CONDITIONAL, OP_BUY);

    if (regrSlow.MeanAmplitudeDirection == DIR_UP)
      if (Close[0]<regrSlow.PolyPeak && regrSlow.AmplitudeDirection == DIR_UP)
        CloseOrders(CLOSE_CONDITIONAL, OP_SELL);
  }

//+------------------------------------------------------------------+
//| ExecutesTrades - executes orders                                 |
//+------------------------------------------------------------------+
void ExecuteTrade()
  {
    if (regrFast.FOCDevNow == 0.00)
    {
      TradeAction = DirAction(regrFast.TrendDirection,CONTRARIAN);
      TradeQuota  = 0;
    }

    
    if (regrFast.FOCDevNow>pow(2,TradeQuota))
    {
      OpenLimitOrder(TradeAction,BestEntryPrice(TradeAction),0.00,LotSize(),"Auto-Limit-Contrarian",IN_PRICE);
      TradeQuota++;
    }
  } 

//+------------------------------------------------------------------+
//| CalcConvergence - Calculates what to do when indicators converge |
//+------------------------------------------------------------------+
void CalcConvergence(double OldPivot=0.00, double Pivot=0.00)
  {
    int lastDirection = TradePivotDir;
    
    if (NormalizeDouble(OldPivot,Digits) == NormalizeDouble(Pivot,Digits))
    {
      TradePivotHigh = NormalizeDouble(fmax(Close[0],TradePivotHigh),Digits);
      TradePivotLow  = NormalizeDouble(fmin(Close[0],TradePivotLow),Digits);
    }
    else
    {
      TradePivot     = NormalizeDouble(Close[0],Digits);
      TradePivotHigh = NormalizeDouble(Close[0],Digits);
      TradePivotLow  = NormalizeDouble(Close[0],Digits);
    }

    if (Pip(TradePivotHigh-TradePivotLow)>inpFiboRange/4) //--- sampling with 1/4 total range....
      TradePivotDir  = dir(NormalizeDouble(Close[0]-TradePivot,Digits));
      
    if (TradePivotDir!=lastDirection)  //--- execute early release on failed continuation
    {
      if (NormalizeDouble(Close[0],Digits) == NormalizeDouble(TradePivotLow,Digits)||
          NormalizeDouble(Close[0],Digits) == NormalizeDouble(TradePivotHigh,Digits))
      {
        LongHold     = false;
        ShortHold    = false;
      }
    }
  } 

//+------------------------------------------------------------------+
//| ExecuteBalance - occurs when Time directions align               |
//+------------------------------------------------------------------+
void ExecuteHold(void)
  {
    // Routine is critical to preserving profit, exiting bad trades
    if (fibo.TimeDirection == DirectionUp)
    {
      ShortHold   = true;
      LongProfit  = true;
    }

    if (fibo.TimeDirection == DirectionDown)
    {
      LongHold    = true;
      ShortProfit = true;
    }
    
    CalcConvergence(TradePivot,Close[0]);
  }

//+------------------------------------------------------------------+
//| ExecuteRelease - occurs when Range direction aligns with Time    |
//+------------------------------------------------------------------+
void ExecuteRelease(void)
  {
    // Routine is critical to restart trading
    if (fibo.TimeDirection == DirectionUp)
    {
      LongHold    = false;
      LongProfit  = false;
    }

    if (fibo.TimeDirection == DirectionDown)
    {
      ShortHold   = false;
      ShortProfit = false;
    }
    
    FiboHedge     = false;
    
    CalcConvergence(TradePivot,Close[0]);
  }

//+------------------------------------------------------------------+
//| CalcFibo - calcs current fibo values                             |
//+------------------------------------------------------------------+
void CalcFibo(void)
  {
    int DirChange   = 0;
    int AggDir      = 0;
    
    //--- Retain directions from last tick
    ArrayCopy(lastFiboDir,FiboDir);

    fibo.Update();    

    FiboDir[FiboTimeDir]     = fibo.TimeDirection;
    FiboDir[FiboTimeAmpDir]  = fibo.TimeAmpDirection;
    FiboDir[FiboRangeDir]    = fibo.RangeDirection;
    FiboDir[FiboRangeAmpDir] = fibo.RangeAmpDirection;

    //---- Calc Fibo Data
    for (int idx=0; idx<FiboDirTypes; idx++)
    {
      AggDir += FiboDir[idx];
      
      if (FiboDir[idx]!=lastFiboDir[idx])
      {
        FiboActive    = idx;
        DirChange++;
      }
    }

    FiboActiveDir     = fibo.TimeDirection;
    
    if (DirChange>1)
    {
//Print ("Divergent DirChange:"+FiboActive+":"+FiboDir[FiboActive]);   
    
      //--- Analyze Divergences;
      if (dir(AggDir)!=fibo.TimeDirection)
        FiboHedge     = true;
      else
        FiboHedge     = false;
    }

    //--- Single pivot changes
    if (DirChange == 1)
    {
//Print ("DirChange:"+FiboActive+":"+FiboDir[FiboActive]);
      if (FiboDir[FiboActive]==fibo.TimeDirection)
        FiboHedge     = false;
      else
        FiboHedge     = true;
        
      if (FiboActive == FiboTimeAmpDir)
        if (FiboDir[FiboActive] == fibo.TimeDirection)
          ExecuteHold();
        else
        {
          LongProfit  = false;
          ShortProfit = false;
        }
          
      if (FiboActive == FiboRangeAmpDir)
        if (FiboDir[FiboActive] == fibo.TimeDirection)
          ExecuteRelease();
    }
    
    if (FiboHedge)
      FiboActiveDir *= DirectionInverse;
  }
  
//+------------------------------------------------------------------+
//| CalcFastRegr - analyzes fast regression data                     |
//+------------------------------------------------------------------+
void CalcFastRegr(void)
  {
    regrFast.Update();
  
    //--- compute ETR boundaries
    ETR[ETRHighMax] = NormalizeDouble(regrFast.PolyPeak+(regrFast.MeanAmplitude*2),Digits);
    ETR[ETRHigh]    = NormalizeDouble(regrFast.PolyPeak+regrFast.MeanAmplitude,Digits);
    ETR[ETRPivot]   = NormalizeDouble(regrFast.PolyPeak,Digits);
    ETR[ETRLow]     = NormalizeDouble(regrFast.PolyPeak-regrFast.MeanAmplitude,Digits);
    ETR[ETRLowMax]  = NormalizeDouble(regrFast.PolyPeak-(regrFast.MeanAmplitude*2),Digits);
    
    ETRZone         = 0;

    while (NormalizeDouble(Close[0],Digits)<NormalizeDouble(ETR[ETRZone++],Digits))
      if (ETRZone == ETRLevels)
        break;
  }

//+------------------------------------------------------------------+
//| AnalyzeTrend                                                     |
//+------------------------------------------------------------------+
void AnalyzeTrend(void)
  {
    CalcFastRegr();
    CalcFibo();
    CalcConvergence();
    
  } 
 
//+------------------------------------------------------------------+
//| ProcessesTickData                                                |
//+------------------------------------------------------------------+
void ProcessTick(void)
  {
    AnalyzeTrend();
    
    if (TradeAction == OP_HALT)
    {
      Comment("Trade Halted");
    }
    else
    {
      if (TradeAction == OP_PEND)
      {
        //--- wait for trade conditions to start
        if (regrPip.TickLoaded)
          if (regrPip.NewHigh||regrPip.NewLow)
            TradeAction = OP_NO_ACTION;
      }
      else
      {
        ExecuteTrade();
        ExecuteProfit();
        ManageRisk();
      }
    }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();

    manualProcessRequest();
    SetTradeParams();
    orderMonitor();

    if (manualAuto)
      ProcessTick();
      
    RefreshScreen();
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
    string report = "";
    string fiboReport = "";
    
    if (TradeAction == OP_PEND)
    {
      report += "Trade Not Authorized; Authorization Pending\n";
    }
    else
    if (orderPending())
    {
      if (orderPending(OP_BUYLIMIT))
        report += "Pending order buy limit\n";
      if (orderPending(OP_BUYSTOP))
        report += "Pending order buy stop\n";
      if (orderPending(OP_SELLLIMIT))
        report += "Pending order sell limit\n";
      if (orderPending(OP_SELLSTOP))
        report += "Pending order sell stop\n";
    }   
    else
    if (TradeQuota>0)
      if (TradeAction == OP_NO_ACTION)
        report += "Analyzing data for "+Direction(FiboActiveDir)+" entry\n";
      else
        report += "Trade Authorized: "+ActionText(TradeAction)+" Size: "+DoubleToStr(LotSize(),2)+"\n";
    else
      report   += "Analyzing trade data ("+Direction(FiboActiveDir)+")\n";
      
    report     += "Strategy ("+Direction(FiboDir[FiboActive]);
    if (FiboHedge)   report += ", Hedge";
    if (LongHold)    report += ", Hold Long";
    if (ShortHold)   report += ", Hold Short";
    if (LongProfit)  report += ", Long Profit";
    if (ShortProfit) report += ", Short Profit";
    report   += ")\n";
    
    report     += "Time:  ("+proper(DirText(fibo.TimeDirection))+","+proper(DirText(fibo.TimeAmpDirection))+") ("+
                   DoubleToStr(fibo.TimeRetrace,1) +"% "+DoubleToStr(fibo.TimeRetraceMax,1)+")";

    if (fibo.TimeAlert)
      fiboReport +=" Alert";

    if (fibo.Time50)
      fiboReport +=" 50%";

    if (fibo.TimeNewTop)
      fiboReport +=" Top";
      
    if (fibo.TimeNewBottom)
      fiboReport +=" Bottom";
      
    if (fiboReport!="")
      report += " ("+StringTrimLeft(fiboReport)+")\n";
    else report += "\n";

    report += "Range: ("+proper(DirText(fibo.RangeDirection))+","+proper(DirText(fibo.RangeAmpDirection))+ ") ("+
              DoubleToStr(fibo.RangeRetrace,1)+"% "+DoubleToStr(fibo.RangeRetraceMax,1)+"%) Range("+DoubleToStr(Pip(fibo.RangeSize),1)+")\n";
    
    report += "FOC: Fast"+regrFast.FOCData()+" Slow"+regrSlow.FOCData()+" Trend"+regrTrend.FOCData()+"\n";
    report += "Pip: "+regrPip.PipData()+" State ("+regrPip.State()+")";

    if (regrPip.TickLoaded)
    {
      if (regrPip.NewHigh) report+= " New High";
      if (regrPip.NewLow)  report+= " New Low";
    }
    report += "\n";
//    report += fibo.FiboPrint();

    ObjectSet("ActivePivot",OBJPROP_TIME1,Time[0]);
    ObjectSet("ActivePivot",OBJPROP_PRICE1,TradePivot);
    ObjectSet("ActivePivot",OBJPROP_COLOR,DirColor(TradePivotDir));

    UpdateLine("TimeHigh",fibo.TimePriceHigh,STYLE_SOLID,clrMaroon);
    UpdateLine("TimeLow",fibo.TimePriceLow,STYLE_SOLID,clrMaroon);
    UpdateLine("TimeRetrace",fibo.TimeRetracePrice,STYLE_DOT,clrMaroon);
    UpdateLine("TimePivot",fibo.TimePivotPrice,STYLE_SOLID,DirColor(fibo.TimeAmpDirection,clrYellow));
      
    UpdateLine("RangeHigh",fibo.RangePriceHigh,STYLE_SOLID,clrSteelBlue);
    UpdateLine("RangeLow",fibo.RangePriceLow,STYLE_SOLID,clrSteelBlue);
    UpdateLine("RangeRetrace",fibo.RangeRetracePrice,STYLE_DOT,clrSteelBlue);
    UpdateLine("RangePivot",fibo.RangePivotPrice,STYLE_SOLID,DirColor(fibo.RangeAmpDirection,clrYellow));

    Comment(report);
  } 
  
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();

    SetTradeParams();

    NewLine("TimeHigh");
    NewLine("TimeLow");
    NewLine("TimeRetrace");
    NewLine("TimePivot");

    NewLine("RangeHigh");
    NewLine("RangeLow");
    NewLine("RangeRetrace");
    NewLine("RangePivot");
    
    ArrayInitialize(FiboDir,DIR_NONE);
    
    ObjectCreate("ActivePivot",OBJ_ARROW,0,0,0);
    ObjectSet("ActivePivot", OBJPROP_ARROWCODE, SYMBOL_RIGHTPRICE);    

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| SetTradeParams - sets up the autotrader                          |
//+------------------------------------------------------------------+
void SetTradeParams()
  {
    if (manualAuto && tradeModeChange)
    {
      //---- Set risk and targets
      SetEquityTarget(ordMinTarget*2,0.1);
      SetRisk(ordMaxRisk*2,ordLotRisk);
    
      //--- Set trade options
      SetProfitPolicy(eqdir);
      SetProfitPolicy(eqhalf);
      SetProfitPolicy(eqprofit);
    }
  }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete regrPip;
    delete regrFast;
    delete regrSlow;
    delete regrTrend;
    delete fibo;
  }