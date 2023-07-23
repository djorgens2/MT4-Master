//+------------------------------------------------------------------+
//|                                                       man-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict

#include <Class/Order.mqh>
#include <Class/Session.mqh>
#include <Class/TickMA.mqh>

#define   NoManager     NoAction

  //--- Configuration
  input string           appHeader          = "";          // +--- Application Config ---+
  input BrokerModel      inpBrokerModel     = Discount;    // Broker Model

  //---- Extern Variables
  input string           ordHeader           = "";         // +----- Order Options -----+
  input double           inpMinTarget        = 5.0;        // Equity% Target
  input double           inpMinProfit        = 0.8;        // Minimum take profit%
  input double           inpMaxRisk          = 50.0;       // Maximum Risk%
  input double           inpMaxMargin        = 60.0;       // Maximum Open Margin
  input double           inpLotFactor        = 2.00;       // Scaling Lotsize Balance Risk%
  input double           inpLotSize          = 0.00;       // Lotsize Override
  input int              inpDefaultStop      = 50;         // Default Stop Loss (pips)
  input int              inpDefaultTarget    = 50;         // Default Take Profit (pips)
  input double           inpZoneStep         = 2.5;        // Zone Step (pips)
  input double           inpMaxZoneMargin    = 5.0;        // Max Zone Margin

  //--- Regression parameters
  input string           regrHeader         = "";           // +--- Regression Config ----+
  input int              inpPeriods         = 80;           // Retention
  input int              inpDegree          = 6;            // Poly Regression Degree
  input double           inpAgg             = 2.5;          // Tick Aggregation


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


  string  indSN      = "CPanel-v2";

  enum    StrategyType
          {
            Opener,          //-- New Position (Opener)
            Build,           //-- Increase Position
            Hedge,           //-- Contrarian drawdown management
            Cover,           //-- Aggressive balancing on excessive drawdown
            Capture,         //-- Contrarian profit protection
            Mitigate,        //-- Risk management on pattern change
            Defer,           //-- Defer to contrarian manager
            Wait             //-- Hold, wait for signal
          };

  enum    ResponseType
          {   
            Breakaway,       //-- Breakout Response
            CrossCheck,      //-- Cross Check for SMA, Poly, TL, et al
            Trigger,         //-- Event Triggering Action
            Review           //-- Reviewable event
          };

  enum    RoleType
          {
            Buyer,           //-- Purchasing Manager
            Seller,          //-- Selling Manager
            Unnassigned,     //-- No Manager
            ManagerTypes
          };

  struct  ManagerRec
          {
            StrategyType     Strategy;     //-- Role Responsibility/Strategy
            double           DCA;           //-- Role DCA
            OrderSummary     Entry;         //-- Role Entry Zone Summary
            bool             Hold;          //-- Hold Role Profit
          };

  struct  SignalRec
          {
            FractalState     State;
            EventType        Event;
            AlertType        Alert;
            int              Direction;
            int              Lead;
            int              Bias;
            double           Price;
            string           Text;
            ResponseType     Response;
            bool             Fired;
            datetime         Updated;
            datetime         Resolved;
          };

  struct  MasterRec
          {
            RoleType         Lead;        //-- Process Manager (Owner|Lead)
            bool             Hold;        //-- Manager hold state
          };

  COrder                *order;
  CSession              *s;
  CTickMA               *t;
  
  MasterRec            master;
  SignalRec            signal;
  ManagerRec           manager[ManagerTypes];             //-- Manager Detail Data

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string        text                    = "";

    //-- Update Comment
//    Append(text,"*----------- Master Fractal Pivots ----------------*");
//    Append(text,"Fractal "+EnumToString(master.Fractal),"\n");
//    Append(text,EnumToString(master.State));
//    Append(text,EnumToString(master.Director));
//    Append(text,s[Daily].PivotStr("Lead",master.Pivot),"\n");
//
//    for (FractalType type=Origin;IsBetween(type,Origin,Term);type++)
//      Append(text,s[Daily].PivotStr(EnumToString(type),s[Daily].Pivot(type)),"\n");
//
//    if (inpShowFractal==Daily)
//      Append(text,s[inpShowFractal].FractalStr(5),"\n\n");
//
//    Append(text,"Daily "+s[Daily].ActiveEventStr(),"\n\n");
//    Append(text,"Tick "+t.ActiveEventStr(),"\n\n");
//
    Comment(text);
  }

//+------------------------------------------------------------------+
//| UpdatePanel - Updates control panel display                      |
//+------------------------------------------------------------------+
void UpdatePanel(void)
  {
    static FractalType fractal   = Prior;
    static int         winid     = NoValue;

    //-- Update Control Panel (Application)
    if (IsChanged(winid,ChartWindowFind(0,indSN)))
      order.ConsoleAlert("Connected to "+indSN+"; System "+BoolToStr(order.Enabled(),"Enabled","Disabled")+" on "+TimeToString(TimeCurrent()));

    //if (winid>NoValue)
    //  if (IsChanged(fractal,master.Fractal))
    //    UpdateLabel("lbhFractal",EnumToString(master.Fractal),Color(s[Daily][master.Fractal].Direction));
  }

