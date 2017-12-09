//+------------------------------------------------------------------+
//|                                                        UDv03.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class\PipFractal.mqh>
#include <manual.mqh>

input string userParamHeader         = "";    //+------ User Options ------------+
input double udDailyTarget           = 5.0;   // Daily objective Equity % Target

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


//--- Class defs
  CFractal           *fractal        = new CFractal(inpRangeMax,inpRangeMin);
  CPipFractal        *pfractal       = new CPipFractal(inpDegree,inpPipPeriods,inpTolerance,fractal); 
  CTrendRegression   *tregr          = new CTrendRegression(inpDegree,inpRegrPeriods,inpSmoothFactor);
  CPolyRegression    *pregrst        = new CPolyRegression(inpDegree,inpRangeMin,inpRegrPeriods);
  CPolyRegression    *pregrmt        = new CPolyRegression(inpDegree,inpRangeMax,inpRegrPeriods);
  CPolyRegression    *pregrlt        = new CPolyRegression(inpDegree,inpPeriodsLT,inpRegrPeriods);

  enum StrategyType
       {
         Spot,
         Build,
         Scalp,
         Hold,
         Hedge,
         Closeout,
         Halt,
         NoStrategy         //--- last position, contains strategy count
       };
       
  enum FractalType
       {
          fo,
          fb,
          fm,
          fn,
          pfo,
          pfm,
          pfn,
          FractalTypes
       };
       
  enum OrderState
       {
          Baseline,         //--- Best Trade for an Action
          LastOpen,         //--- Last trade opened by Action
          NegativeHold,     //--- Position build strategy; hold for profit
          NegativeDrop,     //--- Min equity drop; position building
          PositiveHold,     //--- Profit positions on trend direction
          LossClose,        //--- Emergent loss; risk mitigation
          ProfitClose,      //--- Hold for profit
          TradeClosed       //--- Indicates trade closed
       };

  struct OrderListRec 
         {
           int        Action;
           int        Ticket;
           OrderState Type;
           datetime   OpenTime;
           double     OpenPrice;
           double     Draw;
           double     MaxDraw;
           double     MaxGain;
         };

  int                 fDir[FractalTypes]       = {0,0,0,0,0,0,0};
  bool                fAlert[FractalTypes]     = {false,false,false,false,false,false,false};

  double              fFiboNow[FractalTypes];
  double              fFiboMax[FractalTypes];
  double              fRetMajor[2];
  RetraceType         fnType;
  
  //--- Operational variables
  int                 display         = NoValue;

  bool                tAlert;
  FractalType         tAlertType;
  bool                tOpenOrder[2]   = {false,false};
  OrderListRec        tOrderList[];
  StrategyType        tStrategy[2]    = {Spot, Spot};

  int                 tLast[2];
  int                 tBaseline[2];

//+------------------------------------------------------------------+
//| Strategy - returns Strategy enum for the supplied text           |
//+------------------------------------------------------------------+
StrategyType StrategyCode(string Strategy)
  {
    if (Strategy=="SPOT")     return (Spot);
    if (Strategy=="BUILD")    return (Build);
    if (Strategy=="SCALP")    return (Scalp);
    if (Strategy=="HOLD")     return (Hold);
    if (Strategy=="HEDGE")    return (Hedge);
    if (Strategy=="CLOSEOUT") return (Closeout);
    if (Strategy=="HALT")     return (Halt);

    return (NoStrategy);
  } 
  
