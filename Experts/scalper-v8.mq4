//+------------------------------------------------------------------+
//|                                                   scalper-v8.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\PipRegression.mqh>
#include <Class\TrendRegression.mqh>
#include <Class\Fractal.mqh>
#include <manual.mqh>

//--- Input params
input string scv8Header            = "";    //+---- Regression Inputs -----+
input int    inpDegree             = 6;     // Degree of poly regression
input int    inpPipPeriods         = 200;   // Pip history regression periods
input int    inpTrendPeriods       = 24;    // Trend regression periods
input int    inpSmoothFactor       = 3;     // Trend MA Smoothing Factor
input double inpTolerance          = 0.5;   // Trend change sensitivity


CPipRegression    *pregr           = new CPipRegression(inpDegree,inpPipPeriods,inpTolerance);
CTrendRegression  *tregr           = new CTrendRegression(inpDegree,inpTrendPeriods,inpSmoothFactor);
CFractal          *fractal         = new CFractal(inpRange,inpRangeMin);


//--- Order Fulfillment/Current ticket details
int             sAction            = OP_NO_ACTION;
int             sTicket            = NoValue;
double          sOpenPrice         = 0.00;
double          sProfitLoss        = 0.00;
int             sQuota             = 4;
datetime        sOpenTime          = 0;
string          sReport            = "";
int             sHedgeAction       = OP_NO_ACTION;   

int             frFractalState     = NoValue; 

//+------------------------------------------------------------------+
//| GetData - retrieves analytical data                              |
//+------------------------------------------------------------------+
void GetData(void)
  {
    //--- Get analytics data
    pregr.Update();
    tregr.Update();
    fractal.Update();
    
    //--- Consolidate fractal state
    frFractalState                 = Active;

    if (fractal.IsDivergent())  frFractalState = Divergent;
    if (fractal.IsConvergent()) frFractalState = Convergent;
    if (fractal.IsInvergent())  frFractalState = Inversion; 
        
    //--- Clear tick vars
    sReport                        = "";
    
    if ((int)LotCount()==0)
      sHedgeAction                 = OP_NO_ACTION;
      
    UpdateLine("trail",ordHoldBase,STYLE_DASH,clrYellow);
  }
  
//+------------------------------------------------------------------+
//| VerifyFulfillment - Updates last order filled data               |
//+------------------------------------------------------------------+
void VerifyFulfillment(void)
  {  
    if (OrderFulfilled(sAction,sTicket,sOpenPrice))
    {
      if (OrderSelect(sTicket,SELECT_BY_TICKET,MODE_TRADES))
      {
        sOpenTime  = TimeCurrent();
        
        if (OrderComment()=="Hedge")
          sHedgeAction  = OrderType();          
      }
    }
        
    if (OrderSelect(sTicket,SELECT_BY_TICKET,MODE_TRADES))
    {
      sProfitLoss       = OrderProfit();
        
      sReport  += "------ Fulfillment Manager ---------\n"
                + IntegerToString(sTicket)
                + " "+ActionText(sAction)
                + "  @"+DoubleToStr(sOpenPrice,Digits)
                + "  Stop:"+DoubleToStr(OrderStopLoss(),Digits)
                + "  Target:"+DoubleToStr(OrderTakeProfit(),Digits)
                + "  Profit: "+DoubleToStr(OrderProfit(),2)+"\n";
                
      if (sHedgeAction!=OP_NO_ACTION)
        sReport += " *** Hedge "+proper(ActionText(sHedgeAction))+"\n";
    }
  }

//+------------------------------------------------------------------+
//| ManageRisk - Manages risk - halts trading if necessary           |
//+------------------------------------------------------------------+
void ManageRisk(void)
  {
/*    static int mrFractalState = NoValue;
    
    if (NormalizeDouble(-EquityPercent(),1)>ordEQMaxRisk-2)
      SetProfitPolicy(eqhalt);
      
    if (IsChanged(mrFractalState,frFractalState))
    {
      if (fractal.Direction()==DirectionUp)
      {
        SetStopPrice(OP_BUY,fractal.ExpansionPrice()-Pip(inpRange+inpRangeMin,InPoints));

        if (frFractalState == Active)
          SetStopPrice(OP_SELL,fractal.RootPrice()+Pip(inpRange+inpRangeMin,InPoints));
        else
          SetStopPrice(OP_SELL,fractal.RetracePrice(Divergent)+Pip(inpRange+inpRangeMin,InPoints));
      }
          
      if (fractal.Direction()==DirectionDown)
      {
        SetStopPrice(OP_SELL,fractal.ExpansionPrice()+Pip(inpRange+inpRangeMin,InPoints));

        if (frFractalState == Active)
          SetStopPrice(OP_BUY,fractal.RootPrice()-Pip(inpRange+inpRangeMin,InPoints));
        else
          SetStopPrice(OP_BUY,fractal.RetracePrice(Divergent)-Pip(inpRange+inpRangeMin,InPoints));
      }
    }     

    if (fractal.Direction(Trend) == DirectionUp)
      if (fractal.Direction(Term) == DirectionUp)
        if (tregr.FOCRetrace<-FiboLevel(Fibo50))
          if (LotValue(LOT_SHORT_NET)<0.00)
            if (!DCAPlanPending(OP_SELL))
              OpenDCAPlan(OP_SELL,ordEQMinProfit,CLOSE_ALL);

    if (fractal.Direction(Trend) == DirectionDown)
      if (fractal.Direction(Term) == DirectionDown)
        if (tregr.FOCRetrace>FiboLevel(Fibo50))
          if (LotValue(LOT_LONG_NET)<0.00)
            if (!DCAPlanPending(OP_BUY))
              OpenDCAPlan(OP_BUY,ordEQMinProfit,CLOSE_ALL);
*/
  }

