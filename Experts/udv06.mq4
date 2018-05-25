//+------------------------------------------------------------------+
//|                                                        ud-v5.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <manual.mqh>
#include <Class\PipFractal.mqh>
#include <Class\SessionArray.mqh>

//--- Display constants
enum DisplayConstants
{
  udDisplayEvents,      // Display setting for application comments
  udDisplayFractal,     // Display setting for fractal comments
  udDisplayPipMA,       // Display setting for PipMA comments
  udDisplayOrders       // Display setting for Order comments
};

input string EAHeader                = "";    //+---- Application Options -------+
input double inpDailyTarget          = 3.6;   // Daily target
input int    inpMaxMargin            = 40;    // Maximum trade margin (volume)
  
input string fractalHeader           = "";    //+------ Fractal Options ---------+
input int    inpRangeMin             = 60;    // Minimum fractal pip range
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpPeriodsLT            = 240;   // Long term regression periods

input string RegressionHeader        = "";    //+------ Regression Options ------+
input int    inpDegree               = 6;     // Degree of poly regression
input int    inpSmoothFactor         = 3;     // MA Smoothing factor
input double inpTolerance            = 0.5;   // Directional sensitivity
input int    inpPipPeriods           = 200;   // Trade analysis periods (PipMA)
input int    inpRegrPeriods          = 24;    // Trend analysis periods (RegrMA)

input string SessionHeader           = "";    //+---- Session Hours -------+
input int    inpAsiaOpen             = 1;     // Asian market open hour
input int    inpAsiaClose            = 10;    // Asian market close hour
input int    inpEuropeOpen           = 8;     // Europe market open hour
input int    inpEuropeClose          = 18;    // Europe market close hour
input int    inpUSOpen               = 14;    // US market open hour
input int    inpUSClose              = 23;    // US market close hour

  //--- Strategy enums
  enum StrategyType
  {
    NoStrategy,
    Hedge,
    Recapture,
    Build,
    Reduce
  };

  struct TradePlanRec
  {
    StrategyType      Strategy;
    int               Action;
    double            EntryPrice;
    double            ExitPrice;
    double            LossPrice;
    bool              Executed;
  }
  
  struct OpenOrderRec
  {
    int               Action;
    int               Ticket;
    double            Lots;
    double            Margin;
    double            MaxEquity;
    double            MinEquity;
    int               EquityDir;
    EventType         EquityEvent;
  };
  
  //--- Class defs
  CFractal           *fractal                = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal               = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);
  CSessionArray      *session[SessionTypes];
  CEvent             *udEvent                = new CEvent();
  CEvent             *udOrderEvent           = new CEvent();
  

  //--- Operational variables
  int                 udDisplay              = udDisplayEvents;
  SessionType         udLeadSession;
  bool                udActiveEvent;
  bool                udSessionClosing;
  int                 udFiboLevel            = FiboRoot;
  
  //--- Collections
  OpenOrderRec        udOpenOrders[];
  TradePlanRec        udTradePlan[24];
  
  //--- Trade Execution operationals
  int                 udTradeAction          = OP_NO_ACTION;
  Strategy            udStrategy             = NoStrategy;
  bool                udTradePending         = false;
  
//+------------------------------------------------------------------+
//| DisplayOrders - Displays open order data                         |
//+------------------------------------------------------------------+
void DisplayOrders(void)
  {
    string doOrders = "";
    
    if (ArraySize(udOpenOrders)>0)
    {
      doOrders       = "\nOrders\n";
      
      for (int ord=0;ord<ArraySize(udOpenOrders);ord++)
         doOrders   += ActionText(udOpenOrders[ord].Action)+" "
                    +  IntegerToString(udOpenOrders[ord].Ticket)+" "
                    +  DoubleToStr(udOpenOrders[ord].Lots,2)+" "
                    +  DoubleToStr(udOpenOrders[ord].Margin,1)+" "
                    +  DoubleToStr(udOpenOrders[ord].MaxEquity,1)+" "
                    +  DoubleToStr(udOpenOrders[ord].MinEquity,1)+" "
                    +  DirText(udOpenOrders[ord].EquityDir)+"\n";
    }
    
    Comment(doOrders);
  }
  
