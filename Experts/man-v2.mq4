//+------------------------------------------------------------------+
//|                                                       man-v2.mq4 |
//|                                 Copyright 2017, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.10"
#property strict

#include <Class\PipFractal.mqh>
#include <manual.mqh>

//input string appHeader               = "";    //+------ App Options -------+
//input bool   inpShowFiboLines        = false; // Display Fibonacci Lines

input string fractalHeader           = "";    //+------ Fractal Options ------+
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpRangeMin             = 60;    // Minimum fractal pip range

input string PipMAHeader             = "";    //+------ PipMA Options ------+
input int    inpDegree               = 6;     // Degree of poly regression
input int    inpPeriods              = 200;   // Number of poly regression periods
input double inpTolerance            = 0.5;   // Directional change sensitivity

//--- Class defs
  CFractal         *fractal          = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal         = new CPipFractal(inpDegree,inpPeriods,inpTolerance,fractal);

//--- Operational variables
  int              display           = NoValue;
  bool             alert[EventTypes];
  
//--- Order Opportunity operationals
  int              oTradeLevel       = NoValue;
  int              oTradeEvent       = NoValue;
  int              oTradeDir         = DirectionNone;
  int              oTradeAction      = OP_NO_ACTION;
  bool             oTradeOpen        = false;
  
//--- Trade Action operationals
  enum TriggerState
  {
    Spotting,
    Loaded,
    Locked,
    Ready,
    Fired
  };
  
  struct TradeRec
  {
    TriggerState   OpenTrigger;
    datetime       OpenTime;
    double         OpenPrice;
    double         OpenPriceMax;
    double         OpenPriceMin;
    datetime       OrderTime;
  };
  
  TradeRec         TradeAction[2];

//--- Trade Action operationals
  enum ProfitState
  {
    Inactive,
    Activate,
    Holding,
    Pending,
    Deposited
  };
    
  struct ProfitRec
  {
    ProfitState    ProfitTrigger;
    datetime       ProfitTime;
    double         ProfitPctMax;
    double         ProfitPctMin;
  };
  
  ProfitRec        ProfitAction[2];

//+------------------------------------------------------------------+
//| SetProfitStrategy - Sets the profit state by Action              |
//+------------------------------------------------------------------+
void SetProfitStrategy(int Action)
  {
    int spsDir              = ActionDir(Action);
  }

//+------------------------------------------------------------------+
//| SetProfitAction - Sets the profit state by Action                |
//+------------------------------------------------------------------+
void SetProfitAction(int Action, ProfitState Status)
  {
    ProfitAction[Action].ProfitTrigger = Status;
    
    switch (Status)
    {
      case Inactive:
      case Activate:   ProfitAction[Action].ProfitTime         = 0;
                       ProfitAction[Action].ProfitPctMax       = LotValue(Action,Net,InEquity);
                       ProfitAction[Action].ProfitPctMin       = LotValue(Action,Net,InEquity);
                       
                       if (LotCount(Action)>0.00)
                         ProfitAction[Action].ProfitTrigger    = Holding;
                       else
                         ProfitAction[Action].ProfitTrigger    = Inactive;

                       break;

      case Pending:    if (LotCount(Action)>0.00)
                         if (pfractal.Event(NewLow))
                           ProfitAction[Action].ProfitTrigger  = Holding;
                         else
                           SetProfitStrategy(Action);
                       else
                         if (OrderClosed(Action))
                         {
                           ProfitAction[Action].ProfitTime     = TimeCurrent();
                           ProfitAction[Action].ProfitTrigger  = Deposited;
                         }

      default:         ProfitAction[Action].ProfitPctMax       = fmax(ProfitAction[Action].ProfitPctMax,LotValue(Action,Net,InEquity));
                       ProfitAction[Action].ProfitPctMin       = fmin(ProfitAction[Action].ProfitPctMin,LotValue(Action,Net,InEquity));
    }
  }
  
