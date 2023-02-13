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
#include <Class/TickMA.mqh>
#include <Class/Order.mqh>
#include <Class/Session.mqh>

#define   NoManager     NoAction

enum ManagerState
     {
       Buy,
       Sell,
       Wait,
       Hedge,
       ManagerStates
     };

struct ManagerDetail
       {
         ManagerState  State;
         double        DCA;
         FiboLevel     Level;
         OrderSummary  Zone;
         bool          Hedge;
       };

struct ManagerMaster
       {
         int           Lead;
         ManagerDetail Manager[2];
         PivotRec      Main;
         bool          Hedge;
       };

//--- Configuration
input string           appHeader          = "";          // +--- Application Config ---+
input BrokerModel      inpBrokerModel     = Discount;    // Broker Model
input double           inpZoneStep        = 2.5;         // Zone Step (pips)
input double           inpMaxZoneMargin   = 5.0;         // Max Zone Margin


//--- Regression parameters
input string           regrHeader         = "";          // +--- Regression Config ----+
input int              inpPeriods         = 80;          // Retention
input int              inpDegree          = 6;           // Poly Regression Degree
input double           inpAgg             = 2.5;         // Tick Aggregation


//--- Session Inputs
input string           sessHeader        = "";           // +--- Session Config -------+
input SessionType      inpShowFractal    = Daily;        // Display Session Fractal
input int              inpAsiaOpen       = 1;            // Asia Session Opening Hour
input int              inpAsiaClose      = 10;           // Asia Session Closing Hour
input int              inpEuropeOpen     = 8;            // Europe Session Opening Hour
input int              inpEuropeClose    = 18;           // Europe Session Closing Hour
input int              inpUSOpen         = 14;           // US Session Opening Hour
input int              inpUSClose        = 23;           // US Session Closing Hour
input int              inpGMTOffset      = 0;            // Offset from GMT+3

  CTickMA             *t                 = new CTickMA(inpPeriods,inpDegree,inpAgg);
  COrder              *order             = new COrder(inpBrokerModel,Hold,Hold);
  CSession            *s[SessionTypes];
  
  ManagerMaster        master;

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string        text                    = "";

    Append(text,"*----------- Main [Origin] Pivot ----------------*");
    Append(text,s[Daily].PivotStr("Main",master.Main)+"\n\n","\n");
    
    if (inpShowFractal==Daily)
      Append(text,s[inpShowFractal].FractalStr(5));

    Append(text,s[Daily].ActiveEventStr(),"\n\n");

    Comment(text);
  }

//+------------------------------------------------------------------+
//| UpdateMaster - Updates Master/Manager data                       |
//+------------------------------------------------------------------+
void UpdateMaster(void)
  {
    //-- Update Classes
    for (SessionType type=Daily;type<SessionTypes;type++)
      s[type].Update();

    order.Update();
    t.Update();

    master.Lead                       = Action(s[Daily][Origin].Direction,InDirection);
    
    //-- Handle Main [Origin-Level/Macro] Events
    if (s[Daily].Event(NewBreakout,Critical)||s[Daily].Event(NewReversal,Critical))
      master.Main                     = s[Daily].Pivot();
    else UpdatePivot(master.Main,s[Daily][Origin].Direction);

    for (int action=Buy;IsBetween(action,Buy,Sell);action++)
    {
      master.Manager[action].DCA      = order.DCA(action);
      master.Manager[action].Zone     = order.Entry(action);
      master.Manager[action].Level    = Level(Retrace(s[Daily][Origin].Point[fpRoot],s[Daily][Origin].Point[fpExpansion],master.Manager[action].DCA));
    }
  }

//+------------------------------------------------------------------+
//| ManageOrders - Lead Manager order processor                      |
//+------------------------------------------------------------------+
void ManageOrders(int Manager)
  {
    OrderRequest request = order.BlankRequest(BoolToStr(IsEqual(Manager,Buy),"Purchasing","Sales"));
    
    if (order.Free(Manager)>order.Split(Manager)||IsEqual(order.Entry(Manager).Count,0))
      switch (Manager)
      {
        case Buy:          //request.Type    = OP_BUY;
                           request.Memo    = "Long Manager";
                           break;
      }

    if (IsBetween(request.Type,OP_BUY,OP_SELLSTOP))
      if (order.Submitted(request))
        Print ("Yay");
      else
        order.PrintLog();
  }

//+------------------------------------------------------------------+
//| ManageRisk - Risk Manager order processor and risk mitigation    |
//+------------------------------------------------------------------+
void ManageRisk(int Manager)
  {
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    //-- Handle Active Management
    if (IsBetween(master.Lead,Buy,Sell))
    {
      ManageOrders(master.Lead);
      ManageRisk(Action(master.Lead,InAction,InContrarian));
    }
    else
    
    //-- Handle Unassigned Manager
    {
      ManageRisk(Buy);
      ManageRisk(Sell);
    }

    order.ExecuteOrders(Buy);
    order.ExecuteOrders(Sell);

    order.ExecuteRequests();
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
  
    UpdateMaster();

    InitializeTick();
    GetManualRequest();

    while (AppCommand(otParams,6))
      ExecAppCommands(otParams);

    OrderMonitor(Mode());

    if (Mode()==Auto)
      Execute();

    RefreshScreen();    
    ReconcileTick();        
  }

//+------------------------------------------------------------------+
//| OrderConfig Order class initialization function                  |
//+------------------------------------------------------------------+
void OrderConfig()
  {
    order.Enable();

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
      if (order[action].Lots>0)
        order.Disable(action,"Open Positions Detected; Preparing execution plan");
      else
        order.Enable(action,"System started "+TimeToString(TimeCurrent()));

      //-- Order Config
      order.SetDefaults(action,inpLotSize,inpDefaultStop,inpDefaultTarget);
      order.SetEquityTargets(action,inpMinTarget,inpMinProfit);
      order.SetRiskLimits(action,inpMaxRisk,inpMaxMargin,inpLotFactor);
      order.SetZoneLimits(action,inpZoneStep,inpMaxZoneMargin);
      order.SetDefaultMethod(action,Hold);
    }
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    ManualInit();
    OrderConfig();
   
    //-- Initialize Session
    s[Daily]        = new CSession(Daily,0,23,inpGMTOffset,Always);
    s[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    s[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    s[US]           = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);

    master.Main     = s[Daily].Pivot(Breakout,0,Max);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete t;
    delete order;
    delete s[Daily];
  }
