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
  udDisplayPipMA        // Display setting for PipMA comments
};

input string EAHeader                = "";    //+---- Application Options -------+
input double inpDailyTarget          = 3.6;   // Daily target
input int    inpMaxMargin            = 40;    // Maximum trade margin (volume)
input int    inpMaxVolatilityHour    = 10;    // Most volatile trading hour
input int    inpReversalHour         = 16;    // Most common reversal trading hour

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

  //--- Class defs
  CFractal           *fractal                = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal               = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal);
  CSessionArray      *session[SessionTypes];
  
  //--- Operational collections
  CEvent             *udEvent                = new CEvent();
  SessionType         udLeadSession;
  bool                udActiveEvent;

  //--- Operational variables
  int                 udDisplay              = udDisplayEvents;
  
  //--- Trade Execution operationals
  int                 udTradeBias            = OP_NO_ACTION;
  int                 udTradeAction          = OP_NO_ACTION;
  double              udTradePrice[2]        = {NoValue,NoValue};
  double              udTradeEntryPrice      = NoValue;
  bool                udTradePending         = false;
  
//+------------------------------------------------------------------+
//| IsChanged - Compares events to determine if a change occurred    |
//+------------------------------------------------------------------+
bool IsChanged(EventType &Compare, EventType Value)
  {
    if (Compare==Value)
      return (false);
      
    Compare = Value;
    return (true);
  }
  
