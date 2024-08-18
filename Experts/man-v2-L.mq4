//+------------------------------------------------------------------+
//|                                                     man-v2-L.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                   Demo Working Release - Live EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "2.02"
#property strict

#define debug false

#include <Class/Order.mqh>
#include <Class/Session.mqh>
#include <Class/TickMA.mqh>

#include <ordman.mqh>

  //--- Show Fractal Event Flag
  enum ShowType
     {
       stNone   = NoValue,   // None
       stOrigin = Origin,    // Origin
       stTrend  = Trend,     // Trend
       stTerm   = Term       // Term
     };


  //--- EA Config
  input string           appHeader           = "";            // +--- Application Config ---+
  input BrokerModel      inpBrokerModel      = Discount;      // Broker Model
  input string           inpComFile          = "manual.csv";  // Command File
  input YesNoType        inpShowComments     = No;            // Show Comments
  input int              inpIndSNVersion     = 2;             // Control Panel Version


  //--- Order Config
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

  //--- Regression Config
  input string           regrHeader          = "";            // +--- Regression Config ----+
  input int              inpPeriods          = 80;            // Retention
  input double           inpAgg              = 2.5;           // Tick Aggregation
  input ShowType         inpShowType         = stNone;        // Show TickMA Fractal Events


  //--- Session Config
  input string           sessHeader          = "";            // +--- Session Config -------+
  input int              inpAsiaOpen         = 1;             // Asia Session Opening Hour
  input int              inpAsiaClose        = 10;            // Asia Session Closing Hour
  input int              inpEuropeOpen       = 8;             // Europe Session Opening Hour
  input int              inpEuropeClose      = 18;            // Europe Session Closing Hour
  input int              inpUSOpen           = 14;            // US Session Opening Hour
  input int              inpUSClose          = 23;            // US Session Closing Hour
  input int              inpGMTOffset        = 0;             // Offset from GMT+3


  //-- Internal EA Configuration
  string                 indSN               = "CPanel-v"+(string)inpIndSNVersion;
  string                 objectstr           = "[man-v2]";


  //-- Class defs
  COrder                *order;
  CSession              *s[SessionTypes];
  CTickMA               *t                   = new CTickMA(inpPeriods,inpAgg,(FractalType)inpShowType);


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
      UpdateLabel("pvBalance","",clrNONE,1);
      UpdateLabel("pvProfitLoss","",clrNONE,1);
      UpdateLabel("pvNetEquity","",clrNONE,1);
      UpdateLabel("pvEquity","",clrNONE,1);
      UpdateLabel("pvMargin","",clrNONE,1);

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
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    //-- Update TickMA
    t.Update();

    //-- Update Session
    for (SessionType type=Daily;type<SessionTypes;type++)
      s[type].Update();

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
//| SessionConfig Session class initialization function              |
//+------------------------------------------------------------------+
void SessionConfig(void)
  {
    //-- Initialize Session
    s[Daily]             = new CSession(Daily,0,23,inpGMTOffset);
    s[Asia]              = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    s[Europe]            = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    s[US]                = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);

    //-- Initialize Session
    for (SessionType type=Daily;type<SessionTypes;type++)
      s[type].Update();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    PanelConfig();
    OrderConfig();
    SessionConfig();
    ManualConfig(inpComFile);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete order;
    delete t;

    for (SessionType type=Daily;type<SessionTypes;type++)
      delete s[type];
  }
