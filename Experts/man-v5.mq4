//+------------------------------------------------------------------+
//|                                                       man-v5.mq4 |
//|                                                 Dennis Jorgenson |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
//#property link      "https://www.mql5.com"
#property version   "5.01"
#property strict

#define Hide       true
#define NoHide     false
#define debug      false

  //-- App-Specific Nomens
  enum           StrategyType
                 {
                   NoStrategy,
                   Protect,
                   Position,
                   Mitigate,
                   Capture,
                   Release
                 };

  enum           AccountSource
                 {
                   USD,
                   XRP
                 };

  enum           ManagerType
                 {
                   Sales,
                   Purchasing,
                   Unassigned    = -1
                 };

#include <Class/Order.mqh>
#include <Class/TickMA.mqh>
#include <Class/Session.mqh>
#include <Class/Fractal.mqh>

//--- Show Options
input string        showHeader         = "";          // +--- Show Options ---+
input AccountSource inpSource          = XRP;         // Account Source
input int           inpPeriodsIdle     = 6;           // Idle Time (In Periods)
input int           inpShowZone        = 0;           // Show (n) Zone Lines
input int           inpAreaOfOperation = 6;           // Pips from trigger

input string        fractalHeader      = "";          //+----- Fractal inputs -----+
input int           inpRange           = 120;         // Maximum fractal pip range
input int           inpRangeMin        = 60;          // Minimum fractal pip range

//--- Regression parameters
input string        regrHeader         = "";          // +--- Regression Config ---+
input int           inpPeriods         = 80;          // Retention
input int           inpDegree          = 6;           // Poiy Regression Degree
input double        inpAgg             = 2.5;         // Tick Aggregation
input PriceType     inpShowFractal     = PriceTypes;  // Show Fractal

input string        ordHeader          = "";          // +----- Order Options -----+
input BrokerModel   inpBrokerModel     = Discount;    // Brokerage Leverage Model
input double        inpEquityTarget    = 5.0;         // Equity% Target
input double        inpEquityTargetMin = 0.8;         // Minimum take profit%
input double        inpEquityRiskMax   = 5.0;         // Maximum Risk%
input double        inpMaxMargin       = 60.0;        // Maximum Margin
input double        inpLotFactor       = 2.00;        // Lot Size Risk% of Balance
input double        inpLotSize         = 0.00;        // Lot size override
input int           inpDefaultStop     = 50;          // Default Stop Loss (pips)
input int           inpDefaultTarget   = 50;          // Default Take Profit (pips)
input double        inpZoneStep        = 2.5;         // Zone Step (pips)
input double        inpMaxZoneMargin   = 5.0;         // Max Zone Margin

//--- Session Inputs
input int           inpAsiaOpen        = 1;            // Asia Session Opening Hour
input int           inpAsiaClose       = 10;           // Asia Session Closing Hour
input int           inpEuropeOpen      = 8;            // Europe Session Opening Hour
input int           inpEuropeClose     = 18;           // Europe Session Closing Hour
input int           inpUSOpen          = 14;           // US Session Opening Hour
input int           inpUSClose         = 23;           // US Session Closing Hour
input int           inpGMTOffset       = 0;            // Offset from GMT+3

  CTickMA          *t                  = new CTickMA(inpPeriods,inpDegree,inpAgg);
  COrder           *order              = new COrder(inpBrokerModel,Hold,Hold);
  CSession         *s[SessionTypes];

  struct SessionMaster
  {
    SessionType   Lead;               //-- Lead session
    SessionType   Pivot;              //-- Pivot session
    int           Hedge;              //-- Net Equal Term Direction
    bool          Expansion;          //-- All Session Breakout/Reversal Flag
  };

  struct ManagerRec
  {
    FractalType   Type;
    StrategyType  Strategy;
    int           Bias;
    bool          Confirmed;
    double        Pivot;
    double        AOO;                                 //-- Area of Operation
    double        EquityRiskMax;
    double        EquityTargetMin;
    double        EquityTarget;
  };

  ManagerRec      mr[2];
  SessionMaster   sm;

  int             trManager             = NoAction;
  int             trBias                = NoBias;
  int             trConfirmed           = NoAction;
  int             trTrend               = NoAction;

  bool            PauseOn               = false;
  int             Tick                  = 0;

