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

  enum                ManagerState
                      {
                        Hold,
                        Retain,
                        Halt,
                        ManagerStates
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
                        ManagerState   State;                 //-- Trade State by Action
                        double         LotSize;               //-- Lot Size Override (fixed, non-scaling)
                        double         EquityTarget;          //-- Principal equity target
                        double         MinEquity;             //-- Minimum profit target
                        double         MaxRisk;               //-- Max Principle Risk
                        double         LotScale;              //-- LotSize scaling factor in Margin
                        double         EquityBase;            //-- Retained equity for consistent lot volume
                        double         Tolerance;             //-- Max Margin by Action
                        bool           SplitLots;             //-- Split Lots on Equity Target
                        bool           ProfitHold;            //-- Close trades on profit only
                        double         DefaultStop;           //-- Default stop (in Pips)
                        double         DefaultTarget;         //-- Default target (in Pips)
                        double         StopLoss;              //-- Specific stop loss price
                        double         TakeProfit;            //-- Specific profit price target
                        bool           HideStop;              //-- Hide stops (controlled thru EA)
                        bool           HideTarget;            //-- Hide targets (controlled thru EA)
                        double         Step;                  //-- Order Max Range Aggregation
                        double         Root;                  //-- Step Starting root price
                        OrderSummary   Zone[];                //-- Aggregate order detail by order zone
                        OrderSummary   Summary;               //-- Order Summary by Action
                      };
                        
          
          //-- Operational variables
          OrderRequest    Queue[];
          OrderMaster     Master[2];
          OrderSummary    Summary[Total];
          AccountMetrics  Account;

          //-- Private Methods
          void         ProcessOrderQueue(void);
          bool         OrderApproved(OrderRequest &Order);
          bool         OrderProcessed(OrderRequest &Order);
          

          void         UpdateAccount(void);
          int          GetZone(int Action, double Price);
          double       Order(double Value, OrderMetric Metric, int Format=InPercent);
          void         InitSummaryLine(OrderSummary &Line);

public:

                       COrder(BrokerModel Model, int SlipFactor, bool EnableTrade);
                      ~COrder();
                    
          //--- Public methods
          void         Update(void);
          bool         UpdateTicket(int Ticket, double TakeProfit=0.00, double StopLoss=0.00);
          void         Cancel(int Action, string Reason="");
          OrderStatus  Submit(OrderRequest &Order, bool QueueOrders);
          double       LotSize(int Action, double Lots=0.00);

//          OrderRecord operator[](const int Position) const { return(oOrders[Position]); }
  };

//+------------------------------------------------------------------+
//| LotSize - returns optimal lot size                               |
//+------------------------------------------------------------------+
double COrder::LotSize(int Action, double Lots=0.00)
  {
    if (IsEqual(Master[Action].LotSize,0.00,Account.LotPrecision))
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
      Lots = NormalizeDouble(Master[Action].LotSize,Account.LotPrecision);

    Lots   = fmin((Master[Action].EquityBase*(Master[Action].LotScale/100))/MarketInfo(Symbol(),MODE_MARGINREQUIRED),Account.LotSizeMax);
    
    return(NormalizeDouble(fmax(Lots,Account.LotSizeMin),Account.LotPrecision));
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
//| ProcessOrderQueue - Manages the order cycle                      |
//+------------------------------------------------------------------+
void COrder::ProcessOrderQueue(void)
  {
    OrderStatus  omState                  = NoStatus;
    bool         omRefreshQueue           = false;

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
      {
        omRefreshQueue                 = true;
        Queue[request].Expiry          = Time[0]+(Period()*60);
      }
    }

    Update();
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
  }
  
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
COrder::~COrder()
  {
  }
 
//+------------------------------------------------------------------+
//| OrderMargin                                                      |
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
      
      if (IsLower(Order(oaLots[Action(Order.Action,InAction)],Margin,InPercent),Master[Action(Order.Action,InAction)].Tolerance,NoUpdate))
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
              
          Update();
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
//| OrderSubmit - Creates orders, assigns key in the OM Queue        |
//+------------------------------------------------------------------+
OrderStatus COrder::Submit(OrderRequest &Order, bool QueueOrders)
  {
    while (OrderApproved(Order))
    {
      Order.Key              = ArraySize(Queue);
      Order.Status           = Pending;
    
      ArrayResize(Queue,ArraySize(Queue)+1);
      Queue[Order.Key]       = Order;
      
//      if (QueueOrders)
//        Order.Price         += Pip(ordEQLotFactor,InDecimal)*Direction(Order.Action,IN_ACTION,Order.Action==OP_BUYLIMIT||Order.Action==OP_SELLLIMIT);
//      else break;
    }

    return (Order.Status);
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
//| GetZone - Returns Zone based on Action, Start Price, and Step    |
//+------------------------------------------------------------------+
int COrder::GetZone(int Action, double Price)
  {
    int gzZone   = (int)(fdiv(Price-Master[Action].Root,Master[Action].Step)+1)*Direction(Action,InAction);
    
    while (gzZone<ArraySize(Master[Action].Zone))
    {
      ArrayResize(Master[Action].Zone,ArraySize(Master[Action].Zone)+1);
      InitSummaryLine(Master[Action].Zone[ArraySize(Master[Action].Zone)-1]);
    }
        
    return (gzZone);
  }

//+------------------------------------------------------------------+
//| Update - Updates order detail stats by action                    |
//+------------------------------------------------------------------+
void COrder::Update(void)
  {
    int uoZone                     = 0;
    
    UpdateAccount();
    
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
    Summary[Net].Lots                = Master[OP_BUY].Summary.Lots-Master[OP_SELL].Summary.Lots;
    Summary[Net].Value               = Master[OP_BUY].Summary.Value+Master[OP_SELL].Summary.Value;

    //-- Calculate zone values and margins
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      for (int zone=0;zone<=ArraySize(Master[action].Zone);zone++)
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
//| IsChanged - Compares events to determine if a change occurred    |
//+------------------------------------------------------------------+
bool IsChanged(OrderStatus &Compare, OrderStatus Value)
  {
    if (Compare==Value)
      return (false);
      
    Compare = Value;
    return (true);
  }

