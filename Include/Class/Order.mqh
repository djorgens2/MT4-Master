//+------------------------------------------------------------------+
//|                                                        Order.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.01"
#property strict

#include <stdutil.mqh>

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
  enum                OrderGroup
                      {
                        ByZone,
                        ByTicket,
                        ByAction,
                        ByProfit,
                        ByLoss,
                        ByMethod
                      };


  //-- Order Manager Operations/Methods
  enum                OrderMethod
                      {
                        Hold,          // Hold (unless max risk)
                        Full,          // Close whole orders
                        Split,         // Close half orders 
                        Retain,        // Close half orders and hold
                        DCA,           // Close profit on DCA
                        Recapture,     // Risk mitigation position (not coded)
                        Stop,          // Sets Hard Target (Take Profit even if negative)
                        Kill,          // Close on market
                        OrderMethods
                      };

  //--- Request Queue Statuses
  enum                QueueStatus
                      {
                        //-- Request Submit States
                        Initial,
                        Immediate,
                        Approved,
                        //-- Queue Processing States
                        Pending,
                        Canceled,
                        Declined,
                        Rejected,
                        Expired,
                        //-- Order Open States
                        Fulfilled,
                        Working,
                        Qualified,
                        Processing,
                        //-- Order Close States
                        Processed,
                        Closed,
                        Completed,
                        //-- Submit Error
                        Invalid,
                        QueueStates
                      };

  //--- Margin Calculation Method Types
  enum                MarginType
                      {
                        Margin,
                        MarginLong,
                        MarginShort
                      };
private:

  //--- Panel Indicator
  string              indSN;

  //--- Account Configuration, Derived Metrics, and Directives
  struct              AccountMetrics
                      {
                        bool            TradeEnabled;
                        BrokerModel     MarginModel;
                        int             MaxSlippage;
                        double          EquityOpen;
                        double          EquityClosed;
                        double          EquityVariance;
                        double          EquityBalance;
                        double          NetProfit[2];    //-- Net profit by Action
                        double          Balance;
                        double          Variance;
                        double          Spread;
                        double          Margin;
                        double          Equity;
                        double          LotMargin;
                        double          MarginHedged;
                        double          LotSize;
                        double          LotSizeMin;
                        double          LotSizeMax;
                        int             LotPrecision;
                        double          BaseCurrency;
                      };

  struct              OrderLog
                      {
                        int             Key;
                        int             Ticket;
                        string          Note;
                        datetime        Received;
                      };

  struct              QueueSnapshot
                      {
                        int             Count;                //-- Status by Order Type
                        double          Lots;                 //-- Lots by Order Type
                        double          Profit;               //-- Value by Order Type
                      };

  struct              QueueSummary
                      {
                        QueueSnapshot   Type[6];
                      };

  struct              OrderSlider
                      {
                        bool            Enabled;              //-- Slider On/Off
                        double          Price;                //-- Trigger Price
                        double          Step;                 //-- Slider Step
                      };

  struct              OrderResubmit
                      {
                        int             Type;                 //-- Order Type following fill
                        double          LBound;               //-- Cancel order on Lower Boundary
                        double          UBound;               //-- Cancel order on Upper Boundary
                        double          Step;                 //-- Resubmit Stop/Limit from last fill
                      };

  struct              OrderRequest
                      {
                        QueueStatus     Status;
                        int             Key;
                        int             Ticket;
                        int             Type;
                        int             Action;
                        double          Lots;
                        double          Price;
                        double          TakeProfit;
                        double          StopLoss;
                        string          Requestor;
                        string          Memo;
                        datetime        Expiry;
                        OrderResubmit   Pend;
                      };

  struct              OrderDetail
                      {
                        OrderMethod     Method;
                        QueueStatus     Status;
                        int             Key;
                        int             Ticket;
                        int             Action;
                        double          Price;
                        double          Lots;
                        double          Profit;
                        double          Swap;
                        double          TakeProfit;
                        double          StopLoss;
                        string          Memo;
                      };

  struct              OrderSummary
                      {
                        int            Zone;                  //-- Zone #
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
                        OrderMethod    Method;                //-- Order Processing Method by Action
                        //-- Profit Management
                        double         EquityTarget;          //-- Principal equity target
                        double         EquityMin;             //-- Minimum profit target
                        //-- Risk Management
                        double         LotScale;              //-- LotSize scaling factor in Margin
                        double         MaxRisk;               //-- Max Principle Risk
                        double         MaxMargin;             //-- Max Margin by Action
                        //-- Distribution Management
                        double         ZoneSize;              //-- Order Max Range Aggregation
                        double         ZoneMaxMargin;         //-- Max Margin by Action/Zone
                        //-- Defaults
                        double         DefaultLotSize;        //-- Lot Size Override (fixed, non-scaling)
                        double         DefaultStop;           //-- Default stop (in Pips)
                        double         DefaultTarget;         //-- Default target (in Pips)
                        //-- Order Management
                        double         StopLoss;              //-- Default stop loss price
                        double         TakeProfit;            //-- Defaault profit price target
                        bool           HideStop;              //-- Hide stops (controlled thru EA)
                        bool           HideTarget;            //-- Hide targets (controlled thru EA)
                        //-- Summarized Data & Arrays
                        int            TicketMax;             //-- Ticket w/Highest Profit
                        int            TicketMin;             //-- Ticket w/Least Profit
                        double         DCA;                   //-- Calculated live DCA
                        OrderDetail    Order[];               //-- Order details by ticket/action
                        OrderSummary   Zone[];                //-- Aggregate order detail by order zone
                        OrderSummary   EntryZone;             //-- Entry Zone Summary
                        OrderSummary   Summary[Total];        //-- Order Summary by Action
                      };

          //-- Data Collections
          OrderLog        Log[];
          OrderRequest    Queue[];
          OrderMaster     Master[2];
          OrderSlider     Slider[4];
          OrderSummary    Summary[Total];
          QueueSummary    Snapshot[QueueStates];
          AccountMetrics  Account;
          
          //-- Private Methods
          void         AppendLog(int Key, int Ticket,string Note);
          void         PurgeLog(int Retain=0);

          double       Calc(MarginType Metric, double Lots, int Format=InPercent);

          void         InitMaster(int Action, OrderMethod Method);
          void         InitSummary(OrderSummary &Line, int Node=NoValue);

          void         UpdatePanel(void);
          void         UpdateSnapshot(void);
          void         UpdateZone(int Action, OrderSummary &Zone);
          void         UpdateSummary(void);
          void         UpdateAccount(double BaseCurrency);
          void         UpdateMaster(void);
          void         UpdateOrder(OrderDetail &Order, QueueStatus Status);

          OrderRequest SubmitRequest(OrderRequest &Request, bool Resubmit=false);
          OrderDetail  MergeRequest(OrderRequest &Request);
          void         MergeOrder(int Action, int Ticket);
          void         MergeSplit(OrderDetail &Order);

          bool         OrderApproved(OrderRequest &Request);
          bool         OrderOpened(OrderRequest &Request);
          bool         OrderClosed(OrderDetail &Order);

          void         AdverseEquityHandler(void);

          bool         SliderTriggered(int Action);

          void         ProcessProfits(int Action);
          void         ProcessLosses(int Action);

public:

                       COrder(BrokerModel Model);
                      ~COrder();

          //-- Order Operational Control methods
          void         Update(double BaseCurrency=1.0);         //-- Update Order Statistics, Display, Manage Logs
          void         ProcessRequests(void);                   //-- Process pending orders in the Request Queue
          void         ProcessOrders(int Action);               //-- Manage open orders by Action Type
          void         ProcessHedge(string Requestor);          //-- Hedges on Market (Immediate)

          bool         Enabled(int Action);
          bool         Enabled(OrderRequest &Request);
          bool         Enabled(void)                            {return(Account.TradeEnabled);};
          bool         Disabled(int Action)                     {return(Master[Action].TradeEnabled);};

          void         Enable(string Message="")                {Account.TradeEnabled=true;ConsoleAlert(Message);};
          void         Disable(string Message="")               {Account.TradeEnabled=false;ConsoleAlert(Message);};
          void         Enable(int Action, string Message="")    {Master[Action].TradeEnabled=true;ConsoleAlert(Message);};
          void         Disable(int Action, string Message="")   {Master[Action].TradeEnabled=false;ConsoleAlert(Message);};

          void         ConsoleAlert(string Message, color Color=clrDarkGray) {UpdateLabel("lbvAC-SysMsg",Message,Color);};

          //-- Order properties
          double       Price(SummaryType Type, int Action, double Requested=0.00, double Basis=0.00, bool InPips=false);
          double       LotSize(int Action, double Lots=0.00, double Margin=0.00);

          //-- Margin Calcs
          double       Margin(int Format=InPercent)                          {return(Account.Margin*BoolToInt(IsEqual(Format,InPercent),100,1));};
          double       Margin(double Lots, int Format=InPercent)             {return(Calc(Margin,Lots,Format));};
          double       Margin(int Action, double Lots, int Format=InPercent) {return(Calc((MarginType)BoolToInt(IsEqual(Operation(Action),OP_BUY),MarginLong,MarginShort),Lots,Format));};
          double       Margin(int Type, QueueStatus Status, int Format=InPercent)
                                                                             {return(Calc((MarginType)BoolToInt(IsEqual(Operation(Type),OP_BUY),MarginLong,MarginShort),
                                                                                     Snapshot[Status].Type[Operation(Type)].Lots,Format));};
          double       Free(int Action, double Price, bool IncludePending=true);
          double       Split(int Action)                                     {return(fdiv(LotSize(Action),2,Account.LotPrecision));};
          double       Equity(double Value, int Format=InPercent);
          double       DCA(int Action)                                       {return(NormalizeDouble(Master[Action].DCA,Digits));};
          double       Spread(void)                                          {return(NormalizeDouble(Account.Spread,Digits));};

          //-- Request methods
          void         Cancel(int Type, string Reason="");
          void         Cancel(OrderRequest &Request, string Reason="");
          bool         Submitted(OrderRequest &Request);

          //-- Order States
          bool         Status(QueueStatus State, int Type=NoAction);
          bool         Pending(int Type=NoAction)            {return(Status(Pending,Type));};
          bool         Canceled(int Type=NoAction)           {return(Status(Canceled,Type));};
          bool         Declined(int Type=NoAction)           {return(Status(Declined,Type));};
          bool         Rejected(int Type=NoAction)           {return(Status(Rejected,Type));};
          bool         Expired(int Type=NoAction)            {return(Status(Expired,Type));};
          bool         Fulfilled(int Type=NoAction)          {return(Status(Fulfilled,Type));};
          bool         Qualified(int Type=NoAction)          {return(Status(Qualified,Type));};
          bool         Processing(int Type=NoAction)         {return(Status(Processing,Type));};
          bool         Processed(int Type=NoAction)          {return(Status(Processed,Type));};
          bool         Closed(int Type=NoAction)             {return(Status(Closed,Type));};
          
          bool         IsChanged(QueueStatus &Compare, QueueStatus Value);
          bool         IsEqual(QueueStatus &Compare, QueueStatus Value) {return Compare==Value;};

          //-- Order Property Fetch Methods
          OrderRequest   BlankRequest(string Requestor);
          OrderRequest   Request(int Key, int Ticket=NoValue);
          OrderDetail    Ticket(int Ticket);
          OrderSummary   Recap(int Action, SummaryType Type) {return(Master[Action].Summary[Type]);};
          OrderSummary   EntryZone(int Action)               {return(Master[Action].EntryZone);};
          OrderMaster    Config(int Action)                  {return Master[Action];};
          AccountMetrics Metrics(void)                       {return Account;};

          void         GetGroup(int Action, OrderGroup Group, int &Tickets[], int Key=NoValue);
          void         GetZone(int Action, int Zone, OrderSummary &Node);
          int          Zones(int Action) {return (ArraySize(Master[Action].Zone));};
          int          Zone(int Action, double Price=0.00);

          //-- Configuration methods
          void         SetSlider(int Action, double Step=0.00);
          void         SetDefaultStop(int Action, double Price, int Pips, bool Hide);
          void         SetDefaultTarget(int Action, double Price, int Pips, bool Hide);

          void         SetStopLoss(int Action, OrderGroup Group, double StopLoss, int Key=NoValue);
          void         SetTakeProfit(int Action, OrderGroup Group, double TakeProfit, int Key=NoValue, bool HardStop=false);
          void         SetMethod(int Action, OrderMethod Method, OrderGroup Group, int Key=NoValue);

          void         ConfigureFund(int Action, double EquityTarget, double EquityMin, OrderMethod=Hold);
          void         ConfigureRisk(int Action, double Risk, double Margin, double Scale, double LotSize);
          void         ConfigureZone(int Action, double Size, double Margin);

          //-- Formatted Output Text
          void         PrintLog(void);
          void         PrintLog(int History);

          string       OrderDetailStr(OrderDetail &Order);
          string       OrderStr(int Action=NoAction);
          string       RequestStr(OrderRequest &Request);
          string       QueueStr(int Action=NoAction, bool Force=false);
          string       SummaryLineStr(string Description, OrderSummary &Line, bool Force=false);
          string       SummaryStr(void);
          string       ZoneSummaryStr(int Action=NoAction);
          string       SnapshotStr(void);
          string       MasterStr(int Action);

          OrderSummary  operator[](const SummaryType Type)    const {return(Summary[Type]);};
          OrderSummary  operator[](const int Action)          const {return(Master[Action].Summary[Net]);};
          QueueSummary  operator[](const QueueStatus Status)  const {return(Snapshot[Status]);};
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
//| Calc - Returns derived order Metric for the Value supplied       |
//+------------------------------------------------------------------+
double COrder::Calc(MarginType Metric, double Lots, int Format=InPercent)
  {
    switch (Metric)
    {
      case MarginLong:     if (IsEqual(Account.MarginModel,Discount)) //-- Shared burden on trunk; majority burden on excess Long variance
                             return (Calc(Margin,fmax(0.00,Lots-Master[OP_SELL].Summary[Net].Lots)+
                               (fmin(Lots,Master[OP_SELL].Summary[Net].Lots)*Account.MarginHedged),Format));
                           return (Calc(Margin,Master[OP_BUY].Summary[Net].Lots,Format));

      case MarginShort:    if (IsEqual(Account.MarginModel,Discount)) //-- Shared burden on trunk; majority burden on excess Short variance
                             return (Calc(Margin,fmax(0.00,Lots-Master[OP_BUY].Summary[Net].Lots)+
                               (fmin(Lots,Master[OP_BUY].Summary[Net].Lots)*Account.MarginHedged),Format));
                           return (Calc(Margin,Master[OP_SELL].Summary[Net].Lots,Format));

      case Margin:         switch (Format)
                           {
                             case InDecimal: return (NormalizeDouble(fdiv(Lots,Account.LotSizeMin)*fdiv(Account.LotMargin,Account.EquityBalance),3));
                             case InPercent: return (NormalizeDouble(fdiv(Lots,Account.LotSizeMin)*fdiv(Account.LotMargin,Account.EquityBalance)*100,1));
                             case InDollar:  return (NormalizeDouble(Lots*Account.LotMargin,2));
                           }
    };

    return (0.00);
  }

