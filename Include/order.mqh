//+------------------------------------------------------------------+
//|                                                        order.mqh |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property strict

#include <std_utility.mqh>
#include <stdutil.mqh>

//--- Profit Plan
#define PP_TARGET               0
#define PP_STOP                 1
#define PP_STEP                 2

   //---- Close Options
   enum CloseOptions {
                       CloseNone,
                       CloseAll,
                       CloseMin,
                       CloseMax,
                       CloseHalf,
                       CloseProfit,
                       CloseLoss,
                       CloseConditional,
                       NoCloseOption = -1
                     };

   //---- Open Options
   enum OpenOptions {
                       OpenNone,
                       OpenMin,
                       OpenMax,
                       OpenHalf,
                       OpenSingle,
                       OpenDouble,
                       NoOpenOption = -1
                     };


   //---- Extern Variables
   input string        ordHeader           = "";       // +----- Order Options -----+
   input double        inpMinTarget        = 5.0;      // Equity% Target
   input double        inpMinProfit        = 0.8;      // Minimum take profit%
   input double        inpMaxRisk          = 5.0;      // Maximum Risk%
   input double        inpLotFactor        = 2.00;     // Lot Risk% of Balance
   input double        inpLotSize          = 0.00;     // Lot size override
   input double        inpMinLotSize       = 0.25;     // Minimum Lot Size (% of LotSize)
   input int           inpDefaultStop      = 50;       // Default Stop Loss (pips)
   input int           inpDefaultTarget    = 50;       // Default Take Profit (pips)
   input bool          inpEQHalf           = false;    // Split Lots on Profit
   input bool          inpEQProfit         = false;    // Close on Profit Only
   input bool          inpEQRetain         = false;    // Retain orders<1/2; Explicit Close Required!
   input CloseOptions  inpRiskCloseOption  = CloseAll; // Close at risk option
   input int           inpSlipFactor       = 3;        // Slip Factor (pips)
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

//---- Order flags
bool   eqhalf                 = false;
bool   eqprofit               = false;
bool   eqhalt                 = false;
bool   eqretain               = false;

int    eqhold                 = OP_NO_ACTION;
int    eqholdaction           = OP_NO_ACTION;

struct OrderRec {
                  int    Action;
                  int    Ticket;
                  double Price;
                  double Lots;
                  string Reason;
                };

//---- Successful order details, if placed, cleared at end of tick
OrderRec ordOpen               = {OP_NO_ACTION,0,0.00};
OrderRec ordClose[];

double ordEQBase               = AccountBalance()+AccountCredit();
double ordPipsOpen             = 0.00;
double ordPipsClosed           = 0.00;

//---- Limit order details
int    ordLimitAction         = OP_NO_ACTION;
double ordLimitPrice          = 0.00;
double ordLimitCancel         = 0.00;
double ordLimitLots           = 0.00;
double ordLimitTrail          = 0.00;
string ordLimitComment        = "";
bool   ordLimitTrigger        = false;

//---- Market-if-touched order details
int    ordMITAction           = OP_NO_ACTION;
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
int    ordDCAAction           = OP_NO_ACTION;
int    ordDCACloseOption      = CloseAll;
double ordDCAMinEQ            = 0.00;

//--- Equity data
double EQMin                  = 0.00;
double EQMax                  = 0.00;

//--- Last price data
double ordLastAsk             = 0.00;
double ordLastBid             = 0.00;


