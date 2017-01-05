//+------------------------------------------------------------------+
//|                                                   scalper-v4.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\PipRegression.mqh>
#include <Class\ArrayDouble.mqh>
#include <manual.mqh>

//--- Fibo calculation forms
#define  FiboExpansion               1
#define  FiboRetrace                 2
    

    //--- Class data containers
    CPipRegression *pregr          = new CPipRegression(inpDegree,inpPeriod,inpTolerance);
    CArrayDouble   *fibo           = new CArrayDouble(0);

    //--- Order Fulfillment/Current ticket details
    int         sAction            = OP_NO_ACTION;
    int         sTicket            = NoValue;
    double      sOpenPrice         = 0.00;
    int         sQuota             = 4;
    datetime    sOpenTime          = 0;
    string      sReport            = "";

    //--- Fibo data
    double      sFiboHigh          = High[0]; 
    double      sFiboLow           = Low[0];
    double      sFiboMaxRetrace    = 0.00;
    
    bool        sFiboReversal      = false;
    int         sFiboDirection     = DirectionNone;


//+------------------------------------------------------------------+
//| sFibo - returns the current fibo value                           |
//+------------------------------------------------------------------+
int sFiboAction(int Type=InAction, bool Contrarian=false)
  {
    if (fibo.Count>1)
    {
      if (sFiboRoot()>sFiboBase())
      {
        if (Type == InAction)
          if (Contrarian)
            return (OP_BUY);
          else
            return (OP_SELL);

        if (Type == InDirection)
          if (Contrarian)
            return (DirectionUp);
          else
            return (DirectionDown);
      }      

      if (sFiboRoot()<sFiboBase())
      {
        if (Type == InAction)
          if (Contrarian)
            return (OP_SELL);
          else
            return (OP_BUY);

        if (Type == InDirection)
          if (Contrarian)
            return (DirectionDown);
          else
            return (DirectionUp);
      }      
    }      

    if (Type == InAction)
      return (OP_NO_ACTION);
      
    return(DirectionNone);
  }

//+------------------------------------------------------------------+
//| sFibo - returns the current fibo value                           |
//+------------------------------------------------------------------+
double sFibo(int Form=FiboExpansion, int Type=InMax)
  {    
    if (fibo.Count>1)
    {
      if (Form == FiboRetrace)
      {        
        if (Type == InMax)
          return (NormalizeDouble(sFiboMaxRetrace,3));
                  
        if (Type == InNow)
        {
          if (sFiboDirection == DirectionUp)
            return (NormalizeDouble((fmax(sFiboExpansion(),sFiboBase())-Close[0])/fmax(fabs(sFiboRoot()-sFiboBase()),fabs(sFiboRoot()-sFiboExpansion())),3));
                                    
          if (sFiboDirection == DirectionDown)
            return (NormalizeDouble((Close[0]-fmin(sFiboExpansion(),sFiboBase()))/fmax(fabs(sFiboRoot()-sFiboBase()),fabs(sFiboRoot()-sFiboExpansion())),3));
        }
      }
      
      if (Form == FiboExpansion && Type == InMax)
        return (NormalizeDouble((sFiboRoot()-sFiboExpansion())/(sFiboRoot()-sFiboBase()),3));

      if (Form == FiboExpansion && Type == InNow)
        return (NormalizeDouble((sFiboRoot()-Close[0])/(sFiboRoot()-sFiboBase()),3));
    }      

    return(0.00);
  }

//+------------------------------------------------------------------+
//| sFiboBase - returns the current fibo base                        |
//+------------------------------------------------------------------+
double sFiboBase(void)
  {
    if (fibo.Count>1)
      return (NormalizeDouble(fibo[1],Digits));
      
    return(0.00);
  }
  
//+------------------------------------------------------------------+
//| sFiboRoot - returns the current fibo root                        |
//+------------------------------------------------------------------+
double sFiboRoot(void)
  {
    if (fibo.Count>1)
      return (NormalizeDouble(fibo[0],Digits));
      
    return(0.00);
  }
  
