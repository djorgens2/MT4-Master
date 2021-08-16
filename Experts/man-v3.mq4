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

  COrder *order            = new COrder(Discount,Hold,Hold);

  int Tick                 = 0;

  AccountMetrics Account;
  int            Tickets[];
  OrderSummary   NodeNow[2];
  int            IndexNow[2];


//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+`
void GetData(void)
  {
    static int index[2]  = {0,0};
    
    order.Update(Account);
    
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      IndexNow[action]    = order.Index(action);
      order.GetNode(action,IndexNow[action],NodeNow[action]);

      //if (IsChanged(index[action],IndexNow[action]))
      //  Print(order.ZoneSummaryStr(action));
    }
    
    if (order.Fulfilled())
    {
//      Print(DoubleToStr(order[Net].Margin,1)+"%");
//      Print(DoubleToStr(order[OP_BUY].Lots,Account.LotPrecision)+" $"+DoubleToStr(order[OP_BUY].Value,0));
//      for (int node=0;node<order.Nodes(OP_BUY);node++)
//      Print("Zone: $"+DoubleToStr(order.Zone(OP_BUY,node).Value,2));
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {

    UpdateLine("czDCA:"+(string)OP_BUY,Account.DCA[OP_SELL],STYLE_SOLID,clrYellow);  
  }

//+------------------------------------------------------------------+
//| Stop/TP Test                                                     |
//+------------------------------------------------------------------+
void Test1(void)
  {
    #define NoQueue    false
    
    OrderRequest eRequest   = order.BlankRequest();
    
    eRequest.Requestor      = "Test[1] Market";
    eRequest.Type           = OP_BUY;
    eRequest.Memo           = "Test 1-General Functionality";
    
//    order.DisableTrade(OP_BUY);
    order.SetRiskLimits(OP_BUY,80,80,2);
  
 //--- Stop/Limit Test
    if (OrdersTotal()<3)
    {
      eRequest.Lots            = order.LotSize(OP_BUY);
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*2));
     
      order.Submitted(eRequest);
    }
    else
    {
      eRequest.Memo            = "Test-Tick["+(string)Tick+"]";
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*2));

      switch(Tick)
      {
        case 4:  order.SetStopLoss(OP_BUY,0.00,20,false);
                 order.SetTakeProfit(OP_BUY,0.00,20,false);
                 break;
        case 5:  order.SetStopLoss(OP_BUY,17.40,0,false);
                 order.SetTakeProfit(OP_BUY,18.75,30,false);
                 break;
        case 6:  order.SetStopLoss(OP_BUY,17.8,70,false);
                 order.SetTakeProfit(OP_BUY,18.20,70,false);
                 order.Submitted(eRequest);
                 break;
        case 7:  order.SetStopLoss(OP_BUY,0.00,0,false);
                 order.SetTakeProfit(OP_BUY,0.00,0,false);
                 eRequest.TakeProfit   = 18.16;
                 order.Submitted(eRequest);
                 break;
        case 8:  order.SetStopLoss(OP_BUY,0.00,20,Always);
                 order.SetTakeProfit(OP_BUY,0.00,0,Always);
                 order.Submitted(eRequest);
                 break;
        case 9:  order.SetStopLoss(OP_BUY,17.2,0,Always);
                 order.SetTakeProfit(OP_BUY,18.20,0,Always);
                 break;
        case 10: order.SetStopLoss(OP_BUY,17.2,0,Always);
                 order.SetTakeProfit(OP_BUY,18.11,0,false);
                 break;
        case 11: order.SetRiskLimits(OP_SELL,80,80,4);
                 order.SetStopLoss(OP_SELL,0.00,30,false);
                 order.SetTakeProfit(OP_SELL,0.00,30,false);
                 eRequest.Type   = OP_SELL;
                 order.Submitted(eRequest);
                 break;
        case 12: order.SetStopLoss(OP_SELL,18.40,0,false);
                 order.SetTakeProfit(OP_SELL,17.50,0,false);
                 eRequest.Type   = OP_SELL;
                 order.Submitted(eRequest);
                 break;
        case 13: order.SetStopLoss(OP_SELL,18.40,20,false);
                 order.SetTakeProfit(OP_SELL,0.00,20,false);
                 eRequest.Type   = OP_SELL;
                 order.Submitted(eRequest);
                 break;
        case 14: order.SetStopLoss(OP_SELL,0.00,50,Always);
                 order.SetTakeProfit(OP_SELL,0.00,30,false);
                 eRequest.Type   = OP_SELL;
                 order.Submitted(eRequest);
                 break;
      }
    }
    
//    if (Tick>8)
//     Print(order.QueueStr());
  }