//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {    
    int gdAlert      = NoValue;
    
    tAlert           = false;
    
    fractal.Update();
    pfractal.Update();
    tregr.Update();
    pregrst.Update();
    pregrmt.Update();
    pregrlt.Update();
    
    fnType           = fractal.State(Major);

    //--- Reset alerts
    if (IsChanged(fDir[fo],fractal.Origin(Direction)))
      fAlert[fo]     = false;
    if (IsChanged(fDir[fb],fractal.Direction(Base)))
      fAlert[fb]     = false;
    if (IsChanged(fDir[fm],fractal.Direction(Expansion)))
      fAlert[fm]     = false;
    if (IsChanged(fDir[fn],fractal.Direction(fnType)))
      fAlert[fn]     = false;
    if (IsChanged(fDir[pfo],pfractal.Direction(Origin)))
      fAlert[pfo]    = false;
    if (IsChanged(fDir[pfm],pfractal.Direction(Trend)))
      fAlert[pfm]    = false;
    if (IsChanged(fDir[pfn],pfractal.Direction(Term)))
      fAlert[pfn]    = false;
          
    fFiboNow[fo]     = fractal.Fibonacci(Origin,Expansion,Now);
    fFiboNow[fb]     = fractal.Fibonacci(Base,Expansion,Now);
    fFiboNow[fm]     = fractal.Fibonacci(Expansion,Expansion,Now);
    fFiboNow[fn]     = fractal.Fibonacci(fnType,Expansion,Now);
    fRetMajor[0]     = fractal.Fibonacci(fnType,Retrace,Now);
    fFiboNow[pfo]    = pfractal.Fibonacci(Origin,Expansion,Now);
    fFiboNow[pfm]    = pfractal.Fibonacci(Trend,Expansion,Now);
    fFiboNow[pfn]    = pfractal.Fibonacci(Term,Expansion,Now);
      
    fFiboMax[fo]     = fractal.Fibonacci(Origin,Expansion,Max);
    fFiboMax[fb]     = fractal.Fibonacci(Base,Expansion,Max);
    fFiboMax[fm]     = fractal.Fibonacci(Expansion,Expansion,Max);
    fFiboMax[fn]     = fractal.Fibonacci(fnType,Expansion,Max);
    fRetMajor[1]     = fractal.Fibonacci(fnType,Retrace,Max);
    fFiboMax[pfo]    = pfractal.Fibonacci(Origin,Expansion,Max);
    fFiboMax[pfm]    = pfractal.Fibonacci(Trend,Expansion,Max);
    fFiboMax[pfn]    = pfractal.Fibonacci(Term,Expansion,Max);
    
    if (fFiboNow[pfm]>FiboPercent(Fibo100))
      fAlert[pfm]    = false;
    if (fFiboNow[pfn]>FiboPercent(Fibo100))
      fAlert[pfn]    = false;
    
    for (FractalType type=fo; type<FractalTypes; type++)
      if (type==fn)
      {
        if (fRetMajor[0]>1-FiboPercent(Fibo23))
          if (IsChanged(fAlert[type],true))
            if (gdAlert==NoValue)
              gdAlert   = type;        
      }
      else
      if (fFiboNow[type]<FiboPercent(Fibo23))
        if (IsChanged(fAlert[type],true))
          if (gdAlert==NoValue)
            gdAlert     = type;
 
    if (gdAlert>NoValue)
    {
      tAlertType        = (FractalType)gdAlert;
      tAlert            = true;
    }
  }

//+------------------------------------------------------------------+
//| OrderList - returns formatted order data string of the Index     |
//+------------------------------------------------------------------+
string OrderList(int OrderIndex)
  {
    string olOrderList     = "";
    const string olProfit  = "+";
    const string olLoss    = " -";
    
    
    olOrderList       += BoolToStr(TicketValue(tOrderList[OrderIndex].Ticket)>0.00,olProfit,olLoss)
                        +LPad(ActionText(tOrderList[OrderIndex].Action)," ",5)+"  "
                        +IntegerToString(tOrderList[OrderIndex].Ticket)+":"
                        +DoubleToStr(tOrderList[OrderIndex].OpenPrice,Digits)+"  "
                        +EnumToString(tOrderList[OrderIndex].Type)+" "
                        +DoubleToStr(tOrderList[OrderIndex].Draw,1)+" "
                        +DoubleToStr(tOrderList[OrderIndex].MaxDraw,1)+" "
                        +DoubleToStr(tOrderList[OrderIndex].MaxGain,1);
                        
    return (olOrderList);
  }

