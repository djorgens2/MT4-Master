//+------------------------------------------------------------------+
//|                                                        pt-v3.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "http://www.dennisjorgenson.com"
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <pipMA-v3.mqh>
#include <regrMA-v1.mqh>

//--- Strategy constants
#define STRAT_UNDEFINED    -1
#define STRAT_ST            0
#define STRAT_ST_NET        1
#define STRAT_LT            2
#define STRAT_LT_NET        3
#define STRAT_MAX           4
#define STRAT_MIN           5

//--- Strategy order type index
#define STRAT_LONG          0
#define STRAT_SHORT         1

//--- Strategy matrix
int     stratMatrix[8][8][2] =
          {{{STRAT_MAX,STRAT_MIN},{STRAT_ST_NET,STRAT_ST},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED}},
           {{STRAT_LT_NET,STRAT_ST},{STRAT_ST,STRAT_ST_NET},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED}},
           {{STRAT_LT,STRAT_ST_NET},{STRAT_ST,STRAT_ST_NET},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED}},
           {{STRAT_ST_NET,STRAT_ST},{STRAT_ST_NET,STRAT_ST},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED}},
           {{STRAT_MIN,STRAT_LT_NET},{STRAT_MIN,STRAT_MAX},{STRAT_MIN,STRAT_MAX},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED}},
           {{STRAT_ST,STRAT_ST_NET},{STRAT_UNDEFINED,STRAT_ST_NET},{STRAT_ST,STRAT_LT_NET},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED}},
           {{STRAT_ST_NET,STRAT_ST},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_ST_NET,STRAT_LT},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED}},
           {{STRAT_LT,STRAT_LT_NET},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_ST,STRAT_LT_NET},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED},{STRAT_UNDEFINED,STRAT_UNDEFINED}}
          };


//--- Strategy operational variables
int      stratCol       = 0;
int      stratRow       = 0;

bool     profitShort    = false;
bool     profitLong     = false;


//+------------------------------------------------------------------+
//| StratText - returns the text of an StratCode                     |
//+------------------------------------------------------------------+
string StratText(int Action)
{
  int Value = stratMatrix[stratRow][stratCol][Action];

  switch (Value)
  {
    case STRAT_UNDEFINED  : return("UNDEFINED STRATEGY");
    case STRAT_ST         : return("SHORT TERM");
    case STRAT_ST_NET     : return("SHORT TERM NET");
    case STRAT_LT         : return("LONG TERM");
    case STRAT_LT_NET     : return("LONG TERM NET");
    case STRAT_MAX        : return("MAXIMUM");      
    case STRAT_MIN        : return("MINIMUM");       
    default               : return("BAD STRATEGY CODE");
  }
}
  
//+------------------------------------------------------------------+
//| StratCode - returns the strategy for the action from the matrix  |
//+------------------------------------------------------------------+
int StratCode(int Action)
{
  return(stratMatrix[stratRow][stratCol][Action]);
}
  
//+------------------------------------------------------------------+
//| GetData - gets indicator data                                    |
//+------------------------------------------------------------------+
void GetData()
  {
    pipMAGetData();
    regrMAGetData();
  }

//+------------------------------------------------------------------+
//| RefreshScreen - repaint visual data                              |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
  }

//+------------------------------------------------------------------+
//| UpdateStrategy - Finds strategy via the decision matrix          |
//+------------------------------------------------------------------+
void UpdateStrategy()
  {
    stratCol       = STRAT_UNDEFINED;
    stratRow       = STRAT_UNDEFINED;

    //---- 1. Determine strategy column
    if (regr[regrTLineDirLT] == DIR_UP)
      if (regr[regrTLineDirST] == DIR_UP)
        stratCol = 0;
      else
        stratCol = 2;
    else
    if (regr[regrTLineDirLT] == DIR_DOWN)
      if (regr[regrTLineDirST] == DIR_DOWN)
        stratCol = 4;
      else
        stratCol = 6;
        
    //---- 2. Determine strategy row
    if (regr[regrPTrendWane]>0.00)
      stratCol  += 1;

    if (regr[regrST]>regr[regrTLine])
      if (regr[regrST]>regr[regrLT])
        stratRow = 0;
      else
        stratRow = 2;
    else
    if (regr[regrST]<regr[regrTLine])
      if (regr[regrST]<regr[regrLT])
        stratRow = 4;
      else
        stratRow = 6;
        
    if (regr[regrTrendWane]>0.00)
      stratRow  += 1;

    Comment("RC: ("+IntegerToString(stratRow)+","+IntegerToString(stratCol)+")\n"+"Long:  "+StratText(STRAT_LONG)+"\n"+"Short: "+StratText(STRAT_SHORT));
  }

//+------------------------------------------------------------------+
//| AutoTrade - Executes trades in auto mode                         |
//+------------------------------------------------------------------+
bool Event(int Action)
  {
     if (Action == OP_SELL &&  pipMANewHigh())
     {
       if (regr[regrStr] == REGR_SOFT_SHORT && data[dataFOCCur] < 0.00)
         return (true);
         
       if (regr[regrStr] == REGR_STRONG_SHORT && fabs(data[dataFOCCur]) < fabs(data[dataFOCMax]))
         return (true);
     }
     
     if (Action == OP_BUY && pipMANewLow())
     {
       if (regr[regrStr] == REGR_SOFT_LONG && data[dataFOCCur] > 0.00)
         return (true);
         
       if (regr[regrStr] == REGR_STRONG_LONG && data[dataFOCCur] < data[dataFOCMax])
         return (true);     
     }
     
     return (false);
  }
  
//+------------------------------------------------------------------+
//| AutoTrade - Executes trades in auto mode                         |
//+------------------------------------------------------------------+
void AutoTrade()
  {
    UpdateStrategy();
    
    //--- New orders
    if (Event(OP_SELL))
    {
      if (!orderPending())
      {
        OpenLimitOrder(OP_SELL,Bid+point(0.5),data[dataRngLow],0.00,"Auto",IN_PRICE);
        profitShort = false;
      }
    }

    if (Event(OP_BUY))
    {
      if (!orderPending())
        OpenLimitOrder(OP_BUY,Ask-point(0.5),data[dataRngHigh],0.00,"Auto",IN_PRICE);
    }

    //--- TP Requests
    if (pipMANewLow() && regr[regrTrendWane]>0.00)
    {
      if (!profitShort)
        CloseOrders(CLOSE_CONDITIONAL, OP_SELL);
  
      profitShort = true;
      profitLong = false;
    }

    if (pipMANewHigh() && regr[regrTrendWane]>0.00)
    {
      if (!profitLong)
        CloseOrders(CLOSE_CONDITIONAL, OP_BUY);
  
      profitLong = true;
      profitShort = false;
    }   
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();

    manualProcessRequest();
    orderMonitor();

    if (manualAuto)
      AutoTrade();
      
    RefreshScreen();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();    
    
    SetMode(Auto);
    
    eqhalf   = true;
    eqprofit = true;
    
    SetRisk(80);
    SetTarget(200);
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }