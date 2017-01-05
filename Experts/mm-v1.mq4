//+------------------------------------------------------------------+
//|                                                        mm-v1.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <Class\Manage.mqh>

CManage   *manage       = new CManage();


//+------------------------------------------------------------------+
//| AutoTrade - analyze and execute trades                           |
//+------------------------------------------------------------------+
void AutoTrade(void)
  {
    manage.Update();
  
    return;
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(void)
  {
    manualProcessRequest();
    orderMonitor();
    
    if (manualAuto)
      if (!eqhalt)
        AutoTrade();
  }


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(void)
  {
    manualInit();
    
    SetProfitPolicy(eqhalf);
    SetProfitPolicy(eqprofit);
    
    SetEquityTarget(80,1);
    SetRisk(80,10);     
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete manage;
  }