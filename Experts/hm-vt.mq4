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
#include <Class\Session.mqh>

//--- Input params
input string    appHeader          = "";    //+------ Application inputs ------+
input int       inpMarketIdle      = 50;    // Market Idle Alert (pipMA periods)

input string    PipMAHeader        = "";    //+------ PipMA inputs ------+
input int       inpDegree          = 6;     // Degree of poly regression
input int       inpPeriods         = 200;   // Number of poly regression periods
input double    inpTolerance       = 0.5;   // Trend change tolerance (sensitivity)

input string    fractalHeader      = "";    //+------ Fractal inputs ------+
input int       inpRangeMax        = 120;   // Maximum fractal pip range
input int       inpRangeMin        = 60;    // Minimum fractal pip range
input int       inpRangeLT         = 600;   // Long term fractal pip range
input int       inpRangeST         = 300;   // Short term fractal pip range

input string    SessionHeader      = "";    //+---- Session Hours -------+
input int       inpAsiaOpen        = 1;     // Asian market open hour
input int       inpAsiaClose       = 10;    // Asian market close hour
input int       inpEuropeOpen      = 8;     // Europe market open hour
input int       inpEuropeClose     = 18;    // Europe market close hour
input int       inpUSOpen          = 14;    // US market open hour
input int       inpUSClose         = 23;    // US market close hour


//--- Class defs
  CFractal     *fractal            = new CFractal(inpRangeMax,inpRangeMin);
  CFractal     *lfractal           = new CFractal(inpRangeLT,inpRangeST);
  CPipFractal  *pfractal           = new CPipFractal(inpDegree,inpPeriods,inpTolerance,fractal);

  CSession     *session[SessionTypes];
  CSession     *leadSession;

  int           pfPolyDir          = DirectionNone;

  int           hmShowLineType     = NoValue;    
  int           hmOrderAction      = OP_NO_ACTION;
  string        hmOrderReason      = "";
  
  ReservedWords EventClass[WordCount];
  
//+------------------------------------------------------------------+
//| CallPause - pauses based on class level events                   |
//+------------------------------------------------------------------+
void CallPause(ReservedWords Class, EventType Event, string Indicator, int Action=OP_NO_ACTION)
  {
    int     cpResponse;
    bool    cpContrarian   = false;
    string  cpMessage      = EnumToString(Event)+" alert detected on "+Indicator+"\n";
    int     cpStyle        = BoolToInt(Action==OP_NO_ACTION,MB_OKCANCEL|MB_ICONEXCLAMATION,MB_YESNOCANCEL|MB_ICONQUESTION);
    
    if (Action!=OP_NO_ACTION)
      Append(cpMessage,ActionText(Action)+" triggered, click Yes to trade, No for contrarian","\n");
      
    if (EventClass[Class])
    {
      cpResponse = Pause(cpMessage,EnumToString(Class)+" Alert",cpStyle);
      
      switch (cpStyle)
      {
        case MB_OKCANCEL|MB_ICONEXCLAMATION:  if (cpResponse==IDCANCEL)
                                                EventClass[Class] = false;
                                              break;

        default:  if (cpResponse==IDCANCEL)
                    return;

                  if (cpResponse==IDNO)
                    cpContrarian      = true;
                  
                  OpenOrder(Action(Action,InAction,cpContrarian),Indicator+" "+EnumToString(Event));
      }
    }
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    fractal.Update();
    lfractal.Update();
    pfractal.Update();
    
    pfractal.ShowFiboArrow();

    for (SessionType type=Asia;type<SessionTypes;type++)
    {
      session[type].Update();
            
      if (type<Daily)
        if (session[type].IsOpen())
          leadSession    = session[type];
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {    
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
                       UpdateLine("pfExpansion",0.00,STYLE_DOT,clrNONE);
                       break;
    }
    
//    UpdatePriceLabel("hmIdle",hmIdlePrice,DirColor(hmIdleDir,clrYellow,clrRed));
//    UpdatePriceLabel("hmTrade(e)",hmTradePrice,DirColor(hmTradeDir,clrYellow,clrRed));    
//    UpdatePriceLabel("hmTrade(r)",hmTradePrice,DirColor(hmTradeDir,clrYellow,clrRed));    
  }

//+------------------------------------------------------------------+
//| EventCheck - Scan for entry/exit positions                       |
//+------------------------------------------------------------------+
void EventCheck(int Event)
  {
    static int ecDivergent    = 0;
    static int ecResume       = 0;
    static int ecTradeState   = NoState;
    
    switch (Event)
    {
      case Divergent:    //NewArrow(BoolToInt(pfractal[Term].Direction==DirectionUp,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN),
                         //        +DirColor(pfractal[Term].Direction,clrYellow,clrRed),"Term Divergence("+IntegerToString(ecDivergent++)+")");
                         //Pause("Divergences do occur!","Divergent Trigger");
                         
                         //OpenOrder(Action(pfractal[Term].Direction,InDirection),"Scalp");
                         break;

      case Term:         //OpenDCAPlan(Action(pfractal[Term].Direction,InDirection,InContrarian),ordEQMinTarget,CloseAll);
                         break;

      case Trend:        //Pause("New "+EnumToString((RetraceType)Event)+" detected","Trend Trigger");
                         break;

      case Minor:        break;
      
      case Major:        //CloseOrders(CloseMax,Action(pfractal[Term].Direction,InDirection),"Major PT");
                         break;

      case Boundary:     //Pause("New "+EnumToString((ReservedWords)Event)+" detected","Boundary Trigger");
                         break;

    }
  }

//+------------------------------------------------------------------+
//| ExecPipFractal - Micro management at the pfractal level          |
//+------------------------------------------------------------------+
void ExecPipFractal(void)
  {
    if (fmin(pfractal.Age(RangeLow),pfractal.Age(RangeHigh))==1)
      SetEquityHold(Action(pfractal[Term].Direction,InDirection),3,true);
      
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
      EventCheck(Boundary);
      
   if (pfractal.Event(NewHigh))
     if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Top)))
       if (IsChanged(pfPolyDir,DirectionUp))
         CallPause(Minor,NewBoundary,"PipFractal (Poly)",OP_BUY);
         
   if (pfractal.Event(NewLow))
     if (IsEqual(pfractal.Poly(Head),pfractal.Poly(Bottom)))
       if (IsChanged(pfPolyDir,DirectionDown))
         CallPause(Minor,NewBoundary,"PipFractal (Poly)",OP_SELL);
  }
  
