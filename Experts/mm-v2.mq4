//+------------------------------------------------------------------+
//|                                                        mm-v2.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\PipRegression.mqh>
#include <Class\Fractal.mqh>
#include <manual.mqh>

input string mmv2Header            = "";    //+---- Regression Inputs -----+
input int    inpDegree             = 6;     // Degree of poly regression
input int    inpPipPeriods         = 200;   // Pip history regression periods
input double inpTolerance          = 0.5;   // Trend change sensitivity

#define FBASE 0
#define FROOT 1

CPipRegression    *pregr           = new CPipRegression(inpDegree,inpPipPeriods,inpTolerance);
CFractal          *fractal         = new CFractal(inpRange,inpRangeMin);


int      pdir             = DirectionNone;             // Fractal/Fibo calc direction
double   phigh            = 0.00;                      // Highest price pipMA zero-value 
double   plow             = 0.00;                      // Lowest price pipMA zero-value
double   phighmax         = 0.00;                      // Highest price after pipMA zero-value
double   plowmin          = 0.00;                      // Lowest price after pipMA zero-value
double   phighdev         = 0.00;                      // Highest price of non-zero pipMA dev after zero-value
double   plowdev          = 0.00;                      // Lowest price of non-zero pipMA dev after zero-value
int      pFiboEvent       = FiboRoot;                  // Current Fibo event 

datetime ftime            = 0;                         // Time of last fibo root change
double   fbaseroot[2][2]  = {{0.00,0.00},{0.00,0.00}}; // Base/Root values by Action

int      arrowCode        = SYMBOL_DASH;

//+------------------------------------------------------------------+
//| RefreshScreen - updates screen analytics data                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string rsReport = "Long  "+DoubleToStr(fdiv(fabs(fbaseroot[OP_BUY][FROOT]-Close[0]),fabs(fbaseroot[OP_BUY][FBASE]-fbaseroot[OP_BUY][FROOT]))*100,1)+"%\n"
                    + "Short "+DoubleToStr(fdiv(fabs(fbaseroot[OP_SELL][FROOT]-Close[0]),fabs(fbaseroot[OP_SELL][FBASE]-fbaseroot[OP_SELL][FROOT]))*100,1)+"%\n";
    
    if (ordHoldTrail)
      if (eqhold==OP_BUY)
        UpdateLine("eqHold",ordHoldBase,STYLE_DOT,clrForestGreen);
      else
        UpdateLine("eqHold",ordHoldBase,STYLE_DOT,clrCrimson);
    
    
    UpdateLine("phigh",phigh,STYLE_SOLID,clrYellow);
    UpdateLine("plow",plow,STYLE_SOLID,clrRed);
    UpdateLine("phighdev",phighdev,STYLE_DOT,clrYellow);
    UpdateLine("plowdev",plowdev,STYLE_DOT,clrRed);
    UpdateLine("phighmax",phighmax,STYLE_DOT,clrForestGreen);
    UpdateLine("plowmin",plowmin,STYLE_DOT,clrMaroon);
    
    if (ordLimitTrigger)
      if (ordLimitAction == OP_BUY)
        UpdateLine("LimitPrice",ordLimitPrice+(ordLimitTrail*2),STYLE_DASHDOT,clrGreen);
      else
        UpdateLine("LimitPrice",ordLimitPrice-(ordLimitTrail*2),STYLE_DASHDOT,clrRed);
    else
      if (ordLimitAction == OP_BUY)
        UpdateLine("LimitPrice",ordLimitPrice-Spread(),STYLE_DASHDOT,clrYellow);
      else
        UpdateLine("LimitPrice",ordLimitPrice,STYLE_DASHDOT,clrYellow);
      
    if (ordMITTrigger)
      UpdateLine("MITPrice",ordMITPrice,STYLE_DASH,clrRed);
    else
      UpdateLine("MITPrice",ordMITPrice,STYLE_DASH,clrYellow);
      
    if (pregr.NewHigh)
      rsReport      += "pipMA (NewHigh)\n";

    if (pregr.NewLow)
      rsReport      += "pipMA (NewLow)\n";
      
    UpdateLabel("pipMA",DoubleToStr(pregr.FOCNow,1)+" "+DoubleToStr(pregr.FOCMax,1)+" "+DoubleToStr(pregr.FOCDev,1),DirColor(pregr.CurrentFOCDirection(inpTolerance)));
      
    Comment(rsReport);
      
  }
