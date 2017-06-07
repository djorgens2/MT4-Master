//+------------------------------------------------------------------+
//|                                                        UDv01.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class\PipFractal.mqh>
#include <manual.mqh>

//input string udUserParams            = "";    //+------ User Options ------------+
//input string udDailyTarget           = 5;     // Daily objective

input string fractalHeader           = "";    //+------ Fractal Options ---------+
input int    inpRangeMax             = 120;   // Maximum fractal pip range
input int    inpRangeMin             = 60;    // Minimum fractal pip range

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

  enum FractalType
       {
          fo,
          fm,
          fn,
          pfo,
          pfm,
          pfn,
          FractalTypes
       };
       
  enum OrderState
       {
          LastTrade,        //--- Most current trade by action
          NegativeHold,     //--- Loss hold strategy; hold for profit
          NegativeDrop,     //--- Min equity drop; position building
          PositiveHold,     //--- Profit positions on trend direction
          LossClose,        //--- Emergent loss; risk mitigation
          ProfitClose,      //--- Hold for profit
          MissingOrder      //--- Foriegn source add/restart
       };

  struct OrderListRec 
         {
           int        Action;
           int        Ticket;
           datetime   OpenTime;
           double     OpenPrice;
           OrderState Type;
           bool       PendingClose;
           double     MaxDraw;
           double     MaxGain;
         };

  int     fDir[FractalTypes]         = {0,0,0,0,0,0};
  bool    fAlert[FractalTypes]       = {false,false,false,false,false,false};
  double  fFiboNow[FractalTypes];
  double  fFiboMax[FractalTypes];
  
  //--- Operational variables
  int              display           = NoValue;

  bool             tAlert;
  FractalType      tAlertType;
  double           tNegOpenPrice[2];
  OrderListRec     tOrderList[];

//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {    
    int gdAlert        = NoValue;
    
    tAlert             = false;
    
    fractal.Update();
    pfractal.Update();
    tregr.Update();
    
    //--- Identify Pattern
    if (IsChanged(fDir[fo],fractal.Origin(Direction)))
      fAlert[fo]=false;
    if (IsChanged(fDir[fm],fractal.Direction(Expansion)))
      fAlert[fm]=false;
    if (IsChanged(fDir[fn],fractal.Direction(fractal.State(Major))))
      fAlert[fn]=false;
    if (IsChanged(fDir[pfo],pfractal.Direction(Origin)))
      fAlert[pfo]=false;
    if (IsChanged(fDir[pfm],pfractal.Direction(Trend)))
      fAlert[pfm]=false;
    if (IsChanged(fDir[pfn],pfractal.Direction(Term)))
      fAlert[pfn]=false;
      
    fFiboNow[fo]     = fractal.Fibonacci(Origin,Expansion,Now);
    fFiboNow[fm]     = fractal.Fibonacci(Expansion,Expansion,Now);
    fFiboNow[fn]     = fractal.Fibonacci(fractal.State(Major),Expansion,Now);
    fFiboNow[pfo]    = pfractal.Fibonacci(Origin,Expansion,Now);
    fFiboNow[pfm]    = pfractal.Fibonacci(Trend,Expansion,Now);
    fFiboNow[pfn]    = pfractal.Fibonacci(Term,Expansion,Now);
      
    fFiboMax[fo]     = fractal.Fibonacci(Origin,Expansion,Max);
    fFiboMax[fm]     = fractal.Fibonacci(Expansion,Expansion,Max);
    fFiboMax[fn]     = fractal.Fibonacci(fractal.State(Major),Expansion,Max);
    fFiboMax[pfo]    = pfractal.Fibonacci(Origin,Expansion,Max);
    fFiboMax[pfm]    = pfractal.Fibonacci(Trend,Expansion,Max);
    fFiboMax[pfn]    = pfractal.Fibonacci(Term,Expansion,Max);
    
    for (FractalType type=fo; type<FractalTypes; type++)
      if (fFiboNow[type]<FiboPercent(Fibo23))
        if (IsChanged(fAlert[type],true))
          if (gdAlert==NoValue)
            gdAlert  = type;
 
    if (gdAlert>NoValue)
    {
      tAlertType        = (FractalType)gdAlert;
      tAlert            = true;
    }
  }

//+------------------------------------------------------------------+
//| ShowAppDisplay                                                   |
//+------------------------------------------------------------------+
void ShowAppDisplay(void)
  {
    string sadComment     = "";
    string sadOrderList   = "*--- Order List ---*\n";
    
    if (ArraySize(tOrderList)>0)
    {
      sadComment          = sadOrderList;
      
      for (int ord=0; ord<ArraySize(tOrderList); ord++)
        sadComment       += LPad(ActionText(tOrderList[ord].Action)," ",5)+"  "
                           +IntegerToString(tOrderList[ord].Ticket)+" "
                           +EnumToString(tOrderList[ord].Type)+" "
                           +DoubleToStr(tOrderList[ord].MaxDraw,1)+" "
                           +DoubleToStr(tOrderList[ord].MaxGain,1)+" "
                           +BoolToStr(tOrderList[ord].PendingClose,"Pending Close")
                           +"\n";
    }
    
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

    UpdateLabel("BaseNow",DoubleToStr(fractal.Fibonacci(Base,Expansion,Now,InPercent),1)+"%",DirColor(fractal.Direction(Expansion)));
    UpdateLabel("BaseMax",DoubleToStr(fractal.Fibonacci(Base,Expansion,Max,InPercent),1)+"%",DirColor(fractal.Direction(Expansion)));
    UpdateLabel("fMajor",EnumToString(fractal.State(Major)),DirColor(fractal.Direction(fractal.State(Major))));
  }