//+------------------------------------------------------------------+
//| ExecFractal - Macro management at fractal level                  |
//+------------------------------------------------------------------+
void ExecFractal(void)
  {
    if (fractal.Event(NewMajor))
      CallPause(Major,NewMajor,"Fractal");
  }

//+------------------------------------------------------------------+
//| ExecSession - Test for session events                            |
//+------------------------------------------------------------------+
void ExecSession(void)
  {
    static int esIdx      = 0;
    
    if (leadSession.Event(NewDirection))
      if (leadSession.SessionHour()>2)
        CallPause(Major,NewBreakout,"Session",Action(leadSession[ActiveSession].Direction,InDirection));
        //if (OpenOrder(Action(leadSession[ActiveSession].Direction,InDirection),"Session"))
       // NewArrow(BoolToInt(leadSession[ActiveSession].Direction==DirectionUp,SYMBOL_ARROWUP,SYMBOL_ARROWDOWN),
       //          DirColor(leadSession[ActiveSession].Direction,clrYellow,clrRed),
       //          EnumToString(leadSession.Type())+":"+IntegerToString(esIdx++));
    
  }

//+------------------------------------------------------------------+
//| ExecOrders - Processes Open Order triggers                       |
//+------------------------------------------------------------------+
void ExecOrders(void)
  {
    int  eoMBResponse   = NoValue;
    bool eoContrarian   = false;
    
    if (hmOrderAction!=OP_NO_ACTION)
      if (pfractal.HistoryLoaded())
      {
        eoMBResponse        = Pause("Shall I "+ActionText(hmOrderAction)+"?","Time to Trade!",MB_YESNOCANCEL|MB_ICONQUESTION);
        
        switch (eoMBResponse)
        {
          case IDYES:     eoContrarian   = false;
                          break;
                        
          case IDNO:      eoContrarian   = true;
                          break;
                        
          case IDCANCEL:  hmOrderAction  = OP_NO_ACTION;
                          return;
        }
                                
        if (OpenOrder(Action(hmOrderAction,InAction,eoContrarian),hmOrderReason))
        {
          hmOrderAction     = OP_NO_ACTION;
          hmOrderReason     = "";
        }
      }
  }

//+------------------------------------------------------------------+
//| ExecRiskManagement - Corrects trade imbalances                   |
//+------------------------------------------------------------------+
void ExecRiskManagement(void)
  {
//    if (LotValue(OP_SELL,Loss,InEquity)<-ordEQMinProfit)
//     if (LotValue(OP_SELL,Net,InEquity)>=0.00)
 
//        Pause("DCA Check (Short)","DCA Check");
//
//    if (LotValue(OP_BUY,Loss,InEquity)<-ordEQMinProfit)
//      if (LotValue(OP_BUY,Net,InEquity)>=0.00)
//        Pause("DCA Check (Long)","DCA Check");
  }

//+------------------------------------------------------------------+
//| ExecProfitManagement - Protects trade profits                    |
//+------------------------------------------------------------------+
void ExecProfitManagement(void)
  {
    int epmTickets[1]   = {0};
    
    for (int ord=0;ord<OrdersTotal();ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (TicketValue(OrderTicket(),InEquity)>ordEQMinTarget)
        {
          ArrayResize(epmTickets,ArraySize(epmTickets)+1);
          epmTickets[ArraySize(epmTickets)-1] = OrderTicket();
        }

    for (int ord=0;ord<ArraySize(epmTickets);ord++)
      CloseOrder(epmTickets[ord],true);
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
//    if (session[Daily].Event(NewDay))
//      Pause ("Wake up, it''s a New Day","Alarm Clock");
//      
//    if (leadSession.Event(SessionOpen))
//      Pause ("Ahoy, Matey, the Market is Now OPEN","Alarm Clock");
      
    ExecPipFractal();
    ExecFractal();
    ExecSession();
    ExecRiskManagement();
    ExecProfitManagement();
    ExecOrders();
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
    
    session[Daily]        = new CSession(Daily,inpAsiaOpen,inpUSClose);
    session[Asia]         = new CSession(Asia,inpAsiaOpen,inpAsiaClose);
    session[Europe]       = new CSession(Europe,inpEuropeOpen,inpEuropeClose);
    session[US]           = new CSession(US,inpUSOpen,inpUSClose);
    
    leadSession           = session[Daily];

    ArrayInitialize(EventClass,true);
    
    NewLine("pfBase");
    NewLine("pfRoot");
    NewLine("pfExpansion");
    
    NewPriceLabel("hmTrade(r)");
    NewPriceLabel("hmTrade(e)");
    NewPriceLabel("hmIdle",0,True);
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pfractal;
    delete fractal;
    delete lfractal;
        
    for (SessionType type=Asia;type<SessionTypes;type++)
      delete session[type];
  }