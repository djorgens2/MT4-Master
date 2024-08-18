//+------------------------------------------------------------------+
//|                                              PrintObjectFont.mq4 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property script_show_inputs
//--- input parameters

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
    Print(ObjectGetString(0,"tmaFractalTrendState1",OBJPROP_FONT));
  }
