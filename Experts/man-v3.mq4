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
    static int Tick = 0;
    
    Tick++;
    
    OrderRequest   eRequest = {0,0,OP_BUY,"Mgr:Test",0,0,0,0,"",0,NoStatus};
    
    order.SetRisk(OP_BUY,80,80,2);
  
    if (OrdersTotal()<3)
    {
      eRequest.Lots            = order.LotSize(OP_BUY);
      eRequest.Memo            = "Test";
      eRequest.Expiry          = Time[0]+(Period()*(60*2));
     
      order.Submit(eRequest,NoQueue);
    }
    else
    {
      eRequest.Memo            = "Test-Tick";
      eRequest.Expiry          = Time[0]+(Period()*(60*2));
                 //int omg =1;
                 //OrderDetail detail  = OrderSearch(omg);
      switch(Tick)
      {
        case 4:  order.SetStop(OP_BUY,0.00,20,false);
                 order.SetTarget(OP_BUY,0.00,20,false);
                 break;
        case 5:  order.SetStop(OP_BUY,17.40,0,false);
                 order.SetTarget(OP_BUY,18.75,30,false);
                 break;
        case 6:  order.SetStop(OP_BUY,17.8,70,false);
                 order.SetTarget(OP_BUY,18.20,70,false);
                 order.Submit(eRequest,NoQueue);
                 break;
        case 7:  order.SetStop(OP_BUY,0.00,0,false);
                 order.SetTarget(OP_BUY,0.00,0,false);
                 eRequest.TakeProfit   = 18.16;
                 order.Submit(eRequest,NoQueue);
                 break;
        case 8:  order.SetStop(OP_BUY,0.00,20,Always);  //-- Default stop not working on invisible...
                 order.SetTarget(OP_BUY,0.00,0,Always);  //-- will work this issue after Order[] is finished
                 order.Submit(eRequest,NoQueue);         //      (Now getting TP/SL prices from OrderSelect()/Live
                 Print(order.OrderDetailStr(order.GetOrder(1)));
                 break;                                  //       correction is to store on Order[];
        case 9:  order.SetStop(OP_BUY,17.2,0,Always);
                 order.SetTarget(OP_BUY,18.20,0,Always);
                 break;
        case 10: order.SetStop(OP_BUY,17.2,0,Always);
                 order.SetTarget(OP_BUY,18.11,0,false);
                 break;
        case 11: order.SetRisk(OP_SELL,80,80,4);
                 order.SetStop(OP_SELL,0.00,30,false);
                 order.SetTarget(OP_SELL,0.00,30,false);
                 eRequest.Action   = OP_SELL;
                 order.Submit(eRequest,NoQueue);
                 break;
        case 12: order.SetStop(OP_SELL,18.40,0,false);
                 order.SetTarget(OP_SELL,17.50,0,false);
                 eRequest.Action   = OP_SELL;
                 order.Submit(eRequest,NoQueue);
                 break;
        case 13: order.SetStop(OP_SELL,18.40,20,false);
                 order.SetTarget(OP_SELL,0.00,20,false);
                 eRequest.Action   = OP_SELL;
                 order.Submit(eRequest,NoQueue);
                 break;
        case 14: order.SetStop(OP_SELL,0.00,50,Always);
                 order.SetTarget(OP_SELL,0.00,30,false);
                 eRequest.Action   = OP_SELL;
                 order.Submit(eRequest,NoQueue);
                 break;
      }
    } 
    order.Execute();
    
//    if (order.Fulfilled())
      Print(order.QueueStr());
      Print(order.OrderDetailStr(order.GetOrder(1)));

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