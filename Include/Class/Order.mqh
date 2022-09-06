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

#define ByZone    0
#define ByTicket  1
#define ByAction  2
#define ByProfit  3
#define ByLoss    4
#define ByMethod  5

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

  //-- Trade Manager States
  enum                OrderMethod
                      {
                        Hold,          // Hold (unless max risk)
                        Full,          // Close whole orders
                        Split,         // Close half orders 
                        Retain,        // Close half orders and hold
                        DCA,           // Close profit on DCA
                        Recapture,     // Close on position equity advance
                        Kill,          // Close on market
                        Halt,          // Suspend trading
                        OrderMethods
                      };

  //--- Queue Statuses
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

private:

  //--- Order Metrics
  enum                MarginType
                      {
                        Margin,
                        MarginLong,
                        MarginShort
                      };

  struct              AccountMetrics
                      {
                        bool            TradeEnabled;
                        BrokerModel     MarginModel;
                        double          MaxRisk;
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

  struct              QueueSnapshot
                      {
                        int             Count;             //-- Status by Order Type
                        double          Lots;              //-- Lots by Order Type
                        double          Profit;            //-- Value by Order Type
                      };

  struct              QueueSummary
                      {
                        QueueSnapshot   Type[6];
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
                        double         DCATarget;             //-- Minimum Equity target for DCA
                        //-- Risk Management
                        double         MaxRisk;               //-- Max Principle Risk
                        double         LotScale;              //-- LotSize scaling factor in Margin
                        double         MaxMargin;             //-- Max Margin by Action
                        double         MaxZoneMargin;         //-- Max Margin by Action/Zone
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
                        int            TicketMax;             //-- Ticket w/Highest Profit
                        int            TicketMin;             //-- Ticket w/Least Profit
                        //-- Summarized Data & Arrays
                        double         DCA;                   //-- Calculated live DCA
                        OrderDetail    Order[];               //-- Order details by ticket/action
                        OrderSummary   Zone[];                //-- Aggregate order detail by order zone
                        OrderSummary   Entry;                 //-- Entry Zone Summary
                        OrderSummary   Summary[Total];        //-- Order Summary by Action
                      };

          //-- Data Collections
          OrderLog        Log[];
          OrderRequest    Queue[];
          OrderMaster     Master[2];
          OrderSummary    Summary[Total];
          QueueSummary    Snapshot[QueueStates];

          AccountMetrics  Account;
          
          int          EquityHold;

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
          void         UpdateAccount(void);
          void         UpdateMaster(void);
          void         UpdateOrder(OrderDetail &Order, QueueStatus Status);

          OrderRequest SubmitOrder(OrderRequest &Request, bool Resubmit=false);

          OrderDetail  MergeRequest(OrderRequest &Request, bool Split=false);
          void         MergeOrder(int Action, int Ticket);
          void         MergeSplit(OrderDetail &Order);

          bool         OrderApproved(OrderRequest &Request);
          bool         OrderOpened(OrderRequest &Request);
          bool         OrderClosed(OrderDetail &Order);

          void         AdverseEquityHandler(void);

          void         ProcessRequests(void);
          void         ProcessProfits(int Action);
          void         ProcessLosses(int Action);

public:

                       COrder(BrokerModel Model, OrderMethod Long, OrderMethod Short);
                      ~COrder();

          void         Update(void);
          void         ExecuteOrders(int Action);
          void         ExecuteRequests(void);

          bool         Enabled(int Action);
          bool         Enabled(OrderRequest &Request);

          void         Enable(void)                 {Account.TradeEnabled=true;};
          void         Disable(void)                {Account.TradeEnabled=false;};
          void         Enable(int Action)           {Master[Action].TradeEnabled=true;};
          void         Disable(int Action)          {Master[Action].TradeEnabled=false;};

          //-- Order properties
          double       Price(SummaryType Type, int Action, double Requested, double Basis=0.00);
          double       LotSize(int Action, double Lots=0.00);
          double       Margin(int Format=InPercent)                          {return(Account.Margin*BoolToInt(IsEqual(Format,InPercent),100,1));};
          double       Margin(double Lots, int Format=InPercent)             {return(Calc(Margin,Lots,Format));};
          double       Margin(int Action, double Lots, int Format=InPercent) {return(Calc((MarginType)BoolToInt(IsEqual(Operation(Action),OP_BUY),MarginLong,MarginShort),Lots,Format));};
          double       Margin(int Type, QueueStatus Status, int Format=InPercent)
                                                                             {return(Calc((MarginType)BoolToInt(IsEqual(Operation(Type),OP_BUY),MarginLong,MarginShort),
                                                                                     Snapshot[Status].Type[Operation(Type)].Lots,Format));};
          double       Equity(double Value, int Format=InPercent);
          double       DCA(int Action)                                       {return(NormalizeDouble(Master[Action].DCA,Digits));};

          //-- Order methods
          void         Cancel(int Action, string Reason="");
          void         Cancel(OrderRequest &Request, QueueStatus Status, string Reason="");

          bool         Status(QueueStatus State, int Type=OP_NO_ACTION);
          bool         Pending(int Type=OP_NO_ACTION)            {return(Status(Pending,Type));};
          bool         Canceled(int Type=OP_NO_ACTION)           {return(Status(Canceled,Type));};
          bool         Declined(int Type=OP_NO_ACTION)           {return(Status(Declined,Type));};
          bool         Rejected(int Type=OP_NO_ACTION)           {return(Status(Rejected,Type));};
          bool         Expired(int Type=OP_NO_ACTION)            {return(Status(Expired,Type));};
          bool         Fulfilled(int Type=OP_NO_ACTION)          {return(Status(Fulfilled,Type));};
          bool         Qualified(int Type=OP_NO_ACTION)          {return(Status(Qualified,Type));};
          bool         Processing(int Type=OP_NO_ACTION)         {return(Status(Processing,Type));};
          bool         Processed(int Type=OP_NO_ACTION)          {return(Status(Processed,Type));};
          bool         Closed(int Type=OP_NO_ACTION)             {return(Status(Closed,Type));};
          bool         Submitted(OrderRequest &Request);
          

          //-- Order Property Methods
          OrderRequest BlankRequest(string Requestor);
          OrderRequest Request(int Key, int Ticket=NoValue);
          OrderDetail  Ticket(int Ticket);
          OrderDetail  Ticket(int Action, MeasureType Measure)   {if (IsEqual(Measure,Min)) 
                                                                   return(Ticket(Master[Action].TicketMin)); 
                                                                   return(Ticket(Master[Action].TicketMax));};

          OrderSummary PL(int Action, SummaryType Type)          {return(Master[Action].Summary[Type]);};
          OrderSummary Entry(int Action)                         {return(Master[Action].Entry);};

          void         GetZone(int Action, int Zone, OrderSummary &Node);
          int          Zones(int Action) {return (ArraySize(Master[Action].Zone));};
          int          Zone(int Action, double Price=0.00);

          //-- Configuration methods
          void         SetOrderMethod(int Action, OrderMethod Method, int ByType, int ByValue=NoValue);
          void         SetDefaultMethod(int Action, OrderMethod Method, bool UpdateExisting=true);
          void         SetStopLoss(int Action, double StopLoss, double DefaultStop, bool HideStop, bool FromClose=true);
          void         SetTakeProfit(int Action, double TakeProfit, double DefaultTarget, bool HideTarget, bool FromClose=true);
          void         SetEquityTargets(int Action, double EquityTarget, double EquityMin);
          void         SetRiskLimits(int Action, double MaxRisk, double MaxMargin, double LotScale=0.00);
          void         SetDefaults(int Action, double DefaultLotSize, double DefaultStop, double DefaultTarget);
          void         SetZoneLimits(int Action, double Step, double MaxZoneMargin);
          void         SetEquityHold(int Action) {EquityHold=Operation(Action);};

          //-- Formatted Output Text
          void         PrintLog(void);

          string       OrderDetailStr(OrderDetail &Order);
          string       OrderStr(int Action=OP_NO_ACTION);
          string       RequestStr(OrderRequest &Request);
          string       QueueStr(int Action=OP_NO_ACTION, bool Force=false);
          string       SummaryLineStr(string Description, OrderSummary &Line, bool Force=false);
          string       SummaryStr(void);
          string       ZoneSummaryStr(int Action=OP_NO_ACTION);
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
                             case InDecimal: return (NormalizeDouble(fdiv(Lots,Account.LotSizeMin)*Account.LotMargin/Account.EquityBalance,3));
                             case InPercent: return (NormalizeDouble(fdiv(Lots,Account.LotSizeMin)*Account.LotMargin/Account.EquityBalance*100,1));
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
    Master[Action].TradeEnabled    = !IsEqual(Master[Action].Method,Halt);
    Master[Action].EquityTarget    = 0.00;
    Master[Action].EquityMin       = 0.00;
    Master[Action].DCATarget       = 0.00;
    Master[Action].MaxRisk         = 0.00;
    Master[Action].LotScale        = 0.00;
    Master[Action].MaxMargin       = 0.00;
    Master[Action].MaxZoneMargin   = 0.00;      
    Master[Action].DefaultLotSize  = 0.00;
    Master[Action].DefaultStop     = 0.00;
    Master[Action].DefaultTarget   = 0.00;
    Master[Action].StopLoss        = 0.00;
    Master[Action].TakeProfit      = 0.00;
    Master[Action].HideStop        = false;
    Master[Action].HideTarget      = false;
    Master[Action].Step            = 0.00;
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
    //-- Account Information frame
    UpdateLabel("lbvAI-Bal",LPad(DoubleToStr(Account.Balance,0)," ",11),Color(Summary[Net].Equity),16,"Consolas");
    UpdateLabel("lbvAI-Eq",LPad(NegLPad(Account.Equity,0)," ",11),Color(Summary[Net].Equity),16,"Consolas");
    UpdateLabel("lbvAI-EqBal",LPad(DoubleToStr(Account.EquityBalance,0)," ",11),Color(Summary[Net].Equity),16,"Consolas");
     
    UpdateLabel("lbvAI-Eq%",center(DoubleToStr(Account.EquityClosed*100,1),7)+"%",Color(Summary[Net].Equity),16);
    UpdateLabel("lbvAI-EqOpen%",center(DoubleToStr(Account.EquityOpen*100,1),6)+"%",Color(Summary[Net].Equity),12);
    UpdateLabel("lbvAI-EqVar%",center(DoubleToStr(Account.EquityVariance*100,1),6)+"%",Color(Summary[Net].Equity),12);
    UpdateLabel("lbvAI-Spread",LPad(DoubleToStr(pip(Account.Spread),1)," ",5),Color(Summary[Net].Equity),14);
    UpdateLabel("lbvAI-Margin",LPad(DoubleToStr(Account.Margin*100,1)+"%"," ",6),Color(Summary[Net].Equity),14);

    UpdateDirection("lbvAI-OrderBias",Direction(Summary[Net].Lots),Color(Summary[Net].Lots),30);

    //-- Account Configuration
    UpdateLabel("lbvAC-Trading",BoolToStr(Account.TradeEnabled,"Enabled","Halted"),Color(BoolToInt(Account.TradeEnabled,1,NoValue)));
    UpdateLabel("lbvAC-Options","");

    for (int action=0;action<=2;action++)
      if (action<=OP_SELL)
      {
        UpdateLabel("lbvAI-"+proper(ActionText(action))+"#",IntegerToString(Master[action].Summary[Net].Count,2),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-"+proper(ActionText(action))+"L",LPad(DoubleToStr(Master[action].Summary[Net].Lots,2)," ",6),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-"+proper(ActionText(action))+"V",LPad(DoubleToStr(Master[action].Summary[Net].Value,0)," ",10),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-"+proper(ActionText(action))+"M",LPad(DoubleToStr(Master[action].Summary[Net].Margin,1)," ",5),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-"+proper(ActionText(action))+"E",LPad(DoubleToStr(Master[action].Summary[Net].Equity,1)," ",5),clrDarkGray,10,"Consolas");
      }
      else
      {
        UpdateLabel("lbvAI-Net#",IntegerToString(Summary[Net].Count,2),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-NetL",LPad(DoubleToStr(Summary[Net].Lots,2)," ",6),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-NetV",LPad(DoubleToStr(Summary[Net].Value,0)," ",10),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-NetM",LPad(DoubleToStr(Summary[Net].Margin,1)," ",5),clrDarkGray,10,"Consolas");
        UpdateLabel("lbvAI-NetE",LPad(DoubleToStr(Summary[Net].Equity,1)," ",5),clrDarkGray,10,"Consolas");
      }

    //-- Order Config by Action frames
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      UpdateLabel("lbvOC-"+ActionText(action)+"-Enabled",BoolToStr(Master[action].TradeEnabled,"Enabled "+EnumToString(Master[action].Method),"Disabled"),
                     BoolToInt(Master[action].TradeEnabled,clrLawnGreen,clrDarkGray));
      UpdateLabel("lbvOC-"+ActionText(action)+"-EqTarget",center(DoubleToStr(Master[action].EquityTarget,1)+"%",7),clrDarkGray,10);
      UpdateLabel("lbvOC-"+ActionText(action)+"-EqMin",center(DoubleToStr(Master[action].EquityMin,1)+"%",6),clrDarkGray,10);
      UpdateLabel("lbvOC-"+ActionText(action)+"-Target",center(DoubleToStr(Price(Profit,action,0.00),Digits),9),clrDarkGray,10);
      UpdateLabel("lbvOC-"+ActionText(action)+"-DfltTarget","Default "+DoubleToStr(Master[action].TakeProfit,Digits)+" ("+DoubleToStr(Master[action].DefaultTarget,1)+"p)",clrDarkGray,8);
      UpdateLabel("lbvOC-"+ActionText(action)+"-MaxRisk",center(DoubleToStr(Master[action].MaxRisk,1)+"%",6),clrDarkGray,10);
      UpdateLabel("lbvOC-"+ActionText(action)+"-MaxMargin",center(DoubleToStr(Master[action].MaxMargin,1)+"%",6),clrDarkGray,10);
      UpdateLabel("lbvOC-"+ActionText(action)+"-Stop",center(DoubleToStr(Price(Loss,action,0.00),Digits),9),clrDarkGray,10);
      UpdateLabel("lbvOC-"+ActionText(action)+"-DfltStop","Default "+DoubleToStr(Master[action].StopLoss,Digits)+" ("+DoubleToStr(Master[action].DefaultStop,1)+"p)",clrDarkGray,8);
      UpdateLabel("lbvOC-"+ActionText(action)+"-EQBase",DoubleToStr(Account.NetProfit[action],0)+" ("+DoubleToStr(fdiv(Account.NetProfit[action],Account.Balance)*100,1)+"%)",clrDarkGray,10);
      UpdateLabel("lbvOC-"+ActionText(action)+"-DCA",DoubleToStr(Master[action].DCA,Digits)+BoolToStr(IsEqual(Master[action].DCATarget,0.00),"","("+DoubleToStr(Master[action].DCATarget,1)+"%)"),clrDarkGray,10);
      UpdateLabel("lbvOC-"+ActionText(action)+"-LotSize",center(DoubleToStr(LotSize(action),Account.LotPrecision),7),clrDarkGray,10);
      UpdateLabel("lbvOC-"+ActionText(action)+"-MinLotSize",center(DoubleToStr(Account.LotSizeMin,Account.LotPrecision),6),clrDarkGray,10);
      UpdateLabel("lbvOC-"+ActionText(action)+"-MaxLotSize",center(DoubleToStr(Account.LotSizeMax,Account.LotPrecision),7),clrDarkGray,10);
      UpdateLabel("lbvOC-"+ActionText(action)+"-DfltLotSize",BoolToStr(IsEqual(Master[action].LotScale,0.00),"Default "+DoubleToStr(Master[action].DefaultLotSize,Account.LotPrecision),
                                                   "Scaled "+DoubleToStr(Master[action].LotScale,1)+"%"),clrDarkGray,8);
      UpdateLabel("lbvOC-"+ActionText(action)+"-ZoneStep",center(DoubleToStr(Master[action].Step,1),6),clrDarkGray,10);
      UpdateLabel("lbvOC-"+ActionText(action)+"-MaxZoneMargin",center(DoubleToStr(Master[action].MaxZoneMargin,1)+"%",5),clrDarkGray,10);
      UpdateLabel("lbvOC-"+ActionText(action)+"-ZoneNow",center((string)Zone(action),8),clrDarkGray,10);
    }
    
    //-- Order Zone metrics by Action
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      int node          = 0;
      int row           = 0;
      int ticket        = 0;

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
          UpdateLabel("lbvOZ-"+ActionText(action)+(string)row+"E",NegLPad(Master[action].Zone[node].Equity,1),nodecolor,9,"Consolas");
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
          UpdateLabel("lbvOQ-"+ActionText(action)+(string)row+"-State",BoolToStr(IsEqual(detail.Status,Working),
                         BoolToStr(IsEqual(action,EquityHold),CharToStr(149)+"Hold",
                         BoolToStr(IsEqual(detail.Method,Hold),CharToStr(149)+"Hold",EnumToString(detail.Method))),EnumToString(detail.Status)),
                         BoolToInt(IsEqual(action,EquityHold),clrYellow,clrDarkGray),9,"Consolas");
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
    for (int request=0;request<25;request++)
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
        UpdateLabel("lbvRQ-"+(string)request+"-Limit",DoubleToStr(Queue[request].Pend.Limit,Digits),clrDarkGray);
        UpdateLabel("lbvRQ-"+(string)request+"-Cancel",DoubleToStr(Queue[request].Pend.Cancel,Digits),clrDarkGray);
        UpdateLabel("lbvRQ-"+(string)request+"-Resubmit",proper(ActionText(Queue[request].Pend.Type)),clrDarkGray);
        
        if (IsEqual(Queue[request].Pend.Type,OP_NO_ACTION))
          UpdateLabel("lbvRQ-"+(string)request+"-Step"," 0.00",clrDarkGray);
        else
          UpdateLabel("lbvRQ-"+(string)request+"-Step",LPad(DoubleToStr(BoolToDouble(IsEqual(Queue[request].Pend.Step,0.00),
                     Master[Operation(Queue[request].Pend.Type)].Step,Queue[request].Pend.Step,1),1)," ",4),
                     BoolToInt(IsEqual(Queue[request].Pend.Step,0.00),clrYellow,clrDarkGray));
                     
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
        UpdateLabel("lbvRQ-"+(string)request+"-Limit","");
        UpdateLabel("lbvRQ-"+(string)request+"-Cancel","");
        UpdateLabel("lbvRQ-"+(string)request+"-Resubmit","");
        UpdateLabel("lbvRQ-"+(string)request+"-Step","");
        UpdateLabel("lbvRQ-"+(string)request+"-Memo","");
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
          if (IsEqual(Queue[request].Type,OP_NO_ACTION))
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
      usHighBound[action]                = BoolToDouble(IsEqual(action,OP_BUY),Ask,Bid)+(point(Master[action].Step*0.9,8));
      usLowBound[action]                 = BoolToDouble(IsEqual(action,OP_BUY),Ask,Bid)-(point(Master[action].Step*0.9,8));

      Master[action].TicketMin           = NoValue;
      Master[action].TicketMax           = NoValue;

      for (SummaryType type=0;type<Total;type++)
      {
        InitSummary(Summary[type]);
        InitSummary(Master[action].Summary[type]);
      }

      InitSummary(Master[action].Entry,Zone(action,BoolToDouble(IsEqual(action,OP_BUY),Ask,Bid,Digits)));
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
            ArrayResize(Master[action].Entry.Ticket,++Master[action].Entry.Count,100);
            Master[action].Entry.Lots             += Master[action].Order[detail].Lots;
            Master[action].Entry.Value            += Master[action].Order[detail].Profit;
            Master[action].Entry.Ticket[Master[action].Entry.Count-1] = Master[action].Order[detail].Ticket;
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

      Master[action].Entry.Equity                  = Equity(Master[action].Entry.Value,InPercent);
      Master[action].Entry.Margin                  = fdiv(Master[action].Entry.Lots,Master[action].Summary[Net].Lots)*Master[action].Summary[Net].Margin;
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
void COrder::UpdateAccount(void)
  {
    Account.Variance                = Account.Balance-(AccountBalance()+AccountCredit());
    Account.Balance                 = AccountBalance()+AccountCredit();
    Account.EquityOpen              = NormalizeDouble((AccountEquity()-(AccountBalance()+AccountCredit()))/AccountEquity(),3);
    Account.EquityClosed            = NormalizeDouble((AccountEquity()-(AccountBalance()+AccountCredit()))/(AccountBalance()+AccountCredit()),3);
    Account.EquityVariance          = NormalizeDouble(Account.EquityOpen-Account.EquityClosed,3);
    Account.EquityBalance           = NormalizeDouble(AccountEquity(),2);
    Account.Spread                  = NormalizeDouble(Ask-Bid,Digits);
    Account.Equity                  = NormalizeDouble(Account.EquityBalance-Account.Balance,2);
    Account.Margin                  = NormalizeDouble(AccountMargin()/AccountEquity(),3);
    Account.LotMargin               = NormalizeDouble(BoolToDouble(Symbol()=="USDJPY",(MarketInfo(Symbol(),MODE_LOTSIZE)*MarketInfo(Symbol(),MODE_MINLOT)),
                                        (MarketInfo(Symbol(),MODE_LOTSIZE)*MarketInfo(Symbol(),MODE_MINLOT)*Close[0]))/AccountLeverage(),2);
    Account.MarginHedged            = fdiv(MarketInfo(Symbol(),MODE_MARGINHEDGED),MarketInfo(Symbol(),MODE_LOTSIZE),2);
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
        if (IsEqual(Symbol(),OrderSymbol(),false))
          MergeOrder(OrderType(),OrderTicket());

    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      ArrayResize(updated,0,1000);
      
      Master[action].DCA                           = 0.00;

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

      Master[action].DCA      = BoolToDouble(IsEqual(action,OP_BUY),Bid,Ask)
                                  -fdiv((lots*BoolToDouble(IsEqual(action,OP_BUY),Bid,Ask))-extended,lots);
      
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
//| SubmitOrder - Adds screened orders to Request Processing Queue   |
//+------------------------------------------------------------------+
OrderRequest COrder::SubmitOrder(OrderRequest &Request, bool Resubmit=false)
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
                                               point(Master[Operation(Request.Pend.Type)].Step),
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
          Queue[request].Memo         = "Invalid stop/limit price";
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
OrderDetail COrder::MergeRequest(OrderRequest &Request, bool Split=false)
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

    AppendLog(NoValue,Ticket,"[Order["+(string)Ticket+"]:Merged");
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

        AppendLog(NoValue,OrderTicket(),"[Split["+(string)Order.Ticket+"]:"+(string)OrderTicket());
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

                        if (IsLower(Margin(Request.Action,Snapshot[Pending].Type[Request.Action].Lots+
                                      LotSize(Request.Action,Request.Lots),InPercent)-MarginTolerance,
                                      Master[Request.Action].MaxMargin,NoUpdate))
                          return (IsChanged(Request.Status,Approved));

                        Request.Memo       = "Margin limit "+DoubleToStr(Master[Request.Action].MaxMargin,1)+"% exceeded ["+
                                                DoubleToStr(Margin(Request.Action,Snapshot[Pending].Type[Request.Action].Lots+
                                                LotSize(Request.Action,Request.Lots),InPercent),1)+"%]";
                        break;

        case Immediate: Request.Status     = Declined;
        
                        if (IsLower(Margin(Request.Action,Master[Request.Action].Summary[Net].Lots+
                                      LotSize(Request.Action,Request.Lots),InPercent)-MarginTolerance,
                                      Master[Request.Action].MaxMargin,NoUpdate))
                        {

                          if (IsLower(Entry(Request.Action).Margin,Master[Request.Action].MaxZoneMargin,NoUpdate))
                            return (IsChanged(Request.Status,Approved));

                          Request.Memo     = "Margin Zone limit "+DoubleToStr(Master[Request.Action].MaxZoneMargin,1)+"% exceeded ["+
                                                DoubleToStr(Entry(Request.Action).Margin,1)+"%]";
                        }
                        else
                          Request.Memo     = "Margin limit "+DoubleToStr(Master[Request.Action].MaxMargin,1)+"% exceeded ["+
                                                DoubleToStr(Margin(Request.Action,Master[Request.Action].Summary[Net].Lots+
                                                LotSize(Request.Action,Request.Lots),InPercent),1)+"%]";
                        break;

        default:        Request.Status     = Rejected;
                        Request.Memo       = "Request not pending ["+EnumToString(Request.Status)+"]";
      }
    }
    else Request.Status                    = Rejected;

    AppendLog(Request.Key,NoValue,"[Approval]"+Request.Memo);

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
    double split                = fdiv(LotSize(Order.Action),2,Account.LotPrecision);
    double lots                 = BoolToDouble(IsBetween(Order.Method,Split,Retain),                                //-- If Split/Retain
                                    LotSize(Order.Action,fmin(fdiv(Order.Lots,2),fmax(split,fdiv(Order.Lots,2)))),  //--   Calculate Split Lots
                                    Order.Lots,Account.LotPrecision);                                               //-- else use Order Lots
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
//| AdverseEquityHandler - Kills and halts system                     |
//+------------------------------------------------------------------+
void COrder::AdverseEquityHandler(void)
  {
    double maxrisk                = -(Account.MaxRisk);

    if (IsLower(Summary[Net].Equity,maxrisk))
    {
      for (int action=OP_BUY;action<OP_SELL;action++)
      {
        for (int ticket=0;ticket<Master[action].Summary[Net].Count;ticket++)
          Master[action].Order[ticket].Method   = Kill;
          
        ProcessLosses(action);
      }
      
      Disable();
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

    for (int request=0;request<ArraySize(Queue);request++)
    {
      double price                                     = BoolToDouble(IsEqual(Queue[request].Action,OP_BUY),Ask,Bid);
      
      if (IsEqual(Queue[request].Status,Fulfilled))    //-- Complete Request
        Queue[request].Status                          = Completed;
      else
      if (IsEqual(Queue[request].Status,Pending))
        if (TimeCurrent()>Queue[request].Expiry)       //-- Expire Pending Orders
          Cancel(Queue[request],Expired,"Request expired");
        else
        if (IsBetween(price,
           BoolToDouble(IsEqual(Queue[request].Pend.Limit,0.00),price,Queue[request].Pend.Limit),
           BoolToDouble(IsEqual(Queue[request].Pend.Cancel,0.00),price,Queue[request].Pend.Cancel)))
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
        }
        else Cancel(Queue[request],Expired,"Limit/Cancel bounds exceeded");
      else
        if (TimeCurrent()>Queue[request].Expiry+(Period()*60))
          Queue[request].Status                        = Completed;
      
      if (IsEqual(Queue[request].Status,Immediate))
        if (OrderApproved(Queue[request]))
          if (OrderOpened(Queue[request]))
          {
            //-- Resubmit Queued Pending Orders
            if (IsBetween(Queue[request].Pend.Type,OP_BUYLIMIT,OP_SELLSTOP))
              SubmitOrder(Queue[request],true);

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
//| ProcessProfits - Handles profit using config by action           |
//+------------------------------------------------------------------+
void COrder::ProcessProfits(int Action)
  {
    double netEquity     = 0.00;
    double netDCA        = 0.00;
    double netRecapture  = 0.00;

    //-- Early exit on Equity Hold
    if (IsEqual(Action,EquityHold))
      return;
      
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
      if (IsEqual(Master[Action].Order[ticket].Status,Working))
      {
        //-- Handle Kills first
        if (IsEqual(Master[Action].Order[ticket].Method,Kill))
          Master[Action].Order[ticket].Status  = Processing;
        else
      
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
//| Constructor                                                      |
//+------------------------------------------------------------------+
COrder::COrder(BrokerModel Model, OrderMethod Long, OrderMethod Short)
  {
    //-- Initialize Account
    Account.MarginModel    = Model;
    Account.TradeEnabled   = !(IsEqual(Long,Halt)&&IsEqual(Short,Halt));
    Account.MaxSlippage    = 3;

    Account.Balance        = AccountBalance()+AccountCredit();

    Account.LotSizeMin     = NormalizeDouble(MarketInfo(Symbol(),MODE_MINLOT),2);
    Account.LotSizeMax     = NormalizeDouble(MarketInfo(Symbol(),MODE_MAXLOT),2);
    Account.LotPrecision   = BoolToInt(IsEqual(Account.LotSizeMin,0.01),2,1);

    InitMaster(OP_BUY,Long);
    InitMaster(OP_SELL,Short);

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
void COrder::Update(void)
  {
    PurgeLog();
    
    //-- Reconcile
    UpdateAccount();
    UpdateMaster();
    UpdateSummary();
    UpdateSnapshot();
    
    AdverseEquityHandler();
    
    UpdatePanel();
  }

//+------------------------------------------------------------------+
//| ExecuteRequests - Processes the Order Request Queue              |
//+------------------------------------------------------------------+
void COrder::ExecuteRequests(void)
  {  
    ProcessRequests();

    UpdatePanel();
  }

//+------------------------------------------------------------------+
//| ExecuteOrders - Updates/Closes orders by Action                  |
//+------------------------------------------------------------------+
void COrder::ExecuteOrders(int Action)
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
//| Enabled - returns true if trade is open for supplied Action      |
//+------------------------------------------------------------------+
bool COrder::Enabled(int Action)
  {
    if (Account.TradeEnabled)
      if (IsBetween(Action,OP_BUY,OP_SELL))
        if (Master[Action].TradeEnabled)
          return (true);

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
double COrder::Price(SummaryType Type, int RequestType, double Requested, double Basis=0.00)
  {
    //-- Set Initial Values
    int    action       = Operation(RequestType);
    int    direction    = BoolToInt(IsEqual(action,OP_BUY),DirectionUp,DirectionDown)
                            *BoolToInt(IsEqual(Type,Profit),DirectionUp,DirectionDown);

    Basis               = BoolToDouble(IsEqual(Basis,0.00),BoolToDouble(IsEqual(action,OP_BUY),Bid,Ask),Basis,Digits);

    double requested    = fmax(0.00,Requested);
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

      return (Coalesce(requested,stored,calculated));
    }
    
    return (0.00);
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
//| LotSize - returns optimal lot size                               |
//+------------------------------------------------------------------+
double COrder::LotSize(int Action, double Lots=0.00)
  {
    if (IsBetween(Action,OP_BUY,OP_SELLSTOP))
    {
      if (IsEqual(Master[Operation(Action)].DefaultLotSize,0.00,Account.LotPrecision))
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
        Lots = NormalizeDouble(Master[Operation(Action)].DefaultLotSize,Account.LotPrecision);

      Lots   = fmin((Account.Balance*(Master[Operation(Action)].LotScale/100))/MarketInfo(Symbol(),MODE_MARGINREQUIRED),Account.LotSizeMax);
    }
    else return (NormalizeDouble(0.00,Account.LotPrecision));

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
            Queue[request].Memo     = BoolToStr(IsEqual(StringLen(Reason),0),Queue[request].Memo,Reason);
          }
  }

//+------------------------------------------------------------------+
//| Cancel - Cancels pending limit order Request                     |
//+------------------------------------------------------------------+
void COrder::Cancel(OrderRequest &Request, QueueStatus Status, string Reason="")
  {
    Request.Status           = Status;
    Request.Memo             = BoolToStr(IsEqual(StringLen(Reason),0),Request.Memo,Reason);
  }

//+------------------------------------------------------------------+
//| Status - True on Order/Request Status by Type on current tick    |
//+------------------------------------------------------------------+
bool COrder::Status(QueueStatus State, int Type=OP_NO_ACTION)
  {
    if (IsEqual(Type,OP_NO_ACTION))
      for (int type=OP_BUY;type<=OP_SELLSTOP;type++)
        return (Snapshot[State].Type[type].Count>0);

    return (Snapshot[State].Type[Type].Count>0);
  }

//+------------------------------------------------------------------+
//| Submitted - Adds screened orders to the Order Processing Queue   |
//+------------------------------------------------------------------+
bool COrder::Submitted(OrderRequest &Request)
  {
    if (IsEqual(SubmitOrder(Request).Status,Pending))
      return (true);
      
    return (false);
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
    Request.Type             = OP_NO_ACTION;
    Request.Action           = OP_NO_ACTION;
    Request.Requestor        = Requestor;
    Request.Price            = 0.00;
    Request.Lots             = 0.00;
    Request.TakeProfit       = 0.00;
    Request.StopLoss         = 0.00;
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
                  (Master[Action].DCA-(fdiv(point(Master[Action].Step),2))*Direction(Action,InAction));

      return (BoolToInt(IsEqual(Action,OP_BUY),(int)floor(fdiv(Price,point(Master[Action].Step),Digits)),
                                               (int)ceil(fdiv(Price,point(Master[Action].Step)))));
    }
    
    return (0);
  }

//+------------------------------------------------------------------+
//| SetOrderMethod - Sets Profit strategy by Action/[Ticket|Zone}    |
//+------------------------------------------------------------------+
void COrder::SetOrderMethod(int Action, OrderMethod Method, int ByType, int ByValue=NoValue)
  {
    OrderSummary zone;
    int          ticket[];
    
    if (IsBetween(Action,OP_BUY,OP_SELL))
    {
      switch (ByType)
      {
        case ByZone:    GetZone(Action,ByValue,zone);
                        ArrayCopy(ticket,zone.Ticket);      
                        break;
        case ByTicket:  ArrayResize(ticket,1,100);
                        ticket[0]                 = ByValue;
                        break;
        case ByAction:  ArrayCopy(ticket,Master[Action].Summary[Net].Ticket);
                        break;
        case ByProfit:  ArrayCopy(ticket,Master[Action].Summary[Profit].Ticket);
                        break;
        case ByLoss:    ArrayCopy(ticket,Master[Action].Summary[Loss].Ticket);
                        break;
        case ByMethod:  for (int index=0;index<ArraySize(Master[Action].Order);index++)
                          if (IsEqual(Master[Action].Order[index].Method,ByValue))
                          {
                            ArrayResize(ticket,ArraySize(ticket)+1,100);
                            ticket[ArraySize(ticket)-1] = ByValue;
                          }
      }

      for (int index=0;index<ArraySize(ticket);index++)
        for (int detail=0;detail<ArraySize(Master[Action].Order);detail++)
          if (IsEqual(Master[Action].Order[detail].Ticket,ticket[index]))
            Master[Action].Order[detail].Method     = (OrderMethod)BoolToInt(IsEqual(Method,Split),BoolToInt(Master[Action].Order[detail].Lots<LotSize(Action),Full,Split),
                                                                   BoolToInt(IsEqual(Method,Retain),BoolToInt(Master[Action].Order[detail].Lots<LotSize(Action),Hold,Retain),Method));
    }
  }

//+------------------------------------------------------------------+
//| SetDefaultMethod - Sets default Profit Taking strategy by Action |
//+------------------------------------------------------------------+
void COrder::SetDefaultMethod(int Action, OrderMethod Method, bool UpdateExisting=true)
  {
     if (IsBetween(Action,OP_BUY,OP_SELL))
     {
       Master[Action].Method            = Method;
     
       if (UpdateExisting)
         SetOrderMethod(Action,Method,ByAction);   
     }
  }

//+------------------------------------------------------------------+
//| SetStopLoss - Sets order stops and hide restrictions             |
//+------------------------------------------------------------------+
void COrder::SetStopLoss(int Action, double StopLoss, double DefaultStop, bool HideStop, bool FromClose=true)
  {
    if (IsBetween(Action,OP_BUY,OP_SELL))
    {
      Master[Action].StopLoss           = fmax(0.00,StopLoss);
      Master[Action].DefaultStop        = fmax(0.00,DefaultStop);
      Master[Action].HideStop           = HideStop;

      for (int detail=0;detail<ArraySize(Master[Action].Order);detail++)
        Master[Action].Order[detail].StopLoss   =
          Price(Loss,Action,StopLoss,BoolToDouble(FromClose,0.00,Master[Action].Order[detail].Price));
    }
  }

//+------------------------------------------------------------------+
//| SetTakeProfit - Sets order targets and hide restrictions         |
//+------------------------------------------------------------------+
void COrder::SetTakeProfit(int Action, double TakeProfit, double DefaultTarget, bool HideTarget, bool FromClose=true)
  {    
    if (IsBetween(Action,OP_BUY,OP_SELL))
    {
      Master[Action].TakeProfit         = fmax(0.00,TakeProfit);
      Master[Action].DefaultTarget      = fmax(0.00,DefaultTarget);
      Master[Action].HideTarget         = HideTarget;

      for (int detail=0;detail<ArraySize(Master[Action].Order);detail++)
        Master[Action].Order[detail].TakeProfit =
          Price(Profit,Action,TakeProfit,BoolToDouble(FromClose,0.00,Master[Action].Order[detail].Price));
    }
  }

//+------------------------------------------------------------------+
//| SetEquityTargets - Configures profit/equity management options   |
//+------------------------------------------------------------------+
void COrder::SetEquityTargets(int Action, double EquityTarget, double EquityMin)
  {
     if (IsBetween(Action,OP_BUY,OP_SELL))
     {
       Master[Action].EquityTarget      = fmax(0.00,EquityTarget);
       Master[Action].EquityMin         = fmax(0.00,EquityMin);
     }
  }

//+------------------------------------------------------------------+
//| SetRiskLimits - Configures risk mitigation management options    |
//+------------------------------------------------------------------+
void COrder::SetRiskLimits(int Action, double MaxRisk, double MaxMargin, double LotScale)
  {
     if (IsBetween(Action,OP_BUY,OP_SELL))
     {
       Master[Action].MaxRisk           = fmax(0.00,MaxRisk);
       Master[Action].MaxMargin         = fmax(0.00,MaxMargin);
       Master[Action].LotScale          = fmax(0.00,LotScale);
     
       Account.MaxRisk                  = BoolToDouble(IsEqual(Action,OP_BUY),
                                            fmax(MaxRisk,Master[OP_SELL].MaxRisk),
                                            fmax(MaxRisk,Master[OP_BUY].MaxRisk));
     }
  }

//+------------------------------------------------------------------+
//| SetDefaults - Sets default order management overrides            |
//+------------------------------------------------------------------+
void COrder::SetDefaults(int Action, double DefaultLotSize, double DefaultStop, double DefaultTarget)
  {
     if (IsBetween(Action,OP_BUY,OP_SELL))
     {
       Master[Action].DefaultLotSize    = fmax(0.00,DefaultLotSize);
       Master[Action].DefaultStop       = fmax(0.00,DefaultStop);
       Master[Action].DefaultTarget     = fmax(0.00,DefaultTarget);
     }
  }

//+------------------------------------------------------------------+
//| SetZoneLimits - Sets step/margin limits for aggregation zones    |
//+------------------------------------------------------------------+
void COrder::SetZoneLimits(int Action, double Step, double MaxZoneMargin)
  {
     if (IsBetween(Action,OP_BUY,OP_SELL))
     {
       Master[Action].Step              = fmax(0.00,Step);
       Master[Action].MaxZoneMargin     = fmax(0.00,MaxZoneMargin);
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
//| OrderDetailStr - Returns formatted Order text                    |
//+------------------------------------------------------------------+
string COrder::OrderDetailStr(OrderDetail &Order)
  {
    string text      = "";

    Append(text,"Status: "+EnumToString(Order.Status)+" ["+EnumToString(Order.Method)+"]");
    Append(text,"Ticket: "+BoolToStr(IsEqual(Master[Order.Action].Summary[Net].Count,1),"[*]",
                              BoolToStr(IsEqual(Order.Ticket,Master[Order.Action].TicketMax),"[+]",
                              BoolToStr(IsEqual(Order.Ticket,Master[Order.Action].TicketMin),"[-]","[ ]")))
                             +IntegerToString(Order.Ticket,10,'0'));
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
string COrder::OrderStr(int Action=OP_NO_ACTION)
  {
    string text       = "\n";

    for (int action=OP_BUY;action<=OP_SELL;action++)
      if (IsEqual(Action,OP_NO_ACTION)||IsEqual(action,Action))
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
      Append(text,"Limit: "+DoubleToStr(Request.Pend.Limit,Digits));
      Append(text,"Cancel: "+DoubleToStr(Request.Pend.Cancel,Digits));
      Append(text,"Step: "+DoubleToStr(Request.Pend.Step,Digits)+"]");
    }
    
    Append(text,Request.Memo);

    return (text);
  }

//+------------------------------------------------------------------+
//| QueueStr - Returns formatted Order Queue text                    |
//+------------------------------------------------------------------+
string COrder::QueueStr(int Action=OP_NO_ACTION, bool Force=false)
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

      if (IsEqual(Action,OP_NO_ACTION))
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
    Append(text,"Step:           "+DoubleToStr(Master[Action].Step,1),"\n");

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
string COrder::ZoneSummaryStr(int Action=OP_NO_ACTION)
  {
    string text     = "\n";
    
    for (int action=OP_BUY;action<=OP_SELL;action++)
      if (Master[action].Summary[Net].Count>0)
        if (IsEqual(action,Action)||IsEqual(Action,OP_NO_ACTION))
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
bool IsChanged(QueueStatus &Compare, QueueStatus Value)
  {
    if (IsEqual(Compare,Value))
      return (false);

    Compare = Value;
    return (true);
  }