//+------------------------------------------------------------------+
//| ShowAppDisplay                                                   |
//+------------------------------------------------------------------+
void ShowAppDisplay(void)
  {
    string sadComment        ="\n*--- Strategy ---*\n"
                             +"  Long:  "+EnumToString(tStrategy[OP_BUY])+"\n"
                             +"  Short: "+EnumToString(tStrategy[OP_SELL])+"\n";
    string sadBaselineList   = "\n*--- Baseline ----*\n";
    string sadLongList       = "\n*--- Long List ---*\n";
    string sadShortList      = "\n*--- Short List ---*\n";

    bool   sadAction[2]      = {false,false};

    if (ArraySize(tOrderList)>0)
    {
      sadComment            += sadBaselineList;
      
      if (tLast[OP_BUY]>NoValue)
        sadComment          += OrderList(tLast[OP_BUY])+"\n";

      if (tLast[OP_SELL]>NoValue)
        sadComment          += OrderList(tLast[OP_SELL])+"\n";

      for (int ord=0; ord<ArraySize(tOrderList); ord++)
      {
        if (tOrderList[ord].Action==OP_BUY)
        {
          sadAction[OP_BUY]  = true;
          sadLongList       += OrderList(ord)+"\n";
        }
        
        if (tOrderList[ord].Action==OP_SELL)
        {
          sadAction[OP_SELL] = true;
          sadShortList      += OrderList(ord)+"\n";
        }        
      }
    }
    
    sadComment              += BoolToStr(sadAction[OP_BUY],sadLongList);
    sadComment              += BoolToStr(sadAction[OP_SELL],sadShortList);
    
    if (sadComment=="")
      Comment("No Application Data");
    else
      Comment(sadComment);
  }
  
//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    static int rsLastDisplay   = display;
           int rsArrowColor;
    
    switch (display)
    {
      case 0:  fractal.RefreshScreen();
               break;

      case 1:  pfractal.RefreshScreen();
               break;
               
      case 2:  ShowAppDisplay();
               break;
               
      default: if (IsChanged(rsLastDisplay,display))
                 Comment("No Data");
    }
    
    pfractal.ShowFiboArrow();
    
    for (FractalType type=fo; type<FractalTypes; type++)
    {
      if (fAlert[type])
        rsArrowColor    = clrYellow;
      else
        rsArrowColor    = DirColor(fDir[type]);

      UpdateDirection(EnumToString(type)+"Dir",fDir[type],rsArrowColor);
      UpdateLabel(EnumToString(type)+"Now",DoubleToStr(fFiboNow[type]*100,1)+"%",rsArrowColor);
      UpdateLabel(EnumToString(type)+"Max",DoubleToStr(fFiboMax[type]*100,1)+"%",rsArrowColor);
    }

    UpdateLabel("fnRetNow",DoubleToStr(fRetMajor[0]*100,1)+"%",DirColor(fDir[fn]));
    UpdateLabel("fnRetMax",DoubleToStr(fRetMajor[1]*100,1)+"%",DirColor(fDir[fn]));
    UpdateLabel("fMajor",EnumToString(fnType),DirColor(fDir[fn]));
    UpdateLabel("tOpenBuy",BoolToStr(tOpenOrder[OP_BUY],"Buy","Idle"),BoolToInt(tOpenOrder[OP_BUY],clrYellow,clrGray));
    UpdateLabel("tOpenSell",BoolToStr(tOpenOrder[OP_SELL],"Sell","Idle"),BoolToInt(tOpenOrder[OP_SELL],clrYellow,clrGray));
  }

//+------------------------------------------------------------------+
//| ClearTrigger - Clears open trade trigger for supplied action     |
//+------------------------------------------------------------------+
void ClearTrigger(int Action)
  {
    tOpenOrder[Action]  = false;
  }

//+------------------------------------------------------------------+
//| ExecTradeClose - Manages in-profit order closures                |
//+------------------------------------------------------------------+
bool ExecTradeClose(int Action)
  {
    for (int ord=0; ord<ArraySize(tOrderList); ord++)
      switch (tOrderList[ord].Type)
      {
        case NegativeDrop:  if (tOrderList[ord].Draw>0.00)
                            {
//                            Pause("Testing validity of PipMA as a close Agent.","PipMA() Testing");
                              if (ActionDir(Action)==pfractal.Direction(Tick))
                                if (CloseOrder(tOrderList[ord].Ticket,true))
                                {
                                  tOrderList[ord].Type = TradeClosed;
                                  return (true);
                                }
                            }
      }
/*      if (IsHigher(tOrderList[ord].Draw,ordEQMinProfit,false))
        switch (tOrderList[ord].Type)
        {
          case NegativeDrop: if (IsEqual(pfractal.FOC(Deviation),0.00))
                             {
                               //--- hold for sustained profit (if any)
                             }
                             else
                             {
                             }
        }
*/
    return (false);
  }