//+------------------------------------------------------------------+
//| Long Queue Orders (Limit/Stop) + Zone Summary tests              |
//+------------------------------------------------------------------+
void Test2(void)
  {
    int req                 = 0;
    OrderRequest eRequest   = order.BlankRequest();
    
    eRequest.Requestor      = "Test[2] Resub";
    eRequest.Memo           = "Test 2-Pend/Recur Test";
    
    static bool fill   = false;

    order.SetRiskLimits(OP_BUY,80,80,2);
      
    //--- Queue Order Test
      if (!fill) 
      {
        eRequest.Pend.Type       = OP_BUYSTOP;
        eRequest.Pend.Limit      = 17.970;
        eRequest.Pend.Step       = 2;
        eRequest.Pend.Cancel     = 18.112;

        eRequest.Type            = OP_BUYLIMIT;
        eRequest.Price           = 17.994;
        eRequest.TakeProfit      = 18.12;
        eRequest.Expiry          = TimeCurrent()+(Period()*(60*12));
    
//        Print(order.RequestStr(eRequest));
        if (order.Submitted(eRequest))
//          Print(order.RequestStr(eRequest));
          fill=true;
          
        eRequest.Pend.Type       = OP_SELLSTOP;
        eRequest.Pend.Limit      = 18.160;
        eRequest.Pend.Step       = 2;
        eRequest.Pend.Cancel     = 17.765;

        eRequest.Type            = OP_SELLLIMIT;
        eRequest.Price           = 18.116;
        eRequest.TakeProfit      = 17.765;
        eRequest.Expiry          = TimeCurrent()+(Period()*(60*12));

        if (order.Submitted(eRequest))
//          Print(order.RequestStr(eRequest));
          fill=true;
      }

      if (Tick==1260)
        order.SetStopLoss(OP_BUY,0.00,25,false);
      if (Tick==1300)
        order.SetStopLoss(OP_BUY,0.00,50,false,false);
//      if (order[OP_BUY].Count>0)
//        Print(order.ZoneSummaryStr());
//

      if (order.Fulfilled())
      {
//        Print("Fulfilled: "+order.ZoneSummaryStr(order.Zone(OP_BUY,order.NodeIndex(OP_BUY)).Count));
//        Print(order.OrderStr());
      } 

//      Print(order.QueueStr());
  }

//+------------------------------------------------------------------+
//| Short Queue Orders (Limit/Stop) + Zone Summary tests             |
//+------------------------------------------------------------------+
void Test3(void)
  {
    OrderRequest eRequest   = order.BlankRequest();
    
    eRequest.Requestor      = "Test[3] Shorts";
    eRequest.Memo           = "Test 3-Short Pend/Recur Test";
    
    order.SetRiskLimits(OP_BUY,80,80,2);
      
    //--- Queue Order Test
    if (IsEqual(order[OP_SELL].Count,0))
      if (Close[0]>18.09)
      {
        eRequest.Pend.Type       = OP_SELLSTOP;
        eRequest.Pend.Limit      = 17.982;
        eRequest.Pend.Step       = 2;
        eRequest.Pend.Cancel     = 18.112;
        eRequest.Type            = OP_SELLLIMIT;
        eRequest.Price           = 0.00;
        eRequest.TakeProfit      = 18.12;
        eRequest.Price           = 17.982;
        eRequest.Expiry          = TimeCurrent()+(Period()*(60*2));
     
        order.Submitted(eRequest);
//        order.PrintLog();
//        Print(order.QueueStr());
      }      
  }

//+------------------------------------------------------------------+
//| Duplicate EA request management                                  |
//+------------------------------------------------------------------+
void Test4(void)
  {
    OrderRequest eRequest   = order.BlankRequest();
    
    eRequest.Requestor      = "Test[4] Dups";
    eRequest.Memo           = "Test 4-Lotsa Dups";
    
    order.SetRiskLimits(OP_BUY,80,80,2);
      
    //--- Queue Order Test
    if (Tick<20)
    {
      eRequest.Pend.Type       = OP_SELLSTOP;
      eRequest.Pend.Limit      = 17.75;
      eRequest.Pend.Step       = 2;
      eRequest.Pend.Cancel     = 18.20;
      eRequest.Type            = OP_SELLLIMIT;
      eRequest.TakeProfit      = 18.12;
      eRequest.Price           = 17.982;
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*12));
     
      order.Submitted(eRequest);
    }
  }

//+------------------------------------------------------------------+
//| Margin management                                                |
//+------------------------------------------------------------------+
void Test5(void)
  {
    OrderRequest eRequest   = order.BlankRequest();
    
    eRequest.Requestor      = "Test[5] Margin";
    
    
    order.SetRiskLimits(OP_BUY,80,80,2);
    order.SetRiskLimits(OP_SELL,80,80,5);
      
    //--- Queue Order Test
    if (Tick<4)
    {
      //eRequest.Pend.Type       = OP_SELLSTOP;
      //eRequest.Pend.Limit      = 17.75;
      //eRequest.Pend.Step       = 2;
      //eRequest.Pend.Cancel     = 18.20;
      eRequest.Type            = OP_BUY;
      eRequest.TakeProfit      = 18.12;
      eRequest.Price           = 17.982;
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*12));
    }
    else
    if (Tick<8)
    {
      //eRequest.Pend.Type       = OP_SELLSTOP;
      //eRequest.Pend.Limit      = 17.75;
      //eRequest.Pend.Step       = 2;
      //eRequest.Pend.Cancel     = 18.20;
      eRequest.Type            = OP_SELL;
      eRequest.TakeProfit      = 18.12;
      eRequest.Price           = 17.982;
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*12));     
    }
    
    eRequest.Memo           = "Margin "+DoubleToStr(order.Margin(InPercent),1)+"%";
    order.Submitted(eRequest);
  }