//+------------------------------------------------------------------+
//| SetStrategy - Sets the Manager Strategy                          |
//+------------------------------------------------------------------+
void SetStrategy(void)
  {
//    FractalState strategy        = NoState;
//
//    if (IsEqual(Close[0],s[Daily][Origin].Point[fpExpansion]))
//    {
//      //-- Do Breakout
//      strategy                 = Breakout;
//    }
//    else
//    if (IsEqual(Close[0],s[Daily][Origin].Point[fpRetrace]))
//    {
//      //-- Do Retrace
//      strategy                 = Retrace;
//    }
//    else
//    if (IsEqual(Close[0],s[Daily][Origin].Point[fpRecovery]))
//    {
//      //-- Do Recovery
//      strategy                 = Recovery;
//    }
//    else
//    if (s[Daily].Retrace(Origin,Max)>FiboCorrection)
//    {
//      //-- Do Correction
//      strategy                 = Correction;
//    }
//
//    if (NewState(master.State,strategy))
//      Flag("New State "+EnumToString(strategy),clrYellow);
  }

//+------------------------------------------------------------------+
//| Manager - Returns the manager for the supplied Fractal           |
//+------------------------------------------------------------------+
RoleType Manager(FractalRec &Fractal)
  {
    return (RoleType)BoolToInt(IsEqual(Fractal.State,Correction),Action(Fractal.Direction,InDirection,InContrarian),Action(Fractal.Direction));
  }


//+------------------------------------------------------------------+
//| UpdateMaster - Updates Master/Manager data                       |
//+------------------------------------------------------------------+
void UpdateMaster(void)
  {
    //-- Update Classes
    s.Update();
    order.Update();
    
    //-- Handle Main [Origin-Level/Macro] Events
    master.Lead                  = Manager(s.Fractal(Term));

    for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
    {
      manager[role].Strategy     = Wait;
      manager[role].DCA          = order.DCA(role);
      manager[role].Entry        = order.Entry(role);
    }
  }

//+------------------------------------------------------------------+
//| UpdateSignal - Updates Signal detail on Tick                     |
//+------------------------------------------------------------------+
void UpdateSignal(CSession &Signal)
  {
    SignalRec alert;

    InitSignal(alert);

    for (EventType event=NewRally;IsBetween(event,NewRally,NewExtension);event++)
      if (Signal[event])
      {
        alert.State           = Signal.State(event);
        alert.Event           = event;
        alert.Alert           = Signal.Alert(event);
      }

    if (alert.Event>NoEvent)
    {
    }
  }

//+------------------------------------------------------------------+
//| ManageOrders - Lead Manager order processor                      |
//+------------------------------------------------------------------+
void ManageOrders(RoleType Role)
  {
    OrderRequest  request    = order.BlankRequest(EnumToString(Role));

    //--- R1: Free Zone?
    if (order.Free(Role)>order.Split(Role)||IsEqual(order.Entry(Role).Count,0))
    {
      request.Action         = Role;
      request.Requestor      = "Auto Open ("+request.Requestor+")";
      
      switch (Role)
      {
        case Buyer:          break;
        case Seller:         break;
      }
    }

    if (IsBetween(request.Type,OP_BUY,OP_SELLSTOP))
      if (!order.Submitted(request))
        order.PrintLog();
        
    order.ExecuteOrders(Role,manager[Role].Hold);
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
    if (IsBetween(master.Lead,Buyer,Seller))
    {
      ManageOrders(master.Lead);
      ManageRisk(Action(master.Lead,InAction,InContrarian));
    }
    else
    
    //-- Handle Unassigned Manager
    {
      ManageRisk(Buyer);
      ManageRisk(Seller);
    }

    order.ExecuteRequests();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
      UpdateTick();
//    UpdateMaster();
//    UpdateSignal(s);
//    UpdatePanel();
//
//    Execute();
  }

