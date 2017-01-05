//+------------------------------------------------------------------+
//|                                                   scalper-v9.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\TrendRegression.mqh>
#include <Class\PipRegression.mqh>
#include <Class\Fractal.mqh>
#include <manual.mqh>

//--- Input params
input string scv9Config            = "";    //+------ Advisor Inputs ------+
input double inpEntryTrail         = 3.0;   // Trailing entry in pips

input string scv9Header            = "";    //+---- Regression Inputs -----+
input int    inpDegree             = 6;     // Degree of poly regression
input int    inpPipPeriods         = 200;   // Pip history regression periods
input int    inpTrendPeriods       = 24;    // Trend regression periods
input int    inpSmoothFactor       = 3;     // Trend MA Smoothing Factor
input double inpTolerance          = 0.5;   // Trend change sensitivity


CPipRegression    *pregr           = new CPipRegression(inpDegree,inpPipPeriods,inpTolerance);
CTrendRegression  *tregr           = new CTrendRegression(inpDegree,inpTrendPeriods,inpSmoothFactor);
CFractal          *fractal         = new CFractal(inpRange,inpRangeMin);

bool     sStateChanged             = false;            //--- True on fractal state change
bool     sInvergentLeg             = false;            //--- True when fractal becomes invergent (indecisive)

int      sPivotDirection           = DirectionNone;    //--- Last pipMA zero-dev dir
double   sPivotHigh                = 0.00;             //--- highest value of pipMA last zero-dev dir
double   sPivotLow                 = 0.00;             //--- lowest value of pipMA last zero-dev dir

string   sReport                   = "";               //--- Stores the aggregate report for later comment

int      vfAction                  = OP_NO_ACTION;     //--- Last fulfilled order action
int      vfTicket                  = NoValue;          //--- Last fulfilled order ticket
double   vfOpenPrice               = 0.00;             //--- Last fulfilled order fill price
datetime vfOpenTime                = 0;                //--- Last fulfilled order fill time


//+------------------------------------------------------------------+
//| GetData - Collects indicator data                                |
//+------------------------------------------------------------------+
void GetData(void)
  {
    static int lastStateDirection  = DirectionNone;
    static int idOK                = IDOK;
    
    sStateChanged                  = false;
    
    pregr.Update();
    tregr.Update();
    fractal.Update();
    
    if (fractal.StateChanged(true))
    {
      sStateChanged                = true;
      
      if (fractal.Direction(StateTerm) == DirectionUp)
        NewArrow(SYMBOL_ARROWUP,clrYellow,"Fractal",Bid);

      if (fractal.Direction(StateTerm) == DirectionDown)
        NewArrow(SYMBOL_ARROWDOWN,clrRed,"Fractal",Bid);

      
      if (IsChanged(lastStateDirection,fractal.Direction(StateTerm)))
        Pause("State term direction change to "+proper(DirText(fractal.Direction(StateTerm))),"StateTerm() Direction Change");
    }
                                        
    if (IsEqual(pregr.FOCDev,0.00,1))
    {
      if (idOK == IDOK)
        idOK = Pause("Zero pipMA hit ("+DirText(pregr.FOCDirection)+")","pregr Analysis",MB_ICONINFORMATION|MB_OKCANCEL|MB_DEFBUTTON2);
    }
    else
      idOK = IDOK;
      
    if (fractal.IsInvergent())
      sInvergentLeg               = true;
      
    if (sInvergentLeg)
      if (fractal.IsBreakout())
        sInvergentLeg             = false;
      
    UpdateLine("sTarget_Long",fractal.StateTarget(OP_BUY),STYLE_DASH,clrYellow);
    UpdateLine("sTarget_Short",fractal.StateTarget(OP_SELL),STYLE_DASH,clrRed);
  }

//+------------------------------------------------------------------+
//| VerifyFulfillment - Updates last order filled data               |
//+------------------------------------------------------------------+
void VerifyFulfillment(void)
  {  

    if (OrderFulfilled(vfAction,vfTicket,vfOpenPrice))
      if (OrderSelect(vfTicket,SELECT_BY_TICKET,MODE_TRADES))
        vfOpenTime                = TimeCurrent();
        
    if (OrderSelect(vfTicket,SELECT_BY_TICKET,MODE_TRADES))
    {
      sReport  += "------ Fulfillment Manager ---------\n"
                + IntegerToString(vfTicket)
                + " "+ActionText(vfAction)
                + "  @"+DoubleToStr(vfOpenPrice,Digits)
                + "  Stop:"+DoubleToStr(OrderStopLoss(),Digits)
                + "  Target:"+DoubleToStr(OrderTakeProfit(),Digits)
                + "\n";
                
//      if (sHedgeAction!=OP_NO_ACTION)
//        sReport += " *** Hedge "+proper(ActionText(sHedgeAction))+"\n";
    }
  }