//+------------------------------------------------------------------+
//| OpenOption - returns the code of the text Open Option            |
//+------------------------------------------------------------------+
OpenOptions OpenOption(string Option)
  {
    if (Option == "NONE")         return (OpenNone);
    if (Option == "MIN")          return (OpenMin);
    if (Option == "MAX")          return (OpenMax);
    if (Option == "HALF")         return (OpenHalf);
    if (Option == "SINGLE")       return (OpenSingle);
    if (Option == "DOUBLE")       return (OpenDouble);
  
    return(NoOpenOption);
  }

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
//| MarginPercent                                                    |
//+------------------------------------------------------------------+
double MarginPercent(int Action=OP_NO_ACTION)
  {
    double margin     = 0.00;

    if (NormalizeDouble(AccountEquity(),2) == 0.00)
      return (0.00);

    margin            = (AccountMargin()/AccountEquity())*100;
    
    if (Action == OP_NO_ACTION)
      return (NormalizeDouble(margin,1));

    if (NormalizeDouble(LotCount(),ordLotPrecision) == 0.00)
      return (0.00);
      
    margin            = margin/LotCount();
    
    if (Action == OP_BUY)
      return (NormalizeDouble(margin*LotCount(OP_BUY),1));

    if (Action == OP_SELL)
      return (NormalizeDouble(margin*LotCount(OP_SELL),1));
      
    return (0.00);
  }