//+------------------------------------------------------------------+
//| SetTradeAction - Sets the trade operationals and state by Action |
//+------------------------------------------------------------------+
void SetTradeAction(int Action, TriggerState Status)
  {
    TradeAction[Action].OpenTrigger   = Status;
    
    switch (Status)
    {
      case Fired:      TradeAction[Action].OpenTime        = 0;
                       TradeAction[Action].OpenPrice       = 0.00;
                       TradeAction[Action].OpenPriceMax    = 0.00;
                       TradeAction[Action].OpenPriceMin    = 0.00;
                       
                       if (TradeAction[Action].OrderTime==0)
                         TradeAction[Action].OrderTime     = TimeCurrent();

                       break;

      case Spotting:   if (IsEqual(TradeAction[Action].OpenTime,0))
                       {
                         TradeAction[Action].OpenTime      = TimeCurrent();
                         TradeAction[Action].OpenPrice     = Bid;
                         TradeAction[Action].OpenPriceMax  = Bid;
                         TradeAction[Action].OpenPriceMin  = Bid;
                       }

      default:         TradeAction[Action].OpenPriceMax    = fmax(TradeAction[Action].OpenPriceMax,Bid);
                       TradeAction[Action].OpenPriceMin    = fmin(TradeAction[Action].OpenPriceMax,Bid);
    }
  }
  
//+------------------------------------------------------------------+
//| ManageShort - Manages short trading positions                    |
//+------------------------------------------------------------------+
void ManageShort(void)
  {
    switch (TradeAction[OP_SELL].OpenTrigger)
    {
      case Fired:       if (oTradeOpen && oTradeDir==DirectionDown)
                          SetTradeAction(OP_SELL,Spotting);
                        else
                          SetTradeAction(OP_SELL,Fired);
                        break;        

      case Spotting:    if (Bid>pfractal.Intercept(Bottom))
                          SetTradeAction(OP_SELL,Loaded);
                        break;

      case Loaded:      if (pfractal.Event(NewLow))
                          SetTradeAction(OP_SELL,Spotting);
                        
                        if (pfractal.Event(NewDirection))
                          SetTradeAction(OP_SELL,Locked);
                          
                        SetProfitAction(OP_SELL,Pending);
                        
                        break;

      case Locked:      if (Bid<pfractal.Intercept(Top))
                          SetTradeAction(OP_SELL,Ready);
                        break;

      case Ready:       if (OrderFulfilled(OP_SELL))
                        {
                          SetTradeAction(OP_SELL,Fired);
                          SetProfitAction(OP_SELL,Activate);
                        }
                        else
                        //  OpenLimitOrder(OP_SELL,pfractal.Range(Top),0.00,0.00,0.00,"Trigger Sell");
                        break;
    }
  }
  
//+------------------------------------------------------------------+
//| ManageLong - Manages long trading positions                      |
//+------------------------------------------------------------------+
void ManageLong(void)
  {
    static bool mlNegAdd = false;
    
    switch (TradeAction[OP_BUY].OpenTrigger)
    {
      case Fired:       if (oTradeOpen && oTradeDir==DirectionUp)
                          SetTradeAction(OP_BUY,Spotting);
                        else
                          SetTradeAction(OP_BUY,Fired);
                        break;        

      case Spotting:    if (Bid<pfractal.Intercept(Top))
                          SetTradeAction(OP_BUY,Loaded);
                        break;

      case Loaded:      if (pfractal.Event(NewLow))
                          SetTradeAction(OP_BUY,Spotting);
                        
                        if (pfractal.Event(NewDirection))
                          SetTradeAction(OP_BUY,Locked);

                        SetProfitAction(OP_BUY,Pending);

                        break;

      case Locked:      if (Bid>pfractal.Intercept(Bottom))
                          SetTradeAction(OP_BUY,Ready);
                        break;

      case Ready:       if (OrderFulfilled(OP_BUY))
                        {
                          SetTradeAction(OP_BUY,Fired);
                          SetProfitAction(OP_BUY,Activate);
                        }
                        else
                          OpenMITOrder(OP_BUY,pfractal.Range(Bottom),0.00,0.00,Pip(1),"Trigger Buy");

                        break;
    }  
  }
  