//+------------------------------------------------------------------+
//| ExecTradeOpen - Manages opening trade restrictions               |
//+------------------------------------------------------------------+
bool ExecTradeOpen(int Action)
  {
//Pause ("Opening Order","OpenOrder()");
      
    if (OpenOrder(Action,"Trade Manager "+ActionText(Action)))
    {
      UpdateOrders();
      return (true);
    }
    
    return (false);
  }

//+------------------------------------------------------------------+
//| ExecShort - Manages Short orders                                 |
//+------------------------------------------------------------------+
void ExecShort(void)
  {
    switch (tStrategy[OP_SELL])
    {  
      case Hold:   break;
      default:     if (pfractal.Direction(Trendline)==DirectionUp)
                     if (pfractal.Event(NewHigh))
                       tOpenOrder[OP_SELL]      = true;
                     else
                     if (tOpenOrder[OP_SELL])
                       if (pfractal.Poly(Deviation)<0.00)
                         if (ExecTradeOpen(OP_SELL))
                           tOpenOrder[OP_SELL]  = false;
    }
    
    ExecTradeClose(OP_SELL);
  }

//+------------------------------------------------------------------+
//| ExecLong - Manages Long orders                                   |
//+------------------------------------------------------------------+
void ExecLong(void)
  {
    switch (tStrategy[OP_BUY])
    {
      case Hold:   break;
      default:     if (pfractal.Direction(Trendline)==DirectionDown)
                     if (pfractal.Event(NewLow))
                        tOpenOrder[OP_BUY]       = true;
                     else
                     if (tOpenOrder[OP_BUY])
                       if (pfractal.Poly(Deviation)>0.00)
                         if (ExecTradeOpen(OP_BUY))
                           tOpenOrder[OP_BUY]   = false;
    }

    ExecTradeClose(OP_BUY);
  }
  
//+------------------------------------------------------------------+
//| ManageRisk - Analyzes open trades and margins                    |
//+------------------------------------------------------------------+
void ManageRisk(void)
  {
    if (tAlert)
    {
      //Pause("Alert: "+EnumToString(tAlertType), "Caution",MB_OK|MB_ICONEXCLAMATION);
    }
    
    if (pfractal.Direction(RangeHigh)==DirectionDown)
    {
      SetStrategy(OP_SELL, Spot);

      ClearTrigger(OP_BUY);
      SetStrategy(OP_BUY, Hold);
    }
    
    if (pfractal.Direction(RangeHigh)==DirectionUp)
    {
      SetStrategy(OP_BUY, Spot);

      ClearTrigger(OP_SELL);
      SetStrategy(OP_SELL, Hold);      
    }
  }

//+------------------------------------------------------------------+
//| SetStrategy - Sets the trade strategy for the supplied action    |
//+------------------------------------------------------------------+
void SetStrategy(int Action, StrategyType Strategy)
  {
    tStrategy[Action]    = Strategy;
  }

//+------------------------------------------------------------------+
//| UpdateStrategy - Manages strategy by action                      |
//+------------------------------------------------------------------+
void UpdateStrategy(void)
  {
    if (tAlert) //--- trap Fibo23 alerts
    {
    }
    
    if (pfractal.Event(NewAggregate))
      Pause("New aggregate occurred","Event Manager");
    
  }
  
//+------------------------------------------------------------------+
//| FindOrder - Retrieves order rec by ticket                        |
//+------------------------------------------------------------------+
OrderListRec FindOrder(int Ticket)
  {
    OrderListRec foOrder = {OP_NO_ACTION,0,Baseline,NoValue,NoValue,0.00,0.00};

    double       foPips;
    
    for (int ord=0; ord<ArraySize(tOrderList); ord++)
      if (tOrderList[ord].Ticket == Ticket)
        return (tOrderList[ord]);
        
    if (OrderSelect(Ticket,SELECT_BY_TICKET,MODE_TRADES))
    {
      foPips = Pip(BoolToDouble(OrderType()==OP_BUY,Bid-OrderOpenPrice(),OrderOpenPrice()-Ask));
    
      foOrder.Action         = OrderType();
      foOrder.Ticket         = Ticket;
      foOrder.Type           = Baseline;
      foOrder.OpenTime       = OrderOpenTime();
      foOrder.OpenPrice      = OrderOpenPrice();
      foOrder.Draw           = TicketValue(Ticket,InEquity);
      foOrder.MaxDraw        = fmin(TicketValue(Ticket,InEquity),(-Spread(InPips)*fdiv(OrderProfit(),foPips)/ordEQBase));
      foOrder.MaxGain        = fmax(TicketValue(Ticket,InEquity),(-Spread(InPips)*fdiv(OrderProfit(),foPips)/ordEQBase));
    }
    
    return foOrder;
  }

