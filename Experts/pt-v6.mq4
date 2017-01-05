//+------------------------------------------------------------------+
//|                                                        pt-v6.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <pipMA-v3.mqh>
#include <regrMA-v2.mqh>

//--- User-defined input
input double inpRiskLevel         = 1.2;  // Risk risk manager level

//--- Term Constants
#define  T_NO_TERM        0
#define  T_SHORT_TERM     1
#define  T_LONG_TERM      2

//--- Risk Manager
int    rmCurDir         = DIR_NONE;
int    rmLongAction     = OP_NO_ACTION;
int    rmShortAction    = OP_NO_ACTION;

//--- Profit Manager
double pmStop           = 0.00;
int    pmAction         = OP_NO_ACTION;

//--- Order Manager
int    omAction         = OP_NO_ACTION;
int    omLastTicket     = true;
int    omPivOrdCnt      = 0;
bool   omEvent          = false;

//--- Market Manager
int    mmTermLong       = T_NO_TERM;
int    mmTermShort      = T_NO_TERM;
bool   mmTop            = false;
bool   mmBottom         = false;

//+------------------------------------------------------------------+
//| CallMarketManager - Analyzes data, makes recommendations         |
//+------------------------------------------------------------------+
void CallMarketManager()
  {    
    //--- Major Trend Check
    //--- Pivot Change
    if (data[dataFOCTrendDir] != dataLast[dataFOCTrendDir])
    {
      if (data[dataFOCTrendDir]==DIR_UP)
        if (regr[regrFOCTrendDir]==DIR_UP)
          NewArrow(SYMBOL_ARROWUP,clrYellow);

      if (data[dataFOCTrendDir]==DIR_DOWN)
        if (regr[regrFOCTrendDir]==DIR_DOWN)
          NewArrow(SYMBOL_ARROWDOWN,clrRed);
    }

    //--- Short term hold
    if (regr[regrFOCTrendDir]==DIR_UP)
      SetEquityHold(OP_BUY);
    else
    if (regr[regrFOCTrendDir]==DIR_DOWN)
      SetEquityHold(OP_SELL);
    else
      SetEquityHold(DIR_NONE);    
  }
  
//+------------------------------------------------------------------+
//| CallRiskManager - Sets risk manager percentage levels            |
//+------------------------------------------------------------------+
void CallRiskManager()
  {    
    //--- Micro Manager
    //--- FOC equality check
/*    if (data[dataFOCCur]==data[dataFOCMax])
    {
      if (data[dataFOCTrendDir]==DIR_UP)
      {
        if (LotValue(LOT_SHORT_LOSS)<0.00)
        {
          if (data[dataFOCMax]>=inpRiskLevel)
            rmShortAction = DIR_DOWN;

          if (data[dataFOCDev]>=inpRiskLevel && 
              data[dataFOCPivDevMax]-data[dataFOCPivDev]>=inpRiskLevel)
          {
            rmAction = DIR_NONE;
          }
        }

        if (LotValue(LOT_SHORT_LOSS)==0.00)
          rmAction = DIR_NONE;
      }

      if (data[dataFOCTrendDir]==DIR_DOWN)
      {
        if (LotValue(LOT_LONG_LOSS)<0.00)
        {
          if (fabs(data[dataFOCMax])>=inpRiskLevel)
            rmAction = DIR_UP;

          if (data[dataFOCDev]>=inpRiskLevel && 
              data[dataFOCPivDevMax]-data[dataFOCPivDev]>=inpRiskLevel)
            rmAction = DIR_NONE;
        }

        if (LotValue(LOT_LONG_LOSS)==0.00)
          rmAction = DIR_NONE;
      }
    }
*/    
  }