//+------------------------------------------------------------------+
//| sFiboExpansion - returns the expansion of the active fibo        |
//+------------------------------------------------------------------+
double sFiboExpansion(void)
  {
    if (fibo.Count>1)
    {
      if (sFiboRoot()>sFiboBase())
        return (NormalizeDouble(sFiboLow,Digits));

      if (sFiboRoot()<sFiboBase())
        return (NormalizeDouble(sFiboHigh,Digits));
    }
    
    return (0.00);
  }

//+------------------------------------------------------------------+
//| UpdateFibo - updates fibo price array                            |
//+------------------------------------------------------------------+
void UpdateFibo(int Direction)
  {    

    if ((NormalizeDouble(High[0],Digits)>NormalizeDouble(High[1],Digits)) &&
        (NormalizeDouble(Low[0],Digits)<NormalizeDouble(Low[1],Digits)))
    {
      if (fibo.Count > 1)
         sFiboReversal      = true;
    }
    else
       sFiboReversal        = false;
      
    if (sFiboDirection == DirectionNone)
      sFiboDirection        = Direction;
    else
    {
    if (sFiboReversal)
    {
      if (sFiboDirection == DirectionDown)
        if (NormalizeDouble(High[0],Digits) == NormalizeDouble(Close[0],Digits))
          if (NormalizeDouble(Close[0],Digits)>sFiboRoot())
          {
            fibo.Insert(0,sFiboLow);
            sFiboHigh       = High[0];
            sFiboDirection *= DirectionInverse;
          }

      if (sFiboDirection == DirectionUp)
        if (NormalizeDouble(Low[0],Digits) == NormalizeDouble(Close[0],Digits))
          if (NormalizeDouble(Close[0],Digits)<sFiboRoot())
          {
            fibo.Insert(0,sFiboHigh);
            sFiboLow        = Low[0];
            sFiboDirection *= DirectionInverse;
          }      
      }
      else    
      {           
        if (Direction == DirectionDown)
        {
          fibo.Insert(0,sFiboHigh);
          sFiboLow          = Low[0];
        }

        if (Direction == DirectionUp)
        {
          fibo.Insert(0,sFiboLow);
          sFiboHigh         = High[0];
        }      

        sFiboDirection      = Direction;
      }
      
      UpdateLine("Base",sFiboBase(),STYLE_SOLID,clrDodgerBlue);
      UpdateLine("Root",sFiboRoot(),STYLE_SOLID,clrGoldenrod);
    }
  }
  
//+------------------------------------------------------------------+
//| CalcFibo - retrieves analytical data                             |
//+------------------------------------------------------------------+
void CalcFibo(void)
  {           
    if (NormalizeDouble(High[0],Digits)>NormalizeDouble(High[1],Digits))
    {
      if (sFiboDirection != DirectionUp)
        UpdateFibo(DirectionUp);

      sFiboHigh          = fmax(sFiboHigh,High[0]);      
    }
      
    if (NormalizeDouble(Low[0],Digits)<NormalizeDouble(Low[1],Digits))
    {
      if (sFiboDirection != DirectionDown)
        UpdateFibo(DirectionDown);

      sFiboLow           = fmin(sFiboLow,Low[0]);
    }
    
    if (sFibo(FiboRetrace,InNow) == 0.00)
      sFiboMaxRetrace    = 0.00;
    else
      sFiboMaxRetrace    = fmax(sFiboMaxRetrace,sFibo(FiboRetrace,InNow));

    UpdateLine("Expansion",sFiboExpansion(),STYLE_DOT,DirColor(sFiboDirection));
    
    if (fibo.Count>1)
      sReport += "------ Fibonacci Analysis ---------\n"
              +"Expansion @"+DoubleToStr(sFibo(FiboExpansion,InMax)*100,1)+"% "+DoubleToStr(sFibo(FiboExpansion,InNow)*100,1)+"%\n"
              +"Retrace @"+DoubleToStr(sFibo(FiboRetrace,InMax)*100,1)+"% "+DoubleToStr(sFibo(FiboRetrace,InNow)*100,1)+"%\n"
              +"Reversal: "+BoolToStr(sFiboReversal)+"\n";
  }