//+------------------------------------------------------------------+
//| DisplayEvents - Displays events and other session data           |
//+------------------------------------------------------------------+
void DisplayEvents(void)
  {
    string deEvents  = "\n------ Action ------";

    if (udTradeAction==OP_NO_ACTION)
      deEvents      += "\n  Waiting\n";
    else
      deEvents      += "\n  "+ActionText(udTradeAction)
                    + " "+BoolToStr(udTradePending,"Triggered","Inactive")
                    + "\n";

    //--- Format event display
    if (udActiveEvent)
    {
      deEvents  += "\n------ Events ------";

      for (SessionType type=Asia; type<SessionTypes; type++)
        if (session[type].ActiveEvent())
        {
          deEvents +="\n "
                   + EnumToString(type)+" ("
                   + BoolToStr(session[type].SessionIsOpen(),proper(ActionText(session[type].TradeBias())),"Off-Session")+")";
     
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
    for (SessionType type=Asia; type<SessionTypes; type++)
    {
      UpdateLabel("lbSess"+EnumToString(type),EnumToString(type),BoolToInt(session[type].SessionIsOpen(),clrYellow,clrDarkGray));
      UpdateDirection("lbDir"+EnumToString(type),session[type].Direction(Term),DirColor(session[type].Direction(Term)));
      UpdateLabel("lbState"+EnumToString(type),proper(DirText(session[type].Direction(Trend)))+" "+EnumToString(session[type].State()));
    }
  
    if (session[udLeadSession].Event(SessionOpen))
      UpdateLabel("lbTradeBias",proper(ActionText(session[udLeadSession].TradeBias())),clrWhite,12);
    
    UpdatePriceLabel("lbPipMAPivot",pfractal.Pivot(Price),DirColor(pfractal.Direction(Pivot)));
    UpdateLine("lnTradeEntry",udTradeEntryPrice,STYLE_SOLID,DirColor(Direction(udTradeAction)));
    UpdateLine("lnTradePriceSell",udTradePrice[OP_SELL],STYLE_SOLID,clrMaroon);
    UpdateLine("lnTradePriceBuy",udTradePrice[OP_BUY],STYLE_SOLID,clrForestGreen);
    
//      UpdateLabel("lbEquity","Low:"+DoubleToStr(LotValue(OP_NO_ACTION,Lowest),1)+"  High:"+DoubleToStr(LotValue(OP_NO_ACTION,Highest),1));

    switch(udDisplay)
    {
      case udDisplayEvents:   DisplayEvents();
                              break;
      case udDisplayFractal:  fractal.RefreshScreen();
                              break;
      case udDisplayPipMA:    pfractal.RefreshScreen();
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
        if (session[type].Event(SessionOpen))
          udLeadSession    = type;
    }
  }

//+------------------------------------------------------------------+
//| UpdateTradePlan - Analyzes events/boundaries; sets trade action  |
//+------------------------------------------------------------------+
void UpdateTradePlan(void)
  {
    int  csoTradeBias       = udTradeBias;
    bool csoTradeDispute    = false;
    
    for (SessionType type=Asia;type<SessionTypes;type++)
    {
      if (session[type].Event(SessionOpen))
        switch (type)
        {
          case Daily:  //--- Reset boundaries; validate open positions
                       if (csoTradeBias==OP_NO_ACTION)
                         csoTradeBias      = session[type].TradeBias();
                       else  
                         csoTradeDispute   = IsChanged(csoTradeBias,session[type].TradeBias());
                       break;

          case Asia:   //--- Set asian boundaries and limits;
                       if (csoTradeBias==OP_NO_ACTION)
                         csoTradeBias      = session[type].TradeBias();
                       else  
                         csoTradeDispute   = IsChanged(csoTradeBias,session[type].TradeBias());
                       break;
        }
        
      if (session[type].Event(SessionClose))
        switch (type)
        {
          case Daily:  //--- Reset boundaries; validate open positions
                       udTradePrice[OP_BUY]  = session[Daily].Active().Resistance;
                       udTradePrice[OP_SELL] = session[Daily].Active().Support;
                       break;

          case Asia:   //--- Set asian boundaries and limits;
                       udTradePrice[OP_BUY]  = session[Daily].Active().Resistance;
                       udTradePrice[OP_SELL] = session[Daily].Active().Support;
                       break;
        }
    }

    if (csoTradeDispute)
      Pause("To trade or not to trade?","TradeDispute() Verification");
      
    if (IsChanged(udTradeBias,csoTradeBias))
      Pause("To manage risk or not to manage risk\nChanged to "+ActionText(csoTradeBias),"Trade Action Change() Verification");

    if (udEvent[NewPullback])
      udTradeAction    = OP_BUY;

    if (udEvent[NewRally])
      udTradeAction    = OP_SELL;

    if (udEvent[NewBreakout] || udEvent[NewReversal])
    {
      if (udEvent[NewHigh])
        udTradeAction  = OP_BUY;
      if (udEvent[NewLow])
        udTradeAction  = OP_SELL;
    }

    if (pfractal.Event(NewPivot))
      udTradePrice[Action(pfractal.Direction(Pivot))] = pfractal.Pivot(Price);
  }

//+------------------------------------------------------------------+
//| ExecuteTrades - Opens new trades based on the pipMA trigger      |
//+------------------------------------------------------------------+
bool SafeMargin(int Action)
  {
    return true;
  }

//+------------------------------------------------------------------+
//| PriceOOB - returns true if the market price is out-of-bounds     |
//+------------------------------------------------------------------+
bool PriceOOB(void)
  {
    if (IsHigher(Bid,udTradePrice[OP_SELL]))
    {
      udTradeEntryPrice      = udTradePrice[OP_SELL]-Pip(1,InPoints);
      return true;
    }

    if (IsLower(Ask,udTradePrice[OP_BUY]))
    {
      udTradeEntryPrice      = udTradePrice[OP_BUY]+Pip(1,InPoints);
      return true;
    }
      
    return (false);
  }

//+------------------------------------------------------------------+
//| ExecuteTrades - Opens new trades based on the pipMA trigger      |
//+------------------------------------------------------------------+
void ExecuteTrades(void)
  {
    static EventType   etEvent  = EventTypes;
    
    if (udEvent[NewDay])
      etEvent                   = EventTypes;
//      Pause ("We have a new day!","New Day");
      
    if (session[Asia].Event(SessionClose))
      Pause ("We have closure!","Asia Breakout Strategy");
      
    if (session[Europe].Event(NewBreakout))
      if (IsChanged(etEvent,NewBreakout))
        Pause ("We have a Euro Break!","What session does the breakout occur?");      

    if (session[Europe].Event(NewReversal))
      if (IsChanged(etEvent,NewReversal))
        Pause ("We have a Euro Reversal!","What session does the reversal occur?");      

/*    if (PriceOOB())
    {
      udTradePending                = true;
      Pause("I'm OOB\n Top: "+DoubleToStr(udTradePrice[OP_SELL],Digits)+"\n Bottom: "
                             +DoubleToStr(udTradePrice[OP_BUY],Digits),"OOB() Issue");
    }
      
    if (udTradePending)
    {
      //--- In-Bias trades
      if (udTradeBias==udTradeAction)
      {
        if (udTradeAction==OP_BUY)
          if (SafeMargin(OP_BUY))
            if (IsHigher(Ask,udTradeEntryPrice))
              if (OpenOrder(OP_BUY,"Safe Margin"))
              {
                udTradeEntryPrice   = NoValue;
                udTradeAction       = OP_NO_ACTION;
                udTradePending      = false;
              }
      }
    }
*/
  }

//+------------------------------------------------------------------+
//| Execute - Acts on events to execute trades                       |
//+------------------------------------------------------------------+
void Execute(void)
  {    
    UpdateTradePlan();
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
    udTradePrice[OP_SELL]  = session[Daily].Active().Resistance;
    udTradePrice[OP_BUY]   = session[Daily].Active().Support;
    
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
    
    NewLine("lnTradeEntry");
    NewLine("lnTradePriceSell");
    NewLine("lnTradePriceBuy");
    
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
    
    for (SessionType type=Asia;type<SessionTypes;type++)
      delete session[type];
  }