//+------------------------------------------------------------------+
//| DisplayEvents - Displays events and other session data           |
//+------------------------------------------------------------------+
void DisplayEvents(void)
  {
    string deEvents;

    deEvents        += "\n------ Factors ------";

    deEvents        += "\n";

    deEvents        += "\n------ Action ------";
        
    if (udTradeAction==OP_NO_ACTION)
      deEvents      += "\n  Waiting\n";
    else
      deEvents      += "\n  "+ActionText(udTradeAction)
                    + " "+BoolToStr(udTradePending,"Triggered","Inactive")
                    + "\n  "+BoolToStr(udTradeAction==session[Daily].TradeBias(),"","CONFLICT")
                    + "\n";

    //--- Format event display
    if (udActiveEvent)
    {
      for (SessionType type=Asia; type<SessionTypes; type++)
        if (session[type].ActiveEvent())
        {
          deEvents +="\n "
                   + EnumToString(type)+"\n"
                   + "  Bias: "+proper(ActionText(session[type].TradeBias()))+"\n"
                   + "  State: "+EnumToString(session[type].State(Prior))
                   + "("+IntegerToString(session[type].Active().Age)+")"+"\n";
     
          deEvents += "\n------ Events ------";

          for (EventType event=0;event<EventTypes;event++)
            if (session[type].Event(event))
               deEvents  += "\n    "+EnumToString(event);
               
          deEvents  += "\n"   ;
        }

      Comment(deEvents);
    }
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string  rsLeadText       = EnumToString(session[udLeadSession].Type())+" "+proper(ActionText(session[Daily].TradeBias()));
    
    for (SessionType type=Asia; type<SessionTypes; type++)
    {
      UpdateLabel("lbSess"+EnumToString(type),EnumToString(type)+" ("+IntegerToString(BoolToInt(session[type].SessionIsOpen(),session[type].SessionHour()))+")",BoolToInt(session[type].SessionIsOpen(),clrYellow,clrDarkGray));
      UpdateDirection("lbDir"+EnumToString(type),session[type].Direction(Term),DirColor(session[type].Direction(Term)));
      UpdateLabel("lbState"+EnumToString(type),proper(DirText(session[type].Direction(Trend)))+" "+EnumToString(session[type].State(Trend)));
    }
  
    UpdateLabel("lbTradeBias",rsLeadText,BoolToInt(session[udLeadSession].SessionIsOpen(),clrWhite,clrDarkGray),12);
    UpdatePriceLabel("lbPipMAPivot",pfractal.Pivot(Price),DirColor(pfractal.Direction(Pivot)));

    switch(udDisplay)
    {
      case udDisplayEvents:   DisplayEvents();
                              break;
      case udDisplayFractal:  fractal.RefreshScreen();
                              break;
      case udDisplayPipMA:    pfractal.RefreshScreen();
                              break;
      case udDisplayOrders:   DisplayOrders();
    }
   
//    if (pfractal.Event(NewPivot))
//      Pause("New PipMA Pivot hit\nDirection: "+DirText(pfractal.Direction(Pivot)),"Event() Check");

//    if (udEvent[NewPullback] || udEvent[NewRally])
//      Pause("New Pullback/Rally detected","Pullback/Rally Check");
  }

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {    
    udEvent.ClearEvents();

    udActiveEvent         = false;
    udSessionClosing      = false;
    udLeadSession         = Daily;
        
    fractal.Update();
    pfractal.Update();

    for (SessionType type=Asia;type<SessionTypes;type++)
    {
      session[type].Update();
      
      if (session[type].ActiveEvent())
      {
        udActiveEvent    = true;

        for (EventType event=0;event<EventTypes;event++)
          if (session[type].Event(event))
            udEvent.SetEvent(event);
      }
            
      if (type<Daily)
        if (session[type].SessionIsOpen())
          udLeadSession    = type;
    }

    if (TimeHour(Time[0])>session[udLeadSession].SessionHour()-4)
      udSessionClosing     = true;
  }