//+------------------------------------------------------------------+
//| RefreshPanel - Repaints cPanel-v3                                |
//+------------------------------------------------------------------+
void RefreshPanel(void)
  {
    ManagerType manager;

    //-- Update Control Panel (Session)
    for (SessionType type=Daily;type<SessionTypes;type++)
      if (ObjectGet("bxhAI-Session"+EnumToString(type),OBJPROP_BGCOLOR)==clrBoxOff||s[type].Event(NewFractal)||s[type].Event(NewHour))
      {
        UpdateBox("bxhAI-Session"+EnumToString(type),Color(s[type][Term].Direction,IN_DARK_DIR));
        UpdateBox("bxbAI-OpenInd"+EnumToString(type),BoolToInt(s[type].IsOpen(),clrYellow,clrBoxOff));
      }

    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
    {
      manager         = (ManagerType)Action(action,InAction,InContrarian);

      UpdateLabel("lbvOC-"+ActionText(action)+"-Strategy",BoolToStr(mr[manager].Strategy==NoStrategy,"Pending",EnumToString(mr[manager].Strategy)),
                                                          BoolToInt(mr[manager].Strategy==NoStrategy,clrDarkGray,Color(mr[manager].Strategy)));
      UpdateLabel("lbvOC-"+ActionText(action)+"-Hold",CharToStr(176),BoolToInt(mr[action].Confirmed,clrYellow,
                                                          BoolToInt(mr[Action(action,InAction,InContrarian)].Confirmed,clrRed,clrDarkGray)),16,"Wingdings");
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Repaints Indicator labels                        |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string text = "";
    
    text = "Source Value ["+EnumToString(inpSource)+"]:"+DoubleToStr(iClose("XRPUSD",0,0))+"\n"+ManagerStr()+"\n\n"+t.ActiveEventStr();

    UpdateLine("[m4]Mid",s[Daily].Pivot(OffSession),STYLE_DOT,clrDarkGray);
    UpdateLine("[m4]Lead",s[sm.Lead].Pivot(ActiveSession),STYLE_DOT,Color(sm.Lead,Bright));
    //UpdateLine("[m4]DCABuy",order.DCA(OP_BUY),STYLE_DOT,clrForestGreen);
    //UpdateLine("[m4]DCASell",order.DCA(OP_SELL),STYLE_DOT,clrMaroon);

    for (SessionType session=Daily;session<SessionTypes;session++)
      if (s[session].ActiveEvent())
        Append(text,EnumToString(session)+" "+s[session].ActiveEventStr(),"\n\n");
        
    Comment(text);
  }

//+------------------------------------------------------------------+
//| CallPause                                                        |
//+------------------------------------------------------------------+
void CallPause(string Message, bool Pause)
  {
    if (Pause)
      Pause(Message,AccountCompany()+" Event Trapper");
    else
      Print(Message);
  }

//+------------------------------------------------------------------+
//| IsChanged - Returns true on Strategy Change by Manager           |
//+------------------------------------------------------------------+
bool IsChanged(StrategyType &Compare, StrategyType Value)
  {
    if (Value==NoStrategy)
      return false;

    if (Compare==Value)
      return false;
      
    Compare = Value;
    return true;
  }

//+------------------------------------------------------------------+
//| Zone - Returns calculated Zone of supplied Plan                  |
//+------------------------------------------------------------------+
int Zone(int Action, double Pivot)
  {
    const int zones[2][6]  = {{-3,-2,-1,0,1,2},{2,1,0,-1,-2,-3}};
    double    zone[5];
    
    zone[0]  = t.Range().High;
    zone[1]  = t.Range().Resistance;
    zone[2]  = t.Range().Mean;
    zone[3]  = t.Range().Support;
    zone[4]  = t.Range().Low;
    
    for (int node=0;node<5;node++)
      if (Pivot>zone[node])
        return zones[Action,node];

    return zones[Action][5];    
  }

//+------------------------------------------------------------------+
//| UpdateSession - Updates Session Fractal Data                     |
//+------------------------------------------------------------------+
void UpdateSession(void)
  {
    sm.Expansion       = false;
    sm.Hedge           = NoAction;

    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      s[type].Update();

      sm.Pivot                  = sm.Lead;
      sm.Lead                   = (SessionType)BoolToInt(s[type][SessionOpen]||s[type][SessionClose],type,sm.Lead);
      sm.Expansion              = sm.Expansion||s[type][NewExpansion];
      
      if (type>Daily)
        sm.Hedge                = BoolToInt(IsEqual(s[Daily][Term].Direction,s[type][Term].Direction),sm.Hedge,s[sm.Lead][Term].Bias);
    }    
  }

//+------------------------------------------------------------------+
//| UpdateTick - Updates & Retrieves Tick data and fractals          |
//+------------------------------------------------------------------+
void UpdateTick(void)
  {
    t.Update();
  }

//+------------------------------------------------------------------+
//| UpdateOrder - Updates & Retrieves order data                     |
//+------------------------------------------------------------------+
void UpdateOrder(void)
  {
    order.Update();
  }

