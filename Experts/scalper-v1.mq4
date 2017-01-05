//+------------------------------------------------------------------+
//|                                                   scalper-v1.mq4 |
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

CPipRegression *pregr          = new CPipRegression(inpDegree,inpPeriod,inpTolerance);
CFractal       *fractal        = new CFractal(inpRange,inpRangeMin);

//--- Order Fulfillment
int             sAction        = OP_NO_ACTION;
int             sTicket        = 0;
double          sOpenPrice     = 0.00;

CArrayInteger  *sTickets       = new CArrayInteger(0);
CArrayDouble   *sTargets       = new CArrayDouble(0);
CArrayDouble   *sStops         = new CArrayDouble(0);

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void SetOrderStops(int Action)
  {
    if (OrderModify(sTicket,0.00,0.00,NormalizeDouble(sOpenPrice+(fabs(pregr.PivotDev)*pregr.Action(InDirection,InContrarian)),Digits),0));
  }
      
      
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void VerifyFulfillment(void)
  {
    
    if (OrderFulfilled(sAction,sTicket,sOpenPrice))
    {
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
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void Execute(void)
  {
    VerifyFulfillment();
    
    if (pregr.FOCDevNow>fabs(pregr.FOCNow) && pregr.FOCDevNow>2.0)
    {
      if (pregr.Action(InType,InContrarian)!=sAction)
      {        
        if (OrderPending() && fabs(pregr.FOCNow)<1.0)
        {
          OpenOrder(pregr.Action(InType,InContrarian),"AutoScalp (Market)",pregr.FOCDevNow);
          VerifyFulfillment();
        }
        else
        {
          Comment("Searching for "+ActionText(pregr.Action(InType,InContrarian))+"...");
          OpenLimitOrder(pregr.Action(InType,InContrarian),pregr.TrendNow,0.00,pregr.FOCDevNow,"AutoScalp (Limit)");
        }
      }
    }    
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    pregr.Update();
    fractal.Update();
    
    manualProcessRequest();
    orderMonitor();
    
    if (manualAuto)
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

    return(INIT_SUCCEEDED);
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