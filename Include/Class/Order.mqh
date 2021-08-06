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

  //-- Margin Model Configurations
  enum                LogType
                      {
                        Request,
                        Order,
                        LogTypes
                      };

  //-- Trade Manager States
  enum                TradeState
                      {
                        Hold,
                        Retain,
                        FFE,
                        DCA,
                        TradeStates
                      };

  //--- Queue Statuses
  enum                QueueStatus
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
                        Completed,
                        Closed,
                        Reconciled,
                        Invalid,
                        QueueStates
                      };

private:

  //--- Order Metrics
  enum                OrderMetric
                      {
                        Equity,
                        Margin,
                        MarginLong,
                        MarginShort
                      };

  struct              AccountMetrics
                      {
                        bool            TradeEnabled;
                        BrokerModel     MarginModel;
                        int             MaxSlippage;
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

  struct              OrderLog
                      {
                        int             Key;
                        int             Ticket;
                        string          Note;
                        datetime        Received;
                      };

  struct              OrderResubmit
                      {
                        int             Type;              //-- Order Type following fill
                        double          Cancel;            //-- Cancel order on Stop
                        double          Limit;             //-- Cancel order on Limit
                        double          Step;              //-- Resubmit Stop/Limit from fill
                      };

  struct              OrderRequest
                      {
                        QueueStatus     Status;
                        int             Key;
                        int             Ticket;
                        int             Type;
                        int             Action;
                        string          Requestor;
                        double          Price;
                        double          Lots;
                        double          TakeProfit;
                        double          StopLoss;
                        bool            Hide;
                        string          Memo;
                        datetime        Expiry;
                        OrderResubmit   Pend;
                      };

  struct              OrderDetail
                      {
                        QueueStatus     Status;
                        int             Key;
                        int             Ticket;
                        int             Action;
                        double          Price;
                        double          Lots;
                        double          Profit;
                        double          Swap;
                        bool            Split;
                        double          TakeProfit;
                        double          StopLoss;
                        string          Memo;
                      };

  struct              OrderSummary
                      {
                        int            Index;                 //-- Zone Node (Zone summaries only)
                        int            Count;                 //-- Open Order Count
                        double         Lots;                  //-- Lots by Pos, Neg, Net
                        double         Value;                 //-- Order value by Pos, Neg, Net
                        double         Margin;                //-- Margin% by Pos, Neg, Net
                        double         Equity;                //-- Equity% by Pos, Neg, Net
                        int            Ticket[];              //-- Orders aggregated in this summary
                      };

  struct              OrderMaster
                      {
                        bool           TradeEnabled;          //-- Enables/Disables trading by Action
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
                        double         DCA;                   //-- DCA (peak) for distribution management
                        double         Step;                  //-- Order Max Range Aggregation
                        int            TicketMax[1];          //-- Ticket w/Highest Profit
                        int            TicketMin[1];          //-- Ticket w/Least Profit
                        //-- Summarized Data & Arrays
                        OrderDetail    Order[];               //-- Order details by ticket/action
                        OrderSummary   Zone[];                //-- Aggregate order detail by order zone
                        OrderSummary   Summary;               //-- Order Summary by Action
                      };


          //-- Operational variables
          OrderLog        Log[];
          OrderRequest    Queue[];
          OrderMaster     Master[2];
          OrderSummary    Summary[Total];
          AccountMetrics  Account;

          //-- Private Methods
          void         AppendLog(int Key, int Ticket,string Note);
          void         PurgeLog(int Retain=0);

          double       CalcMetric(OrderMetric Metric, double Value, int Format=InPercent);
          void         CalcDCA(int Action, double Extended);

          void         InitMasterConfig(void);
          void         InitSummaryLine(OrderSummary &Line, int Node=NoValue);

          void         UpdateSummary(void);
          void         UpdateAccount(void);

          void         Reconcile(void);
          
          void         MergeRequest(OrderRequest &Request, bool Split=false);
          void         MergeOrder(int Action, int Ticket);

          bool         OrderUpdated(OrderDetail &Order);
          bool         OrderApproved(OrderRequest &Request);
          bool         OrderOpened(OrderRequest &Request);
          bool         OrderClosed(OrderDetail &Order, double Lots=0.00);

          void         ProcessOrders(void);
          void         ProcessClosures(int &Batch[], bool Conditional);

public:

                       COrder(BrokerModel Model, int MaxSlippage, bool EnableTrade);
                      ~COrder();

          void         Update(void);
          void         Execute(void)            {ProcessOrders();};
          void         EnableTrade(void)        {Account.TradeEnabled=true;};
          void         DisableTrade(void)       {Account.TradeEnabled=false;};
          void         EnableTrade(int Action)  {Master[Action].TradeEnabled=true;};
          void         DisableTrade(int Action) {Master[Action].TradeEnabled=false;};

          //-- Order methods
          double       LotSize(int Action, double Lots=0.00);
          void         Cancel(int Action, string Reason="");
          void         Cancel(OrderRequest &Request, QueueStatus Status, string Reason="");
          bool         Fulfilled(int Action=OP_NO_ACTION);
          bool         Submit(OrderRequest &Order, double Price=0.00);

          //-- Array Property Interfaces
          OrderRequest BlankRequest(void);
          OrderDetail  Ticket(int Ticket);
          OrderRequest Request(int Key, int Ticket=NoValue);
          OrderSummary Zone(int Action, int Node);

          int          NodeIndex(int Action, double Price);

          //-- Configuration methods
          void         SetNode(int Action, OrderSummary &Node);
          void         SetTradeState(int Action, TradeState State);
          void         SetStopLoss(int Action, double StopLoss, double DefaultStop, bool HideStop);
          void         SetTakeProfit(int Action, double TakeProfit, double DefaultTarget, bool HideTarget);
          void         SetEquityTargets(int Action, double EquityTarget, double MinEquity, bool SplitLots, bool ProfitHold);
          void         SetRiskLimits(int Action, double MaxRisk, double MaxMargin, double LotScale);
          void         SetDefaults(int Action, double DefaultLotSize, double DefaultStop, double DefaultTarget);
          void         SetZoneStep(int Action, double Step);

          //-- Formatted Output Text
          void         PrintLog(LogType Type);
          string       OrderDetailStr(OrderDetail &Order);
          string       OrderStr(int Action=OP_NO_ACTION);
          string       RequestStr(OrderRequest &Request);
          string       QueueStr(int Action=OP_NO_ACTION, bool Force=false);
          string       SummaryLineStr(string Description, OrderSummary &Line, bool Force=false);
          string       SummaryStr(void);
          string       ZoneSummaryStr(int Action=OP_NO_ACTION);
          string       MasterStr(int Action);

          OrderSummary operator[](const MeasureType Measure) const { return(Summary[Measure]);};
          OrderSummary operator[](const int Action) const { return(Master[Action].Summary);};
  };

//+------------------------------------------------------------------+
//| AppendLog - Appends log on ticket-related events                 |
//+------------------------------------------------------------------+
void COrder::AppendLog(int Key, int Ticket,string Note)
  {
    if (StringLen(Note)>0)
    {
      ArrayResize(Log,ArraySize(Log)+1,1000);

      Log[ArraySize(Log)-1].Key        = Key;
      Log[ArraySize(Log)-1].Ticket     = Ticket;
      Log[ArraySize(Log)-1].Note       = Note;
      Log[ArraySize(Log)-1].Received   = TimeCurrent();
    }
  }

//+------------------------------------------------------------------+
//| PurgeLog - Purges log FIFO based on supplied retention           |
//+------------------------------------------------------------------+
void COrder::PurgeLog(int Retain=0)
  {
    if (Retain<0)
      return;

    ArrayResize(Log,0,fmax(Retain,1000));
  }

//+------------------------------------------------------------------+
//| CalcMetric - Returns derived order Metric for the Value supplied |
//+------------------------------------------------------------------+
double COrder::CalcMetric(OrderMetric Metric, double Value, int Format=InPercent)
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
      case MarginLong:     if (IsEqual(Account.MarginModel,Discount)) //-- Shared burden on trunk; majority burden on excess variance
                             return (CalcMetric(Margin,BoolToDouble(Summary[Net].Lots>0,Summary[Net].Lots)+
                               fdiv(fmin(Master[OP_BUY].Summary.Lots,Master[OP_SELL].Summary.Lots),4),Format));
                           return (CalcMetric(Margin,Master[OP_BUY].Summary.Lots,Format));
                           break;
      case MarginShort:    if (IsEqual(Account.MarginModel,Discount)) //-- Shared burden on trunk; majority burden on excess variance
                             return (CalcMetric(Margin,BoolToDouble(Summary[Net].Lots<0,fabs(Summary[Net].Lots))+
                               fdiv(fmin(Master[OP_BUY].Summary.Lots,Master[OP_SELL].Summary.Lots),4),Format));
                           return (CalcMetric(Margin,Master[OP_SELL].Summary.Lots,Format));
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
//| CalcDCA - Calculates DCA by Action                               |
//+------------------------------------------------------------------+
void COrder::CalcDCA(int Action, double Extended)
  {
    //-- DCA Calc
    if (IsEqual(Master[Action].Summary.Count,0))
      Master[Action].DCA     = 0;
    else
      Master[Action].DCA     = BoolToDouble(IsEqual(Action,OP_BUY),Bid,Ask)
                               -fdiv((Master[Action].Summary.Lots*BoolToDouble(IsEqual(Action,OP_BUY),Bid,Ask))
                               -Extended,Master[Action].Summary.Lots);

    UpdateLine("czDCA:"+(string)Action,Master[Action].DCA,STYLE_SOLID,Color(Direction(Action,InAction),IN_CHART_DIR));
  }

//+------------------------------------------------------------------+
//| InitTradeManagers - Sets the trading options for all Actions     |
//+------------------------------------------------------------------+
void COrder::InitMasterConfig(void)
  {
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      Master[action].State           = Hold;
      Master[action].TradeEnabled    = Account.TradeEnabled;
      Master[action].EquityTarget    = 0.00;
      Master[action].MinEquity       = 0.00;
      Master[action].SplitLots       = false;
      Master[action].ProfitHold      = false;
      Master[action].MaxRisk         = 0.00;
      Master[action].MaxMargin       = 0.00;
      Master[action].LotScale        = 0.00;
      Master[action].EquityBase      = Account.Balance;
      Master[action].DefaultLotSize  = 0.00;
      Master[action].DefaultStop     = 0.00;
      Master[action].DefaultTarget   = 0.00;
      Master[action].StopLoss        = 0.00;
      Master[action].TakeProfit      = 0.00;
      Master[action].HideStop        = false;
      Master[action].HideTarget      = false;
      Master[action].Step            = 0.00;
    }
  }

//+------------------------------------------------------------------+
//| InitSummaryLine - Zeroes an Order Summary Record                 |
//+------------------------------------------------------------------+
void COrder::InitSummaryLine(OrderSummary &Line, int Index=NoValue)
  {
      Line.Index                     = Index;
      Line.Count                     = 0;
      Line.Lots                      = 0.00;
      Line.Value                     = 0.00;
      Line.Margin                    = 0.00;
      Line.Equity                    = 0.00;

      ArrayResize(Line.Ticket,0,100);
  }

//+------------------------------------------------------------------+
//| UpdateSummary - Updates Order summaries                          |
//+------------------------------------------------------------------+
void COrder::UpdateSummary(void)
  {
    OrderSummary node;

    double usProfitMin               = 0.00;
    double usProfitMax               = 0.00;
    double usExtended                = 0.00;

    //-- Initialize Summaries
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      Master[action].TicketMin[0]    = NoValue;
      Master[action].TicketMax[0]    = NoValue;

      InitSummaryLine(Master[action].Summary);

      for (int pos=0;pos<Total;pos++)
        InitSummaryLine(Summary[pos]);

      ArrayResize(Master[action].Zone,0,100);
    }

    //-- Order preliminary aggregation
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      for (int ord=0;ord<OrdersTotal();ord++)
        if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
          if (IsEqual(OrderType(),action)&&Symbol()==OrderSymbol())
          {
            MergeOrder(OrderType(),OrderTicket());

            //-- Calc Min/Max/Extended by Action
            usExtended                      += OrderOpenPrice()*OrderLots();

            if (IsEqual(Master[action].Summary.Count,0))
            {
              Master[action].TicketMin[0]    = OrderTicket();
              Master[action].TicketMax[0]    = OrderTicket();

              usProfitMin                    = OrderProfit();
              usProfitMax                    = OrderProfit();
            }
            else
            {
              Master[action].TicketMin[0]    = BoolToInt(IsLower(OrderProfit(),usProfitMin),OrderTicket(),Master[action].TicketMin[0]);
              Master[action].TicketMax[0]    = BoolToInt(IsHigher(OrderProfit(),usProfitMax),OrderTicket(),Master[action].TicketMax[0]);
            }

            //-- Build and Agg Zone Summary By Action
            node                     = Zone(action,NodeIndex(action,OrderOpenPrice()));

            ArrayResize(node.Ticket,++node.Count,100);
            node.Lots                       += OrderLots();
            node.Value                      += OrderProfit();
            node.Ticket[node.Count-1]        = OrderTicket();

            SetNode(action,node);

            //-- Agg By Action
            ArrayResize(Master[action].Summary.Ticket,++Master[action].Summary.Count,100);
            Master[action].Summary.Lots     += OrderLots();
            Master[action].Summary.Value    += OrderProfit();
            Master[action].Summary.Ticket[Master[action].Summary.Count-1] = OrderTicket();

            //-- Agg By P/L
            if (NormalizeDouble(OrderProfit(),2)<0.00)
            {
              ArrayResize(Summary[Loss].Ticket,++Summary[Loss].Count,100);
              Summary[Loss].Lots            += OrderLots();
              Summary[Loss].Value           += OrderProfit();
              Summary[Loss].Ticket[Summary[Loss].Count-1] = OrderTicket();
            }
            else
            {
              ArrayResize(Summary[Profit].Ticket,++Summary[Profit].Count,100);
              Summary[Profit].Lots          += OrderLots();
              Summary[Profit].Value         += OrderProfit();
              Summary[Profit].Ticket[Summary[Profit].Count-1] = OrderTicket();
            }
          }

      //-- Calc DCA
      CalcDCA(action,usExtended);
    }

    //-- Compute interim Net Values req'd by Equity/Margin calcs
    Summary[Net].Count               = Master[OP_BUY].Summary.Count-Master[OP_SELL].Summary.Count;
    Summary[Net].Lots                = Master[OP_BUY].Summary.Lots-Master[OP_SELL].Summary.Lots;
    Summary[Net].Value               = Master[OP_BUY].Summary.Value+Master[OP_SELL].Summary.Value;

    //-- Calc Action Aggregates
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      for (int index=0;index<ArraySize(Master[action].Zone);index++)
      {
        Master[action].Zone[index].Equity   = CalcMetric(Equity,Master[action].Zone[index].Value,InPercent);
        Master[action].Zone[index].Margin   = CalcMetric((OrderMetric)BoolToInt(IsEqual(action,OP_BUY),MarginLong,MarginShort),
                                                Master[action].Zone[index].Lots,InPercent)*fdiv(Master[action].Zone[index].Lots,Master[action].Summary.Lots,1);
      }

      Master[action].Summary.Equity  = CalcMetric(Equity,Master[action].Summary.Value,InPercent);
      Master[action].Summary.Margin  = CalcMetric((OrderMetric)BoolToInt(IsEqual(action,OP_BUY),MarginLong,MarginShort),Master[action].Summary.Lots,InPercent);
    }

    //-- Calc P/L Aggregates
    Summary[Profit].Equity           = CalcMetric(Equity,Summary[Profit].Value,InPercent);
    Summary[Profit].Margin           = CalcMetric(Margin,Summary[Profit].Lots,InPercent);

    Summary[Loss].Equity             = CalcMetric(Equity,Summary[Loss].Value,InPercent);
    Summary[Loss].Margin             = CalcMetric(Margin,Summary[Loss].Lots,InPercent);

    //-- Calc Net Aggregates
    Summary[Net].Equity              = CalcMetric(Equity,Summary[Net].Value,InPercent);
    Summary[Net].Margin              = CalcMetric(Margin,Summary[Net].Lots,InPercent);
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
//| Reconcile - Reconciles Order, Account/Equity changes             |
//+------------------------------------------------------------------+
void COrder::Reconcile(void)
  {
    //-- Recon/Equity Rebalance
  }

//+------------------------------------------------------------------+
//| MergeRequest - Merge EA-opened order requests into Master        |
//+------------------------------------------------------------------+
void COrder::MergeRequest(OrderRequest &Request, bool Split=false)
  {
    int detail;

    //-- Add New Tracked Order to Master
    detail                                            = ArraySize(Master[Request.Action].Order);
    ArrayResize(Master[Request.Action].Order,detail+1,1000);

    Master[Request.Action].Order[detail].Status       = Fulfilled;
    Master[Request.Action].Order[detail].Ticket       = Request.Ticket;
    Master[Request.Action].Order[detail].Key          = Request.Key;
    Master[Request.Action].Order[detail].Action       = Request.Action;
    Master[Request.Action].Order[detail].Price        = Request.Price;
    Master[Request.Action].Order[detail].Lots         = Request.Lots;
    Master[Request.Action].Order[detail].Profit       = OrderProfit();
    Master[Request.Action].Order[detail].Swap         = OrderSwap();
    Master[Request.Action].Order[detail].Split        = Split;
    Master[Request.Action].Order[detail].TakeProfit   = BoolToDouble(IsEqual(Request.TakeProfit,0.00),NoValue,Request.TakeProfit);
    Master[Request.Action].Order[detail].StopLoss     = BoolToDouble(IsEqual(Request.StopLoss,0.00),NoValue,Request.StopLoss);;
    Master[Request.Action].Order[detail].Memo         = Request.Memo;

    AppendLog(Request.Key,Request.Ticket,"Request["+(string)Request.Key+"]:Merged");

    if (OrderUpdated(Master[Request.Action].Order[detail]))
    {
      Request.TakeProfit       = Master[Request.Action].Order[detail].TakeProfit;
      Request.StopLoss         = Master[Request.Action].Order[detail].StopLoss;
    }
  }

//+------------------------------------------------------------------+
//| MergeOrder - Merge/Update new/existing orders into Master Detail |
//+------------------------------------------------------------------+
void COrder::MergeOrder(int Action, int Ticket)
  {
    int detail                 = NoValue;
    
    //-- Merge Existing (tracked) Order
    for (detail=0;detail<ArraySize(Master[Action].Order);detail++)
      if (IsEqual(Ticket,Master[Action].Order[detail].Ticket))
      {
        Master[Action].Order[detail].Profit   = OrderProfit();
        Master[Action].Order[detail].Swap     = OrderSwap();

        AppendLog(Master[Action].Order[detail].Key,Ticket,"[Order Updated]");
        return;
      }

    //-- Add New (untracked) Order
    detail                                    = ArraySize(Master[Action].Order);
    ArrayResize(Master[Action].Order,detail+1,1000);

    Master[Action].Order[detail].Status       = Fulfilled;
    Master[Action].Order[detail].Ticket       = Ticket;
    Master[Action].Order[detail].Key          = NoValue;
    Master[Action].Order[detail].Action       = Action;
    Master[Action].Order[detail].Price        = OrderOpenPrice();
    Master[Action].Order[detail].Lots         = OrderLots();
    Master[Action].Order[detail].Profit       = OrderProfit();
    Master[Action].Order[detail].Swap         = OrderSwap();
    Master[Action].Order[detail].Split        = OrderLots()<=fdiv(LotSize(Action),2);
    Master[Action].Order[detail].TakeProfit   = BoolToDouble(IsEqual(OrderTakeProfit(),0.00),NoValue,OrderTakeProfit());
    Master[Action].Order[detail].StopLoss     = BoolToDouble(IsEqual(OrderStopLoss(),0.00),NoValue,OrderStopLoss());
    Master[Action].Order[detail].Memo         = OrderComment();

    AppendLog(NoValue,Ticket,"[Order["+(string)Ticket+"]:Merged");
  }

//+------------------------------------------------------------------+
//| OrderUpdated - Modifies ticket values; Currently Stop/TP prices  |
//+------------------------------------------------------------------+
bool COrder::OrderUpdated(OrderDetail &Order)
  {
    string ouLogNote      = "";
    
    if (OrderSelect(Order.Ticket,SELECT_BY_TICKET,MODE_TRADES))
      if (Symbol()!=OrderSymbol())
      {
        Order.Memo                  = "Update error; Invalid Symbol ("+Symbol()+")";
        Order.Status                = Invalid;

        AppendLog(Order.Key,Order.Ticket,Order.Memo);

        return (false);
      }
      else
      {
        //--- Calculate StopLoss
        if (IsHigher(0.00,Order.StopLoss))
          if (IsHigher(Master[Order.Action].StopLoss,Order.StopLoss))
            Append(ouLogNote,"[Stop:"+DoubleToStr(Master[Order.Action].StopLoss,Digits)+"]","");
          else
          if (IsEqual(Master[Order.Action].DefaultStop,0.00))
            Append(ouLogNote,"[Stop:None]","");
          else
          {
            Order.StopLoss          = BoolToDouble(IsEqual(Order.Action,OP_BUY),Bid,Ask)-(point(Master[Order.Action].DefaultStop)*Direction(Order.Action,InAction));
            Append(ouLogNote,"[Stop:Default/"+DoubleToStr(Order.StopLoss,Digits)+"]","");
          }   
        else
          if (IsEqual(Order.StopLoss,0.00))
            Append(ouLogNote,"[Stop:None]","");
          else
            Append(ouLogNote,"[Stop:Force/"+DoubleToStr(Order.StopLoss,Digits)+"]","");

        //--- Calculate Targets
        if (IsHigher(0.00,Order.TakeProfit))
          if (IsHigher(Master[Order.Action].TakeProfit,Order.TakeProfit))
            Append(ouLogNote,"[TP:"+DoubleToStr(Master[Order.Action].TakeProfit,Digits)+"]","");
          else
          if (IsEqual(Master[Order.Action].DefaultTarget,0.00))
            Append(ouLogNote,"[TP:None]","");
          else
          {
            Order.TakeProfit        = BoolToDouble(IsEqual(Order.Action,OP_BUY),Bid,Ask)+(point(Master[Order.Action].DefaultTarget)*Direction(Order.Action,InAction));
            Append(ouLogNote,"[TP:Default/"+DoubleToStr(Order.TakeProfit,Digits)+"]","");
          }
        else
          if (IsEqual(Order.TakeProfit,0.00))
            Append(ouLogNote,"[TP:None]","");
          else
            Append(ouLogNote,"[TP:Force/"+DoubleToStr(Order.TakeProfit,Digits)+"]","");

        //--- Handle "Hides"
        if (Master[Order.Action].HideStop)
          Append(ouLogNote,"[Stop:Hide"+BoolToStr(IsEqual(Order.StopLoss,0.00),"","/"+DoubleToStr(Order.StopLoss,Digits))+"]","");

        if (Master[Order.Action].HideTarget)
          Append(ouLogNote,"[TP:Hide"+BoolToStr(IsEqual(Order.TakeProfit,0.00),"","/"+DoubleToStr(Order.TakeProfit,Digits))+"]","");

        //--- Return if unchanged
        if (IsEqual(BoolToDouble(Master[Order.Action].HideStop,0.00,Order.StopLoss),OrderStopLoss())&&
            IsEqual(BoolToDouble(Master[Order.Action].HideTarget,0.00,Order.TakeProfit),OrderTakeProfit()))
          return (true);

        //--- Update if changed
        if (OrderModify(Order.Ticket,0.00,BoolToDouble(Master[Order.Action].HideStop,0.00,Order.StopLoss,Digits),
                                          BoolToDouble(Master[Order.Action].HideTarget,0.00,Order.TakeProfit,Digits),0))
        {
          AppendLog(Order.Key,Order.Ticket,ouLogNote);
          return (true);
        }

        AppendLog(Order.Key,Order.Ticket,"Invalid Stop/TP;Error: "+DoubleToStr(GetLastError(),0));
      }
    else
      AppendLog(Order.Key,Order.Ticket,"Invalid Ticket Stop/TP;Error: "+DoubleToStr(GetLastError(),0));

    return (false);
  }

//+------------------------------------------------------------------+
//| OrderApproved - Performs health/sanity checks for order approval |
//+------------------------------------------------------------------+
bool COrder::OrderApproved(OrderRequest &Request)
  {
    if (Account.TradeEnabled)
    {
      if (!Master[Request.Action].TradeEnabled)
        Request.Memo                = "Action ["+ActionText(Request.Action)+"] not enabled";
      else
      if (IsEqual(Request.Status,Pending)||IsEqual(Request.Status,Immediate))
        if (IsLower(CalcMetric(Margin,Master[Request.Action].Summary.Lots+LotSize(Request.Action,Request.Lots),InPercent),
                                      Master[Request.Action].MaxMargin,NoUpdate))
        {
          //-- if zone limits met
             Request.Status         = Approved;
             return (true);
          //-- else
          // Request.Memo                  = "Zone maximum exceeded";
        }
        else
          Request.Memo              = "Margin limit "+DoubleToStr(CalcMetric(Margin,Master[Request.Action].Summary.Lots+
                                                                 LotSize(Request.Action,Request.Lots),InPercent),1)+"% exceeded";
          //-- Offer counter proposal? Return state 'Modify' and approve on'Accept'
      else
        Request.Memo                = "Request not pending ["+EnumToString(Request.Status)+"]";
    }
    else
      Request.Memo                  = "Trade disabled; system halted";

    Request.Status                  = Declined;

    AppendLog(Request.Key,NoValue,Request.Memo);

    return (false);
  }

//+------------------------------------------------------------------+
//| OrderOpened - Executes orders from the order queue               |
//+------------------------------------------------------------------+
bool COrder::OrderOpened(OrderRequest &Request)
  {
    if (!Master[Request.Action].TradeEnabled)
    {
      Request.Status         = Declined;
      Request.Memo           = "Action ["+ActionText(Request.Action)+"] not enabled";
      
      AppendLog(Request.Key,NoValue,Request.Memo);

      return (false);
    }

    if (!Account.TradeEnabled)
    {
      Request.Memo           = "Trade disabled; system halted";
      Request.Status         = Declined;
      AppendLog(Request.Key,NoValue,Request.Memo);

      return (false);
    }

    Request.Lots             = LotSize(Request.Action,Request.Lots);
    Request.Ticket           = OrderSend(Symbol(),
                                 Request.Action,
                                 Request.Lots,
                                 BoolToDouble(IsEqual(Request.Action,OP_BUY),Ask,Bid,Digits),
                                 Account.MaxSlippage*10,
                                 0.00,
                                 0.00,
                                 Request.Memo);

    if (Request.Ticket>0)
    {
      AppendLog(Request.Key,Request.Ticket,"Request["+(string)Request.Key+"]:Fulfilled");

      if (OrderSelect(Request.Ticket,SELECT_BY_TICKET,MODE_TRADES))
      {
        Request.Action       = OrderType();
        Request.Price        = OrderOpenPrice();
        Request.Lots         = OrderLots();

        MergeRequest(Request);
        
        return (true);        
      }
      else
        AppendLog(Request.Key,Request.Ticket,"Request ["+(string)Request.Key+"]:Order not found");
    }
    
    AppendLog(Request.Key,NoValue,"Request ["+(string)Request.Key+"]:Error ["+DoubleToStr(GetLastError(),0)+"]"+
          ActionText(Request.Action)+" open failed @"+DoubleToStr(Request.Price,Digits)+"("+DoubleToStr(Request.Lots,2)+") "+Request.Memo);

    return (false);
  }

//+------------------------------------------------------------------+
//| OrderClosed - Closes the number of supplied Lots of an Order     |
//+------------------------------------------------------------------+
bool COrder::OrderClosed(OrderDetail &Order, double Lots=0.00)
  {
    int error                   = NoValue;
    
    RefreshRates();

    if (OrderClose(Order.Ticket,
                     BoolToDouble(IsEqual(Lots,0.00),fmin(LotSize(Order.Action,Lots),Order.Lots),fmin(Lots,Order.Lots),Account.LotPrecision),
                     BoolToDouble(IsEqual(Order.Action,OP_BUY),Bid,Ask,Digits),
                     Account.MaxSlippage*20,Red))
    {
      Order.Status              = Closed;
      return (true);          
    }
    else

      switch (IsChanged(error,GetLastError()))
      {
        case 129:   Order.Memo  = "Invalid Price(129): "+DoubleToStr(BoolToDouble(IsEqual(Order.Action,OP_BUY),Bid,Ask,Digits));
                    break;
        case 138:   Order.Memo  = "Requote(138): "+DoubleToStr(BoolToDouble(IsEqual(Order.Action,OP_BUY),Bid,Ask,Digits));
                    break;
        default:    Order.Memo  = "Unknown Error("+(string)error+"): "+DoubleToStr(BoolToDouble(IsEqual(Order.Action,OP_BUY),Bid,Ask,Digits));
      }


    AppendLog(Order.Key,Order.Ticket,Order.Memo);

    return (false);
  }

//+------------------------------------------------------------------+
//| ProcessOrders - Process orders in the Order Request Queue        |
//+------------------------------------------------------------------+
void COrder::ProcessOrders(void)
  {
    for (int request=0;request<ArraySize(Queue);request++)
    {
      if (IsEqual(Queue[request].Status,Fulfilled))
      {
        Queue[request].Status           = Completed;
        Queue[request].Expiry           = TimeCurrent()+(Period()*60);
      }

      if (IsEqual(Queue[request].Status,Completed))
        if (OrderSelect(Queue[request].Ticket,SELECT_BY_TICKET,MODE_HISTORY))
          if (OrderCloseTime()>0)
            Queue[request].Status       = Closed;

      if (IsEqual(Queue[request].Status,Pending))
        if (IsBetween(Close[0],BoolToDouble(IsEqual(Queue[request].Pend.Limit,0.00),Close[0],Queue[request].Pend.Limit),
                               BoolToDouble(IsEqual(Queue[request].Pend.Cancel,0.00),Close[0],Queue[request].Pend.Cancel)))
        {
          switch(Queue[request].Type)
          {
            case OP_BUY:        Queue[request].Status  = Immediate;
                                break;
            case OP_BUYSTOP:    Queue[request].Status  = (QueueStatus)BoolToInt(Ask>=Queue[request].Price,Immediate,Pending);
                                break;
            case OP_BUYLIMIT:   Queue[request].Status  = (QueueStatus)BoolToInt(Ask<=Queue[request].Price,Immediate,Pending);
                                break;
            case OP_SELL:       Queue[request].Status  = Immediate;
                                break;
            case OP_SELLSTOP:   Queue[request].Status  = (QueueStatus)BoolToInt(Bid<=Queue[request].Price,Immediate,Pending);
                                break;
            case OP_SELLLIMIT:  Queue[request].Status  = (QueueStatus)BoolToInt(Bid>=Queue[request].Price,Immediate,Pending);
                                break;
          }
          
          //-- Expire Pending Orders
          if (IsBetween(Queue[request].Pend.Type,OP_BUYLIMIT,OP_SELLSTOP))
            if (TimeCurrent()>Queue[request].Expiry)
              Cancel(Queue[request],Expired,"Request expired");
        }
        else Cancel(Queue[request],Expired,"Cancel/Limit price exceeded");
      
      if (IsEqual(Queue[request].Status,Immediate))
        if (OrderApproved(Queue[request]))
          if (OrderOpened(Queue[request]))
          {
            Queue[request].Status        = Fulfilled;

            UpdateAccount();
            UpdateSummary();

            //-- Resubmit Queued Pending Orders
            if (IsBetween(Queue[request].Pend.Type,OP_BUYLIMIT,OP_SELLSTOP))
            {
              Queue[request].Type        = Queue[request].Pend.Type;

              Submit(Queue[request],Queue[request].Price+
                 (BoolToDouble(IsEqual(Master[Queue[request].Action].State,FFE),Account.Spread,
                  BoolToDouble(IsEqual(Queue[request].Pend.Step,0.00),point(Master[Queue[request].Action].Step),point(Queue[request].Pend.Step)))
                    *Direction(Queue[request].Action,InAction,IsEqual(Queue[request].Action,OP_BUYLIMIT)||IsEqual(Queue[request].Action,OP_SELLLIMIT))));
            }
          }
    }
  }

//+------------------------------------------------------------------+
//| ProcessClosures - Closes orders based on closure strategy        |
//+------------------------------------------------------------------+
void COrder::ProcessClosures(int &Batch[], bool Conditional=true)
  {
    for (int ticket=0;ticket<ArraySize(Batch);ticket++)
      if (Conditional)
      {
        //-- Close based on Master Config conditions
      }
      else
      {
        if (OrderClosed(Ticket(Batch[ticket])))
        {
          UpdateAccount();
          UpdateSummary();

          Reconcile();
        }
      }
  }

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
COrder::COrder(BrokerModel Model, int MaxSlippage, bool EnableTrade)
  {
     //-- Initialize Account
     Account.MarginModel    = Model;
     Account.TradeEnabled   = EnableTrade;
     Account.MaxSlippage    = MaxSlippage;

     Account.LotSizeMin     = NormalizeDouble(MarketInfo(Symbol(),MODE_MINLOT),2);
     Account.LotSizeMax     = NormalizeDouble(MarketInfo(Symbol(),MODE_MAXLOT),2);
     Account.LotPrecision   = BoolToInt(IsEqual(Account.LotSizeMin,0.01),2,1);

     UpdateAccount();
     InitMasterConfig();
     
     NewLine("czDCA:0");
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
    PurgeLog();
    
    UpdateAccount();
    UpdateSummary();

    Reconcile();
  }

//+------------------------------------------------------------------+
//| LotSize - returns optimal lot size                               |
//+------------------------------------------------------------------+
double COrder::LotSize(int Action, double Lots=0.00)
  {
    if (IsEqual(Master[Action].DefaultLotSize,0.00,Account.LotPrecision))
    {
      if(NormalizeDouble(Lots,Account.LotPrecision)>0.00)
        if (NormalizeDouble(Lots,Account.LotPrecision)<=Account.LotSizeMin)
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
//| Cancel - Cancels pending orders by Type                          |
//+------------------------------------------------------------------+
void COrder::Cancel(int Type, string Reason="")
  {
    if (IsBetween(Type,OP_BUYLIMIT,OP_SELLSTOP)||IsEqual(Type,OP_NO_ACTION))
      for (int request=0;request<ArraySize(Queue);request++)
        if (IsEqual(Queue[request].Status,Pending))
          if (IsEqual(Queue[request].Type,Type)||IsEqual(Type,OP_NO_ACTION))
          {
            Queue[request].Status   = Canceled;
            Queue[request].Expiry   = TimeCurrent()+(Period()*60);
            Queue[request].Memo     = BoolToStr(IsEqual(StringLen(Reason),0),Queue[request].Memo,Reason);
          }
  }

//+------------------------------------------------------------------+
//| Cancel - Cancels pending limit order Request                     |
//+------------------------------------------------------------------+
void COrder::Cancel(OrderRequest &Request, QueueStatus Status, string Reason="")
  {
    Request.Status           = Status;
    Request.Expiry           = TimeCurrent()+(Period()*60);
    Request.Memo             = BoolToStr(IsEqual(StringLen(Reason),0),Request.Memo,Reason);
  }

//+------------------------------------------------------------------+
//| Fulfilled - True if Order Fulfilled by Action on current tick    |
//+------------------------------------------------------------------+
bool COrder::Fulfilled(int Action=OP_NO_ACTION)
  {
    for (int request=0;request<ArraySize(Queue);request++)
      if (IsEqual(Queue[request].Status,Fulfilled))
        return(IsEqual(Action,OP_NO_ACTION)||IsEqual(Action,Queue[request].Action));

    return (false);
  }

//+------------------------------------------------------------------+
//| Submit - Adds screened orders to the Order Processing Queue      |
//+------------------------------------------------------------------+
bool COrder::Submit(OrderRequest &Request, double Price=0.00)
  {
    static int key                    = 0;
    int        request                = ArraySize(Queue);
    
    ArrayResize(Queue,request+1,1000);

    Queue[request]                    = Request;
    Queue[request].Key                = ++key;
    Queue[request].Status             = Pending;
    Queue[request].Action             = Operation(Queue[request].Type);

    //-- Screening checks before submitting for approval
    if (IsBetween(Queue[request].Action,OP_BUY,OP_SELL))
    {
      Queue[request].Ticket           = 0;
      Queue[request].Requestor        = BoolToStr(StringLen(Queue[request].Requestor)==0,"No Requestor",Queue[request].Requestor);
      Queue[request].Lots             = BoolToDouble(IsEqual(Queue[request].Lots,0.00),Queue[request].Lots,LotSize(Queue[request].Action));
      Queue[request].TakeProfit       = fmax(Queue[request].TakeProfit,0.00);
      Queue[request].StopLoss         = fmax(Queue[request].StopLoss,0.00);      
      
      //-- Market Orders
      if (IsEqual(Queue[request].Type,Queue[request].Action))
      {
        Queue[request].Price          = 0.00;
        Queue[request].Hide           = false;
        Queue[request].Expiry         = TimeCurrent()+(Period()*60);
      }
      else
      
      //-- Pending Orders
      {
        Queue[request].Price          = BoolToDouble(IsEqual(Price,0.00),Queue[request].Price,Price,Digits);

        if (IsEqual(Queue[request].Price,0.00)||IsHigher(0.00,Queue[request].Price,NoUpdate))
        {
          Append(Queue[request].Memo,"Invalid stop/limit price",";");
          AppendLog(Queue[request].Key,Queue[request].Ticket,Queue[request].Memo);
        }
      }        
    }
    else
    {
      Append(Queue[request].Memo,"Invalid order type",";");
      AppendLog(Queue[request].Key,Queue[request].Ticket,Queue[request].Memo);
    }

    if (IsEqual(Queue[request].Status,Pending))
      if (OrderApproved(Queue[request]))
        return (IsChanged(Queue[request].Status,Pending));

    Queue[request].Status             = Rejected;
    Queue[request].Expiry             = TimeCurrent()+(Period()*60);

    return (false);
  }

//+------------------------------------------------------------------+
//| BlankRequest - Returns a blank Request                           |
//+------------------------------------------------------------------+
OrderRequest COrder::BlankRequest(void)
  {
    OrderRequest Request;
    
    Request.Status           = NoStatus;
    Request.Key              = NoValue;
    Request.Ticket           = NoValue;
    Request.Type             = OP_NO_ACTION;
    Request.Action           = OP_NO_ACTION;
    Request.Requestor        = "";
    Request.Price            = 0.00;
    Request.Lots             = 0.00;
    Request.TakeProfit       = 0.00;
    Request.StopLoss         = 0.00;
    Request.Hide             = false;
    Request.Memo             = "";
    Request.Expiry           = TimeCurrent()+(Period()*60);
    Request.Pend.Type        = OP_NO_ACTION;
    Request.Pend.Limit       = 0.00;
    Request.Pend.Cancel      = 0.00;
    Request.Pend.Step        = 0.00;

    return (Request);
  }

//+------------------------------------------------------------------+
//| Ticket - Returns Order Record by Ticket                          |
//+------------------------------------------------------------------+
OrderDetail COrder::Ticket(int Ticket)
  {
    OrderDetail search;
    
    for (int detail=0;detail<fmax(ArraySize(Master[OP_BUY].Order),ArraySize(Master[OP_SELL].Order));detail++)
    {
      if (detail<ArraySize(Master[OP_BUY].Order))
        if (IsEqual(Master[OP_BUY].Order[detail].Ticket,Ticket))
          return (Master[OP_BUY].Order[detail]);

      if (detail<ArraySize(Master[OP_SELL].Order))
        if (IsEqual(Master[OP_SELL].Order[detail].Ticket,Ticket))
          return (Master[OP_SELL].Order[detail]);
    }

    search.Ticket            = Ticket;
    search.Status            = Rejected;
    search.Memo              = "Ticket not found: "+IntegerToString(Ticket,10,'0');

    return (search);
  }

//+------------------------------------------------------------------+
//| Request - Returns Order Request from Queue by Key/Ticket         |
//+------------------------------------------------------------------+
OrderRequest COrder::Request(int Key, int Ticket=NoValue)
  {
    OrderRequest search      = BlankRequest();

    for (int request=0;request<ArraySize(Queue);request++)
      if (IsEqual(Key,Queue[request].Key)||IsEqual(Ticket,Queue[request].Ticket))
        return (Queue[request]);

    search.Status            = Invalid;
    search.Requestor         = "Search Request";
    search.Memo              = "Request not found: "+IntegerToString(Key,10,'0');

    return (search);
  }

//+------------------------------------------------------------------+
//| Zone - Returns Zone Summary Node by Index                        |
//+------------------------------------------------------------------+
OrderSummary COrder::Zone(int Action, int Index)
  {
    OrderSummary Node;
    
    for (int node=0;node<ArraySize(Master[Action].Zone);node++)
      if (IsEqual(Master[Action].Zone[node].Index,Index))
        return (Master[Action].Zone[node]);

    InitSummaryLine(Node,Index);
    
    return(Node);
  }

//+------------------------------------------------------------------+
//| NodeIndex - Returns Node by Price                                |
//+------------------------------------------------------------------+
int COrder::NodeIndex(int Action, double Price)
  {
    switch(Action)
    {
      case OP_BUY:   return((int)ceil(fdiv(Close[0]-Price,point(Master[Action].Step),Digits+1)));
      case OP_SELL:  return((int)ceil(fdiv(Price,point(Master[Action].Step)-Close[0],Digits+1)));
    }
    
    return (0);
  }

//+------------------------------------------------------------------+
//| SetNode - Applies Node changes to the Master Zone                |
//+------------------------------------------------------------------+
void COrder::SetNode(int Action, OrderSummary &Node)
  {
    int   node;
    
    for (node=0;node<ArraySize(Master[Action].Zone);node++)
      if (IsEqual(Master[Action].Zone[node].Index,Node.Index))
        break;

    if (IsEqual(node,ArraySize(Master[Action].Zone)))
      ArrayResize(Master[Action].Zone,node+1,100);

    Master[Action].Zone[node].Index   = Node.Index;
    Master[Action].Zone[node].Count   = Node.Count;
    Master[Action].Zone[node].Lots    = Node.Lots;
    Master[Action].Zone[node].Value   = Node.Value;
    Master[Action].Zone[node].Margin  = Node.Margin;
    Master[Action].Zone[node].Equity  = Node.Equity;
        
    ArrayCopy(Master[Action].Zone[node].Ticket,Node.Ticket);
  }

//+------------------------------------------------------------------+
//| SetTradeState - Enables trading and configures order management  |
//+------------------------------------------------------------------+
void COrder::SetTradeState(int Action, TradeState State)
  {
     Master[Action].State            = State;
  }

//+------------------------------------------------------------------+
//| SetStopLoss - Sets order stops and hide restrictions             |
//+------------------------------------------------------------------+
void COrder::SetStopLoss(int Action, double StopLoss, double DefaultStop, bool HideStop)
  {
    Master[Action].StopLoss          = StopLoss;
    Master[Action].HideStop          = HideStop;
    Master[Action].DefaultStop       = DefaultStop;

    for (int detail=0;detail<ArraySize(Master[Action].Order);detail++)
    {
      Master[Action].Order[detail].StopLoss   = NoValue;

      if (!OrderUpdated(Master[Action].Order[detail]))
        Pause(Master[Action].Order[detail].Memo,"SetStop() error",MB_ICONERROR);
    }
  }

//+------------------------------------------------------------------+
//| SetTakeProfit - Sets order targets and hide restrictions         |
//+------------------------------------------------------------------+
void COrder::SetTakeProfit(int Action, double TakeProfit, double DefaultTarget, bool HideTarget)
  {    
    Master[Action].TakeProfit        = TakeProfit;
    Master[Action].HideTarget        = HideTarget;
    Master[Action].DefaultTarget     = DefaultTarget;

    for (int detail=0;detail<ArraySize(Master[Action].Order);detail++)
    {
      Master[Action].Order[detail].TakeProfit = NoValue;

      if (!OrderUpdated(Master[Action].Order[detail]))
        Pause(Master[Action].Order[detail].Memo,"SetTarget() error",MB_ICONERROR);
    }
  }

//+------------------------------------------------------------------+
//| SetEquityTargets - Configures profit/equity management options   |
//+------------------------------------------------------------------+
void COrder::SetEquityTargets(int Action, double EquityTarget, double MinEquity, bool SplitLots, bool ProfitHold)
  {
     Master[Action].EquityTarget     = EquityTarget;
     Master[Action].MinEquity        = MinEquity;
     Master[Action].SplitLots        = SplitLots;
     Master[Action].ProfitHold       = ProfitHold;
  }

//+------------------------------------------------------------------+
//| SetRiskLimits - Configures risk mitigation management options    |
//+------------------------------------------------------------------+
void COrder::SetRiskLimits(int Action, double MaxRisk, double MaxMargin, double LotScale)
  {
     Master[Action].MaxRisk          = MaxRisk;
     Master[Action].MaxMargin        = MaxMargin;
     Master[Action].LotScale         = LotScale;
  }

//+------------------------------------------------------------------+
//| SetDefaults - Sets default order management overrides            |
//+------------------------------------------------------------------+
void COrder::SetDefaults(int Action, double DefaultLotSize, double DefaultStop, double DefaultTarget)
  {
     Master[Action].DefaultLotSize   = DefaultLotSize;
     Master[Action].DefaultStop      = DefaultStop;
     Master[Action].DefaultTarget    = DefaultTarget;
  }

//+------------------------------------------------------------------+
//| SetZoneStep - Sets distrbution step for aggregation zones        |
//+------------------------------------------------------------------+
void COrder::SetZoneStep(int Action, double Step)
  {
     Master[Action].Step             = Step;
  }

//+------------------------------------------------------------------+
//| PrintLog                                                         |
//+------------------------------------------------------------------+
void COrder::PrintLog(LogType Type)
  {
    string osText       = "\n";

    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      Append(osText,"==== Open "+ActionText(action)+" Orders ["+(string)Master[action].Summary.Count+"]","\n\n");

      for (int detail=0;detail<ArraySize(Master[action].Order);detail++)
      {
        Append(osText,OrderDetailStr(Master[action].Order[detail]),"\n");

        for (int line=0;line<ArraySize(Log);line++)
          if (IsEqual(Log[line].Ticket,Master[action].Order[detail].Ticket))
            Append(osText,Log[line].Note,";");
      }
    }

    Print (osText);
  }

//+------------------------------------------------------------------+
//| OrderDetailStr - Returns formatted Order text                    |
//+------------------------------------------------------------------+
string COrder::OrderDetailStr(OrderDetail &Order)
  {
    string odsText      = "";

    Append(odsText,"Status: "+EnumToString(Order.Status));
    Append(odsText,"Ticket: "+BoolToStr(IsEqual(Master[Order.Action].Summary.Count,1),"[*]",
                              BoolToStr(IsEqual(Order.Ticket,Master[Order.Action].TicketMax[0]),"[+]",
                              BoolToStr(IsEqual(Order.Ticket,Master[Order.Action].TicketMin[0]),"[-]","[ ]")))
                             +IntegerToString(Order.Ticket,10,'0'));
    Append(odsText,ActionText(Order.Action));
    Append(odsText,"Open Price: "+DoubleToStr(Order.Price,Digits));
    Append(odsText,"Lots: "+DoubleToStr(Order.Lots,Account.LotPrecision));
    Append(odsText,"Profit: "+DoubleToStr(Order.Profit,2));
    Append(odsText,"Swap: "+DoubleToStr(Order.Swap,2));
    Append(odsText,"TP: "+DoubleToStr(Order.TakeProfit,Digits));
    Append(odsText,"Stop: "+DoubleToStr(Order.StopLoss,Digits));
    Append(odsText,BoolToStr(Order.Split,"Split"));
    Append(odsText,Order.Memo);

    return (odsText);
  }

//+------------------------------------------------------------------+
//| OrderStr - Returns formatted text for all open orders            |
//+------------------------------------------------------------------+
string COrder::OrderStr(int Action=OP_NO_ACTION)
  {
    string osText       = "\n";

    for (int action=OP_BUY;action<=OP_SELL;action++)
      if (IsEqual(Action,OP_NO_ACTION)||IsEqual(action,Action))
      {
        Append(osText,"==== Open "+ActionText(action)+" Orders ["+(string)Master[action].Summary.Count+"]","\n\n");

        for (int detail=0;detail<ArraySize(Master[action].Order);detail++)
          if (!IsEqual(Master[action].Order[detail].Status,Closed))
            Append(osText,OrderDetailStr(Master[action].Order[detail]),"\n");
      }

    return (osText);
  }

//+------------------------------------------------------------------+
//| RequestStr - Returns formatted Request text                      |
//+------------------------------------------------------------------+
string COrder::RequestStr(OrderRequest &Request)
  {
    string rsText      = "";

    Append(rsText,"Key: "+IntegerToString(Request.Key,10,'0'));
    Append(rsText,"Ticket: "+IntegerToString(Request.Ticket,10,'0'));
    Append(rsText,ActionText(Request.Type)+BoolToStr(IsEqual(Request.Type,Request.Action),"","["+ActionText(Request.Action)+"]"));
    Append(rsText,EnumToString(Request.Status));
    Append(rsText,Request.Requestor);
    Append(rsText,"Price: "+BoolToStr(IsEqual(Request.Price,0.00),"Market",DoubleToStr(Request.Price,Digits)));
    Append(rsText,"Lots: "+DoubleToStr(Request.Lots,Account.LotPrecision));
    Append(rsText,"TP: "+DoubleToStr(Request.TakeProfit,Digits));
    Append(rsText,"Stop: "+DoubleToStr(Request.StopLoss,Digits));
    Append(rsText,"Expiry: "+TimeToStr(Request.Expiry));

    if (IsBetween(Request.Pend.Type,OP_BUYLIMIT,OP_SELLSTOP))
    {
      Append(rsText,"[Resubmit/"+ActionText(Request.Pend.Type)+"]");
      Append(rsText,"Limit: "+DoubleToStr(Request.Pend.Limit,Digits));
      Append(rsText,"Cancel: "+DoubleToStr(Request.Pend.Cancel,Digits));
      Append(rsText,"Step: "+DoubleToStr(Request.Pend.Step,Digits)+"]");
    }
    
    Append(rsText,Request.Memo);

    return (rsText);
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
      Append(qsAction[Queue[oq].Action],RequestStr(Queue[oq]),"\n");
    }

    for (int action=OP_BUY;action<6;action++)
    {
      qsAction[action]      = ActionText(action)+" Queue ["+(string)qsCount[action]+"]\n"+qsAction[action]+"\n";

      if (IsEqual(Action,OP_NO_ACTION))
        if (qsCount[action]>0||Force)
          Append(qsText,qsAction[action],"\n");

      if (IsEqual(Action,action))
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
      Append(slsText,"Orders["+IntegerToString(Line.Count,3)+"]");
      Append(slsText,"Lots:"+DoubleToStr(Line.Lots,Account.LotPrecision));
      Append(slsText,"Value:$ "+DoubleToStr(Line.Value,2));
      Append(slsText,"Margin:"+DoubleToStr(Line.Margin,1)+"%");
      Append(slsText,"Equity:"+DoubleToStr(Line.Equity,1)+"%");

      if (ArraySize(Line.Ticket)>0)
        for (int ticket=0;ticket<ArraySize(Line.Ticket);ticket++)
          Append(slsTickets,(string)Line.Ticket[ticket],",");
      else
        if (InStr(Description,"Net"))
          for (int action=OP_BUY;action<=OP_SELL;action++)
            for (int ticket=0;ticket<ArraySize(Summary[action].Ticket);ticket++)
              Append(slsTickets,(string)Summary[action].Ticket[ticket],",");

        Append(slsText,BoolToStr(slsTickets=="","","Ticket(s): ["+slsTickets+"]"));
    }

    return (slsText);
  }

//+------------------------------------------------------------------+
//| MasterStr - Returns formatted Master[Action] text                |
//+------------------------------------------------------------------+
string COrder::MasterStr(int Action)
  {
    string msText  = "\n\nMaster Configuration ["+proper(ActionText(Action))+"]";

    Append(msText,"State:          "+EnumToString(Master[Action].State),"\n");
    Append(msText,"Trade:          "+BoolToStr(Master[Action].TradeEnabled,"Enabled","Disabled"),"\n");
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

    return (msText);
  }

//+------------------------------------------------------------------+
//| SummaryStr - Returns formatted Net Summary for all open trades   |
//+------------------------------------------------------------------+
string COrder::SummaryStr(void)
  {
    string ssText      = "\n";
    
    Append(ssText,"===== Master Summary Detail =====","\n");

    for (MeasureType measure=0;measure<Total;measure++)
      Append(ssText,SummaryLineStr(EnumToString(measure),Summary[measure],Always),"\n");

    return (ssText);
  }

//+------------------------------------------------------------------+
//| ZoneSummaryStr - Returns the formstted Zone Summary by Action    |
//+------------------------------------------------------------------+
string COrder::ZoneSummaryStr(int Action=OP_NO_ACTION)
  {
    string zssText     = "\n";
    
    for (int action=OP_BUY;action<=OP_SELL;action++)
      if (Master[action].Summary.Count>0)
        if (IsEqual(action,Action)||IsEqual(Action,OP_NO_ACTION))
        {
          Append(zssText,"===== "+proper(ActionText(action))+" Master Zone Detail =====","\n");

          for (int node=0;node<ArraySize(Master[action].Zone);node++)
            Append(zssText,SummaryLineStr("Zone["+IntegerToString(Master[action].Zone[node].Index,3)+"]",Master[action].Zone[node]),"\n");
        }

    return (zssText);
  }

//+------------------------------------------------------------------+
//| IsChanged - Compares events to determine if a change occurred    |
//+------------------------------------------------------------------+
bool IsChanged(QueueStatus &Compare, QueueStatus Value)
  {
    if (IsEqual(Compare,Value))
      return (false);

    Compare = Value;
    return (true);
  }
