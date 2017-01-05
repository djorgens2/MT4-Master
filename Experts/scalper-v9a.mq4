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
input string scv9Header            = "";    //+---- Regression Inputs -----+
input int    inpDegree             = 6;     // Degree of poly regression
input int    inpPipPeriods         = 200;   // Pip history regression periods
input int    inpTrendPeriods       = 24;    // Trend regression periods
input int    inpSmoothFactor       = 3;     // Trend MA Smoothing Factor
input double inpTolerance          = 0.5;   // Trend change sensitivity


CPipRegression    *pregr           = new CPipRegression(inpDegree,inpPipPeriods,inpTolerance);
CTrendRegression  *tregr           = new CTrendRegression(inpDegree,inpTrendPeriods,inpSmoothFactor);
CFractal          *fractal         = new CFractal(inpRange,inpRangeMin);

//+------------------------------------------------------------------+
//| GetData - Collects indicator data                                |
//+------------------------------------------------------------------+
void GetData(void)
  {
    pregr.Update();
    tregr.Update();
    fractal.Update();
  }

//+------------------------------------------------------------------+
//| Authorized - returns true if authorized to perform trade action  |
//+------------------------------------------------------------------+
bool Authorized(int Action)
  {
    static double aFOCHold = 0.00;
    
    if (IsEqual(aFOCHold,pregr.FOCMax,1))
      return (false);
      
    aFOCHold = pregr.FOCMax;
    
    return (true);
  }

//+------------------------------------------------------------------+
//| Execute - Processes the tick                                     |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static int    pdir  = DirectionNone;
    static double phigh = 0.00;
    static double plow  = 0.00;
    static int    mbResult    = IDOK;
    static string arrowName   = "";
    

    if (pregr.NewHigh || pregr.NewLow)
    {
//      if (IsLower(fabs(pregr.FOCNow),pregr.FOCDev,1,false))
//      {
//        if (mbResult!=IDCANCEL)
//          mbResult = Pause("Expect a bounce or short term correction.","Pip Regression Alert",MB_OKCANCEL|MB_ICONINFORMATION|MB_DEFBUTTON1);
//      }
//      else
//        mbResult            = IDOK;

      if (pregr.NewHigh || pregr.NewLow)
        if (IsEqual(pregr.FOCDev,0.0,1))
        {          
          if (pregr.NewHigh)
          {
            if (InStr(arrowName,"pip_up"))
              ObjectDelete(arrowName);
              
            arrowName = NewArrow(4,DirColor(pregr.FOCDirection,clrYellow),"pip_up",Close[0]);

            if (pdir!=pregr.FOCDirection)
            {
              pdir = DirectionUp;
              phigh = Close[0];
            }
            else phigh = fmax(phigh,Close[0]);
          }
          
          if (pregr.NewLow)
          {
            if (InStr(arrowName,"pip_down"))
              ObjectDelete(arrowName);
            
            arrowName = NewArrow(4,DirColor(pregr.FOCDirection,clrYellow),"pip_down",Close[0]);

            if (pdir!=pregr.FOCDirection)
            {
              pdir = DirectionDown;
              plow = Close[0];
            }
            else plow = fmin(plow,Close[0]);
          }
        }
        else
        if (IsHigher(Close[0],phigh,Digits,false) && !IsEqual(phigh,0.00))
        {
          if (Authorized(OP_SELL))
            OpenMITOrder(OP_SELL,phigh-Pip(inpSlipFactor,InPoints),phigh+Pip(inpRange,InPoints),0.00,Pip(inpSlipFactor,InPoints),"Auto-Sell");
        }
        else
        if (IsLower(Close[0],plow,Digits,false) && !IsEqual(plow,0.00))
        {
          if (Authorized(OP_BUY))
            OpenMITOrder(OP_BUY,plow+Pip(inpSlipFactor,InPoints),plow-Pip(inpRange,InPoints),0.00,Pip(inpSlipFactor,InPoints),"Auto-Buy");      
        }
    }
    
    UpdateLine("phigh",phigh,STYLE_SOLID,clrYellow);
    UpdateLine("plow",plow,STYLE_SOLID,clrRed);
    UpdateLine("MITPrice",ordMITPrice,STYLE_DASH,clrRed);
    UpdateLine("PegMinorPivot",fractal.PegMinorPivot(),STYLE_DOT,clrWhite);
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

    if (ordHoldTrail)
      if (eqhold==OP_BUY)
        UpdateLine("eqHold",ordHoldBase,STYLE_DOT,clrForestGreen);
      else
        UpdateLine("eqHold",ordHoldBase,STYLE_DOT,clrCrimson);
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
    NewLine("PegMinorPivot");

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