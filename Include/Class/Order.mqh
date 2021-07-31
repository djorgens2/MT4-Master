//+------------------------------------------------------------------+
//|                                                        Order.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <std_utility.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class COrder
  {
  
protected:

  //-- Margin Model Configurations
  enum                BrokerModel
                      {
                        Discount,
                        Premium,
                        FIFO
                      };

  enum                TradeState
                      {
                        Enabled,
                        Hold,
                        Retain,
                        FFE,
                        Halt,
                        TradeStates
                      };
 
  //--- Order Statuses
  enum                OrderStatus
                      {
                        NoStatus,
                        Pending,
                        Immediate,
                        Canceled,
                        Approved,
                        Declined,
                        Rejected,
                        Fulfilled,
                        Expired,
                        Closed,
                        OrderStates
                      };

  //--- Order Values
  enum                OrderMetric
                      {
                        Equity,
                        Margin,
                        MarginLong,
                        MarginShort
                      };

private:

  struct              AccountMetrics
                      {
                        bool            TradeEnabled;
                        BrokerModel     MarginModel;
                        int             Slippage;
                        double          EquityOpen;
                        double          EquityClosed;
                        double          EquityVariance;
                        double          EquityBalance;
                        double          Balance;
                        double          Spread;
                        double          Margin;
                        double          MarginLong;
                        double          MarginShort;
                        double          Equity;
                        double          LotMargin;
                        double          LotSizeMin;
                        double          LotSizeMax;
                        int             LotPrecision;
                      };

  struct              OrderRequest
                      {
                        int             Key;
                        int             Action;
                        string          Requestor;
                        double          Price;
                        double          Lots;
                        double          Target;
                        double          Stop;
                        string          Memo;
                        datetime        Expiry;
                        OrderStatus     Status;
                      };

  struct              OrderSummary 
                      {
                        int            Count;                 //-- Open Order Count
                        double         Lots;                  //-- Lots by Pos, Neg, Net
                        double         Value;                 //-- Order value by Pos, Neg, Net
                        double         Margin;                //-- Margin% by Pos, Neg, Net
                        double         Equity;                //-- Equity% by Pos, Neg, Net
                        int            Ticket[];              //-- Orders aggregated in this summary
                      };

  struct              OrderMaster
                      {
                        TradeState     State;                 //-- Trade State by Action
                        //-- Profit Management
                        double         EquityTarget;          //-- Principal equity target
                        double         MinEquity;             //-- Minimum profit target
                        bool           SplitLots;             //-- Split Lots on Equity Target
                        bool           ProfitHold;            //-- Close trades on profit only
                        //-- Risk Management
                        double         MaxRisk;               //-- Max Principle Risk
                        double         LotScale;              //-- LotSize scaling factor in Margin
                        double         EquityBase;            //-- Retained equity for consistent lot volume
                        double         MaxMargin;             //-- Max Margin by Action
                        //-- Defaults
                        double         DefaultLotSize;        //-- Lot Size Override (fixed, non-scaling)
                        double         DefaultStop;           //-- Default stop (in Pips)
                        double         DefaultTarget;         //-- Default target (in Pips)
                        //-- Order Management
                        double         StopLoss;              //-- Specific stop loss price
                        double         TakeProfit;            //-- Specific profit price target
                        bool           HideStop;              //-- Hide stops (controlled thru EA)
                        bool           HideTarget;            //-- Hide targets (controlled thru EA)
                        //-- Distribution Management
                        double         Step;                  //-- Order Max Range Aggregation
                        double         Start;                 //-- Step Starting root price
                        //-- Summarized Data
                        OrderSummary   Zone[];                //-- Aggregate order detail by order zone
                        OrderSummary   Summary;               //-- Order Summary by Action
                      };
                        
          
          //-- Operational variables
          OrderRequest    Queue[];
          OrderMaster     Master[2];
          OrderSummary    Summary[Total];
          AccountMetrics  Account;

          //-- Private Methods
          double       Order(double Value, OrderMetric Metric, int Format=InPercent);
          int          GetZone(int Action, double Price);

          void         InitTradeOptions(void);
          void         InitSummaryLine(OrderSummary &Line);
          void         UpdateAccount(void);
          void         UpdateSummary(void);

          bool         UpdateTicket(int Ticket, double TakeProfit=0.00, double StopLoss=0.00);
          bool         OrderApproved(OrderRequest &Order);
          bool         OrderProcessed(OrderRequest &Order);
          void         ProcessOrderQueue(void);

public:

                       COrder(BrokerModel Model, int SlipFactor, bool EnableTrade);
                      ~COrder();
                    
          void         Update(void);
          void         Execute(void) {ProcessOrderQueue();};
          void         EnableTrade(void)  {Account.TradeEnabled=true;};
          void         DisableTrade(void) {Account.TradeEnabled=false;};

          //-- Order methods
          double       LotSize(int Action, double Lots=0.00);
          void         Cancel(int Action, string Reason="");
          bool         Fulfilled(int Action=OP_NO_ACTION);
          OrderStatus  Submit(OrderRequest &Order, bool QueueOrders);

          //-- Configuration methods
          void         SetTradeState(int Action, TradeState State);
          void         SetEquity(int Action, double EquityTarget, double MinEquity, bool SplitLots, bool ProfitHold);
          void         SetRisk(int Action, double MaxRisk, double LotScale, double MaxMargin);
          void         SetDefault(int Action, double DefaultLotSize, double DefaultStop, double DefaultTarget);
          void         SetZone(int Action, double Start, double Step);

          //-- Formatted Output Text
          string       QueueStr(int Action=OP_NO_ACTION, bool Force=false);
          string       SummaryLineStr(string Description, OrderSummary &Line, bool Force=false);
          string       MasterStr(int Action);
          
//          OrderRecord operator[](const int Position) const { return(oOrders[Position]); }
  };

//+------------------------------------------------------------------+
//| Order - Returns derivative order Metrics for the supplied Value  |
//+------------------------------------------------------------------+
double COrder::Order(double Value, OrderMetric Metric, int Format=InPercent)
  {
    switch (Metric)
    {
      case Margin:         switch (Format)
                           {
                             case InDecimal: return (NormalizeDouble(fdiv(Value,Account.LotSizeMin)*Account.LotMargin/Account.EquityBalance,3));
                             case InPercent: return (NormalizeDouble(fdiv(Value,Account.LotSizeMin)*Account.LotMargin/Account.EquityBalance*100,1));
                             case InDollar:  return (NormalizeDouble(Value*Account.LotMargin,2));
                           }
                           break;
      case MarginLong:     if (Account.MarginModel==Discount) //-- Shared burden on trunk; majority burden on excess variance
                             return (Order(BoolToDouble(Summary[Net].Lots>0,Summary[Net].Lots)+
                               fdiv(fmin(Master[OP_BUY].Summary.Lots,Master[OP_SELL].Summary.Lots),4),Margin,Format));
                           return (Order(Master[OP_BUY].Summary.Lots,Margin,Format));
                           break;
      case MarginShort:    if (Account.MarginModel==Discount) //-- Shared burden on trunk; majority burden on excess variance
                             return (Order(BoolToDouble(Summary[Net].Lots<0,fabs(Summary[Net].Lots))+
                               fdiv(fmin(Master[OP_BUY].Summary.Lots,Master[OP_SELL].Summary.Lots),4),Margin,Format));
                           return (Order(Master[OP_SELL].Summary.Lots,Margin,Format));
                           break;
      case Equity:         switch (Format)
                           {
                             case InDecimal: return (NormalizeDouble(fdiv(Value,Account.EquityBalance),3));
                             case InPercent: return (NormalizeDouble(fdiv(Value,Account.EquityBalance),3)*100);
                             case InDollar:  return (NormalizeDouble(Value,2));
                           }
                           break;
    };
      
    return (0.00);
  }

//+------------------------------------------------------------------+
//| GetZone - Returns Zone based on Action, Start Price, and Step    |
//+------------------------------------------------------------------+
int COrder::GetZone(int Action, double Price)
  {
    double gzZone   = fdiv(Pip(Price-Master[Action].Start),Master[Action].Step)+1*Direction(Action,InAction);
    
//    Print("gz:"+(string)gzZone+":"+DoubleToStr(Pip(Price-Master[Action].Start),2));
    
    while (gzZone>ArraySize(Master[Action].Zone)-1)
    {
      ArrayResize(Master[Action].Zone,ArraySize(Master[Action].Zone)+1);
      InitSummaryLine(Master[Action].Zone[ArraySize(Master[Action].Zone)-1]);
    }
        
    return ((int)gzZone);
  }

//+------------------------------------------------------------------+
//| InitTradeOptions - Sets the trading options for all Actions      |
//+------------------------------------------------------------------+
void COrder::InitTradeOptions(void)
  {
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      Master[action].State           = Halt;
      Master[action].EquityTarget    = 0.00;
      Master[action].MinEquity       = 0.00;
      Master[action].MaxRisk         = 0.00;
      Master[action].LotScale        = 0.00;
      Master[action].EquityBase      = 0.00;
      Master[action].MaxMargin       = 0.00;
      Master[action].SplitLots       = false;
      Master[action].ProfitHold      = false;
      Master[action].DefaultLotSize  = 0.00;
      Master[action].DefaultStop     = 0.00;
      Master[action].DefaultTarget   = 0.00;
      Master[action].StopLoss        = 0.00;
      Master[action].TakeProfit      = 0.00;
      Master[action].HideStop        = false;
      Master[action].HideTarget      = false;
      Master[action].Step            = 0.00;
      Master[action].Start           = 0.00;
    }
  }

//+------------------------------------------------------------------+
//| InitSummaryLine - Zeroes an Order Summary Record                 |
//+------------------------------------------------------------------+
void COrder::InitSummaryLine(OrderSummary &Line)
  {
      Line.Count                     = 0;
      Line.Lots                      = 0.00;
      Line.Value                     = 0.00;
      Line.Margin                    = 0.00;
      Line.Equity                    = 0.00;
      
      ArrayResize(Line.Ticket,0);
  }

//+------------------------------------------------------------------+
//| UpdateSummary - Updates Order summaries                          |
//+------------------------------------------------------------------+
void COrder::UpdateSummary(void)
  {
    int uoZone                     = 0;
    
    //-- Set zone details on NewFractal
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      InitSummaryLine(Master[action].Summary);
      
      for (int pos=0;pos<Total;pos++)
        InitSummaryLine(Summary[pos]);

      ArrayResize(Master[action].Zone,0);
    }
        
    //-- Order preliminary aggregation
    for (int action=OP_BUY;action<=OP_SELL;action++)
      for (int ord=0;ord<OrdersTotal();ord++)
        if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
          if (OrderType()==action)
          {
            //-- Agg By Action
            ArrayResize(Master[action].Summary.Ticket,++Master[action].Summary.Count);
            Master[action].Summary.Lots               += OrderLots();
            Master[action].Summary.Value              += OrderProfit();
            Master[action].Summary.Ticket[Master[action].Summary.Count-1] = OrderTicket();
            
            //-- Agg By P/L
            if (NormalizeDouble(OrderProfit(),2)<0.00)
            {
              ArrayResize(Summary[Loss].Ticket,++Summary[Loss].Count);
              Summary[Loss].Lots                += OrderLots();
              Summary[Loss].Value               += OrderProfit();
              Summary[Loss].Ticket[Summary[Loss].Count-1] = OrderTicket();
            }
            else
            {
              ArrayResize(Summary[Profit].Ticket,++Summary[Profit].Count);
              Summary[Profit].Lots              += OrderLots();
              Summary[Profit].Value             += OrderProfit();
              Summary[Profit].Ticket[Summary[Profit].Count-1] = OrderTicket();
            }
            
            //-- Agg By Zone
            uoZone                   = GetZone(action,OrderOpenPrice());
            
            ArrayResize(Master[action].Zone[uoZone].Ticket,++Master[action].Zone[uoZone].Count);
            Master[action].Zone[uoZone].Lots     += OrderLots();
            Master[action].Zone[uoZone].Value    += OrderProfit();
            Master[action].Zone[uoZone].Ticket[Master[action].Zone[uoZone].Count-1] = OrderTicket();
          }

    //-- Compute interim Net Values req'd by Equity/Margin calcs
    Summary[Net].Count               = Master[OP_BUY].Summary.Count-Master[OP_SELL].Summary.Count;    
    Summary[Net].Lots                = Master[OP_BUY].Summary.Lots-Master[OP_SELL].Summary.Lots;
    Summary[Net].Value               = Master[OP_BUY].Summary.Value+Master[OP_SELL].Summary.Value;

    //-- Calculate zone values and margins
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      for (int zone=0;zone<ArraySize(Master[action].Zone);zone++)
      {
        Master[action].Zone[zone].Margin = Order(Master[action].Zone[zone].Lots,(OrderMetric)BoolToInt(action==OP_BUY,MarginLong,MarginShort),InPercent)*
                                                       fdiv(Master[action].Zone[zone].Lots,Master[action].Summary.Lots,1);
        Master[action].Zone[zone].Equity = Order(Master[action].Zone[zone].Value,Equity,InPercent);
      }
      
      //-- Calc Action Aggregates
      Master[action].Summary.Equity  = Order(Master[action].Summary.Value,Equity,InPercent);
      Master[action].Summary.Margin  = Order(Master[action].Summary.Lots,(OrderMetric)BoolToInt(action==OP_BUY,MarginLong,MarginShort),InPercent);
    }

    //-- Calc P/L Aggregates
    Summary[Profit].Equity           = Order(Summary[Profit].Value,Equity,InPercent);
    Summary[Profit].Margin           = Order(Summary[Profit].Lots,Margin,InPercent);

    Summary[Loss].Equity             = Order(Summary[Loss].Value,Equity,InPercent);
    Summary[Loss].Margin             = Order(Summary[Loss].Lots,Margin,InPercent);

    //-- Calc Net Aggregates
    Summary[Net].Equity              = Order(Summary[Net].Value,Equity,InPercent);
    Summary[Net].Margin              = Order(Summary[Net].Lots,Margin,InPercent);
  }

//+------------------------------------------------------------------+
//| UpdateAccount - Updates high usage account metrics               |
//+------------------------------------------------------------------+
void COrder::UpdateAccount(void)
  {
    Account.EquityOpen              = NormalizeDouble((AccountEquity()-(AccountBalance()+AccountCredit()))/AccountEquity(),3);
    Account.EquityClosed            = NormalizeDouble((AccountEquity()-(AccountBalance()+AccountCredit()))/(AccountBalance()+AccountCredit()),3);
    Account.EquityVariance          = NormalizeDouble(Account.EquityOpen-Account.EquityClosed,3);
    Account.EquityBalance           = NormalizeDouble(AccountEquity(),2);
    Account.Balance                 = NormalizeDouble(AccountBalance()+AccountCredit(),2);
    Account.Spread                  = NormalizeDouble(Ask-Bid,Digits);
    Account.Equity                  = NormalizeDouble(Account.EquityBalance-Account.Balance,2);
    Account.Margin                  = NormalizeDouble(AccountMargin()/AccountEquity(),3);
    Account.LotMargin               = NormalizeDouble(BoolToDouble(Symbol()=="USDJPY",(MarketInfo(Symbol(),MODE_LOTSIZE)*MarketInfo(Symbol(),MODE_MINLOT)),
                                        (MarketInfo(Symbol(),MODE_LOTSIZE)*MarketInfo(Symbol(),MODE_MINLOT)*Close[0]))/AccountLeverage(),2);
  }

//+------------------------------------------------------------------+
//| UpdateTicket - Modifies ticket values; Currently Stop/TP prices  |
//+------------------------------------------------------------------+
bool COrder::UpdateTicket(int Ticket, double TakeProfit=0.00, double StopLoss=0.00)
  {
    if (OrderSelect(Ticket,SELECT_BY_TICKET,MODE_TRADES))
    {
      if (Symbol()!=OrderSymbol())
        return (false);
        
      //--- set stops
      if (Master[OrderType()].HideStop)
        StopLoss        = 0.00;
      else
      if (IsEqual(StopLoss,0.00))
        if (IsEqual(Master[OrderType()].StopLoss,0.00))
          StopLoss      = BoolToDouble(OrderType()==OP_BUY,Bid,Ask)-point(Master[OrderType()].DefaultStop*Direction(OrderType()));
        else
          StopLoss      = Master[OrderType()].StopLoss;

      //--- set targets
      if (Master[OrderType()].HideTarget)
        TakeProfit      = 0.00;
      else
      if (IsEqual(TakeProfit,0.00))
        if (IsEqual(Master[OrderType()].TakeProfit,0.00))
          TakeProfit    = BoolToDouble(OrderType()==OP_BUY,Bid,Ask)+point(Master[OrderType()].DefaultTarget*Direction(OrderType()));
        else
          TakeProfit    = Master[OrderType()].TakeProfit;

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
//| OrderProcessed - Executes orders from the order manager          |
//+------------------------------------------------------------------+
bool COrder::OrderProcessed(OrderRequest &Order)
  {
    if (Master[Order.Action].State==Halt)
    {
      Order.Memo       = "Action Halted";
      Order.Status     = Declined;
      
      return (false);
    }
      
    if (!Account.TradeEnabled)
    {
      Order.Memo       = "System halted";
      Order.Status     = Declined;

      return (false);
    }

    Order.Lots = LotSize(Order.Action,Order.Lots);
    Order.Key  = OrderSend(Symbol(),
                           Order.Action,
                           Order.Lots,
                           BoolToDouble(Order.Action==OP_BUY,Ask,Bid,Digits),
                           Account.Slippage*10,
                           0.00,
                           0.00,
                           Order.Memo);

    if (Order.Key>0)
      if (OrderSelect(Order.Key,SELECT_BY_TICKET,MODE_TRADES))
      {
        UpdateTicket(Order.Key,Order.Target,Order.Stop);
 
        Order.Action    = OrderType();
        Order.Price     = OrderOpenPrice();
        Order.Lots      = OrderLots();
      
        return (true);
      }
    
    Order.Memo          = "Error: "+DoubleToStr(GetLastError(),0);
    Print(ActionText(Order.Action)+" order open failed @"+DoubleToStr(Order.Price,Digits)+"("+DoubleToStr(Order.Lots,2)+") "+Order.Memo);
    
    return (false);
  }

//+------------------------------------------------------------------+
//| OrderApproved - Performs health/sanity checks for order approval |
//+------------------------------------------------------------------+
bool COrder::OrderApproved(OrderRequest &Order)
  {
    double oaLots[6]                           = {0.00,0.00,0.00,0.00,0.00,0.00};
    
    if (Account.TradeEnabled)
    {      
      oaLots[OP_BUY]                           = Master[OP_BUY].Summary.Lots;
      oaLots[OP_SELL]                          = Master[OP_SELL].Summary.Lots;
      
      oaLots[Action(Order.Action,InAction)]   += LotSize(Order.Action,Order.Lots);

      if (Order.Status==Pending)
      {
        for (int ord=0;ord<ArraySize(Queue);ord++)
          if (Queue[ord].Status==Pending)
            oaLots[Queue[ord].Action]         += LotSize(Queue[ord].Action,Queue[ord].Lots);

        oaLots[Action(Order.Action,InAction)] += oaLots[Order.Action];
      }
      
      if (Master[Order.Action].State==Halt)
        Order.Memo           = "Action disabled";
      else
      if (IsLower(Order(oaLots[Action(Order.Action,InAction)],Margin,InPercent),Master[Action(Order.Action,InAction)].MaxMargin,NoUpdate))
      {
        Order.Status         = Approved;
        return (true);
      }
      else
        Order.Memo           = "Margin-"+DoubleToStr(Order(oaLots[Action(Order.Action,InAction)],Margin,InPercent),1)+"%";
    }
    else
      Order.Memo             = "Trade disabled.";

    Order.Status             = Declined;

    return (false);
  }

//+------------------------------------------------------------------+
//| ProcessOrderQueue - Manages the order cycle                      |
//+------------------------------------------------------------------+
void COrder::ProcessOrderQueue(void)
  {
    OrderStatus  omState                  = NoStatus;

    for (int request=0;request<ArraySize(Queue);request++)
    {
      omState                            = Queue[request].Status;
      
      if (Queue[request].Status==Fulfilled)
        if (OrderSelect(Queue[request].Key,SELECT_BY_TICKET,MODE_HISTORY))
          if (OrderCloseTime()>0)
            Queue[request].Status      = Closed;
          
      if (Queue[request].Status==Pending)
      {
        switch(Queue[request].Action)
        {
          case OP_BUY:          Queue[request].Status      = Immediate;
                                break;
          case OP_BUYSTOP:      if (Ask>=Queue[request].Price)
                                  Queue[request].Status    = Immediate;
                                break;
          case OP_BUYLIMIT:     if (Ask<=Queue[request].Price)
                                  Queue[request].Status    = Immediate;
                                break;
          case OP_SELL:         Queue[request].Status      = Immediate;
                                break;
          case OP_SELLSTOP:     if (Bid<=Queue[request].Price)
                                  Queue[request].Status    = Immediate;
                                break;
          case OP_SELLLIMIT:    if (Bid>=Queue[request].Price)
                                  Queue[request].Status    = Immediate;
                                break;
        }
        
        if (Time[0]>Queue[request].Expiry)
          Queue[request].Status        = Expired;
      }

      if (Queue[request].Status==Immediate)
        if (OrderApproved(Queue[request]))
          if (OrderProcessed(Queue[request]))
            Queue[request].Status      = Fulfilled;
          else
            Queue[request].Status      = Rejected;

      if (IsChanged(omState,Queue[request].Status))
        Queue[request].Expiry          = Time[0]+(Period()*60);
        
      if (omState==Fulfilled)
        Update();
    }
  }

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
COrder::COrder(BrokerModel Model, int SlipFactor, bool EnableTrade)
  {
     //-- Initialize Account
     Account.MarginModel    = Model;
     Account.TradeEnabled   = EnableTrade;
     Account.Slippage       = SlipFactor;

     Account.LotSizeMin     = NormalizeDouble(MarketInfo(Symbol(),MODE_MINLOT),2);
     Account.LotSizeMax     = NormalizeDouble(MarketInfo(Symbol(),MODE_MAXLOT),2);
     Account.LotPrecision   = BoolToInt(Account.LotSizeMin==0.01,2,1);
     
     InitTradeOptions();                        
  }
  
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
COrder::~COrder()
  {
  }

//+------------------------------------------------------------------+
//| Update - Updates order detail stats by action                    |
//+------------------------------------------------------------------+
void COrder::Update(void)
  {
    UpdateAccount();
    UpdateSummary();
  }

//+------------------------------------------------------------------+
//| LotSize - returns optimal lot size                               |
//+------------------------------------------------------------------+
double COrder::LotSize(int Action, double Lots=0.00)
  {
    if (IsEqual(Master[Action].DefaultLotSize,0.00,Account.LotPrecision))
    {
      if(NormalizeDouble(Lots,Account.LotPrecision)>0.00)
        if (NormalizeDouble(Lots,Account.LotPrecision)==0.00)
          return (Account.LotSizeMin);
        else
        if(Lots>Account.LotSizeMax)
          return (Account.LotSizeMax);
        else
          return(NormalizeDouble(Lots,Account.LotPrecision));
    }
    else
      Lots = NormalizeDouble(Master[Action].DefaultLotSize,Account.LotPrecision);

    Lots   = fmin((Master[Action].EquityBase*(Master[Action].LotScale/100))/MarketInfo(Symbol(),MODE_MARGINREQUIRED),Account.LotSizeMax);
    
    return(NormalizeDouble(fmax(Lots,Account.LotSizeMin),Account.LotPrecision));
  }

//+------------------------------------------------------------------+
//| Cancel - Cancels pending orders by Action                        |
//+------------------------------------------------------------------+
void COrder::Cancel(int Action, string Reason="")
  {
    for (int request=0;request<ArraySize(Queue);request++)
      if (Queue[request].Status==Pending)
        if (Queue[request].Action==Action||((Action==OP_BUY||Action==OP_SELL)&&(Action(Queue[request].Action,InAction)==Action)))
        {
          Queue[request].Status   = Canceled;
          Queue[request].Expiry   = Time[0]+(Period()*60);

          if (Reason!="")
            Queue[request].Memo   = Reason;
        }
  }

////+------------------------------------------------------------------+
////| OrderClose - Closes orders based on closure strategy             |
////+------------------------------------------------------------------+
//bool OrderClose(int Action, CloseOptions Option)
//  {
//    int       ocTicket        = NoValue;
//    double    ocValue         = 0.00;
///*
//    for (int ord=0;ord<ocOrders;ord++)
//      if (OrderSelect(ticket[ord],SELECT_BY_TICKET,MODE_TRADES))
//        if (Action=OrderType())
//          switch (Option)
//          {
//            case CloseMin:    if (ocTicket==NoValue)
//                              { 
//                                ocTicket   = OrderTicket();
//                                ocValue    = OrderProfit();
//                              }
//                              else
//                              if (IsLower(OrderProfit(),ocValue))
//                                ocTicket   = OrderTicket();
//                                
//                              break;
//                              
//            case CloseMax:    if (ocTicket==NoValue)
//                              { 
//                                ocTicket   = OrderTicket();
//                                ocValue    = OrderProfit();
//                              }
//                              else
//                              if (IsHigher(OrderProfit(),ocValue))
//                                ocTicket   = OrderTicket();
//                              
//                              break;
//            
//            case CloseAll:    CloseOrder(ticket[ord],true);
//                              break;
//
//            case CloseHalf:   CloseOrder(ticket[ord],true,HalfLot(OrderLots()));
//                              break;
//
//            case CloseProfit: if (OrderProfit()>0.00)
//                                CloseOrder(ticket[ord],true);
//                              break;
//
//            case CloseLoss:   if (OrderProfit()<0.00)
//                                CloseOrder(ticket[ord],true);
//                              break;
//          }
//*/          
//    return(false);
//  }
//

//+------------------------------------------------------------------+
//| Fulfilled - True if Order Fulfilled by Action on current tick    |
//+------------------------------------------------------------------+
bool COrder::Fulfilled(int Action=OP_NO_ACTION)
  {
    for (int oq=0;oq<ArraySize(Queue);oq++)
      if (Queue[oq].Status==Fulfilled)
        return(Action==OP_NO_ACTION||Action==Queue[oq].Action);

    return (false);
  }

//+------------------------------------------------------------------+
//| Submit - Creates orders, assigns key in the OM Queue             |
//+------------------------------------------------------------------+
OrderStatus COrder::Submit(OrderRequest &Order, bool QueueOrders)
  {
    Order.Key              = ArraySize(Queue);
    Order.Status           = Pending;
    
    ArrayResize(Queue,ArraySize(Queue)+1);
    Queue[Order.Key]       = Order;

    while (OrderApproved(Order))
      if (QueueOrders)
        Order.Price         += BoolToDouble(Master[Order.Action].State==FFE,Account.Spread,Pip(Master[Order.Action].Step,InDecimal))
                                *Direction(Order.Action,IN_ACTION,Order.Action==OP_BUYLIMIT||Order.Action==OP_SELLLIMIT);
      else break;

    return (Order.Status);
  }

//+------------------------------------------------------------------+
//| SetTradeState - Enables trading and configures order management  |
//+------------------------------------------------------------------+
void COrder::SetTradeState(int Action, TradeState State)
  {
     Master[Action].State            = State;
  }

//+------------------------------------------------------------------+
//| SetEquity - Configures profit/equity management options          |
//+------------------------------------------------------------------+
void COrder::SetEquity(int Action, double EquityTarget, double MinEquity, bool SplitLots, bool ProfitHold)
  {
     Master[Action].EquityTarget     = EquityTarget;
     Master[Action].MinEquity        = MinEquity;
     Master[Action].SplitLots        = SplitLots;
     Master[Action].ProfitHold       = ProfitHold;
  }

//+------------------------------------------------------------------+
//| SetRisk - Configures risk mitigation management options          |
//+------------------------------------------------------------------+
void COrder::SetRisk(int Action, double MaxRisk, double MaxMargin, double LotScale)
  {
     Master[Action].MaxRisk          = MaxRisk;
     Master[Action].MaxMargin        = MaxMargin;
     Master[Action].LotScale         = LotScale;
  }

//+------------------------------------------------------------------+
//| SetDefault - Sets default order management overrides             |
//+------------------------------------------------------------------+
void COrder::SetDefault(int Action, double DefaultLotSize, double DefaultStop, double DefaultTarget)
  {
     Master[Action].DefaultLotSize   = DefaultLotSize;
     Master[Action].DefaultStop      = DefaultStop;
     Master[Action].DefaultTarget    = DefaultTarget;
  }

//+------------------------------------------------------------------+
//| SetZone - Configures Action zones to supplied Start Price, Step  |
//+------------------------------------------------------------------+
void COrder::SetZone(int Action, double Start, double Step)
  {
     Master[Action].Start            = Start;
     Master[Action].Step             = Step;
  }

//+------------------------------------------------------------------+
//| QueueStr - Returns formatted Order Queue text                    |
//+------------------------------------------------------------------+
string COrder::QueueStr(int Action=OP_NO_ACTION, bool Force=false)
  {
    string qsText       = "\n";
    string qsAction[6]  = {"","","","","",""};
    int    qsCount[6]   = {0,0,0,0,0,0};
    
    for (int oq=0;oq<ArraySize(Queue);oq++)
    {
      qsCount[Queue[oq].Action]++;
      
      Append(qsAction[Queue[oq].Action],"Ticket/ID#: "+IntegerToString(Queue[oq].Key,10,'0'),"\n");
      Append(qsAction[Queue[oq].Action],EnumToString(Queue[oq].Status));
      Append(qsAction[Queue[oq].Action],Queue[oq].Requestor);
      Append(qsAction[Queue[oq].Action],"Open/Request Price: "+BoolToStr(IsEqual(Queue[oq].Price,0.00),"Market",DoubleToStr(Queue[oq].Price,Digits)));
      Append(qsAction[Queue[oq].Action],"Lots: "+DoubleToStr(Queue[oq].Lots,Account.LotPrecision));
      Append(qsAction[Queue[oq].Action],"TP: "+DoubleToStr(Queue[oq].Target,Digits));
      Append(qsAction[Queue[oq].Action],"Stop: "+DoubleToStr(Queue[oq].Stop,Digits));
      Append(qsAction[Queue[oq].Action],"Expiry: "+TimeToStr(Queue[oq].Expiry));
      Append(qsAction[Queue[oq].Action],Queue[oq].Memo);
    }
    
    for (int action=OP_BUY;action<6;action++)
    {
      qsAction[action]      = ActionText(action)+" Queue ["+(string)qsCount[action]+"]\n"+qsAction[action]+"\n";
      
      if (Action==OP_NO_ACTION)
        if (qsCount[action]>0||Force)
          Append(qsText,qsAction[action],"\n");
        
      if (Action==action)
        return (qsAction[action]);
    }

    return (qsText);
  }

//+------------------------------------------------------------------+
//| SummaryLineStr - Returns formatted Summary Line text             |
//+------------------------------------------------------------------+
string COrder::SummaryLineStr(string Description, OrderSummary &Line, bool Force=false)
  {
    string slsText    = "";
    string slsTickets = "";
        
    if (Line.Count>0||Force)
    {
      Append(slsText,Description,"\n");
      Append(slsText,"Open Orders:"+(string)Line.Count);
      Append(slsText,"Lots:"+DoubleToStr(Line.Lots,Account.LotPrecision));
      Append(slsText,"Value:$"+DoubleToStr(Line.Value,2));
      Append(slsText,"Margin:"+DoubleToStr(Line.Margin,3));
      Append(slsText,"Equity:"+DoubleToStr(Line.Equity,3));

      if (ArraySize(Line.Ticket)>0)
        for (int ticket=0;ticket<ArraySize(Line.Ticket);ticket++)
          Append(slsTickets,(string)Line.Ticket[ticket],",");
      else  
        if (InStr(Description,"Net"))
          for (int action=OP_BUY;action<=OP_SELL;action++)
            for (int ticket=0;ticket<ArraySize(Summary[action].Ticket);ticket++)
              Append(slsTickets,(string)Summary[action].Ticket[ticket],",");

        Append(slsText,BoolToStr(slsTickets=="","","  Ticket(s): ["+slsTickets+"]"),"\n");
    }
      
    return (slsText);
  }

//+------------------------------------------------------------------+
//| MasterStr - Returns formatted Master[Action] text                |
//+------------------------------------------------------------------+
string COrder::MasterStr(int Action)
  {
    string msText  = "\n\nMaster Configuration/Order Details for Action["+proper(ActionText(Action))+"]";

    Append(msText,"State:          "+EnumToString(Master[Action].State),"\n");
    Append(msText,"LotSize:        "+DoubleToStr(LotSize(Action),Account.LotPrecision),"\n");
    Append(msText,"EquityTarget:   "+DoubleToStr(Master[Action].EquityTarget,1),"\n");
    Append(msText,"MinEquity:      "+DoubleToStr(Master[Action].MinEquity,1),"%\n");
    Append(msText,"MaxRisk:        "+DoubleToStr(Master[Action].MaxRisk,1),"%\n");
    Append(msText,"LotScale:       "+DoubleToStr(Master[Action].LotScale,1),"%\n");
    Append(msText,"EquityBase:   $ "+DoubleToStr(Master[Action].EquityBase,2),"%\n");
    Append(msText,"MaxMargin:      "+DoubleToStr(Master[Action].MaxMargin,1),"\n");
    Append(msText,"SplitLots:      "+BoolToStr(Master[Action].SplitLots,InYesNo),"%\n");
    Append(msText,"ProfitHold:     "+BoolToStr(Master[Action].ProfitHold,InYesNo),"\n");
    Append(msText,"DefaultLotSize: "+DoubleToStr(Master[Action].DefaultLotSize,Account.LotPrecision),"\n");
    Append(msText,"DefaultStop:    "+DoubleToStr(Master[Action].DefaultStop,1),"\n");
    Append(msText,"DefaultTarget:  "+DoubleToStr(Master[Action].DefaultTarget,1),"\n");
    Append(msText,"StopLoss:       "+DoubleToStr(Master[Action].StopLoss,Digits),"\n");
    Append(msText,"TakeProfit:     "+DoubleToStr(Master[Action].TakeProfit,Digits),"\n");
    Append(msText,"HideStop:       "+BoolToStr(Master[Action].HideStop,InYesNo),"\n");
    Append(msText,"HideTarget:     "+BoolToStr(Master[Action].HideTarget,InYesNo),"\n");
    Append(msText,"Step:           "+DoubleToStr(Master[Action].Step,1),"\n");
    Append(msText,"Start:          "+DoubleToStr(Master[Action].Start,Digits),"\n");

    if (Master[Action].Summary.Count>0)
    {
      Append(msText,"===== "+proper(ActionText(Action))+" Master Zone Detail =====","\n\n");
      
      for (int zone=0;zone<ArraySize(Master[Action].Zone);zone++)
        Append(msText,SummaryLineStr((string)zone,Master[Action].Zone[zone]),"\n");

      Append(msText,"===== "+proper(ActionText(Action))+" Master Summary Detail =====","\n\n");
      
      for (MeasureType measure=0;measure<Total;measure++)
        Append(msText,SummaryLineStr(EnumToString(measure),Summary[measure],Always),"\n");
    }
    
    return (msText);
  }
  
//+------------------------------------------------------------------+
//| IsChanged - Compares events to determine if a change occurred    |
//+------------------------------------------------------------------+
bool IsChanged(OrderStatus &Compare, OrderStatus Value)
  {
    if (Compare==Value)
      return (false);
      
    Compare = Value;
    return (true);
  }