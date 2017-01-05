//+------------------------------------------------------------------+
//|                                                      Manager.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict


//--- Manger params
input string mgrHeader        = "";    // +----- Manager Configuration -----+"
input int    inpAutoTPBuffer  = 20;    // Take Profit buffer (in pips)
input int    inpAutoSLBuffer  = 20;    // Stop Loss buffer (in pips)

//--- PipMA params
input string pipHeader        = "";    // +------ PipMA Configuration ------+"
input int    inpDegree        = 6;     // Degree of polynomial regression
input int    inpPips          = 200;   // Pip change history range
input double inpTolerance     = 0.5;   // Trend change tolerance (sensitivity)

//--- RegrMA params
input string regrHeader        = "";    // +----- RegrMA Configuration -----+"
input int    inpRegrRange      = 24;    // Regression range (in bars)
input int    inpMARange        = 3;     // Moving Average range (smoothing)

#include <Class\Target.mqh>


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CManage
  {
  
private:

          //--- Target pointers
          CTarget           *mtTarget[];   //--- Target list
          COrder            *mtOrder[];    //--- Order list (stored in FIFO)

          CTarget           *mtActive;     //--- Lead target (in Active execution)
          CTarget           *mtBase;       //--- Last target (Basis for managing divergence)

          //--- Analytics pointers
          CFractal          *mtFractal;
          CPipRegression    *mtPregr;
          CTrendRegression  *mtTregr;
          
          //--- Operataional variables
          int        mtTargetCount;        //--- Target counts
          int        mtOrderCount[2];      //--- Order counts by action

          bool       mtHalt;               //--- Halts the system
          bool       mtPeg;                //--- Confirms peg-added target
          bool       mtBreakout;           //--- Confirms breakout-added target


public:
                     CManage(void);
                    ~CManage();

       //--- Manage methods
       void          Update(void);
       void          Orders(void);
       void          Risk(void);
       void          Profit(void);

       bool          AddTarget(int Type);
       void          PrintTargets(void);

              
       //--- Target properties
       int           TargetCount(void) { return (mtTargetCount); }
       int           OrderCount(int Action=NoValue) { switch (Action) 
                                                      {
                                                        case NoValue: return (mtOrderCount[OP_BUY]+mtOrderCount[OP_SELL]);
                                                        case OP_BUY:  return (mtOrderCount[OP_BUY]);
                                                        case OP_SELL: return (mtOrderCount[OP_SELL]);
                                                      }
                                                      
                                                      return (0);
                                                    }

       CTarget*      ActiveTarget(void) { return (mtActive); }
       CTarget*      BaseTarget(void) { return (mtBase); }
       
       CTarget*      operator[](const int index) const { return(mtTarget[index]); }

  };
  

//+------------------------------------------------------------------+
//| AddTarget - creates a new order object and sets fibo targets     |
//+------------------------------------------------------------------+
bool CManage::AddTarget(int Type)
  {
    CTarget *Target = new CTarget(Type,mtFractal,mtPregr,mtTregr);

    if (Target.IsValid())
    {      
      mtBase                     = mtActive;

      ArrayResize(mtTarget,mtTargetCount+1);

      mtTarget[mtTargetCount++]  = Target;
      mtActive                   = Target;
    
      return(true);
    }
    
    delete Target;
    
    return(false);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CManage::CManage(void)
  {
    //--- Initialize operational variables
    mtTargetCount    = 0;
    ArrayInitialize(mtOrderCount,0);
    
    mtActive         = NULL;
    mtBase           = NULL;    

    mtHalt           = true;
    mtPeg            = false;
    mtBreakout       = false;
    
    mtFractal        = new CFractal(inpRange,inpRangeMin);
    mtPregr          = new CPipRegression(inpDegree,inpPips,inpTolerance);
    mtTregr          = new CTrendRegression(inpDegree,inpRegrRange,inpMARange);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CManage::~CManage()
  {
    for (int target=0; target<mtTargetCount; target++)
      delete mtTarget[target];

    delete mtFractal;
    delete mtPregr;
    delete mtTregr;

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CManage::Orders(void)
  {
    for (int target=0; target<mtTargetCount; target++)
    {
      //delete mtTarget[target];
    }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CManage::Risk(void)
  {
    for (int target=0; target<mtTargetCount; target++)
    {
      //delete mtTarget[target];
    }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CManage::Profit(void)
  {
    for (int target=0; target<mtTargetCount; target++)
    {
      //delete mtTarget[target];
    }
  }


  
//+------------------------------------------------------------------+
//| Update - updates operational target/order data                   |
//+------------------------------------------------------------------+
void CManage::Update(void)
  {
    mtFractal.Update();
    mtPregr.Update();
    mtTregr.Update();
          
    for (int target=0;target<mtTargetCount;target++)
      mtTarget[target].Update();

    //--- Add new at pegs
    if (!mtPeg && mtFractal.IsPegged())
    {
      if (mtFractal.Direction(Trend) == mtFractal.Direction(Root))
        mtPeg      = AddTarget(ttContrarian);
      else  
        mtPeg      = AddTarget(ttTrend);
          
      mtHalt       = !mtPeg;
      mtBreakout   = false;
    }

    //--- Add new at Breakouts
    if (!mtBreakout && mtFractal.IsBreakout())
    {
      mtPeg          = false;
      
      if (mtFractal.IsReversal())
      {
       // ActiveTarget().SetObjectives(TypeTrap,Level50,Level161,Level100,Level161); //---hmmm; -- need to think about this one
      }
      else
      {
        mtBreakout   = AddTarget(ttTrend);
        mtHalt       = !mtPeg;
      }
    }

    Orders();
    Profit();
    Risk();
    
    PrintTargets();
  }

//+------------------------------------------------------------------+
//| Update - updates operational target/order data                   |
//+------------------------------------------------------------------+
void CManage::PrintTargets(void)
  {
    string uTargets = "";

    for (int target=0;target<mtTargetCount;target++)
      uTargets += mtTarget[target].PrintTarget();

    Comment (uTargets);
  }
