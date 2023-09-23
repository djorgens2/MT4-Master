//+------------------------------------------------------------------+
//|                                                   dj-live-v1.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.50"
#property strict

#include <ordman.mqh>

//--- App Configuration
input string           appHeader           = "";            // +--- Application Config ---+
input BrokerModel      inpBrokerModel      = Discount;      // Broker Model
input string           inpComFile          = "manual.csv";  // Command File Name
input YesNoType        inpShowComments     = No;            // Show Comments
input int              inpIndSNVersion     = 2;             // Control Panel Version

//---- Extern Variables
input string           ordHeader           = "";            // +----- Order Options -----+
input double           inpMinTarget        = 5.0;           // Equity% Target
input double           inpMinProfit        = 0.8;           // Minimum take profit%
input double           inpMaxRisk          = 50.0;          // Maximum Risk%
input double           inpMaxMargin        = 60.0;          // Maximum Open Margin
input double           inpLotFactor        = 2.00;          // Scaling Lotsize Balance Risk%
input double           inpLotSize          = 0.00;          // Lotsize Override
input int              inpDefaultStop      = 50;            // Default Stop Loss (pips)
input int              inpDefaultTarget    = 50;            // Default Take Profit (pips)
input double           inpZoneStep         = 2.5;           // Zone Step (pips)
input double           inpMaxZoneMargin    = 5.0;           // Max Zone Margin

string                 indSN               = "CPanel-v"+(string)inpIndSNVersion;

  
//-- Class defs
COrder                *order;

//+------------------------------------------------------------------+
//| RefreshPanel - Updates control panel display                     |
//+------------------------------------------------------------------+
void RefreshPanel(void)
  {
    static int         winid     = NoValue;
    
    //-- Update Control Panel (Application)
    if (IsChanged(winid,ChartWindowFind(0,indSN)))
      order.ConsoleAlert("Connected to "+indSN+"; System "+BoolToStr(order.Enabled(),"Enabled","Disabled")+" on "+TimeToString(TimeCurrent()));

//    if (winid>NoValue)
//    {
//      //-- Update Control Panel (Session)
//      for (SessionType type=Daily;type<SessionTypes;type++)
//        if (ObjectGet("bxhAI-Session"+EnumToString(type),OBJPROP_BGCOLOR)==clrBoxOff||s.Event(NewTerm)||s.Event(NewHour))
//        {
//          UpdateBox("bxhAI-Session"+EnumToString(type),Color(s[Term].Direction,IN_DARK_DIR));
//          UpdateBox("bxbAI-OpenInd"+EnumToString(type),BoolToInt(s.IsOpen(master.Session[type].HourOpen,master.Session[type].HourClose),clrYellow,clrBoxOff));
//        }
//
//      for (RoleType role=Buyer;IsBetween(role,Buyer,Seller);role++)
//      {
//        UpdateLabel("lbvOC-"+ActionText(role)+"-Strategy",BoolToStr(manager[role].Trigger,"*")+EnumToString(manager[role].Strategy),
//                                                          BoolToInt(manager[role].Trigger,Color(Direction(signal.Lead,InAction)),clrDarkGray));
//        UpdateLabel("lbvOC-"+ActionText(role)+"-Hold",CharToStr(176),BoolToInt(manager[role].Hold,clrYellow,clrDarkGray),16,"Wingdings");
//      }
//
//      UpdateLabel("lbvOC-BUY-Manager",BoolToStr(IsEqual(master.Lead,Buyer),CharToStr(108)),clrGold,11,"Wingdings");
//      UpdateLabel("lbvOC-SELL-Manager",BoolToStr(IsEqual(master.Lead,Seller),CharToStr(108)),clrGold,11,"Wingdings");
//    }
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
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    ProcessComFile(order);

    order.Update();
    order.ExecuteRequests();
    order.ExecuteOrders(OP_BUY);
    order.ExecuteOrders(OP_SELL);

    RefreshScreen();
    RefreshPanel();
  }

//+------------------------------------------------------------------+
//| OrderConfig Order class initialization function                  |
//+------------------------------------------------------------------+
void OrderConfig(void)
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
      order.SetDefaults(action,Hold,inpLotSize,inpDefaultStop,inpDefaultTarget);
      order.SetFundLimits(action,inpMinTarget,inpMinProfit);
      order.SetRiskLimits(action,inpMaxRisk,inpLotFactor,inpMaxMargin);
      order.SetZoneLimits(action,inpZoneStep,inpMaxZoneMargin);
    }
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    OrderConfig();
    ManualInit(inpComFile);
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete order;
  }