//+------------------------------------------------------------------+
//| ManagePosition - Handle Order, Request, Risk & Profit by Manager |
//+------------------------------------------------------------------+
void ManageOrders(ManagerType Manager)
  {
    OrderRequest request    = order.BlankRequest(EnumToString(Manager));
    int action              = Operation(mr[Manager].Bias);

    if (order.Enabled(Manager))
    {
      if (NewStrategy(Manager))
      {};

      if (IsEqual(Manager,mr[Manager].Bias)||IsEqual(mr[Manager].Bias,NoBias))
      {
        //-- Risk mitigation steps
      }

      else
        if (order.LotSize(action)<=order.Free(action))
          if (mr[Manager].Confirmed)
          {
            request.Type        = action;
            request.Memo        = "Order "+ActionText(request.Type)+" Test";
   
            if (order.Submitted(request))
              Print(order.RequestStr(request));
            else {/* identifyfailure */}
          }
    }

    //-- Process Contrarian Queue
    if (order.Enabled(Action(Manager,InAction,InContrarian)))
      order.ExecuteOrders(Action(Manager,InAction,InContrarian));
  }

//+------------------------------------------------------------------+
//| NewBias - Confirms bias changes                                  |
//+------------------------------------------------------------------+
bool NewBias(int Manager, int &Bias, int Change)
  {
    if (IsEqual(mr[Manager].AOO,NoValue))
      return false;

    if (IsEqual(Manager,OP_BUY))
      if (IsHigher(Close[0],mr[Manager].AOO,NoUpdate,Digits))
        Change           = Manager;

    if (IsEqual(Manager,OP_SELL))
      if (IsLower(Close[0],mr[Manager].AOO,NoUpdate,Digits))
        Change           = Manager;

    return NewAction(Bias,Change);
  }

//+------------------------------------------------------------------+
//| NewMomentum - Tests changes in Momentum                          |
//+------------------------------------------------------------------+
bool NewMomentum(void)
  {
    return !(t.Momentum().High.Event==NoEvent&&t.Momentum().Low.Event==NoEvent);
  }

//+------------------------------------------------------------------+
//| NewStrategy - Updates strategy based on supplied Action Pivot    |
//+------------------------------------------------------------------+
bool NewStrategy(ManagerType Manager)
  {
    StrategyType strategy   = NoStrategy;
    int          action     = Action(Manager,InAction,InContrarian);
    int          calc       = Zone(Manager,order.DCA(action))-Zone(action,s[sm.Lead].Pivot(ActiveSession));

    switch (Zone(Manager,order.DCA(action)))
    {
       case -3: //--Capture/Release
                strategy    = (StrategyType)BoolToInt(order.Recap(action,Loss).Equity<-mr[action].EquityRiskMax,Release,Capture);
                break;
                
       case -2: //--Mitigate/Release
                strategy    = (StrategyType)BoolToInt(order.Recap(action,Loss).Equity<-mr[action].EquityRiskMax,Release,Mitigate);
                break;
                
       case -1: //--Mitigate/Position
                strategy    = (StrategyType)BoolToInt(order.Recap(action,Loss).Equity<-mr[action].EquityRiskMax,Mitigate,Position);
                break;

       case  0: //--Position
                strategy    = Position;
                break;

       case +1: //--Position/Protect
                strategy    = (StrategyType)BoolToInt(order.Recap(action,Profit).Equity>mr[action].EquityTarget,Protect,Position);
                break;

       case +2: //--Protect
                strategy    = Protect;
                break;
    }

    return IsChanged(mr[Manager].Strategy,strategy);
  }

