//+------------------------------------------------------------------+
//|                                                        hm-v3.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <Class\PipFractal.mqh>
#include <Class\ArrayInteger.mqh>

//--- Input params
input string appHeader          = "";    //+------ Application inputs ------+
//input int    inpShowLines       = 120;   // Maximum fractal pip range
//input int    inpRangeMin        = 60;    // Minimum fractal pip range

input string PipMAHeader        = "";    //+------ PipMA inputs ------+
input int    inpDegree          = 6;     // Degree of poly regression
input int    inpPeriods         = 200;   // Number of poly regression periods
input double inpTolerance       = 0.5;   // Trend change tolerance (sensitivity)
input bool   inpShowFibo        = true;  // Display lines and fibonacci points
input bool   inpShowComment     = false; // Display fibonacci data in Comment

input string fractalHeader      = "";    //+------ Fractal inputs ------+
input int    inpRangeMax        = 120;   // Maximum fractal pip range
input int    inpRangeMin        = 60;    // Minimum fractal pip range


//--- Class defs
  CFractal         *fractal     = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal    = new CPipFractal(inpDegree,inpPeriods,inpTolerance,fractal);
  CArrayInteger    *kill        = new CArrayInteger(0);

  enum PivotState {
                    NewOrder,
                    NewHedge,
                    TakeProfit,
                    TakeLoss
                  };
                  
  struct PivotRec {
                    int         Action;
                    int         Direction;
                    PivotState  State;
                    double      Price;
                    datetime    Time;
                 };

  PivotRec          pr;                

  int               hmShowLineType = NoValue;
  int               hmTradeBias    = OP_NO_ACTION;
  int               hmTradeDir     = DirectionNone;

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    fractal.Update();
    pfractal.Update();
    
    if (pfractal.Event(NewTrend))
      Print ("New Trend @"+DoubleToStr(Close[0],Digits));
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    UpdateLine("lnPivot",pr.Price,STYLE_SOLID,clrWhite);
    
    switch (hmShowLineType)
    {
      case Term:       UpdateLine("pfBase",pfractal[Term].Base,STYLE_DASH,clrGoldenrod);
                       UpdateLine("pfRoot",pfractal[Term].Root,STYLE_DASH,clrSteelBlue);
                       UpdateLine("pfExpansion",pfractal[Term].Expansion,STYLE_DASH,clrFireBrick);
                       break;
      
      case Trend:      UpdateLine("pfBase",pfractal[Trend].Base,STYLE_SOLID,clrGoldenrod);
                       UpdateLine("pfRoot",pfractal[Trend].Root,STYLE_SOLID,clrSteelBlue);
                       UpdateLine("pfExpansion",pfractal[Trend].Expansion,STYLE_SOLID,clrFireBrick);
                       break;
                       
      case Origin:     UpdateLine("pfBase",pfractal.Price(Origin,Base),STYLE_DOT,clrGoldenrod);
                       UpdateLine("pfRoot",pfractal.Price(Origin,Root),STYLE_DOT,clrSteelBlue);
                       UpdateLine("pfExpansion",pfractal.Price(Origin,Expansion),STYLE_DOT,clrFireBrick);
                       break;

      default:         UpdateLine("pfBase",0.00,STYLE_DOT,clrNONE);
                       UpdateLine("pfRoot",0.00,STYLE_DOT,clrNONE);
                       UpdateLine("pfExpansionSQL",0.00,STYLE_DOT,clrNONE);
                       break;
    }
  }

//+------------------------------------------------------------------+
//| PivotDeviation - Current pivot deviation                         |
//+------------------------------------------------------------------+
double PivotDeviation(void)
  {
    if (hmTradeDir==DirectionUp)
      return (Close[0]-pr.Price);
      
    if (hmTradeDir==DirectionDown)
      return (pr.Price-Close[0]);
      
    return (0.00);
  }

//+------------------------------------------------------------------+
//| SetPivot - Moves the pivot based on the most recent action       |
//+------------------------------------------------------------------+
void SetPivot(int Action, PivotState State, double Price)
  {
    pr.Action      = Action;
    pr.Direction   = Direction(Action,InAction);
    pr.State       = State;
    pr.Price       = Price;
    pr.Time        = TimeCurrent();
  }

//+------------------------------------------------------------------+
//| OrderCheck - verifies order margin requirements and position     |
//+------------------------------------------------------------------+
void OrderCheck(int Action, PivotState State, string Reason)
  {
    if (OpenOrder(Action,Reason))
      SetPivot(Action,State,ordOpen.Price);
  }

//+------------------------------------------------------------------+
//| EquityCheck - lot diversity micro manager                        |
//+------------------------------------------------------------------+
void EquityCheck(void)
  {
    string ecComment         = "";
    
    if (LotCount(OP_BUY,Loss)>0.00)
      if (LotValue(OP_BUY,Lowest,InEquity)<-ordEQMinTarget)
        ecComment            = "Long";
        //Pause("Check your Long positions","Equity Check");

    if (LotCount(OP_SELL,Loss)>0.00)
      if (LotValue(OP_SELL,Lowest,InEquity)<-ordEQMinTarget)
        Append(ecComment,"Short","\\");
        //Pause("Check your Short positions","Equity Check");

    if (StringLen(ecComment)>0)
      ecComment              ="Check your "+ecComment+" Positions";
    else
      ecComment              = "OK";
      
    UpdateLabel("lbEQCheck",ecComment,BoolToInt(ecComment=="OK",clrLawnGreen,clrRed),16);
  }

