//+------------------------------------------------------------------+
//|                                                    break6-v1.mq4 |
//|                                                 Dennis Jorgenson |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\PipFractal.mqh>

//--- Application Inputs
input string    RegressionHeader        = "";    //+------ Regression Options ------+
input int       inpDegree               = 6;     // Degree of poly regression
input int       inpSmoothFactor         = 3;     // MA Smoothing factor
input double    inpTolerance            = 0.5;   // Directional sensitivity
input int       inpPipPeriods           = 200;   // Trade analysis periods (PipMA)
input int       inpRegrPeriods          = 24;    // Trend analysis periods (RegrMA)

//--- Order constants
#define OP_NO_ACTION            -1

input double inpLotFactor     = 6.4;
input int    inpSlipFactor    = 3;
input int    inpMagic         = 0;

//--- Order parameters
int    ordLotPrecision        = 0;
double ordAcctLotSize         = (int)MarketInfo(Symbol(), MODE_LOTSIZE);
double ordAcctMinLot          = MarketInfo(Symbol(), MODE_MINLOT);
double ordAcctMaxLot          = MarketInfo(Symbol(), MODE_MAXLOT);


enum Direction {
                 Idle  = 0,
                 Up    = 1,
                 Down  = -1
               };

//--- Operational variables
double       b6_High              = 0.00;
double       b6_Low               = 0.00;
double       b6_Top               = 0.00;
double       b6_Bottom            = 0.00;

Direction    b6_Trend             = Idle;

//+------------------------------------------------------------------+
//| ActionText - returns the text of an ActionCode                   |
//+------------------------------------------------------------------+
string ActionText(int Action)
  {
    switch (Action)
    {
      case OP_BUY:       return("BUY");
      case OP_BUYLIMIT:  return("BUY LIMIT");
      case OP_BUYSTOP:   return("BUY STOP");
      case OP_SELL:      return("SELL");
      case OP_SELLLIMIT: return("SELL LIMIT");
      case OP_SELLSTOP:  return("SELL STOP");
      case OP_NO_ACTION: return("NO ACTION");
    }
        
    return("BAD ACTION CODE");
  }

//+------------------------------------------------------------------+
//| IsLower - returns true if compare value lower than check         |
//+------------------------------------------------------------------+
bool IsLower(double Compare, double &Check, bool Update=true, int Precision=0)
  {
    if (Precision == 0)
      Precision  = Digits;
      
    if (NormalizeDouble(Compare,Precision) < NormalizeDouble(Check,Precision))
    {
      if (Update)
        Check    = NormalizeDouble(Compare,Precision);

      return (true);
    }
    
    return (false);
  }

