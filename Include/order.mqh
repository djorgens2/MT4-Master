//+------------------------------------------------------------------+
//|                                                        order.mqh |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property strict

#include <stdutil.mqh>

//--- Profit Plan
#define PP_TARGET               0
#define PP_STOP                 1
#define PP_STEP                 2

  //---- Trade Modes
  enum TradeMode
       {
         Manual,
         Legacy,
         Shutdown,
         Auto
       };

   //---- Close Options
   enum CloseOptions 
        {
          CloseNone,
          CloseAll,
          CloseMin,
          CloseMax,
          CloseHalf,
          CloseProfit,
          CloseLoss,
          CloseConditional,
          CloseFIFO,
          NoCloseOption = -1
        };

   //---- Extern Variables
   input string        ordHeader           = "";       // +----- Order Options -----+
   input double        inpMinTarget        = 5.0;      // Equity% Target
   input double        inpMinProfit        = 0.8;      // Minimum take profit%
   input double        inpMaxRisk          = 50.0;     // Maximum Risk%
   input double        inpMaxMargin        = 60.0;     // Maximum Open Margin
   input double        inpLotFactor        = 2.00;     // Scaling Lotsize Balance Risk%
   input double        inpLotSize          = 0.00;     // Lotsize Override
   input double        inpOrderSpacing     = 2.5;      // Order Spacing (pips)
   input int           inpDefaultStop      = 50;       // Default Stop Loss (pips)
   input int           inpDefaultTarget    = 50;       // Default Take Profit (pips)
   input int           inpSlipFactor       = 3;        // Slip Factor (pips)
   input bool          inpEQHalf           = false;    // Split Lots on Profit
   input bool          inpEQProfit         = false;    // Close on Profit Only
   input bool          inpEQRetain         = false;    // Retain orders<1/2; Explicit Close Required!
   input CloseOptions  inpRiskCloseOption  = CloseAll; // Close at risk option
   input int           inpMagic            = 8;        // Magic Number

string whereClose             = "";

//---- Account details
int    ordLotPrecision        = 0;
int    ordAcctLotSize         = 0;
double ordAcctMinLot          = 0.00;
double ordAcctMaxLot          = 0.00;

//---- Standard order Target/Risk operationals
double ordEQMinTarget         = 0.00;
double ordEQMinProfit         = 0.00;
double ordEQMaxRisk           = 0.00;
double ordEQLotFactor         = 0.00;
double ordEQHalfLot           = 0.00;
double ordEQNormalSpread      = 0.00;

//---- Order flags
bool   eqhalf                 = false;
bool   eqprofit               = false;
bool   eqhalt                 = false;
bool   eqretain               = false;

int    eqhold                 = NoAction;  //--- hold profit closes until cleared;
int    eqhaltaction           = NoAction;  //--- halt new orders for this action

struct OrderRec {
                  int         Action;
                  int         Ticket;
                  double      Price;
                  double      Lots;
                  string      Reason;
                };

struct QueueRec {
                  int         Type;
                  double      Price;
                  double      Lots;
                  double      Step;
                  double      Stop;
                };

//---- Successful order details, if placed, cleared at end of tick
OrderRec ordOpened               = {NoAction,0,0.00};   //-- Last order opened
OrderRec ordClosed[];                                   //-- Orders closed
QueueRec ordQueue[2];                                   //-- Order Queue by action
OrderRec ordOpen[2];                                    //-- Current Orders Open

double ordEQBase               = AccountBalance()+AccountCredit();
double ordPipsOpen             = 0.00;
double ordPipsClosed           = 0.00;

//---- Limit order details
int    ordLimitAction         = NoAction;
double ordLimitPrice          = 0.00;
double ordLimitCancel         = 0.00;
double ordLimitLots           = 0.00;
double ordLimitTrail          = 0.00;
string ordLimitComment        = "";
bool   ordLimitTrigger        = false;

//---- Market-if-touched order details
int    ordMITAction           = NoAction;
double ordMITPrice            = 0.00;
double ordMITCancel           = 0.00;
double ordMITLots             = 0.00;
double ordMITTrail            = 0.00;
string ordMITComment          = "";
bool   ordMITTrigger          = false;

//---- Stop loss details
bool   ordStopLong            = false;
bool   ordStopShort           = false;
double ordStopLongPrice       = 0.00;
double ordStopShortPrice      = 0.00;

//---- Take profit details
bool   ordTargetLong          = false;
bool   ordTargetShort         = false;
double ordTargetLongPrice     = 0.00;
double ordTargetShortPrice    = 0.00;

//---- Take Profit strategy details
bool   ordHideStop[2]         = {false,false};
bool   ordHideTarget[2]       = {false,false};
double ordProfitPlan[2][3];

//---- Equity Hold details
double ordHoldPips            = 0.00;
double ordHoldBase            = 0.00;
bool   ordHoldTrail           = false;

//---- Dollar cost average action
int    ordDCAAction           = NoAction;
int    ordDCACloseOption      = CloseAll;
double ordDCAMinEQ            = 0.00;
double ordDCACloseMinEQ       = 0.00;
bool   ordDCAKeep             = false;

//--- Equity data
double EQMin                  = 0.00;
double EQMax                  = 0.00;

//--- Last price data
double ordLastAsk             = 0.00;
double ordLastBid             = 0.00;


//+------------------------------------------------------------------+
//| CloseOption - returns the code of the text Close Option          |
//+------------------------------------------------------------------+
CloseOptions CloseOption(string Option)
  {
    if (Option == "NONE")         return (CloseNone);
    if (Option == "ALL")          return (CloseAll);
    if (Option == "MIN")          return (CloseMin);
    if (Option == "MAX")          return (CloseMax);
    if (Option == "HALF")         return (CloseHalf);
    if (Option == "PROFIT")       return (CloseProfit);
    if (Option == "LOSS")         return (CloseLoss);
    if (Option == "CONDITIONAL")  return (CloseConditional);
  
    return(NoCloseOption);
  }

//+------------------------------------------------------------------+
//| EquityPercent                                                    |
//+------------------------------------------------------------------+
double EquityPercent(MeasureType Measure=Now)
  {
    double eqPercent  = 0.00;
    double eqZero     = 0.00;
    double acctBal    = AccountBalance()+AccountCredit();

    if (acctBal==0.00)
      return (0.00);
          
    eqPercent = NormalizeDouble(((AccountEquity()-acctBal)/acctBal)*100,1);
    
    if (OrdersTotal()>0)
    {
      if (IsLower(eqPercent,EQMin))
        if (IsLower(EQMin,eqZero,NoUpdate))
          EQMax  = EQMin;
          
      if (IsHigher(eqPercent,EQMax))
        if (IsHigher(EQMax,eqZero,NoUpdate))
          EQMin  = EQMax;
    }
    else
    {
      EQMin = 0.00;
      EQMax = 0.00;
    }

    switch (Measure)
    {
      case Now:   return(eqPercent);
      case Max:   return(EQMax);
      case Min:   return(EQMin);
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| SetEquityTarget - Sets the profit percent driver                 |
//+------------------------------------------------------------------+
void SetEquityTarget(double MinTarget=0.00, double MinProfit=0.00)
  {
    ordEQMinTarget    = MinTarget;
    ordEQMinProfit    = MinProfit;  

    if (inpMinTarget!=ordEQMinTarget)
      UpdateLabel("ordTargetMax",DoubleToStr(ordEQMinTarget,1)+"%",clrYellow);
    else
      UpdateLabel("ordTargetMax",DoubleToStr(inpMinTarget,1)+"%",clrDarkGray);

    if (inpMinProfit!=ordEQMinProfit)
      UpdateLabel("ordTargetMin",DoubleToStr(ordEQMinProfit,1)+"%",clrYellow);
    else
      UpdateLabel("ordTargetMin",DoubleToStr(inpMinProfit,1)+"%",clrDarkGray);
  }

//+------------------------------------------------------------------+
//| SetEquityHold - Keeps trades open for the supplied Action        |
//+------------------------------------------------------------------+
void SetEquityHold(int Action=NoAction, double Pips=0.00, bool Trail=false)
  {
    if (eqhalt)
    {
      eqhold               = NoAction;
      return;
    }

    if (Action == OP_BUY || Action == OP_SELL)
    {
      ordHoldPips          = Pips;
      ordHoldTrail         = Trail;

      eqhold               = Action;
      
      if (NormalizeDouble(Pips,1) == 0.00)
        ordHoldBase        = 0.00;
      else
      if (Action == OP_BUY)
        ordHoldBase        = Bid-point(Pips);
      else
      if (Action == OP_SELL)
        ordHoldBase        = Ask+point(Pips);

      SetTargetPrice(Action);        
    }
    else
    {
      ordHoldBase          = 0.00;
      ordHoldPips          = 0.00;
      ordHoldTrail         = false;
      
      eqhold               = NoAction;
    }
  }

//+------------------------------------------------------------------+
//| SetTradeResume - If not halted, allows trading to resume         |
//+------------------------------------------------------------------+
void SetTradeResume(int Action=NoAction)
  {
    if (eqhalt)
    {
      if (Action==OP_BUY)
        SetActionHold(OP_SELL);

      if (Action==OP_SELL)
        SetActionHold(OP_BUY);
    }
    else      
      if (Action==eqhaltaction)
        SetActionHold(NoAction);

    eqhalt                 = false;
  }

//+------------------------------------------------------------------+
//| SetActionHold - Disallows trading in a specified direction       |
//+------------------------------------------------------------------+
void SetActionHold(int Action=NoAction)
  {
    eqhaltaction = Action;
  }

//+------------------------------------------------------------------+
//| ActionHold - Disallows trading in a specified direction          |
//+------------------------------------------------------------------+
bool ActionHold(int Action=NoAction)
  {
    return (eqhaltaction==Action);
  }

//+------------------------------------------------------------------+
//| SetProfitPolicy - Sets policies close half, profit, and halt     |
//+------------------------------------------------------------------+
void SetProfitPolicy(bool &Policy)
  {
    if (eqhalt)
      return;
      
    if (Policy)
      Policy=false;
    else Policy=true;
  }

//+------------------------------------------------------------------+
//| SetDefaults - restores order parameters to defaults              |
//+------------------------------------------------------------------+
void SetDefaults(void)
  {
    SetRisk(inpMaxRisk, inpLotFactor);
    SetEquityTarget(inpMinTarget, inpMinProfit);

    eqhalf                = inpEQHalf;
    eqprofit              = inpEQProfit;
    eqretain              = inpEQRetain;
  }

//+------------------------------------------------------------------+
//| DCAPlanPending - returns true if action is in a DCA plan         |
//+------------------------------------------------------------------+
bool DCAPlanPending(int Action=NoAction)
  {
    if (Action==OP_BUY || Action == NoAction)
      if (ordDCAAction == OP_BUY)
        return (true);

    if (Action==OP_SELL || Action == NoAction)
      if (ordDCAAction == OP_SELL)
        return (true);

    return (false);
  }

//+------------------------------------------------------------------+
//| CloseDCAPlan - Closes the DCA Plan for the specified action      |
//+------------------------------------------------------------------+
void CloseDCAPlan(int Action, bool Keep=false)
  {
    if (LotCount(Action)==0.00)
      ordDCAKeep           = false;

    if (Keep)
      return;

    if (ordDCAAction == Action)
    {
      ordDCAAction         = NoAction;
      ordDCAMinEQ          = 0.00;
      ordDCACloseOption    = CloseNone;
      ordDCAKeep           = false;
      ordDCACloseMinEQ     = 0.00;
    }
  }

//+------------------------------------------------------------------+
//| OpenDCAPlan - Sets the DCA action                                |
//+------------------------------------------------------------------+
void OpenDCAPlan(int Action, double DCAMinEQ=0.00, CloseOptions Option=CloseAll, bool Keep=false, double CloseMinEQ=0.00)
  {
    if (Action == OP_BUY || Action == OP_SELL)
    {
      ordDCAAction         = Action;
      ordDCAMinEQ          = DCAMinEQ;
      ordDCACloseOption    = Option;
      ordDCAKeep           = Keep;
      ordDCACloseMinEQ     = CloseMinEQ;
    
      if (ProfitPlanPending(Action))
        CloseProfitPlan(Action);

      if (Action!=NoAction)
        SetTargetPrice(Action);
    }
  }

//+------------------------------------------------------------------+
//| UpdateTicket - Modifies ticket values; Currently Stop/TP prices  |
//+------------------------------------------------------------------+
bool UpdateTicket(int Ticket, double TakeProfit=0.00, double StopLoss=0.00)
  {
    if (OrderSelect(Ticket,SELECT_BY_TICKET,MODE_TRADES))
    {
      if (Symbol()!=OrderSymbol())
        return (false);
        
      //--- set stops
      if (ordHideStop[OrderType()])
        StopLoss        = 0.00;
      else
      if (NormalizeDouble(StopLoss,Digits) == 0.00)
      {
        if (inpDefaultStop>0)
        {
          if (OrderType() == OP_BUY)
            StopLoss    = Bid-point(inpDefaultStop);

          if (OrderType() == OP_SELL)
              StopLoss  = Ask+point(inpDefaultStop);
        }
        
        if (OrderType() == OP_SELL)
          if (ordStopShort)
            StopLoss      = ordStopShortPrice;

        if (OrderType() == OP_BUY)
          if (ordStopLong)
            StopLoss      = ordStopLongPrice;
      }
      
      //--- set targets
      if (ordHideTarget[OrderType()] || ProfitPlanPending(OrderType()))
        TakeProfit      = 0.00;
      else
      if (NormalizeDouble(TakeProfit,Digits) == 0.00)
      {
        if (inpDefaultTarget>0)
        {
          if (OrderType() == OP_BUY)
            if (eqhold != OP_BUY)
              TakeProfit  = Bid+point(inpDefaultTarget);

          if (OrderType() == OP_SELL)
            if (eqhold != OP_SELL)
              TakeProfit  = Ask-point(inpDefaultTarget);
        }

        if (OrderType() == OP_SELL)
          if (ordTargetShort)
            TakeProfit    = ordTargetShortPrice;

        if (OrderType() == OP_BUY)
          if (ordTargetLong)
            TakeProfit    = ordTargetLongPrice;
      }

      //--- validate for errors
      if (NormalizeDouble(TakeProfit,Digits)!=NormalizeDouble(OrderTakeProfit(),Digits) ||
          NormalizeDouble(StopLoss,Digits)!=NormalizeDouble(OrderStopLoss(),Digits))
      {
        if (OrderModify(Ticket,0.00,
            NormalizeDouble(StopLoss,Digits),
            NormalizeDouble(TakeProfit,Digits),0))
          return (true);

        else
          Pause("Invalid price for order modify\n"
               +"  Type: "+ActionText(OrderType())+" "+Symbol()+"\n"
               +"  Ticket: "+IntegerToString(Ticket)+"\n"
               +"  Take Profit: "+DoubleToString(TakeProfit,Digits)+"\n"
               +"  Stop Loss: "+DoubleToString(StopLoss,Digits)
               +"  Error: "+DoubleToStr(GetLastError(),0),
            "OrderModify() Error",MB_OK|MB_ICONEXCLAMATION);
      }
    }
    else
      Pause("Missing ticket for order modify\n"
           +"  Ticket: "+IntegerToString(Ticket)+"\n"
           +"  Take Profit: "+DoubleToString(TakeProfit,Digits)+"\n"
           +"  Stop Loss: "+DoubleToString(StopLoss,Digits),
        "OrderModify() Error",MB_OK|MB_ICONEXCLAMATION);

    return (false);
  }

//+------------------------------------------------------------------+
//| SetTargetPrice - Sets the profit target for the supplied action  |
//+------------------------------------------------------------------+
void SetTargetPrice(int Action, double Price=0.00, bool Hide=false)
  { 
    if (NormalizeDouble(Price,Digits)>0.00)
    {
      ordHideTarget[Action]   = Hide;
    
      if (Action==OP_BUY)
      {
        if (NormalizeDouble(Price,Digits)>NormalizeDouble(Ask+point(inpSlipFactor),Digits))
        {
          ordTargetLong       = true;
          ordTargetLongPrice  = Price;
        
          CloseProfitPlan(OP_BUY);
        }
        else return;
      }
      
      if (Action==OP_SELL)
      {
        if (NormalizeDouble(Price,Digits)<NormalizeDouble(Bid-point(inpSlipFactor),Digits))
        {
          ordTargetShort        = true;
          ordTargetShortPrice   = Price+(Ask-Bid);

          CloseProfitPlan(OP_SELL);
        }
        else return;
      }
    }
    else
    {
      ordHideTarget[Action]     = false;
    
      if (Action == OP_BUY)
      {
        ordTargetLong           = false;
        ordTargetLongPrice      = 0.00;
      }

      if (Action == OP_SELL)
      {
        ordTargetShort          = false;
        ordTargetShortPrice     = 0.00;
      }
    }
      
    for (int ord=0; ord<OrdersTotal(); ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderType() == Action)
          if (Hide)
          {
            if (NormalizeDouble(OrderTakeProfit(),Digits)>0.00)
              UpdateTicket(OrderTicket(),0.00,OrderStopLoss());
          }
          else
          if (NormalizeDouble(OrderTakeProfit(),Digits)!=NormalizeDouble(Price,Digits))
            UpdateTicket(OrderTicket(),Price,OrderStopLoss());
  }

//+------------------------------------------------------------------+
//| SetStopPrice - Sets the stop loss prices for the supplied action |
//+------------------------------------------------------------------+
void SetStopPrice(int Action, double Price=0.00, bool Hide=false)
  { 
    //--- bad price/early return
    if (NormalizeDouble(Price,Digits)<0.00)
      return;

    //--- test price for validity
    if (NormalizeDouble(Price,Digits)>0.00)
    {
      if (Action==OP_BUY||Action==OP_SELL)
        ordHideStop[Action]   = Hide;

      if (Action==OP_BUY)
      {
        if (NormalizeDouble(Price,Digits)<NormalizeDouble(Bid-point(inpSlipFactor),Digits))
        {
          ordStopLong         = true;
          ordStopLongPrice    = Price;
        }
        else return;
      }
      
      if (Action==OP_SELL)
      {
        if (NormalizeDouble(Price,Digits)>NormalizeDouble(Ask+point(inpSlipFactor),Digits))
        {
          ordStopShort        = true;
          ordStopShortPrice   = Price;
        }
        else return;
      }
    }
    else
    
    //--- Cancel stop
    if (NormalizeDouble(Price,Digits) == 0.00)
    {
      if (Action==OP_BUY||Action==OP_SELL)
        ordHideStop[Action]   = false;
    
      if (Action == OP_BUY)
      {
        ordStopLong           = false;
        ordStopLongPrice      = 0.00;
      }

      if (Action == OP_SELL)
      {
        ordStopShort          = false;
        ordStopShortPrice     = 0.00;
      }
    }
      
    for (int ord=0; ord<OrdersTotal(); ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderType() == Action)
          if (Hide)
          {
            if (NormalizeDouble(OrderStopLoss(),Digits)>0.00)        
              UpdateTicket(OrderTicket(),OrderTakeProfit(),0.00);
          }
          else
          if (NormalizeDouble(OrderStopLoss(),Digits)!=NormalizeDouble(Price,Digits))
            UpdateTicket(OrderTicket(),OrderTakeProfit(),Price);
  }

//+------------------------------------------------------------------+
//| SetRisk - Sets the maximum risk based on EQ% (override)          |
//+------------------------------------------------------------------+
void SetRisk(double MaxRisk, double LotFactor)
  {
    ordEQMaxRisk      = MaxRisk;
    ordEQLotFactor    = LotFactor;
    
    UpdateLabel("ordRisk","Risk ("+DoubleToStr(ordEQLotFactor,1)+")",clrWhite);

    if (inpMaxRisk!=ordEQMaxRisk)
      UpdateLabel("ordRiskMax",DoubleToStr(ordEQMaxRisk,1)+"%",clrYellow);
    else
      UpdateLabel("ordRiskMax",DoubleToStr(inpMaxRisk,1)+"%",clrDarkGray);
  }

//+------------------------------------------------------------------+
//| LotValue - returns the value of open lots conditionally          
//|   MeasureTypes:
//|     Net:      Aggregate net of all open trades by Action
//|     Profit:   Sum of all profitable trades by Action
//|     Loss:     Sum of all losing trades by Action
//|     Highest:  Highest value of all open trades by Action
//|     Lowest:   Lowest value of all open trades by Action
//|     Smallest: Least |absolute| value of all open trades by Action
//|     Largest:  Greatest |absolute| value of all open trades by Action 
//+------------------------------------------------------------------+
double LotValue(int Action=NoAction, int Measure=Net, int Format=InDollar, bool Contrarian=false)
  {
    static const int netaction   = 2;
    
    double    lvOrderNetProfit   = 0.00;
    bool      lvMinMaxInit[2]    = {false,false};

    double value[3][SummaryTypes];
    
    if (Contrarian)
    {
      if (Action==OP_BUY)
        Action = OP_SELL;

      if (Action==OP_SELL)
        Action = OP_BUY;
    }
    
    ArrayInitialize(value,0.00);
    
    for (int ord=0; ord<OrdersTotal(); ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol()==Symbol())
          if (OrderType()==OP_BUY || OrderType()==OP_SELL)
          {
            lvOrderNetProfit  = OrderProfit()+OrderCommission()+OrderSwap();

            //--- Calculate if initialized
            if (lvMinMaxInit[OrderType()])
              switch (Measure)
              {
                case Net:         value[OrderType()][Net]        += lvOrderNetProfit;
                                  break;
                case Profit:      if (OrderProfit()>0.00)
                                    value[OrderType()][Profit]   += lvOrderNetProfit;
                                  break;
                case Loss:        if (OrderProfit()<0.00)
                                    value[OrderType()][Loss]     += lvOrderNetProfit;
                                  break;
                case Highest:     if (Action==OrderType())
                                    value[OrderType()][Highest]   = fmax(lvOrderNetProfit,value[OrderType()][Highest]);
                                  break;
                case Lowest:     if (Action==OrderType())
                                    value[OrderType()][Lowest]    = fmin(lvOrderNetProfit,value[OrderType()][Lowest]);
                                  break;
              }
            else

            //--- Initialize first pass
            {
              value[OrderType()][Measure]  = lvOrderNetProfit;
              lvMinMaxInit[OrderType()]    = true;
            }
          }
    
    if (Action == NoAction)
    {
      Action   = netaction;
      
      switch (Measure)
      {
        case Net:               value[Action][Net]       = value[OP_BUY][Net]    + value[OP_SELL][Net];
                                break;
        case Profit:            value[Action][Profit]    = value[OP_BUY][Profit] + value[OP_SELL][Profit];
                                break;
        case Loss:              value[Action][Loss]      = value[OP_BUY][Loss]   + value[OP_SELL][Loss];
                                break;
        case Highest:           value[Action][Highest]   = fmax(BoolToDouble(IsEqual(value[OP_BUY][Highest],0.00),value[OP_SELL][Highest],value[OP_BUY][Highest]),
                                                                BoolToDouble(IsEqual(value[OP_SELL][Highest],0.00),value[OP_BUY][Highest],value[OP_SELL][Highest]));
                                break;
        case Lowest:            value[Action][Lowest]    = fmin(BoolToDouble(IsEqual(value[OP_BUY][Lowest],0.00),value[OP_SELL][Lowest],value[OP_BUY][Lowest]),
                                                                BoolToDouble(IsEqual(value[OP_SELL][Lowest],0.00),value[OP_BUY][Lowest],value[OP_SELL][Lowest]));
                                break;
      }    
    }
          
    if (Format == InEquity)
      return (NormalizeDouble(fdiv(value[Action][Measure],AccountBalance()+AccountCredit(),3)*100,1));

    return (NormalizeDouble(value[Action][Measure],2));
  }

//+------------------------------------------------------------------+
//| TicketValue - returns the measure value for the supplied ticket  |
//+------------------------------------------------------------------+
double TicketValue(int Ticket, int Format=InDollar)
  {
    int    tvOrderType;
    
    if (OrderSelect(Ticket,SELECT_BY_TICKET))
    {
      tvOrderType               = OrderType();
      
      if (tvOrderType==OP_BUY||tvOrderType==OP_SELL)
      {
        if (Format == InDollar)
          return (NormalizeDouble(OrderProfit()+OrderSwap()+OrderCommission(),2));
      
        if (Format == InEquity)
          if (AccountBalance()+AccountCredit()>0.00)
            return (NormalizeDouble(((OrderProfit()+OrderSwap()+OrderCommission())/(AccountBalance()+AccountCredit())*100),1));
            
        Print("Ticket Value: Invalid format specified");        
      }
    }
    
    return (0.00);
  }

//+------------------------------------------------------------------+
//| LotCount - returns the total open lots                           |
//+------------------------------------------------------------------+
double LotCount(int Action=NoAction, SummaryType Measure=Total, bool Contrarian=false)
  {
    static const int all = 2;
    double value[3][SummaryTypes];
    int    ticket   = NoValue;
    double area     = 0.00;
    
    ArrayInitialize(value,0.00);

    if (Contrarian)
    {
      if (Action == OP_BUY)
        Action = OP_SELL;
        
      if (Action == OP_SELL)
        Action = OP_BUY;
    }
    
    //--- #bug: used to store the current ticket if LotCount() is called within an OrderSelect() iteration
    if (OrderSelect(OrderTicket(),SELECT_BY_TICKET))
      ticket   = OrderTicket();
        
    for (int count=0; count<OrdersTotal(); count++)
      if (OrderSelect(count,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol()==Symbol())
          if (OrderType()==OP_BUY || OrderType()==OP_SELL)
          {
            switch (Measure)
            {
              case Total:            value[OrderType()][Total]     += OrderLots();
                                     break;
              case Net:              if (Action==NoAction)
                                       value[OrderType()][Net]     += OrderLots();
                                     else
                                     if (OrderProfit()>0.00)
                                       value[OrderType()][Net]     += OrderLots();
                                     else
                                       value[OrderType()][Net]     -= OrderLots();
                                     break; 
              case Profit:           if (OrderProfit()>0.00)
                                       value[OrderType()][Profit]  += OrderLots();
                                     break;
              case Loss:             if (OrderProfit()<0.00)
                                       value[OrderType()][Loss]    += OrderLots();
                                     break;
              case Count:            value[OrderType()][Count]++;
                                     break;
              case Area:             if (IsBetween(BoolToDouble(IsEqual(OrderType(),OP_BUY),Ask,Bid,Digits),
                                           BoolToDouble(IsEqual(OrderType(),OP_BUY),Ask,Bid,Digits)-point(inpOrderSpacing),
                                           BoolToDouble(IsEqual(OrderType(),OP_BUY),Ask,Bid,Digits)+point(inpOrderSpacing)))
                                       value[OrderType()][Area]    += OrderLots();
            }
          }
    
    if (Action == NoAction)
    {
      Action   = all;
      
      switch (Measure)
      {
        case Total:             value[Action][Total]     = value[OP_BUY][Total]  + value[OP_SELL][Total];
                                break;      
        case Net:               value[Action][Net]       = value[OP_BUY][Net]    - value[OP_SELL][Net];
                                break;
        case Profit:            value[Action][Profit]    = value[OP_BUY][Profit] + value[OP_SELL][Profit];
                                break;
        case Loss:              value[Action][Loss]      = value[OP_BUY][Loss]   + value[OP_SELL][Loss];
                                break;
        case Count:             value[Action][Count]     = value[OP_BUY][Count]  + value[OP_SELL][Count];
                                break;
      }    
    }

    //--- #bug: used to reset the current ticket if LotCount() is called within an OrderSelect() iteration
    if (ticket>NoValue)
      if (OrderSelect(ticket,SELECT_BY_TICKET))
        ticket = NoValue;

    if (Measure==Count)
      return (NormalizeDouble(value[Action][Measure],0));

    return (NormalizeDouble(value[Action][Measure],ordLotPrecision));
  }

//+------------------------------------------------------------------+
//| LotSize - returns optimal lot size                               |
//+------------------------------------------------------------------+
double LotSize(double Lots=0.00, double Risk=0.00)
  {
    if (Risk==0.00)
      Risk            = ordEQLotFactor;

    if (NormalizeDouble(inpLotSize,ordLotPrecision) == 0.00)
    {
      if(NormalizeDouble(Lots,ordLotPrecision)>0.00)
        if (NormalizeDouble(Lots,ordLotPrecision)==0.00)
          return (ordAcctMinLot);
        else
        if(Lots>ordAcctMaxLot)
          return (ordAcctMaxLot);
        else
          return(NormalizeDouble(Lots,ordLotPrecision));
    }
    else
      Lots = NormalizeDouble(inpLotSize,ordLotPrecision);

    Lots = fmin((ordEQBase*(Risk/100))/MarketInfo(Symbol(),MODE_MARGINREQUIRED),ordAcctMaxLot);
    
    return(fmax(NormalizeDouble(Lots,ordLotPrecision),ordAcctMinLot));
  }

//+------------------------------------------------------------------+
//| HalfLot - Returns half the allowed lotsize given the value       |
//+------------------------------------------------------------------+
double HalfLot(double Lots=0.00)
  {
    if (NormalizeDouble(ordEQHalfLot,ordLotPrecision) == 0.00)
      ordEQHalfLot = NormalizeDouble(LotSize(0.00)/2,ordLotPrecision);
    
    if (NormalizeDouble(Lots,ordLotPrecision)>0.00)
      if (NormalizeDouble(Lots,ordLotPrecision)>NormalizeDouble(ordEQHalfLot,ordLotPrecision))
        return(NormalizeDouble(Lots/2,ordLotPrecision));
      else
        return(NormalizeDouble(Lots,ordLotPrecision));
       
    return(NormalizeDouble(ordEQHalfLot,ordLotPrecision));
  }
  
//+------------------------------------------------------------------+
//| OrderPending - Returns true if an open order request exists      |
//+------------------------------------------------------------------+
bool OrderPending(int Action=NoAction)
  {
    if (ordLimitAction == NoAction && ordMITAction == NoAction )
      return (false);
      
    if (Action == NoAction)
      return (true);
      
    if ((Action == OP_BUYLIMIT  && ordLimitAction == OP_BUY)||
        (Action == OP_BUYSTOP   && ordMITAction   == OP_BUY)||
        (Action == OP_SELLLIMIT && ordLimitAction == OP_SELL)||
        (Action == OP_SELLSTOP  && ordMITAction   == OP_SELL))
      return (true);
      
    if (Action == ordLimitAction || Action == ordMITAction)
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| ProfitPlanPending - returns true if action is in a profit plan   |
//+------------------------------------------------------------------+
bool ProfitPlanPending(int Action=NoAction)
  {
    bool pending[2]    = {false,false};

    if (ordProfitPlan[OP_BUY][PP_STOP]>0.00)
      if (Bid<ordProfitPlan[OP_BUY][PP_STOP])
        CloseProfitPlan(OP_BUY);

    if (ordProfitPlan[OP_SELL][PP_STOP]>0.00)
      if (Ask>ordProfitPlan[OP_SELL][PP_STOP])
        CloseProfitPlan(OP_SELL);

    switch (Action)
    {
      case OP_BUY:  if (ordProfitPlan[OP_BUY][PP_TARGET]>0.00)
                      pending[OP_BUY]  = true;
                    break;
                    
      case OP_SELL: if (ordProfitPlan[OP_SELL][PP_TARGET]>0.00)
                      pending[OP_SELL]  = true;
                    break;
    }

    if (Action==NoAction)
      return (pending[OP_BUY]||pending[OP_SELL]);
      
    return (pending[Action]);
  }


//+------------------------------------------------------------------+
//| CloseProfitPlan - Removes TP plan for the specified Action       |
//+------------------------------------------------------------------+
void CloseProfitPlan(int Action)
  {
    ordProfitPlan[Action][PP_TARGET] = 0.00;
    ordProfitPlan[Action][PP_STEP]   = 0.00;
    ordProfitPlan[Action][PP_STOP]   = 0.00;
  }

//+------------------------------------------------------------------+
//| OpenProfitPlan - Sets profit targets and steps                   |
//+------------------------------------------------------------------+
void OpenProfitPlan(int Action, double Price, double Step, double Stop=NoValue)
  {
    if (IsBetween(Action,OP_BUY,OP_SELL))
    {
      SetTargetPrice(Action);
    
      if (Action == eqhold)
        SetEquityHold(NoAction);

      ordProfitPlan[Action][PP_TARGET]   = Price;
      ordProfitPlan[Action][PP_STEP]     = Step;
      ordProfitPlan[Action][PP_STOP]     = Stop;        
    }
  }

//+------------------------------------------------------------------+
//| ClosePendingOrders - Closes Pending Orders                       |
//+------------------------------------------------------------------+
void ClosePendingOrders()
  {
    bool cpoOrderClose;
    
    CloseLimitOrder();
    CloseMITOrder();
    CloseQueueOrder(OP_BUY);
    CloseQueueOrder(OP_SELL);
    
    for (int ord=0;ord<OrdersTotal();ord++)
      if (OrderSelect(ord,SELECT_BY_POS))
        if (OrderSymbol()==Symbol())
          if (OrderType()==OP_BUYLIMIT||
              OrderType()==OP_BUYSTOP||
              OrderType()==OP_SELLLIMIT||
              OrderType()==OP_SELLSTOP)
             cpoOrderClose = OrderClose(OrderTicket(),OrderLots(),OrderOpenPrice(),inpSlipFactor*10);
             
  }

//+------------------------------------------------------------------+
//| UpdateLimitOrder - Updates Limit Order key values                |
//+------------------------------------------------------------------+
void UpdateLimitOrder(double Price, double Cancel=NoValue, double Lots=NoValue, double Trail=NoValue, string LimitComment="Updated")
  {
    if (eqhalt || ordLimitAction == eqhaltaction || ordLimitAction == NoAction)
      return;

    if (!ordLimitTrigger)
    {
      ordLimitPrice        = Price;
      ordLimitCancel       = BoolToDouble(Cancel==NoValue,ordLimitCancel,Cancel);
      ordLimitLots         = BoolToDouble(Lots==NoValue,ordLimitLots,LotSize(Lots));
      ordLimitTrail        = BoolToDouble(Trail==NoValue,ordLimitTrail,Trail);
      ordLimitComment      = LimitComment;
    }
  }
  
//+------------------------------------------------------------------+
//| CloseLimitOrder - Removes stealth limit order on market          |
//+------------------------------------------------------------------+
void CloseLimitOrder()
  {
    ordLimitAction       = NoAction;
    ordLimitPrice        = 0.00;
    ordLimitCancel       = 0.00;
    ordLimitLots         = 0.00;
    ordLimitTrail        = 0.00;
    ordLimitComment      = "";
    ordLimitTrigger      = false;
  }
  
//+------------------------------------------------------------------+
//| OpenLimitOrder - Places viewable limit order                     |
//+------------------------------------------------------------------+
void OpenLimitOrder(int Action, double OpenPrice, string LimitComment="Auto-Independent")
  {
    int    oloOpenAction  = NoValue;
    double oloOpenPrice   = NoValue;
    double oloTargetPrice = NoValue;
    double oloStopPrice   = NoValue;
    
    switch (Action)
    {
      case OP_BUY:        Action          = OP_BUYLIMIT;
      case OP_BUYLIMIT:   oloOpenAction   = OP_BUY;
                          oloOpenPrice    = OpenPrice;
                          oloTargetPrice  = Bid+pip(inpDefaultTarget);
                          oloStopPrice    = Bid-pip(inpDefaultStop);
                          Print("Buy Limit: "+DoubleToStr(OpenPrice,Digits)+" t:"+DoubleToStr(oloTargetPrice,Digits)+" s:"+DoubleToStr(oloStopPrice,Digits));
                          break;

      case OP_SELL:       Action          = OP_SELLLIMIT;
      case OP_SELLLIMIT:  oloOpenAction   = OP_SELL;
                          oloOpenPrice    = OpenPrice;
                          oloTargetPrice  = Bid-pip(ordEQNormalSpread)-pip(inpDefaultTarget);
                          oloStopPrice    = Bid+pip(ordEQNormalSpread)+pip(inpDefaultStop);
                          Print("Sell Limit: "+DoubleToStr(OpenPrice,Digits)+" t:"+DoubleToStr(oloTargetPrice,Digits)+" s:"+DoubleToStr(oloStopPrice,Digits));
                          break;
    }
      
    if (oloOpenPrice>0.00)
      if (OrderSend(Symbol(),Action,LotSize(),oloOpenPrice,inpSlipFactor*10,0.00,0.00,LimitComment,inpMagic))
      {
        SetTargetPrice(oloOpenAction,oloTargetPrice);
        SetStopPrice(oloOpenAction,oloStopPrice);
      }
      else
        Print(ActionText(Action)+" failure @"+DoubleToStr(oloOpenPrice,Digits)+"; error ("+DoubleToStr(GetLastError(),0)+"): "+DoubleToStr(LotSize(),2));
  }
  
//+------------------------------------------------------------------+
//| OpenLimitOrder - Places stealth limit order on market            |
//+------------------------------------------------------------------+
void OpenLimitOrder(int Action, double Price, double Lots=0.00, double Cancel=0.00, double Trail=0.00, string LimitComment="Manual")
  {
    if (eqhalt || Action == eqhaltaction)
      return;
      
    ordLimitAction       = Action;
    ordLimitComment      = LimitComment;

    ordLimitPrice        = Price;
    ordLimitCancel       = Cancel;
    ordLimitLots         = LotSize(Lots);
    ordLimitTrail        = Trail;
    ordLimitTrigger      = false;
  }
  
//+------------------------------------------------------------------+
//| UpdateMITOrder - Updates Limit Order key values                  |
//+------------------------------------------------------------------+
void UpdateMITOrder(double Price, double Cancel=NoValue, double Lots=NoValue, double Trail=NoValue, string MITComment="Updated")
  {
    if (eqhalt || ordMITAction == eqhaltaction || ordMITAction == NoAction)
      return;

    if (!ordMITTrigger)
    {
      ordMITPrice        = Price;
      ordMITCancel       = BoolToDouble(Cancel==NoValue,ordMITCancel,Cancel);
      ordMITLots         = BoolToDouble(Lots==NoValue,ordMITLots,LotSize(Lots));
      ordMITTrail        = BoolToDouble(Trail==NoValue,ordMITTrail,Trail);
      ordMITComment      = MITComment;
    }
  }
  
//+------------------------------------------------------------------+
//| CloseMITOrder - Removes stealth limit order on market            |
//+------------------------------------------------------------------+
void CloseMITOrder()
  {
    ordMITAction         = NoAction;
    ordMITPrice          = 0.00;
    ordMITCancel         = 0.00;
    ordMITLots           = 0.00;
    ordMITTrail          = 0.00;
    ordMITComment        = "";
    ordMITTrigger        = false;
  }

//+------------------------------------------------------------------+
//| OpenMITOrder - Places stealth market-if-touched order on market  |
//+------------------------------------------------------------------+
void OpenMITOrder(int Action, double Price, double Cancel=0.00, double Lots=0.00, double Trail=0.00, string MITComment="Manual")
  {    
    if (eqhalt || Action == eqhaltaction)
      return;

    ordMITAction         = Action;
    ordMITComment        = MITComment;
    ordMITPrice          = Price;
    ordMITCancel         = Cancel;
    ordMITLots           = LotSize(Lots);
    ordMITTrail          = Trail;
    ordMITTrigger        = false;
  }

//+------------------------------------------------------------------+
//| CloseQueueOrder - Initializes/Inactivates Order Queue by Action  |
//+------------------------------------------------------------------+
void CloseQueueOrder(int Action)
  {
    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
     if (action==Action||Action==NoAction)
     {
      ordQueue[action].Type      = NoAction;
      ordQueue[action].Price     = NoValue;
      ordQueue[action].Lots      = 0.00;
      ordQueue[action].Step      = NoValue;
      ordQueue[action].Stop      = NoValue;
    }
  }

//+------------------------------------------------------------------+
//| ProcessQueueOrder - Updates/Processes Order Queue by Action      |
//+------------------------------------------------------------------+
void ProcessQueueOrder(int Action)
  {
    double price          = BoolToDouble(IsEqual(Action,OP_BUY),Ask,Bid);

    if (ordQueue[Action].Type==OP_BUYSTOP||ordQueue[Action].Type==OP_SELLLIMIT)
    {
      if (ordQueue[Action].Stop>NoValue)
        if (IsHigher(price,ordQueue[Action].Stop,NoUpdate,Digits))
          CloseQueueOrder(Operation(Action));

      if (IsHigher(price,ordQueue[Action].Price,NoUpdate,Digits))
        if (OpenOrder(ordQueue[Action]))
          while (ordQueue[Action].Price<price)
            ordQueue[Action].Price     += point(ordQueue[Action].Step);
    }

    if (ordQueue[Action].Type==OP_BUYLIMIT||ordQueue[Action].Type==OP_SELLSTOP)
    {
      if (ordQueue[Action].Stop>NoValue)
        if (IsLower(price,ordQueue[Action].Stop,NoUpdate,Digits))
          CloseQueueOrder(Operation(Action));

      if (IsLower(price,ordQueue[Action].Price,NoUpdate,Digits))
        if (OpenOrder(ordQueue[Action]))
          while (ordQueue[Action].Price>price)
            ordQueue[Action].Price     -= point(ordQueue[Action].Step);
    }
  }

//+------------------------------------------------------------------+
//| OpenQueueOrder - Opens a new Order Queue order                   |
//+------------------------------------------------------------------+
void OpenQueueOrder(QueueRec &Queue)
  {
    if (IsBetween(Queue.Type,OP_BUYLIMIT,OP_SELLSTOP))
    {
      ordQueue[Operation(Queue.Type)]    = Queue;
      Print(ActionText(Queue.Type)+"|"+DoubleToStr(Queue.Price,Digits)+"|"+DoubleToStr(Queue.Lots,2)+"|"+DoubleToStr(Queue.Step)+"|"+DoubleToStr(Queue.Stop,Digits));
    }
  }

//+------------------------------------------------------------------+
//| OrderClosed - Returns true if order was closed                   |
//+------------------------------------------------------------------+
bool OrderClosed(int Action=NoAction)
  {
    if (ArraySize(ordClosed)==0)
      return (false);
      
    for (int ord=0;ord<ArraySize(ordClosed);ord++)
      if (Action == ordClosed[ord].Action || Action == NoAction)
        return (true);

    return (false);
  }

//+------------------------------------------------------------------+
//| OrderFulfilled - returns true if order was fulfilled by app only |
//+------------------------------------------------------------------+
bool OrderFulfilled(int Action=NoAction)
  {
    if (ordOpened.Action != NoAction)
      if (ordOpened.Action == Action || Action == NoAction)
        return (true);

    return (false);
  }

//+------------------------------------------------------------------+
//| OpenOrder - Opens Queue Orders meeting queue/step requirements   |
//+------------------------------------------------------------------+
bool OpenOrder(QueueRec &Queue)
  {
    double price       = BoolToDouble(IsEqual(Operation(Queue.Type),OP_BUY),Ask,Bid);
    
    for (int ord=0;ord<ArraySize(ordOpen);ord++)
      if (IsEqual(ordOpen[ord].Action,Operation(Queue.Type)))
        if (IsBetween(price,Queue.Price+point(Queue.Step),Queue.Price+point(Queue.Step)))
          return (false);
    
    return OpenOrder(Operation(Queue.Type),"[Legacy Queue]",Queue.Lots);
  }

//+------------------------------------------------------------------+
//| OpenOrder - Places new orders on market                          |
//+------------------------------------------------------------------+
bool OpenOrder(int Action, string Reason, double Lots=0.00)
  {
    int    ticket     = 0;
    double price      = 0.00;

    ordOpened.Action = Action;
    ordOpened.Ticket = 0;
    ordOpened.Reason = Reason;
  
    if (eqhaltaction==Action)
    {
      ordOpened.Reason = "Action halted";
      return (false);
    }
      
    if (eqhalt)
    {
      ordOpened.Reason = "System halted";
      return (false);
    }

    Lots=LotSize(Lots);
             
    //--- set stops/targets
    if (Action==OP_BUY) 
      price      = Ask;
    
    if (Action==OP_SELL)
      price      = Bid;

    ticket = OrderSend(Symbol(),
             Action,
             Lots,
             NormalizeDouble(price,Digits),
             inpSlipFactor*10,
             0.00,
             0.00,
             Reason,
             inpMagic,
             0,0);

    if (ticket<1)
    {
      ordOpened.Reason = "Error: "+DoubleToStr(GetLastError(),0);
      Print(ActionText(Action)+" failure @"+DoubleToStr(price,Digits)+"; error ("+DoubleToStr(GetLastError(),0)+"): "+DoubleToStr(Lots,2));
      return (false);
    }    
    else
    if (OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
    {
      ordOpened.Price  = OrderOpenPrice();
      ordOpened.Ticket = ticket;
      ordOpened.Lots   = OrderLots();
    
      UpdateTicket(ticket);
 
      return (true);
    }
    
    ordOpened.Reason = "Error: Reason unknown";
    
    return (false);
  }

//+------------------------------------------------------------------+
//| CloseOrder                                                       |
//+------------------------------------------------------------------+
bool CloseOrder(int Ticket, bool Kill=false, double Lots=0.00)
  {
    double price     = 0.00;
    double lots      = Lots;

    double minPVal   = (ordEQMinProfit/100)*(AccountBalance()+AccountCredit());
    string errmsg    = "Order close failure; ticket ("+DoubleToStr(Ticket,0)+"): ";
    
    int    error     = 0;

    if (OrderSelect(Ticket,SELECT_BY_TICKET,MODE_TRADES))
    {
      if (eqhaltaction==OrderType() && !Kill)
        return (false);
        
      if (IsEqual(0.00,lots))
      {
        lots         = OrderLots();

        if (eqretain && !Kill)
          if (OrderLots()<=HalfLot())
            return (false);
          
        if (eqhalf)               lots    = HalfLot(OrderLots());
        if (Kill)                 lots    = OrderLots();
      }
      
      if (OrderType()==OP_BUY)    price   = Bid;
      if (OrderType()==OP_SELL)   price   = Ask;

      RefreshRates();

      if ((eqprofit && OrderProfit()>minPVal) || !eqprofit || Kill)
        if (OrderClose(Ticket,lots,NormalizeDouble(price,Digits),inpSlipFactor*20,Red))
        {
//          Pause ("Where am I closing? "+whereClose,"OrderClose() Issue");
          return (true);          
          //--- Need to incorporate equity baseline logic
        }
        else
        {
          error                 = GetLastError();
          
          switch (error)
          {
            case 129:   errmsg += "Invalid Price(129): "+DoubleToStr(price,Digits)+" Bid:"+DoubleToStr(Bid,Digits)+" Ask:"+DoubleToStr(Ask,Digits);
                        break;
            case 138:   errmsg += "Requote(138): "+DoubleToStr(price,Digits);
                        break;
            default:    errmsg += "Error:"+DoubleToStr(error,0);
          }

          Print(errmsg);
          
          return (false);
        }
    }
    
    return (false);
  }

//+------------------------------------------------------------------+
//| CloseOrders                                                      |
//+------------------------------------------------------------------+
bool CloseOrders(int Option=CloseConditional, int Action=NoAction, double Equity=0.00, string Reason="Unknown")
  {
    int    ticket[];
    int    ticketMin[2] = {NoValue,NoValue};
    int    ticketMax[2] = {NoValue,NoValue};

    int    ord;
    int    ordCount     = 0;

    double ordMin[2]    = {0.00,0.00};
    double ordMax[2]    = {0.00,0.00};

    double lots         = LotCount();
    
    whereClose          = Reason;

    for (ord=0;ord<OrdersTotal();ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol()==Symbol())
          if (OrderType() == Action || Action == NoAction)
          {
            ArrayResize(ticket,ArraySize(ticket)+1);
            ticket[ordCount++] = OrderTicket();

            if (OrderType()==OP_BUY || OrderType()==OP_SELL)           
              if (ticketMin[OrderType()] == NoValue)
              {
                ordMin[OrderType()]      = OrderProfit();
                ordMax[OrderType()]      = OrderProfit();
              
                ticketMin[OrderType()]   = OrderTicket();
                ticketMax[OrderType()]   = OrderTicket();
              }
              else
              {
                ordMin[OrderType()]      = fmin(ordMin[OrderType()],OrderProfit());
                ordMax[OrderType()]      = fmax(ordMax[OrderType()],OrderProfit());
   
                if (NormalizeDouble(ordMin[OrderType()],2) == NormalizeDouble(OrderProfit(),2))
                  ticketMin[OrderType()] = OrderTicket();
                
                if (NormalizeDouble(ordMax[OrderType()],2) == NormalizeDouble(OrderProfit(),2))
                  ticketMax[OrderType()] = OrderTicket();
              }
          }

    //--- Execute Closes
    if (Option == CloseFIFO)
    {
      if (ordCount>0)
        return (CloseOrder(ticket[0],true));
    }
    else

    if (Option == CloseMin)
    {
      if (Action==NoAction)
        if (ticketMin[OP_BUY] == NoValue)
          Action    = OP_SELL;
        else
        if (ticketMin[OP_SELL] == NoValue)
          Action    = OP_BUY;
        else
          Action = BoolToInt(ordMin[OP_BUY]<ordMin[OP_SELL],OP_BUY,OP_SELL);

      return (CloseOrder(ticketMin[Action],true));
    }
    else
    if (Option == CloseMax)
    {
      if (Action==NoAction)
        if (ticketMax[OP_BUY] == NoValue)
          Action    = OP_SELL;
        else
        if (ticketMax[OP_SELL] == NoValue)
          Action    = OP_BUY;
        else
          Action = BoolToInt(ordMax[OP_BUY]>ordMax[OP_SELL],OP_BUY,OP_SELL);
        
      return (CloseOrder(ticketMax[Action],true));
    }
    else
    for (ord=0;ord<ordCount;ord++)
      if (OrderSelect(ticket[ord],SELECT_BY_TICKET,MODE_TRADES))
        switch (Option)
        {
          case CloseAll:            if (OrderType() == Action || Action == NoAction)
                                      CloseOrder(ticket[ord],true);

                                    CloseLimitOrder();
                                    CloseMITOrder();
                                    break;

          case CloseHalf:           if (OrderType() == Action || Action == NoAction)
                                      CloseOrder(ticket[ord],true,HalfLot(OrderLots()));
                                    break;

          case CloseProfit:         if (OrderProfit()>0.00)
                                      if (OrderType() == Action || Action == NoAction)
                                        if (TicketValue(ticket[ord],InEquity)>Equity)
                                          CloseOrder(ticket[ord],true);
                                    break;

          case CloseLoss:           if (OrderProfit()<0.00)
                                      if (OrderType() == Action || Action == NoAction)
                                        if (fabs(TicketValue(ticket[ord],InEquity))>Equity)
                                          CloseOrder(ticket[ord],true);
                                    break;

          case CloseConditional:    if (OrderType() == Action || Action == NoAction)
                                      if (ProfitPlanPending(Action))
                                      {
                                        if (Action==OP_SELL)
                                          if (NormalizeDouble(Ask,Digits)<NormalizeDouble(ordProfitPlan[OP_SELL][PP_TARGET],Digits))
                                          {
                                            CloseOrder(ticketMax[OP_SELL],true);
                                            break;
                                          }
                                             
                                        if (Action==OP_BUY)
                                          if (NormalizeDouble(Bid,Digits)>NormalizeDouble(ordProfitPlan[OP_BUY][PP_TARGET],Digits))
                                          {
                                            CloseOrder(ticketMax[OP_BUY],true);
                                            break;
                                          }
                                      }
                                      else  
                                        if (OrderType()!=eqhold)
                                          CloseOrder(ticket[ord]);
        }

    if (lots == LotCount())
      return (false);

    return (true);
  }

//+------------------------------------------------------------------+
//| KillHalf - Closes half of the open orders                        |
//+------------------------------------------------------------------+
bool KillHalf(int Action=NoAction, CloseOptions Option=CloseAll, string Reason="")
  {
    bool   chSuccess      = false;
    double chLotSize;
    double chOrderPrice   = Ask;
    int    chOrderCount   = 0;
    int    chOrderList[];
    
    whereClose = "KillHalf";
    
    if (StringLen(Reason)>0)
      whereClose += ": "+Reason;
    
    for (int ord=0;ord<OrdersTotal();ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol()==Symbol())
          if (OrderType()==Action || Action==NoAction)
          {
            ArrayResize(chOrderList,chOrderCount+1);
            chOrderList[chOrderCount++] = OrderTicket();
          }

    for (int ord=0;ord<ArraySize(chOrderList);ord++)
      if (OrderSelect(chOrderList[ord],SELECT_BY_TICKET))
      {
        if (OrderLots()<LotSize()*ordAcctMinLot)
          chLotSize = OrderLots();
        else
          chLotSize = fdiv(OrderLots(),2,ordLotPrecision);
        
        if (OrderType()==OP_BUY)
          chOrderPrice = Bid;

        if (Option == CloseAll ||
           (Option == CloseProfit && OrderProfit()>0.00) ||
           (Option == CloseLoss && OrderProfit()<0.00))
          chSuccess   = OrderClose(OrderTicket(),chLotSize,NormalizeDouble(chOrderPrice,Digits),inpSlipFactor*20,clrBlack);
      }

    return(chSuccess);
  }

//+------------------------------------------------------------------+
//| RefreshScreen - updates manual options display                   |
//+------------------------------------------------------------------+
void orderRefreshScreen()
  {
    string stAction[9]    = {"","","","","","","","",""};
    int    actionIdx      = 0;
    string eqHoldOption   = "";
    
    UpdateLabel("acBalance",DoubleToStr(AccountBalance()+AccountCredit(),0),Color(EquityPercent()),12);
    UpdateLabel("acEquity",DoubleToStr(AccountEquity(),0),Color(EquityPercent()));
    UpdateLabel("acMargin",DoubleToStr(fdiv(AccountMargin(),AccountEquity())*100,1)+"%",Color(EquityPercent()));
    UpdateLabel("acLotsLong",DoubleToStr(LotCount(OP_BUY),2),Color(LotValue(OP_BUY,Net)));
    UpdateLabel("acLotsShort",DoubleToStr(LotCount(OP_SELL),2),Color(LotValue(OP_SELL,Net)));
    UpdateLabel("acLotsNet",DoubleToStr(LotCount(NoAction,Net),2),Color(LotCount(NoAction,Net)));
    UpdateLabel("acLongEQ",lpad(LotValue(OP_BUY,Net,InEquity),1),Color(LotValue(OP_BUY,Net,InEquity)));
    UpdateLabel("acShortEQ",lpad(LotValue(OP_SELL,Net,InEquity),1),Color(LotValue(OP_SELL,Net,InEquity)));
    UpdateLabel("acNetEQ",lpad(LotValue(NoAction,Net,InEquity),1),Color(LotValue()));
    
    UpdateLabel("ordPipsOpen",lpad(pip(ordPipsOpen),1),Color(ordPipsOpen));
    UpdateLabel("ordPipsClosed",lpad(pip(ordPipsClosed),1),Color(ordPipsClosed));
    
    if (ordLimitTrigger)
    {
      if (ordLimitAction==OP_BUY)
        UpdateLine("ordTrail",NormalizeDouble(ordLimitPrice+(ordLimitTrail*2),Digits),STYLE_DOT,clrForestGreen);
      else
      if (ordLimitAction==OP_SELL)
        UpdateLine("ordTrail",NormalizeDouble(ordLimitPrice-(ordLimitTrail*2),Digits),STYLE_DOT,clrCrimson);
    }
    else

    if (ordMITTrigger)
      UpdateLine("ordTrail",NormalizeDouble(ordMITPrice,Digits),STYLE_DOT,Color(Direction(ordMITAction,InAction)));

    else
      UpdateLine("ordTrail",0.00,STYLE_DOT,clrGray);

    if (eqhalt)
      UpdateLabel("ordHold","Halt     ",clrRed,10);
    else
    if (eqhold == NoAction)
      UpdateLabel("ordHold","No Hold  ",Color(EquityPercent()),10);
    else
    if (ordHoldTrail)
      if (eqhold == OP_BUY)
        UpdateLabel("ordHold","Trail[L] "+DoubleToString(ordHoldPips,1),clrLawnGreen,9);
      else
        UpdateLabel("ordHold","Trail[S] "+DoubleToString(ordHoldPips,1),clrRed,9);
    else
      UpdateLabel("ordHold",proper(DirText(Direction(eqhold,InAction)))+"    ",Color(EquityPercent()),10);

    UpdateLabel("ordEQ%",DoubleToStr(EquityPercent(),1)+"%",Color(EquityPercent()),12);
    UpdateLabel("ordSpread",DoubleToStr(pip(Ask-Bid),1),Color(EquityPercent()),12);
    UpdateLabel("ordEQ%Min",DoubleToStr(EQMin,1)+"%",Color(EQMin),8);
    UpdateLabel("ordEQ%Max",DoubleToStr(EQMax,1)+"%",Color(EQMax),8);

    //--- Queue Labels (Currently overrides Limit/Stop)
    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
      if (IsBetween(ordQueue[action].Type,OP_BUYLIMIT,OP_SELLSTOP))
        stAction[action+7]  = ActionText(ordQueue[action].Type)+" "+DoubleToStr(ordQueue[action].Price,Digits)+"  "+
                              DoubleToStr(LotSize(ordQueue[action].Lots),ordLotPrecision)+"  "+DoubleToStr(point(ordQueue[action].Step),Digits)+"  "+
                              DoubleToStr(ordQueue[action].Stop,Digits);

    //--- Limit Entry Labels
    if (ordLimitAction!=NoAction)
    {
      stAction[0] = ActionText(ordLimitAction) + " Limit ("+DoubleToStr(ordLimitLots,2)+") " + DoubleToStr(ordLimitPrice,Digits);

      if (ordLimitCancel>0.00)
        stAction[0] += " Cancel " + DoubleToStr(ordLimitCancel,Digits);
        
      if (ordLimitTrail>0.00)
        stAction[1] += " Trail " + DoubleToStr(pip(ordLimitTrail),1);

      if (StringLen(ordLimitComment)>0)
        stAction[0] += " " + ordLimitComment;
    }
    
    //--- Stop(MIT) Entry Labels
    if (ordMITAction!=NoAction)
    {
      stAction[1] = ActionText(ordMITAction) + " MIT ("+DoubleToStr(ordMITLots,2)+") " + DoubleToStr(ordMITPrice,Digits);

      if (ordMITCancel>0.00)
        stAction[1] += " Cancel " + DoubleToStr(ordMITCancel,Digits);

      if (ordMITTrail>0.00)
        stAction[1] += " Trail " + DoubleToStr(pip(ordMITTrail),1);

      if (StringLen(ordMITComment)>0)
        stAction[1] += " " + ordMITComment;
    }

    //--- Exit Labels
    if (ordStopLong)
      stAction[2] = "Long Stop @"+DoubleToStr(ordStopLongPrice,Digits);
      
    if (ordStopShort)
      stAction[3] = "Short Stop @"+DoubleToStr(ordStopShortPrice,Digits);

    if (ordDCAAction!=NoAction)
    {
      stAction[4] = "DCA "+BoolToStr(IsEqual(ordDCAAction,OP_BUY),"Long","Short")+" "+StringSubstr(EnumToString((CloseOptions)ordDCACloseOption),5);
      
      if (ordDCAMinEQ!=0.00)
        stAction[4] += " EQ%: "+DoubleToStr(ordDCAMinEQ,1)+"%";
        
      if (ordDCACloseMinEQ>0.00)
        stAction[4] += " "+DoubleToStr(ordDCACloseMinEQ,1)+"%";
        
      if (ordDCAKeep)
        stAction[4] += " Keep";
    }

    if (ordTargetLong)
      stAction[5] = "Long Target @"+DoubleToStr(ordTargetLongPrice,Digits);
      
    if (ordTargetShort)
      stAction[6] = "Short Target @"+DoubleToStr(ordTargetShortPrice,Digits);


    if (ProfitPlanPending(OP_BUY))
      stAction[5] = "Long Plan @"+DoubleToStr(ordProfitPlan[OP_BUY][PP_TARGET],Digits)
                   +BoolToStr(ordProfitPlan[OP_BUY][PP_STEP]>0,"  Step "+DoubleToString(ordProfitPlan[OP_BUY][PP_STEP],1),"  NoStep")
                   +BoolToStr(ordProfitPlan[OP_BUY][PP_STOP]>0.00,"  Stop "+DoubleToString(ordProfitPlan[OP_BUY][PP_STOP],Digits),"  NoCancel");

    if (ProfitPlanPending(OP_SELL))
      stAction[6] = "Short Plan @"+DoubleToStr(ordProfitPlan[OP_SELL][PP_TARGET],Digits)
                   +"  Step "+DoubleToString(ordProfitPlan[OP_SELL][PP_STEP],1)
                   +"  Stop "+DoubleToString(ordProfitPlan[OP_SELL][PP_STOP],Digits);
                   
    //---Populate Entry/Exit matrix
    for (int idx=0;idx<9;idx++)
    {
      UpdateLabel("ordAction"+IntegerToString(idx),"",clrBlack);

      if (StringLen(stAction[idx])>0)
        UpdateLabel("ordAction"+IntegerToString(actionIdx++),stAction[idx],clrYellow);
    }

    //--- Option labels
    if (eqprofit) 
      UpdateLabel("ordProfit","$",clrYellow,10);
    else UpdateLabel("ordProfit","$",clrDarkGray,10);

    if (eqhalf)
      UpdateLabel("ordHalf",CharToStr(189),clrYellow,9);
    else UpdateLabel("ordHalf",CharToStr(189),clrDarkGray,9);

    if (eqretain) 
      UpdateLabel("ordRetain","®",clrYellow,10);
    else UpdateLabel("ordRetain","®",clrDarkGray,10);
    
    //--- Set eqhaltaction
    if (eqhaltaction == OP_BUY)
    {
      ObjectSetText("ordHoldAction",CharToStr(241),11,"Wingdings",clrYellow);
      ObjectSetText("ordHoldActionX",CharToStr(251),11,"Wingdings",clrRed);
    }
    else
    if (eqhaltaction == OP_SELL)
    {
      ObjectSetText("ordHoldAction",CharToStr(242),11,"Wingdings",clrYellow);
      ObjectSetText("ordHoldActionX",CharToStr(251),11,"Wingdings",clrRed);
    }
    else
    {
      ObjectSetText("ordHoldActionX","",1,"Wingdings",clrNONE);

      if (eqhalt)
        ObjectSetText("ordHoldAction",CharToStr(76),11,"Wingdings",clrRed);
      else
        ObjectSetText("ordHoldAction",CharToStr(74),11,"Wingdings",clrLawnGreen);
    }
    
    if (inpLotFactor!=ordEQLotFactor)
      UpdateLabel("ordRiskLot",DoubleToStr(LotSize(),2),clrYellow);
    else
      UpdateLabel("ordRiskLot",DoubleToStr(LotSize(),2),clrDarkGray);
  }

//+------------------------------------------------------------------+
//| InitializeTick - Initializes flags, operational values each tick |
//+------------------------------------------------------------------+
void InitializeTick()
  {
    //--- clears immediate order details from last tick
    ordOpened.Action      = NoAction;
    ordOpened.Price       = 0.00;
    ordOpened.Ticket      = 0;
    ordOpened.Lots        = 0.00;

    ordEQHalfLot          = 0.00;

    whereClose            = "Close outside of Monitor";
    
    if (eqhalt)
    {
      ClosePendingOrders();
      SetActionHold(NoAction);
    }

    //--- Update equity base
    if (IsEqual(LotCount(),0.00))
      ordEQBase = AccountBalance()+AccountCredit();
      
    //--- clears direction-specific stops
    if (LotCount(OP_SELL) == 0.00)
    {
      if (eqhold == OP_SELL && !ordHoldTrail)
        SetEquityHold(NoAction);

      if (NormalizeDouble(Ask,Digits)>NormalizeDouble(ordStopShortPrice,Digits))
        SetStopPrice(OP_SELL);

      if (NormalizeDouble(Bid,Digits)<NormalizeDouble(ordTargetShortPrice,Digits))
        SetTargetPrice(OP_SELL);

      if (ordDCAAction == OP_SELL)
        CloseDCAPlan(OP_SELL);
    }
    
    if (LotCount(OP_BUY) == 0.00)
    {
      if (eqhold == OP_BUY && !ordHoldTrail)
        SetEquityHold(NoAction);

      if (NormalizeDouble(Bid,Digits)<ordStopLongPrice)
        SetStopPrice(OP_BUY);

      if (NormalizeDouble(Ask,Digits)>ordTargetLongPrice)
        SetTargetPrice(OP_BUY);

      if (ordDCAAction == OP_BUY)
        CloseDCAPlan(OP_BUY);
    }
    
    //---- Examine/Adjust equity hold details
    if (ordHoldTrail)
    {
      if (eqhold == OP_BUY)
      {
        ordHoldBase    = fmax(ordHoldBase,Bid-point(ordHoldPips));

        if (NormalizeDouble(ordHoldBase,Digits)>NormalizeDouble(Bid,Digits))
        {
          SetEquityHold(NoAction);
          CloseProfitPlan(OP_BUY);
          SetTargetPrice(OP_BUY);
        } 
      }
      
      if (eqhold == OP_SELL)
      {
        ordHoldBase    = fmin(ordHoldBase,Ask+point(ordHoldPips));

        if (NormalizeDouble(ordHoldBase,Digits)<NormalizeDouble(Ask,Digits))
        {
          SetEquityHold(NoAction);
          CloseProfitPlan(OP_SELL);
          SetTargetPrice(OP_SELL);
        }
      } 
    }
  }
  
//+------------------------------------------------------------------+
//| ReconcileTick - Post-monitor order reconciliation                |
//+------------------------------------------------------------------+
void ReconcileTick(void)
  {
    int        roNewTickets[];
    static int roOldTickets[];
    double     roProfitLoss = 0.00;
    
    ordPipsOpen             = 0.00;

    ArrayResize(ordOpen,0,1000);
    ArrayResize(ordClosed,0,1000);
    ArrayResize(roNewTickets,0,1000);
          
    for (int ord=0; ord<OrdersTotal(); ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol()==Symbol())
          if (IsBetween(OrderType(),OP_BUY,OP_SELL))
          {
            ArrayResize(ordOpen,ArraySize(ordOpen)+1);
            ordOpen[ArraySize(ordOpen)-1].Action   = OrderType();
            ordOpen[ArraySize(ordOpen)-1].Ticket   = OrderTicket();
            ordOpen[ArraySize(ordOpen)-1].Price    = OrderOpenPrice();
            ordOpen[ArraySize(ordOpen)-1].Lots     = OrderLots();
            
            ArrayResize(roNewTickets,ArraySize(roNewTickets)+1);
            roNewTickets[ArraySize(roNewTickets)-1]  = OrderTicket();
            ordPipsOpen += (OrderOpenPrice()-OrderClosePrice())*fdiv(OrderLots(),LotSize())
                           *BoolToInt(OrderType()==OP_BUY,DirectionDown,DirectionUp);         
          }

    for (int ord=0; ord<ArraySize(roOldTickets); ord++)
      if (OrderSelect(roOldTickets[ord],SELECT_BY_TICKET,MODE_HISTORY))
        if (OrderCloseTime()>0)
        {
          ArrayResize(ordClosed,ArraySize(ordClosed)+1);

          ordClosed[ArraySize(ordClosed)-1].Ticket = OrderTicket();
          ordClosed[ArraySize(ordClosed)-1].Action = OrderType();
          ordClosed[ArraySize(ordClosed)-1].Price  = OrderClosePrice();
          ordClosed[ArraySize(ordClosed)-1].Lots   = OrderLots();
                
          roProfitLoss  += OrderProfit();
          ordPipsClosed += (OrderOpenPrice()-OrderClosePrice())*fdiv(OrderLots(),LotSize())
                           *BoolToInt(OrderType()==OP_BUY,DirectionDown,DirectionUp);
        }
    
    ordEQBase   = ordEQBase+roProfitLoss;

    ArrayResize(roOldTickets,ArraySize(roNewTickets));
    ArrayCopy(roOldTickets,roNewTickets);
    
    orderRefreshScreen();
  }
      
//+------------------------------------------------------------------+
//| OrderMonitor - monitors trade opens, closes, plans, and risk     |
//+------------------------------------------------------------------+
void OrderMonitor(TradeMode Mode)
  {
    if (IsBetween(Mode,Manual,Shutdown))
    {
    //---- Monitor Queue requests
    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
      if (IsEqual(action,Operation(ordQueue[action].Type)))
        ProcessQueueOrder(action);

    //---- Monitor limit requests
    if (ordLimitAction!=NoAction)
    {
      if (ordLimitAction==OP_BUY)
      {      
        if (NormalizeDouble(Bid,Digits)<NormalizeDouble(ordLimitPrice,Digits))
          if (NormalizeDouble(ordLimitTrail,Digits)>0.00)
            if (!ordLimitTrigger)
            {
              ordLimitTrigger   = true;
              ordLimitPrice     = Bid-ordLimitTrail;
            }

        if (ordLimitTrigger)
        {
          ordLimitPrice         = fmin(Bid-ordLimitTrail,ordLimitPrice);

          if (NormalizeDouble(Bid,Digits)>=  NormalizeDouble(ordLimitPrice+(ordLimitTrail*2),Digits))
            if (OpenOrder(OP_BUY,ordLimitComment,ordLimitLots))
              CloseLimitOrder();            
        }
                
        if (NormalizeDouble(Ask,Digits)<NormalizeDouble(ordLimitPrice,Digits))
          if (NormalizeDouble(Ask,Digits)>NormalizeDouble(ordLastAsk,Digits))
            if (OpenOrder(OP_BUY,ordLimitComment,ordLimitLots))
              CloseLimitOrder();

        if (ordLimitCancel>0.00 && Ask>ordLimitCancel)
          CloseLimitOrder();
      }

      if (ordLimitAction==OP_SELL)
      {
        if (NormalizeDouble(Bid,Digits)>NormalizeDouble(ordLimitPrice,Digits))
          if (NormalizeDouble(ordLimitTrail,Digits)>0.00)
            if (!ordLimitTrigger)
            {
              ordLimitTrigger   = true;
              ordLimitPrice     = Bid+ordLimitTrail;
            }

        if (ordLimitTrigger)
        {
          ordLimitPrice         = fmax(Bid+ordLimitTrail,ordLimitPrice);

          if (NormalizeDouble(Bid,Digits)<=NormalizeDouble(ordLimitPrice-(ordLimitTrail*2),Digits))
            if (OpenOrder(OP_SELL,ordLimitComment,ordLimitLots))
              CloseLimitOrder();
        }
        else
        if (NormalizeDouble(Bid,Digits)>NormalizeDouble(ordLimitPrice,Digits))
          if (NormalizeDouble(Bid,Digits)<NormalizeDouble(ordLastBid,Digits))
            if (OpenOrder(OP_SELL,ordLimitComment,ordLimitLots))
              CloseLimitOrder();

        if (ordLimitCancel>0.00 && Bid<ordLimitCancel)
          CloseLimitOrder();
      }
    }

    //---- Monitor MIT requests
    if (ordMITAction!=NoAction)
    {
      if (ordMITAction==OP_BUY)
      {
        if (NormalizeDouble(Bid,Digits)>=NormalizeDouble(ordMITPrice,Digits))
          if (NormalizeDouble(ordMITTrail,Digits)>0.00)
            if (!ordMITTrigger)
            {
              ordMITTrigger     = true;
              ordMITPrice       = Bid+ordMITTrail;
            }
            
        if (ordMITTrigger)
          ordMITPrice           = fmin(Bid+ordMITTrail,ordMITPrice);
              
        if (NormalizeDouble(Bid,Digits)>=NormalizeDouble(ordMITPrice,Digits))
          if (OpenOrder(OP_BUY,ordMITComment,ordMITLots))
            CloseMITOrder();
        
        if (ordMITCancel>0.00 && Ask<ordMITCancel)
          CloseMITOrder();
      }

      if (ordMITAction==OP_SELL)
      {
        if (NormalizeDouble(Bid,Digits)<=NormalizeDouble(ordMITPrice,Digits))
          if (NormalizeDouble(ordMITTrail,Digits)>0.00)
            if (!ordMITTrigger)
            {
              ordMITTrigger     = true;
              ordMITPrice       = Bid-ordMITTrail;
            }
        
        if (ordMITTrigger)
          ordMITPrice           = fmax(Bid-ordMITTrail,ordMITPrice);

        if (NormalizeDouble(Bid,Digits)<=NormalizeDouble(ordMITPrice,Digits))
          if (OpenOrder(OP_SELL,ordMITComment,ordMITLots))
            CloseMITOrder();

        if (ordMITCancel>0.00 && Bid>ordMITCancel)
          CloseMITOrder();
      }
    }

    //---- Long take profit methods
    if (NormalizeDouble(Bid,Digits)<NormalizeDouble(ordLastBid,Digits))
      if (ProfitPlanPending(OP_BUY))
      {
        if (eqhold!=OP_BUY&&CloseOrders(CloseConditional,OP_BUY,0.00,"Plan Long"))
          ordProfitPlan[OP_BUY][PP_TARGET] += point(ordProfitPlan[OP_BUY][PP_STEP]);
      }
      else
      if (ordTargetLong)
      {
        if (NormalizeDouble(Bid,Digits)>NormalizeDouble(ordTargetLongPrice,Digits))
          if (CloseOrders(CloseAll,OP_BUY,0.00,"Target Long"))
            SetTargetPrice(OP_BUY);
      }
      else
      if (eqprofit)
      {
        if(LotValue(OP_BUY,Profit,InEquity)>NormalizeDouble(ordEQMinTarget,1))
          if (eqhold!=OP_BUY && ordDCAAction != OP_BUY)
            CloseOrders(CloseConditional,OP_BUY,0.00,"EQ Profit Long");
      }
      else
      if (LotValue(OP_BUY,Net,InEquity)>NormalizeDouble(ordEQMinTarget,1))
        if (eqhold!=OP_BUY)
          CloseOrders(CloseConditional,OP_BUY,0.00,"Net EQ Profit Long");


    //---- Short take profit methods
    if (NormalizeDouble(Ask,Digits)>NormalizeDouble(ordLastAsk,Digits))
      if(ProfitPlanPending(OP_SELL))
      {      
        if (eqhold!=OP_SELL&&CloseOrders(CloseConditional,OP_SELL,0.00,"Plan Short"))
          ordProfitPlan[OP_SELL][PP_TARGET] -= point(ordProfitPlan[OP_SELL][PP_STEP]);
      }
      else
      if (ordTargetShort)
      {
        if (NormalizeDouble(Ask,Digits)<NormalizeDouble(ordTargetShortPrice,Digits))
          if (CloseOrders(CloseAll,OP_SELL,0.00,"Target Short"))
            SetTargetPrice(OP_SELL);
      }
      else
      if (eqprofit)
      {
        if(LotValue(OP_SELL,Profit,InEquity)>ordEQMinTarget&&Ask>ordLastAsk)
          if (eqhold != OP_SELL && ordDCAAction != OP_SELL)
            CloseOrders(CloseConditional,OP_SELL,0.00,"EQ Profit Short");
      }
      else
      if (LotValue(OP_SELL,Net,InEquity)>NormalizeDouble(ordEQMinTarget,1))
        if (eqhold!=OP_SELL)
          CloseOrders(CloseConditional,OP_SELL,0.00,"Net EQ Profit Short");


    //---- Loss Exits
    if (NormalizeDouble(Bid,Digits)<NormalizeDouble(ordLastBid,Digits))
      if (eqhold!=OP_BUY&&ordDCAAction==OP_BUY)
      {      
        if (LotValue(OP_BUY,Net,InEquity)>NormalizeDouble(ordDCAMinEQ,1))
        {
          if (ordDCACloseMinEQ>0.00)
          {
            if (ordDCACloseOption==CloseMax)
              if (LotValue(OP_BUY,Highest,InEquity)>ordDCACloseMinEQ)
                if (CloseOrders(ordDCACloseOption,OP_BUY,0.00,"DCA Long (Max)"))
                  CloseDCAPlan(OP_BUY,ordDCAKeep);
          }
          else
          if (CloseOrders(ordDCACloseOption,OP_BUY,0.00,"DCA Long"))
            CloseDCAPlan(OP_BUY,ordDCAKeep);
        }
      }
      else
      if (ordStopLong)
      {
        if (NormalizeDouble(Bid,Digits)<NormalizeDouble(ordStopLongPrice,Digits))
          if (CloseOrders(inpRiskCloseOption,OP_BUY,0.00,"Stop Long"))
            SetStopPrice(OP_BUY);
      }
      else
      if (LotValue(OP_BUY,Loss,InEquity)<-NormalizeDouble(ordEQMaxRisk,1))
        CloseOrders(inpRiskCloseOption,OP_BUY,0.00,"EQ Loss Long");
  
    if (NormalizeDouble(Ask,Digits)>NormalizeDouble(ordLastAsk,Digits))
      if (eqhold!=OP_SELL&&ordDCAAction==OP_SELL)
      {
        if (LotValue(OP_SELL,Net,InEquity)>NormalizeDouble(ordDCAMinEQ,1))
        {
          if (ordDCACloseMinEQ>0.00)
          {
            if (ordDCACloseOption==CloseMax)
              if (LotValue(OP_SELL,Highest,InEquity)>ordDCACloseMinEQ)
                if (CloseOrders(ordDCACloseOption,OP_SELL,0.00,"DCA Short (Max)"))
                  CloseDCAPlan(OP_SELL,ordDCAKeep);
          }
          else
          if (CloseOrders(ordDCACloseOption,OP_SELL,0.00,"DCA Short"))
            CloseDCAPlan(OP_SELL,ordDCAKeep);
        }
      }
      else
      if (ordStopShort)
      {
        if (NormalizeDouble(Ask,Digits)>NormalizeDouble(ordStopShortPrice,Digits))
          if (CloseOrders(inpRiskCloseOption,OP_SELL,0.00,"Stop Short"))
            SetStopPrice(OP_SELL);
      }
      else
      if (LotValue(OP_SELL,Loss,InEquity)<-NormalizeDouble(ordEQMaxRisk,1))
        CloseOrders(inpRiskCloseOption,OP_SELL,0.00,"EQ Loss Short");
    }
    
    ordLastAsk         = Ask;
    ordLastBid         = Bid;
  }

//+------------------------------------------------------------------+
//| OrderInit - Sets global operational vars, creates display        |
//+------------------------------------------------------------------+
void OrderInit()
  {  
    ArrayInitialize(ordProfitPlan,0.00);
    
    ordAcctLotSize  = (int)MarketInfo(Symbol(), MODE_LOTSIZE);
    ordAcctMinLot   = MarketInfo(Symbol(), MODE_MINLOT);
    ordAcctMaxLot   = MarketInfo(Symbol(), MODE_MAXLOT);
    
    if (ordAcctMinLot==0.01) ordLotPrecision=2;
    if (ordAcctMinLot==0.1)  ordLotPrecision=1;
    
    for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
      CloseQueueOrder(action);
    
    EQMin           = EquityPercent();
    EQMax           = EquityPercent();
    
    Print("Pair: "+Symbol()+
            " Account Balance: "+DoubleToStr(AccountBalance()+AccountCredit(),2)+
            " Lot Size: "+IntegerToString(ordAcctLotSize)+
            " Min Lot: "+DoubleToString(ordAcctMinLot,2)+
            " Max Lot: "+DoubleToStr(ordAcctMaxLot,2)+
            " Leverage: "+DoubleToStr(AccountLeverage(),0));

    NewLabel("acBalance","",195,11,clrDarkGray,SCREEN_UR);
    NewLabel("acBalanceTag","Balance",195,27,clrWhite,SCREEN_UR);
    NewLabel("acEquity","",225,42,clrDarkGray,SCREEN_UR);
    NewLabel("acEquityTag","Equity",225,54,clrWhite,SCREEN_UR);
    NewLabel("acMargin","",180,42,clrDarkGray,SCREEN_UR);
    NewLabel("acMarginTag","Margin",178,54,clrWhite,SCREEN_UR);
    NewLabel("acLotsLong","",240,69,clrDarkGray,SCREEN_UR);
    NewLabel("acLotsLongTag","Long",238,91,clrWhite,SCREEN_UR);
    NewLabel("acLotsShort","",200,69,clrDarkGray,SCREEN_UR);
    NewLabel("acLotsShortTag","Short",198,91,clrWhite,SCREEN_UR);
    NewLabel("acLotsNet","",165,69,clrDarkGray,SCREEN_UR);
    NewLabel("acNetTag","Net",168,91,clrWhite,SCREEN_UR);
    NewLabel("acLotsTag","Lots",275,69,clrWhite,SCREEN_UR);
    NewLabel("acNetEQTag","Net",275,80,clrWhite,SCREEN_UR);
    NewLabel("acLongEQ","",240,80,clrDarkGray,SCREEN_UR);
    NewLabel("acShortEQ","",200,80,clrDarkGray,SCREEN_UR);
    NewLabel("acNetEQ","",165,80,clrDarkGray,SCREEN_UR);

    NewLabel("ordEQ%","",100,11,clrWhite,SCREEN_UR);
    NewLabel("ordSpread","",38,11,clrWhite,SCREEN_UR);
    NewLabel("ordEQ%Tag","Equity",106,27,clrWhite,SCREEN_UR);
    NewLabel("ordSpreadTag","Spread",32,27,clrWhite,SCREEN_UR);
    NewLabel("ordEQ%Min","",128,42,clrWhite,SCREEN_UR);
    NewLabel("ordEQ%Max","",88,42,clrWhite,SCREEN_UR);
    NewLabel("ordEQ%MinTag","Min",132,54,clrWhite,SCREEN_UR);
    NewLabel("ordEQ%MaxTag","Max",92,54,clrWhite,SCREEN_UR);
    NewLabel("ordHold","No Hold",16,39,clrDarkGray,SCREEN_UR);
    NewLabel("ordHoldAction","",66,54,clrDarkGray,SCREEN_UR);
    NewLabel("ordHoldActionX","",62,59,clrDarkGray,SCREEN_UR);
    NewLabel("ordHalf",CharToStr(189),50,54,clrDarkGray,SCREEN_UR);
    NewLabel("ordProfit","$",36,54,clrDarkGray,SCREEN_UR);
    NewLabel("ordRetain","®",16,53,clrDarkGray,SCREEN_UR);

    NewLabel("ordTarget","Target",105,91,clrWhite,SCREEN_UR);
    NewLabel("ordTargetMaxTag","Max",128,80,clrWhite,SCREEN_UR);
    NewLabel("ordTargetMinTag","Min",92,80,clrWhite,SCREEN_UR);
    NewLabel("ordTargetMax","",122,69,clrWhite,SCREEN_UR);
    NewLabel("ordTargetMin","",88,69,clrWhite,SCREEN_UR);

    NewLabel("ordRisk","Risk",15,91,clrWhite,SCREEN_UR);
    NewLabel("ordRiskMaxTag","Max",52,80,clrWhite,SCREEN_UR);
    NewLabel("ordRiskLotTag","Lotsize",10,80,clrWhite,SCREEN_UR);
    NewLabel("ordRiskMax","",49,69,clrWhite,SCREEN_UR);
    NewLabel("ordRiskLot","",15,69,clrWhite,SCREEN_UR);

    NewLabel("ordPipsOpenTag","Open",300,12,clrWhite,SCREEN_UR);
    NewLabel("ordPipsClosedTag","Closed",300,23,clrWhite,SCREEN_UR);
    NewLabel("ordPipsOpen","0.00",250,12,clrDarkGray,SCREEN_UR);
    NewLabel("ordPipsClosed","0.00",250,23,clrDarkGray,SCREEN_UR);

    NewLabel("ordAction0","",10,103,clrWhite,SCREEN_UR);
    NewLabel("ordAction1","",10,114,clrWhite,SCREEN_UR);
    NewLabel("ordAction2","",10,125,clrWhite,SCREEN_UR);
    NewLabel("ordAction3","",10,136,clrWhite,SCREEN_UR);
    NewLabel("ordAction4","",10,147,clrWhite,SCREEN_UR);
    NewLabel("ordAction5","",10,158,clrWhite,SCREEN_UR);
    NewLabel("ordAction6","",10,169,clrWhite,SCREEN_UR);
    NewLabel("ordAction7","",10,180,clrWhite,SCREEN_UR);
    NewLabel("ordAction8","",10,191,clrWhite,SCREEN_UR);

    NewLine("ordTrail");

    SetDefaults();    
  }
