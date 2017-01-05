//+------------------------------------------------------------------+
//|                                                   scalper-v4.mq4 |
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
#include <Class\ArrayInteger.mqh>
#include <manual.mqh>


CPipRegression *pregr              = new CPipRegression(inpDegree,inpPeriod,inpTolerance);
CArrayInteger  *rmSuspects         = new CArrayInteger(0);

//--- Order Fulfillment/Current ticket details
int             sAction            = OP_NO_ACTION;
int             sTicket            = NoValue;
double          sOpenPrice         = 0.00;
double          sProfitLoss        = 0.00;
int             sQuota             = 0;

bool            sNewRange          = false;

double          jrData[8];

int             jrDirection        = DirectionNone;
int             stDirection        = DirectionNone;
int             ltDirection        = DirectionNone;

double          ltPivot            = 0.00;

int             rmAction           = OP_NO_ACTION;

//+------------------------------------------------------------------+
//| Pause - pauses execution and waits for user input                |
//+------------------------------------------------------------------+
int Pause(string Message, string Title, int Style=64)
  {
    return(MessageBoxW(0, Message, Title, Style));
  }
  
   
//+------------------------------------------------------------------+
//| CalcExpansion - Computes fibo expansions on fractal change       |
//+------------------------------------------------------------------+
void CalcExpansion(int Direction)
  {     
     jrDirection        = Direction;
     jrData[Base]       = jrData[Root];
     jrData[Root]       = jrData[Expansion];

     UpdateExpansion(Close[0]);

     jrData[Convergent] = fmin(jrData[Base],jrData[Root]) - (fabs(jrData[Base]-jrData[Root])*FiboLevels[Fibo61]);
     jrData[Divergent]  = fmax(jrData[Base],jrData[Root]) + (fabs(jrData[Base]-jrData[Root])*FiboLevels[Fibo61]);
     
     if (Direction == DirectionUp)
       Swap(jrData[Convergent],jrData[Divergent],Digits);
       
     sNewRange          = true;
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
     
     if (jrDirection == DirectionUp)
       if (NormalizeDouble(High[0],Digits) > NormalizeDouble(fmax(jrData[Convergent],jrData[Divergent]),Digits))
         stDirection      = DirectionUp;
         
     if (jrDirection == DirectionDown)
       if (NormalizeDouble(Low[0],Digits)  < NormalizeDouble(fmin(jrData[Convergent],jrData[Divergent]),Digits))
         stDirection      = DirectionDown;         

     if (NormalizeDouble(jrData[Active],3)>FiboLevels[Fibo261])
       if (IsChanged(ltDirection,stDirection))
         ltPivot          = Close[0];
         
     if (ltDirection == DirectionNone)
     {
       ltDirection        = stDirection;
       ltPivot            = Close[0];
     }

     UpdatePriceLabel("ltPivot",ltPivot);
     UpdateLabel("jrActive",DoubleToStr(jrData[Active]*100,1)+"%",DirColor(jrDirection),15);
  }
  

//+------------------------------------------------------------------+
//| ManageAnalysis - retrieves values and computes strategy metrics  |
//+------------------------------------------------------------------+
void ManageAnalysis(void)
  {
    //--- Get analytics data
    pregr.Update();
    
    //---- Analyze pip data
    sNewRange          = false;

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
    string vfSuspect = "";
    
    if (OrderFulfilled(sAction,sTicket,sOpenPrice))
      if (OrderSelect(sTicket,SELECT_BY_TICKET,MODE_TRADES))
        sQuota       = fmin(++sQuota,3);
        
    if (sNewRange)
      sQuota         = 0;
                  
    if (OrderSelect(sTicket,SELECT_BY_TICKET,MODE_TRADES))
    {
      sProfitLoss    = OrderProfit();
        
      vfReport       = IntegerToString(sTicket)
                      +" "+ActionText(sAction)
                      +"  @"+DoubleToStr(sOpenPrice,Digits)
                      +"  Stop:"+DoubleToStr(OrderStopLoss(),Digits)
                      +"  Target:"+DoubleToStr(OrderTakeProfit(),Digits)
                      +"  Profit: "+DoubleToStr(OrderProfit(),2)
                      +"  Auth: "+IntegerToString(sQuota)+"\n";
    }
    else
    if (sTicket>NoValue)
    {
      sProfitLoss    = 0.00;
      vfReport      += "  *** Ticket error ***\n";
    }

    for (int suspect=0; suspect<rmSuspects.Count; suspect++)
      if (OrderSelect(rmSuspects[suspect],SELECT_BY_TICKET,MODE_TRADES))
        vfSuspect   += IntegerToString(OrderTicket())+" "+ActionText(OrderType())+" "+DoubleToStr(OrderProfit(),Digits)+"\n";

    if (StringLen(vfSuspect)>0)
      vfReport      += "\n*** Suspects ("+IntegerToString(rmSuspects.Count)+")\n"+vfSuspect;
      
    Comment(vfReport);    
  }

//+------------------------------------------------------------------+
//| ExecuteHealthCheck - validates trade layout/applies corrections  |
//+------------------------------------------------------------------+
void ExecuteHealthCheck(int Action, int &Health[])
  {
    double price[];

    double highShort       = 0.00;
    double lowLong         = 0.00;
    
    int    ticket[];
    int    seek            = 0;
    int    health          = 0;
    
    string hcReport        = "";
    string hcHealth        = "";

    for (int ord=0; ord<OrdersTotal(); ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol() == Symbol())
        {
          ArrayResize(price,ArraySize(price)+1);
          price[ArraySize(price)-1] = OrderOpenPrice();

          if (OrderType() == OP_BUY)
            if (NormalizeDouble(lowLong,Digits)==0.00)
              lowLong      = OrderOpenPrice();
            else
              lowLong      = fmin(OrderOpenPrice(),lowLong);
              
          if (OrderType() == OP_SELL)
            highShort      = fmax(OrderOpenPrice(),highShort);
        }
    
    ArraySort(price,WHOLE_ARRAY,0,MODE_DESCEND);
    ArrayResize(ticket,ArraySize(price));

    for (int ord=0; ord<OrdersTotal(); ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol() == Symbol())
        {
          seek             = 0;

          while (NormalizeDouble(price[seek],Digits)!=NormalizeDouble(OrderOpenPrice(),Digits))
            seek++;

          ticket[seek]     = OrderTicket();
        }

    hcReport += "Long: "+DoubleToStr(lowLong,Digits)+"  Short: "+DoubleToStr(highShort,Digits)+"\n\n";

    for (int ord=0; ord<ArraySize(price); ord++)
      if (OrderSelect(ticket[ord],SELECT_BY_TICKET,MODE_HISTORY))
      {
        if (Action == OP_BUY)
        {
          if (OrderType() == OP_BUY)
            if (NormalizeDouble(OrderOpenPrice(),Digits)<NormalizeDouble(highShort,Digits))
              hcReport    += "Good Health    ";
            else
            {
              hcReport    += "Bad Health       ";
              ArrayResize(Health,health+1);
              Health[health++] = OrderTicket();
            }
          else
            hcReport      += "Not Evaluated  ";
        }

        if (Action == OP_SELL)
        {
          if (OrderType() == OP_SELL)
            if (NormalizeDouble(OrderOpenPrice(),Digits)>NormalizeDouble(lowLong,Digits))
              hcReport    += "Good Health    ";
            else
            {
              hcReport    += "Bad Health       ";
              ArrayResize(Health,health+1);
              Health[health++] = OrderTicket();
            }
          else
            hcReport      += "Not Evaluated  ";
        }
                    
        hcReport     += IntegerToString(OrderTicket())
                       +"  "+ActionText(OrderType())
                       +"  @"+DoubleToStr(OrderOpenPrice(),Digits)
                       +"  P/L: "+NegLPad(OrderProfit(),2);
                       
        if (rmSuspects.Found(ticket[ord]))
          hcReport   += "  *** Suspect ***";
          
        hcReport     += "\n";
      }

    Pause (hcReport,"Health Check Report");
  }

//+------------------------------------------------------------------+
//| ManageProfit - analyzes open trades and refines targets          |
//+------------------------------------------------------------------+
void ManageProfit(void)
  {
    static bool tpComplete  = false;

    static int  tpSuspect   = NoValue;
    static int  tpLevel     = NoValue;
    static int  tpAction    = NoValue;
    static int  mbCancel    = NoValue;
    
    int         health[];
    
    //--- Max profit during excessive market volatility
    if (NormalizeDouble(jrData[Active],3)>NormalizeDouble(FiboLevels[Fibo261],3))
    {
      SetEquityHold(DirAction(jrDirection));
      SetActionHold(DirAction(jrDirection,InContrarian));
    }

    //--- Identify suspects
    if (tpAction != rmAction || tpSuspect == NoValue)
      for (int suspect=0; suspect<rmSuspects.Count; suspect++)
      {
        if (OrderSelect(rmSuspects[suspect],SELECT_BY_TICKET))
          if (OrderType() == DirAction(jrDirection))
            if (IsChanged(tpSuspect,rmSuspects[suspect]))
            {
              if (tpAction != rmAction)
              {
                tpAction    = OrderType();
                tpLevel     = NoValue;
              }
              
              if (jrDirection*DirectionInverse == ltDirection)
                SetEquityHold(DirAction(jrDirection,InContrarian));

              mbCancel        = Pause("Changing the suspect: "+IntegerToString(rmSuspects[suspect])+" Level: "+IntegerToString(tpLevel),"Suspect Change",MB_ICONEXCLAMATION|MB_OK);
            }
            
        if (tpSuspect != NoValue)
          break;
      }
      
    //--- Target suspects for early closure
    if (tpSuspect>NoValue)
    {
      if (NormalizeDouble(jrData[Active],3) >= NormalizeDouble(FiboLevels[Fibo161+fmin(tpLevel,2)],3))
      {
        if (OrderFulfilled(DirAction(jrDirection,InContrarian)))
//        {}
//        else
//        if (pregr.TickDirection!=jrDirection )
        {
          for (int suspect=0; suspect<rmSuspects.Count; suspect++)
            if (NormalizeDouble(jrData[Active],3) >= NormalizeDouble(FiboLevels[Fibo261],3))
              CloseOrder(rmSuspects[suspect],false);   //--- takes profit when profitable on a neg-tick
            else
              CloseOrder(rmSuspects[suspect],true);    //--- kill on a neg-tick
            
          if (OrderSelect(tpSuspect,SELECT_BY_TICKET,MODE_HISTORY))
            if (OrderCloseTime()>0)
            {
              tpLevel++;
              tpSuspect         = NoValue;

              ExecuteHealthCheck(OrderType(),health);

              for (int ord=0; ord<ArraySize(health); ord++)
                CloseOrder(tpSuspect,true);    //--- kill on a neg-tick
            }
        }
      }
    }
    else
    
    //--- Execute healthy take profit protocol    
    if (NormalizeDouble(jrData[Active],3) < NormalizeDouble(FiboLevels[Fibo100],3))
    {
      tpComplete            = false;
      tpLevel               = NoValue;
    }
    else
    if (!tpComplete)
    {
      if (NormalizeDouble(jrData[Active],3) >= NormalizeDouble(FiboLevels[Fibo161],3))
        if (NormalizeDouble(pregr.FOCDev,1) > 0.00)
        {
          CloseOrders(CLOSE_CONDITIONAL,DirAction(jrDirection));
          tpComplete        = true;
        }
    }

    string mpReport = "";
    
    if (OrderSelect(tpSuspect,SELECT_BY_TICKET,MODE_TRADES))
      mpReport  += "Current Suspect: "+ActionText(OrderType())
                  +" Ticket: "+IntegerToString(tpSuspect)
                  +" @"+DoubleToStr(FiboLevels[Fibo161+tpLevel]*100,1)+"%";
                                       
    if (eqholdaction != OP_NO_ACTION)
      Append(mpReport,proper(ActionText(eqholdaction))+" Suspended"," ");
      
    if (tpComplete)
      UpdateLabel("tpComplete","$"+ActionText(DirAction(jrDirection))+" "+mpReport,clrYellow,10);
    else
    if (tpSuspect>NoValue)
      UpdateLabel("tpComplete",mpReport,clrRed,10);
    else
      UpdateLabel("tpComplete","$"+ActionText(DirAction(jrDirection)),clrGray,10);
  }

