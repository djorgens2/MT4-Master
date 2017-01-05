//+------------------------------------------------------------------+
//|                                                        pt-v8.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\TrendRegression.mqh>
#include <manual.mqh>

input int inpDegree      =   6;  // Degree of the polynomial regression
input int inpMAPeriod    =   3;  // Moving average period
input int inpSTPeriod    =  24;  // Short term range
input int inpLTPeriod    =  48;  // Long term range
input int inpTrendPeriod = 240;  // Trend range

CTrendRegression *regrFast  = new CTrendRegression(inpDegree,inpSTPeriod,inpMAPeriod);
CTrendRegression *regrSlow  = new CTrendRegression(inpDegree,inpLTPeriod,inpMAPeriod);
CTrendRegression *regrTrend = new CTrendRegression(inpDegree,inpTrendPeriod,inpMAPeriod);


double    stTrend[];
double    stPoly[];

double    ltTrend[];
double    ltPoly[];

int       tradeAction            = OP_NO_ACTION;
double    tradeQuota             = 0.00;
double    lotsAuthorized         = 0.00;
bool      vertexBasedLimitOrder  = false;


//+------------------------------------------------------------------+
//| GetData - retrieves indicator data                               |
//+------------------------------------------------------------------+
void GetData()
  {
    regrFast.Update(stPoly,stTrend);
    regrSlow.Update(ltPoly,ltTrend);
    regrTrend.Update(ltPoly,ltTrend);
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
    if (lotsAuthorized>0)
      report += "Trade Authorized: "+ActionText(tradeAction)+" Size: "+DoubleToStr(lotsAuthorized,2)+"\n";  
    else
      report += "Trade Not Authorized\n";
        
    report+="Vertex: "+DoubleToStr(regrFast.Vertex,Digits)+" Position: "+DoubleToStr(regrFast.AmplitudePosition,1)+"% Range: "+DoubleToStr(pip(regrFast.VertexRange*regrFast.VertexDevDirection),1)+
             " High: "+DoubleToStr(regrFast.VertexHigh,Digits)+" Low: "+DoubleToStr(regrFast.VertexLow,Digits)+"\n"; 
    report+=regrFast.FOCData()+"  Direction: "+proper(DirText(regrFast.TrendDirection))+"\n";
    report+=regrFast.FOCHistoryData()+"\n";
    report+="Poly Top: "+DoubleToStr(regrFast.Top,Digits)+" Bottom: "+DoubleToStr(regrFast.Bottom,Digits)+"\n";
    report+="Fibo: "+DoubleToStr(regrFast.FibonacciLevels[regrFast.FibonacciLevel],1)+"  Direction: "+proper(DirText(regrFast.FibonacciDirection))+" Retrace: "+DoubleToStr(regrFast.PriceRetrace,1)+"%\n"; 
      
    Comment(report);
  } 

//+------------------------------------------------------------------+
//| ProcessesTickData                                                |
//+------------------------------------------------------------------+
void ManageRisk()
  {
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
    if (regrFast.NewVertex)
    {
      ClosePendingOrders();
      
      lotsAuthorized  = 0.00;
      tradeQuota      = 0;
      
      if (regrFast.HeadAmplitudeDirection == DIR_UP)
        tradeAction = OP_BUY;
        
      if (regrFast.HeadAmplitudeDirection == DIR_DOWN)
        tradeAction = OP_SELL;
    }
    
    if (pip(regrFast.VertexRange)>pow(2,tradeQuota))
    {
      lotsAuthorized += LotSize();
      tradeQuota++;
    }
    
     //--- Contrarian trades - trend insurance and retention
    if (lotsAuthorized>0.00)
    {
      if (regrFast.Vertex>regrFast.TrendNow)
        if (tradeAction == OP_BUY)
          if (regrFast.TrendDirection == DIR_DOWN)
            OpenLimitOrder(tradeAction,regrFast.Vertex-point(spread()),0.00,lotsAuthorized,"Auto-Limit-Contrarian",IN_PRICE);

      if (regrFast.Vertex<regrFast.TrendNow)
        if (tradeAction == OP_SELL)
          if (regrFast.TrendDirection == DIR_UP)
            OpenLimitOrder(tradeAction,regrFast.Vertex,0.00,lotsAuthorized,"Auto-Limit-Contrarian",IN_PRICE);

      if (orderPending())
      {
        lotsAuthorized        = 0.00;
        vertexBasedLimitOrder = true;
      }
    }

    if (vertexBasedLimitOrder)
    {
      if (orderPending(OP_BUYLIMIT))
        ordLimitPrice = (regrFast.Vertex+regrFast.VertexRange)-point(spread());
      else
      if (orderPending(OP_SELLLIMIT))
        ordLimitPrice = regrFast.Vertex-regrFast.VertexRange;
      else
        vertexBasedLimitOrder = false;
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

    RefreshScreen();
          
    if (manualAuto)
      ProcessTick();
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

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete regrFast;
    delete regrSlow;
  }