//+------------------------------------------------------------------+
//| FiboRetracePct - returns the current fibo level of direction     |
//+------------------------------------------------------------------+
double FiboRetracePct(int Direction)
  {
    int frpAction  = DirectionAction(Direction);
    
    if (Direction == DirectionNone)
      return (NormalizeDouble(0.00,3));
      
    return (NormalizeDouble(fdiv(fabs(fbaseroot[frpAction][FROOT]-Close[0]),fabs(fbaseroot[frpAction][FBASE]-fbaseroot[frpAction][FROOT])),3));

  }

//+------------------------------------------------------------------+
//| SetZeroArrow - paints the pipMA zero arrow                       |
//+------------------------------------------------------------------+
void SetZeroArrow(int Direction)
  {
    static string    arrowName      = "";
    static int       arrowDir       = DirectionNone;
           double    arrowPrice     = 0.00;
           
    switch (Direction)
    {
      case DirectionNone:  return;
      case DirectionUp:    arrowPrice = phighmax;
                           break;
      case DirectionDown:  arrowPrice = plowmin;
                           break;
    }

    if (IsChanged(arrowDir,Direction))
    {
      arrowCode                     = SYMBOL_DASH;
      pFiboEvent                    = FiboRoot;
    }
    else      
      ObjectDelete(arrowName);

    if (FiboRetracePct(Direction)>FiboLevel(Fibo823))
    {
      arrowCode                     = SYMBOL_POINT4;
      pFiboEvent                    = Fibo823;
    }
    else
    if (FiboRetracePct(Direction)>FiboLevel(Fibo423))
    {
      arrowCode                     = SYMBOL_POINT3;
      pFiboEvent                    = Fibo423;
    }
    else
    if (FiboRetracePct(Direction)>FiboLevel(Fibo261))
    {
      arrowCode                     = SYMBOL_POINT2;
      pFiboEvent                    = Fibo261;
    }
    else  
    if (FiboRetracePct(Direction)>FiboLevel(Fibo161))
    {
      arrowCode                     = SYMBOL_POINT1;
      pFiboEvent                    = Fibo161;
    }

    arrowName = NewArrow(arrowCode,DirColor(pregr.FOCDirection,clrYellow),DirText(arrowDir),arrowPrice);
  }
  
//+------------------------------------------------------------------+
//| AnalyzeData - completes fibo event calculations                  |
//+------------------------------------------------------------------+
void AnalyzeData(void)
  {
    
  }
  