//+------------------------------------------------------------------+
//| IsHigher - returns true if compare value higher than check       |
//+------------------------------------------------------------------+
bool IsHigher(double Compare, double &Check, bool Update=true, int Precision=0)
  {
    if (Precision == 0)
      Precision  = Digits;
      
    if (NormalizeDouble(Compare,Precision) > NormalizeDouble(Check,Precision))
    {    
      if (Update)
        Check    = NormalizeDouble(Compare,Precision);
        
      return (true);
    }
    return (false);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(datetime &Check, datetime Compare, bool Update=true)
  {
    if (Check == Compare)
      return (false);
  
    if (Update)
      Check   = Compare;
  
    return (true);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(string &Check, string Compare, bool Update=true)
  {
    if (Check == Compare)
      return (false);
  
    if (Update) 
      Check   = Compare;
  
    return (true);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(double &Check, double Compare, bool Update=true, int Precision=0)
  {
    if (Precision == 0)
      Precision  = Digits;

    if (NormalizeDouble(Check,Precision) == NormalizeDouble(Compare,Precision))
      return (false);
  
    if (Update) 
      Check   = NormalizeDouble(Compare,Precision);
  
    return (true);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(int &Check, int Compare, bool Update=true)
  {
    if (Check == Compare)
      return (false);
   
    if (Update) 
      Check   = Compare;
  
    return (true);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(bool &Check, bool Compare, bool Update=true)
  {
    if (Check == Compare)
      return (false);
   
    if (Update) 
      Check   = Compare;
  
    return (true);
  }

//+------------------------------------------------------------------+
//| IsChanged - returns true if the updated value has changed        |
//+------------------------------------------------------------------+
bool IsChanged(uchar &Check, uchar Compare, bool Update=true)
  {
    if (Check == Compare)
      return (false);
   
    if (Update) 
      Check   = Compare;
  
    return (true);
  }

//+------------------------------------------------------------------+
//| NewArrow - Paints a directional arrow                            |
//+------------------------------------------------------------------+
void NewArrow(Direction Arrow)
  {
    static int naIdx           = 0;
    int        naArrowCode     = SYMBOL_ARROWUP;
    int        naArrowColor    = clrYellow;

    naIdx++;
    
    if (Arrow==Down)
    {
      naArrowCode              = SYMBOL_ARROWDOWN;
      naArrowColor             = clrRed;
    }
      
    ObjectCreate ("ar"+IntegerToString(naIdx), OBJ_ARROW, 0, Time[0], Close[0]);
    ObjectSet    ("ar"+IntegerToString(naIdx), OBJPROP_ARROWCODE, naArrowCode);
    ObjectSet    ("ar"+IntegerToString(naIdx), OBJPROP_COLOR,naArrowColor);
  }

//+------------------------------------------------------------------+
//| RefreshScreen - Updates screen metrics                           |
//+------------------------------------------------------------------+
void RefreshScreen()
  {
    ObjectSet("lnHigh",OBJPROP_PRICE1,b6_High);
    ObjectSet("lnLow",OBJPROP_PRICE1,b6_Low);
    ObjectSet("lnTop",OBJPROP_PRICE1,b6_Top);
    ObjectSet("lnBottom",OBJPROP_PRICE1,b6_Bottom);
    
    Comment(EnumToString(b6_Trend));
  }
  
//+------------------------------------------------------------------+
//| NewDirection - Identifies changes in direction                   |
//+------------------------------------------------------------------+
bool NewDirection(Direction &Now, Direction Change)
  {
    if (Now==Change)
      return (false);
      
    if (Change==Idle)
      return (false);
      
    if (Now==Idle)
    {
      Now                  = Change;
      return (false);
    }
    
    Now                    = Change;
    return(true);
  }


//+------------------------------------------------------------------+
//| LotSize - returns optimal lot size                               |
//+------------------------------------------------------------------+
double LotSize(double Lots=0.00)
  {
    if(NormalizeDouble(Lots,ordLotPrecision)>0.00)
      if(Lots<ordAcctMinLot)
        return (ordAcctMinLot);
      else
      if(Lots>ordAcctMaxLot)
        return (ordAcctMaxLot);
      else
        return(NormalizeDouble(Lots,ordLotPrecision));

    Lots = fmin((AccountBalance()*(inpLotFactor/100))/MarketInfo(Symbol(),MODE_MARGINREQUIRED),ordAcctMaxLot);
    
    return(fmax(NormalizeDouble(Lots,ordLotPrecision),ordAcctMinLot));
  }

//+------------------------------------------------------------------+
//| OpenOrder - Places new orders on market                          |
//+------------------------------------------------------------------+
bool OpenOrder(int Action, string Reason, double Lots=0.00)
  {
    int    ooTicket     = 0;
    double ooPrice      = 0.00;

//    if (eqhaltaction == Action)
//      return (false);
      
    Lots=LotSize(Lots);
             
    //--- set stops/targets
    if (Action==OP_BUY) 
      ooPrice      = Ask;
    
    if (Action==OP_SELL)
      ooPrice      = Bid;

//    if (!eqhalt)
      ooTicket=OrderSend(Symbol(),
              Action,
              Lots,
              NormalizeDouble(ooPrice,Digits),
              inpSlipFactor*10,
              0.00,
              0.00,
              Reason,
              inpMagic,
              0,0);

    if (ooTicket>0)
       return (true);

    Print(ActionText(Action)+" failure @"+DoubleToStr(ooPrice,Digits)+"; error ("+DoubleToStr(GetLastError(),0)+"): "+DoubleToStr(Lots,2));

    return (false);
  }

//+------------------------------------------------------------------+
//| CloseOrders - Closes orders on the market                        |
//+------------------------------------------------------------------+
bool CloseOrders(void)
  {
    double coPrice      = 0.00;

    for (int ord=0;ord<OrdersTotal();ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol()==Symbol())
        {
          if (OrderType()==OP_BUY)
            coPrice       = Bid;
          else
            coPrice       = Ask;     

          if (OrderClose(OrderTicket(),OrderLots(),coPrice,inpSlipFactor*10,clrRed))
            ord--;
          else
          {
            Print("Close "+ActionText(OrderType())+" failure @"+DoubleToStr(coPrice,Digits)+
                     "; error ("+DoubleToStr(GetLastError(),0)+"): "+DoubleToStr(OrderLots(),2));
            return (false);
          }
        }

    return (true);
  }

//+------------------------------------------------------------------+
//| MonitorRisk - Monitor trade risk at trend changes                |
//+------------------------------------------------------------------+
void MonitorRisk()
  {
    int mrRisk     = OP_SELL;
    
    if (b6_Trend==Up)
      mrRisk       = OP_BUY;
      
    NewArrow(b6_Trend);
    CloseOrders();
    OpenOrder(mrRisk,"Risk Manager");
  }

//+------------------------------------------------------------------+
//| Execute - main execution loop                                    |
//+------------------------------------------------------------------+
void Execute()
  {
    static int eTimeHour   = 0;
    
    if (IsChanged(eTimeHour,TimeHour(Time[0])))
    {
      if (eTimeHour==0)
      {
        b6_High            = Open[0];
        b6_Low             = Open[0];
      }
    
      b6_Top               = High[iHighest(Symbol(),PERIOD_H1,MODE_HIGH,6)];
      b6_Bottom            = Low[iLowest(Symbol(),PERIOD_H1,MODE_LOW,6)];
    }
    
    if (IsHigher(Close[0],b6_High))
      if (eTimeHour>5)
        if (NewDirection(b6_Trend,Up))
          MonitorRisk();
    
    if (IsLower(Close[0],b6_Low))
      if (eTimeHour>5)
        if (NewDirection(b6_Trend,Down))
          MonitorRisk();
  }
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    Execute();
    RefreshScreen();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    ObjectCreate("lnHigh",OBJ_HLINE,0,Time[0],0.00);
    ObjectCreate("lnLow",OBJ_HLINE,0,Time[0],0.00);
    ObjectCreate("lnTop",OBJ_HLINE,0,Time[0],0.00);
    ObjectCreate("lnBottom",OBJ_HLINE,0,Time[0],0.00);

    ObjectSet("lnHigh",OBJPROP_STYLE,STYLE_DOT);
    ObjectSet("lnLow",OBJPROP_STYLE,STYLE_DOT);
    ObjectSet("lnTop",OBJPROP_STYLE,STYLE_SOLID);
    ObjectSet("lnBottom",OBJPROP_STYLE,STYLE_SOLID);

    ObjectSet("lnHigh",OBJPROP_COLOR,clrForestGreen);
    ObjectSet("lnLow",OBJPROP_COLOR,clrFireBrick);
    ObjectSet("lnTop",OBJPROP_COLOR,clrForestGreen);
    ObjectSet("lnBottom",OBJPROP_COLOR,clrFireBrick);
    
    ordAcctLotSize  = (int)MarketInfo(Symbol(), MODE_LOTSIZE);
    ordAcctMinLot   = MarketInfo(Symbol(), MODE_MINLOT);
    ordAcctMaxLot   = MarketInfo(Symbol(), MODE_MAXLOT);
    
    if (ordAcctMinLot==0.01) ordLotPrecision=2;
    if (ordAcctMinLot==0.1)  ordLotPrecision=1;    

    Print("Pair: "+Symbol()+
            " Account Balance: "+DoubleToStr(AccountBalance()+AccountCredit(),2)+
            " Lot Size: "+DoubleToString(ordAcctLotSize,2)+
            " Min Lot: "+DoubleToString(ordAcctMinLot,2)+
            " Max Lot: "+DoubleToStr(ordAcctMaxLot,2)+
            " Leverage: "+DoubleToStr(AccountLeverage(),0));

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
