#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "https://www.mql4.com"
#property version   "1.00"
#property strict
#property indicator_separate_window
#property indicator_plots               0
#property indicator_buffers             0
#property indicator_minimum             0.0
#property indicator_maximum             0.0
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+

#include <MyAppDialog.mqh>

MyAppDialog InstMyAppDialog;

int OnInit()
  {
  if(!InstMyAppDialog.Create(0,"TestDialog",0,0,0,0,300))
     return(INIT_FAILED);
  if(!InstMyAppDialog.Run())
     return(INIT_FAILED);   
//--- indicator buffers mapping
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
   
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   InstMyAppDialog.ChartEvent(id,lparam,dparam,sparam);
  }