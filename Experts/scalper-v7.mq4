//+------------------------------------------------------------------+
//|                                                   scalper-v7.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\PipRegression.mqh>
#include <manual.mqh>

    

    //--- Class data containers
    CPipRegression *pregr          = new CPipRegression(inpDegree,inpPeriod,inpTolerance);

    //--- Order Fulfillment/Current ticket details
    int         sAction            = OP_NO_ACTION;
    int         sTicket            = NoValue;
    double      sOpenPrice         = 0.00;
    datetime    sOpenTime          = 0;
    
    int         sCloseAction       = OP_NO_ACTION;
    int         sCloseTicket       = NoValue;
    double      sClosePrice        = 0.00;
    double      sCloseProfit       = 0.00;
   
    string      sReport            = "";

//+------------------------------------------------------------------+
//| ActionCode - translates a supplied action code based on args     |
//+------------------------------------------------------------------+
int ActionCode(int Action, bool Contrarian=false, int Type=InAction)
  {
    if (Type==InAction)
      if (Contrarian)
      {
        if (Action == OP_BUY)
          return (OP_SELL);

        if (Action == OP_SELL)
          return (OP_BUY);
      }
      else
        return (Action);
        
    if (Type == InAction)
      return (OP_NO_ACTION);
      
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| GetData - retrieves analytical data                              |
//+------------------------------------------------------------------+
void GetData(void)
  {
    sReport              = "";
    
    //--- Get analytics data
    pregr.Update();
    
    UpdateDirection("pregrDir",pregr.StdDevDirection,DirColor(pregr.StdDevDirection),10);
    UpdateLabel("pregrStatus","Std Dev: "+DoubleToStr(Pip(pregr.StdDevNow),1)
               +" x:"+DoubleToStr(fmax(Pip(pregr.StdDevPos),fabs(Pip(pregr.StdDevNeg))),1)
               +" p:"+DoubleToStr(Pip(pregr.StdDev),1)
               +" +"+DoubleToStr(Pip(pregr.StdDevPos),1)
               +" "+DoubleToStr(Pip(pregr.StdDevNeg),1),DirColor(dir(pregr.StdDevNow)),10);

    if (ProfitPlanPending(OP_BUY))
      UpdateLine("pPlan",ordProfitPlan[OP_BUY][PP_TARGET],STYLE_SOLID,clrLawnGreen);
      
    if (ProfitPlanPending(OP_SELL))
      UpdateLine("pPlan",ordProfitPlan[OP_SELL][PP_TARGET],STYLE_SOLID,clrRed);

    if (eqhold==OP_BUY)
      UpdateLine("tLine",ordHoldBase,STYLE_DOT,clrForestGreen);
    
    if (eqhold==OP_SELL)
      UpdateLine("tLine",ordHoldBase,STYLE_DOT,clrMaroon);
  }
  
//+------------------------------------------------------------------+
//| VerifyFulfillment - Updates last order filled data               |
//+------------------------------------------------------------------+
void VerifyFulfillment(void)
  {    
    if (OrderFulfilled(sAction,sTicket,sOpenPrice))
      if (OrderSelect(sTicket,SELECT_BY_TICKET,MODE_TRADES))
          sOpenTime  = TimeCurrent();
        
    if (OrderSelect(sTicket,SELECT_BY_TICKET,MODE_HISTORY))
      if (OrderCloseTime()==0)        
        sReport     += "------ Fulfillment Manager ---------\n"
                    +   IntegerToString(sTicket)
                    +" "+ActionText(sAction)
                    +"  @"+DoubleToStr(sOpenPrice,Digits)
                    +"  Stop:"+DoubleToStr(OrderStopLoss(),Digits)
                    +"  Target:"+DoubleToStr(OrderTakeProfit(),Digits)
                    +"  Profit: "+DoubleToStr(OrderProfit(),2)
                    +"\n";
  }

//+------------------------------------------------------------------+
//| ManageRisk - Manages risk - halts trading if necessary           |
//+------------------------------------------------------------------+
void ManageRisk(void)
  {
    static const double mrFibo61  = point(inpDefaultStop)*FiboLevel(Fibo61);

    static int    mrLossCount[2]  = {0,0};
    static int    mrAction        = OP_NO_ACTION;
    static int    mrActionAdv     = OP_NO_ACTION;
    static double mrActionHold    = 0.00;

    if (OrderClosed(sCloseAction,sClosePrice,sCloseProfit))
      if (NormalizeDouble(sCloseProfit,2)<0.00)
      {
        mrAction                  = sCloseAction;
        mrActionAdv               = ActionCode(sCloseAction,InContrarian);
        
        if (mrActionAdv == OP_BUY)
          mrActionHold            = Bid+mrFibo61;
          
        if (mrActionAdv == OP_SELL)
          mrActionHold            = Ask-mrFibo61;

        OpenProfitPlan(mrActionAdv,mrActionHold,inpDefaultTarget,inpDefaultStop);
        OpenDCAPlan(mrAction,ordEQMinProfit,CLOSE_MIN);
        SetActionHold(mrAction);

        sReport     += "------ Risk Manager ---------\n"
                    +"Last Close: "+proper(ActionText(sCloseAction))
                    +"  @"+DoubleToStr(sClosePrice,Digits)
                    +"  Profit:"+DoubleToStr(sCloseProfit,2)
                    +"\n";
      }
      
      if (mrAction == eqholdaction)
      {
        if (mrAction == OP_BUY)
          if (Bid>mrActionHold)
            SetActionHold(OP_NO_ACTION);

        if (mrAction == OP_SELL)
          if (Ask<mrActionHold)
            SetActionHold(OP_NO_ACTION);
      }
  }

//+------------------------------------------------------------------+
//| ManageProfit - analyzes open trades and refines targets          |
//+------------------------------------------------------------------+
void ManageProfit(void)
  {
    static int mpAction  = OP_NO_ACTION;
    
    if (!Authorized(mpAction))
    {
      if (mpAction == OP_BUY)
        if (Bid<pregr.TrendNow)
          if (!ProfitPlanPending(OP_BUY) && ordDCAAction!=OP_BUY)
            CloseOrders(CLOSE_CONDITIONAL, OP_BUY);

      if (mpAction == OP_SELL)
        if (Ask>pregr.TrendNow)
          if (!ProfitPlanPending(OP_SELL) && ordDCAAction!=OP_SELL)
            CloseOrders(CLOSE_CONDITIONAL, OP_SELL);
    }
    
//    if (OrdersTotal()>0)
/*      sReport       += "------ Profit Manager ---------\n"
                    +"Target: "+DoubleToStr(FiboLevel(mpQuota,InPercent),1)+"%"
                    +"  Action: "+proper(ActionText(mpAction))
                    +"  Hold "+proper(ActionText(eqhold))
                    +" (L:S): "+IntegerToString(mpHold[OP_BUY])+":"+IntegerToString(mpHold[OP_SELL])
                    +"\n";*/
  }

//+------------------------------------------------------------------+
//| Authorized - returns true if trade meets analyst requirements    |
//+------------------------------------------------------------------+
bool Authorized(int &Action)
  {
    static int aStdDevDir  = DirectionNone;
    
    //--- Possible entry point Pos:Neg amp divergent to the Std Dev direction
    Action                 = DirAction(aStdDevDir);
        
    if (IsChanged(aStdDevDir,pregr.StdDevDirection))
      return (true);
    
    return (false);
/*    {
      sReport += "------ Authorization Manager ---------\n"
              +"Pending "+proper(ActionText(sFiboAction(InAction,InContrarian)))+" Authorization @"+DoubleToStr(FiboLevel(Fibo100+aQuota,InPercent),1)+"%\n";
    
      if (sFibo()>FiboLevel(Fibo100+aQuota))
        if (OrderFulfilled())
          aQuota++;
        else
          return (true);
    }
    
    return (false);*/
  }
  
//+------------------------------------------------------------------+
//| ManageOrders - analyzes account manager orders and refines       |
//+------------------------------------------------------------------+
void ManageOrders(void)
  {
    static double moEntryPrice  = 0.00;
    static int    moAction      = OP_NO_ACTION;
    static int    moAuthAction  = OP_NO_ACTION;
    
    VerifyFulfillment();
    
    if (OrderFulfilled())
    {
      moEntryPrice              = 0.00;
      moAction                  = OP_NO_ACTION;
    }
    
    if (Authorized(moAuthAction))
    {
      moAction                  = moAuthAction;
      
      if (OP_BUY)
        moEntryPrice            = Ask;

      if (OP_SELL)
        moEntryPrice            = Bid;
    }
    
    if (moAction == OP_SELL)
    {
      if (IsEqual(moEntryPrice,0.00))
        moEntryPrice            = Bid+point(inpSlipFactor);
          
      if (IsHigher(Bid-point(inpSlipFactor),moEntryPrice))
        OpenMITOrder(OP_SELL,moEntryPrice,0.00,0.00,"Orig");
    }

    if (moAction == OP_BUY)
    {
      if (IsEqual(moEntryPrice,0.00))
        moEntryPrice            = Ask-point(inpSlipFactor);
          
      if (IsLower(Ask+point(inpSlipFactor),moEntryPrice))
        OpenMITOrder(OP_BUY,moEntryPrice,0.00,0.00,"Orig");
    }

    if (moAction!=OP_NO_ACTION)
      sReport   += "-------- Order Manager --------\n"
                +"Pending Authorization for "+proper(ActionText(moAction))+"\n"
                +"Calculating entry from "+DoubleToStr(moEntryPrice,Digits)+"\n";
                
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
    
    Comment (sReport);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    GetData();
    
    manualProcessRequest();
    orderMonitor();
        
    if (manualAuto)
    {
      AutoInit();
      if (pregr.TickLoaded)
        Execute();
    }
    else
    {
      SetDefaults();
      AutoInit(false);
    }
  }

//+------------------------------------------------------------------+
//| AutoInit - initializes auto trade parameters                     |
//+------------------------------------------------------------------+
void AutoInit(bool Enable=true)
  {
    static bool initComplete = false;
    
    if (Enable)
    {
      if (initComplete)
        return;
      
      SetProfitPolicy(eqhalf);
      SetProfitPolicy(eqprofit);
    
      SetEquityTarget(0.5,0.1);
      SetRisk(3,5);
    
      initComplete     = true;
    
      return;
    }
    
    initComplete       = false;
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    manualInit();

    NewLabel("pregrStatus","",15,5,clrLightGray,SCREEN_LL,0);
    NewLabel("pregrDir","",5,5,clrLightGray,SCREEN_LL,0);
    
    NewLine("pPlan");
    NewLine("tLine");
            
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pregr;
  }