//+------------------------------------------------------------------+
//| ProfitCheck - Add ticket to Major entry array                    |
//+------------------------------------------------------------------+
void ProfitCheck(int Action)
  {
    double pcLotsToClose  = fmin(LotCount(Action,Total),LotSize());
    
    if (LotValue(Action,Net,InEquity)>(ordEQMinTarget*2))
      for (int ord=0;ord<OrdersTotal();ord++)
      {
        if (CloseOrders(CloseMax,Action,"ProfitCheck"))
        {
          Print("Closed Order: "+IntegerToString(OrderTicket())+" Lots: "+DoubleToStr(OrderLots(),2));
          pcLotsToClose -= OrderLots();
        }

        if (pcLotsToClose<=0.00)
          return;
      }
  }

//+------------------------------------------------------------------+
//| AddTicket - Add ticket to Major entry array                      |
//+------------------------------------------------------------------+
void AddTicket(int Action)
  {
    if (OrderFulfilled(Action))
      kill.Add(ordOpen.Ticket);
  }

//+------------------------------------------------------------------+
//| CloseTicket - Closes profitable tickets on Major entry array     |
//+------------------------------------------------------------------+
void CloseTicket(int Action)
  {
    int ctCount     = kill.Count;
    int ctTicket[];
    
    kill.Copy(ctTicket);
    
    for (int ct=0; ct<ctCount; ct++)
      if (OrderSelect(ctTicket[ct],SELECT_BY_TICKET,MODE_TRADES))
      {
        if (OrderCloseTime()>0)
          kill.Delete(kill.Find(ctTicket[ct]));
        else
        if (OrderType()==Action && OrderProfit()+OrderSwap()+OrderCommission()>0.00)
          if (CloseOrder(ctTicket[ct],true))
            kill.Delete(kill.Find(ctTicket[ct]));
      }
      else kill.Delete(kill.Find(ctTicket[ct]));
  }

//+------------------------------------------------------------------+
//| EventCheck - Scan for entry/exit positions                       |
//+------------------------------------------------------------------+
void EventCheck(int Event)
  {
    switch (Event)
    {
      case Term:         hmTradeDir      = pfractal[Term].Direction;
                         hmTradeBias     = BoolToInt(pfractal[Term].Direction==DirectionUp,OP_BUY,OP_SELL);

                         NewArrow(BoolToInt(hmTradeDir==DirectionUp,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN),DirColor(pfractal[Term].Direction,clrYellow,clrRed),"TermTrigger");
                         OrderCheck(hmTradeBias,NewOrder,"Term Trigger");
                         break;

      case Trend:        OrderCheck(Action(pfractal[Term].Direction,InDirection,InContrarian),NewOrder,"Trend Trigger");
                         ProfitCheck(Action(pfractal[Term].Direction));
                         Pause("New trend detected","Trend Trigger");
                         break;

      case Minor:        CloseTicket(Action(pfractal[Term].Direction,InDirection));
                         Pause("New minor detected","Minor Trigger");
                         break;

      case Major:        //NewArrow(BoolToInt(hmTradeDir==DirectionUp,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN),DirColor(pfractal[Term].Direction,clrYellow,clrRed),"TrendTrigger");
                         CloseTicket(Action(pfractal[Term].Direction,InDirection));
                         OrderCheck(Action(pfractal[Term].Direction,InDirection,InContrarian),NewOrder,"Major Trigger");
                         AddTicket(Action(pfractal[Term].Direction,InDirection,InContrarian));
                         Pause("New major term ("+ActionText(Action(pfractal[Term].Direction,InDirection,InContrarian))+") detected","Major Trigger");
                         break;

      case Divergent:    break;
    }
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    if (pfractal.Event(NewMinor))
      if (pfractal.Event(NewTerm))
        EventCheck(Term);
      else
        EventCheck(Minor);
    else
    if (pfractal.Event(NewMajor))
      if (pfractal.Event(NewTrend))
        EventCheck(Trend);
      else
        EventCheck(Major);
    else
    if (pfractal.Event(NewTerm))
      EventCheck(Divergent);
    else
    if (pfractal.Event(NewBoundary))
      EquityCheck();
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0] == "SHOW")
      if (StringSubstr(Command[1],0,4) == "LINE")
      {
         hmShowLineType    = NoValue;

         if (Command[2] == "ORIGIN")
           hmShowLineType    = Origin;

         if (Command[2] == "TREND")
           hmShowLineType    = Trend;

         if (Command[2] == "TERM")
           hmShowLineType    = Term;
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
    
    NewLine("pfBase");
    NewLine("pfRoot");
    NewLine("pfExpansion");

    NewLabel("lbEQCheck","",5,20);
    NewLine("lnPivot");
    
    kill.AutoExpand    = true;
    kill.Truncate      = false;
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pfractal;
    delete fractal;
    delete kill;
  }