//+------------------------------------------------------------------+
//| ManageProfit - Manages profitable positions by Action            |
//+------------------------------------------------------------------+
void ManageProfit(int Action)
  {
    if (Action==OP_NO_ACTION)
      return;
      
    SetProfitAction(Action,ProfitAction[Action].ProfitTrigger);
    
    if (ProfitAction[Action].ProfitTrigger==Pending)
    {
    }
  }
  
//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {    
    if (pfractal.Event(NewMajor))
    {
      oTradeOpen                     = true;
      oTradeEvent                    = Major;
      oTradeDir                      = pfractal.Direction(Trend);
      oTradeAction                   = DirAction(oTradeDir);
      oTradeLevel                    = FiboRoot;
    }
    else
    if (pfractal.Event(NewTerm))
    {
      oTradeEvent                    = Minor;
      
      if (oTradeDir!=DIR_NONE)
        if (pfractal.Direction(Origin)==pfractal.Direction(Term))
          oTradeOpen                   = false;
        else
          oTradeOpen                   = true;
    }
      
    ManageShort();
    ManageLong();
    
    ManageProfit(oTradeAction);
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    fractal.Update();
    pfractal.Update();
  }

//+------------------------------------------------------------------+
//| ShowAppData - Hijacks the comment for application metrics        |
//+------------------------------------------------------------------+
void ShowAppData(void)
  {
    string        rsComment   = "";

    rsComment     = "No Comment";
    
    Comment(rsComment);  
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    static int rsLastDisplay   = display;
    
    switch (display)
    {
      case 0:  fractal.RefreshScreen();

               UpdateLine("oTop",fractal.Price(Origin,Top),STYLE_SOLID,clrGoldenrod);
               UpdateLine("oBottom",fractal.Price(Origin,Bottom),STYLE_SOLID,clrSteelBlue);
               UpdateLine("oPrice",fractal.Price(Origin),STYLE_SOLID,clrRed);
               UpdateLine("oRetrace",fractal.Price(Origin,Retrace),STYLE_DOT,clrLightGray);

               break;

      case 1:  pfractal.RefreshScreen();
               
               UpdateLine("oBase",pfractal.Price(Origin,Base),STYLE_SOLID,clrGoldenrod);
               UpdateLine("oRoot",pfractal.Price(Origin,Root),STYLE_SOLID,clrSteelBlue);
               UpdateLine("oExpansion",pfractal.Price(Origin,Expansion),STYLE_SOLID,clrRed);
               UpdateLine("oRetrace",pfractal.Price(Origin,Retrace),STYLE_DOT,clrLightGray);

               break;
               
      case 2:  ShowAppData();
               break;
               
      default: if (IsChanged(rsLastDisplay,display))
                 Comment("No Data");
    }

    //--- Show trade status
    if (oTradeOpen)
      UpdateLabel("oTradeDetails","Trade: "+proper(DirText(oTradeDir))
                 +" ("+proper(ActionText(oTradeAction))
                 +"): "+EnumToString(TradeAction[oTradeAction].OpenTrigger)
                 +BoolToStr(LotCount(oTradeAction)>0.00," Profit: "+EnumToString(ProfitAction[oTradeAction].ProfitTrigger)),
        BoolToInt(oTradeOpen,clrYellow,clrGray));
    else
    if (oTradeAction != OP_NO_ACTION)
      if (TradeAction[oTradeAction].OpenTrigger==Fired)
        UpdateLabel("oTradeDetails","Trade: "+proper(DirText(oTradeDir))
                   +" ("+proper(ActionText(oTradeAction))
                   +"): "+DoubleToStr(ProfitAction[oTradeAction].ProfitPctMin,1)
                   +"% "+DoubleToStr(ProfitAction[oTradeAction].ProfitPctMax,1)+"%"
                   +BoolToStr(LotCount(oTradeAction)>0.00," Profit: "+EnumToString(ProfitAction[oTradeAction].ProfitTrigger)),
          clrGoldenrod);
      else
        UpdateLabel("oTradeDetails","Trade: "+proper(DirText(oTradeDir))
                   +" ("+proper(ActionText(oTradeAction))
                   +"): "+EnumToString(TradeAction[oTradeAction].OpenTrigger)
                   +BoolToStr(LotCount(oTradeAction)>0.00," Profit: "+EnumToString(ProfitAction[oTradeAction].ProfitTrigger)),
          clrLawnGreen);      
    
    pfractal.ShowFiboArrow();    
  }
  
//+------------------------------------------------------------------+
//| ExecAlerts - executes alert tests for strategy breakpoints       |
//+------------------------------------------------------------------+
void ExecAlerts(void)
  {
    static int    eOK     = IDTRYAGAIN;
    static bool   eFOC    = true;
    static string eAlert  = "";
    
    if (alert[ZeroFOCDeviation])
      if (IsEqual(pfractal.FOC(Deviation),0.0,1))
      {
        if (!eFOC)
          if (pfractal.HistoryLoaded())
            Append(eAlert,"PipMA FOC Deviation at zero","\n");

        eFOC                = true;
      }
      else
        eFOC                = false;
      
    if (alert[NewMajor])
      if (pfractal.Event(NewMajor))
        Append(eAlert,"New PipMA Major Event","\n");

    if (alert[NewTerm])
      if (pfractal.Event(NewTerm))
        Append(eAlert,"New PipMA Term Direction","\n");

    if (alert[NewTrend])
      if (pfractal.Event(NewTrend))
        Append(eAlert,"New PipMA Trend Direction","\n");

    if (alert[NewMajor])
      if (fractal.Event(NewMajor))
        Append(eAlert,"New Fractal Major Event","\n");

    if (alert[NewFractal])
      if (fractal.Event(NewFractal))
        Append(eAlert,"New Fractal Event","\n");

    if (alert[NewOrigin])
      if (fractal.Event(NewOrigin))
        Append(eAlert,"New Fractal Origin Event","\n");

    if (StringLen(eAlert)>0)
    {
      if (eOK != IDCANCEL)
        eOK = Pause(eAlert,"Event Watcher",MB_ICONEXCLAMATION|MB_DEFBUTTON3|MB_CANCELTRYCONTINUE);
      
      if (eOK == IDCONTINUE)
        eAlert            = "";
    }
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    bool eacAlert;  
    
    if (Command[0]=="SHOW")
      if (InStr(Command[1],"NONE"))
        display  = NoValue;
      else
      if (InStr(Command[1],"FIB"))
        display  = 0;
      else
      if (InStr(Command[1],"PIP"))
        display  = 1;
      else
      if (InStr(Command[1],"APP"))
        display  = 2;
      else
        display  = NoValue;  

    if (Command[0]=="SET")
    {
      eacAlert   = Command[2]=="ON";
     
      if (InStr(Command[1],"ALERT"))
        for (EventType type=0; type<EventTypes; type++)
          alert[type] = eacAlert;
      else
        if (GetEvent(Command[1])<EventTypes)
          alert[GetEvent(Command[1])] = eacAlert;
    }
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
    ExecAlerts();
    
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
    
    NewLine("oBase");
    NewLine("oRoot");
    NewLine("oExpansion");
    NewLine("oRetrace");

    NewLine("oTop");
    NewLine("oBottom");
    NewLine("oPrice");
    
    NewLabel("oTradeDetails","Trade: None",5,10,clrLightGray,SCREEN_LL);

    SetTradeAction  (OP_BUY,  Fired);
    SetTradeAction  (OP_SELL, Fired);
    SetProfitAction (OP_BUY,  Activate);
    SetProfitAction (OP_SELL, Activate);
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete pfractal;
  }