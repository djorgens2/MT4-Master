//+------------------------------------------------------------------+
//|                                                        pm-v1.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property strict

input  double inpPMProfitFactor = 0.65;  // Profit Factor

#define PM_PROFIT_MEASURES    8
#define PM_OPEN_HIGH          0
#define PM_OPEN_LOW           1
#define PM_OPEN_MIN           2
#define PM_OPEN_LOTS          3
#define PM_EQ_TARGET_MAX      4
#define PM_EQ_TARGET_MIN      5
#define PM_CLOSE_LOTS         6
#define PM_CLOSE_PRICE        7

//--- Profit Manager
double pmStop         = 0.00;
int    pmAction       = OP_NO_ACTION;
int    pmNewOrder     = OP_NO_ACTION;
int    pmForceAction  = OP_NO_ACTION;
double pmForceEquity  = 0.00;

double pmProfit[2][PM_PROFIT_MEASURES];
double pmProfitLast[2][PM_PROFIT_MEASURES];
int    pmPrecision[PM_PROFIT_MEASURES] = {1,1,1,2,1,1,2,0};


//+------------------------------------------------------------------+
//| pmGetProfitData() - accumulates data needed to take profit       |
//+------------------------------------------------------------------+
string ProfitManagerReport()
  {
    string strLReport = "";
    string strSReport = "";
    string strDelim   = "";
    
    for (int idx=0; idx<PM_PROFIT_MEASURES; idx++)
    {
      switch (idx)
      {
         case 0:
         case 1:
         case 2: strDelim = "%:";
                 break;
         case 3: strDelim = ":";
                 break;
         case 4:
         case 5: strDelim = "%:";
                 break;
         case 6: strDelim = ":";
                 break;
                 
         default: strDelim = ":";
      }

      if (LotCount(LOT_LONG_NET)>0.00)
        strLReport += DoubleToStr(pmProfit[OP_BUY][idx],pmPrecision[idx])+strDelim;

      if (LotCount(LOT_SHORT_NET)>0.00)
        strSReport += DoubleToStr(pmProfit[OP_SELL][idx],pmPrecision[idx])+strDelim;
    }

    if (LotCount(LOT_LONG_NET)>0.00)
      strLReport = "PM: Long: ("+strLReport+")\n";

    if (LotCount(LOT_SHORT_NET)>0.00)
      strSReport = "PM: Short: ("+strSReport+")\n";
      
    return (strLReport+strSReport);
  }
  
//+------------------------------------------------------------------+
//| pmGetProfitData() - accumulates data needed to take profit       |
//+------------------------------------------------------------------+
void pmGetProfitData()
  {
    ArrayCopy(pmProfitLast,pmProfit);
    
    pmNewOrder    = OP_NO_ACTION;
    pmForceAction = OP_NO_ACTION;
    
    pmProfit[OP_BUY][PM_OPEN_HIGH]   = fmax(pmProfit[OP_BUY][PM_OPEN_HIGH],LotValue(LOT_LONG_PROFIT,IN_EQUITY));
    pmProfit[OP_BUY][PM_OPEN_LOW]    = fmin(pmProfit[OP_BUY][PM_OPEN_LOW],LotValue(LOT_LONG_PROFIT,IN_EQUITY));
    pmProfit[OP_BUY][PM_OPEN_MIN]    = fmin(pmProfit[OP_BUY][PM_OPEN_MIN],LotValue(LOT_LONG_LOSS,IN_EQUITY));
    pmProfit[OP_BUY][PM_OPEN_LOTS]   = LotCount(LOT_LONG_NET);
        
    if (pmProfit[OP_BUY][PM_OPEN_HIGH] == LotValue(LOT_LONG_PROFIT,IN_EQUITY))
      pmProfit[OP_BUY][PM_OPEN_LOW]  = LotValue(LOT_LONG_PROFIT,IN_EQUITY);
      
    if (pmProfit[OP_BUY][PM_OPEN_LOTS]<pmProfitLast[OP_BUY][PM_OPEN_LOTS])
    {
      pmProfit[OP_BUY][PM_CLOSE_LOTS]    = pmProfitLast[OP_BUY][PM_OPEN_LOTS]-pmProfit[OP_BUY][PM_OPEN_LOTS];
      pmProfit[OP_BUY][PM_CLOSE_PRICE]   = ordLastBid;
    }

    if (pmProfit[OP_BUY][PM_OPEN_LOTS]>pmProfitLast[OP_BUY][PM_OPEN_LOTS])
      pmNewOrder  = OP_BUY;

    pmProfit[OP_SELL][PM_OPEN_HIGH]  = fmax(pmProfit[OP_SELL][PM_OPEN_HIGH],LotValue(LOT_SHORT_PROFIT,IN_EQUITY));
    pmProfit[OP_SELL][PM_OPEN_LOW]   = fmin(pmProfit[OP_SELL][PM_OPEN_LOW],LotValue(LOT_SHORT_PROFIT,IN_EQUITY));
    pmProfit[OP_SELL][PM_OPEN_MIN]   = fmin(pmProfit[OP_SELL][PM_OPEN_MIN],LotValue(LOT_SHORT_LOSS,IN_EQUITY));
    pmProfit[OP_SELL][PM_OPEN_LOTS]  = LotCount(LOT_SHORT_NET);
        
    if (pmProfit[OP_SELL][PM_OPEN_HIGH] == LotValue(LOT_SHORT_PROFIT,IN_EQUITY))
      pmProfit[OP_SELL][PM_OPEN_LOW] = LotValue(LOT_SHORT_PROFIT,IN_EQUITY);

    if (pmProfit[OP_SELL][PM_OPEN_LOTS]<pmProfitLast[OP_SELL][PM_OPEN_LOTS])
    {
      pmProfit[OP_SELL][PM_CLOSE_LOTS]    = pmProfitLast[OP_SELL][PM_OPEN_LOTS]-pmProfit[OP_SELL][PM_OPEN_LOTS];
      pmProfit[OP_SELL][PM_CLOSE_PRICE]   = ordLastAsk;
    }

    if (pmProfit[OP_SELL][PM_OPEN_LOTS]>pmProfitLast[OP_SELL][PM_OPEN_LOTS])
      pmNewOrder  = OP_SELL;
  }
  
