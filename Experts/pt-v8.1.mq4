//+------------------------------------------------------------------+
//|                                                      pt-v8.1.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "8.10"
#property strict

#include <Class\TrendRegression.mqh>
#include <Class\Fibonacci.mqh>

#include <manual.mqh>

input int inpDegree          =   6;  // Degree of the polynomial regression
input int inpMAPeriod        =   3;  // Moving average period
input int inpSTPeriod        =  24;  // Short term range
input int inpLTPeriod        =  48;  // Long term range
input int inpTrendPeriod     = 240;  // Trend range
input int inpFiboTolerance   = 120;  // Fibonacci tolerance in pips

CTrendRegression *regrFast   = new CTrendRegression(inpDegree,inpSTPeriod,inpMAPeriod);
CTrendRegression *regrSlow   = new CTrendRegression(inpDegree,inpLTPeriod,inpMAPeriod);
CTrendRegression *regrTrend  = new CTrendRegression(inpDegree,inpTrendPeriod,inpMAPeriod);
CFibonacci       *fibo       = new CFibonacci(inpFiboTolerance);

double    stTrend[];
double    stPoly[];

double    ltTrend[];
double    ltPoly[];

int       tradeAction            = OP_NO_ACTION;
int       tradeQuota             = 0;

double    lotsAuthorized         = 0.00;
double    reserveQuota           = 0.00;
double    reservePrice           = 0.00;

bool      vertexBasedLimitOrder  = false;


//+------------------------------------------------------------------+
//| GetData - retrieves indicator data                               |
//+------------------------------------------------------------------+
void GetData()
  {
    regrFast.Update(stPoly,stTrend);
    regrSlow.Update(ltPoly,ltTrend);
    regrTrend.Update(ltPoly,ltTrend);
    fibo.Update();
  }

//+------------------------------------------------------------------+
//| BestEntryPrice - analyzes the best entry price                   |
//+------------------------------------------------------------------+
double BestEntryPrice(int Action)
  {
    if (Action == OP_BUY)
      return (fmin(Close[0]+point(spread()-ordMinTarget),regrFast.Head+point(spread()-ordMinTarget)));
      
    if (Action == OP_SELL)
      return (fmax(Close[0]+point(ordMinTarget),regrFast.Head+point(ordMinTarget)));
      
    return (-1);
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
    string report = "";
    
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
    if (tradeQuota>0)
      report += "Trade Authorized: "+ActionText(tradeAction)+" Size: "+DoubleToStr(LotSize(),2)+"\n";  
    else
      report += "Trade Not Authorized: Calculating "+proper(ActionText(tradeAction,IN_DIRECTION))+" @FOCDev:"+DoubleToStr(pow(2,tradeQuota),0)+"\n";
        
//    report+="Vertex: "+DoubleToStr(regrFast.Vertex,Digits)+" Position: "+DoubleToStr(regrFast.AmplitudePosition,1)+"% Range: "+DoubleToStr(pip(regrFast.VertexRange*regrFast.VertexDevDirection),1)+
//             " High: "+DoubleToStr(regrFast.VertexHigh,Digits)+" Low: "+DoubleToStr(regrFast.VertexLow,Digits)+"\n"; 
    report+="Fast:  " + regrFast.FOCData()+"  Direction: "+proper(DirText(regrFast.TrendDirection))+"\n";
    report+="Trend: " + regrTrend.FOCData()+"  Direction: "+proper(DirText(regrTrend.TrendDirection))+"\n";

//    report+="Poly Top: "+DoubleToStr(regrFast.Top,Digits)+" Bottom: "+DoubleToStr(regrFast.Bottom,Digits)+"\n";
    report+="Time:  Direction: "+proper(DirText(fibo.TimeDirection))  + " Retrace: "+DoubleToStr(fibo.TimeRetrace,1)+"% Retrace: "+DoubleToStr(fibo.TimeRetraceMax,1)+"%\n";
    report+="Range: Direction: "+proper(DirText(fibo.RangeDirection)) + " Retrace: "+DoubleToStr(fibo.RangeRetrace,1)+"% Retrace: "+DoubleToStr(fibo.RangeRetraceMax,1)+"%\n";
//    report+="Fibo: High: "+DoubleToStr(fibo.TimePriceHigh,Digits)+" Low: "+DoubleToStr(fibo.TimePriceLow,Digits)+" Retrace Price: "+DoubleToStr(fibo.TimeRetracePrice,Digits)+"\n";
//    report+=fibo.FiboData()+"\n";

    if (fibo.Time50)
      report+="50%: Yes";
    else
      report+="50%: No";

    if (fibo.TimeNewTop)
      report+=" Top: Yes";
      
    if (fibo.TimeNewBottom)
      report+=" Bottom: Yes";
      
    if (fibo.TimeAlert)
      report+=" Alert: Yes\n";
    
    UpdateLine("PriceHigh",fibo.TimePriceHigh,STYLE_SOLID,clrForestGreen);
    UpdateLine("PriceLow",fibo.TimePriceLow,STYLE_SOLID,clrCrimson);
    UpdateLine("Retrace",fibo.TimeRetracePrice,STYLE_DOT,clrDarkGray);
      
    UpdateLine("RangeHigh",fibo.RangePriceHigh,STYLE_SOLID,clrSteelBlue);
    UpdateLine("RangeLow",fibo.RangePriceLow,STYLE_SOLID,clrSteelBlue);
    UpdateLine("RangeRetrace",fibo.RangeRetracePrice,STYLE_DOT,clrYellow);

    Comment(report);
  } 

//+------------------------------------------------------------------+
//| ProcessesTickData                                                |
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
      if (Close[0]>regrSlow.Peak && regrSlow.AmplitudeDirection == DIR_DOWN)
        CloseOrders(CLOSE_CONDITIONAL, OP_BUY);

    if (regrSlow.MeanAmplitudeDirection == DIR_UP)
      if (Close[0]<regrSlow.Peak && regrSlow.AmplitudeDirection == DIR_UP)
        CloseOrders(CLOSE_CONDITIONAL, OP_SELL);
  }

//+------------------------------------------------------------------+
//| ProcessesTickData                                                |`
//+------------------------------------------------------------------+
void ExecuteTrade()
  {
    if (regrFast.FOCDevNow == 0.00)
    {
      tradeAction = DirAction(regrFast.TrendDirection,CONTRARIAN);
      tradeQuota  = 0;
    }

    
    if (regrFast.FOCDevNow>pow(2,tradeQuota))
    {
      OpenLimitOrder(tradeAction,BestEntryPrice(tradeAction),0.00,LotSize(),"Auto-Limit-Contrarian",IN_PRICE);
      tradeQuota++;
    }
  } 


//+------------------------------------------------------------------+
//| ProcessesTickData                                                |
//+------------------------------------------------------------------+
void ProcessTick()
  {
    ExecuteTrade();
    ExecuteProfit();
    ManageRisk();
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
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();

    SetTradeParams();

    ArrayResize(stPoly,inpSTPeriod);
    ArrayResize(stTrend,inpSTPeriod);
    
    ArrayResize(ltPoly,inpLTPeriod);
    ArrayResize(ltTrend,inpLTPeriod);

    NewLine("PriceHigh");
    NewLine("PriceLow");
    NewLine("Retrace");

    NewLine("RangeHigh");
    NewLine("RangeLow");
    NewLine("RangeRetrace");

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete regrFast;
    delete regrSlow;
    delete regrTrend;
    delete fibo;
  }