//+------------------------------------------------------------------+
//| Request Fulfilled/Reject/Expired signals                         |
//+------------------------------------------------------------------+
void Test6(void)
  {
    OrderRequest eRequest   = order.BlankRequest();
    
    eRequest.Requestor      = "Test[6] Margin";
    
    
    order.SetRiskLimits(OP_BUY,80,80,2);
    order.SetRiskLimits(OP_SELL,80,80,5);
      
    //--- Queue Order Test
    if (Tick<4)
    {
      //eRequest.Pend.Type       = OP_SELLSTOP;
      //eRequest.Pend.Limit      = 17.75;
      //eRequest.Pend.Step       = 2;
      //eRequest.Pend.Cancel     = 18.20;
      eRequest.Type            = OP_BUYLIMIT;
      eRequest.TakeProfit      = 18.12;
      eRequest.Price           = 17.892;
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*12));
    }
    else
    if (Tick<8)
    {
      //eRequest.Pend.Type       = OP_SELLSTOP;
      //eRequest.Pend.Limit      = 17.75;
      //eRequest.Pend.Step       = 2;
      //eRequest.Pend.Cancel     = 18.20;
      eRequest.Type            = OP_SELLLIMIT;
      eRequest.TakeProfit      = 18.12;
      eRequest.Price           = 18.14;
      eRequest.Expiry          = TimeCurrent()+(Period()*(60*12));     
    }
    
    eRequest.Memo           = "Margin "+DoubleToStr(order.Margin(InPercent),1)+"%";
    order.Submitted(eRequest);
    
    if (order.Pending())
      order.PrintSnapshotStr();

    if (order.Fulfilled(OP_BUY))
      Print(order.QueueStr());
      
    if (order.Rejected())
      Print(order.QueueStr());
      
    if (order.Expired(OP_SELL))
      Print(order.QueueStr());
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    #define Test 2

    Comment("Tick: "+(string)++Tick);
    
    switch (Test)
    {
      case 1:  Test1();
               break;
      case 2:  Test2();
               break;
      case 3:  Test3();
               break;
      case 4:  Test4();
               break;
      case 5:  Test5();
               break;
      case 6:  Test6();
               break;
    }
    
//    if (order[OP_BUY].Count>0)
//      Print(order.QueueStr());

    order.Execute(Tickets,true);

//    if (Tick==5) Print (">>>After:"+order.OrderStr());
    
    //if (order.Fulfilled())
    //{
    //  Print(order.OrderStr());
    //  if (order[OP_BUY].Count>0)
    //order.PrintLog();
    //  Print(order.ZoneSummaryStr());
    //}
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ChartEventObjectClick(string &Command[])
  {
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
    //-- MouseEvents
    ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,1);
    
    ManualInit();
    
    order.Enable();
    
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      order.Enable(action);
      order.SetEquityTargets(action,inpMinTarget,inpMinProfit);
      order.SetRiskLimits(action,inpMaxRisk,inpMaxMargin,inpLotFactor);
      order.SetDefaults(action,inpLotSize,inpDefaultStop,inpDefaultTarget);
      order.SetZoneStep(action,2.5,60.0);
    }
    
    NewLine("czDCA:0");

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

//+------------------------------------------------------------------+
//| MouseState                                                       |
//+------------------------------------------------------------------+
string MouseState(uint state)
  {
   string res;
   res+="\nML: "   +(((state& 1)== 1)?"DN":"UP");   // mouse left
   res+="\nMR: "   +(((state& 2)== 2)?"DN":"UP");   // mouse right 
   res+="\nMM: "   +(((state&16)==16)?"DN":"UP");   // mouse middle
   res+="\nMX: "   +(((state&32)==32)?"DN":"UP");   // mouse first X key
   res+="\nMY: "   +(((state&64)==64)?"DN":"UP");   // mouse second X key
   res+="\nSHIFT: "+(((state& 4)== 4)?"DN":"UP");   // shift key
   res+="\nCTRL: " +(((state& 8)== 8)?"DN":"UP");   // control key
   return(res);
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   Print("Got Here");
   if(id==CHARTEVENT_OBJECT_CLICK)
      Comment("POINT: ",(int)lparam,",",(int)dparam,"\n",MouseState((uint)sparam));
  }