//+------------------------------------------------------------------+
//| CallProfitManager - Reviews facts/recommends and takes profit    |
//+------------------------------------------------------------------+
void CallProfitManager()
  {
    //Comment("EQ%:"+DoubleToStr(EquityPercent(),1)+"% Long:"+DoubleToStr(LotValue(LOT_LONG_PROFIT,IN_EQUITY),1)+"% Short:"+DoubleToStr(LotValue(LOT_SHORT_PROFIT,IN_EQUITY),1));

    if (pipMANewHigh())
      if (LotValue(LOT_LONG_PROFIT)>0.00)
        pmAction = OP_BUY;
    
    if (pipMANewLow())
      if (LotValue(LOT_SHORT_PROFIT)>0.00)
        pmAction = OP_SELL;
    
    if (pmAction == OP_BUY)
    {
      if (LotCount(LOT_LONG_NET) == 0.00)
        pmAction = OP_NO_ACTION;
      else
      {
        //--- profit manager profit tasks
      }
    }

    if (pmAction == OP_SELL)
    {
      if (LotCount(LOT_SHORT_NET) == 0.00)
        pmAction = OP_NO_ACTION;
      else
      {
        //--- profit manager profit tasks
      }
    }
  }

//+------------------------------------------------------------------+
//| CallOrderManager - Reviews facts/recommends and opens orders     |
//+------------------------------------------------------------------+
void CallOrderManager()
  {
    if (data[dataFOCTrendDir]!=dataLast[dataFOCTrendDir])
    {
      omPivOrdCnt = 0;

      if (data[dataFOCTrendDir] == DIR_DOWN) omAction = OP_SELL;
      if (data[dataFOCTrendDir] == DIR_UP) omAction = OP_BUY;

      if (RiskManagerApproval(omAction))
        OpenLimitOrder(omAction,point(3.0),point(20.0),0.00,"OM-Auto",IN_PIPS);
    }
    
    if (orderPending())
    {}
    else
    {
      if (orderOpenSuccess())
      {
        omLastTicket = ordOpenTicket;
        omEvent      = false;
        omPivOrdCnt++;
      }
      
      if (pipMANewHigh() || pipMANewLow())
        omEvent      = true;
//      if (data[dataFOCDev]>(0.1) &&
    }
  }
  
//+------------------------------------------------------------------+
//| RiskManagerApproval- Reviews facts/recommends and approves trade |
//+------------------------------------------------------------------+
bool RiskManagerApproval(int Action)
  {
    return (true);
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
    string strMgmtRpt = "";

    //--- Risk Manager Report
//    if (rmAction!=DIR_NONE)
//      strMgmtRpt += "Micro Manager: "+proper(DirText(rmAction))+" at risk\n";
      
    //--- Profit Manager Report
    if (pmAction!=OP_NO_ACTION)
      if (pmStop > 0.00)
        strMgmtRpt += "Profit Manager: "+proper(ActionText(pmAction))+" exit target ("+DoubleToStr(pmStop,1)+"\n";
      else    
        strMgmtRpt += "Profit Manager: Calculating "+proper(ActionText(pmAction))+" profit target\n";

    strMgmtRpt = DoubleToStr(LotValue(LOT_LONG_PROFIT,IN_EQUITY),1)+"% "+DoubleToStr(LotValue(LOT_SHORT_PROFIT,IN_EQUITY),1)+"%";
    
    Comment(strMgmtRpt);
  }

//+------------------------------------------------------------------+
//| EventOpen - Identifies potential order entry points              |
//+------------------------------------------------------------------+
int EventOpen()
  {
     
     return (OP_NO_ACTION);
  }
  
//+------------------------------------------------------------------+
//| EventClose - Identifies potential order exit points              |
//+------------------------------------------------------------------+
bool EventClose(int Action)
  {
     return (false);
  }

//+------------------------------------------------------------------+
//| AutoTrade - Executes trades in auto mode                         |
//+------------------------------------------------------------------+
void AutoTrade()
  { 
    CallMarketManager();
    CallRiskManager();
    CallProfitManager();
    CallOrderManager();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();

    manualProcessRequest();
    orderMonitor();

    if (pipMALoaded)
    {
      if (manualAuto)
        AutoTrade();
    }
      
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
    eqdir    = true;
    
    SetRisk(80);
    SetTarget(5);


    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }