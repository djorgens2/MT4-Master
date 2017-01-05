//+------------------------------------------------------------------+
//|                                                   scalper-v3.mq4 |
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

#include <Class\Fractal.mqh>
#include <Class\PipRegression.mqh>
#include <manual.mqh>

#define   OrderBase                2

CPipRegression *pregr              = new CPipRegression(inpDegree,inpPeriod,inpTolerance);
CFractal       *fractal            = new CFractal(inpRange,inpRangeMin);


//--- Order Fulfillment/Current ticket details
int             sAction            = OP_NO_ACTION;
int             sTicket            = NoValue;
double          sOpenPrice         = 0.00;
double          sProfitLoss        = 0.00;

int             sShortQuota        = 0;
int             sLongQuota         = 0;

double          jrData[8];
double          srData[8];

int             jrDirection        = DirectionNone;
int             stDirection161     = DirectionNone;
int             ltDirection161     = DirectionNone;


//+------------------------------------------------------------------+
//| Pause - pauses execution and waits for user input                |
//+------------------------------------------------------------------+
void Pause(string Message, string Title)
  {
    //MessageBoxW(0, Message, Title, 64);        
  }
  
  
//+------------------------------------------------------------------+
//| Authorized - Returns true if order is authorized                 |
//+------------------------------------------------------------------+
bool Authorized(int Action)
  {    
    bool safe       = IsBetween(jrData[Expansion],jrData[Base],jrData[Root],Digits);
    
    if (LotCount() == 0)
    {
      sLongQuota    = 0;
      sShortQuota   = 0;

      safe          = true;
    }
          
    if (NormalizeDouble(pregr.FOCNow,1)>NormalizeDouble(inpTolerance,1))
      sLongQuota    = 0;
      
    if (NormalizeDouble(-pregr.FOCNow,1)>NormalizeDouble(inpTolerance,1))
      sShortQuota   = 0;

    
    if (Action == OP_BUY)
    {
      if (!safe)
        if (sAction == OP_BUY && NormalizeDouble(sProfitLoss,Digits)>=0.00 && LotValue(LOT_LONG_NET)>=0.00)
          safe      = true;
                
      if (safe)
        if (sLongQuota == 0 && NormalizeDouble(pregr.FOCNow,1)<0.00)  //--- Roots only
//        if (sLongQuota == 0 || NormalizeDouble(pregr.FOCDev,1)>pow(OrderBase,sLongQuota))
        {
          Comment("Order Authorized: "+proper(ActionText(Action))+"@"+DoubleToStr(Close[0],Digits)
                                      +"  Auth Code:"+DoubleToStr(pregr.FOCDev,1)+"."+DoubleToStr(pow(2,sLongQuota),1));
          return (true);
        }
      else
        if (sLongQuota == 0 && NormalizeDouble(pregr.FOCNow,1)>0.00)  //--- Roots only
        {
          //--- Handle pullbacks
        }
//      Comment("Calculating buy entry @"+DoubleToStr(fmax(ordMITPrice,ordLimitPrice),Digits));
    }  
    
    if (Action == OP_SELL)
    {
      if (!safe)
        if (sAction == OP_SELL && NormalizeDouble(sProfitLoss,Digits)>=0.00 && LotValue(LOT_SHORT_NET)>=0.00)
          safe      = true;
    
      if (safe)
//        if (NormalizeDouble(pregr.FOCDev,1)>pow(2,sShortQuota))
        if (sShortQuota == 0 || NormalizeDouble(pregr.FOCDev,1)>pow(2,sShortQuota))
        {
          Comment("Order Authorized: "+proper(ActionText(Action))+"@"+DoubleToStr(Close[0],Digits)
                                      +"  Auth Code:"+DoubleToStr(pregr.FOCDev,1)+"."+DoubleToStr(pow(2,sShortQuota),1));
          return (true);
        }
      
//      Comment("Calculating short entry @"+DoubleToStr(fmax(ordMITPrice,ordLimitPrice),Digits));
    }

    return (false);
  }
  
//+------------------------------------------------------------------+
//| CalcExpansion - Computes fibo expansions on fractal change       |
//+------------------------------------------------------------------+
void CalcExpansion(int Direction)
  {     
     jrDirection        = Direction;
     jrData[Base]       = jrData[Root];
     jrData[Root]       = jrData[Expansion];

     NewArrow(4,DirColor(Direction,clrYellow,clrRed),"",Close[0]);
     UpdateExpansion(Close[0]);

     jrData[Convergent] = fmin(jrData[Base],jrData[Root]) - (fabs(jrData[Base]-jrData[Root])*FiboLevels[Fibo61]);
     jrData[Divergent]  = fmax(jrData[Base],jrData[Root]) + (fabs(jrData[Base]-jrData[Root])*FiboLevels[Fibo61]);
     
     if (Direction == DirectionUp)
       Swap(jrData[Convergent],jrData[Divergent],Digits);
  }
  

//+------------------------------------------------------------------+
//| UpdateExpansion - Updates fibo expansion direction and price     |
//+------------------------------------------------------------------+
void UpdateExpansion(double ExpansionPrice)
  {
     jrData[Expansion]    = ExpansionPrice;
     
     if (pregr.TickLoaded)
     {
       jrData[Retrace]      = jrData[Expansion]-((jrData[Base]-jrData[Expansion])*FiboLevels[Fibo61]);
       jrData[Active]       = (jrData[Expansion]-jrData[Root])/(jrData[Base]-jrData[Root]);
     }
     
     UpdatePriceLabel("jrRetrace",jrData[Retrace]);
     UpdateLabel("jrActive",DoubleToStr(jrData[Active]*100,1)+"%",DirColor(jrDirection),15);

     if (jrDirection == DirectionUp)
       if (NormalizeDouble(High[0],Digits) > NormalizeDouble(fmax(jrData[Convergent],jrData[Divergent]),Digits))
         stDirection161   = DirectionUp;
         
     if (jrDirection == DirectionDown)
       if (NormalizeDouble(Low[0],Digits)  < NormalizeDouble(fmin(jrData[Convergent],jrData[Divergent]),Digits))
         stDirection161   = DirectionDown;
  }
  

//+------------------------------------------------------------------+
//| ManageAnalysis - retrieves values and computes strategy metrics  |
//+------------------------------------------------------------------+
void ManageAnalysis(void)
  {
    //--- Get analytics data
    pregr.Update();
    fractal.Update();
    
    //---- Analyze pip data
    if (pregr.NewHigh)
      if (jrDirection == DirectionUp)
        UpdateExpansion(High[0]);
      else
        CalcExpansion(DirectionUp);
    
    if (pregr.NewLow)
      if (jrDirection == DirectionDown)
        UpdateExpansion(Low[0]);
      else
        CalcExpansion(DirectionDown);
  }
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void VerifyFulfillment(void)
  {
    string vfReport  = "";
    
    if (OrderFulfilled(sAction,sTicket,sOpenPrice))
      if (OrderSelect(sTicket,SELECT_BY_TICKET,MODE_TRADES))
      {
        if (sAction == OP_BUY)
          sLongQuota++;
      
        if (sAction == OP_SELL)
          sShortQuota++;
      }
    
    if (!OrderPending() && sTicket>NoValue)
    {
      vfReport       = IntegerToString(sTicket)
                      +" "+ActionText(sAction)
                      +"  @"+DoubleToStr(sOpenPrice,Digits)
                      +"  Quota L/S: ("+IntegerToString(sLongQuota)+"/"+IntegerToString(sShortQuota)+")\n";

      if (OrderSelect(sTicket,SELECT_BY_TICKET,MODE_TRADES))
      {
        sProfitLoss  = OrderProfit();
        
        vfReport    += "  Stop:"+DoubleToStr(OrderStopLoss(),Digits)
                      +"  Target:"+DoubleToStr(OrderTakeProfit(),Digits)
                      +"  Profit: "+DoubleToStr(OrderProfit(),2);
      }
      else
      {
        sProfitLoss  = 0.00;
        vfReport    += "  *** Ticket error *** ";
      }

      Comment(vfReport);
    }
  }

//+------------------------------------------------------------------+
//| ManageProfit - analyzes open trades and refines targets          |
//+------------------------------------------------------------------+
void ManageProfit(void)
  {
    static int lastAction = OP_NO_ACTION;
    
    if (stDirection161 == DirectionUp && lastAction != OP_BUY)
{
      if (NormalizeDouble((AccountMargin()/(AccountEquity()))*100,1)>20)
        Pause ("Margin at maximum","Margin Warning");
         
      if (jrData[Active]>=FiboLevels[Fibo161])
        if (NormalizeDouble(pregr.FOCDev,1)>0.00)
          if (CloseOrders(CLOSE_CONDITIONAL,OP_BUY))
            lastAction  = OP_BUY;
}    
    if (jrDirection == DirectionDown && jrData[Active]>=FiboLevels[Fibo100])
      lastAction  = OP_SELL;
    
//      if (jrData[Active]>=FiboLevels[Fibo161])
//        if (NormalizeDouble(pregr.FOCDev,1)>0.00)
//          if (CloseOrders(CLOSE_CONDITIONAL,OP_SELL))
//            lastAction  = OP_SELL;
    
//        if (OrderModify(sTicket,0.00,NormalizeDouble(vfStop,Digits),NormalizeDouble(vfTP,Digits),0))
//          vfReport   = "Order fulfilled: "+vfReport;
//        else
//          vfReport   = "Order fulfilled/Bad Modify: "+vfReport;
  }

//+------------------------------------------------------------------+
//| ManageRisk - analyzes open trade and refines stop loss levels    |
//+------------------------------------------------------------------+
void ManageRisk(void)
  {
  }

//+------------------------------------------------------------------+
//| ManageOrders - analyzes account manager orders and refines       |
//+------------------------------------------------------------------+
void ManageOrders(void)
  {
    if (OrderPending(OP_BUY))
    {
      if (pregr.NewHigh)
      {
        CloseLimitOrder();
        CloseMITOrder();
      }

      if (ordMITAction == OP_BUY)
      {
        if (NormalizeDouble(pregr.PHead(),Digits)<NormalizeDouble(pregr.TrendNow,Digits))
          OpenMITOrder(OP_BUY,pregr.PivotPrice-Spread(),0.00,0.00,"Account Manager");
        else
        if (NormalizeDouble(Close[0],Digits)<NormalizeDouble(pregr.TrendNow,Digits))
          OpenMITOrder(OP_BUY,pregr.PHead(),0.00,0.00,"Order Manager");
      }

      if (ordLimitAction == OP_BUY)
      {
        if (NormalizeDouble(pregr.PHead(),Digits)<NormalizeDouble(pregr.TrendNow,Digits))
        {
          CloseLimitOrder();
          OpenMITOrder(OP_BUY,pregr.PivotPrice-Spread(),0.00,0.00,"Order Manager");
        }
        else
        if (NormalizeDouble(Close[0],Digits)<NormalizeDouble(pregr.TrendNow,Digits))
          OpenLimitOrder(OP_BUY,pregr.TrendNow,0.00,0.00,"Order Manager");
      }
    }

    if (OrderPending(OP_SELL))
    {
    }
  }
  
//+------------------------------------------------------------------+
//| Execute - executes orders, risk, profit management               |
//+------------------------------------------------------------------+
void Execute(void)
  {
    int exAction = pregr.Action(InType,InContrarian);
    
    //--- Verify Limit/MIT order execution
    VerifyFulfillment();
    
    //--- Manage pending orders
    if (OrderPending())
      ManageOrders();
    else

    //--- Execute new orders
    {
      if (NormalizeDouble(pregr.FOCDev,1) > 0.1)
      {
        if (exAction == OP_BUY)
          if (Authorized(exAction))
          {
            if (NormalizeDouble(Ask,Digits)>NormalizeDouble(pregr.PivotPrice-Spread(),Digits))
            {
              //OpenLimitOrder(exAction,pregr.TrendNow,0.00,0.00,"Account Manager");
              Pause ("New Limit order opened","Execute");
            }
            else
            {
              //OpenMITOrder(exAction,pregr.PivotPrice-Spread(),0.00,0.00,"Account Manager");
              Pause ("New MIT order opened","Execute");
            }
          }
        
        if (exAction == OP_SELL)
          if (Authorized(exAction));
//            OpenMITOrder(exAction,pregr.PivotPrice-Spread(),0.00,0.00,"Account Manager");
      }
    }
    
    ManageProfit(); 
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    ManageAnalysis();
    
    UpdateLine("pBase",jrData[Base],STYLE_SOLID,DirColor(jrDirection));
    UpdateLine("pRoot",jrData[Root],STYLE_SOLID,DirColor(jrDirection));
    UpdateLine("pExpansion",jrData[Expansion],STYLE_DOT,DirColor(stDirection161));

    manualProcessRequest();
    orderMonitor();
        
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
    
    SetProfitPolicy(eqhalf);
    SetProfitPolicy(eqprofit);
    SetProfitPolicy(eqdir);
    
    SetEquityTarget(150,0.5);
    SetRisk(80,5);     

    ArrayInitialize(jrData,Close[0]);
    ArrayInitialize(srData,Close[0]);
    
    jrData[Active]  = 0.00;
    srData[Active]  = 0.00;

    NewLine("pBase");
    NewLine("pRoot");
    NewLine("pExpansion");

    NewPriceLabel("jrRetrace");
    NewLabel("jrActive","",5,5,clrLawnGreen,SCREEN_LL,0);
            
    ordDefaultStop   = 0;
    ordDefaultTarget = 0;

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pregr;
    delete fractal;
  }
