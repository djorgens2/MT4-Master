//+------------------------------------------------------------------+
//|                                                       man-v3.mq4 |
//|                                 Copyright 2017, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Dennis Jorgenson"
#property link      ""
#property version   "1.30"
#property strict

#include <manual.mqh>
#include <Class\Strategy.mqh>
#include <Class\PipFractal.mqh>

//-- EA config options
input string fractalHeader           = "";    //+------ Fractal Options ------+
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpRangeMin             = 60;    // Minimum fractal pip range

input string PipMAHeader             = "";    //+------ PipMA Options ------+
input int    inpDegree               = 6;     // Degree of poly regression
input int    inpPeriods              = 200;   // Number of poly regression periods
input double inpTolerance            = 0.5;   // Directional change sensitivity

//-- Class defs
  CFractal         *fractal          = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal      *pfractal         = new CPipFractal(inpDegree,inpPeriods,inpTolerance,fractal);
  CStrategy        *strategy         = new CStrategy(fractal,pfractal);

//-- Operational params
  int              display           = NoValue;
  
//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    fractal.Update();
    pfractal.Update();
    strategy.Update();
  }

//+------------------------------------------------------------------+
//| ShowAppData - Hijacks the comment for application metrics        |
//+------------------------------------------------------------------+
void ShowAppData(void)
  {
    strategy.Show();
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
    }
    
    if (IsChanged(rsLastDisplay,display))
    {
      Comment("No Data");
      
      UpdateLine("oTop",0.00,STYLE_SOLID,clrGoldenrod);
      UpdateLine("oBottom",0.00,STYLE_SOLID,clrSteelBlue);
      UpdateLine("oPrice",0.00,STYLE_SOLID,clrRed);
      UpdateLine("oBase",0.00,STYLE_SOLID,clrGoldenrod);
      UpdateLine("oRoot",0.00,STYLE_SOLID,clrSteelBlue);
      UpdateLine("oExpansion",0.00,STYLE_SOLID,clrRed);
      UpdateLine("oRetrace",0.00,STYLE_DOT,clrLightGray);
    }
    
    pfractal.ShowFiboArrow();
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static  bool eTrade = false;
    
    if (pfractal.Event(NewBoundary))
      eTrade    = true;
    else
    if (eTrade)
    {
//      Pause("Open a trade","TradeOpen()");
      if (pfractal.Direction(Tick)==DirectionUp)
      {
//        OpenOrder(OP_SELL,"Contrarian Sell");
        CloseOrders(CloseMax,OP_BUY,"TP-Buy");
      }
      if (pfractal.Direction(Tick)==DirectionDown)
      {
//        OpenOrder(OP_BUY,"Contrarian Buy");
        CloseOrders(CloseMax,OP_SELL,"TP-Sell");
      }
      eTrade    = false;
    }
    
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {
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
      if (pfractal.HistoryLoaded())
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

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete pfractal;
    delete strategy;
  }