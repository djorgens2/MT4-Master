//+------------------------------------------------------------------+
//|                                                    testevent.mq4 |
//|                                 Copyright 2018, Dennis Jorgenson |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Dennis Jorgenson"
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#include <Class\Event.mqh>
#include <Class\Sessions.mqh>

   CEvent    *ev_asia    = new CEvent();
   CSession  *session    = new CSession(Asia);
   CSessions *sessions   = new CSessions();
   
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    ev_asia.ClearEvents();
    
    sessions.SetSessionHours(Daily,inpNewDay,inpEndDay);
    sessions.SetSessionHours(Asia,inpAsiaOpen,inpAsiaClose);
    sessions.SetSessionHours(Europe,inpEuropeOpen,inpEuropeClose);
    sessions.SetSessionHours(US,inpUSOpen,inpUSClose);
    
    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete ev_asia;
    delete session;
  }
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
     ev_asia.SetEvent(NewLow);
     session.Update();
     
     if (ev_asia[NewHigh]) Print("1.New High");

     ev_asia.SetEvent(NewHigh);
     
     if (ev_asia[NewHigh]) Print("2.New High");

     ev_asia.ClearEvent(NewHigh);

     if (ev_asia[NewLow]) Print("3.1 New Low");
     if (ev_asia[NewHigh]) Print("3.2 New High");     
     
     ev_asia.SetEvent(NewHigh);

     if (ev_asia[NewHigh]) Print("4.New High");     

     ev_asia.ClearEvents();
     
     if (ev_asia[NewLow]) Print("5.1 New Low");
     if (ev_asia[NewHigh]) Print("5.1 New High");

    if (session[NewReversal])
      Print("Reversal");
    else
      Print("Trending");
      
    Print("Session Open: "+DoubleToStr(session.Open(),Digits));
    session.OpenSession();
    Print("Session Open: "+DoubleToStr(session.Open(),Digits));
    
  }