//+------------------------------------------------------------------+
//| ManageProfit - sets and removes locks and profit plans           |
//+------------------------------------------------------------------+
void ManageProfit(void)
  {
    static int    mpAction       = OP_NO_ACTION;
    static int    mpState        = NoValue;
    static bool   mpKill         = false;
    static double mpTarget[2]    = {0.00,0.00};
    
    if (IsChanged(mpAction,vfAction))
    {
      SetTargetPrice(mpAction,fractal.StateTarget(vfAction));
      
      if (mpAction == OP_BUY)
        mpTarget[mpAction]       = sPivotHigh;
        
      if (mpAction == OP_SELL)
        mpTarget[mpAction]       = sPivotLow;
      
      Pause("What's my target?\n"
           +"  Long:      "+DoubleToStr(fractal.StateTarget(OP_BUY))+"\n"
           +"  Short:     "+DoubleToStr(fractal.StateTarget(OP_SELL))+"\n"
           +"  Base:      "+DoubleToStr(fractal.StatePrice(StateBase),Digits)+"\n"
           +"  Root:      "+DoubleToStr(fractal.StatePrice(StateRoot),Digits)+"\n"
           +"  Expansion: "+DoubleToStr(fractal.StatePrice(StateExpansion),Digits)+"\n",
         "StateTarget() Issue");
    }
    
/*    if (IsChanged(mpState,fractal.State()))
    {
//      SetTargetPrice(DirectionAction(fractal.Direction(StateTerm)),fractal.StateTarget(DirectionAction(fractal.Direction(StateTerm))));
      OpenProfitPlan(DirectionAction(fractal.Direction(Active)),fractal.StateTarget(DirectionAction(fractal.Direction(Active))),Pip(inpRange,InPoints),Pip(inpRangeMin,InPoints));
      
      if (fractal.PivotPrice(Retrace)>FiboLevel(Fibo50))
      {        
        mpTarget[DirectionAction(fractal.Direction(Active,InContrarian))] =
          fractal.PivotPrice(Root)+(fdiv(fractal.PivotPrice(Root)+fractal.PivotPrice(StateTrend),2)*FiboLevel(Fibo38))*fractal.Direction(Active,InContrarian);

        OpenProfitPlan(DirectionAction(fractal.Direction(Active,InContrarian)),mpTarget[DirectionAction(fractal.Direction(Active,InContrarian))],Pip(inpRange,InPoints),Pip(inpRangeMin,InPoints));
          
      }
    }  
*/
//    if (LotValue(LOT_LONG_PROFIT)>0.00)
//      if (IsLower(sPivotHigh,Bid))
  }

//+------------------------------------------------------------------+
//| ManageRisk - sets and removes locks, stop loss, and dca plans    |
//+------------------------------------------------------------------+
void ManageRisk(void)
  {
    static bool   mpKill       = false;
    
/*    if (OrderFulfilled())
    {
        SetStopPrice(DirectionAction(fractal.Direction(Active,InContrarian)),
                      );
      if (vfAction == OP_BUY)
        SetStopPrice(OP_BUY,Bid-fmin(Pip(200,InPoints),Bid-(pregr.RangeSize-fabs(pregr.PivotDev))));

      if (vfAction == OP_SELL)
        SetStopPrice(OP_SELL,Ask+fmin(Pip(200,InPoints),Ask-(pregr.RangeSize-fabs(pregr.PivotDev))));
    }*/
  }

//+------------------------------------------------------------------+
//| Authorized - returns true if authorized to perform trade action  |
//+------------------------------------------------------------------+
bool Authorized(int Action)
  {
    static double aFOCHold       = 0.00;
    static double aPivotLowHold  = 0.00;
    static double aPivotHighHold = 0.00;
    static bool   aAuthorized    = true;
    
    if (IsEqual(aFOCHold,pregr.FOCMax,1))
      return (false);
          
    if (IsChanged(aPivotLowHold,sPivotLow) ||
        IsChanged(aPivotHighHold,sPivotHigh))
    {
      aAuthorized               = true;
      return (false);
    }

    if (OrderPending(Action))
      return (false);

    if (aAuthorized)
    {
      aAuthorized               = false;
      return (true);
    }

    return (false);
  }