//+------------------------------------------------------------------+
//| GetData - retrieves analytical data                              |
//+------------------------------------------------------------------+
void GetData(void)
  {
    sReport              = "";
    
    //--- Get analytics data
    pregr.Update();
    
    //--- calc fibo
    CalcFibo();    
  }
  
//+------------------------------------------------------------------+
//| VerifyFulfillment - Updates last order filled data               |
//+------------------------------------------------------------------+
void VerifyFulfillment(void)
  {
    double vfStop        = 0.00;
    double vfTarget      = 0.00;
    double vfRoot        = sFiboRoot();
    double vfExpansion   = sFiboExpansion();
    
    if (OrderFulfilled(sAction,sTicket,sOpenPrice))
      if (OrderSelect(sTicket,SELECT_BY_TICKET,MODE_TRADES))
      {
        if (sAction != sFiboAction())
          Swap(vfRoot,vfExpansion);
          
        if (sFiboAction(InAction) == OP_BUY)
        {
          vfStop     = vfExpansion-((vfExpansion-vfRoot)*FiboLevel(Fibo423));
          vfTarget   = vfRoot+((vfExpansion-vfRoot)*FiboLevel(Fibo261));
        }
        
        if (sFiboAction(InAction) == OP_SELL)
        {
          vfStop     = vfExpansion+((vfRoot-vfExpansion)*FiboLevel(Fibo423));
          vfTarget   = vfRoot-((vfRoot-vfExpansion)*FiboLevel(Fibo261));
        }
        
        if (UpdateTicket(sTicket,vfTarget,vfStop))
          sOpenTime  = TimeCurrent();
      }
        
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
    double maxrisk = ordEQMinProfit;
    
/*    if (NormalizeDouble(EquityPercent(),1)<-(ordEQRisk-1))
      SetProfitPolicy(eqhalt);
    
    if (IsHigher(-LotValue(LOT_LONG_NET,IN_EQUITY),maxrisk,1,false))
      SetDCA(OP_BUY,ordEQTargetMin,CLOSE_MIN);

    if (IsHigher(-LotValue(LOT_SHORT_NET,IN_EQUITY),maxrisk,1,false))
      SetDCA(OP_SELL,ordEQTargetMin,CLOSE_MIN);
      
    if (IsEqual(ordDCAAction,DirAction(pregr.StdDevDirection)))
      SetEquityHold(ordDCAAction);
*/
  }

//+------------------------------------------------------------------+
//| ManageProfit - analyzes open trades and refines targets          |
//+------------------------------------------------------------------+
void ManageProfit(void)
  {
    static int mpQuota        = 0;
    static int mpAction       = OP_NO_ACTION;
    static int mpHold[2]      = {0,0};
    static int mpHoldLevel    = 0;
    
    if (sFiboAction() == OP_NO_ACTION)
      return;
    
    if (sFibo()<FiboLevel(Fibo100))
    {
      mpQuota                 = Fibo100+(mpHold[sFiboAction(InAction)]-mpHold[sFiboAction(InAction,InContrarian)]);
      mpHoldLevel             = Fibo161;
    }

    if (sFibo()>FiboLevel(mpHoldLevel))
    {      
      if (mpAction != sFiboAction(InAction))
      {              
        if (mpHold[sFiboAction(InAction,InContrarian)]>0)
          mpHold[sFiboAction(InAction,InContrarian)]--;
      }

      mpAction              = sFiboAction(InAction);
      
      if (mpQuota<Fibo100)
      {
        mpHold[sFiboAction(InAction)]++;
        mpHoldLevel++;
      }
    }

   
    if (sFibo()>FiboLevel(Fibo161))
    {
      if (mpHold[sFiboAction(InAction)]>1)
      {
        SetEquityHold(sFiboAction(InAction));
        mpHold[sFiboAction(InAction,InContrarian)]=0;
      }
      else
      if (mpHold[sFiboAction(InAction,InContrarian)]>1)
        SetEquityHold(sFiboAction(InAction,InContrarian));
      else
        SetEquityHold(OP_NO_ACTION);
    }
    
    if (sFibo()>FiboLevel(mpQuota))
      if (CloseOrders(CLOSE_CONDITIONAL,sFiboAction(InAction)))
        mpQuota++;
        
//    if (OrdersTotal()>0)
      sReport       += "------ Profit Manager ---------\n"
                    +"Target: "+DoubleToStr(FiboLevel(mpQuota,InPercent),1)+"%"
                    +"  Action: "+proper(ActionText(mpAction))
                    +"  Hold "+proper(ActionText(eqhold))
                    +" (L:S): "+IntegerToString(mpHold[OP_BUY])+":"+IntegerToString(mpHold[OP_SELL])
                    +"\n";
  }

