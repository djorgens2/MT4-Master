//+------------------------------------------------------------------+
//|                                                       man-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                         Raw Order-Integration EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "2.02"
#property strict

#define debug false

#include <Class/Order.mqh>
#include <ordman.mqh>


  //--- Configuration
  input string           appHeader           = "";            // +--- Application Config ---+
  input BrokerModel      inpBrokerModel      = Discount;      // Broker Model
  input string           inpComFile          = "manual.csv";  // Command File
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

  //-- Internal EA Configuration
  string                 indSN               = "CPanel-v"+(string)inpIndSNVersion;
  string                 objectstr           = "[man-v2]";


  //-- Class defs
  COrder                *order;

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string text     = "";
    static int         winid     = NoValue;
    
    //-- Update Control Panel (Application)
    if (IsChanged(winid,ChartWindowFind(0,indSN)))
    {
      //-- Update Panel
      order.ConsoleAlert("Connected to "+indSN+"; System "+BoolToStr(order.Enabled(),"Enabled","Disabled")+" on "+TimeToString(TimeCurrent()));
      UpdateLabel("lbvAC-File",inpComFile,clrGoldenrod);
      
      for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
      {
        UpdateLabel("lbvOQ-"+ActionText(action)+"-ShowTP",
          CharToStr((uchar)BoolToInt(order.Config(action).HideTarget,251,252)),BoolToInt(order.Config(action).HideTarget,clrRed,clrLawnGreen),12,"Wingdings");

        UpdateLabel("lbvOQ-"+ActionText(action)+"-ShowSL",
          CharToStr((uchar)BoolToInt(order.Config(action).HideStop,251,252)),BoolToInt(order.Config(action).HideStop,clrRed,clrLawnGreen),12,"Wingdings");
      }

      //-- Hide non-Panel elements
      UpdateLabel("pvEquity","",clrNONE,16);
      UpdateLabel("pvBalance","",clrNONE,16);
      UpdateLabel("pvMargin","",clrNONE,16);

    }

    if (IsEqual(winid,NoValue))
    {
      UpdateLabel("pvBalance","$"+dollar(order.Metrics().Balance,11),clrLightGray,12,"Consolas");
      UpdateLabel("pvProfitLoss","$"+dollar(order.Metrics().Equity,11),clrLightGray,12,"Consolas");
      UpdateLabel("pvNetEquity","$"+dollar(order.Metrics().EquityBalance,11),clrLightGray,12,"Consolas");
      UpdateLabel("pvEquity",DoubleToStr(order.Metrics().EquityClosed*100,1)+"%",Color(order[Net].Value),14,"Consolas");
      UpdateLabel("pvMargin",DoubleToString(order.Metrics().Margin*100,1)+"%",Color(order[Net].Lots),14,"Consolas");

      Comment(order.QueueStr()+order.OrderStr());
    }
//    if (winid>NoValue)
//    {
//      -- Update Control Panel (Session)
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
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    order.Update();
    order.ProcessOrders(OP_SELL);
    order.ProcessOrders(OP_BUY);
    order.ProcessRequests();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    ProcessComFile(order);
    Execute();

    RefreshScreen();
  }

//+------------------------------------------------------------------+
//| PanelConfig Sets up display alternative CPanel                   |
//+------------------------------------------------------------------+
void PanelConfig(void)
  {
    NewLabel("pvBalance","",80,10,clrLightGray,SCREEN_UR);
    NewLabel("pvProfitLoss","",80,26,clrLightGray,SCREEN_UR);
    NewLabel("pvNetEquity","",80,42,clrLightGray,SCREEN_UR);
    NewLabel("pvEquity","",10,10,clrLightGray,SCREEN_UR);
    NewLabel("pvMargin","",10,40,clrLightGray,SCREEN_UR);
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
      order.SetFundLimits(action,inpMinTarget,inpMinProfit,inpLotSize);
      order.SetRiskLimits(action,inpMaxRisk,inpLotFactor,inpMaxMargin);
      order.SetZoneLimits(action,inpZoneStep,inpMaxZoneMargin);
      order.SetDefaultStop(action,0.00,inpDefaultStop,false);
      order.SetDefaultTarget(action,0.00,inpDefaultTarget,false);
    }
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    PanelConfig();
    OrderConfig();
    ManualConfig(inpComFile);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete order;
  }