//+------------------------------------------------------------------+
//| ManageRisk - analyzes open trade and refines stop loss levels    |
//+------------------------------------------------------------------+
void ManageRisk(void)
  {
    static const bool Unique = true;
    
    //--- Margin verification
//    if (NormalizeDouble((AccountMargin()/(AccountEquity()))*100,1)>20)
//      Pause ("Margin at maximum","Margin Warning");

    //--- Health check
    for (int suspect=0; suspect<rmSuspects.Count; suspect++)
      if (OrderSelect(rmSuspects[suspect],SELECT_BY_TICKET,MODE_HISTORY))
        if (OrderCloseTime()>0 || IsBetween(OrderOpenPrice(),jrData[Root],jrData[Base],Digits))
          rmSuspects.Delete(suspect);

    int oldCount  = rmSuspects.Count;
    for (int ord=0; ord<OrdersTotal(); ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (Symbol() == OrderSymbol())
        {
          if (OrderType()==OP_BUY && NormalizeDouble(OrderOpenPrice(),Digits)>NormalizeDouble(fmax(jrData[Base],jrData[Root]),Digits))
            rmSuspects.Add(OrderTicket(),Unique);
      
          if (OrderType()==OP_SELL && NormalizeDouble(OrderOpenPrice(),Digits)<NormalizeDouble(fmin(jrData[Base],jrData[Root]),Digits))
            rmSuspects.Add(OrderTicket(),Unique);
        }

    string suspectList = "*** Suspects ("+IntegerToString(rmSuspects.Count)+")\n";
    if (oldCount!=rmSuspects.Count && rmSuspects.Count>0)
    {
      rmAction         = OP_NO_ACTION;
      
      for (int suspect=0; suspect<rmSuspects.Count; suspect++)
        if (OrderSelect(rmSuspects[suspect],SELECT_BY_TICKET,MODE_TRADES))
        {
          suspectList += IntegerToString(rmSuspects[suspect])+" "+ActionText(OrderType())+DoubleToStr(OrderProfit(),2)+"\n";
          rmAction     = OrderType();
        }

      Pause (suspectList,"Suspect Line-Up");
    }

/*    
    //--- Execute safety measures
    if (NormalizeDouble(jrData[Active],3) >= NormalizeDouble(FiboLevels[Fibo100],3))
    {
      if (jrDirection == DirectionUp && LotValue(LOT_LONG_LOSS)<0.00)
        if (NormalizeDouble(jrData[Active],3) >= NormalizeDouble(FiboLevels[Fibo161],3))
            CloseOrders(CLOSE_MIN,OP_BUY);

      if (jrDirection == DirectionDown && LotValue(LOT_SHORT_LOSS)<0.00)
        if (NormalizeDouble(jrData[Active],3) >= NormalizeDouble(FiboLevels[Fibo161],3))
        {
          Pause("Managing short risk","Risk Manager");
          CloseOrders(CLOSE_MIN,OP_SELL);
        }
    }            
*/
  }

//+------------------------------------------------------------------+
//| Authorized - returns true if trade meets analyst requirements    |
//+------------------------------------------------------------------+
bool Authorized(int Action)
  {   
    //--- test holds and clear if safe
    if (DirAction(stDirection) == eqholdaction)
      SetActionHold();
      
    if (eqholdaction == Action)
      return (false);
      
    if (NormalizeDouble(jrData[Active],3)<NormalizeDouble(FiboLevels[Fibo100+sQuota],3))
      return (false);
      
    if (jrDirection == DirectionUp)
      if (Action == OP_BUY)
        return (false);
    
    if (jrDirection == DirectionDown)
      if (Action == OP_SELL)
        return (false);

    return (true);
  }
  
//+------------------------------------------------------------------+
//| ManageOrders - analyzes account manager orders and refines       |
//+------------------------------------------------------------------+
void ManageOrders(void)
  {
    VerifyFulfillment();

    //--- test hold conditions    
    if (eqholdaction != OP_NO_ACTION)
      if (eqholdaction == ordLimitAction)
        CloseLimitOrder();
      
    if (DirAction(jrDirection) == eqholdaction)
      if (NormalizeDouble(jrData[Active],3)>FiboLevels[Fibo161])
        eqholdaction  = OP_NO_ACTION;
    
    if (OrderPending())
    {
      if (NormalizeDouble(pregr.FOCDev,1) == 0.00)
      {
        if (ordLimitAction == OP_SELL)
          OpenLimitOrder(OP_SELL,fmax(Bid+Pip(2,InPoints),pregr.RangeHigh),pregr.RangeLow,0.00,"Mod");

        if (ordLimitAction == OP_BUY)
          OpenLimitOrder(OP_BUY,fmin(Ask-Pip(2,InPoints),pregr.RangeLow),pregr.RangeHigh,0.00,"Mod");
      }
    }
    else
    {
      if (Authorized(OP_SELL))
        OpenLimitOrder(OP_SELL,Bid+Pip(2,InPoints),pregr.RangeLow,0.00,"Orig");

      if (Authorized(OP_BUY))
        OpenLimitOrder(OP_BUY,Ask-Pip(2,InPoints),pregr.RangeHigh,0.00,"Orig");
    }
  }
  
//+------------------------------------------------------------------+
//| Execute - executes orders, risk, profit management               |
//+------------------------------------------------------------------+
void Execute(void)
  { 
    ManageOrders();
    ManageProfit(); 
    ManageRisk();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    ManageAnalysis();
    
    UpdateLine("pBase",jrData[Base],STYLE_SOLID,DirColor(jrDirection));
    UpdateLine("pRoot",jrData[Root],STYLE_SOLID,DirColor(jrDirection));
    UpdateLine("pExpansion",jrData[Expansion],STYLE_DOT,DirColor(stDirection));

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
    
    SetEquityTarget(150,0.1);
    SetRisk(80,5);     

    ArrayInitialize(jrData,Close[0]);
    
    jrData[Active]  = 0.00;
    rmSuspects.AutoExpand  = true;

    NewLine("pBase");
    NewLine("pRoot");
    NewLine("pExpansion");

    NewPriceLabel("ltPivot");
    NewLabel("jrActive","",5,16,clrLawnGreen,SCREEN_LL,0);
    NewLabel("tpComplete","",5,5,clrLawnGreen,SCREEN_LL,0);
            
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
    delete rmSuspects;
  }
