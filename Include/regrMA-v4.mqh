//+------------------------------------------------------------------+
//|                                                    regrMA-v4.mqh |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property strict

//+------------------------------------------------------------------+
//| regrMAGetData - loads the measures                               |
//+------------------------------------------------------------------+
void regrMAGetData()
  {        
    ArrayCopy(regrSlowLast,regrSlow);

    for (int idx=0; idx<regrMeasures; idx++)
      regrFast[idx]   = iCustom(Symbol(),Period(),"regrMA-v3",inpRegrDegree,inpRegrFastRng,inpRegrSlowRng,inpRegrST,inpRegrLT,BUF_FAST_DATA,idx);
    new 
  }
  