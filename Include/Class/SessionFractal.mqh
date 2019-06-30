//+------------------------------------------------------------------+
//|                                               SessionFractal.mqh |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class/Event.mqh>
#include <Class/Session.mqh>
#include <Class/ArrayDouble.mqh>
#include <std_utility.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSessionFractal
  {

public:
  enum               FractalType
                     {
                       ftTerm,
                       ftTrend,
                       ftOrigin,
                       ftFractalTypes
                     };

  struct             FiboRec
                     {
                       int    Direction;
                       int    State;
                       double Prior;
                       double Base;
                       double Root;
                       double Expansion;
                       double Retrace;
                       double Recovery;
                     };

                     CSessionFractal(int AsiaOpen, int AsiaClose, int EUOpen, int EUClose, int USOpen, int USClose, int GMTOffset);
                    ~CSessionFractal();
                    
  //--- Public Methods

                     void Update(void);


private:

  //--- Private Classes
  
  CSession     *sf[SessionTypes];
  CEvent       *sEvent;
  
  //--- Private Properties
  
  FiboRec       ft[ftFractalTypes];

  //--- Private Methods

                void CSessionFractal::UpdateFractal(void);


  };

//+------------------------------------------------------------------+
//| UpdateFractal - Computes new fractal points on reversals         |
//+------------------------------------------------------------------+
void CSessionFractal::UpdateFractal(void)
  {
  }
  
//+------------------------------------------------------------------+
//| SessionFractal class constructor                                 |
//+------------------------------------------------------------------+
CSessionFractal::CSessionFractal(int AsiaOpen, int AsiaClose, int EUOpen, int EUClose, int USOpen, int USClose, int GMTOffset)
  {
    sf[Daily]       = new CSession(Daily,0,23,GMTOffset);
    sf[Asia]        = new CSession(Asia,AsiaOpen,AsiaClose,GMTOffset);
    sf[Europe]      = new CSession(Europe,EUOpen,EUClose,GMTOffset);
    sf[US]          = new CSession(US,USOpen,USClose,GMTOffset);
  }

//+------------------------------------------------------------------+
//| SessionFractal class destructor                                  |
//+------------------------------------------------------------------+
CSessionFractal::~CSessionFractal()
  {
  }

//+------------------------------------------------------------------+
//| Update - Updates session and fractal data                        |
//+------------------------------------------------------------------+
void CSessionFractal::Update(void)
  {
    for (SessionType type=Daily;type<SessionTypes;type++)
    {
      sf[type].Update();

      if (sf[type].Event(NewReversal))
        UpdateFractal();
    }
  }