//+------------------------------------------------------------------+
//| Authorized - returns true if trade meets analyst requirements    |
//+------------------------------------------------------------------+
bool Authorized(void)
  {
    static int aQuota   = 0;
        

    if (sFibo()<FiboLevel(Fibo100))
      aQuota            = 0;
    else
    {
      sReport += "------ Authorization Manager ---------\n"
              +"Pending "+proper(ActionText(sFiboAction(InAction,InContrarian)))+" Authorization @"+DoubleToStr(FiboLevel(Fibo100+aQuota,InPercent),1)+"%\n";
    
      if (sFibo()>FiboLevel(Fibo100+aQuota))
        if (OrderFulfilled())
          aQuota++;
        else
          return (true);
    }
    
    return (false);
  }
  
//+------------------------------------------------------------------+
//| ManageOrders - analyzes account manager orders and refines       |
//+------------------------------------------------------------------+
void ManageOrders(void)
  {
    static double entryPrice = 0.00;
    
    VerifyFulfillment();
    
    if (OrderFulfilled())
      entryPrice             = 0.00;

    if (Authorized())    
    {
      if (sFiboAction()== OP_BUY)
      {
        if (IsEqual(entryPrice,0.00))
          entryPrice         = Bid+point(inpSlipFactor);
          
        if (IsHigher(Bid-point(inpSlipFactor),entryPrice))
          OpenMITOrder(OP_SELL,entryPrice,0.00,0.00,"Orig");
      }

      if (sFiboAction()== OP_SELL)
      {
        if (IsEqual(entryPrice,0.00))
          entryPrice         = Ask-point(inpSlipFactor);
          
        if (IsLower(Ask+point(inpSlipFactor),entryPrice))
          OpenMITOrder(OP_BUY,entryPrice,0.00,0.00,"Orig");
      }
    }
/*    
    if (OrderPending())
    {
      UpdateLabel("omStatus","Pending "+proper(ActionText(ordLimitAction))+" Order",clrYellow,10);
      UpdatePriceLabel("omEntry",ordLimitPrice,clrWhite);
    }
    else
    if (filled)
      UpdateLabel ("omStatus","Working",clrLawnGreen,10);
    else
      UpdateLabel ("omStatus","Searching ("+DoubleToStr(pregr.FOCDev,1)+")",clrForestGreen,10);
  
    UpdateLabel ("pregrStatus","Regression: ("+DoubleToStr(pregr.FOCMax,1)+":"+DoubleToStr(pregr.FOCDev,1)+") StdDev:"+DirText(pregr.StdDevDirection),DirColor(pregr.FOCDirection),10);
 */
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
        
    fibo.AutoExpand = true;
    
    NewLabel("omStatus","",8,28);
    NewLabel("pregrStatus","",8,42);
    NewPriceLabel("omEntry");

    NewLine("Base");
    NewLine("Root");
    NewLine("Expansion");

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pregr;
    delete fibo;
  }