//+------------------------------------------------------------------+
//| InitMaster - Sets the trading options for all Actions on Open    |
//+------------------------------------------------------------------+
void COrder::InitMaster(int Action, OrderMethod Method)
  {
    Master[Action].Method          = Method;
    Master[Action].TradeEnabled    = true;
    Master[Action].EquityTarget    = 0.00;
    Master[Action].EquityMin       = 0.00;
    Master[Action].LotScale        = 0.00;
    Master[Action].MaxRisk         = 0.00;
    Master[Action].MaxMargin       = 0.00;
    Master[Action].ZoneSize        = 0.00;
    Master[Action].ZoneMaxMargin   = 0.00;      
    Master[Action].DefaultLotSize  = 0.00;
    Master[Action].DefaultStop     = 0.00;
    Master[Action].DefaultTarget   = 0.00;
    Master[Action].StopLoss        = 0.00;
    Master[Action].TakeProfit      = 0.00;
    Master[Action].HideStop        = false;
    Master[Action].HideTarget      = false;
  }

//+------------------------------------------------------------------+
//| InitSummary - Zeroes an Order Summary Record                     |
//+------------------------------------------------------------------+
void COrder::InitSummary(OrderSummary &Line, int Zone=NoValue)
  {
    Line.Zone                      = Zone;
    Line.Count                     = 0;
    Line.Lots                      = 0.00;
    Line.Value                     = 0.00;
    Line.Margin                    = 0.00;
    Line.Equity                    = 0.00;

    ArrayResize(Line.Ticket,0,100);
  }

//+------------------------------------------------------------------+
//| UpdatePanel - Updates control panel display                      |
//+------------------------------------------------------------------+
void COrder::UpdatePanel(void)
  {
    if (ChartWindowFind(0,indSN)>NoValue)
    {
      //-- Account Information frame
      UpdateLabel("lbvAI-Bal",lpad(DoubleToStr(Account.Balance,0)," ",11),Color(Summary[Net].Equity),16,"Consolas");
      UpdateLabel("lbvAI-Eq",lpad(lpad(Account.Equity,0)," ",11),Color(Summary[Net].Equity),16,"Consolas");
      UpdateLabel("lbvAI-EqBal",lpad(DoubleToStr(Account.EquityBalance,0)," ",11),Color(Summary[Net].Equity),16,"Consolas");

      UpdateLabel("lbvAI-Eq%",center(DoubleToStr(Account.EquityClosed*100,1)+"%",7),Color(Summary[Net].Equity),16);
      UpdateLabel("lbvAI-EqOpen%",center(DoubleToStr(Account.EquityOpen*100,1)+"%",6),Color(Summary[Net].Equity),12);
      UpdateLabel("lbvAI-EqVar%",center(DoubleToStr(Account.EquityVariance*100,1)+"%",6),Color(Summary[Net].Equity),12);
      UpdateLabel("lbvAI-Spread",lpad(DoubleToStr(pip(Account.Spread),1)," ",5),Color(Summary[Net].Equity),14);
      UpdateLabel("lbvAI-Margin",lpad(DoubleToStr(Account.Margin*100,1)+"%"," ",6),Color(Summary[Net].Equity),14);

      UpdateDirection("lbvAI-OrderBias",Direction(Summary[Net].Lots),Color(Summary[Net].Lots),30);            

      //-- Account Configuration
      UpdateLabel("lbvAC-Trading",BoolToStr(Account.TradeEnabled,"Enabled","Halted"),Color(BoolToInt(Account.TradeEnabled,1,NoValue)));
      UpdateLabel("lbvAC-Options","");

      for (int action=0;action<=2;action++)
        if (action<=OP_SELL)
        {
          UpdateLabel("lbvAI-"+proper(ActionText(action))+"#",IntegerToString(Master[action].Summary[Net].Count,2),clrDarkGray,10,"Consolas");
          UpdateLabel("lbvAI-"+proper(ActionText(action))+"L",lpad(DoubleToStr(Master[action].Summary[Net].Lots,2)," ",6),clrDarkGray,10,"Consolas");
          UpdateLabel("lbvAI-"+proper(ActionText(action))+"V",lpad(DoubleToStr(Master[action].Summary[Net].Value,0)," ",10),clrDarkGray,10,"Consolas");
          UpdateLabel("lbvAI-"+proper(ActionText(action))+"M",lpad(DoubleToStr(Master[action].Summary[Net].Margin,1)," ",5),clrDarkGray,10,"Consolas");
          UpdateLabel("lbvAI-"+proper(ActionText(action))+"E",lpad(DoubleToStr(Master[action].Summary[Net].Equity,1)," ",5),clrDarkGray,10,"Consolas");
        }
        else
        {
          UpdateLabel("lbvAI-Net#",IntegerToString(Summary[Net].Count,2),clrDarkGray,10,"Consolas");
          UpdateLabel("lbvAI-NetL",lpad(DoubleToStr(Summary[Net].Lots,2)," ",6),clrDarkGray,10,"Consolas");
          UpdateLabel("lbvAI-NetV",lpad(DoubleToStr(Summary[Net].Value,0)," ",10),clrDarkGray,10,"Consolas");
          UpdateLabel("lbvAI-NetM",lpad(DoubleToStr(Summary[Net].Margin,1)," ",5),clrDarkGray,10,"Consolas");
          UpdateLabel("lbvAI-NetE",lpad(DoubleToStr(Summary[Net].Equity,1)," ",5),clrDarkGray,10,"Consolas");
        }

      //-- Order Config by Action frames
      for (int action=OP_BUY;action<=OP_SELL;action++)
      {
        UpdateLabel("lbvOC-"+ActionText(action)+"-Enabled",BoolToStr(Master[action].TradeEnabled,"Enabled "+EnumToString(Master[action].Method),"Disabled"),
                                                    BoolToInt(Master[action].TradeEnabled,clrLawnGreen,clrDarkGray));
        UpdateLabel("lbvOC-"+ActionText(action)+"-EqTarget",center(DoubleToStr(Master[action].EquityTarget,1)+"%",7),clrDarkGray,10);
        UpdateLabel("lbvOC-"+ActionText(action)+"-EqMin",center(DoubleToStr(Master[action].EquityMin,1)+"%",6),clrDarkGray,10);
        UpdateLabel("lbvOC-"+ActionText(action)+"-Target",center(DoubleToStr(Price(Profit,action),Digits),9),clrDarkGray,10);
        UpdateLabel("lbvOC-"+ActionText(action)+"-DfltTarget","Default "+DoubleToStr(Master[action].TakeProfit,Digits)+" ("+DoubleToStr(Master[action].DefaultTarget,1)+"p)",
                                                    Color(Master[action].TakeProfit+Master[action].DefaultTarget,IN_CHART_DIR),8);
        UpdateLabel("lbvOC-"+ActionText(action)+"-MaxRisk",center(DoubleToStr(Master[action].MaxRisk,1)+"%",6),clrDarkGray,10);
        UpdateLabel("lbvOC-"+ActionText(action)+"-MaxMargin",center(DoubleToStr(Master[action].MaxMargin,1)+"%",6),clrDarkGray,10);
        UpdateLabel("lbvOC-"+ActionText(action)+"-Stop",center(DoubleToStr(Price(Loss,action),Digits),9),clrDarkGray,10);
        UpdateLabel("lbvOC-"+ActionText(action)+"-DfltStop","Default "+DoubleToStr(Master[action].StopLoss,Digits)+" ("+DoubleToStr(Master[action].DefaultStop,1)+"p)",
                                                    Color(Master[action].TakeProfit+Master[action].DefaultTarget,IN_CHART_DIR),8);
        UpdateLabel("lbvOC-"+ActionText(action)+"-EQBase",DoubleToStr(Account.NetProfit[action],0)+" ("+DoubleToStr(fdiv(Account.NetProfit[action],Account.Balance)*100,1)+"%)",clrDarkGray,10);
        UpdateLabel("lbvOC-"+ActionText(action)+"-DCA",DoubleToStr(Master[action].DCA,Digits),clrDarkGray,10);
        UpdateLabel("lbvOC-"+ActionText(action)+"-LotSize",center(DoubleToStr(LotSize(action),Account.LotPrecision),7),clrDarkGray,10);
        UpdateLabel("lbvOC-"+ActionText(action)+"-MinLotSize",center(DoubleToStr(Account.LotSizeMin,Account.LotPrecision),6),clrDarkGray,10);
        UpdateLabel("lbvOC-"+ActionText(action)+"-MaxLotSize",center(DoubleToStr(Account.LotSizeMax,Account.LotPrecision),7),clrDarkGray,10);
        UpdateLabel("lbvOC-"+ActionText(action)+"-DfltLotSize",BoolToStr(IsEqual(Master[action].DefaultLotSize,0.00),
                                                   "Scaled "+DoubleToStr(Master[action].LotScale,1)+"%",
                                                   "Default "+DoubleToStr(Master[action].DefaultLotSize,Account.LotPrecision)),clrDarkGray,8);
        UpdateLabel("lbvOC-"+ActionText(action)+"-ZoneSize",center(DoubleToStr(Master[action].ZoneSize,1),6),clrDarkGray,10);
        UpdateLabel("lbvOC-"+ActionText(action)+"-ZoneMaxMargin",center(DoubleToStr(Master[action].ZoneMaxMargin,1)+"%",5),clrDarkGray,10);
        UpdateLabel("lbvOC-"+ActionText(action)+"-ZoneNow",center((string)Zone(action),8),clrDarkGray,10);
        UpdateLabel("lbvOC-"+ActionText(action)+"-EntryZone",center("Entry "+DoubleToStr(Free(action),Account.LotPrecision),10),
                                                    BoolToInt(IsEqual(EntryZone(action).Lots,0.00),clrLawnGreen,
                                                    BoolToInt(IsEqual(EntryZone(action).Lots,LotSize(action)),clrGoldenrod,
                                                    BoolToInt(EntryZone(action).Lots<fdiv(EntryZone(action).Lots,2),clrYellow,clrRed))));
      }
    
      //-- Order Zone metrics by Action
      for (int action=OP_BUY;action<=OP_SELL;action++)
      {
        int node          = 0;
        int row           = 0;
        int ticket        = 0;

        UpdateLabel("lbvOQ-"+ActionText(action)+"-ShowTP",
          CharToStr((uchar)BoolToInt(Master[action].HideTarget,251,252)),BoolToInt(Master[action].HideTarget,clrRed,clrLawnGreen),12,"Wingdings");

        UpdateLabel("lbvOQ-"+ActionText(action)+"-ShowSL",
          CharToStr((uchar)BoolToInt(Master[action].HideStop,251,252)),BoolToInt(Master[action].HideStop,clrRed,clrLawnGreen),12,"Wingdings");

        while (row<11)
        {
          if (node<ArraySize(Master[action].Zone)&&IsEqual(ticket,0))
          {
            int nodecolor = BoolToInt(IsEqual(Master[action].Zone[node].Zone,Zone(action)),clrYellow,clrDarkGray);
          
            UpdateLabel("lbvOZ-"+ActionText(action)+(string)row+"Z",IntegerToString(Master[action].Zone[node].Zone,3),nodecolor,9,"Consolas");
            UpdateLabel("lbvOZ-"+ActionText(action)+(string)row+"#",IntegerToString(Master[action].Zone[node].Count,2),nodecolor,9,"Consolas");
            UpdateLabel("lbvOZ-"+ActionText(action)+(string)row+"L",center(DoubleToString(Master[action].Zone[node].Lots,Account.LotPrecision),7),nodecolor,9,"Consolas");
            UpdateLabel("lbvOZ-"+ActionText(action)+(string)row+"V",dollar(Master[action].Zone[node].Value,14),nodecolor,9,"Consolas");
            UpdateLabel("lbvOZ-"+ActionText(action)+(string)row+"M",DoubleToString(Master[action].Zone[node].Margin,1),nodecolor,9,"Consolas");
            UpdateLabel("lbvOZ-"+ActionText(action)+(string)row+"E",lpad(Master[action].Zone[node].Equity,1),nodecolor,9,"Consolas");
          }
          else
          {
            UpdateLabel("lbvOZ-"+ActionText(action)+(string)row+"Z","");
            UpdateLabel("lbvOZ-"+ActionText(action)+(string)row+"#","");
            UpdateLabel("lbvOZ-"+ActionText(action)+(string)row+"L","");
            UpdateLabel("lbvOZ-"+ActionText(action)+(string)row+"V","");
            UpdateLabel("lbvOZ-"+ActionText(action)+(string)row+"M","");
            UpdateLabel("lbvOZ-"+ActionText(action)+(string)row+"E","");
          }
        
          if (node<ArraySize(Master[action].Zone)&&ticket<ArraySize(Master[action].Zone[node].Ticket))
          {
            OrderDetail detail = Ticket(Master[action].Zone[node].Ticket[ticket]);
          
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-Ticket",IntegerToString(detail.Ticket,10,'-'),clrDarkGray,9,"Consolas");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-State",BoolToStr(IsEqual(detail.Status,Working),EnumToString(detail.Method),EnumToString(detail.Status)),
                                                                         BoolToInt(IsEqual(detail.Method,Hold),clrWhite,clrDarkGray),9,"Consolas");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-Price",DoubleToStr(detail.Price,Digits),clrDarkGray,9,"Consolas");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-Lots",DoubleToStr(detail.Lots,Account.LotPrecision),clrDarkGray,9,"Consolas");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-TP",DoubleToStr(detail.TakeProfit,Digits),clrDarkGray,9,"Consolas");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-SL",DoubleToStr(detail.StopLoss,Digits),clrDarkGray,9,"Consolas");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-Profit",dollar(detail.Profit,11,false),clrDarkGray,9,"Consolas");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-Swap",dollar(detail.Swap,8,false),clrDarkGray,9,"Consolas");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-Net",dollar(detail.Profit+detail.Swap,11,false),clrDarkGray,9,"Consolas");

            if (IsEqual(++ticket,ArraySize(Master[action].Zone[node].Ticket)))
            {
              ticket   = 0;
              node++;
            }
          }
          else
          {
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-Ticket","");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-State","");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-Price","");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-Lots","");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-TP","");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-SL","");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-Profit","");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-Swap","");
            UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-Net","");

            ticket      = 0;
          }

          row++;
        }
      }

      //-- Col 2: Request Queue
      for (int request=0;request<12;request++)
        if (request<ArraySize(Queue))
        {
          UpdateLabel("lbvRQ-"+(string)request+"-Key",IntegerToString(BoolToInt(IsEqual(Queue[request].Status,Fulfilled),
                      Queue[request].Ticket,Queue[request].Key),8,'-'),BoolToInt(IsEqual(Queue[request].Status,Fulfilled),clrYellow,clrDarkGray),8,"Consolas");

          UpdateLabel("lbvRQ-"+(string)request+"-Status",EnumToString(Queue[request].Status),
                      BoolToInt(IsEqual(Queue[request].Status,Fulfilled),clrWhite,BoolToInt(IsEqual(Queue[request].Status,Pending),clrYellow,clrRed)));

          UpdateLabel("lbvRQ-"+(string)request+"-Requestor",Queue[request].Requestor,clrDarkGray);
          UpdateLabel("lbvRQ-"+(string)request+"-Type",proper(ActionText(Queue[request].Type))+BoolToStr(IsBetween(Queue[request].Type,OP_BUY,OP_SELL)," (m)"),clrDarkGray);
          UpdateLabel("lbvRQ-"+(string)request+"-Price",DoubleToStr(Queue[request].Price,Digits),clrDarkGray);

          if (IsEqual(Queue[request].Status,Pending))
          {
            UpdateLabel("lbvRQ-"+(string)request+"-Lots",DoubleToStr(LotSize(Queue[request].Action,Queue[request].Lots),Account.LotPrecision),
                      BoolToInt(IsEqual(Queue[request].Lots,0.00,Digits),clrYellow,clrDarkGray));
            UpdateLabel("lbvRQ-"+(string)request+"-Target",DoubleToStr(Price(Profit,Queue[request].Type,Queue[request].TakeProfit,Queue[request].Price),Digits),
                      BoolToInt(IsEqual(Queue[request].TakeProfit,0.00,Digits),clrYellow,clrDarkGray));
            UpdateLabel("lbvRQ-"+(string)request+"-Stop",DoubleToStr(Price(Loss,Queue[request].Type,Queue[request].StopLoss,Queue[request].Price),Digits),
                      BoolToInt(IsEqual(Queue[request].StopLoss,0.00,Digits),clrYellow,clrDarkGray));
          }
          else
          {
            UpdateLabel("lbvRQ-"+(string)request+"-Lots",DoubleToStr(LotSize(Queue[request].Action,Queue[request].Lots),Account.LotPrecision),clrDarkGray);
            UpdateLabel("lbvRQ-"+(string)request+"-Target",DoubleToStr(Queue[request].TakeProfit,Digits),clrDarkGray);
            UpdateLabel("lbvRQ-"+(string)request+"-Stop",DoubleToStr(Queue[request].StopLoss,Digits),clrDarkGray);
          }
        
          UpdateLabel("lbvRQ-"+(string)request+"-Expiry",TimeToStr(Queue[request].Expiry),clrDarkGray);
          UpdateLabel("lbvRQ-"+(string)request+"-LBound",DoubleToStr(Queue[request].Pend.LBound,Digits),clrDarkGray);
          UpdateLabel("lbvRQ-"+(string)request+"-UBound",DoubleToStr(Queue[request].Pend.UBound,Digits),clrDarkGray);
          UpdateLabel("lbvRQ-"+(string)request+"-Resubmit",proper(ActionText(Queue[request].Pend.Type)),clrDarkGray);
        
          if (IsBetween(Queue[request].Pend.Type,OP_BUY,OP_SELLSTOP))
            UpdateLabel("lbvRQ-"+(string)request+"-Step",
                        lpad(BoolToDouble(IsEqual(Queue[request].Pend.Step,0.00),Master[Operation(Queue[request].Pend.Type)].ZoneSize,Queue[request].Pend.Step),1,4),
                        BoolToInt(IsEqual(Queue[request].Pend.Step,0.00),clrYellow,clrDarkGray));
          else
            UpdateLabel("lbvRQ-"+(string)request+"-Step"," ----",clrDarkGray);
                     
          UpdateLabel("lbvRQ-"+(string)request+"-Memo",Queue[request].Memo,clrDarkGray);
        }
        else
        {
          UpdateLabel("lbvRQ-"+(string)request+"-Key","");
          UpdateLabel("lbvRQ-"+(string)request+"-Status","");
          UpdateLabel("lbvRQ-"+(string)request+"-Requestor","");
          UpdateLabel("lbvRQ-"+(string)request+"-Type","");
          UpdateLabel("lbvRQ-"+(string)request+"-Price","");
          UpdateLabel("lbvRQ-"+(string)request+"-Lots","");
          UpdateLabel("lbvRQ-"+(string)request+"-Target","");
          UpdateLabel("lbvRQ-"+(string)request+"-Stop","");
          UpdateLabel("lbvRQ-"+(string)request+"-Expiry","");
          UpdateLabel("lbvRQ-"+(string)request+"-LBound","");
          UpdateLabel("lbvRQ-"+(string)request+"-UBound","");
          UpdateLabel("lbvRQ-"+(string)request+"-Resubmit","");
          UpdateLabel("lbvRQ-"+(string)request+"-Step","");
          UpdateLabel("lbvRQ-"+(string)request+"-Memo","");
        }
    }
  }

//+------------------------------------------------------------------+
//| UpdateSnapshot - Update Request/Order snapshots                  |
//+------------------------------------------------------------------+
void COrder::UpdateSnapshot(void)
  {
    for (int type=OP_BUY;type<=OP_SELLSTOP;type++)
    {
      for (QueueStatus status=Initial;status<QueueStates;status++)
      {
        Snapshot[status].Type[type].Count         = 0;
        Snapshot[status].Type[type].Lots          = 0.00;
        Snapshot[status].Type[type].Profit        = 0.00;
      }

      if (IsBetween(type,OP_BUY,OP_SELL))
        for (int detail=0;detail<ArraySize(Master[type].Order);detail++)
        {
          Snapshot[Master[type].Order[detail].Status].Type[type].Count++;
          Snapshot[Master[type].Order[detail].Status].Type[type].Lots      += Master[type].Order[detail].Lots;
          Snapshot[Master[type].Order[detail].Status].Type[type].Profit    += Master[type].Order[detail].Profit;
        }
      else
        for (int request=0;request<ArraySize(Queue);request++)
          if (IsEqual(Queue[request].Type,NoAction))
            Snapshot[Invalid].Type[type].Count++;
          else
          {
            if (IsBetween(Queue[request].Status,Pending,Expired))
              if (IsEqual(Queue[request].Type,type))
              {
                Snapshot[Queue[request].Status].Type[Operation(type)].Count++;
                Snapshot[Queue[request].Status].Type[Operation(type)].Lots     += LotSize(Queue[request].Action,Queue[request].Lots);
              }

            if (IsEqual(Queue[request].Type,type))
            {
              Snapshot[Queue[request].Status].Type[type].Count++;
              Snapshot[Queue[request].Status].Type[type].Lots      += LotSize(Queue[request].Action,Snapshot[Queue[request].Status].Type[type].Lots);
            }
          }
    }
  }

//+------------------------------------------------------------------+
//| UpdateZone - Applies Node changes to the Master Zone             |
//+------------------------------------------------------------------+
void COrder::UpdateZone(int Action, OrderSummary &Zone)
  {
    int   node;

    for (node=0;node<ArraySize(Master[Action].Zone);node++)
      if (IsEqual(Master[Action].Zone[node].Zone,Zone.Zone))
        break;

    if (IsEqual(node,ArraySize(Master[Action].Zone)))
    {
      ArrayResize(Master[Action].Zone,node+1,100);

      while (node>0)
      {
        if (Zone.Zone<Master[Action].Zone[node-1].Zone)
          break;
        else
        {
          InitSummary(Master[Action].Zone[node]);
          Master[Action].Zone[node]      = Master[Action].Zone[node-1];
        }

        node--;
      }
    }

    InitSummary(Master[Action].Zone[node]);
    Master[Action].Zone[node]            = Zone;
  }

//+------------------------------------------------------------------+
//| UpdateSummary - Updates Order summaries                          |
//+------------------------------------------------------------------+
void COrder::UpdateSummary(void)
  {
    OrderSummary zone;

    double usProfitMin                   = 0.00;
    double usProfitMax                   = 0.00;
    double usHighBound[2]                = {0.00,0.00};
    double usLowBound[2]                 = {0.00,0.00};

    //-- Initialize Summaries
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      usHighBound[action]                = BoolToDouble(IsEqual(action,OP_BUY),Ask,Bid)+(point(Master[action].ZoneSize*0.9,8));
      usLowBound[action]                 = BoolToDouble(IsEqual(action,OP_BUY),Ask,Bid)-(point(Master[action].ZoneSize*0.9,8));

      Master[action].TicketMin           = NoValue;
      Master[action].TicketMax           = NoValue;

      for (SummaryType type=0;type<Total;type++)
      {
        InitSummary(Summary[type]);
        InitSummary(Master[action].Summary[type]);
      }

      InitSummary(Master[action].EntryZone,Zone(action,BoolToDouble(IsEqual(action,OP_BUY),Ask,Bid,Digits)));
      ArrayResize(Master[action].Zone,0,100);
    }

    //-- Order preliminary aggregation
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      for (int detail=0;detail<ArraySize(Master[action].Order);detail++)
        if (!IsEqual(Master[action].Order[detail].Status,Closed))
        {
          //-- Calc Min/Max by Action
          if (IsEqual(Master[action].Summary[Net].Count,0))
          {
            Master[action].TicketMin               = Master[action].Order[detail].Ticket;
            Master[action].TicketMax               = Master[action].Order[detail].Ticket;

            usProfitMin                            = Master[action].Order[detail].Profit;
            usProfitMax                            = Master[action].Order[detail].Profit;
          }
          else
          {
            Master[action].TicketMin               = BoolToInt(IsLower(Master[action].Order[detail].Profit,usProfitMin),
                                                       Master[action].Order[detail].Ticket,Master[action].TicketMin);
            Master[action].TicketMax               = BoolToInt(IsHigher(Master[action].Order[detail].Profit,usProfitMax),
                                                       Master[action].Order[detail].Ticket,Master[action].TicketMax);
          }

          //-- Agg By Action
          ArrayResize(Master[action].Summary[Net].Ticket,++Master[action].Summary[Net].Count,100);
          Master[action].Summary[Net].Lots        += Master[action].Order[detail].Lots;
          Master[action].Summary[Net].Value       += Master[action].Order[detail].Profit;
          Master[action].Summary[Net].Ticket[Master[action].Summary[Net].Count-1] = Master[action].Order[detail].Ticket;

          //-- Agg By P/L
          if (NormalizeDouble(Master[action].Order[detail].Profit,2)<0.00)
          {
            ArrayResize(Summary[Loss].Ticket,++Summary[Loss].Count,100);
            Summary[Loss].Lots                    += Master[action].Order[detail].Lots;
            Summary[Loss].Value                   += Master[action].Order[detail].Profit;
            Summary[Loss].Ticket[Summary[Loss].Count-1] = Master[action].Order[detail].Ticket;

            ArrayResize(Master[action].Summary[Loss].Ticket,++Master[action].Summary[Loss].Count,100);
            Master[action].Summary[Loss].Lots     += Master[action].Order[detail].Lots;
            Master[action].Summary[Loss].Value    += Master[action].Order[detail].Profit;
            Master[action].Summary[Loss].Ticket[Master[action].Summary[Loss].Count-1] = Master[action].Order[detail].Ticket;
          }
          else
          {
            ArrayResize(Summary[Profit].Ticket,++Summary[Profit].Count,100);
            Summary[Profit].Lots                  += Master[action].Order[detail].Lots;
            Summary[Profit].Value                 += Master[action].Order[detail].Profit;
            Summary[Profit].Ticket[Summary[Profit].Count-1] = Master[action].Order[detail].Ticket;

            ArrayResize(Master[action].Summary[Profit].Ticket,++Master[action].Summary[Profit].Count,100);
            Master[action].Summary[Profit].Lots   += Master[action].Order[detail].Lots;
            Master[action].Summary[Profit].Value  += Master[action].Order[detail].Profit;
            Master[action].Summary[Profit].Ticket[Master[action].Summary[Profit].Count-1] = Master[action].Order[detail].Ticket;
          }

          //-- Build Zone Summary Nodes By Action
          GetZone(action,Zone(action,Master[action].Order[detail].Price),zone);

          ArrayResize(zone.Ticket,++zone.Count,100);
          zone.Lots                               += Master[action].Order[detail].Lots;
          zone.Value                              += Master[action].Order[detail].Profit;
          zone.Ticket[zone.Count-1]                = Master[action].Order[detail].Ticket;

          UpdateZone(action,zone);

          //-- Build Entry Zone Summary by Action/Proximity
          if (IsBetween(Master[action].Order[detail].Price,usHighBound[action],usLowBound[action],Digits))
          {
            ArrayResize(Master[action].EntryZone.Ticket,++Master[action].EntryZone.Count,100);
            Master[action].EntryZone.Lots         += Master[action].Order[detail].Lots;
            Master[action].EntryZone.Value        += Master[action].Order[detail].Profit;
            Master[action].EntryZone.Ticket[Master[action].EntryZone.Count-1] = Master[action].Order[detail].Ticket;
          }          
        }
    }
    
    //-- Compute interim Net Values req'd by Equity/Margin calcs
    Summary[Net].Count                             = Master[OP_BUY].Summary[Net].Count-Master[OP_SELL].Summary[Net].Count;
    Summary[Net].Lots                              = Master[OP_BUY].Summary[Net].Lots-Master[OP_SELL].Summary[Net].Lots;
    Summary[Net].Value                             = Master[OP_BUY].Summary[Net].Value+Master[OP_SELL].Summary[Net].Value;

    //-- Calc Action Aggregates
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      for (SummaryType type=0;type<Total;type++)
      {
        Master[action].Summary[type].Equity     = Equity(Master[action].Summary[type].Value,InPercent);
        Master[action].Summary[type].Margin     = Margin(action,Master[action].Summary[type].Lots,InPercent);
      }

      for (int node=0;node<ArraySize(Master[action].Zone);node++)
      {
        Master[action].Zone[node].Equity           = Equity(Master[action].Zone[node].Value,InPercent);
        Master[action].Zone[node].Margin           = fdiv(Master[action].Zone[node].Lots,Master[action].Summary[Net].Lots)*Master[action].Summary[Net].Margin;
      }

      Master[action].EntryZone.Equity                  = Equity(Master[action].EntryZone.Value,InPercent);
      Master[action].EntryZone.Margin                  = fdiv(Master[action].EntryZone.Lots,Master[action].Summary[Net].Lots)*Master[action].Summary[Net].Margin;
    }

    //-- Calc P/L Aggregates
    for (SummaryType type=0;type<Total;type++)
    {
      Summary[type].Equity                      = Equity(Summary[type].Value,InPercent);
      Summary[type].Margin                      = BoolToDouble(IsEqual(type,Net),Margin(InPercent));
    }
  }

//+------------------------------------------------------------------+
//| UpdateAccount - Updates high usage account metrics               |
//+------------------------------------------------------------------+
void COrder::UpdateAccount(double BaseCurrency)
  {
    Account.Variance                = Account.Balance-(AccountBalance()+AccountCredit());
    Account.Balance                 = AccountBalance()+AccountCredit();
    Account.EquityOpen              = NormalizeDouble((AccountEquity()-(AccountBalance()+AccountCredit()))/AccountEquity(),3);
    Account.EquityClosed            = NormalizeDouble((AccountEquity()-(AccountBalance()+AccountCredit()))/(AccountBalance()+AccountCredit()),3);
    Account.EquityVariance          = NormalizeDouble(Account.EquityOpen-Account.EquityClosed,3);
    Account.EquityBalance           = NormalizeDouble(AccountEquity(),2);
    Account.Equity                  = NormalizeDouble(Account.EquityBalance-Account.Balance,2);
    Account.Spread                  = NormalizeDouble(Ask-Bid,Digits);
    Account.Margin                  = NormalizeDouble(AccountMargin()/AccountEquity(),3);
    Account.LotSize                 = MarketInfo(Symbol(),MODE_LOTSIZE);
    Account.BaseCurrency            = BaseCurrency;
    Account.LotMargin               = NormalizeDouble(fdiv((BoolToDouble(Symbol()=="USDJPY",MarketInfo(Symbol(),MODE_LOTSIZE)*MarketInfo(Symbol(),MODE_MINLOT),
                                        (MarketInfo(Symbol(),MODE_LOTSIZE)*MarketInfo(Symbol(),MODE_MINLOT)*Close[0]))/AccountLeverage()),Account.BaseCurrency),2);
    Account.MarginHedged            = fdiv(fdiv(MarketInfo(Symbol(),MODE_MARGINHEDGED),MarketInfo(Symbol(),MODE_LOTSIZE)),Account.BaseCurrency,2);
  }

//+------------------------------------------------------------------+
//| UpdateMaster - Maintains the order master                        |
//+------------------------------------------------------------------+
void COrder::UpdateMaster(void)
  {
    OrderDetail updated[];
    
    double extended;
    double lots;
    
    //-- Merge Untracked/Update Tracked
    for (int position=0;position<OrdersTotal();position++)
      if (OrderSelect(position,SELECT_BY_POS,MODE_TRADES))
        if (Symbol()==OrderSymbol())
          MergeOrder(OrderType(),OrderTicket());

    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      ArrayResize(updated,0,1000);
      
      extended                                     = 0.00;
      lots                                         = 0.00;
      
      for (int ticket=0;ticket<ArraySize(Master[action].Order);ticket++)
      {
        if (IsEqual(Master[action].Order[ticket].Status,Closed))
          Master[action].Order[ticket].Status      = Completed;
        else
        if (OrderSelect(Master[action].Order[ticket].Ticket,SELECT_BY_TICKET,MODE_HISTORY))
           if (OrderCloseTime()>0)
           {
             Master[action].Order[ticket].Status   = Closed;
             Account.NetProfit[action]            += OrderProfit()+OrderSwap();
           }
           else
           {
             extended                             += OrderLots()*OrderOpenPrice();
             lots                                 += OrderLots();
           }
         
        if (!IsEqual(Master[action].Order[ticket].Status,Completed))
        {
          ArrayResize(updated,ArraySize(updated)+1);      
          updated[ArraySize(updated)-1]            = Master[action].Order[ticket];
        }
      }

      Master[action].DCA                           = BoolToDouble(IsEqual(lots,0.00),BoolToDouble(IsEqual(action,OP_BUY),Bid,Ask),fdiv(extended,lots),Digits);
      
      ArrayResize(Master[action].Order,ArraySize(updated),1000);

      for (int update=0;update<ArraySize(updated);update++)
        Master[action].Order[update]               = updated[update];
    }
  }

//+------------------------------------------------------------------+
//| UpdateOrder - Modifies ticket values; Currently Stop/TP prices   |
//+------------------------------------------------------------------+
void COrder::UpdateOrder(OrderDetail &Order, QueueStatus Status)
  {
    if (IsBetween(Order.Action,OP_BUY,OP_SELL))
      if (OrderSelect(Order.Ticket,SELECT_BY_TICKET,MODE_HISTORY))
        if (IsEqual(OrderCloseTime(),0))
        {
          Order.Status    = Status;
          
          if (IsEqual(BoolToDouble(Master[Order.Action].HideStop,0.00,Order.StopLoss),OrderStopLoss())&&
              IsEqual(BoolToDouble(Master[Order.Action].HideTarget,0.00,Order.TakeProfit),OrderTakeProfit()))
          {
            //-- No Change
          }
          else
          {
            Order.Memo    = "[Stop"+BoolToStr(Master[Order.Action].HideStop,"/Hide")+":"+BoolToStr(IsEqual(Order.StopLoss,0.00),"None",DoubleToStr(Order.StopLoss,Digits))+"]";
            Order.Memo   += "[TP"+BoolToStr(Master[Order.Action].HideTarget,"/Hide")+":"+BoolToStr(IsEqual(Order.TakeProfit,0.00),"None",DoubleToStr(Order.TakeProfit,Digits))+"]";

            //--- Update if changed
            if (OrderModify(Order.Ticket,
                            0.00,
                            BoolToDouble(Master[Order.Action].HideStop,0.00,Order.StopLoss,Digits),
                            BoolToDouble(Master[Order.Action].HideTarget,0.00,Order.TakeProfit,Digits),
                            0))
              Order.Memo  = "Modified:"+Order.Memo;
            else
              Order.Memo  = "Invalid Stop/TP("+DoubleToStr(GetLastError(),0)+"):"+Order.Memo;
          }
        }

    AppendLog(Order.Key,Order.Ticket,Order.Memo);
  }

//+------------------------------------------------------------------+
//| SubmitRequest - Adds screened orders to Request Queue            |
//+------------------------------------------------------------------+
OrderRequest COrder::SubmitRequest(OrderRequest &Request, bool Resubmit=false)
  {
    static int key                    = 0;
    int        request                = ArraySize(Queue);
    
    ArrayResize(Queue,request+1,1000);

    Queue[request]                    = Request;
    Queue[request].Key                = ++key;
    Queue[request].Ticket             = NoValue;
    Queue[request].Status             = Rejected;
    
    //-- Handle Resubmits
    if (Resubmit)
      if (IsBetween(Operation(Request.Pend.Type),OP_BUY,OP_SELL))
      {
        Queue[request].Type           = Request.Pend.Type;
        Queue[request].Price          = Request.Price+
                                            BoolToDouble(IsEqual(Request.Pend.Step,0.00),
                                               point(Master[Operation(Request.Pend.Type)].ZoneSize),
                                               point(Request.Pend.Step)
                                           *Direction(Request.Pend.Type,InAction,IsEqual(Request.Pend.Type,OP_BUYLIMIT)||IsEqual(Request.Pend.Type,OP_SELLLIMIT)));
        Queue[request].Memo           = "["+ActionText(Request.Pend.Type)+"] resubmit";
      }
    
    //-- Screening checks before submitting for approval
    if (Enabled(Queue[request]))
    {
      Queue[request].Status           = Pending;
      Queue[request].Action           = Operation(Queue[request].Type);
      Queue[request].Requestor        = BoolToStr(StringLen(Queue[request].Requestor)==0,"No Requestor",Queue[request].Requestor);
      Queue[request].Lots             = BoolToDouble(IsEqual(Queue[request].Lots,0.00),LotSize(Queue[request].Action),Queue[request].Lots);
      Queue[request].TakeProfit       = fmax(Queue[request].TakeProfit,0.00);
      Queue[request].StopLoss         = fmax(Queue[request].StopLoss,0.00);

      //-- Pending Order Checks
      if (IsBetween(Queue[request].Type,OP_BUYLIMIT,OP_SELLSTOP))
      {
        if (IsEqual(Queue[request].Price,0.00)||IsHigher(0.00,Queue[request].Price,NoUpdate))
        {
          Queue[request].Status       = Declined;          
          Queue[request].Memo         = "Invalid pending entry price";
        }

        if (Queue[request].Expiry<TimeCurrent())
        {
          Queue[request].Status       = Declined;          
          Queue[request].Memo         = "Invalid order expiration";
        }
      }
    }

    if (IsEqual(Queue[request].Status,Pending))
    {
      if (OrderApproved(Queue[request]))
        Queue[request].Status         = Pending;
    }
    else AppendLog(Queue[request].Key,Queue[request].Ticket,"[Submit]"+Queue[request].Memo);

    UpdateSnapshot();
    
    return(Queue[request]);
  }

//+------------------------------------------------------------------+
//| MergeRequest - Merge EA-opened order requests into Master        |
//+------------------------------------------------------------------+
OrderDetail COrder::MergeRequest(OrderRequest &Request)
  {
    int detail;

    //-- Add New Tracked Order to Master
    detail                                            = ArraySize(Master[Request.Action].Order);
    ArrayResize(Master[Request.Action].Order,detail+1,1000);

    Master[Request.Action].Order[detail].Method       = Master[Request.Action].Method;
    Master[Request.Action].Order[detail].Status       = Fulfilled;
    Master[Request.Action].Order[detail].Ticket       = Request.Ticket;
    Master[Request.Action].Order[detail].Key          = Request.Key;
    Master[Request.Action].Order[detail].Action       = Request.Action;
    Master[Request.Action].Order[detail].Price        = Request.Price;
    Master[Request.Action].Order[detail].Lots         = Request.Lots;
    Master[Request.Action].Order[detail].Profit       = OrderProfit();
    Master[Request.Action].Order[detail].Swap         = OrderSwap();
    Master[Request.Action].Order[detail].TakeProfit   = Price(Profit,OrderType(),Request.TakeProfit,OrderOpenPrice());
    Master[Request.Action].Order[detail].StopLoss     = Price(Loss,OrderType(),Request.StopLoss,OrderOpenPrice());
    Master[Request.Action].Order[detail].Memo         = Request.Memo;
    
    Request.TakeProfit    = Master[Request.Action].Order[detail].TakeProfit;
    Request.StopLoss      = Master[Request.Action].Order[detail].StopLoss;

    if (IsBetween(Request.Type,OP_BUY,OP_SELLLIMIT))
      if (Slider[Request.Type].Enabled)
        Slider[Request.Type].Price                    = NoValue;

    ConsoleAlert("Request["+(string)Request.Key+"]:Merged "+Request.Memo); 
    AppendLog(Request.Key,Request.Ticket,"Request["+(string)Request.Key+"]:Merged");

    return (Master[Request.Action].Order[detail]);
  }

//+------------------------------------------------------------------+
//| MergeOrder - Merge Untracked into Master/Update existing order   |
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

    Master[Action].Order[detail].Method       = Master[Action].Method;
    Master[Action].Order[detail].Status       = Fulfilled;
    Master[Action].Order[detail].Ticket       = Ticket;
    Master[Action].Order[detail].Key          = NoValue;
    Master[Action].Order[detail].Action       = Action;
    Master[Action].Order[detail].Price        = OrderOpenPrice();
    Master[Action].Order[detail].Lots         = OrderLots();
    Master[Action].Order[detail].Profit       = OrderProfit();
    Master[Action].Order[detail].Swap         = OrderSwap();
    Master[Action].Order[detail].TakeProfit   = OrderTakeProfit();
    Master[Action].Order[detail].StopLoss     = OrderStopLoss();
    Master[Action].Order[detail].Memo         = OrderComment();

    ConsoleAlert(ActionText(Action)+" Order["+(string)Ticket+"]:Merged "+Master[Action].Order[detail].Memo);
    AppendLog(NoValue,Ticket,ActionText(Action)+" Order["+(string)Ticket+"]:Merged");
  }

//+------------------------------------------------------------------+
//| MergeSplit - Merge order splits into Master                      |
//+------------------------------------------------------------------+
void COrder::MergeSplit(OrderDetail &Order)
  {
    int detail                                = ArraySize(Master[Order.Action].Order);
    
    //-- Find new split order
    if (OrderSelect(OrdersTotal()-1,SELECT_BY_POS))
      if (IsBetween(Order.Method,Split,Retain))
      {
        //-- Add New split Order
        ArrayResize(Master[Order.Action].Order,detail+1,1000);

        Master[Order.Action].Order[detail].Method     = (OrderMethod)BoolToInt(OrderLots()<LotSize(Order.Action),
                                                                     BoolToInt(IsEqual(Order.Method,Split),Full,Hold),Order.Method);
        Master[Order.Action].Order[detail].Status     = Fulfilled;
        Master[Order.Action].Order[detail].Ticket     = OrderTicket();
        Master[Order.Action].Order[detail].Key        = NoValue;
        Master[Order.Action].Order[detail].Action     = Order.Action;
        Master[Order.Action].Order[detail].Price      = OrderOpenPrice();
        Master[Order.Action].Order[detail].Lots       = OrderLots();
        Master[Order.Action].Order[detail].Profit     = OrderProfit();
        Master[Order.Action].Order[detail].Swap       = OrderSwap();
        Master[Order.Action].Order[detail].TakeProfit = OrderTakeProfit();
        Master[Order.Action].Order[detail].StopLoss   = OrderStopLoss();
        Master[Order.Action].Order[detail].Memo       = OrderComment();

        ConsoleAlert("Split["+(string)Order.Ticket+"]:"+(string)OrderTicket()+":Merged "+Master[Order.Action].Order[detail].Memo);
        AppendLog(NoValue,OrderTicket(),"Split["+(string)Order.Ticket+"]:"+(string)OrderTicket());
      }
  }

//+------------------------------------------------------------------+
//| OrderApproved - Performs health/sanity checks for order approval |
//+------------------------------------------------------------------+
bool COrder::OrderApproved(OrderRequest &Request)
  {
    #define MarginTolerance    1
    
    if (Enabled(Request))
    {
      switch (Request.Status)
      {
        case Pending:   Request.Status     = Declined;

                        if (IsLower(Margin(Snapshot[Pending].Type[Request.Action].Lots+
                                      LotSize(Request.Action,Request.Lots),InPercent)-MarginTolerance,
                                      Master[Request.Action].MaxMargin,NoUpdate))
                          return (IsChanged(Request.Status,Approved));

                        Request.Memo       = proper(ActionText(Request.Action))+"er Margin "+DoubleToStr(Master[Request.Action].MaxMargin,1)+"% exceeded ["+
                                                DoubleToStr(Margin(Request.Action,Snapshot[Pending].Type[Request.Action].Lots+
                                                LotSize(Request.Action,Request.Lots),InPercent),1)+"%]";
                        break;

        case Immediate: Request.Status     = Declined;
        
                        if (IsLower(Margin(Master[Request.Action].Summary[Net].Lots+
                                      LotSize(Request.Action,Request.Lots),InPercent)-MarginTolerance,
                                      Master[Request.Action].MaxMargin,NoUpdate))
                        {

                          if (IsLower(EntryZone(Request.Action).Margin,Master[Request.Action].ZoneMaxMargin,NoUpdate))
                            return (IsChanged(Request.Status,Approved));

                          Request.Memo     = "Margin Zone limit "+DoubleToStr(Master[Request.Action].ZoneMaxMargin,1)+"% exceeded ["+
                                                DoubleToStr(Margin(Request.Action,EntryZone(Request.Action).Lots+Request.Lots,InPercent),1)+"%]";
                        }
                        else
                          Request.Memo     = proper(ActionText(Request.Action))+"er Margin "+DoubleToStr(Master[Request.Action].MaxMargin,1)+"% exceeded ["+
                                                DoubleToStr(Margin(Request.Action,Master[Request.Action].Summary[Net].Lots+
                                                LotSize(Request.Action,Request.Lots),InPercent),1)+"%]";
                        break;

        default:        Request.Status     = Rejected;
                        Request.Memo       = "Request not pending ["+EnumToString(Request.Status)+"]";
      }
    }
    else Request.Status                    = Rejected;

    AppendLog(Request.Key,NoValue,"["+EnumToString(Request.Status)+"]"+Request.Memo);

    return (false);
  }

//+------------------------------------------------------------------+
//| OrderOpened - Executes orders from the order queue               |
//+------------------------------------------------------------------+
bool COrder::OrderOpened(OrderRequest &Request)
  {
    if (Enabled(Request))
    {
      RefreshRates();
  
      Request.Lots             = LotSize(Request.Action,Request.Lots);
      Request.Ticket           = OrderSend(Symbol(),
                                     Request.Action,
                                     Request.Lots,
                                     BoolToDouble(IsEqual(Request.Action,OP_BUY),Ask,Bid,Digits),
                                     Account.MaxSlippage*10,
                                     0.00,
                                     0.00,
                                     Request.Memo,
                                     0,
                                     0,
                                     BoolToInt(IsEqual(Request.Action,OP_BUY),clrNavy,clrFireBrick));

      if (Request.Ticket>0)
      {
        if (OrderSelect(Request.Ticket,SELECT_BY_TICKET,MODE_TRADES))
        {
          Request.Action       = OrderType();
          Request.Price        = OrderOpenPrice();
          Request.Lots         = OrderLots();
        }
        else
          Request.Memo         = "Request ["+(string)Request.Key+"]:Fulfilled; Order not found";

        Request.Status         = Fulfilled;
        AppendLog(Request.Key,Request.Ticket,"Request["+(string)Request.Key+"]:Fulfilled");
        return (true);
      }

      Request.Memo             = "Request ["+(string)Request.Key+"]:Error ["+DoubleToStr(GetLastError(),0)+"]"
                                   +ActionText(Request.Action)+" failed @"+DoubleToStr(Request.Price,Digits)+"("
                                   +DoubleToStr(Request.Lots,2)+")";
    }

    Request.Status             = Rejected;
    AppendLog(Request.Key,Request.Ticket,"[Open]"+Request.Memo);
    
    return (false);
  }

//+------------------------------------------------------------------+
//| OrderClosed - Closes the number of supplied Lots of an Order     |
//+------------------------------------------------------------------+
bool COrder::OrderClosed(OrderDetail &Order) 
  {
    int    error                = NoValue;
    double lots                 = BoolToDouble(IsBetween(Order.Method,Split,Retain),     //-- If Split/Retain
                                    LotSize(Order.Action,                                //--   Calculate Split Lots
                                        fmin(fdiv(Order.Lots,2),
                                        fmax(Split(Order.Action),fdiv(Order.Lots,2)))),  
                                    Order.Lots,Account.LotPrecision);                    //-- else use Order Lots
    RefreshRates();

    if (OrderClose(Order.Ticket,
                   NormalizeDouble(lots,Account.LotPrecision),
                   BoolToDouble(IsEqual(Order.Action,OP_BUY),Bid,Ask,Digits),
                   Account.MaxSlippage*20,clrRed))
    {
      if (IsBetween(Order.Method,Split,Retain))
        if (IsEqual(lots,Order.Lots))
          Order.Method            = (OrderMethod)BoolToInt(IsEqual(Split,Order.Method),Full,Hold);
        else
          MergeSplit(Order);

      Order.Status              = Processed;

      return (true);          
    }
    else
    {  
      Order.Status              = Rejected;

      switch (IsChanged(error,GetLastError()))
      {
        case 129:   Order.Memo  = "Invalid Price(129): "+DoubleToStr(BoolToDouble(IsEqual(Order.Action,OP_BUY),Bid,Ask,Digits));
                    break;
        case 138:   Order.Memo  = "Requote(138): "+DoubleToStr(BoolToDouble(IsEqual(Order.Action,OP_BUY),Bid,Ask,Digits));
                    break;
        default:    Order.Memo  = "Unknown Error("+(string)error+"): "+DoubleToStr(BoolToDouble(IsEqual(Order.Action,OP_BUY),Bid,Ask,Digits));
      }
    }

    AppendLog(Order.Key,Order.Ticket,Order.Memo);

    return (false);
  }

//+------------------------------------------------------------------+
//| AdverseEquityHandler - Kills and halts system                    |
//+------------------------------------------------------------------+
void COrder::AdverseEquityHandler(void)
  {
    double maxrisk                = -fmax(Master[OP_SELL].MaxRisk,Master[OP_BUY].MaxRisk);

    if (IsLower(Summary[Net].Equity,maxrisk))
    {
      Cancel(NoAction);

      for (int action=OP_BUY;IsBetween(action,OP_BUY,OP_SELL);action++)
      {
        for (int ticket=0;ticket<Master[action].Summary[Net].Count;ticket++)
          Master[action].Order[ticket].Method   = Kill;

        ProcessLosses(action);
      }

      Disable("System halted [adverse equity]: Maximum risk threshold exceeded");
    }
  }

//+------------------------------------------------------------------+
//| ProcessRequests - Process requests in the Request Queue          |
//+------------------------------------------------------------------+
void COrder::ProcessRequests(void)
  {
    bool         complete    = false;
    
    OrderRequest updated[];
    
    ArrayResize(updated,0,1000);

    AdverseEquityHandler();

    for (int request=0;request<ArraySize(Queue);request++)
    {
      double price                                     = BoolToDouble(IsEqual(Queue[request].Action,OP_BUY),Ask,Bid);
      
      if (IsEqual(Queue[request].Status,Fulfilled))    //-- Complete Request
        Queue[request].Status                          = Completed;
      else
      if (IsEqual(Queue[request].Status,Pending))
        if (TimeCurrent()>Queue[request].Expiry)       //-- Expire Pending Orders
        {
          Queue[request].Status                        = Expired;
          Queue[request].Memo                          = "Request expired";
          Print(RequestStr(Queue[request]));
        }
        else
        if (IsBetween(price,
           BoolToDouble(IsEqual(Queue[request].Pend.LBound,0.00),price,Queue[request].Pend.LBound),
           BoolToDouble(IsEqual(Queue[request].Pend.UBound,0.00),price,Queue[request].Pend.UBound)))
        {
          switch(Queue[request].Type)
          {
            case OP_BUY:
            case OP_SELL:       Queue[request].Status    = (QueueStatus)BoolToInt(SliderTriggered(Queue[request].Type),Immediate,Pending);
                                break;
            case OP_BUYLIMIT:   if (Ask<=Queue[request].Price)
                                  Queue[request].Status  = (QueueStatus)BoolToInt(SliderTriggered(Queue[request].Type),Immediate,Pending);
                                break;
            case OP_SELLLIMIT:  if (Bid>=Queue[request].Price)
                                  Queue[request].Status  = (QueueStatus)BoolToInt(SliderTriggered(Queue[request].Type),Immediate,Pending);
                                break;
            case OP_BUYSTOP:    Queue[request].Status    = (QueueStatus)BoolToInt(Ask>=Queue[request].Price,Immediate,Pending);
                                break;
            case OP_SELLSTOP:   Queue[request].Status    = (QueueStatus)BoolToInt(Bid<=Queue[request].Price,Immediate,Pending);
                                break;
          }          
        }
        else
        {
          Queue[request].Status                        = Expired;
          Queue[request].Memo                          = "Price bounds exceeded";
        }
      else
        if (TimeCurrent()>Queue[request].Expiry+(Period()*60))
          Queue[request].Status                        = Completed;
      
      if (IsEqual(Queue[request].Status,Immediate))
        if (OrderApproved(Queue[request]))
          if (OrderOpened(Queue[request]))
          {
            //-- Resubmit Queued Pending Orders
            if (IsBetween(Queue[request].Pend.Type,OP_BUYLIMIT,OP_SELLSTOP))
              SubmitRequest(Queue[request],true);

            //-- Merge fulfilled requests/update stops
            UpdateOrder(MergeRequest(Queue[request]),Fulfilled);
            Update();
          }
          
      if (IsEqual(Queue[request].Status,Completed))
        complete                            = true;
      else
      {
        ArrayResize(updated,ArraySize(updated)+1);      
        updated[ArraySize(updated)-1]       = Queue[request];
      }
    }

    ArrayResize(Queue,ArraySize(updated),1000);
    
    for (int update=0;update<ArraySize(updated);update++)
      Queue[update]                         = updated[update];
      
    if (complete)
      UpdatePanel();
  }

//+------------------------------------------------------------------+
//| SliderTriggered - Activates and maintains Slider by Order Type   |
//+------------------------------------------------------------------+
bool COrder::SliderTriggered(int Action)
  {
    if (Slider[Action].Enabled)
    {
      if (Slider[Action].Price<0.00)
        Slider[Action].Price    = Close[0];
      else
        switch (Action)
        {
          case OP_BUY:
          case OP_BUYLIMIT:     if (IsLower(Close[0],Slider[Action].Price))
                                  return false;
                                break;
          case OP_SELL:
          case OP_SELLLIMIT:    if (IsHigher(Close[0],Slider[Action].Price))
                                  return false;
        }

      return fabs(Close[0]-Slider[Action].Price)>Slider[Action].Step;
    }

    return true;
  }

//+------------------------------------------------------------------+
//| ProcessProfits - Handles profit using config by action           |
//+------------------------------------------------------------------+
void COrder::ProcessProfits(int Action)
  {
    double netEquity     = 0.00;
    double netDCA        = 0.00;
    double netRecapture  = 0.00;

    //-- Calculate Profit Taking types
    for (int ticket=0;ticket<ArraySize(Master[Action].Summary[Net].Ticket);ticket++)
    {
      if (IsEqual(Master[Action].Order[ticket].Status,Working))
      {
        switch (Master[Action].Order[ticket].Method)
        {
          case Retain:
          case Split:
          case Full:        if (IsHigher(Equity(Master[Action].Order[ticket].Profit,InPercent),Master[Action].EquityMin,NoUpdate,3))
                              if (IsEqual(Master[Action].Order[ticket].TakeProfit,0.00,Digits))
                                Master[Action].Order[ticket].Status  = Qualified;
                              else
                              if (IsEqual(Action,OP_BUY)&&IsHigher(Bid,Master[Action].Order[ticket].TakeProfit,NoUpdate,Digits))
                                Master[Action].Order[ticket].Status  = Qualified;
                              else
                              if (IsEqual(Action,OP_SELL)&&IsLower(Ask,Master[Action].Order[ticket].TakeProfit,NoUpdate,Digits))
                                Master[Action].Order[ticket].Status  = Qualified;

                            if (IsEqual(Master[Action].Order[ticket].Status,Qualified))
                              netEquity     += Master[Action].Order[ticket].Profit;
                            break;
                            
          case Stop:        if (IsEqual(Action,OP_BUY)&&IsHigher(Bid,Master[Action].Order[ticket].TakeProfit,NoUpdate,Digits))
                              Master[Action].Order[ticket].Status  = Qualified;
                            else
                            if (IsEqual(Action,OP_SELL)&&IsLower(Ask,Master[Action].Order[ticket].TakeProfit,NoUpdate,Digits))
                              Master[Action].Order[ticket].Status  = Qualified;

                            if (IsEqual(Master[Action].Order[ticket].Status,Qualified))
                              netEquity     += Master[Action].Order[ticket].Profit;
                            break;

          case Recapture:   Master[Action].Order[ticket].Status      = Qualified;
                            netRecapture    += Master[Action].Order[ticket].Profit;
                            break;

          case DCA:         if (IsLower(0.00,Master[Action].Order[ticket].Profit,NoUpdate,2))
                              Master[Action].Order[ticket].Status    = Qualified;

                            netDCA          += Master[Action].Order[ticket].Profit;
                            break;
        }
      }
    }
    
    for (int ticket=0;ticket<ArraySize(Master[Action].Summary[Net].Ticket);ticket++)
      if (IsEqual(Master[Action].Order[ticket].Status,Qualified))
      {
        switch (Master[Action].Order[ticket].Method)
        {
          case Retain:
          case Split:
          case Full:      if (IsHigher(Equity(netEquity),Master[Action].EquityTarget,NoUpdate,3))
                            Master[Action].Order[ticket].Status      = Processing;
                          break;
                          
          case Stop:      Master[Action].Order[ticket].Status        = Processing;
                          break;

          case DCA:       if (IsHigher(Equity(netDCA,InPercent),Master[Action].EquityMin,NoUpdate,3))
                            Master[Action].Order[ticket].Status      = Processing;
                          break;

          case Recapture: break;
        }
        
        if (IsEqual(Master[Action].Order[ticket].Status,Processing))
          if (OrderClosed(Master[Action].Order[ticket]))
            UpdateSnapshot();
          else
            Master[Action].Order[ticket].Status                      = Working;
        else
          Master[Action].Order[ticket].Status                        = Working;
      }
  }

//+------------------------------------------------------------------+
//| ProcessLosses - Handles losses using config by Action            |
//+------------------------------------------------------------------+
void COrder::ProcessLosses(int Action)
  {
    double maxrisk                = -(Master[Action].MaxRisk);

    for (int ticket=0;ticket<Master[Action].Summary[Net].Count;ticket++)
    {
      //-- Handle Kills first
      if (IsEqual(Master[Action].Order[ticket].Method,Kill))
        Master[Action].Order[ticket].Status  = Processing;
      else

      //-- Handle working orders
      if (IsEqual(Master[Action].Order[ticket].Status,Working))
      {
        //-- Handle Adverse Tickets (No Stop)
        if (IsEqual(Master[Action].Order[ticket].StopLoss,0.00,Digits))
          Master[Action].Order[ticket].Status  = (QueueStatus)BoolToInt(IsLower(Equity(Master[Action].Order[ticket].Profit),maxrisk),Processing,Master[Action].Order[ticket].Status);
        else

          //-- Handle Stops
          switch (Master[Action].Order[ticket].Method)
          {
            case Retain:
            case Split:
            case Full:   if (IsEqual(Action,OP_BUY))
                           if (IsLower(Bid,Master[Action].Order[ticket].StopLoss,NoUpdate,Digits))
                             Master[Action].Order[ticket].Status     = Processing;

                         if (IsEqual(Action,OP_SELL))
                           if (IsHigher(Ask,Master[Action].Order[ticket].StopLoss,NoUpdate,Digits))
                             Master[Action].Order[ticket].Status     = Processing;
                          break;
          }
      }

      if (IsEqual(Master[Action].Order[ticket].Status,Processing))
        if (OrderClosed(Master[Action].Order[ticket]))
          UpdateSnapshot();
        else
          Master[Action].Order[ticket].Status                        = Working;
      else
        Master[Action].Order[ticket].Status                          = Working;
    }
  }

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
COrder::COrder(BrokerModel Model)
  {
    //--- Set Panel Indicator Short Name
    indSN                            = "CPanel-v2";

    //-- Initialize Account
    Account.MarginModel    = Model;
    Account.TradeEnabled   = true;
    Account.MaxSlippage    = 3;

    Account.Balance        = AccountBalance()+AccountCredit();

    Account.LotSizeMin     = NormalizeDouble(MarketInfo(Symbol(),MODE_MINLOT),2);
    Account.LotSizeMax     = NormalizeDouble(MarketInfo(Symbol(),MODE_MAXLOT),2);
    Account.LotPrecision   = BoolToInt(IsEqual(Account.LotSizeMin,0.01),2,1);
    Account.BaseCurrency   = 1;

    InitMaster(OP_BUY,Hold);
    InitMaster(OP_SELL,Hold);

    for (int action=OP_BUY;action<=OP_SELL;action++)
      Account.NetProfit[action]                   = 0.00;
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
void COrder::Update(double BaseCurrency=1.0)
  {
    PurgeLog();
    
    //-- Reconcile
    UpdateAccount(BaseCurrency);
    UpdateMaster();
    UpdateSummary();
    UpdateSnapshot();
    UpdatePanel();
  }

//+------------------------------------------------------------------+
//| ProcessOrders - Updates/Closes orders by Action                  |
//+------------------------------------------------------------------+
void COrder::ProcessOrders(int Action)
  {
    //-- Set stops/targets
    for (int detail=0;detail<ArraySize(Master[Action].Order);detail++)
      UpdateOrder(Master[Action].Order[detail],Working);

    ProcessProfits(Action);
    ProcessLosses(Action);

    //-- Order close processed
    if (Processed(Action))
      Update();
  }

//+------------------------------------------------------------------+
//| ProcessHedge - Opens offsetting position to Zero-Net             |
//+------------------------------------------------------------------+
void COrder::ProcessHedge(string Requestor)
  {
    OrderRequest request       = BlankRequest(Requestor);

    if (fabs(Summary[Net].Lots)>0.00)
    {
      int hedges               = (int)ceil(fdiv(fabs(Summary[Net].Lots),Account.LotSizeMax));

      request.Action           = Action(Summary[Net].Lots,InDirection,InContrarian);
      request.Type             = Action(Summary[Net].Lots,InDirection,InContrarian);
      request.Lots             = fdiv(fabs(Summary[Net].Lots),hedges,Account.LotPrecision);
      request.Memo             = "Hedge";

      while (hedges-->0)
        if (Submitted(request))
          Print(RequestStr(request));
        else
          PrintLog(0);
    }
  }

//+------------------------------------------------------------------+
//| Enabled - returns true if trade is open for supplied Action      |
//+------------------------------------------------------------------+
bool COrder::Enabled(int Action)
  {
    if (Account.TradeEnabled)
      if (IsBetween(Action,OP_BUY,OP_SELL))
        return Master[Action].TradeEnabled;

    return (false);
  }

//+------------------------------------------------------------------+
//| Enabled - true if trade is open and request type is valid        |
//+------------------------------------------------------------------+
bool COrder::Enabled(OrderRequest &Request)
  {
    if (Account.TradeEnabled)
      if (IsBetween(Operation(Request.Type),OP_BUY,OP_SELL))
        if (Master[Operation(Request.Type)].TradeEnabled)
          return (true);
        else
          Request.Memo       = "Action ["+ActionText(Request.Action)+"] not enabled";
      else
        Request.Memo         = "Invalid Request Type ["+proper(ActionText(Request.Action)+"]");
    else      
      Request.Memo           = "Trade disabled; system halted";

    return (false);
  }   

//+------------------------------------------------------------------+
//| Price - returns Stop(loss)|Profit prices by Action from Basis    |
//+------------------------------------------------------------------+
double COrder::Price(SummaryType Type, int Action, double Requested=0.00, double Basis=0.00, bool InPips=false)
  {
    //-- Set Initial Values
    int    action       = Operation(Action);
    int    direction    = BoolToInt(IsEqual(action,OP_BUY),DirectionUp,DirectionDown)
                            *BoolToInt(IsEqual(Type,Profit),DirectionUp,DirectionDown);

    Basis               = BoolToDouble(IsEqual(Basis,0.00),BoolToDouble(IsEqual(action,OP_BUY),Bid,Ask),Basis,Digits);

    double requested    = BoolToDouble(IsEqual(fmax(0.00,Requested),0.00),0.00,BoolToDouble(InPips,Basis+(direction*point(Requested)),Requested));

    double stored       = BoolToDouble(IsBetween(action,OP_BUY,OP_SELL),BoolToDouble(IsEqual(Type,Profit),
                            Master[action].TakeProfit,Master[action].StopLoss),0.00,Digits);
    double calculated   = BoolToDouble(IsEqual(Type,Profit),
                            BoolToDouble(IsEqual(Master[action].DefaultTarget,0.00),0.00,Basis+(direction*point(Master[action].DefaultTarget))),
                            BoolToDouble(IsEqual(Master[action].DefaultStop,0.00),0.00,Basis+(direction*point(Master[action].DefaultStop))),Digits);
                            
    //-- Validate and return
    if (IsEqual(Type,Profit)||IsEqual(Type,Loss))
    {
      requested         = BoolToDouble(IsEqual(direction,DirectionUp),
                            BoolToDouble(IsLower(Basis+Account.Spread,requested,NoUpdate),requested,0.00),
                            BoolToDouble(IsHigher(Basis-Account.Spread,requested,NoUpdate),requested,0.00),Digits);
    
      stored            = BoolToDouble(IsEqual(direction,DirectionUp),
                            BoolToDouble(IsLower(Basis+Account.Spread,stored,NoUpdate),stored,0.00),
                            BoolToDouble(IsHigher(Basis-Account.Spread,stored,NoUpdate),stored,0.00),Digits);
                     
      calculated        = BoolToDouble(IsBetween(calculated,Basis+Account.Spread,Basis-Account.Spread),0.00,calculated,Digits);

      return (coalesce(requested,stored,calculated));
    }
    
    return (0.00);
  }

//+------------------------------------------------------------------+
//| Free - Returns Lots Open/Pend(?) in the zone of supplied Price   |
//+------------------------------------------------------------------+
double COrder::Free(int Action, double Price=0.00, bool IncludePending=true)
  {
    if (IsBetween(Action,OP_BUY,OP_SELL))
    {
      
      double price   = BoolToDouble(Price==0.00,BoolToDouble(Action==OP_BUY,Bid,Ask),Price,Digits);
      double lots    = LotSize(Action);
      double req     = 0.00;
      double ord     = 0.00;
    
      if (IncludePending)
        for (int request=0;request<ArraySize(Queue);request++)
          if (IsEqual(Queue[request].Action,Action))
            if (IsBetween(price,Queue[request].Price-(point(Master[Action].ZoneSize*0.9,Digits)),
                                Queue[request].Price+(point(Master[Action].ZoneSize*0.9,Digits))))
              req    += LotSize(Action,Queue[request].Lots);

      for (int node=0;node<ArraySize(Master[Action].Order);node++)
        if (IsEqual(Master[Action].Order[node].Action,Action))
          if (IsBetween(price,Master[Action].Order[node].Price-(point(Master[Action].ZoneSize*0.9,Digits)),
                              Master[Action].Order[node].Price+(point(Master[Action].ZoneSize*0.9,Digits))))
            ord     += Master[Action].Order[node].Lots;

      return NormalizeDouble(lots-(req+ord),Account.LotPrecision);
    }
  
    return NormalizeDouble(NoValue,Account.LotPrecision);
  }

//+------------------------------------------------------------------+
//| Equity - returns the account equity                              |
//+------------------------------------------------------------------+
double COrder::Equity(double Value, int Format=InPercent)
  {   
    switch (Format)
    {
      case InDecimal: return (NormalizeDouble(fdiv(Value,Account.EquityBalance),3));
      case InPercent: return (NormalizeDouble(fdiv(Value,Account.EquityBalance),3)*100);
      default:        return (NormalizeDouble(Value,2));
    }
  }

//+------------------------------------------------------------------+
//| LotSize - returns default or scaled by supplied/default Margin   |
//+------------------------------------------------------------------+
double COrder::LotSize(int Action, double Lots=0.00, double Margin=0.00)
  {
    if (IsBetween(Action,OP_BUY,OP_SELLSTOP))
    {
      if(IsBetween(Lots,Account.LotSizeMin,Account.LotSizeMax,Account.LotPrecision))
        return(NormalizeDouble(Lots,Account.LotPrecision));

      if (Master[Operation(Action)].DefaultLotSize>0.00)
        return NormalizeDouble(Master[Operation(Action)].DefaultLotSize,Account.LotPrecision);

      return NormalizeDouble(fmax(fmin((Account.Balance*BoolToDouble(Margin>0.00,Margin,Master[Operation(Action)].LotScale/100))/
                MarketInfo(Symbol(),MODE_MARGINREQUIRED),Account.LotSizeMax),Account.LotSizeMin),Account.LotPrecision);
    }

    return (NormalizeDouble(0.00,Account.LotPrecision));
  }

//+------------------------------------------------------------------+
//| Cancel - Cancels pending orders by Type                          |
//+------------------------------------------------------------------+
void COrder::Cancel(int Type, string Reason="")
  {
    for (int request=0;request<ArraySize(Queue);request++)
      if (IsEqual(Queue[request].Status,Pending))
        if (IsEqual(Type,Queue[request].Action)||
            IsEqual(Type,Queue[request].Type)||
            IsEqual(Type,NoAction))
        {
          Queue[request].Status   = Canceled;
          Queue[request].Memo     = BoolToStr(IsEqual(StringLen(Reason),0),Queue[request].Memo,Reason);
        }
  }

//+------------------------------------------------------------------+
//| Cancel - Cancels supplied pending Request                        |
//+------------------------------------------------------------------+
void COrder::Cancel(OrderRequest &Request, string Reason="")
  {
    for (int request=0;request<ArraySize(Queue);request++)
      if (IsEqual(Request.Key,Queue[request].Key)&&IsEqual(Queue[request].Ticket,NoValue))
      {
        Queue[request].Status       = Canceled;
        Queue[request].Memo         = BoolToStr(IsEqual(StringLen(Reason),0),Request.Memo,Reason);
      }
  }

//+------------------------------------------------------------------+
//| Submitted - Adds screened orders to the Order Processing Queue   |
//+------------------------------------------------------------------+
bool COrder::Submitted(OrderRequest &Request)
  {
    if (IsEqual(SubmitRequest(Request).Status,Pending))
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| Status - True on Order/Request Status by Type on current tick    |
//+------------------------------------------------------------------+
bool COrder::Status(QueueStatus State, int Type=NoAction)
  {
    if (IsEqual(Type,NoAction))
      for (int type=OP_BUY;type<=OP_SELLSTOP;type++)
        return (Snapshot[State].Type[type].Count>0);

    return (Snapshot[State].Type[Type].Count>0);
  }

//+------------------------------------------------------------------+
//| BlankRequest - Returns a blank Request                           |
//+------------------------------------------------------------------+
OrderRequest COrder::BlankRequest(string Requestor)
  {
    OrderRequest Request;
    
    Request.Status           = Initial;
    Request.Key              = NoValue;
    Request.Ticket           = NoValue;
    Request.Type             = NoAction;
    Request.Action           = NoAction;
    Request.Requestor        = Requestor;
    Request.Price            = 0.00;
    Request.Lots             = 0.00;
    Request.TakeProfit       = 0.00;
    Request.StopLoss         = 0.00;
    Request.Memo             = "";
    Request.Expiry           = TimeCurrent()+(Period()*60);
    Request.Pend.Type        = NoAction;
    Request.Pend.LBound      = 0.00;
    Request.Pend.UBound      = 0.00;
    Request.Pend.Step        = 0.00;

    return (Request);
  }

//+------------------------------------------------------------------+
//| Ticket - Returns Order Record by Ticket                          |
//+------------------------------------------------------------------+
OrderDetail COrder::Ticket(int Ticket)
  {
    OrderDetail search;
    
    for (int detail=0;detail<ArraySize(Master[OP_BUY].Order);detail++)
      if (IsEqual(Master[OP_BUY].Order[detail].Ticket,Ticket))
        return (Master[OP_BUY].Order[detail]);

    for (int detail=0;detail<ArraySize(Master[OP_SELL].Order);detail++)
      if (IsEqual(Master[OP_SELL].Order[detail].Ticket,Ticket))
        return (Master[OP_SELL].Order[detail]);

    search.Ticket            = Ticket;
    search.Status            = Invalid;
    search.Memo              = "Ticket not found: "+IntegerToString(Ticket,10,'0');

    return (search);
  }

//+------------------------------------------------------------------+
//| Request - Returns Order Request from Queue by Key/Ticket         |
//+------------------------------------------------------------------+
OrderRequest COrder::Request(int Key, int Ticket=NoValue)
  {
    OrderRequest search      = BlankRequest("Search");

    for (int request=0;request<ArraySize(Queue);request++)
      if (IsEqual(Key,Queue[request].Key)&&IsEqual(Ticket,Queue[request].Ticket))
        return (Queue[request]);

    search.Status            = Invalid;
    search.Memo              = "Request not found: "+IntegerToString(Key,10,'-');

    return (search);
  }

//+------------------------------------------------------------------+
//| GetGroup - Loads Ticket[] for the specified OrderGroup           |
//+------------------------------------------------------------------+
void COrder::GetGroup(int Action, OrderGroup Group, int &Ticket[], int Key=NoValue)
  {
    OrderSummary zone;
    
    if (IsBetween(Action,OP_BUY,OP_SELL))
      switch (Group)
      {
        case ByZone:    GetZone(Action,Key,zone);
                        ArrayCopy(Ticket,zone.Ticket);
                        break;
        case ByTicket:  if (Ticket(Key).Status<Invalid)
                        {
                          ArrayResize(Ticket,1,100);
                          Ticket[0]    = Key;
                        }
                        break;
        case ByAction:  ArrayCopy(Ticket,Master[Action].Summary[Net].Ticket);
                        break;
        case ByProfit:  ArrayCopy(Ticket,Master[Action].Summary[Profit].Ticket);
                        break;
        case ByLoss:    ArrayCopy(Ticket,Master[Action].Summary[Loss].Ticket);
                        break;
        case ByMethod:  for (int index=0;index<ArraySize(Master[Action].Order);index++)
                          if (IsEqual(Master[Action].Order[index].Method,Key))
                          {
                            ArrayResize(Ticket,ArraySize(Ticket)+1,100);
                            Ticket[ArraySize(Ticket)-1] = Master[Action].Order[index].Ticket;
                          }
      }


  }

//+------------------------------------------------------------------+
//| GetZone - Updates Zone Summary Node by Action/Zone #             |
//+------------------------------------------------------------------+
void COrder::GetZone(int Action, int Zone, OrderSummary &Node)
  {
    InitSummary(Node,Zone);

    if (IsBetween(Action,OP_BUY,OP_SELL))
      for (int node=0;node<ArraySize(Master[Action].Zone);node++)
        if (IsEqual(Master[Action].Zone[node].Zone,Zone))
          Node               = Master[Action].Zone[node];
  }


//+------------------------------------------------------------------+
//| Zone - Returns Zone based on supplied Price, Buy/Bid, Sell/Ask   |
//+------------------------------------------------------------------+
int COrder::Zone(int Action, double Price=0.00)
  {
    if (IsBetween(Action,OP_BUY,OP_SELL))
    {
      Price   = BoolToDouble(IsEqual(Price,0.00),BoolToDouble(IsEqual(Action,OP_BUY),Bid,Ask),Price,Digits)-
                  (Master[Action].DCA-(fdiv(point(Master[Action].ZoneSize),2))*Direction(Action,InAction));

      return (BoolToInt(IsEqual(Action,OP_BUY),(int)floor(fdiv(Price,point(Master[Action].ZoneSize),Digits)),
                                               (int)ceil(fdiv(Price,point(Master[Action].ZoneSize)))));
    }

    return (0);
  }

//+------------------------------------------------------------------+
//| SetSlider - Sets Slider Triggering ENTRY event options           |
//+------------------------------------------------------------------+
void COrder::SetSlider(int Action, double Step=0.00)
  {
    Slider[Action].Enabled      = Step>0.00;
    Slider[Action].Price        = NoValue;
    Slider[Action].Step         = Step;
  }

//+------------------------------------------------------------------+
//| SetMethod - Set Order handling by Action/Method                  |
//+------------------------------------------------------------------+
void COrder::SetMethod(int Action, OrderMethod Method, OrderGroup Group, int Key=NoValue)
  {
    int          ticket[];
    
    if (IsEqual(Group,ByTicket))
      Action                                    = Ticket(Key).Action;

    if (IsBetween(Action,OP_BUY,OP_SELL))
    {
      GetGroup(Action,Group,ticket,Key);

      for (int index=0;index<ArraySize(ticket);index++)
        for (int detail=0;detail<ArraySize(Master[Action].Order);detail++)
          if (IsEqual(Master[Action].Order[detail].Ticket,ticket[index]))
             Master[Action].Order[detail].Method   = (OrderMethod)BoolToInt(IsEqual(Method,Split),BoolToInt(Master[Action].Order[detail].Lots<Split(Action),Full,Split),
                                                                  BoolToInt(IsEqual(Method,Retain),BoolToInt(Master[Action].Order[detail].Lots<Split(Action),Hold,Retain),Method));
    }
  }

//+------------------------------------------------------------------+
//| SetDefaultStop - Set Stop price, defaullt pip, hide property     |
//+------------------------------------------------------------------+
void COrder::SetDefaultStop(int Action, double Price, int Pips, bool Hide)
  {
    if (IsBetween(Action,OP_BUY,OP_SELL))
    {
      if (Pips>NoValue)   Master[Action].DefaultStop      = Pips;
      if (Price>NoValue)  Master[Action].StopLoss         = Price;

      if (IsChanged(Master[Action].HideStop,Hide))
        UpdateLabel("lbvOQ-"+ActionText(Action)+"-ShowSL",
          CharToStr((uchar)BoolToInt(Hide,251,252)),BoolToInt(Hide,clrRed,clrLawnGreen),12,"Wingdings");
    }
  }

//+------------------------------------------------------------------+
//| SetDefaultTarget - Set Target price, default pip, hide property  |
//+------------------------------------------------------------------+
void COrder::SetDefaultTarget(int Action, double Price, int Pips, bool Hide)
  {
    if (IsBetween(Action,OP_BUY,OP_SELL))
    {
      if (Pips>NoValue)   Master[Action].DefaultTarget    = Pips;
      if (Price>NoValue)  Master[Action].TakeProfit       = Price;

      if (IsChanged(Master[Action].HideTarget,Hide))
        UpdateLabel("lbvOQ-"+ActionText(Action)+"-ShowTP",
          CharToStr((uchar)BoolToInt(Hide,251,252)),BoolToInt(Hide,clrRed,clrLawnGreen),12,"Wingdings");
    }
  }

//+------------------------------------------------------------------+
//| SetStopLoss - Sets order stops and hide restrictions             |
//+------------------------------------------------------------------+
void COrder::SetStopLoss(int Action, OrderGroup Group, double StopLoss, int Key=NoValue)
  {
    int ticket[];
    
    if (IsEqual(Group,ByTicket))
      Action                                    = Ticket(Key).Action;
    
    if (IsBetween(Action,OP_BUY,OP_SELL))
    {
      GetGroup(Action,Group,ticket,Key);
  
      for (int index=0;index<ArraySize(ticket);index++)
        for (int detail=0;detail<ArraySize(Master[Action].Order);detail++)
          if (IsEqual(Master[Action].Order[detail].Ticket,ticket[index]))
            Master[Action].Order[detail].StopLoss = Price(Loss,Action,StopLoss,0.00);
    }
  }

//+------------------------------------------------------------------+
//| SetTakeProfit - Sets order targets and hide restrictions         |
//+------------------------------------------------------------------+
void COrder::SetTakeProfit(int Action, OrderGroup Group, double TakeProfit, int Key=NoValue, bool HardStop=false)
  {
    int ticket[];
    
    if (IsEqual(Group,ByTicket))
      Action                                    = Ticket(Key).Action;
    
    if (IsBetween(Action,OP_BUY,OP_SELL))
    {
      GetGroup(Action,Group,ticket,Key);
  
      for (int index=0;index<ArraySize(ticket);index++)
        for (int detail=0;detail<ArraySize(Master[Action].Order);detail++)
          if (IsEqual(Master[Action].Order[detail].Ticket,ticket[index]))
          {
            Master[Action].Order[detail].TakeProfit = Price(Profit,Action,TakeProfit,0.00);
            
            if (HardStop)
              if (Master[Action].Order[detail].TakeProfit>0.00)
                Master[Action].Order[detail].Method = Stop;
          }
    }
  }

//+------------------------------------------------------------------+
//| ConfigureFund - Configures profit/equity management options      |
//+------------------------------------------------------------------+
void COrder::ConfigureFund(int Action, double EquityTarget, double EquityMin, OrderMethod Method=Hold)
  {
     if (IsBetween(Action,OP_BUY,OP_SELL))
     {
       Master[Action].EquityTarget      = fmax(0.00,EquityTarget);
       Master[Action].EquityMin         = fmax(0.00,EquityMin);
       Master[Action].Method            = Method;
     }
  }

//+------------------------------------------------------------------+
//| ConfigureRisk - Configures risk mitigation management options    |
//+------------------------------------------------------------------+
void COrder::ConfigureRisk(int Action, double Risk, double Margin, double Scale, double LotSize)
  {
     if (IsBetween(Action,OP_BUY,OP_SELL))
     {
       Master[Action].MaxRisk           = fmax(0.00,Risk);
       Master[Action].MaxMargin         = fmax(0.00,Margin);
       Master[Action].LotScale          = fmax(0.00,Scale);     
       Master[Action].DefaultLotSize    = fmin(fmax(0.00,LotSize),Account.LotSizeMax);
     }
  }

//+------------------------------------------------------------------+
//| ConfigureZone - Configures zone management options               |
//+------------------------------------------------------------------+
void COrder::ConfigureZone(int Action, double Size, double Margin)
  {
     if (IsBetween(Action,OP_BUY,OP_SELL))
     {
       Master[Action].ZoneSize          = fmax(0.00,Size);
       Master[Action].ZoneMaxMargin     = fmax(0.00,Margin);
     }
  }

//+------------------------------------------------------------------+
//| PrintLog                                                         |
//+------------------------------------------------------------------+
void COrder::PrintLog(void)
  {
    string text       = "\n";

    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      Append(text,"==== Open "+ActionText(action)+" Orders ["+(string)Master[action].Summary[Net].Count+"]","\n\n");

      for (int detail=0;detail<ArraySize(Master[action].Order);detail++)
      {
        Append(text,OrderDetailStr(Master[action].Order[detail]),"\n");

        for (int line=0;line<ArraySize(Log);line++)
          if (IsEqual(Log[line].Ticket,Master[action].Order[detail].Ticket))
            Append(text,Log[line].Note,";");
      }
    }

    Print (text);
  }


//+------------------------------------------------------------------+
//| PrintLog                                                         |
//+------------------------------------------------------------------+
void COrder::PrintLog(int History)
  {
    int history       = BoolToInt(History>0,fmin(History,ArraySize(Log)),ArraySize(Log));

    for (int line=0;line<history;line++)
      Print(TimeToStr(Log[line].Received)+"["+(string)Log[line].Key+":"+(string)Log[line].Ticket+"]:"+Log[line].Note);
  }

//+------------------------------------------------------------------+
//| OrderDetailStr - Returns formatted Order text                    |
//+------------------------------------------------------------------+
string COrder::OrderDetailStr(OrderDetail &Order)
  {
    string text      = "";

    Append(text,"Status: "+EnumToString(Order.Status)+" ["+EnumToString(Order.Method)+"]");

    if (IsBetween(Order.Action,OP_BUY,OP_SELL))
      Append(text,"Ticket: "+BoolToStr(IsEqual(Master[Order.Action].Summary[Net].Count,1),"[*]",
                             BoolToStr(IsEqual(Order.Ticket,Master[Order.Action].TicketMax),"[+]",
                             BoolToStr(IsEqual(Order.Ticket,Master[Order.Action].TicketMin),"[-]","[ ]")))
                            +IntegerToString(Order.Ticket,10,'0'));
    else Append(text,"Ticket: Order Detail error");

    Append(text,ActionText(Order.Action));
    Append(text,"Open Price: "+DoubleToStr(Order.Price,Digits));
    Append(text,"Lots: "+DoubleToStr(Order.Lots,Account.LotPrecision));
    Append(text,"Profit: "+DoubleToStr(Order.Profit,2));
    Append(text,"Equity: "+DoubleToStr(Equity(Order.Profit,InPercent),1));
    Append(text,"Swap: "+DoubleToStr(Order.Swap,2));
    Append(text,"TP: "+DoubleToStr(Order.TakeProfit,Digits));
    Append(text,"Stop: "+DoubleToStr(Order.StopLoss,Digits));
    Append(text,Order.Memo);

    return (text);
  }

//+------------------------------------------------------------------+
//| OrderStr - Returns formatted text for all open orders            |
//+------------------------------------------------------------------+
string COrder::OrderStr(int Action=NoAction)
  {
    string text       = "\n";

    for (int action=OP_BUY;action<=OP_SELL;action++)
      if (IsEqual(Action,NoAction)||IsEqual(action,Action))
      {
        Append(text,"==== Open "+ActionText(action)+" Orders ["+IntegerToString(Master[action].Summary[Net].Count,3,'-')+"]","\n\n");
        Append(text,"     Profit ["+IntegerToString(Master[action].Summary[Profit].Count,3,'-')+"]","\n");
        Append(text,"Equity ["+DoubleToStr(Master[action].Summary[Profit].Equity,1)+"%]");
        Append(text,"Margin ["+DoubleToStr(Master[action].Summary[Profit].Margin,1)+"%]");
        Append(text,"     Loss   ["+IntegerToString(Master[action].Summary[Loss].Count,3,'-')+"]","\n");
        Append(text,"Equity ["+DoubleToStr(Master[action].Summary[Loss].Equity,1)+"%]");
        Append(text,"Margin ["+DoubleToStr(Master[action].Summary[Loss].Margin,1)+"%]");

        for (int detail=0;detail<ArraySize(Master[action].Order);detail++)
          if (!IsEqual(Master[action].Order[detail].Status,Closed))
            Append(text,OrderDetailStr(Master[action].Order[detail]),"\n");
      }

    return (text);
  }

//+------------------------------------------------------------------+
//| RequestStr - Returns formatted Request text                      |
//+------------------------------------------------------------------+
string COrder::RequestStr(OrderRequest &Request)
  {
    string text      = "";

    Append(text,"Key: "+IntegerToString(Request.Key,10,'-'));
    Append(text,BoolToStr(Request.Ticket>NoValue,"Ticket: "+IntegerToString(Request.Ticket,10,'-')));
    Append(text,ActionText(Request.Type)+BoolToStr(IsEqual(Request.Type,Request.Action),"","["+ActionText(Request.Action)+"]"));
    Append(text,EnumToString(Request.Status));
    Append(text,Request.Requestor);
    Append(text,"Price: "+BoolToStr(IsEqual(Request.Price,0.00),"Market",DoubleToStr(Request.Price,Digits)));
    Append(text,"Lots: "+DoubleToStr(Request.Lots,Account.LotPrecision));
    Append(text,"TP: "+DoubleToStr(Request.TakeProfit,Digits));
    Append(text,"Stop: "+DoubleToStr(Request.StopLoss,Digits));
    Append(text,"Expiry: "+TimeToStr(Request.Expiry));

    if (IsBetween(Request.Pend.Type,OP_BUYLIMIT,OP_SELLSTOP))
    {
      Append(text,"[Resubmit/"+ActionText(Request.Pend.Type)+"]");
      Append(text,"Lower: "+DoubleToStr(Request.Pend.LBound,Digits));
      Append(text,"Upper: "+DoubleToStr(Request.Pend.UBound,Digits));
      Append(text,"Step: "+DoubleToStr(Request.Pend.Step,Digits)+"]");
    }
    
    Append(text,Request.Memo);

    return (text);
  }

//+------------------------------------------------------------------+
//| QueueStr - Returns formatted Order Queue text                    |
//+------------------------------------------------------------------+
string COrder::QueueStr(int Action=NoAction, bool Force=false)
  {
    string text       = "\n";
    string actions[6]  = {"","","","","",""};
    int    counts[6]   = {0,0,0,0,0,0};

    for (int oq=0;oq<ArraySize(Queue);oq++)
      if (IsBetween(Queue[oq].Action,OP_BUY,OP_SELLSTOP))
      {
        counts[Queue[oq].Action]++;
        Append(actions[Queue[oq].Action],RequestStr(Queue[oq]),"\n");
      }

    for (int action=OP_BUY;action<6;action++)
    {
      actions[action]      = ActionText(action)+" Queue ["+(string)counts[action]+"]\n"+actions[action]+"\n";

      if (IsEqual(Action,NoAction))
        if (counts[action]>0||Force)
          Append(text,actions[action],"\n");

      if (IsEqual(Action,action))
        return (actions[action]);
    }

    return (text);
  }

//+------------------------------------------------------------------+
//| SummaryLineStr - Returns formatted Summary Line text             |
//+------------------------------------------------------------------+
string COrder::SummaryLineStr(string Description, OrderSummary &Line, bool Force=false)
  {
    string text    = "";
    string tickets = "";

    if (Line.Count>0||Force)
    {
      Append(text,Description,"\n");
      Append(text,"Zone["+IntegerToString(Line.Zone,2)+"]");
      Append(text,"Orders["+IntegerToString(Line.Count,3)+"]");
      Append(text,"Lots:"+DoubleToStr(Line.Lots,Account.LotPrecision));
      Append(text,"Value:$ "+DoubleToStr(Line.Value,2));
      Append(text,"Margin:"+DoubleToStr(Line.Margin,1)+"%");
      Append(text,"Equity:"+DoubleToStr(Line.Equity,1)+"%");

      if (ArraySize(Line.Ticket)>0)
        for (int ticket=0;ticket<ArraySize(Line.Ticket);ticket++)
          Append(tickets,(string)Line.Ticket[ticket],",");
      else
        if (InStr(Description,"Net"))
          for (int action=OP_BUY;action<=OP_SELL;action++)
            for (int ticket=0;ticket<ArraySize(Summary[action].Ticket);ticket++)
              Append(tickets,(string)Summary[action].Ticket[ticket],",");

        Append(text,BoolToStr(tickets=="","","Ticket(s): ["+tickets+"]"));
    }

    return (text);
  }

//+------------------------------------------------------------------+
//| MasterStr - Returns formatted Master[Action] text                |
//+------------------------------------------------------------------+
string COrder::MasterStr(int Action)
  {
    string text  = "\n\nMaster Configuration ["+proper(ActionText(Action))+"]";

    Append(text,"Method:         "+EnumToString(Master[Action].Method),"\n");
    Append(text,"Trade:          "+BoolToStr(Master[Action].TradeEnabled,"Enabled","Disabled"),"\n");
    Append(text,"LotSize:        "+DoubleToStr(LotSize(Action),Account.LotPrecision),"\n");
    Append(text,"EquityTarget:   "+DoubleToStr(Master[Action].EquityTarget,1),"\n");
    Append(text,"EquityMin:      "+DoubleToStr(Master[Action].EquityMin,1),"%\n");
    Append(text,"MaxRisk:        "+DoubleToStr(Master[Action].MaxRisk,1),"%\n");
    Append(text,"LotScale:       "+DoubleToStr(Master[Action].LotScale,1),"%\n");
    Append(text,"MaxMargin:      "+DoubleToStr(Master[Action].MaxMargin,1),"\n");
    Append(text,"DefaultLotSize: "+DoubleToStr(Master[Action].DefaultLotSize,Account.LotPrecision),"\n");
    Append(text,"DefaultStop:    "+DoubleToStr(Master[Action].DefaultStop,1),"\n");
    Append(text,"DefaultTarget:  "+DoubleToStr(Master[Action].DefaultTarget,1),"\n");
    Append(text,"StopLoss:       "+DoubleToStr(Master[Action].StopLoss,Digits),"\n");
    Append(text,"TakeProfit:     "+DoubleToStr(Master[Action].TakeProfit,Digits),"\n");
    Append(text,"HideStop:       "+BoolToStr(Master[Action].HideStop,InYesNo),"\n");
    Append(text,"HideTarget:     "+BoolToStr(Master[Action].HideTarget,InYesNo),"\n");
    Append(text,"Step:           "+DoubleToStr(Master[Action].ZoneSize,1),"\n");

    return (text);
  }

//+------------------------------------------------------------------+
//| SummaryStr - Returns formatted Net Summary for all open trades   |
//+------------------------------------------------------------------+
string COrder::SummaryStr(void)
  {
    string text      = "\n";
    
    Append(text,"===== Master Summary Detail =====","\n");

    for (SummaryType type=0;type<Total;type++)
      Append(text,SummaryLineStr(EnumToString(type),Summary[type],Always),"\n");

    return (text);
  }

//+------------------------------------------------------------------+
//| ZoneSummaryStr - Returns the formstted Zone Summary by Action    |
//+------------------------------------------------------------------+
string COrder::ZoneSummaryStr(int Action=NoAction)
  {
    string text     = "\n";
    
    for (int action=OP_BUY;action<=OP_SELL;action++)
      if (Master[action].Summary[Net].Count>0)
        if (IsEqual(action,Action)||IsEqual(Action,NoAction))
        {
          Append(text,"===== "+proper(ActionText(action))+" Master Zone Detail =====","\n");

          for (int node=0;node<ArraySize(Master[action].Zone);node++)
            Append(text,SummaryLineStr("Zone["+IntegerToString(Master[action].Zone[node].Zone,3)+"]",Master[action].Zone[node]),"\n");
        }

    return (text);
  }

//+------------------------------------------------------------------+
//| SnapshotStr - Prints the formatted Snapshot Text                 |
//+------------------------------------------------------------------+
string COrder::SnapshotStr(void)
  {
    string text       = "\n";
    
    for (int type=OP_BUY;type<=OP_SELLSTOP;type++)
    {
      Append(text,ActionText(type),"\n");
    
      for (QueueStatus status=Initial;status<QueueStates;status++)
      {
        Append(text,EnumToString(status)+":"+(string)Snapshot[status].Type[type].Count,"[");
        Append(text,"Lots:"+DoubleToStr(Snapshot[status].Type[type].Lots,Account.LotPrecision),":");
        Append(text,"Profit:"+DoubleToStr(Snapshot[status].Type[type].Profit,2)+"]",":");
      }
    }

    return(text);
  }

//+------------------------------------------------------------------+
//| IsChanged - Compares events to determine if a change occurred    |
//+------------------------------------------------------------------+
bool COrder::IsChanged(QueueStatus &Compare, QueueStatus Value)
  {
    if (IsEqual(Compare,Value))
      return (false);

    Compare = Value;
    return (true);
  }