//+------------------------------------------------------------------+
//| UpdateOrders - Manages order statistics and alerts               |
//+------------------------------------------------------------------+
void UpdateOrders()
  {
    OrderListRec uoOrderList[];
    
    datetime uoLastOrderTime[2]     = {NoValue,NoValue};

    ArrayInitialize(tLast,NoValue);
    
    for (int ord=0; ord<OrdersTotal(); ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol()==Symbol())
        {
          ArrayResize(uoOrderList,ord+1);

          uoOrderList[ord]          = FindOrder(OrderTicket());
          uoOrderList[ord].Draw     = TicketValue(OrderTicket(),InEquity);
          uoOrderList[ord].MaxDraw  = fmin(uoOrderList[ord].MaxDraw,TicketValue(OrderTicket(),InEquity));
          uoOrderList[ord].MaxGain  = fmax(uoOrderList[ord].MaxGain,TicketValue(OrderTicket(),InEquity));

          if (uoOrderList[ord].OpenTime>uoLastOrderTime[uoOrderList[ord].Action])
          {
            tLast[uoOrderList[ord].Action]           = ord;
            uoLastOrderTime[uoOrderList[ord].Action] = uoOrderList[ord].OpenTime;
          }
        }

    for (int ord=0; ord<OrdersTotal(); ord++)
      if (ord==tLast[uoOrderList[ord].Action])
        uoOrderList[ord].Type               = LastOpen;

      else
      {
        if (uoOrderList[ord].Action==OP_BUY)
          if (uoOrderList[ord].OpenPrice>uoOrderList[tLast[OP_BUY]].OpenPrice)
            uoOrderList[ord].Type           = NegativeDrop;
          else
            uoOrderList[ord].Type           = PositiveHold;

        if (uoOrderList[ord].Action==OP_SELL)
          if (uoOrderList[ord].OpenPrice<uoOrderList[tLast[OP_SELL]].OpenPrice)
            uoOrderList[ord].Type           = NegativeDrop;
          else
            uoOrderList[ord].Type           = PositiveHold;
      }
    
    ArrayResize(tOrderList,ArraySize(uoOrderList));
    ArrayCopy(tOrderList,uoOrderList);
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static bool eInit    = false;
    
    UpdateOrders();
    UpdateStrategy();
      
    if (pfractal.HistoryLoaded())
      if (eInit)
      {
        ExecLong();
        ExecShort();
      }
      else
      {
        Pause("History is now loaded","HistoryLoaded()");
        eInit            = true;
      }
   
    ManageRisk();
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
    else
    if (Command[0]=="SET")
      if (InStr(Command[1],"STRAT"))
        SetStrategy(ActionCode(Command[2]),StrategyCode(Command[3]));

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
    
    for (FractalType type=fo; type<FractalTypes; type++)
    {
      NewLabel(EnumToString(type)+"Header",EnumToString(type),870-(type*50),5,DirColor(clrGray),SCREEN_UR);
      NewLabel(EnumToString(type)+"Dir","0.0%",850-(type*50),5,DirColor(fDir[type]),SCREEN_UR);
      NewLabel(EnumToString(type)+"Now","0.0%",850-(type*50),15,DirColor(fDir[type]),SCREEN_UR);
      NewLabel(EnumToString(type)+"Max","0.0%",850-(type*50),25,DirColor(fDir[type]),SCREEN_UR);
    }

    NewLabel("fnRetNow","",800,35,clrGray,SCREEN_UR);
    NewLabel("fnRetMax","",750,35,clrGray,SCREEN_UR);
    NewLabel("fMajor","",850,35,clrGray,SCREEN_UR);
    
    NewLabel("tOpenOrder","Trigger",700,35,clrGray,SCREEN_UR);
    NewLabel("tOpenBuy","",650,35,clrGray,SCREEN_UR);
    NewLabel("tOpenSell","",600,35,clrGray,SCREEN_UR);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
    delete pfractal;
    delete tregr;
  }