//+------------------------------------------------------------------+
//| GetData - retrieves data from indicators; exec prelim calcs      |
//+------------------------------------------------------------------+
void GetData(void)
  {
    int gdArrowDir  = DirectionNone;
    
    pregr.Update();
    fractal.Update();
  
    if (fractal.StateChanged())
    {
      if (fractal.Direction(StateTerm) == DirectionUp)
        NewArrow(SYMBOL_ARROWUP,clrYellow,"Fractal",Bid);

      if (fractal.Direction(StateTerm) == DirectionDown)
        NewArrow(SYMBOL_ARROWDOWN,clrRed,"Fractal",Bid);
    }
    
    if (pregr.NewHigh || pregr.NewLow)
    {
      if (IsEqual(pregr.FOCDev,0.0,1))
      {
        if (pregr.NewHigh)
        {
          gdArrowDir                  = DirectionUp;
          
          if (IsChanged(pdir,pregr.FOCDirection))
          {
            ObjectSet("sfibo",OBJPROP_TIME1,ftime);
            ObjectSet("sfibo",OBJPROP_PRICE1,plowmin);

            phigh                     = Close[0];
            phighmax                  = Close[0];

            ftime                     = Time[0];
            fbaseroot[OP_SELL][FBASE] = plowmin;
          }            

          if (IsChanged(phighmax,fmax(phighmax,Close[0])))
          {
            ftime                     = Time[0];
            fbaseroot[OP_SELL][FROOT] = phighmax;

            ObjectSet("sfibo",OBJPROP_TIME2,ftime);
            ObjectSet("sfibo",OBJPROP_PRICE2,phighmax);
          }            
        }
       
        if (pregr.NewLow)
        {
          gdArrowDir                  = DirectionDown;
         
          if (IsChanged(pdir,pregr.FOCDirection))
          {
            ObjectSet("lfibo",OBJPROP_TIME1,ftime);
            ObjectSet("lfibo",OBJPROP_PRICE1,phighmax);

            plow                      = Close[0];
            plowmin                   = Close[0];
            
            ftime                     = Time[0];
            fbaseroot[OP_BUY][FBASE]  = phighmax;
          }

          if (IsChanged(plowmin,fmin(plowmin,Close[0])))
          {
            ftime                     = Time[0];
            fbaseroot[OP_BUY][FROOT]  = plowmin;

            ObjectSet("lfibo",OBJPROP_TIME2,ftime);
            ObjectSet("lfibo",OBJPROP_PRICE2,plowmin);
          }            
        }
      }
      else
      {
        if (pregr.NewHigh)
          phighdev                  = Close[0];

        if (pregr.NewLow)
          plowdev                   = Close[0];
      }
           
      if (IsChanged(phighmax,fmax(phighmax,Close[0])))
      {
        ftime                       = Time[0];
        fbaseroot[OP_SELL][FROOT]   = phighmax;
        
        gdArrowDir                  = DirectionUp;

        ObjectSet("sfibo",OBJPROP_TIME2,ftime);
        ObjectSet("sfibo",OBJPROP_PRICE2,phighmax);
      }

      if (IsChanged(plowmin,fmin(plowmin,Close[0])))
      {
        ftime                       = Time[0];
        fbaseroot[OP_BUY][FROOT]    = plowmin;

        gdArrowDir                  = DirectionDown;

        ObjectSet("lfibo",OBJPROP_TIME2,ftime);
        ObjectSet("lfibo",OBJPROP_PRICE2,plowmin);
    }
      }

    SetZeroArrow(gdArrowDir);
  }
    
//+------------------------------------------------------------------+
//| ManageOrders - Order entry management; analyze data and execute  |
//+------------------------------------------------------------------+
void ManageOrders(void)
  {
    static double moLastLowMin      = 0.00;
    static double moLastHighMax     = 0.00;
    static int    moLastAction      = NoValue;
    static int    moLastFiboEvent   = FiboRoot;
    static double moEventData[2][2] = {{0.00,0.00},{0.00,0.00}};
    static int    moPivotDir        = DirectionNone;

    if (IsChanged(moLastFiboEvent,pFiboEvent))
      Pause ("Houston, we have an attitude change!\n"
           + "     To: "+DoubleToStr(FiboLevel(pFiboEvent)*100,1)+"%",
        "Major Fibo Change");
  }
  
//+------------------------------------------------------------------+
//| ExecuteTick - processes analytics, trades within the tick        |
//+------------------------------------------------------------------+
void ExecuteTick(void)
  {
    ManageOrders();
  
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
        ExecuteTick();

    RefreshScreen();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();
    
    ObjectCreate("lfibo",OBJ_FIBO,0,0,0);
    ObjectCreate("sfibo",OBJ_FIBO,0,0,0);
    
    ObjectSet("lfibo",OBJPROP_LEVELCOLOR,clrForestGreen);    
    ObjectSet("sfibo",OBJPROP_LEVELCOLOR,clrMaroon);
    
    NewLabel("pipMA","",5,5,clrGray,SCREEN_LL);

//    NewLine("eqHold");
    NewLine("phigh");
    NewLine("plow");
/*    NewLine("phighmax");
    NewLine("plowmin");
    NewLine("phighdev");
    NewLine("plowdev");
    NewLine("MITPrice");
    NewLine("LimitPrice");
*/    
    return(INIT_SUCCEEDED); 
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pregr;
  }