//+------------------------------------------------------------------+
//| Execute - Processes the tick                                     |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static int    mbResult    = IDOK;
    static string arrowName   = "";
    
    if (mbResult==IDOK)
      mbResult = Pause("pipMA is loaded.","Pip Regression Alert",MB_OKCANCEL|MB_ICONINFORMATION|MB_DEFBUTTON2);

    VerifyFulfillment();
    
    if (IsEqual(pregr.FOCDev,0.0,1))
    {
      if (pregr.NewHigh)
      {
        if (sPivotDirection == pregr.FOCDirection)
        {
          sPivotHigh          = fmax(sPivotHigh,Close[0]);
          ObjectDelete(arrowName);
        }
        else
        {
          sPivotHigh          = Close[0];
          sPivotDirection     = DirectionUp;
        }

        arrowName = NewArrow(4,DirColor(pregr.FOCDirection,clrYellow),"pip_up",Close[0]);
      }
       
      if (pregr.NewLow)
      {
        if (sPivotDirection == pregr.FOCDirection)
        { 
          sPivotLow           = fmin(sPivotLow,Close[0]);
          ObjectDelete(arrowName);
        }
        else
        {
          sPivotLow           = Close[0];
          sPivotDirection     = DirectionDown;
        }
         
        arrowName = NewArrow(4,DirColor(pregr.FOCDirection,clrYellow),"pip_down",Close[0]);
      }
      
      ClosePendingOrders();
    }
    else
    if (IsHigher(Close[0],sPivotHigh,Digits,false))
    {
      if (!IsEqual(sPivotHigh,0.00))
        if (Authorized(OP_SELL))
          OpenMITOrder(OP_SELL,sPivotHigh-Pip(inpEntryTrail,InPoints),sPivotHigh+Pip(inpRangeMin,InPoints),0.00,Pip(inpEntryTrail,InPoints),"Auto-MIT-Short");
    }
    else
    if (IsLower(Close[0],sPivotLow,Digits,false))
    {
      if (!IsEqual(sPivotLow,0.00))
        if (Authorized(OP_BUY))
          OpenMITOrder(OP_BUY,sPivotLow+Pip(inpEntryTrail,InPoints)+Spread(),sPivotLow-Pip(inpRangeMin,InPoints)-Spread(),0.00,Pip(inpEntryTrail,InPoints),"Auto-MIT-Long");      
    }
    
    ManageProfit();
    ManageRisk();
  }
  
//+------------------------------------------------------------------+
//| RefreshScreen - repaints display                                 |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {    
    UpdateLine("phigh",sPivotHigh,STYLE_SOLID,clrYellow);
    UpdateLine("plow",sPivotLow,STYLE_SOLID,clrRed);
    UpdateLine("MinorPivot",fractal.PivotPrice(StateTerm),STYLE_DASHDOTDOT,clrYellow);
    UpdateLine("MajorPivot",fractal.PivotPrice(StateTrend),STYLE_DASHDOTDOT,DirColor(fractal.Direction(Active)));
    
    if (OrderFulfilled())
      UpdateLine("MITPrice",ordMITPrice,STYLE_DASH,clrNONE);

    if (ordMITAction==OP_BUY)
      UpdateLine("MITPrice",ordMITPrice,STYLE_DASH,clrYellow);
      
    if (ordMITAction==OP_SELL)
      UpdateLine("MITPrice",ordMITPrice,STYLE_DASH,clrRed);

    if (ordHoldTrail)
      if (eqhold==OP_BUY)
        UpdateLine("eqHold",ordHoldBase,STYLE_DOT,clrForestGreen);
      else
        UpdateLine("eqHold",ordHoldBase,STYLE_DOT,clrCrimson);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {    
    GetData();
    
    manualProcessRequest();
    OrderMonitor();
    
    if (pregr.TickLoaded)
      if (AutoTrade())
        Execute();

    RefreshScreen();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();

    NewLine("eqHold");
    NewLine("phigh");
    NewLine("plow");
    NewLine("MITPrice");
    NewLine("MinorPivot");
    NewLine("MajorPivot");
    
    NewLine("sTarget_Long");
    NewLine("sTarget_Short");
      
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pregr;
    delete tregr;
    delete fractal;
  }