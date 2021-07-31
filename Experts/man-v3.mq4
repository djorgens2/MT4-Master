//+------------------------------------------------------------------+
//|                                                       man-v3.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <Class\Order.mqh>

  COrder *order            = new COrder(Discount,3,true);

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    order.Update();  
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    #define NoQueue    false
    
    OrderRequest   eRequest = {0,OP_BUY,"Mgr:Test",0,0,0,0,"",0,NoStatus};
  
    if (OrdersTotal()==0)
    {
      eRequest.Lots            = order.LotSize(OP_BUY);
      eRequest.Memo            = "Test";
      eRequest.Expiry          = Time[0]+(Period()*(60*2));
     
      order.Submit(eRequest,NoQueue);
    }
   
    order.Execute();
    
    if (order.Fulfilled())
      Print(order.MasterStr(OP_BUY));
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
    
    order.EnableTrade();
    
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      order.SetTradeState(action,Enabled);
      order.SetEquity(action,inpMinTarget,inpMinProfit,inpEQHalf,inpEQProfit);
      order.SetRisk(action,inpMaxRisk,inpMaxMargin,inpLotFactor);
      order.SetDefault(action,inpLotSize,inpDefaultStop,inpDefaultTarget);
      order.SetZone(OP_BUY,18.00,2.5);
    }
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete (order);
  }