//+------------------------------------------------------------------+
//| UpdateTick - Updates TickMA + visuals                            |
//+------------------------------------------------------------------+
void UpdateTick()
  {
    FractalType show = Origin;

    t.Update();

    UpdateRay("[man-v2]lnS_Origin:"+EnumToString(show),inpPeriods,t[show].Fractal[fpOrigin],-8);
    UpdateRay("[man-v2]lnS_Base:"+EnumToString(show),inpPeriods,t[show].Fractal[fpBase],-8);
    UpdateRay("[man-v2]lnS_Root:"+EnumToString(show),inpPeriods,t[show].Fractal[fpRoot],-8,0,
                           BoolToInt(IsEqual(t[show].Direction,DirectionUp),clrRed,clrLawnGreen));
    UpdateRay("[man-v2]lnS_Expansion:"+EnumToString(show),inpPeriods,t[show].Fractal[fpExpansion],-8,0,
                           BoolToInt(IsEqual(t[show].Direction,DirectionUp),clrLawnGreen,clrRed));
    UpdateRay("[man-v2]lnS_Retrace:"+EnumToString(show),inpPeriods,t[show].Fractal[fpRetrace],-8,0);
    UpdateRay("[man-v2]lnS_Recovery:"+EnumToString(show),inpPeriods,t[show].Fractal[fpRecovery],-8,0);

    for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
    {
      UpdateRay("[man-v2]lnS_"+EnumToString(fibo)+":"+EnumToString(show),inpPeriods,t.Price(fibo,show,Extension),-8,0,Color(t[show].Direction,IN_DARK_DIR));
      UpdateText("[man-v2]lnT_"+EnumToString(fibo)+":"+EnumToString(show),"",t.Price(fibo,show,Extension),-5,Color(t[show].Direction,IN_DARK_DIR));
    }

    for (FractalPoint point=fpBase;IsBetween(point,fpBase,fpRecovery);point++)
      UpdateText("[man-v2]lnT_"+fp[point]+":"+EnumToString(show),"",t[show].Fractal[point],-6);
  }

//+------------------------------------------------------------------+
//| TickConfig TickMA configuration                                  |
//+------------------------------------------------------------------+
void TickConfig()
  {
    FractalType show   = Origin;

    t                  = new CTickMA(inpPeriods,inpAgg,Origin);

    NewRay("[man-v2]lnS_Origin:"+EnumToString(show),STYLE_DOT,clrWhite,Never);
    NewRay("[man-v2]lnS_Base:"+EnumToString(show),STYLE_SOLID,clrYellow,Never);
    NewRay("[man-v2]lnS_Root:"+EnumToString(show),STYLE_SOLID,clrDarkGray,Never);
    NewRay("[man-v2]lnS_Expansion:"+EnumToString(show),STYLE_SOLID,clrDarkGray,Never);
    NewRay("[man-v2]lnS_Retrace:"+EnumToString(show),STYLE_DOT,clrGoldenrod,Never);
    NewRay("[man-v2]lnS_Recovery:"+EnumToString(show),STYLE_DOT,clrSteelBlue,Never);

    for (FractalPoint point=fpBase;IsBetween(point,fpBase,fpRecovery);point++)
      NewText("[man-v2]lnT_"+fp[point]+":"+EnumToString(show),fp[point]);

    for (FibonacciType fibo=Fibo161;fibo<FibonacciTypes;fibo++)
    {
      NewRay("[man-v2]lnS_"+EnumToString(fibo)+":"+EnumToString(show),STYLE_DOT,clrDarkGray,Never);
      NewText("[man-v2]lnT_"+EnumToString(fibo)+":"+EnumToString(show),DoubleToStr(fibonacci[fibo]*100,1)+"%");
    }
  }

//+------------------------------------------------------------------+
//| OrderConfig Order class initialization function                  |
//+------------------------------------------------------------------+
void OrderConfig()
  {
    order = new COrder(inpBrokerModel,Hold,Hold);
    order.Enable("System Enabled "+TimeToString(TimeCurrent()));

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
      if (order[action].Lots>0)
        order.Disable(action,"Open "+proper(ActionText(action))+" Positions; Preparing execution plan");
      else
        order.Enable(action,"Action Enabled "+TimeToString(TimeCurrent()));

      //-- Order Config
      order.SetDefaults(action,inpLotSize,inpDefaultStop,inpDefaultTarget);
      order.SetEquityTargets(action,inpMinTarget,inpMinProfit);
      order.SetRiskLimits(action,inpMaxRisk,inpMaxMargin,inpLotFactor);
      order.SetZoneLimits(action,inpZoneStep,inpMaxZoneMargin);
      order.SetDefaultMethod(action,Hold);
    }
  }

//+------------------------------------------------------------------+
//| InitSignal - Inits a FractalRec for supplied Signal              |
//+------------------------------------------------------------------+
void InitSignal(SignalRec &Signal)
  {
    Signal.State       = NoState;
    Signal.Event       = NoEvent;
    Signal.Alert       = NoAlert;
    Signal.Direction   = NoDirection;
    Signal.Lead        = NoManager;
    Signal.Bias        = NoBias;
    Signal.Price       = NoValue;
    Signal.Text        = "";
    Signal.Price       = Close[0];
    Signal.Response    = Review;
    Signal.Fired       = false;
    Signal.Updated     = TimeCurrent();
    Signal.Resolved    = NoValue;
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    datetime time      = NoValue;

    OrderConfig();
    TickConfig();
   
    //-- Initialize Session
    s                  = new CSession(Daily,0,23,inpGMTOffset);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete order;
    delete s;
    delete t;
  }