//+------------------------------------------------------------------+
//| pmSetProfitParams - configures processes related to order closes |
//+------------------------------------------------------------------+
void pmSetProfitParams()
  {
    //--- handle pivot leg tp data
    if (NormalizeDouble(regrFast[regrFOCCur],1) == NormalizeDouble(regrFast[regrFOCMax],1))
      for (int idx=0; idx<2; idx++)
      {
        pmProfit[idx][PM_EQ_TARGET_MIN] = 0.00;
        pmProfit[idx][PM_EQ_TARGET_MAX] = 0.00;
        pmProfit[idx][PM_CLOSE_LOTS]    = 0.00;
        pmProfit[idx][PM_CLOSE_PRICE]   = 0.00;
      }
    
    //--- Long operations
    if (pipMANewHigh())
      if (LotValue(LOT_LONG_PROFIT)>0.00)
      {
        pmAction = OP_BUY;

        if (High[0]>regrFast[regrPolyST])
          SetEquityHold(pmAction);
      }

    if (pmAction == OP_BUY)
      if (LotCount(LOT_LONG_NET) == 0.00)
        pmAction = OP_NO_ACTION;

    //--- Short operations    
    if (pipMANewLow())
      if (LotValue(LOT_SHORT_PROFIT)>0.00)
      {
        pmAction = OP_SELL;

        if (Low[0]<regrFast[regrPolyST])
          SetEquityHold(pmAction);
      }
      
    if (pmAction == OP_SELL)
      if (LotCount(LOT_SHORT_NET) == 0.00)
        pmAction = OP_NO_ACTION;
  }
  
//+------------------------------------------------------------------+
//| pmExecuteProfit - takes profit                                   |
//+------------------------------------------------------------------+
void pmExecuteProfit()
  {
    int    profitAction = DirAction((int)regrFast[regrFOCTrendDir]);
    double profitEQ     = 0.00;
    
    if (profitAction == OP_BUY)
      profitEQ = LotValue(LOT_LONG_NET, IN_EQUITY);
    
    if (profitAction == OP_SELL)
      profitEQ = LotValue(LOT_SHORT_NET, IN_EQUITY);

    //--- Profit Strat #1 - take profit on a waning crest;
    if (regrFast[regrFOCDev]>0.1)
      if (pmProfit[profitAction][PM_EQ_TARGET_MAX] == 0.00)
      {
        if (fabs(regrFast[regrFOCMax])>data[dataAmpMean]*inpPMProfitFactor &&
            pmProfit[profitAction][PM_CLOSE_PRICE]   == 0.00)
        {
          pmProfit[profitAction][PM_EQ_TARGET_MAX] = pmProfit[profitAction][PM_OPEN_HIGH];
          pmProfit[profitAction][PM_EQ_TARGET_MIN] = pmProfit[profitAction][PM_OPEN_LOW]-ordEQTargetMin;
        }
      }
      else
      if (profitEQ >= pmProfit[profitAction][PM_EQ_TARGET_MAX] ||
          profitEQ <= pmProfit[profitAction][PM_EQ_TARGET_MIN])
      {
        CloseOrders(CLOSE_CONDITIONAL, profitAction);
        
        pmProfit[profitAction][PM_EQ_TARGET_MIN] = 0.00;
        pmProfit[profitAction][PM_EQ_TARGET_MAX] = 0.00;
      }
  }
  
//+------------------------------------------------------------------+
//| CallProfitManager - Reviews facts/recommends and takes profit    |
//+------------------------------------------------------------------+
void CallProfitManager()
  {
    pmGetProfitData();
    pmSetProfitParams();
    pmExecuteProfit();
  }

//+------------------------------------------------------------------+
//| pmInit() - executes profit manager initialization tasks          |
//+------------------------------------------------------------------+
void pmInit()
  {
    ArrayInitialize(pmProfit,0.00);

    pmPrecision[PM_CLOSE_PRICE] = Digits;
  }
