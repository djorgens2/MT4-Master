//+------------------------------------------------------------------+
//|                                                   scalper-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#import "user32.dll"
   int MessageBoxW(int Ignore, string Caption, string Title, int Icon);
#import

//    MessageBoxW(0, "wussup?", "Pause...", 64);

#include <Class\PipRegression.mqh>
#include <Class\Fractal.mqh>
#include <Class\ArrayDouble.mqh>
#include <Class\ArrayInteger.mqh>
#include <manual.mqh>

#define   OrderBase            2

CPipRegression *pregr          = new CPipRegression(inpDegree,inpPeriod,inpTolerance);
CFractal       *fractal        = new CFractal(inpRange,inpRangeMin);

//--- Strategy Metrics
double          jrFractal[3];

int             jrDirection    = DirectionNone;

double          jrHigh;
double          jrLow;

double          jrRetrace;
double          jrExpansion;
double          jrRootRetrace;

double          jrWorkRetrace;
double          jrWorkExpansion;



double          jrWorkExpansionLong;
double          jrWorkExpansionShort;
double          jrWorkRetraceLong;
double          jrWorkRetraceShort;


//--- Order Fulfillment
int             sAction        = OP_NO_ACTION;
int             sTicket        = 0;
double          sOpenPrice     = 0.00;

int             sOrderQuota    = 0;
int             sOrderAction   = OP_NO_ACTION;


CArrayInteger  *sTickets       = new CArrayInteger(0);

CArrayDouble   *sTargets       = new CArrayDouble(0);
CArrayDouble   *sStops         = new CArrayDouble(0);
CArrayDouble   *sProfit        = new CArrayDouble(0);


//+------------------------------------------------------------------+
//| GetData - retrieves values and computes strategy metrics         |
//+------------------------------------------------------------------+
void GetData(void)
  {
    int lastDirection       = jrDirection;
    
    pregr.Update();
    fractal.Update();
    
    //--- Compute jr
    if (IsHigher(High[0],jrHigh,Digits))
    {
      jrDirection           = DirectionUp;

      jrWorkExpansionLong   = Close[0]+((jrHigh-jrLow)*0.618);

      jrRetrace             = jrHigh;
      jrExpansion           = jrHigh;
    }
    
    if (IsLower(Low[0],jrLow,Digits))
    {
      jrDirection           = DirectionDown;

      jrWorkExpansionShort  = Close[0]-((jrHigh-jrLow)*0.618);

      jrRetrace             = jrLow;
      jrExpansion           = jrLow;
    }

    if (jrDirection == DirectionDown)
    {
      if (IsHigher(Close[0],jrRetrace,Digits))
        jrExpansion         = jrRetrace;
      else
      if (IsLower(Close[0],jrExpansion,Digits))
      {
        //--- calc retraces
        jrWorkRetrace       = jrRetrace+((jrRetrace-jrLow)*0.618);
        jrWorkExpansion     = jrExpansion+((jrRetrace-jrLow)*0.618);
        jrRootRetrace       = jrRetrace+((jrRetrace-jrExpansion)*0.618);
      }
    }
    
    if (jrDirection == DirectionUp)
    {
      if (IsLower(Close[0],jrRetrace,Digits))
        jrExpansion         = jrRetrace;
      else
      if (IsHigher(Close[0],jrExpansion,Digits))
      {
        //--- calc retraces
        jrWorkRetrace       = jrRetrace-((jrHigh-jrRetrace)*0.618);
        jrWorkExpansion     = jrExpansion-((jrHigh-jrRetrace)*0.618);
        jrRootRetrace       = jrRetrace-((jrExpansion-jrRetrace)*0.618);
      }
    }
    
    Comment(Direction(jrDirection));
    
    
    jrWorkRetraceLong       = Close[0]-((Close[0]-jrLow)*0.618);
    jrWorkRetraceShort      = Close[0]+((jrHigh-Close[0])*0.618);
  }
      
      
