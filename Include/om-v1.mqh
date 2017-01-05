//+------------------------------------------------------------------+
//|                                                        om-v1.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property strict

#include <order.mqh>

  //--- Order Manager
  bool          omAlert[AlertCount];                                //--- Order Manager monitored alerts 
  AlertRecord   omAlertLog[];                                       //--- Order Manager active alerts
  OpenOptions   omOpenOption                = OpenSingle;           //--- Order Manager lot size
  double        omNormalSpread              = Spread();             //--- Normal spread used to derive order fibo levels
  double        omTrailPips                 = 0.00;

/*
//+------------------------------------------------------------------+
//| OrderManagement - Executes new orders                            |
//+------------------------------------------------------------------+
void OrderManagement(void)
  {
    ProcessAlert(omAlertLog, omAlert);
    
    if (OrderPending())
    {
      if (ActiveAlert(alAlertLog, pfTermDir))
        ClosePendingOrders();
    }
    
    if (ActiveAlert(omAlertLog))
    {
      if (ActiveAlert(omAlertLog,StdDev161))
        if (alTradeDir!=omAlertLog[AlertIndex(omAlertLog,StdDev161)].Direction)
        {
          SetActionHold(DirAction(omAlertLog[AlertIndex(omAlertLog,StdDev161)].Direction,InContrarian));
          CloseAlert(omAlertLog,StdDev161);
        }

      if (ActionHold(OP_BUY))
        if (Close[0]>trend.Trendline(Head))
          SetActionHold(OP_NO_ACTION);
          
      if (ActionHold(OP_SELL))
        if (Close[0]<trend.Trendline(Head))
          SetActionHold(OP_NO_ACTION);
          
      if (alTradeDir!=pfractal[Term].Direction)
        if (Authorized(PipMATradeAction))
        {
          if (alTradeAction == OP_BUY)
            OpenMITOrder(OP_BUY,Ask,pfractal.Range(Bottom)+omNormalSpread,LotSize(),omNormalSpread,"Auto-MIT(PTA)");
          
          if (alTradeAction == OP_SELL)
            OpenMITOrder(OP_SELL,Ask,pfractal.Range(Top),LotSize(),omNormalSpread,"Auto-MIT(PTA)");

          CloseAlert(omAlertLog,PipMATradeAction);
        }

      if (ActiveAlert(omAlertLog,pfTermFibo))
        if (Authorized(pfTermFibo))
        {
          if (pfractal.Fibonacci(Term,pfractal.Direction(Term),Expansion,Now)>FiboPercent(omAlertLog[AlertIndex(omAlertLog,pfTermFibo)].FiboLevel))
          {      
            //--- Process Short actions
            if (alTradeAction==OP_SELL)
              OpenLimitOrder(OP_SELL,Bid+omNormalSpread,0.00,0.00,omTrailPips,"Auto-InRange-Sell");

            //--- Process Long actions      
            if (alTradeAction==OP_BUY)
              OpenLimitOrder(OP_BUY,Ask-omNormalSpread,0.00,0.00,omTrailPips,"Auto-InRange-Buy");
          }
          else
          {      
            //--- Process Short actions
            if (alTradeAction==OP_SELL)
              OpenLimitOrder(OP_SELL,omAlertLog[AlertIndex(omAlertLog,pfTermFibo)].Price+omNormalSpread,0.00,0.00,omTrailPips,"Auto-OutRange-Sell");

            //--- Process Long actions      
            if (alTradeAction==OP_BUY)
              OpenLimitOrder(OP_BUY,omAlertLog[AlertIndex(omAlertLog,pfTermFibo)].Price-(omNormalSpread*2),0.00,0.00,omTrailPips,"Auto-OutRange-Buy");
          }

          if (OrderPending())
            CloseAlert(omAlertLog,pfTermFibo);
        }
    }      
  }
*/
//+------------------------------------------------------------------+
//| OrderManagement - Executes new orders                            |
//+------------------------------------------------------------------+
void OrderManagement(void)
  {
    ProcessAlert(omAlertLog, omAlert);
    
    if (OrderPending())
    {
      if (ActiveAlert(alAlertLog, pfTermDir))
        ClosePendingOrders();
    }
    
    if (ActiveAlert(omAlertLog))
    {
      //--- Sets action holds
      if (ActiveAlert(omAlertLog,StdDev161))
        if (alTradeDir!=omAlertLog[AlertIndex(omAlertLog,StdDev161)].Direction)
        {
          SetActionHold(DirAction(omAlertLog[AlertIndex(omAlertLog,StdDev161)].Direction,InContrarian));
          CloseAlert(omAlertLog,StdDev161);
        }

      if (ActionHold(OP_BUY))
        if (Close[0]>trend.Trendline(Head))
          SetActionHold(OP_NO_ACTION);
          
      if (ActionHold(OP_SELL))
        if (Close[0]<trend.Trendline(Head))
          SetActionHold(OP_NO_ACTION);          
    }      
    
    //--- Start Trading
    if (ActiveAlert(alAlertLog,PipMATradeState))
    {
      if (alTradeAction==OP_BUY)
        OpenLimitOrder(OP_BUY,Ask,0.00,0.00,omNormalSpread,"Auto");

      if (alTradeAction==OP_SELL)
        OpenLimitOrder(OP_SELL,Bid,0.00,0.00,omNormalSpread,"Auto");
    }
  }

//+------------------------------------------------------------------+
//| InitOrderManagement - initialize alert subscriptions for OM      |
//+------------------------------------------------------------------+
void InitOrderManagement(void)
  {
    ArrayInitialize(omAlert,false);
    
//    SetAlert(omAlert,pfTermDir,true);
//    SetAlert(omAlert,pfTermFibo,true);
//      SetAlert(omAlert,FiboTradeAction,true);
      SetAlert(omAlert,StdDev161,true);
      SetAlert(omAlert,PipMATradeAction,true);
  }