//+------------------------------------------------------------------+
//| EquityPercent                                                    |
//+------------------------------------------------------------------+
double EquityPercent()
  {
    double eqPercent  = 0.00;
    double acctBal    = AccountBalance()+AccountCredit();

    if (acctBal==0.00)
      return (0.00);
          
    eqPercent = NormalizeDouble(((AccountEquity()-acctBal)/acctBal)*100,1);
    
    if (OrdersTotal()>0)
    {
      EQMin=fmin(eqPercent,EQMin);
      EQMax=fmax(eqPercent,EQMax);
    }
    else
    {
      EQMin = 0.00;
      EQMax = 0.00;
    }

    return(eqPercent);    
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
void SetEquityHold(int Action=OP_NO_ACTION, double Pips=0.00, bool Trail=false)
  {
    if (eqhalt)
    {
      eqhold               = OP_NO_ACTION;
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
      
      eqhold               = OP_NO_ACTION;
    }
  }

//+------------------------------------------------------------------+
//| SetTradeResume - If not halted, allows trading to resume         |
//+------------------------------------------------------------------+
void SetTradeResume(int Action=OP_NO_ACTION)
  {
    if (eqhalt)
    {
      if (Action==OP_BUY)
        SetActionHold(OP_SELL);

      if (Action==OP_SELL)
        SetActionHold(OP_BUY);
    }
    else      
      if (Action==eqholdaction)
        SetActionHold(OP_NO_ACTION);

    eqhalt                 = false;
  }

//+------------------------------------------------------------------+
//| SetActionHold - Disallows trading in a specified direction       |
//+------------------------------------------------------------------+
void SetActionHold(int Action=OP_NO_ACTION)
  {
    eqholdaction = Action;
  }

//+------------------------------------------------------------------+
//| ActionHold - Disallows trading in a specified direction          |
//+------------------------------------------------------------------+
bool ActionHold(int Action=OP_NO_ACTION)
  {
    return (eqholdaction==Action);
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
bool DCAPlanPending(int Action=OP_NO_ACTION)
  {
    if (Action==OP_BUY || Action == OP_NO_ACTION)
      if (ordDCAAction == OP_BUY)
        return (true);

    if (Action==OP_SELL || Action == OP_NO_ACTION)
      if (ordDCAAction == OP_SELL)
        return (true);

    return (false);
  }

//+------------------------------------------------------------------+
//| CloseDCAPlan - Closes the DCA Plan for the specified action      |
//+------------------------------------------------------------------+
void CloseDCAPlan(int Action)
  {
    if (ordDCAAction == Action)
    {
      ordDCAAction         = OP_NO_ACTION;
      ordDCAMinEQ          = 0.00;
      ordDCACloseOption    = CloseNone;
    }
  }

//+------------------------------------------------------------------+
//| OpenDCAPlan - Sets the DCA action                                |
//+------------------------------------------------------------------+
void OpenDCAPlan(int Action, double DCAMinEQ=0.00, CloseOptions Option=CloseAll)
  {
    if (Action == OP_BUY || Action == OP_SELL)
    {
      ordDCAAction         = Action;
      ordDCAMinEQ          = DCAMinEQ;
      ordDCACloseOption    = Option;
    
      if (ProfitPlanPending(Action))
        CloseProfitPlan(Action);

      if (Action!=OP_NO_ACTION)
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
          ordTargetShortPrice   = Price+Spread(InPoints);

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
//| LotValue - returns the value of open lots conditionally          |
//+------------------------------------------------------------------+
double LotValue(int Action=OP_NO_ACTION, int Measure=Net, int Format=InDollar, bool Contrarian=false)
  {
    static const int NoAction = 2;
    double lvOrderNetProfit   = 0.00;

    double value[3][QuantityTypes];
    
    if (Contrarian)
    {
      if (Action==OP_BUY)
        Action = OP_SELL;

      if (Action==OP_SELL)
        Action = OP_BUY;
    }
    
    ArrayInitialize(value,0.00);
    
    for (int count=0; count<OrdersTotal(); count++)
      if (OrderSelect(count,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol()==Symbol())
          if (OrderType()==OP_BUY || OrderType()==OP_SELL)
          {
            lvOrderNetProfit  = OrderProfit()+OrderCommission()+OrderSwap();
            
            switch (Measure)
            {
              case Net:         value[OrderType()][Net]      += lvOrderNetProfit;
                                break;
              case Profit:      if (OrderProfit()>0.00)
                                  value[OrderType()][Profit] += lvOrderNetProfit;
                                break;
              case Loss:        if (OrderProfit()<0.00)
                                  value[OrderType()][Loss]   += lvOrderNetProfit;
                                break;
            }
          }
    
    if (Action == OP_NO_ACTION)
    {
      Action   = NoAction;
      
      switch (Measure)
      {
        case Net:               value[Action][Net]       = value[OP_BUY][Net]    + value[OP_SELL][Net];
                                break;
        case Profit:            value[Action][Profit]    = value[OP_BUY][Profit] + value[OP_SELL][Profit];
                                break;
        case Loss:              value[Action][Loss]      = value[OP_BUY][Loss]   + value[OP_SELL][Loss];
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
    double tvProfit = 0.00;
    
    if (OrderSelect(Ticket,SELECT_BY_TICKET))
      tvProfit      = OrderProfit()+OrderSwap()+OrderCommission();
      
    if (Format == InEquity)
      if (AccountBalance()+AccountCredit()>0.00)
        return (NormalizeDouble((tvProfit/(AccountBalance()+AccountCredit())*100),1));

    return (NormalizeDouble(tvProfit,2));
  }

//+------------------------------------------------------------------+
//| LotCount - returns the total open lots                           |
//+------------------------------------------------------------------+
double LotCount(int Action=OP_NO_ACTION, int Measure=Total, bool Contrarian=false)
  {
    static const int Hedge = 2;
    double value[3][5];
    
    ArrayInitialize(value,0.00);

    if (Contrarian)
    {
      if (Action == OP_BUY)
        Action = OP_SELL;
        
      if (Action == OP_SELL)
        Action = OP_BUY;        
    }
        
    for (int count=0; count<OrdersTotal(); count++)
      if (OrderSelect(count,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol()==Symbol())
          if (OrderType()==OP_BUY || OrderType()==OP_SELL)
          {
            switch (Measure)
            {
              case Total:            value[OrderType()][Total]     += OrderLots();
                                     break;
              case Net:              if (Action==OP_NO_ACTION)
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
            }
          }
    
    if (Action == OP_NO_ACTION)
    {
      Action   = Hedge;
      
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
          
    if (Measure == Count)
      return (NormalizeDouble(value[Action][Measure],0));

    return (NormalizeDouble(value[Action][Measure],ordLotPrecision));
  }

//+------------------------------------------------------------------+
//| LotSize - returns optimal lot size                               |
//+------------------------------------------------------------------+
double LotSize(double Lots=0.00)
  {
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

    Lots = fmin(((ordEQBase/ordAcctLotSize)*ordEQLotFactor),ordAcctMaxLot);
    
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
bool OrderPending(int Action=OP_NO_ACTION)
  {
    if (ordLimitAction == OP_NO_ACTION && ordMITAction == OP_NO_ACTION )
      return (false);
      
    if (Action == OP_NO_ACTION)
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
bool ProfitPlanPending(int Action=OP_NO_ACTION)
  {

    if (Action==OP_BUY || Action == OP_NO_ACTION)
      if (NormalizeDouble(ordProfitPlan[OP_BUY][PP_TARGET],Digits)>0.00)
        if (NormalizeDouble(Bid,Digits)<NormalizeDouble(ordProfitPlan[OP_BUY][PP_STOP],Digits))
          CloseProfitPlan(OP_BUY);
        else
          return (true);

    if (Action==OP_SELL || Action == OP_NO_ACTION)
      if (NormalizeDouble(ordProfitPlan[OP_SELL][PP_TARGET],Digits)>0.00)
        if (NormalizeDouble(Ask,Digits)>NormalizeDouble(ordProfitPlan[OP_SELL][PP_STOP],Digits))
          CloseProfitPlan(OP_SELL);
        else
          return (true);

    return (false);
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
void OpenProfitPlan(int Action=OP_NO_ACTION, double Price=0.00, double Step=0.00, double Stop=0.00)
  {    
    if (Action==OP_BUY||Action==OP_SELL)
    {
      SetTargetPrice(Action);
    
      if (Action == eqhold)
        SetEquityHold(OP_NO_ACTION);

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
    if (eqhalt || ordLimitAction == eqholdaction || ordLimitAction == OP_NO_ACTION)
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
    ordLimitAction       = OP_NO_ACTION;
    ordLimitPrice        = 0.00;
    ordLimitCancel       = 0.00;
    ordLimitLots         = 0.00;
    ordLimitTrail        = 0.00;
    ordLimitComment      = "";
    ordLimitTrigger      = false;
  }
  
//+------------------------------------------------------------------+
//| OpenLimitOrder - Places stealth limit order on market            |
//+------------------------------------------------------------------+
void OpenLimitOrder(int Action, double Price, double Cancel=0.00, double Lots=0.00, double Trail=0.00, string LimitComment="Manual")
  {
    if (eqhalt || Action == eqholdaction)
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
    if (eqhalt || ordMITAction == eqholdaction || ordMITAction == OP_NO_ACTION)
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
    ordMITAction         = OP_NO_ACTION;
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
    if (eqhalt || Action == eqholdaction)
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
//| OrderClosed - Returns true if order was closed                   |
//+------------------------------------------------------------------+
bool OrderClosed(int Action=OP_NO_ACTION)
  {
    if (ArraySize(ordClose)==0)
      return (false);
      
    for (int ord=0;ord<ArraySize(ordClose);ord++)
      if (Action == ordClose[ord].Action || Action == OP_NO_ACTION)
        return (true);

    return (false);
  }

//+------------------------------------------------------------------+
//| OrderFulfilled - returns true if order was fulfilled by app only |
//+------------------------------------------------------------------+
bool OrderFulfilled(int Action=OP_NO_ACTION)
  {
    if (ordOpen.Action != OP_NO_ACTION)
      if (ordOpen.Action == Action || Action == OP_NO_ACTION)
        return (true);

    return (false);
  }

//+------------------------------------------------------------------+
//| OpenOrder - Places new orders on market                          |
//+------------------------------------------------------------------+
bool OpenOrder(int Action, string Reason, double Lots=0.00)
  {
    int    ticket     = 0;
    double price      = 0.00;

    if (eqholdaction == Action)
      return (false);
      
    Lots=LotSize(Lots);
             
    //--- set stops/targets
    if (Action==OP_BUY) 
      price      = Ask;
    
    if (Action==OP_SELL)
      price      = Bid;

    if (!eqhalt)
      ticket=OrderSend(Symbol(),
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
      Print(ActionText(Action)+" failure @"+DoubleToStr(price,Digits)+"; error ("+DoubleToStr(GetLastError(),0)+"): "+DoubleToStr(Lots,2));
      return (false);
    }
    else
    if (OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
    {
      ordOpen.Action = Action;
      ordOpen.Price  = OrderOpenPrice();
      ordOpen.Ticket = ticket;
      ordOpen.Lots   = OrderLots();
      ordOpen.Reason = Reason;
    
      UpdateTicket(ticket);
 
      return (true);
    }
    
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
          return (true);          
          //Pause ("Where am I closing? "+whereClose,"OrderClose() Issue");
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
bool CloseOrders(int Option=CloseConditional, int Action=OP_NO_ACTION, string Reason="Unknown")
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
          if (OrderType() == Action || Action == OP_NO_ACTION)
          {
            ArrayResize(ticket,ArraySize(ticket)+1);
            ticket[ordCount++] = OrderTicket();

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
    if (Option == CloseMin)
    {
      if (Action==OP_NO_ACTION)
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
      if (Action==OP_NO_ACTION)
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
          case CloseAll:            if (OrderType() == Action || Action == OP_NO_ACTION)
                                      CloseOrder(ticket[ord],true);
                                    break;

          case CloseHalf:           if (OrderType() == Action || Action == OP_NO_ACTION)
                                      CloseOrder(ticket[ord],true,HalfLot(OrderLots()));
                                    break;

          case CloseProfit:         if (OrderProfit()>0.00)
                                      if (OrderType() == Action || Action == OP_NO_ACTION)
                                        CloseOrder(ticket[ord],true);
                                    break;

          case CloseLoss:           if (OrderProfit()<0.00)
                                      if (OrderType() == Action || Action == OP_NO_ACTION)
                                        CloseOrder(ticket[ord],true);
                                    break;

          case CloseConditional:    if (OrderType() == Action || Action == OP_NO_ACTION)
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
bool KillHalf(int Action=OP_NO_ACTION, CloseOptions Option=CloseAll, string Reason="")
  {
    bool   chSuccess      = false;
    double chLotSize;
    int    chOrderCount   = 0;
    int    chOrderList[];
    
    whereClose = "KillHalf";
    Append(whereClose,Reason,": ");
    
    for (int ord=0;ord<OrdersTotal();ord++)
      if (OrderSelect(ord,SELECT_BY_POS))
        if (OrderSymbol()==Symbol())
          if (OrderType()==Action || Action==OP_NO_ACTION)
          {
            ArrayResize(chOrderList,chOrderCount+1);
            chOrderList[chOrderCount++] = OrderTicket();
          }

    for (int ord=0;ord<ArraySize(chOrderList);ord++)
      if (OrderSelect(chOrderList[ord],SELECT_BY_TICKET))
      {
        if (OrderLots()<LotSize()*inpMinLotSize)
          chLotSize = OrderLots();
        else
          chLotSize = fdiv(OrderLots(),2,ordLotPrecision);
        
        if (Option == CloseAll ||
           (Option == CloseProfit && OrderProfit()>0.00) ||
           (Option == CloseLoss && OrderProfit()<0.00))
        chSuccess   = OrderClose(OrderTicket(),chLotSize,Bid,inpSlipFactor*20,clrBlack);
      }

    return(chSuccess);
  }

//+------------------------------------------------------------------+
//| RefreshScreen - updates manual options display                   |
//+------------------------------------------------------------------+
void orderRefreshScreen()
  {
    string stAction[7]    = {"","","","","","",""};
    int    actionIdx      = 0;
    string eqHoldOption   = "";
    
    UpdateLabel("acBalance",DoubleToStr(AccountBalance()+AccountCredit(),0),DirColor(dir(EquityPercent())),12);
    UpdateLabel("acEquity",DoubleToStr(AccountEquity(),0),DirColor(dir(EquityPercent())));
    UpdateLabel("acMargin",DoubleToStr(MarginPercent(),1)+"%",DirColor(dir(EquityPercent())));
    UpdateLabel("acLotsLong",DoubleToStr(LotCount(OP_BUY),2),DirColor(dir(LotValue(OP_BUY,Net))));
    UpdateLabel("acLotsShort",DoubleToStr(LotCount(OP_SELL),2),DirColor(dir(LotValue(OP_SELL,Net))));
    UpdateLabel("acLotsNet",DoubleToStr(LotCount(OP_NO_ACTION,Net),2),DirColor(dir(LotCount(OP_NO_ACTION,Net))));
    UpdateLabel("acLongEQ",NegLPad(LotValue(OP_BUY,Net,InEquity),1),DirColor(dir(LotValue(OP_BUY,Net,InEquity))));
    UpdateLabel("acShortEQ",NegLPad(LotValue(OP_SELL,Net,InEquity),1),DirColor(dir(LotValue(OP_SELL,Net,InEquity))));
    UpdateLabel("acNetEQ",NegLPad(LotValue(OP_NO_ACTION,Net,InEquity),1),DirColor(dir(LotValue())));
    
    UpdateLabel("ordPipsOpen",NegLPad(Pip(ordPipsOpen),1),DirColor(dir(ordPipsOpen)));
    UpdateLabel("ordPipsClosed",NegLPad(Pip(ordPipsClosed),1),DirColor(dir(ordPipsClosed)));
    
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
      UpdateLine("ordTrail",NormalizeDouble(ordMITPrice,Digits),STYLE_DOT,DirColor(ActionDir(ordMITAction)));

    else
      UpdateLine("ordTrail",0.00,STYLE_DOT,clrGray);

    if (eqhalt)
      UpdateLabel("ordHold","Halt     ",clrRed,10);
    else
    if (eqhold == OP_NO_ACTION)
      UpdateLabel("ordHold","No Hold  ",DirColor(dir(EquityPercent())),10);
    else
    if (ordHoldTrail)
      if (eqhold == OP_BUY)
        UpdateLabel("ordHold","Trail-"+StringSubstr(ActionText(eqhold,IN_DIRECTION),0,1)+" "+DoubleToString(ordHoldPips,1),clrLawnGreen,9);
      else
        UpdateLabel("ordHold","Trail-"+StringSubstr(ActionText(eqhold,IN_DIRECTION),0,1)+" "+DoubleToString(ordHoldPips,1),clrRed,9);
    else
      UpdateLabel("ordHold",proper(ActionText(eqhold,IN_DIRECTION))+"    ",DirColor(dir(EquityPercent())),10);

    UpdateLabel("ordEQ%",DoubleToStr(EquityPercent(),1)+"%",DirColor(dir(EquityPercent())),12);
    UpdateLabel("ordSpread",DoubleToStr(Spread(InPips),1),DirColor(dir(EquityPercent())),12);
    UpdateLabel("ordEQ%Min",DoubleToStr(EQMin,1)+"%",DirColor(dir(EQMin)),8);
    UpdateLabel("ordEQ%Max",DoubleToStr(EQMax,1)+"%",DirColor(dir(EQMax)),8);

    //--- Entry Labels
    if (ordLimitAction!=OP_NO_ACTION)
    {
      stAction[0] = ActionText(ordLimitAction) + " Limit ("+DoubleToStr(ordLimitLots,2)+") " + DoubleToStr(ordLimitPrice,Digits);

      if (ordLimitCancel>0.00)
        stAction[0] += " Cancel " + DoubleToStr(ordLimitCancel,Digits);
        
      if (ordLimitTrail>0.00)
        stAction[1] += " Trail " + DoubleToStr(pip(ordLimitTrail),1);

      if (StringLen(ordLimitComment)>0)
        stAction[0] += " " + ordLimitComment;
    }
    
    if (ordMITAction!=OP_NO_ACTION)
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

    if (ordDCAAction!=OP_NO_ACTION)
    {
      stAction[4] = "DCA " + proper(ActionText(ordDCAAction,IN_DIRECTION))+" "+StringSubstr(EnumToString((CloseOptions)ordDCACloseOption),5);
      
      if (ordDCAMinEQ>0.00)
        stAction[4] += " EQ%: "+DoubleToStr(ordDCAMinEQ,1)+"%";
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
    for (int idx=0;idx<7;idx++)
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
    
    //--- Set eqholdaction
    if (eqholdaction == OP_BUY)
    {
      ObjectSetText("ordHoldAction",CharToStr(241),11,"Wingdings",clrYellow);
      ObjectSetText("ordHoldActionX",CharToStr(251),11,"Wingdings",clrRed);
    }
    else
    if (eqholdaction == OP_SELL)
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
    ordOpen.Action      = OP_NO_ACTION;
    ordOpen.Price       = 0.00;
    ordOpen.Ticket      = 0;
    ordOpen.Lots        = 0.00;

    ordEQHalfLot        = 0.00;

    whereClose          = "Close outside of Monitor";
    
    if (eqhalt)
    {
      ClosePendingOrders();
      SetActionHold(OP_NO_ACTION);
    }

    //--- Update equity base
    if (IsEqual(LotCount(),0.00))
      ordEQBase = AccountBalance()+AccountCredit();
      
    //--- clears direction-specific stops
    if (LotCount(OP_SELL) == 0.00)
    {
      if (eqhold == OP_SELL && !ordHoldTrail)
        SetEquityHold(OP_NO_ACTION);

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
        SetEquityHold(OP_NO_ACTION);

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
          SetEquityHold(OP_NO_ACTION);
          CloseProfitPlan(OP_BUY);
          SetTargetPrice(OP_BUY);
        } 
      }
      
      if (eqhold == OP_SELL)
      {
        ordHoldBase    = fmin(ordHoldBase,Ask+point(ordHoldPips));

        if (NormalizeDouble(ordHoldBase,Digits)<NormalizeDouble(Ask,Digits))
        {
          SetEquityHold(OP_NO_ACTION);
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

    ArrayResize(ordClose,0);
    ArrayResize(roNewTickets,0);
          
    for (int ord=0; ord<OrdersTotal(); ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol()==Symbol())
        {
          ArrayResize(roNewTickets,ArraySize(roNewTickets)+1);
          roNewTickets[ArraySize(roNewTickets)-1]  = OrderTicket();
          ordPipsOpen += (OrderOpenPrice()-OrderClosePrice())*BoolToInt(OrderType()==OP_BUY,DirectionDown,DirectionUp);         
        }

    for (int ord=0; ord<ArraySize(roOldTickets); ord++)
      if (OrderSelect(roOldTickets[ord],SELECT_BY_TICKET,MODE_HISTORY))
        if (OrderCloseTime()>0)
        {
          ArrayResize(ordClose,ArraySize(ordClose)+1);

          ordClose[ArraySize(ordClose)-1].Ticket = OrderTicket();
          ordClose[ArraySize(ordClose)-1].Action = OrderType();
          ordClose[ArraySize(ordClose)-1].Price  = OrderClosePrice();
          ordClose[ArraySize(ordClose)-1].Lots   = OrderLots();
                
          roProfitLoss  += OrderProfit();
          ordPipsClosed += (OrderOpenPrice()-OrderClosePrice())*BoolToInt(OrderType()==OP_BUY,DirectionDown,DirectionUp);
        }
    
    if (IsChanged(ordEQBase,ordEQBase+roProfitLoss,true,2))
    {
      EQMin=EquityPercent();
      EQMax=EquityPercent();
    }
    
    ArrayResize(roOldTickets,ArraySize(roNewTickets));
    ArrayCopy(roOldTickets,roNewTickets);
    
    orderRefreshScreen();
  }
      
//+------------------------------------------------------------------+
//| OrderMonitor - monitors trade opens, closes, plans, and risk     |
//+------------------------------------------------------------------+
void OrderMonitor()
  {
    //---- Monitor limit requests
    if (ordLimitAction!=OP_NO_ACTION)
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
    if (ordMITAction!=OP_NO_ACTION)
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
        if (eqhold!=OP_BUY&&CloseOrders(CloseConditional,OP_BUY,"Plan Long"))
          ordProfitPlan[OP_BUY][PP_TARGET] += point(ordProfitPlan[OP_BUY][PP_STEP]);
      }
      else
      if (ordTargetLong)
      {
        if (NormalizeDouble(Bid,Digits)>NormalizeDouble(ordTargetLongPrice,Digits))
          if (CloseOrders(CloseAll, OP_BUY, "Target Long"))
            SetTargetPrice(OP_BUY);
      }
      else
      if (eqprofit)
      {
        if(LotValue(OP_BUY,Profit,InEquity)>NormalizeDouble(ordEQMinTarget,1))
          if (eqhold!=OP_BUY && ordDCAAction != OP_BUY)
            CloseOrders(CloseConditional, OP_BUY, "EQ Profit Long");
      }
      else
      if (LotValue(OP_BUY,Net,InEquity)>NormalizeDouble(ordEQMinTarget,1))
        if (eqhold!=OP_BUY)
          CloseOrders(CloseConditional, OP_BUY, "Net EQ Profit Long");


    //---- Short take profit methods
    if (NormalizeDouble(Ask,Digits)>NormalizeDouble(ordLastAsk,Digits))
      if(ProfitPlanPending(OP_SELL))
      {      
        if (eqhold!=OP_SELL&&CloseOrders(CloseConditional, OP_SELL, "Plan Short"))
          ordProfitPlan[OP_SELL][PP_TARGET] -= point(ordProfitPlan[OP_SELL][PP_STEP]);
      }
      else
      if (ordTargetShort)
      {
        if (NormalizeDouble(Ask,Digits)<NormalizeDouble(ordTargetShortPrice,Digits))
          if (CloseOrders(CloseAll, OP_SELL, "Target Short"))
            SetTargetPrice(OP_SELL);
      }
      else
      if (eqprofit)
      {
        if(LotValue(OP_SELL,Profit,InEquity)>ordEQMinTarget&&Ask>ordLastAsk)
          if (eqhold != OP_SELL && ordDCAAction != OP_SELL)
            CloseOrders(CloseConditional, OP_SELL, "EQ Profit Short");
      }
      else
      if (LotValue(OP_SELL,Net,InEquity)>NormalizeDouble(ordEQMinTarget,1))
        if (eqhold!=OP_SELL)
          CloseOrders(CloseConditional, OP_SELL, "Net EQ Profit Short");


    //---- Loss Exits
    if (NormalizeDouble(Bid,Digits)<NormalizeDouble(ordLastBid,Digits))
      if (eqhold!=OP_BUY&&ordDCAAction==OP_BUY)
      {      
        if (LotValue(OP_BUY,Net,InEquity)>NormalizeDouble(ordDCAMinEQ,1))
          if (CloseOrders(ordDCACloseOption, OP_BUY, "DCA Long"))
            CloseDCAPlan(OP_BUY);
      }
      else
      if (ordStopLong)
      {
        if (NormalizeDouble(Bid,Digits)<NormalizeDouble(ordStopLongPrice,Digits))
          if (CloseOrders(inpRiskCloseOption, OP_BUY, "Stop Long"))
            SetStopPrice(OP_BUY);
      }
      else
      if (LotValue(OP_BUY,Loss,InEquity)<-NormalizeDouble(ordEQMaxRisk,1))
        CloseOrders(inpRiskCloseOption, OP_BUY, "EQ Loss Long");
  
    if (NormalizeDouble(Ask,Digits)>NormalizeDouble(ordLastAsk,Digits))
      if (eqhold!=OP_SELL&&ordDCAAction==OP_SELL)
      {
        if (LotValue(OP_SELL,Net,InEquity)>NormalizeDouble(ordDCAMinEQ,1))
          if (CloseOrders(ordDCACloseOption, OP_SELL, "DCA Short"))
            CloseDCAPlan(OP_SELL);
      }
      else
      if (ordStopShort)
      {
        if (NormalizeDouble(Ask,Digits)>NormalizeDouble(ordStopShortPrice,Digits))
          if (CloseOrders(inpRiskCloseOption, OP_SELL, "Stop Short"))
            SetStopPrice(OP_SELL);
      }
      else
      if (LotValue(OP_SELL,Loss,InEquity)<-NormalizeDouble(ordEQMaxRisk,1))
        CloseOrders(inpRiskCloseOption, OP_SELL, "EQ Loss Short");

    ordLastAsk = Ask;
    ordLastBid = Bid;
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
    
    EQMin           = EquityPercent();
    EQMax           = EquityPercent();
    
    Print("Account Balance: "+DoubleToStr(AccountBalance()+AccountCredit(),2)+
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

    NewLine("ordTrail");

    SetDefaults();    
  }