//+------------------------------------------------------------------+
//| ExecNegAdd - Updates NegAdd guidelines and manages close list    |
//+------------------------------------------------------------------+
void ExecNegAdd(int Action)
  {
/*    for (int ord=0; ord<OrdersTotal(); ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol()==Symbol())
          if (OrderType()==Action)
            if (OrderProfit()>(ordEQBase*ordEQMinProfit))
              switch (Action)
              {
                case OP_BUY:  if (OrderOpenPrice()>=tNegAddPrice[Action])
                                 AddPendingClose(Action,OrderTicket());
                              break;
                case OP_SELL: if (OrderOpenPrice()<=tNegAddPrice[Action])
                                AddPendingClose(Action,OrderTicket());
                              break;
              }
*/
  }

//+------------------------------------------------------------------+
//| ExecClose - Tests tickets in the closure stack for closes        |
//+------------------------------------------------------------------+
void ExecTradeClose(int Action, int Ticket)
  {
/*    CloseList apcNewCloseList[];
    
    for (int ord=0; ord<ArraySize(tCloseList); ord++)
      if (tCloseList[ord].Ticket==Ticket)
        if (!OrderClosed(ord))
        {
          ArrayResize(apcNewCloseList,ArraySize(apcNewCloseList)+1);
          apcNewCloseList[ArraySize(apcNewCloseList)-1] = tCloseList[ord];
        }

    ArrayCopy(tCloseList,apcNewCloseList);
*/
  }

//+------------------------------------------------------------------+
//| ExecShort - Manages Short orders                                 |
//+------------------------------------------------------------------+
void ExecShort(void)
  {
  }

//+------------------------------------------------------------------+
//| ExecLong - Manages Long orders                                   |
//+------------------------------------------------------------------+
void ExecLong(void)
  {
    static bool   elTrigger        = false;
    
    if (pfractal.Event(NewLow))
      elTrigger           = true;
    else
    if (elTrigger)
      if (OpenOrder(OP_BUY,"Contrary Long"))
      {
        UpdateOrders();
        elTrigger         = false;
      }        
  }
  
//+------------------------------------------------------------------+
//| FindOrder - Retrieves order rec by ticket                        |
//+------------------------------------------------------------------+
OrderListRec FindOrder(int Ticket)
  {
    OrderListRec foOrder;

    double       foPips;
    
    for (int ord=0; ord<ArraySize(tOrderList); ord++)
      if (tOrderList[ord].Ticket == Ticket)
        return (tOrderList[ord]);
        
    if (OrderSelect(Ticket,SELECT_BY_TICKET,MODE_TRADES))
    {
      foPips = Pip(BoolToDouble(OrderType()==OP_BUY,Bid-OrderOpenPrice(),OrderOpenPrice()-Ask));
    
      foOrder.Action         = OrderType();
      foOrder.Ticket         = Ticket;
      foOrder.PendingClose   = false;
      foOrder.Type           = LastTrade;
      foOrder.MaxDraw        = fmin(TicketValue(Ticket,InEquity),(-Spread(InPips)*fdiv(OrderProfit(),foPips)/ordEQBase));
      foOrder.MaxGain        = fmax(TicketValue(Ticket,InEquity),(-Spread(InPips)*fdiv(OrderProfit(),foPips)/ordEQBase));
      foOrder.OpenTime       = OrderOpenTime();
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
    int      uoLastOrder[2]         = {NoValue,NoValue};
    
    for (int ord=0; ord<OrdersTotal(); ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol()==Symbol())
        {
          ArrayResize(uoOrderList,ord+1);

          uoOrderList[ord]          = FindOrder(OrderTicket());
          uoOrderList[ord].MaxDraw  = fmin(uoOrderList[ord].MaxDraw,TicketValue(OrderTicket(),InEquity));
          uoOrderList[ord].MaxGain  = fmax(uoOrderList[ord].MaxGain,TicketValue(OrderTicket(),InEquity));
          
          if (uoOrderList[ord].OpenTime>uoLastOrderTime[uoOrderList[ord].Action])
          {
            uoLastOrder[uoOrderList[ord].Action]     = ord;
            uoLastOrderTime[uoOrderList[ord].Action] = uoOrderList[ord].OpenTime;
          }
        }

    for (int ord=0; ord<OrdersTotal(); ord++)
      if (ord==uoLastOrder[uoOrderList[ord].Action])
        uoOrderList[ord].Type       = LastTrade;

      else
      {
        if (uoOrderList[ord].Action==OP_BUY)
          if (uoOrderList[ord].OpenPrice>uoOrderList[uoLastOrder[OP_BUY]].OpenPrice)
          {
            uoOrderList[ord].Type          = NegativeDrop;
            uoOrderList[ord].PendingClose  = true;
          }
          else
          {
            uoOrderList[ord].Type          = PositiveHold;
            uoOrderList[ord].PendingClose  = false;
          }

        if (uoOrderList[ord].Action==OP_SELL)
          if (uoOrderList[ord].OpenPrice<uoOrderList[uoLastOrder[OP_SELL]].OpenPrice)
          {
            uoOrderList[ord].Type          = NegativeDrop;
            uoOrderList[ord].PendingClose  = true;
          }
          else
          {
            uoOrderList[ord].Type          = PositiveHold;
            uoOrderList[ord].PendingClose  = false;
          }
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
   
    //ExecPendingClose();
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

    NewLabel("BaseNow","",800,35,clrGray,SCREEN_UR);
    NewLabel("BaseMax","",750,35,clrGray,SCREEN_UR);
    NewLabel("fMajor","",850,35,clrGray,SCREEN_UR);
    
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