//+------------------------------------------------------------------+
//| NewTrigger - Tests and sets trigger boundaries                   |
//+------------------------------------------------------------------+
bool NewTrigger(void)
  {
    static int    action       = NoBias;
           bool   triggered    = false;

    for (int manager=OP_BUY;IsBetween(manager,OP_BUY,OP_SELL);manager++)
    {
      if (NewBias(manager,mr[manager].Bias,BoolToInt(Close[0]>mr[manager].AOO,OP_BUY,OP_SELL)))
        mr[manager].Confirmed  = false;

      if (IsChanged(mr[manager].Confirmed,mr[manager].Confirmed||(IsEqual(mr[manager].Bias,OP_BUY)&&Close[0]>t.SMA().High[0])||(IsEqual(mr[manager].Bias,OP_SELL)&&Close[0]<t.SMA().Low[0])))
        trConfirmed            = manager;
    }

    if (mr[OP_BUY].Confirmed&&mr[OP_SELL].Confirmed)
      if (IsEqual(mr[OP_BUY].Bias,mr[OP_SELL].Bias))
        if (IsChanged(trTrend,trConfirmed))
          Flag("trConfirmed",Color(Direction(trTrend)));

    if (IsChanged(action,t.Fractal().Bias))
      if (NewAction(trManager,action))
        triggered              = true;

    if (t.Event(NewReversal,Critical))
    {
      if (NewAction(trManager,Action(t.Range().Direction)))
        if (IsChanged(action,trManager))
          Flag("lnRangeReversal",clrWhite);

      triggered                = true;
    }

    if (t.Event(NewBreakout,Critical))
    {
      if (NewAction(trManager,Action(t.Range().Direction)))
        if (IsChanged(action,trManager))
          Flag("lnRangeBreakout",clrSteelBlue);

      triggered                = true;
    }

    if (triggered)
    {
//      Flag("New "+ActionText(action),Color(Direction(action,InAction)));
      mr[trManager].Type       = (FractalType)BoolToInt(t[NewHigh],t.Fractal().High.Type,t.Fractal().Low.Type);
      mr[trManager].Bias       = Action(trManager,InAction,InContrarian);
      mr[trManager].Pivot      = Close[0];
      mr[trManager].AOO        = BoolToDouble(IsEqual(trManager,OP_BUY),mr[trManager].Pivot,mr[trManager].Pivot)+(point(inpAreaOfOperation)*Direction(trManager,InAction));
      mr[trManager].Confirmed  = false;

      UpdatePriceLabel("trManager-"+ActionText(trManager),Close[0],Color(Direction(mr[trManager].Bias,InAction)));
      return true;
    }
    
    return NewMomentum();
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {    
    if (NewTrigger())
      if (IsBetween(trManager,OP_BUY,OP_SELL))
      {
//      Pause("New Trigger!","Change");
        ManageOrders((ManagerType)trManager);
        ManageOrders((ManagerType)Action(trManager,InAction,InContrarian));
      }

    order.ExecuteRequests();    
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    UpdateOrder();
    UpdateTick();
    UpdateSession();

    Execute();

    RefreshScreen();
    RefreshPanel();
  }


//+------------------------------------------------------------------+
//| ManagerStr - returns formatted Manager data                      |
//+------------------------------------------------------------------+
string ManagerStr(void)
  {
    string text   = "";
    
    Append(text,"Manager Active: "+EnumToString((ManagerType)trManager),"\n");
    Append(text,"Confirmed: "+EnumToString((ManagerType)trConfirmed));
    Append(text,"Trend: "+BoolToStr(IsEqual(trTrend,OP_BUY),"Long",BoolToStr(IsEqual(trTrend,OP_SELL),"Short","Awaiting Confirmation")),"\n");
    
    for (int bias=OP_BUY;IsBetween(bias,OP_BUY,OP_SELL);bias++)
    {
      Append(text,"Manager: "+EnumToString((ManagerType)bias),"\n");
      Append(text,"Bias: "+ActionText(mr[bias].Bias)+BoolToStr(mr[bias].Confirmed,"*"));
      Append(text,"Type: "+EnumToString(mr[bias].Type));
      Append(text,"Pivot: "+DoubleToString(mr[bias].Pivot,Digits));
      Append(text,"AOO: "+DoubleToString(mr[bias].AOO,Digits));
    }

    return text;
  }

//+------------------------------------------------------------------+  
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    order.Disable();

    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      //-- Manager Config
      mr[action].Type              = Expansion;
      mr[action].Bias              = NoBias;
      mr[action].Confirmed         = false;
      mr[action].Pivot             = NoValue;
      mr[action].AOO               = NoValue;       //-- Area of Operation
      mr[action].EquityRiskMax     = inpEquityRiskMax;
      mr[action].EquityTargetMin   = inpEquityTargetMin;
      mr[action].EquityTarget      = inpEquityTarget;

      //-- Order Config
      order.Enable(action);
      order.SetDefaults(action,inpLotSize,inpDefaultStop,inpDefaultTarget);
      order.SetEquityTargets(action,mr[action].EquityTarget,mr[action].EquityTargetMin);
      order.SetRiskLimits(action,mr[action].EquityRiskMax,inpMaxMargin,inpLotFactor);
      order.SetZoneLimits(action,inpZoneStep,inpMaxZoneMargin);
      order.SetDefaultMethod(action,Hold);

      NewPriceLabel("trManager-"+ActionText(action));
    }

    //-- Initialize Session
    s[Daily]        = new CSession(Daily,0,23,inpGMTOffset);
    s[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose,inpGMTOffset);
    s[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose,inpGMTOffset);
    s[US]           = new CSession(US,inpUSOpen,inpUSClose,inpGMTOffset);

    NewLine("[m4]Lead");
    NewLine("[m4]Mid");
    NewLine("[m4]DCABuy");
    NewLine("[m4]DCASell");

    NewPriceLabel("tmaNewLow");
    NewPriceLabel("tmaNewHigh");

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete t;
    delete order;

    for (SessionType type=Daily;type<SessionTypes;type++)
      delete s[type];
  }
