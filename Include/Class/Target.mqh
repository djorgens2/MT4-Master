//+------------------------------------------------------------------+
//|                                                       Target.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class\PipRegression.mqh>
#include <Class\TrendRegression.mqh>
#include <Class\Fractal.mqh>
#include <Class\Order.mqh>

//--- Entry/Exit stated defs
#define stPend                   0
#define stActive                 1
#define stEntry                  2
#define stExit                   3
#define stHold                   4
#define stDCA                    5
#define stStop                   6
#define stBroken                 7
#define stSuspend                8

//+------------------------------------------------------------------+
//| CTarget Class - Currently supports fibo targeting. Later, to be  |
//|                 extended to support independent order management |
//+------------------------------------------------------------------+
class CTarget
  {
  
private:

       //--- Analytics pointers
       CFractal              *tFractal;
       CPipRegression        *tPregr;
       CTrendRegression      *tTregr;


       //--- Fibo price level properties
       bool          IsDCA(void) { if (this.State()==stDCA) return(true); return(false); }
       bool          IsStop(void) { if (this.State()==stStop) return(true); return(false); }

       double        tFiboBase;           //--- Fibonacci base expansion of prior leg; immutable
       double        tFiboRoot;           //--- Fibonacci root origin; immutable
       double        tFiboExpansion;      //--- Fibonacci expansion; current direction; variable
       

       //--- Private methods
       bool          ManageOrders(void);
       void          ManageProfit(void);
       void          ManageRisk(void);
       

       //--- Target properties
       int           tAction;             //--- Target action (buy, sell)
       int           tType;               //--- User defined id
       int           tState;              //--- Target's overall state

       bool          tSuccess;            //--- True when target hits/near misses profit
       bool          tFail;               //--- True when target hits/near misses loss
       datetime      tCreated;            //--- Date/time target was created
       datetime      tUpdated;            //--- Date/time target stated changed
       

       //--- Order management
       COrder       *tOrder[];             //--- Order array
       int           tOrderCount;          //--- Order count

       
       //--- Entry properties
       int           tStopPrice;          //--- The stop price for target orders
       int           tOrderQuota;         //--- Plans current quota


public:
                     CTarget(int Type, CFractal *Fractal, CPipRegression *PipRegression, CTrendRegression *TrendRegression);
                    ~CTarget();

                    
       //--- Target data access methods
       void          Update(void);
       bool          SetPriceBounds(double FiboBase, double FiboRoot, double FiboExpansion);

       //--- Target properties
       int           Action(int Type=InAction, bool Contrarian=false);
       int           Direction(bool Contrarian=false) { return (Action(InDirection, Contrarian)); }
       int           Type(void) { return (tType); }
       int           State(void) { return (tState); }

       bool          ExecuteEntry(double Lots=0.00);
       bool          ExecuteExit(double Lots=0.00);
       bool          EventOpen(void);
       bool          EventClose(void);
       int           OrderCount(void) { return (tOrderCount); }

       //--- Target display properties
       string        Text(int Type, bool Contrarian=false);
       string        PrintTarget(void);
       
       //--- Target event methods
       bool          IsValid(void);
       bool          IsContrarian(void) { if (tType==Divergent || tType==Inversion) return (true); return (false); }
  };


//+------------------------------------------------------------------+
//| ManageRisk - Manages risk exits, order volumes, DCA and Supense  |
//+------------------------------------------------------------------+
 void CTarget::ManageRisk(void)
  {
  }


//+------------------------------------------------------------------+
//| ManageProfit - Manages order profit, takes profit, sets holds    |
//+------------------------------------------------------------------+
 void CTarget::ManageProfit(void)
  {
  }
  
//+------------------------------------------------------------------+
//| EventClose - Signals events to open new orders                   |
//+------------------------------------------------------------------+
 bool CTarget::EventOpen(void)
  {
    return (true);
  }
       
//+------------------------------------------------------------------+
//| EventClose - Signals events requiring closes, profit or loss     |
//+------------------------------------------------------------------+
 bool CTarget::EventClose(void)
  {
    return (true);
  }

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTarget::CTarget(int Type, CFractal *Fractal, CPipRegression *PipRegression, CTrendRegression *TrendRegression)
  {
    tType              = Type;
    tState             = stPend;
    
    tFractal           = Fractal;
    tPregr             = PipRegression;
    tTregr             = TrendRegression;

    if (this.IsValid())
      tUpdated         = TimeCurrent();
    else
      Pause("Target Not Created\n"
           +" Type: "+this.Text()+"\n"
           +" Base: "+DoubleToStr(tFiboBase,Digits)+"\n"
           +" Root: "+DoubleToStr(tFiboRoot,Digits)+"\n"
           +" Expansion: "+DoubleToStr(tFiboExpansion,Digits),
         "Target Creation Error");
  }


//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTarget::~CTarget(void)
  {
    for (int ord=0; ord<tOrderCount; ord++)
      delete tOrder[ord];
  }

  
//+------------------------------------------------------------------+
//| Update - updates the current fibo expansion and retrace          |
//+------------------------------------------------------------------+
void CTarget::Update(void)
  {    
  }


//+------------------------------------------------------------------+
//| ExecuteEntry - Opens a new order                                 |
//+------------------------------------------------------------------+
bool CTarget::ExecuteEntry(double Lots=0.00)
  {
    COrder       *order;
    
    if (EventOpen())
    {
      order                     = new COrder(tAction,Lots);
        
      if (order.IsOpen())
      {
        ArrayResize(tOrder,tOrderCount+1);

        tOrder[tOrderCount++]   = order;

        return (true);
      }
      else
        delete order;
    }
    
    return (false);
  }


//+------------------------------------------------------------------+
//| ExecuteExit - Closes an open order                               |
//+------------------------------------------------------------------+
bool CTarget::ExecuteExit(double Lots=0.00)
  {
    static bool   trigger       = false;
           int    try           = 0;
           int    closeCount    = 0;
    
    if (this.EventClose())
    {
      for (int ord=0;ord<tOrderCount;ord++)
        if (this.State() == stExit)
        {
          try                   = 0;
          
          while (!tOrder[ord].IsSplit() && try++<10)
            tOrder[ord].ExecuteClose(IsContrarian());        

          if (tOrder[ord].IsOpen())
          {}
          else
            closeCount++;
        }
        else
        {
          try                   = 0;
          
          while (tOrder[ord].IsOpen() && try++<10)
            tOrder[ord].ExecuteClose(InContrarian);
            
          if (tOrder[ord].IsOpen())
            Alert("Uh Oh, can't close a DCA");
          else
            closeCount++;
        }
    }
    
    if (closeCount == tOrderCount)
      return (true);
      
    return (false);
  }

//+------------------------------------------------------------------+
//| IsValid - validates key class properties                         |
//+------------------------------------------------------------------+
bool CTarget::IsValid(void)
  { 
    if (tFractal.Direction() == DirectionUp)
      tAction           = OP_BUY;

    if (tFractal.Direction() == DirectionDown)
      tAction           = OP_SELL;
  
    switch(this.Type())
    {
      case Root:        tFiboBase        = tFractal.BasePrice();
                        tFiboRoot        = tFractal.RootPrice();
                        tFiboExpansion   = tFractal.ExpansionPrice();
                        break;
                        
      case Divergent:   tFiboBase        = tFractal.RootPrice();
                        tFiboRoot        = tFractal.ExpansionPrice();
                        tFiboExpansion   = tFractal.RetracePrice(Divergent);
                        tAction          = Action(InAction,InContrarian);
                        break;
                        
      case Convergent:  if (tFractal.IsDivergent())
                        {
                          tFiboBase      = tFractal.ExpansionPrice();
                          tFiboRoot      = tFractal.RetracePrice(Divergent);
                          tFiboExpansion = tFractal.RetracePrice(Convergent);
                          break;
                        }
                        return (false);
                        
      case Inversion:   if (tFractal.IsConvergent())
                        {
                          tFiboBase      = tFractal.RetracePrice(Divergent);
                          tFiboRoot      = tFractal.RetracePrice(Convergent);
                          tFiboExpansion = tFractal.RetracePrice(Inversion);
                          tAction        = Action(InAction,InContrarian);
                          break;
                        }
                        return (false);
                        
      default:          return (false);
    }
      
    tCreated           = TimeCurrent();

    return (true);
  }


//+------------------------------------------------------------------+
//| Action - returns the requested format based on the supplied type |
//+------------------------------------------------------------------+
int CTarget::Action(int Type=InAction, bool Contrarian=false)
  {
    switch (Type)
    {
      case InAction:        switch(tAction)
                            {
                              case     OP_BUY:
                              case     OP_BUYLIMIT:
                              case     OP_BUYSTOP:    if (Contrarian)
                                                        return (OP_SELL+(tAction/2));
                                                      else
                                                        return (tAction);
                              case     OP_SELL:
                              case     OP_SELLLIMIT:
                              case     OP_SELLSTOP:   if (Contrarian)
                                                        return (OP_BUY+(tAction/2));
                                                      else
                                                        return (tAction);

                              default:                return (tAction);
                            }

      case InDirection:     switch(tAction)
                            {
                              case     OP_BUY:
                              case     OP_BUYLIMIT:
                              case     OP_BUYSTOP:    if (Contrarian)
                                                        return (DirectionDown);
                                                      else
                                                        return (DirectionUp);
                              case     OP_SELL:
                              case     OP_SELLLIMIT:
                              case     OP_SELLSTOP:   if (Contrarian)
                                                        return (DirectionUp);
                                                      else
                                                        return (DirectionDown);

                              default:                return (DirectionNone);
                            }
    }
    
    return (NoValue);
  }


//+------------------------------------------------------------------+
//| Text - returns the text description of the supplied type         |
//+------------------------------------------------------------------+
string CTarget::Text(int Type=NoValue, bool Contrarian=false)
  {
    switch (Type)
    {
      case NoValue:         switch (tType)
                            {
                              case Root:          return ("Trend");
                              case Divergent:     return ("Divergent");
                              case Convergent:    return ("Convergent");
                              case Inversion:     return ("Inversion");
                            }
                            
                            return ("Invalid Target Type");
      
      case TextAction:     if (this.Action(InType,Contrarian) == OP_BUY)
                             return ("Buy");
                           else
                             return ("Sell");

      case TextDirection:  if (this.Action(InDirection,Contrarian)== DirectionUp)
                             return ("Long");
                           else
                             return ("Short");

      case TextState:      switch (this.State())
                           {
                             case stPend:           return ("Pending");
                             case stActive:         return ("Active");
                             case stEntry:          return ("Entry");
                             case stHold:           return ("Hold");
                             case stExit:           return ("Exit");
                             case stDCA:            return ("DCA");
                             case stSuspend:        return ("Suspend");
                             case stBroken:         return ("Broken");
                             default:               return ("Bad Target State");
                           }
    }
    
    return ("Bad Text Type");
  }
    
 
//+------------------------------------------------------------------+
//| PrintOrders - Returns a formatted string of all orders           |
//+------------------------------------------------------------------+
string CTarget::PrintTarget(void)
  {
    string targets   = "Updated: "+TimeToStr(tUpdated);
    
    targets += "  "+this.Text(TextAction)
      +"  State: "+this.Text(TextState)
//      +"  Alert: "+BoolToStr(tEntryTrigger)
      +"  brx: "+DoubleToStr(tFiboBase,Digits)+":"+DoubleToStr(tFiboRoot,Digits)+":"+DoubleToStr(tFiboExpansion,Digits);
//      +"  Exp: "+DoubleToStr(tFiboExpansion,Digits)
//      +"  Retrace: "+DoubleToStr(tFiboRetrace,Digits);
                
    return(targets);
  }