//+------------------------------------------------------------------+
//| SetOrderStop - sets the stop loss on a specific order            |
//+------------------------------------------------------------------+
void SetOrderStop(int Ticket, double StopPrice)
  {
    if (OrderSelect(Ticket,SELECT_BY_TICKET,MODE_TRADES))
      if (OrderModify(Ticket,0.00,NormalizeDouble(OrderTakeProfit(),Digits),NormalizeDouble(StopPrice,Digits),0));
  }
      
      
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void VerifyFulfillment(void)
  {
    
    if (OrderFulfilled(sAction,sTicket,sOpenPrice))
    {
      sOrderQuota++;
      
      if (OrderModify(sTicket,0.00,0.00,NormalizeDouble(sOpenPrice+(fabs(pregr.PivotDev)*pregr.Action(InDirection,InContrarian)),Digits),0))
        Print ("Good Modify "+ActionText(sAction)+"@"+DoubleToStr(sOpenPrice+(fabs(pregr.PivotDev)*pregr.Action(InDirection,InContrarian)),Digits)+":"+DoubleToString(pregr.PivotDev,Digits));
      else
        Print ("Bad Modify "+ActionText(sAction)+"@"+DoubleToStr(sOpenPrice+(pregr.RangeSize*pregr.Action(InDirection,InContrarian)),Digits)+":"+DoubleToString(pregr.PivotDev,Digits));
        
      Comment("Order fulfilled: "+IntegerToString(sTicket)+" "+ActionText(sAction)
                            +" @"+DoubleToStr(sOpenPrice,Digits)
                            +" TP Range:"+DoubleToStr(pregr.PivotDev*pregr.Action(InDirection,InContrarian),Digits));
    }  
  }

//+------------------------------------------------------------------+
//| ExecuteDown - executes short strategy                            |
//+------------------------------------------------------------------+
void ExecuteDown(void)
  {
    if (pregr.FOCNow>pow(OrderBase,sOrderQuota))
      OpenOrder(sOrderAction,"AutoScalp (Market)");
  }
  
//+------------------------------------------------------------------+
//| ExecuteUp - executes long strategy                               |
//+------------------------------------------------------------------+
void ExecuteUp(void)
  {
    if (-pregr.FOCNow>pow(OrderBase,sOrderQuota))
      OpenOrder(sOrderAction,"AutoScalp (Market)");  
  }

//+------------------------------------------------------------------+
//| SetDown - executes a transition to short trend                   |
//+------------------------------------------------------------------+
void SetDown(int FromDirection)
  {
    sOrderQuota  = 0;
    sOrderAction = OP_BUY;
  }

//+------------------------------------------------------------------+
//| SetUp - executes a transition to long trend                      |
//+------------------------------------------------------------------+
void SetUp(int FromDirection)
  {
    sOrderQuota  = 0;
    sOrderAction = OP_SELL;
  }

//+------------------------------------------------------------------+
//| SetShortCorrection - executes evasive action to short            |
//+------------------------------------------------------------------+
void SetShortCorrection(int FromDirection)
  {
  }

//+------------------------------------------------------------------+
//| SetShortReversal - executes servere evasion to short             |
//+------------------------------------------------------------------+
void SetShortReversal(int FromDirection)
  {
  }

//+------------------------------------------------------------------+
//| SetLongCorrection - executes evasive action to long              |
//+------------------------------------------------------------------+
void SetLongCorrection(int FromDirection)
  {
  }

//+------------------------------------------------------------------+
//| SetLongReversal - executes servere evasion to long               |
//+------------------------------------------------------------------+
void SetLongReversal(int FromDirection)
  {
  }

//+------------------------------------------------------------------+
//| SetRally - executes a clean transition to short trend            |
//+------------------------------------------------------------------+
void SetRally(int FromDirection)
  {
  }