//+------------------------------------------------------------------+
//| ExecuteTrades - Opens new trades based on the pipMA trigger      |
//+------------------------------------------------------------------+
bool SafeMargin(int Action)
  {
    return true;
  }

//+------------------------------------------------------------------+
//| CalcFiboEvents - Analyzes fibo level and sets fibo change events |
//+------------------------------------------------------------------+
void CalcFiboEvents(void)
  {
    if (fractal.Event(NewReversal) || fractal.Event(NewBreakout) || fractal.Fibonacci(Base,Expansion,Now)>FiboPercent(Fibo100))
      udFiboLevel           = FiboRoot;
    else
    if (fractal.Fibonacci(Expansion,Expansion,Now)<FiboPercent(Fibo23))
    {
      if (udFiboLevel==Fibo61)
        if (IsChanged(udFiboLevel,Fibo23))
          udEvent.SetEvent(NewFibonacci);
    }
    else
    if (fractal.Fibonacci(Expansion,Retrace,Now)>FiboPercent(Fibo61))
    {
      if (udFiboLevel==Fibo50)
        if (IsChanged(udFiboLevel,Fibo61))
          udEvent.SetEvent(NewFibonacci);
    }
    else
    if (fractal.Fibonacci(Expansion,Retrace,Now)>FiboPercent(Fibo50))
      if (udFiboLevel==FiboRoot)
        if (IsChanged(udFiboLevel,Fibo50))
          udEvent.SetEvent(NewFibonacci);
  }

//+------------------------------------------------------------------+
//| CalcOrderEvents - Analyzes open positions; sets order events     |
//+------------------------------------------------------------------+
void CalcOrderEvents(void)
  {
    double        coeOrderMajor     = ordEQMinTarget;
    double        coeOrderMinor     = ordEQMinProfit;
    
    OpenOrderRec  coeOpenOrders[];
    
    udOrderEvent.ClearEvents();
    
    for (int ord=0;ord<OrdersTotal();ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol()==Symbol())
          if (OrderType()==OP_BUY || OrderType()==OP_SELL)
          {
            ArrayResize(coeOpenOrders,ArraySize(coeOpenOrders)+1);
            coeOpenOrders[ArraySize(coeOpenOrders)-1].Action      = OrderType();
            coeOpenOrders[ArraySize(coeOpenOrders)-1].Ticket      = OrderTicket();
            coeOpenOrders[ArraySize(coeOpenOrders)-1].Lots        = OrderLots();

            coeOpenOrders[ArraySize(coeOpenOrders)-1].Margin      = TicketValue(OrderTicket(),InMargin);
            coeOpenOrders[ArraySize(coeOpenOrders)-1].MaxEquity   = TicketValue(OrderTicket(),InEquity);
            coeOpenOrders[ArraySize(coeOpenOrders)-1].MinEquity   = TicketValue(OrderTicket(),InEquity);
            coeOpenOrders[ArraySize(coeOpenOrders)-1].EquityDir   = DirectionNone;
            coeOpenOrders[ArraySize(coeOpenOrders)-1].EquityEvent = NoEvent;

            for (int ticket=0;ticket<ArraySize(udOpenOrders);ticket++)
              if (udOpenOrders[ticket].Ticket==OrderTicket())
              {
                //--- Handle equity boundary alerts
                if (IsHigher(TicketValue(OrderTicket(),InEquity),udOpenOrders[ticket].MaxEquity))
                  udOrderEvent.SetEvent(NewHigh);
                    
                if (IsLower(TicketValue(OrderTicket(),InEquity),udOpenOrders[ticket].MinEquity))
                  udOrderEvent.SetEvent(NewLow);
                            
                //--- Handle major equity alerts
                if (IsHigher(fabs(TicketValue(OrderTicket(),InEquity)),coeOrderMajor,NoUpdate,3))
                {
                  if (IsChanged(udOpenOrders[ticket].EquityDir,Direction(TicketValue(OrderTicket(),InEquity))))
                  {
                    udOrderEvent.SetEvent(NewDirection);
                    udOrderEvent.SetEvent(NewMajor);
                  }

                  if (IsChanged(udOpenOrders[ticket].EquityEvent,NewMajor))
                    udOrderEvent.SetEvent(NewMajor);                  
                }
                else

                //--- Handle minor equity alerts
                if (IsHigher(fabs(TicketValue(OrderTicket(),InEquity)),coeOrderMinor,NoUpdate,3))
                {
                  if (IsChanged(udOpenOrders[ticket].EquityDir,Direction(TicketValue(OrderTicket(),InEquity))))
                  {
                    udOrderEvent.SetEvent(NewDirection);
                    udOrderEvent.SetEvent(NewMinor);
                  }

                  if (udOpenOrders[ticket].EquityEvent!=NewMajor)
                    if (IsChanged(udOpenOrders[ticket].EquityEvent,NewMinor))
                      udOrderEvent.SetEvent(NewMinor);                  
                }
                
                //--- Post updated equity change record
                coeOpenOrders[ArraySize(coeOpenOrders)-1]=udOpenOrders[ticket];
              }
          }

    ArrayResize(udOpenOrders,ArraySize(coeOpenOrders));
    ArrayCopy(udOpenOrders,coeOpenOrders);
  }
  
