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

enum OrderCommand
     {
       Buy,             //-- Purchase Manager
       Sell,            //-- Sales Manager
       Hedge,
       Cover,
       Capture,
       Wait
     };

struct ManagerDetail
       {
         OrderCommand  Command;
         double        DCA;
         FiboLevel     Level;
         OrderSummary  Entry;
         bool          Hold;
       };

struct ManagerMaster
       {
         int           Director;                        //-- Principal Manager (Action)
         OrderCommand  Directive;                       //-- Fractal level determination
         int           Lead;                            //-- Confirmed [Bias] 
         int           Bias;                            //-- Active [Bias]
         ManagerDetail Manager[2]; 
         PivotRec      Pivot;
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
  ManagerMaster        legacy;

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string        text                    = "";

    //-- Update M3 Indicators
    UpdateDirection("[m3]Lead",Direction(legacy.Lead,InAction),Color(Direction(legacy.Lead,InAction)),12);
    UpdateDirection("[m3]Bias",Direction(legacy.Bias,InAction),Color(Direction(legacy.Bias,InAction)),24);

    UpdateLabel("[m3]ActivePivot",EnumToString(s[Daily].Pivot().State)+" ["+DoubleToStr(s[Daily].Pivot().Open,Digits)+"] "+
                                  DoubleToStr(pip(Close[0]-s[Daily].Pivot().Open),1),Color(Close[0]-s[Daily].Pivot().Open),12);
    UpdateLabel("[m3]MasterPivot",EnumToString(master.Pivot.State)+" ["+DoubleToStr(master.Pivot.Open,Digits)+"] "+
                                  DoubleToStr(pip(Close[0]-master.Pivot.Open),1),Color(Close[0]-master.Pivot.Open),12);

    //-- Update Comment
    Append(text,"*----------- Main [Origin] Pivot ----------------*");
    Append(text,s[Daily].PivotStr("Main",master.Pivot)+"\n\n","\n");
    
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
    
    //-- Handle Main [Origin-Level/Macro] Events
    if (s[Daily].Event(NewBreakout,Critical)||s[Daily].Event(NewReversal,Critical))
    {
      master.Director                   = Action(s[Daily][Origin].Direction);
      master.Pivot                      = s[Daily].Pivot();
    }
    else 
    {
      if (s[Daily][NewCorrection])
        master.Director                 = Action(s[Daily][Origin].Direction,InDirection,InContrarian);

      UpdatePivot(master.Pivot,s[Daily][Origin].Direction);
    }

    if (t[NewTick])
    {
      master.Hedge                      = !IsEqual(s[Daily][Origin].Bias,s[Daily][Origin].Lead);
    }

    //-- Set Master Command
    if (t[NewSegment])
    {
    };

    for (int role=Buy;IsBetween(role,Buy,Sell);role++)
    {
      master.Manager[role].Command = Wait;
      master.Manager[role].DCA     = order.DCA(role);
      master.Manager[role].Entry   = order.Entry(role);
      master.Manager[role].Level   = Level(Retrace(s[Daily][Origin].Point[fpRoot],s[Daily][Origin].Point[fpExpansion],master.Manager[role].DCA));
    }
  }

//+------------------------------------------------------------------+
//| ManageOrders - Lead Manager order processor                      |
//+------------------------------------------------------------------+
void ManageOrders(int Role)
  {
    OrderRequest  request    = order.BlankRequest(BoolToStr(IsEqual(Role,Buy),"Purchase","Sales"));
    ManagerDetail manager    = master.Manager[Role];

    //--- R1: Free Zone?
    if (order.Free(Role)>order.Split(Role)||IsEqual(order.Entry(Role).Count,0))
    {
      request.Action         = Role;
      request.Requestor      = "Auto Open ("+request.Requestor+")";
      
      switch (Role)
      {
        case Buy:          break;
        case Sell:         break;
      }
    }

    if (IsBetween(request.Type,OP_BUY,OP_SELLSTOP))
      if (!order.Submitted(request))
        order.PrintLog();
        
    order.ExecuteOrders(Role,manager.Hold);
  }

//+------------------------------------------------------------------+
//| ManageRisk - Risk Manager order processor and risk mitigation    |
//+------------------------------------------------------------------+
void ManageRisk(int Manager)
  {
    order.ExecuteOrders(Manager);
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    //-- Handle Active Management
    if (IsBetween(master.Director,Buy,Sell))
    {
      ManageOrders(master.Director);
      ManageRisk(Action(master.Director,InAction,InContrarian));
    }
    else
    
    //-- Handle Unassigned Manager
    {
      ManageRisk(Buy);
      ManageRisk(Sell);
    }

    order.ExecuteRequests();
  }

//+------------------------------------------------------------------+
//| ExecuteLegacy -                                                  |
//+------------------------------------------------------------------+ 
void ExecuteLegacy(void)
    {
      OrderMonitor(Mode());
      bool bias, lead;

      if (t[NewTick])
      {
        bias   = NewAction(legacy.Bias,Action(t.SMA().Close[1]-t.SMA().Open[1]));
        lead   = NewAction(legacy.Lead,BoolToInt(IsEqual(legacy.Bias,Action(t.Poly().Close[1]-t.Poly().Open[1])),legacy.Bias,legacy.Lead));
        
        if ((bias&&lead))
          if (IsEqual(legacy.Bias,legacy.Lead))
            Pause("Director Change: "+EnumToString((OrderCommand)legacy.Director)+"\n"+
                  "   Bias: "+EnumToString((OrderCommand)legacy.Bias)+"\n"+
                  "   Lead: "+EnumToString((OrderCommand)legacy.Lead),"New Director");
          else Print("Hmmm, mismatch lead/bias");
        else
        if (bias)
          Pause("Bias Change: "+EnumToString((OrderCommand)legacy.Bias),"New Bias");
        else
          Pause("Lead Change: "+EnumToString((OrderCommand)legacy.Lead),"New Lead");
      }
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

    if (Mode()==Legacy)
      ExecuteLegacy();

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

    master.Pivot    = s[Daily].Pivot(Breakout,0,Max);
    
    DrawBox("[m3]Stat",496,1,240,80,C'0,0,60',BORDER_FLAT);

    NewLabel("[m3]Bias","^",500,5,clrLawnGreen);
    NewLabel("[m3]Lead","^",520,5,clrLawnGreen);

    NewLabel("[m3]ActivePivot","Active",540,15,clrLawnGreen);
    NewLabel("[m3]MasterPivot","Master",540,40,clrLawnGreen);

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
