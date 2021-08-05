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
//| Stop/TP Test                                                     |
//+------------------------------------------------------------------+
void Test1(void)
  {
    #define NoQueue    false
    static int Tick = 0;
    
    Tick++;
    
    OrderRequest   eRequest = {NoStatus,0,0,OP_BUY,OP_NO_ACTION,"Mgr:Test",0,0,0,0,false,"",0};
    
    order.SetRisk(OP_BUY,80,80,2);
  
 //--- Stop/Limit Test
    if (OrdersTotal()<3)
    {
      eRequest.Lots            = order.LotSize(OP_BUY);
      eRequest.Memo            = "Test";
      eRequest.Expiry          = Time[0]+(Period()*(60*2));
     
      order.Submit(eRequest);
    }
    else
    {
      eRequest.Memo            = "Test-Tick["+(string)Tick+"]";
      eRequest.Expiry          = Time[0]+(Period()*(60*2));

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
                 order.Submit(eRequest);
                 break;
        case 7:  order.SetStop(OP_BUY,0.00,0,false);
                 order.SetTarget(OP_BUY,0.00,0,false);
                 eRequest.TakeProfit   = 18.16;
                 order.Submit(eRequest);
                 break;
        case 8:  order.SetStop(OP_BUY,0.00,20,Always);
                 order.SetTarget(OP_BUY,0.00,0,Always);
                 order.Submit(eRequest);
                 break;
        case 9:  order.SetStop(OP_BUY,17.2,0,Always);
                 order.SetTarget(OP_BUY,18.20,0,Always);
                 break;
        case 10: order.SetStop(OP_BUY,17.2,0,Always);
                 order.SetTarget(OP_BUY,18.11,0,false);
                 break;
        case 11: order.SetRisk(OP_SELL,80,80,4);
                 order.SetStop(OP_SELL,0.00,30,false);
                 order.SetTarget(OP_SELL,0.00,30,false);
                 eRequest.Type   = OP_SELL;
                 order.Submit(eRequest);
                 break;
        case 12: order.SetStop(OP_SELL,18.40,0,false);
                 order.SetTarget(OP_SELL,17.50,0,false);
                 eRequest.Type   = OP_SELL;
                 order.Submit(eRequest);
                 break;
        case 13: order.SetStop(OP_SELL,18.40,20,false);
                 order.SetTarget(OP_SELL,0.00,20,false);
                 eRequest.Type   = OP_SELL;
                 order.Submit(eRequest);
                 break;
        case 14: order.SetStop(OP_SELL,0.00,50,Always);
                 order.SetTarget(OP_SELL,0.00,30,false);
                 eRequest.Type   = OP_SELL;
                 order.Submit(eRequest);
                 break;
      }
    }
    
//    if (Tick>8)
     Print(order.QueueStr());
  }

//+------------------------------------------------------------------+
//| Long Queue Orders (Limit/Stop) + Zone Summary tests              |
//+------------------------------------------------------------------+
void Test2(void)
  {
    OrderRequest   eRequest = {NoStatus,0,0,OP_BUYSTOP,OP_NO_ACTION,"Mgr:Test",0,0,0,0,false,"Queue Order Test"};
    
    static bool fill   = false;

    order.SetRisk(OP_BUY,80,80,2);
      
 //--- Queue Order Test
    if (IsEqual(OrdersTotal(),0))
      if (IsEqual(Close[0],17.982,Digits))
      {
        eRequest.Pend.Limit      = 17.982;
        eRequest.Pend.Step       = 2;
        eRequest.Pend.Cancel     = 18.112;
        eRequest.Pend.Retain     = true;
        eRequest.Price           = 0.00;
        eRequest.TakeProfit      = 18.12;
        eRequest.Price           = 17.982;
        eRequest.Expiry          = Time[0]+(Period()*(60*2));
     
        order.Submit(eRequest);
        fill=true;
      }
      
      if (order.Fulfilled())
        fill = true;

      if (fill)
        Print(order.ZoneSummaryStr());
//        Print(order.QueueStr());
  }

//+------------------------------------------------------------------+
//| Short Queue Orders (Limit/Stop) + Zone Summary tests             |
//+------------------------------------------------------------------+
void Test3(void)
  {
    OrderRequest   eRequest = {NoStatus,0,0,OP_SELLSTOP,OP_NO_ACTION,"Mgr:Test",0,0,0,0,false,"ShortQ Order Test"};
    
    order.SetRisk(OP_BUY,80,80,2);
      
    //--- Queue Order Test
    if (IsEqual(order[OP_SELL].Count,0))
      if (Close[0]>18.09)
      {
        eRequest.Pend.Limit      = 17.982;
        eRequest.Pend.Step       = 2;
        eRequest.Pend.Cancel     = 18.112;
        eRequest.Pend.Retain     = true;
        eRequest.Price           = 0.00;
        eRequest.TakeProfit      = 18.12;
        eRequest.Price           = 17.982;
        eRequest.Expiry          = Time[0]+(Period()*(60*2));
     
        order.Submit(eRequest);
        order.PrintLog(Order);
        Print(order.QueueStr());
      }
      
      if (order.Fulfilled())
      {
        order.PrintLog(Order);        
      } 
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    #define Test   2
    
    switch (Test)
    {
      case 1:  Test1();
               break;
      case 2:  Test2();
               break;
      case 3:  Test3();
    }
    
//    if (order[OP_BUY].Count>0)
//      Print(order.QueueStr());

    order.Execute();
    
    //if (order.Fulfilled())
    //{
    //  Print(order.QueueStr());
    //  if (order[OP_BUY].Count>0)
    //    order.PrintLog(Order);
    //  Print(order.ZoneSummaryStr());
    //}
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
      order.EnableTrade(action);
      order.SetEquity(action,inpMinTarget,inpMinProfit,inpEQHalf,inpEQProfit);
      order.SetRisk(action,inpMaxRisk,inpMaxMargin,inpLotFactor);
      order.SetDefault(action,inpLotSize,inpDefaultStop,inpDefaultTarget);
      order.SetStep(action,2.5);
    }
    
    Print(order.MasterStr(OP_BUY));
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete (order);
  }