//+------------------------------------------------------------------+
//| ExecuteTrades - Opens new trades based on the pipMA trigger      |
//+------------------------------------------------------------------+
void ExecuteTrades(void)
  {
  }

//+------------------------------------------------------------------+
//| CreateTradePlan - Sets the daily trade strategy up               |
//+------------------------------------------------------------------+
void CreateTradePlan(void)
  {
  }

//+------------------------------------------------------------------+
//| CalcStrategy - Analyzes events/boundaries; sets trade action     |
//+------------------------------------------------------------------+
void CalcStrategy(void)
  {
    static bool           csSessionClosing;

    static EventType      csSessionEvent;
    static EventType      csOrderEvent;
    static EventType      csFractalEvent;

    string                csEventText   = "";
        
    if (session[Daily].Event(NewDay))
      Append(csEventText,"End of Trading Day","\n");

    if (session[Asia].Event(SessionOpen))
    {
      Append(csEventText,"Asia Market Open","\n");
      CreateTradePlan();
    }
    
    if (udEvent[NewDirection])
      if (session[udLeadSession].Event(NewDirection))
      {
        if (session[udLeadSession].SessionHour()>3)
          Append(csEventText,"Term Change After Mid (Lead Session:"+EnumToString(session[udLeadSession].Type()),")\n");
      }
      else
        Append(csEventText,"Term Change After Mid (Off-Session)","\n");
      
    if (IsChanged(csSessionClosing,udSessionClosing))
      Append(csEventText,"Session Close Warning","\n");
      
    if (udEvent[NewDivergence])
      Append(csEventText,"Session Divergence Warning","\n");   

    if (udEvent[NewBreakout])
      if (IsChanged(csSessionEvent,NewBreakout))
        Append(csEventText,"Breakout Checkpoint","\n");

    if (udEvent[NewReversal])
      if (IsChanged(csSessionEvent,NewReversal))
        Append(csEventText,"Reversal Checkpoint","\n");

    if (udOrderEvent[NewMinor])
      if (IsChanged(csOrderEvent,NewMinor))
        Append(csEventText,"Minor Order Change","\n");
        
    if (udOrderEvent[NewDirection])
      Append(csEventText,"Order Equity Change","\n");

    if (udOrderEvent[NewMajor])
      if (IsChanged(csOrderEvent,NewMajor))
        Append(csEventText,"Major Order Event","\n");

    if (fractal.Event(NewMinor))
      if (IsChanged(csFractalEvent,NewMinor))
        Append(csEventText,"New Fractal Minor","\n");
    
    if (fractal.Event(NewMajor))
      if (IsChanged(csFractalEvent,NewMajor))
        Append(csEventText,"New Fractal Major","\n");
        
    if (udEvent[NewFibonacci])
      Append(csEventText,"New Fibonacci Level: "+DoubleToStr(FiboPercent(udFiboLevel,InPercent),1),"%\n");

    if (pfractal.Event(NewPivot))
      Append(csEventText,"Pivot Price Change");

    if (csEventText!="")
      Pause(csEventText,"Event()");
  }

