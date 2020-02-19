//+------------------------------------------------------------------+
//|                                                        mm-v3.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\PipRegression.mqh>
#include <manual.mqh>

input string mmv2Header            = "";    //+---- Regression Inputs -----+
input int    inpDegree             = 6;     // Degree of poly regression
input int    inpPipPeriods         = 200;   // Pip history regression periods
input double inpTolerance          = 0.5;   // Trend change sensitivity

//--- Fibo calc array
#define FBASE      0
#define FROOT      1
#define FTREND     2

//--- Fibo event array
#define FNOW     0
#define FLAST    1

CPipRegression    *pregr           = new CPipRegression(inpDegree,inpPipPeriods,inpTolerance);

int      pdir             = DirectionNone;             // Fractal/Fibo calc direction
double   phigh            = 0.00;                      // Highest price pipMA zero-value 
double   plow             = 0.00;                      // Lowest price pipMA zero-value
double   phighmax         = 0.00;                      // Highest price after pipMA zero-value
double   plowmin          = 0.00;                      // Lowest price after pipMA zero-value
double   phighdev         = 0.00;                      // Highest price of non-zero pipMA dev after zero-value
double   plowdev          = 0.00;                      // Lowest price of non-zero pipMA dev after zero-value

datetime flowtime         = 0;                         // Time of last low fibo root change
datetime fhightime        = 0;                         // Time of last high fibo root change
double   fbaseroot[3][2];                              // Base/Root values by Action/Trend
double   fretrace         = 0.00;                      // Current retrace price
double   fpriorbase       = 0.00;                      // Prior base price
int      fevent           = FiboRoot;                  // Current Fibo event 

int      arrowCode        = SYMBOL_DASH;

//+------------------------------------------------------------------+
//| RefreshScreen - updates screen analytics data                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string rsReport = "Long  "+DoubleToStr(FiboRetracePct(DirectionUp)*100,1)+"% "+DoubleToStr(FiboRetracePct(DirectionUp,InMax)*100,1)+"% "+DoubleToStr(FiboRetracePct(DirectionUp,InMax,InContrarian)*100,1)+"%\n"
                    + "Short "+DoubleToStr(FiboRetracePct(DirectionDown)*100,1)+"% "+DoubleToStr(FiboRetracePct(DirectionDown,InMax)*100,1)+"% "+DoubleToStr(FiboRetracePct(DirectionDown,InMax,InContrarian)*100,1)+"%\n";
    
    if (ordHoldTrail)
      if (eqhold==OP_BUY)
        UpdateLine("eqHold",ordHoldBase,STYLE_DOT,clrForestGreen);
      else
        UpdateLine("eqHold",ordHoldBase,STYLE_DOT,clrCrimson);
    
    
    UpdateLine("phigh",phigh,STYLE_SOLID,clrYellow);
    UpdateLine("plow",plow,STYLE_SOLID,clrRed);