//+------------------------------------------------------------------+
//| ManageProfit - analyzes open trades and refines targets          |
//+------------------------------------------------------------------+
void ManageProfit(void)
  {      
    if (IsEqual(pregr.FOCDev,0.0,1))
    {
      if (tregr.FOCDirection == DirectionUp)
        CloseOrders(CLOSE_CONDITIONAL,OP_BUY);

      if (tregr.FOCDirection == DirectionDown)
        CloseOrders(CLOSE_CONDITIONAL,OP_SELL);      
    }
  }

//+------------------------------------------------------------------+
//| AvailableQuota - returns true on available quota                 |
//+------------------------------------------------------------------+
bool AvailableQuota(int Action)
  {
    double ActionCount[2];
    
    ActionCount[OP_BUY]  = LotCount(LOT_LONG_ORDERS);
    ActionCount[OP_SELL] = LotCount(LOT_SHORT_ORDERS);

    if (Action!=OP_NO_ACTION)
      if ((int)ActionCount[Action]>=sQuota)
        return (false);
  
    return (true);
  }

//+------------------------------------------------------------------+
//| Authorized - returns true if trade meets analyst requirements    |
//+------------------------------------------------------------------+
bool Authorized(int Action)
  {
    static double aLastAuth  = 0.00;
    static bool   aZeroAuth  = false;
           double aTPolyNow  = tregr.PHead();

//    if (IsEqual(pregr.FOCMax,aLastAuth,1))
//      return (false);

    if (AvailableQuota(Action))
    {
      if (IsEqual(pregr.FOCDev,0.0,1))
        if (aZeroAuth)
          return (false);
        else
          aZeroAuth         = true;
      else
        aZeroAuth           = false;
        
      aLastAuth             = pregr.FOCMax;

      if (IsEqual(pregr.FOCDev,0.0,1))
      {
//      Pause ("I'm trying to "+ActionText(Action)+"@"+DoubleToStr(aTPolyNow,Digits)+" but the damn thing won't honor my request!","Why won't you let me trade?!?");
        if (Action == OP_SELL)
          if (pregr.NewHigh)
            return (true);

        if (Action == OP_BUY)
          if (pregr.NewLow)
            return (true);
      }
      else
      if (IsEqual(pregr.FOCDev,0.1,1))
        return (true);
    }
      
    return (false);
  }
  
//+------------------------------------------------------------------+
//| ManageOrders - analyzes account manager orders and refines       |
//+------------------------------------------------------------------+
void ManageOrders(void)
  {
    VerifyFulfillment();

    //--- Hedge Entry
    if (IsEqual(pregr.FOCDev,0.0,1))
    {
      if (pregr.FOCDirection == DirectionUp)
      {
        if (OrderPending(OP_SELL))
          if (IsHigher(pregr.PHead(),ordMITPrice))
            OpenMITOrder(OP_SELL,pregr.PHead(),0.00,0.00,0.00,"Adjusted");

        if (Authorized(OP_SELL))
          OpenMITOrder(OP_SELL,pregr.PHead(),0.00,0.00,0.00,"Base");        
      }
      
      if (pregr.FOCDirection == DirectionDown)      
      {
        if (OrderPending(OP_BUY))
          if (IsLower(pregr.PHead()+Spread(InPoints),ordMITPrice))
            OpenMITOrder(OP_BUY,pregr.PHead(),0.00,0.00,0.00,"Adjusted");
      
        if (Authorized(OP_BUY))
          OpenMITOrder(OP_BUY,pregr.PHead()+Spread(InPoints),0.00,0.00,0.00,"Base");
      }
    }
    else
    if (Authorized(OP_NO_ACTION));
  }
  
//+------------------------------------------------------------------+
//| Execute - executes orders, risk, profit management               |
//+------------------------------------------------------------------+
void Execute(void)
  {
    static int mbCancel = IDOK;

    if (mbCancel == IDOK)
      mbCancel = Pause("Regression analysis complete","Progress",MB_OKCANCEL|MB_ICONINFORMATION|MB_DEFBUTTON1);  

    ManageOrders();
    ManageProfit(); 
    ManageRisk();
      
    Comment(sReport);    
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();
    
    manualProcessRequest();
    OrderMonitor();
        
    if (manualAuto)
      if (pregr.TickLoaded)
        Execute();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();
      
    NewLine("trail");
    SetEquityTarget(0.5,0.1);
    SetRisk(20,5);
            
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