//+------------------------------------------------------------------+
//| Execute - Acts on events to execute trades                       |
//+------------------------------------------------------------------+
void Execute(void)
  {
    CalcFiboEvents();
    CalcOrderEvents();
    CalcStrategy();
    ExecuteTrades(); 
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
    if (Command[0]=="SHOW")
    {
      if (Command[1]=="FRACTAL") udDisplay=udDisplayFractal;
      if (Command[1]=="FIBO")    udDisplay=udDisplayFractal;
      if (Command[1]=="FIB")     udDisplay=udDisplayFractal;
      if (Command[1]=="PIPMA")   udDisplay=udDisplayPipMA;
      if (Command[1]=="PIP")     udDisplay=udDisplayPipMA;
      if (Command[1]=="EVENTS")  udDisplay=udDisplayEvents;
      if (Command[1]=="EVENT")   udDisplay=udDisplayEvents;
      if (Command[1]=="EV")      udDisplay=udDisplayEvents;
      if (Command[1]=="ORD")     udDisplay=udDisplayOrders;
      if (Command[1]=="ORDER")   udDisplay=udDisplayOrders;
      if (Command[1]=="ORDERS")  udDisplay=udDisplayOrders;
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
        
    session[Daily]        = new CSessionArray(Daily,inpAsiaOpen,inpUSClose);
    session[Asia]         = new CSessionArray(Asia,inpAsiaOpen,inpAsiaClose);
    session[Europe]       = new CSessionArray(Europe,inpEuropeOpen,inpEuropeClose);
    session[US]           = new CSessionArray(US,inpUSOpen,inpUSClose);
    
    //--- Initialize trade boundaries
    NewLabel("lbSessDaily","Daily",105,62,clrDarkGray,SCREEN_LR);
    NewLabel("lbSessAsia","Asia",105,51,clrDarkGray,SCREEN_LR);
    NewLabel("lbSessEurope","Europe",105,40,clrDarkGray,SCREEN_LR);
    NewLabel("lbSessUS","US",105,29,clrDarkGray,SCREEN_LR);
    
    NewLabel("lbDirDaily","",85,62,clrDarkGray,SCREEN_LR);
    NewLabel("lbDirAsia","",85,51,clrDarkGray,SCREEN_LR);
    NewLabel("lbDirEurope","",85,40,clrDarkGray,SCREEN_LR);
    NewLabel("lbDirUS","",85,29,clrDarkGray,SCREEN_LR);

    NewLabel("lbStateDaily","",5,62,clrDarkGray,SCREEN_LR);
    NewLabel("lbStateAsia","",5,51,clrDarkGray,SCREEN_LR);
    NewLabel("lbStateEurope","",5,40,clrDarkGray,SCREEN_LR);
    NewLabel("lbStateUS","",5,29,clrDarkGray,SCREEN_LR);

    NewLabel("lbTradeBias","",5,10,clrDarkGray,SCREEN_LR);
    
    NewLine("lnTrSupport");
    NewLine("lnTrResistance");
    NewLine("lnTrPullback");
    NewLine("lnTrRally");
    
    NewPriceLabel("lbPipMAPivot");
    NewLabel("lbEquity","",5,5,clrWhite,SCREEN_LL);
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete pfractal;
    delete udEvent;
    delete udOrderEvent;
    
    for (SessionType type=Asia;type<SessionTypes;type++)
      delete session[type];
  }