//+------------------------------------------------------------------+
//| SetPullback - executes a clean transition to long trend          |
//+------------------------------------------------------------------+
void SetPullback(int FromDirection)
  {
  }


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static int ampDirection = DirectionNone;
    
    if (ampDirection!=pregr.FOCAmpDirection)
    {
      if (ampDirection == DirectionNone)
      {
        ampDirection    = pregr.FOCAmpDirection;
        return;
      }
      
      switch (pregr.FOCAmpDirection)
      {
        case DirectionDown:   SetDown(ampDirection);
        case DirectionUp:     SetUp(ampDirection);
        case ShortCorrection: SetShortCorrection(ampDirection);
        case ShortReversal:   SetShortReversal(ampDirection);
        case LongCorrection:  SetLongCorrection(ampDirection);
        case LongReversal:    SetLongReversal(ampDirection);
        case Pullback:        SetPullback(ampDirection);
        case Rally:           SetRally(ampDirection);        
      }
    }

    ampDirection      = pregr.FOCAmpDirection;

    switch (ampDirection)
    {
/*      case DirectionDown:     ExecuteDown();
      case DirectionUp:       ExecuteUp();
      case ShortCorrection:   SetShortCorrection(ampDirection);
      case ShortReversal:     SetShortReversal(ampDirection);
      case LongCorrection:    SetLongCorrection(ampDirection);
      case LongReversal:      SetLongReversal(ampDirection);
      case Pullback:          SetPullback(ampDirection);
      case Rally:             SetRally(ampDirection);        */
    }
          
    VerifyFulfillment();

    
    if (pregr.FOCDevNow>fabs(pregr.FOCNow) && pregr.FOCDevNow>2.0)
    {
      if (pregr.Action(InType,InContrarian)!=sAction)
      {        
        if (OrderPending() && fabs(pregr.FOCNow)<1.0)
        {
//          OpenOrder(pregr.Action(InType,InContrarian),"AutoScalp (Market)",pregr.FOCDevNow);
          VerifyFulfillment();
        }
        else
        {
          Comment("Searching for "+ActionText(pregr.Action(InType,InContrarian))+"...");
//          OpenLimitOrder(pregr.Action(InType,InContrarian),pregr.TrendNow,0.00,pregr.FOCDevNow,"AutoScalp (Limit)");
        }
      }
    }    
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    UpdateLine("jrHigh",jrHigh,STYLE_SOLID,clrYellow);
    UpdateLine("jrLow",jrLow,STYLE_SOLID,clrRed);
    UpdateLine("jrRetrace",jrRetrace,STYLE_DOT,clrYellow);
    UpdateLine("jrExpansion",jrExpansion,STYLE_DOT,clrRed);
    UpdateLine("jrRootRetrace",jrRootRetrace,STYLE_DOT,clrGray);
    UpdateLine("jrWorkRetrace",jrWorkRetrace,STYLE_DOT,clrForestGreen);
    UpdateLine("jrWorkExpansion",jrWorkExpansion,STYLE_DOT,clrMaroon);

//    UpdateLine("jrExpLong",jrWorkExpansionLong,STYLE_DOT,clrForestGreen);
//    UpdateLine("jrExpShort",jrWorkExpansionShort,STYLE_DOT,clrMaroon);
//    UpdateLine("jrRetLong",jrWorkRetraceLong,STYLE_SOLID,clrForestGreen);
//    UpdateLine("jrRetShort",jrWorkRetraceShort,STYLE_SOLID,clrMaroon);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();
    
    manualProcessRequest();
    orderMonitor();
    
    RefreshScreen();
    
    if (manualAuto && pregr.TickLoaded)
      Execute();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();
    
    SetProfitPolicy(eqhalf);
    SetProfitPolicy(eqprofit);
    SetProfitPolicy(eqdir);
    
    SetEquityTarget(80,1);
    SetRisk(80,10);     

    InitJunior();
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
void InitJunior(void)
  {
    jrDirection           = DirectionNone;

    jrHigh                = High[1];
    jrLow                 = Low[1];

    jrWorkExpansionLong   = Close[0]+((jrHigh-jrLow)*0.618);    
    jrWorkExpansionShort  = Close[0]-((jrHigh-jrLow)*0.618);
    
    NewLine("jrHigh");
    NewLine("jrLow");
    NewLine("jrRetrace");
    NewLine("jrExpansion");
    NewLine("jrRootRetrace");
    NewLine("jrWorkRetrace");
    NewLine("jrWorkExpansion");

//    NewLine("jrExpLong");
//    NewLine("jrExpShort");
//    NewLine("jrRetLong");
//    NewLine("jrRetShort");
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pregr;
    delete fractal;
    delete sTickets;
    delete sTargets;
    delete sStops;    
  }