//    UpdateLine("phighdev",phighdev,STYLE_DOT,clrYellow);
//    UpdateLine("plowdev",plowdev,STYLE_DOT,clrRed);
    UpdateLine("fretrace",fretrace,STYLE_DOT,clrRed);
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
      
    rsReport        += "pdir "+DirText(pdir)+"\n";
    
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
double FiboRetracePct(int Direction, int Type=InNow, int Return=InExpansion)
  {
    int frpAction  = DirectionAction(Direction);
    
    if (frpAction != OP_NO_ACTION)
      return (NormalizeDouble(0.00,3));
      
    if (Direction != pdir)
      if (Return == InRetrace)
        switch (Type)
        {
          case InNow:  if (Direction == DirectionUp)
                         return (NormalizeDouble(fdiv(fmax(fbaseroot[frpAction][FROOT]-Close[0],fabs(fbaseroot[frpAction][FBASE]-fbaseroot[frpAction][FROOT])),3));
          case InMax:  if (Direction == DirectionUp)
        }
      
    switch (Type)
    {
      case InNow:  if (Return == InExpansion || pdir == Direction)
                     

      case InMax:  if (Contrarian)
                     return (NormalizeDouble(fdiv(fabs(fbaseroot[frpAction][FBASE]-fbaseroot[FRETRACE][frpAction]),fabs(fbaseroot[frpAction][FBASE]-fbaseroot[frpAction][FROOT])),3));

                   if (Direction == DirectionUp)
                     return (NormalizeDouble(fdiv(fabs(fbaseroot[frpAction][FROOT]-phighmax),fabs(fbaseroot[frpAction][FBASE]-fbaseroot[frpAction][FROOT])),3));

                   if (Direction == DirectionDown)
                     return (NormalizeDouble(fdiv(fabs(fbaseroot[frpAction][FROOT]-plowmin),fabs(fbaseroot[frpAction][FBASE]-fbaseroot[frpAction][FROOT])),3));
    }
      
    return (NormalizeDouble(0.00,3));
  }

//+------------------------------------------------------------------+
//| PriorFiboBase - returns the prior fibo base price                |
//+------------------------------------------------------------------+
double PriorFiboBase(void)
  {
    int pfbAction  =     
  }

//+------------------------------------------------------------------+
//| SetFiboBase - sets the fibo base for the supplied direction      |
//+------------------------------------------------------------------+
void SetFiboBase(int Direction)
  {    
    switch (Direction)
    {
      case DirectionUp:    {
                             ObjectSet("sfibo",OBJPROP_TIME1,flowtime);
                             ObjectSet("sfibo",OBJPROP_PRICE1,plowmin);

                             fpriorbase                = phighmax;
                             fbaseroot[OP_SELL][FBASE] = plowmin;
                             fhightime                 = Time[0];

                             phigh                     = Close[0];
                             phighmax                  = Close[0];

                             break;
                           }            

      case DirectionDown:  {
                             ObjectSet("lfibo",OBJPROP_TIME1,fhightime);
                             ObjectSet("lfibo",OBJPROP_PRICE1,phighmax);
            
                             fpriorbase                = plowmin;
                             fbaseroot[OP_BUY][FBASE]  = phighmax;
                             flowtime                  = Time[0];

                             plow                      = Close[0];
                             plowmin                   = Close[0];

                             break;
                           }
    }
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
      fevent                        = FiboRoot;
    }
    else      
      ObjectDelete(arrowName);

    if (FiboRetracePct(Direction,InMax)>FiboLevel(Fibo823))
    {
      arrowCode                     = SYMBOL_POINT4;
      fevent                        = Fibo823;
    }
    else
    if (FiboRetracePct(Direction,InMax)>FiboLevel(Fibo423))
    {
      arrowCode                     = SYMBOL_POINT3;
      fevent                        = Fibo423;
    }
    else
    if (FiboRetracePct(Direction,InMax)>FiboLevel(Fibo261))
    {
      arrowCode                     = SYMBOL_POINT2;
      fevent                        = Fibo261;
    }
    else  
    if (FiboRetracePct(Direction,InMax)>FiboLevel(Fibo161))
    {
      arrowCode                     = SYMBOL_POINT1;
      fevent                        = Fibo161;
    }
    else
    if (FiboRetracePct(Direction,InMax)>FiboLevel(Fibo100))
      if (IsChanged(arrowDir,pregr.RangeDirection))
      {
        arrowCode                     = SYMBOL_ROOT;
        fevent                        = Fibo100;
      }

    arrowName = NewArrow(arrowCode,DirColor(pdir,clrYellow),DirText(arrowDir),arrowPrice);
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
    int gdDirection  = DirectionNone;
    
    pregr.Update();

    if (pregr.NewHigh || pregr.NewLow)
    {
      if (IsEqual(pregr.FOCDev,0.0,1) || FiboRetracePct(pdir,InMax,InContrarian)>FiboLevel(Fibo100))
      {
        if (pregr.NewHigh)
          gdDirection                = DirectionUp;
          
        if (pregr.NewLow)
          gdDirection                = DirectionDown;
      }
      else
      {      
        if (pregr.NewHigh)
          phighdev                   = Close[0];

        if (pregr.NewLow)
          plowdev                    = Close[0];
          
      }

      if (gdDirection != DirectionNone)
        if (IsChanged(pdir,gdDirection))
          SetFiboBase(pdir);
          
    }

      if (IsChanged(phighmax,fmax(phighmax,Close[0])))
      {
        gdDirection                  = DirectionUp;

        fhightime                    = Time[0];
        fbaseroot[OP_SELL][FROOT]    = phighmax;
        fretrace                     = phighmax;
        
        ObjectSet("sfibo",OBJPROP_TIME2,fhightime);
        ObjectSet("sfibo",OBJPROP_PRICE2,phighmax);
      }

      if (IsChanged(plowmin,fmin(plowmin,Close[0])))
      {
        flowtime                     = Time[0];
        fbaseroot[OP_BUY][FROOT]     = plowmin;
        fbaseroot[FRETRACE][OP_SELL] = plowmin;

        gdDirection                  = DirectionDown;

        ObjectSet("lfibo",OBJPROP_TIME2,flowtime);
        ObjectSet("lfibo",OBJPROP_PRICE2,plowmin);
      }

    if (pdir == DirectionUp)
      fretrace                       = fmin(fretrace,Close[0]);

    if (pdir == DirectionDown)
      fretrace                       = fmax(fretrace,Close[0]);
           
    SetZeroArrow(gdDirection);
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

    if (IsChanged(moLastFiboEvent,fevent))
      Pause ("Houston, we have an attitude change!\n"
           + "     To: "+DoubleToStr(FiboLevel(fevent)*100,1)+"%",
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
    
    ArrayInitialize(fbaseroot,0.00);
    
    ObjectCreate("lfibo",OBJ_FIBO,0,0,0);
    ObjectCreate("sfibo",OBJ_FIBO,0,0,0);
    
    ObjectSet("lfibo",OBJPROP_LEVELCOLOR,clrForestGreen);    
    ObjectSet("sfibo",OBJPROP_LEVELCOLOR,clrMaroon);
    
    NewLabel("pipMA","",5,5,clrGray,SCREEN_LL);
    

   Print("Symbol=",Symbol()); 
   Print("Low day price=",MarketInfo(Symbol(),MODE_LOW)); 
   Print("High day price=",MarketInfo(Symbol(),MODE_HIGH)); 
   Print("The last incoming tick time=",(MarketInfo(Symbol(),MODE_TIME))); 
   Print("Last incoming bid price=",MarketInfo(Symbol(),MODE_BID)); 
   Print("Last incoming ask price=",MarketInfo(Symbol(),MODE_ASK)); 
   Print("Point size in the quote currency=",MarketInfo(Symbol(),MODE_POINT)); 
   Print("Digits after decimal point=",MarketInfo(Symbol(),MODE_DIGITS)); 
   Print("Spread value in points=",MarketInfo(Symbol(),MODE_SPREAD)); 
   Print("Stop level in points=",MarketInfo(Symbol(),MODE_STOPLEVEL)); 
   Print("Lot size in the base currency=",MarketInfo(Symbol(),MODE_LOTSIZE)); 
   Print("Tick value in the deposit currency=",MarketInfo(Symbol(),MODE_TICKVALUE)); 
   Print("Tick size in points=",MarketInfo(Symbol(),MODE_TICKSIZE));  
   Print("Swap of the buy order=",MarketInfo(Symbol(),MODE_SWAPLONG)); 
   Print("Swap of the sell order=",MarketInfo(Symbol(),MODE_SWAPSHORT)); 
   Print("Market starting date (for futures)=",MarketInfo(Symbol(),MODE_STARTING)); 
   Print("Market expiration date (for futures)=",MarketInfo(Symbol(),MODE_EXPIRATION)); 
   Print("Trade is allowed for the symbol=",MarketInfo(Symbol(),MODE_TRADEALLOWED)); 
   Print("Minimum permitted amount of a lot=",MarketInfo(Symbol(),MODE_MINLOT)); 
   Print("Step for changing lots=",MarketInfo(Symbol(),MODE_LOTSTEP)); 
   Print("Maximum permitted amount of a lot=",MarketInfo(Symbol(),MODE_MAXLOT)); 
   Print("Swap calculation method=",MarketInfo(Symbol(),MODE_SWAPTYPE)); 
   Print("Profit calculation mode=",MarketInfo(Symbol(),MODE_PROFITCALCMODE)); 
   Print("Margin calculation mode=",MarketInfo(Symbol(),MODE_MARGINCALCMODE)); 
   Print("Initial margin requirements for 1 lot=",MarketInfo(Symbol(),MODE_MARGININIT)); 
   Print("Margin to maintain open orders calculated for 1 lot=",MarketInfo(Symbol(),MODE_MARGINMAINTENANCE)); 
   Print("Hedged margin calculated for 1 lot=",MarketInfo(Symbol(),MODE_MARGINHEDGED)); 
   Print("Free margin required to open 1 lot for buying=",MarketInfo(Symbol(),MODE_MARGINREQUIRED)); 
   Print("Order freeze level in points=",MarketInfo(Symbol(),MODE_FREEZELEVEL));  

    Print(MarketInfo("GBPUSD",MODE_MARGINMAINTENANCE);
    Print(MarketInfo("GBPUSD",MODE_MARGINHEDGED);
    Print(MarketInfo("GBPUSD",MODE_MARGINMAINTENANCE);
    Print(MarketInfo("GBPUSD",MODE_MARGINMAINTENANCE);
    
//    NewLine("eqHold");
    NewLine("phigh");
    NewLine("plow");
    NewLine("phighmax");
    NewLine("plowmin");
    NewLine("phighdev");
    NewLine("plowdev");
/*    NewLine("MITPrice");
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