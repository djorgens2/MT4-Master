//+------------------------------------------------------------------+
//|                                                  LoadHistory.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//    int    fhandle;
//    string frecord;
//    
//    if (IsTesting())
//      fhandle = FileOpen("GBPUSD1.hst",FILE_BIN|FILE_WRITE|FILE_SHARE_WRITE|FILE_SHARE_READ);
//    else
//      fhandle = FileOpenHistory("GBPUSD1.hst",FILE_BIN|FILE_WRITE|FILE_SHARE_WRITE|FILE_SHARE_READ);
//
//    if (fhandle<1)
//    {
//      Print("Error opening hisotry file GBPUSD1.hst file for read (error: "+IntegerToString(GetLastError())+")");
//      return;
//    }
//    
//    frecord = FileReadString(fhandle);
//    Print(frecord);
//    
//    FileClose(fhandle);
   MqlRates rates[]; 
   ArraySetAsSeries(rates,true); 
   int copied=CopyRates(Symbol(),PERIOD_M1,0,100,rates); 
   if(copied>0) 
     { 
      Print("Bars copied: "+copied); 
      string format="open = %G, high = %G, low = %G, close = %G, volume = %d"; 
      string out; 
      int size=fmin(copied,10); 
      for(int i=0;i<size;i++) 
        { 
         out=i+":"+TimeToString(rates[i].time); 
         out=out+" "+StringFormat(format, 
                                  rates[i].open, 
                                  rates[i].high, 
                                  rates[i].low, 
                                  rates[i].close, 
                                  rates[i].tick_volume); 
         Print(out); 
        } 
     } 
   else Print("Failed to get history data for the symbol ",Symbol()); 
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
