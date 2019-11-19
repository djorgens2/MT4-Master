//+------------------------------------------------------------------+
//|                                                        Order.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <order.mqh>
#include <stdutil.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class COrder
  {
  
private:
  //--- Order Statuses
  enum                OrderState
                      {
                        Waiting,
                        Pending,
                        Requested,
                        Canceled,
                        Approved,
                        Rejected,
                        Fulfilled,
                        Expired,
                        Closed,
                        OrderStates
                      };
                      


          struct OrderRecord
          {  
            //---- Order details
            int        Action;
            int        Ticket;
            double     OpenPrice;
            double     OpenLots;
            int        FractalLeg;
            datetime   OpenTime;
            datetime   CloseTime;

            //---- Profit management details
            double     Profit;
            double     TakeProfit;
            double     ProfitPercent;
            bool       ProfitTaken;
          
            //---- Risk management details
            double     MarginPercent;
            double     StopLoss;
            bool       AtRisk;
          };
        
          //---- Operational variables
          OrderRecord  oOrders[];
          RetraceType  oFractalLeg;
                      
          //---- Account details
          int          oAcctLotPrecision;
          int          oAcctLotSize;
          double       oAcctMinLot;
          double       oAcctMaxLot;
                      

public:
                     COrder(RetraceType FractalLeg);
                    ~COrder();
                    
          //--- Public methods
          void       Update(RetraceType FractalLeg);

          //--- Public properties
          bool       IsSplit(void)  { return (oProfitTaken); }
          int        Position(int Ticket);
          bool       Found(int Ticket) {if (Position(Ticket)==NoValue) return (false); return (true); }
           
          OrderRecord operator[](const int Position) const { return(oOrders[Position]); }
  };


//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
COrder::COrder(RetraceType FractalLeg)
  {
    Update(FractalLeg);
  }
  
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
COrder::~COrder()
  {
  }

//+------------------------------------------------------------------+
//| Position - Returns the position if found in managed order pool   |
//+------------------------------------------------------------------+
int COrder::Position(int Ticket)
  {
    int ioOrderCount = ArraySize(oOrders);
    
    if (OrderSelect(Ticket,SELECT_BY_TICKET,MODE_TRADES))
      for (int pos=0; pos<ioOrderCount; pos++)
        if (oOrders[pos].Ticket==Ticket)
          return (pos);
          
    return (NoValue);
  }

//+------------------------------------------------------------------+
//| NewOrder - adds an order to the managed order pool               |
//+------------------------------------------------------------------+
COrder::Update(RetraceType FractalLeg)
  {
    OrderRecord uOrders[];
    int         uIndex     = 0;
    
    oFractalLeg            = FractalLeg;

    for (int ord=0; ord<OrdersTotal(); ord++)
      if (OrderSelect(ord,SELECT_BY_POS,MODE_TRADES))
        if (OrderSymbol()==Symbol())
        {
          uIndex           = uIndex++;
          ArrayResize(uOrders,uIndex);
          
          if (Found(OrderTicket()))
          {
            uOrders[uIndex].Action        = OrderType();
            uOrders[uIndex].Ticket        = OrderTicket();
            uOrders[uIndex].OpenPrice     = OrderOpenPrice();
            uOrders[uIndex].OpenLots      = OrderLots();
            uOrders[uIndex].Fractal       = FractalLeg;
            uOrders[uIndex].OpenTime      = OrderOpenTime();
            uOrders[uIndex].CloseTime     = 0;
            uOrders[uIndex].ProfitTaken   = false;
            uOrders[uIndex].AtRisk        = false;
          }
          else
            uOrders[uIndex]               = oOrders[Position(OrderTicket())];

          if (OrderSelect(uOrders[uIndex].Ticket,SELECT_BY_TICKET,MODE_HISTORY))
          {
            uOrders[uIndex].CloseTime     = OrderCloseTime();
            uOrders[uIndex].TakeProfit    = OrderTakeProfit();
            uOrders[uIndex].ProfitPercent = TicketValue(OrderTicket(),InEquity);
            
            if (OrderLots()<=HalfLot())
              uOrders[uIndex].ProfitTaken = true;
              
            uOrders[uIndex].StopLoss      = OrderStopLoss();
            
            if (IsChanged(uOrders[uIndex].FractalLeg,FractalLeg) ||
               
               )
            uOrders[uIndex].AtRisk        = OrderType();
          }
        }
      }
    }
  }
