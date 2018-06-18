//+------------------------------------------------------------------+
//|                                                        pt-v7.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <pipMA-v4.mqh>
#include <regrMA-v3.mqh>


#include <ma-v2.mqh>
#include <rm-v1.mqh>
#include <om-v1.mqh>
#include <pm-v1.mqh>


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

    strMgmtRpt += MarketAnalystReport();
    strMgmtRpt += OrderManagerReport();
    strMgmtRpt += ProfitManagerReport();
    strMgmtRpt += RiskManagerReport();    
                        
    Comment(strMgmtRpt);
  }

//+------------------------------------------------------------------+
//| AutoTrade - Executes trades in auto mode                         |
//+------------------------------------------------------------------+  
void AutoTrade()
  { 
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
    
    if (tradeModeChange)
    {
      maInit();
      pmInit();
    }
      
    orderMonitor();

    if (pipMALoaded)
    {
      CallMarketAnalyst();

      if (manualAuto)
        AutoTrade();      
    }
    
    RefreshScreen();
//    Comment("STTL Head/Tail/FOC:"+DoubleToStr(regrComp[compFastPolySTTLHead],Digits)+"/"+DoubleToStr(regrComp[compFastPolySTTLTail],Digits)+"/"+DoubleToStr(regrComp[compFastPolySTTLFOC],1));
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();    
    
    if (manTradeMode == Auto)
    {
      maInit();
      pmInit();
    }
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }   