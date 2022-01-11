//+------------------------------------------------------------------+
//|                                                 CleanObjects.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict
#property script_show_inputs

#include <std_utility.mqh>

//--- input parameters
input string   Key;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
    //-- Clean Open Chart Objects
    int fObject             = 0;
    
    while (fObject<ObjectsTotal())
      if (InStr(ObjectName(fObject),Key))
        ObjectDelete(ObjectName(fObject));
      else fObject++;
  }
