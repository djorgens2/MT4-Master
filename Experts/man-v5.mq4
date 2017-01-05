//+------------------------------------------------------------------+
//|                                                       man-v5.mq4 |
//|                                 Copyright 2014, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Dennis Jorgenson"
#property link      ""
#property version   "1.50"
#property strict

#include <Class\Fractal.mqh>
#include <manual.mqh>

input string fractalHeader           = "";    //+------ Fractal inputs ------+
input int    inpRangeMax             = 30;    // Maximum fractal pip range
input int    inpRangeMin             = 15;    // Minimum fractal pip range

//--- Class defs
  CFractal         *fractal          = new CFractal(inpRangeMax,inpRangeMin);

//--- Constants
  const string   cFiboLeg[] = {"tr","tm","p","b","r","e","d","c","iv","cv","a"};

//--- Types
  struct AlertRec
  {
    RetraceType  Leg;          //--- The leg for computing stops
    double       Fibo;         //--- The retrace alert fibo
    int          Action;       //--- Action to take for the alert
    double       LotSize;      //--- The lots to execute for the alert
    double       BasePrice;    //--- The base price at alert setup 
    double       RootPrice;    //--- The root price at alert setup
    double       Range;        //--- The base/root trade range
    double       TargetPrice;  //--- Computed target price
    double       StopPrice;    //--- Computed stop price
    double       FiboTarget;   //--- The expansion target fibo
    double       FiboStop;     //--- The expansion stop fibo
    double       FiboReset;    //--- The re-execute retrace fibo (adds)
    double       TrailOpen;    //--- The pip trail for mit/limit orders
    double       TrailStop;    //--- The pip trail for take profit
  };

  AlertRec Alerts[];
  
  bool     ShowFibonacci    = false;


//+------------------------------------------------------------------+
//| FormatOrder - formats the order line diplayed in the messagebox  |
//+------------------------------------------------------------------+
string FormatOrder(int Ticket)
  {
    string foDetail   = "";
    
    if (OrderSelect(Ticket,SELECT_BY_TICKET))
      foDetail +=BoolToStr(OrderType()==OP_BUY,"L","S")
               +LPad(IntegerToString(Ticket)," ",9)
               +" "+LPad(OrderSymbol()," ",8)
               +"   "+LPad(DoubleToStr(OrderOpenPrice(),Digits)," ",Digits+2)
               +"   "+LPad(DoubleToStr(OrderLots(),ordLotPrecision)," ",ordLotPrecision+2)
               +"   "+LPad(DoubleToStr(OrderCommission(),2)," ",6)
               +"   "+LPad(NegLPad(OrderSwap(),2)," ",7)
               +"  "+LPad(DoubleToStr(TicketValue(Ticket),2)," ",11)
               +"/"+DoubleToStr(TicketValue(Ticket,InEquity),1)
               +"%";

    return (foDetail);
  }
  
//+------------------------------------------------------------------+
//| ShowTrades - Opens a dialogue box with open trade values         |
//+------------------------------------------------------------------+
void ShowTrades(string Message, string Title="Application Show Trade")
  {
    string stComment           = "No Active Trades";
    string stShort             = "";
    string stLong              = "";
    
    int    stMinTicket[2]      = {0,0};
    double stMinValue[2]       = {0.00,0.00};
    
    orderRefreshScreen();
    
    for (int ord=0;ord<OrdersTotal();ord++)
      if (OrderSelect(ord,SELECT_BY_POS))
        if (OrderSymbol()==Symbol())
          if (OrderType()==OP_BUY||OrderType()==OP_SELL)
          {
            if (stMinTicket[OrderType()]==0)
              stMinTicket[OrderType()] = OrderTicket();
            else
              stMinTicket[OrderType()]=BoolToInt(TicketValue(OrderTicket())<stMinValue[OrderType()],OrderTicket(),stMinTicket[OrderType()]);

            switch (OrderType())
            {
              case OP_BUY:  stLong  += FormatOrder(OrderTicket())+"\n";
                            break;
              case OP_SELL: stShort += FormatOrder(OrderTicket())+"\n";
            }
          }
        
    if (LotCount()>0.00)
      stComment = " Ticket   Symbol      Open    Lots    Com     Swap       Profit(Val/%)\n"
                 +stShort+stLong+"\n"
                 +"Minimum Tickets"
                 +BoolToStr(stMinTicket[OP_BUY]>0,"\n"+FormatOrder(stMinTicket[OP_BUY]))
                 +BoolToStr(stMinTicket[OP_SELL]>0,"\n"+FormatOrder(stMinTicket[OP_SELL]))
                 +"\n\nBalance: "+DoubleToStr(AccountBalance()+AccountCredit(),2)
                 +"\nEquity: "+DoubleToStr(AccountEquity(),2)
                 +" ("+DoubleToStr(EquityPercent(),1)+"%)";

    Pause(BoolToStr(StringLen(Message)>0,Message+"_____________________________________________________________________\n\n")+stComment,
         Title);
  }
 
//+------------------------------------------------------------------+
//| GetData                                                          |
//+------------------------------------------------------------------+
void GetData(void)
  {
    fractal.Update();    
  }

//+------------------------------------------------------------------+
//| RefreshScreen                                                    |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    string rsComment = "";
    
    for (int alert=0;alert<ArraySize(Alerts);alert++)
    {
      rsComment += EnumToString(Alerts[alert].Leg)+" ("+DoubleToStr(Alerts[alert].Fibo,1)+"%) "
                 + BoolToStr(Alerts[alert].Action==OP_NO_ACTION,"Alert Only",ActionText(Alerts[alert].Action)+ "("+DoubleToStr(LotSize(Alerts[alert].LotSize),ordLotPrecision)+") ")
                 + BoolToStr(Alerts[alert].FiboReset>0.00,"Reset("+DoubleToStr(Alerts[alert].FiboReset,1)+"%) ")
                 + BoolToStr(Alerts[alert].FiboTarget>0.00,"Target("+DoubleToStr(Alerts[alert].FiboTarget,1)+"%) ")
                 + BoolToStr(Alerts[alert].FiboStop>0.00,"Stop("+DoubleToStr(Alerts[alert].FiboStop,1)+"%) ");
                 
      if (Alerts[alert].TrailOpen+Alerts[alert].TrailStop>0.00)
      {
        rsComment += "Trail("
                   + "Open:"+DoubleToStr(Alerts[alert].TrailOpen,1)+" "
                   + "Stop:"+DoubleToStr(Alerts[alert].TrailStop,1)+")";
      }
      
      rsComment += "\n";
    }
    
      UpdateLine("oTop",fractal.Range(Origin,Term,Top),STYLE_SOLID,clrLawnGreen);
      UpdateLine("oPrice",fractal.Origin().Price,STYLE_DOT,clrGray);
      UpdateLine("oBottom",fractal.Range(Origin,Term,Bottom),STYLE_SOLID,clrMaroon);

    //Comment(rsComment);
    
    if (ShowFibonacci)
      fractal.RefreshScreen();
  }

//+------------------------------------------------------------------+
//| Execute                                                          |
//+------------------------------------------------------------------+
void Execute(void)
  {
    AlertRec UnprocessedAlerts[];

    for (int alert=0; alert<ArraySize(Alerts); alert++)
      if (fractal.Fibonacci(Alerts[alert].Leg,Retrace,Now,InPercent)>=Alerts[alert].Fibo)
      {
        switch (Alerts[alert].Action)
        {                               
          case OP_BUY:         
          case OP_SELL:        if (OpenOrder(Alerts[alert].Action,"Alert:"+EnumToString(Alerts[alert].Leg)+"("+DoubleToStr(Alerts[alert].Fibo,1)+"%)",Alerts[alert].LotSize))
                               {
                                 //--- Handle stop/target
                                 if (Alerts[alert].StopPrice>0.00)
                                   SetStopPrice(Alerts[alert].Action,Alerts[alert].StopPrice);

                                 if (Alerts[alert].TargetPrice>0.00)
                                   SetTargetPrice(Alerts[alert].Action,Alerts[alert].TargetPrice);

                                 //--- Handle reset
                                 if (Alerts[alert].FiboReset>0.00)
                                 {
                                   Alerts[alert].Fibo = Alerts[alert].FiboReset;
                                   Alerts[alert].FiboReset = 0.00;
                                   
                                   ArrayResize(UnprocessedAlerts,ArraySize(UnprocessedAlerts)+1);
                                   UnprocessedAlerts[ArraySize(UnprocessedAlerts)-1] = Alerts[alert];
                                 }
                               }
                               break;

          default:             Pause("Fibo Stop Hit: "+EnumToString(Alerts[alert].Leg)+"("+DoubleToStr(Alerts[alert].Fibo,1)+"%)","Fibo Stop Alert",MB_OK|MB_ICONINFORMATION);

                               if (IsHigher(Alerts[alert].FiboReset,Alerts[alert].Fibo,true,1))
                               {
                                 Alerts[alert].FiboReset = 0.00;
                                  
                                 ArrayResize(UnprocessedAlerts,ArraySize(UnprocessedAlerts)+1);
                                 UnprocessedAlerts[ArraySize(UnprocessedAlerts)-1] = Alerts[alert];
                               }
        }
      }
      else
      {
        ArrayResize(UnprocessedAlerts,ArraySize(UnprocessedAlerts)+1);
        UnprocessedAlerts[ArraySize(UnprocessedAlerts)-1] = Alerts[alert];
      }
    
    ArrayResize(Alerts,0);    
    ArrayCopy(Alerts,UnprocessedAlerts);
  }

//+------------------------------------------------------------------+
//| SetFAlert                                                        |
//+------------------------------------------------------------------+
void SetFAlert(string Leg, double Fibo, int Action, string &Options[])
  {
    RetraceType sfaLeg     = NULL;

    bool        sfaExists  = false;
    bool        sfaTrail   = false;
    int         sfaAlert   = 0;
    string      sfaOption[];
        
    //--- preliminary validation
    for (int leg=0; leg<ArraySize(cFiboLeg); leg++)
      if (cFiboLeg[leg] == Leg)
      {
        sfaLeg = RetraceType(leg);
        break;
      }
      
    if (sfaLeg == NULL)
      return;

    //--- determine if add or change
    for (sfaAlert=0; sfaAlert<ArraySize(Alerts); sfaAlert++)
      if (sfaLeg == Alerts[sfaAlert].Leg  &&
          Fibo   == Alerts[sfaAlert].Fibo &&
          Action == Alerts[sfaAlert].Action)
      {
        sfaExists = true;
        break;
      }
    
    if (!sfaExists)
    {
      sfaAlert = ArraySize(Alerts);
      ArrayResize(Alerts,sfaAlert+1);
          
      Alerts[sfaAlert].Leg       = sfaLeg;
      Alerts[sfaAlert].Fibo      = Fibo;
      Alerts[sfaAlert].Action    = Action;          
      Alerts[sfaAlert].RootPrice = fractal.Price(fractal.Previous(sfaLeg));
      Alerts[sfaAlert].BasePrice = fractal.Price(fractal.Previous(fractal.Previous(sfaLeg)));
      
      if (IsEqual(fractal.Price(fractal.Previous(fractal.Previous(sfaLeg))),0.00,Digits))
        Alerts[sfaAlert].BasePrice = fractal.Price(sfaLeg)-(fractal.Range(sfaLeg,Max)*FiboPercent(Fibo50)*fractal.Direction(sfaLeg));

      Alerts[sfaAlert].Range     = fabs(Alerts[sfaAlert].RootPrice-Alerts[sfaAlert].BasePrice);
    }
        
    if (Action == OP_NO_ACTION)
    {
      Alerts[sfaAlert].LotSize    = 0.00;
      Alerts[sfaAlert].FiboTarget = 0.00;
      Alerts[sfaAlert].FiboStop   = 0.00;
      Alerts[sfaAlert].FiboReset  = 0.00;
      Alerts[sfaAlert].TrailOpen  = 0.00;
      Alerts[sfaAlert].TrailStop  = 0.00;
    }
    else
      for (int option=0; option<ArraySize(Options); option++)
      {
        StringSplit(Options[option],"=",sfaOption);

        switch (ArraySize(sfaOption))
        {
          case 0:     break;
        
          case 1:     if (sfaOption[0] == "TRAIL")   sfaTrail=true;
                      break;
                    
          case 2:     if (sfaOption[0] == "LOTS")    
                        Alerts[sfaAlert].LotSize    = StrToDouble(sfaOption[1]);
                        
                      if (sfaOption[0] == "TARGET")
                      {
                        Alerts[sfaAlert].FiboTarget  = StrToDouble(sfaOption[1]);
                        Alerts[sfaAlert].TargetPrice = (Alerts[sfaAlert].Range*fdiv(Alerts[sfaAlert].FiboTarget,100)*ActionDir(Action))+Alerts[sfaAlert].BasePrice;
                      }
                      
                      if (sfaOption[0] == "STOP")
                      {
                        Alerts[sfaAlert].FiboStop    = StrToDouble(sfaOption[1]);
                        Alerts[sfaAlert].StopPrice   = (Alerts[sfaAlert].Range*fdiv(Alerts[sfaAlert].FiboStop,100)*ActionDir(Action))+Alerts[sfaAlert].RootPrice;
                      }
                      
                      if (sfaOption[0] == "RESET")
                        Alerts[sfaAlert].FiboReset  = StrToDouble(sfaOption[1]);
      
                      if (sfaTrail)
                      {
                        if (sfaOption[0] == "-O")    Alerts[sfaAlert].TrailOpen = StrToDouble(sfaOption[1]);
                        if (sfaOption[0] == "-S")    Alerts[sfaAlert].TrailStop = StrToDouble(sfaOption[1]);
                      }  
        }
      }
      
      Pause("Alert Stops: (t):"+DoubleToStr(Alerts[sfaAlert].TargetPrice,Digits)+" Fibo:"+DoubleToStr(fdiv(Alerts[sfaAlert].FiboTarget,100),5)+"\n"
           +"             (s):"+DoubleToStr(Alerts[sfaAlert].StopPrice,Digits)+" Fibo:"+DoubleToStr(fdiv(Alerts[sfaAlert].FiboStop,100),5)+"\n"
           +"        Range:"+DoubleToStr(Alerts[sfaAlert].Range,Digits)+" (b):"+DoubleToStr(Alerts[sfaAlert].BasePrice,Digits)
           +"             (r):"+DoubleToStr(Alerts[sfaAlert].RootPrice,Digits),"I got stops!");      
  }

//+------------------------------------------------------------------+
//| ExecAppCommands                                                  |
//+------------------------------------------------------------------+
void ExecAppCommands(string &Command[])
  {    
    if (Command[0]=="ALERT")
      if (Command[1]=="CANCEL")
        ArrayResize(Alerts,0);
      else
        SetFAlert(lower(Command[1]), StrToDouble(Command[2]), ActionCode(Command[3]),Command);
    else
    if (Command[0]=="SHOW")
      if (InStr(Command[1],"FIB"))
        ShowFibonacci  = true;
      else
      if (InStr(Command[1],"TRADE"))
        ShowTrades("Open Trades");
      else
        ShowTrades("");
    else
    if (Command[0]=="HIDE")
      if (InStr(Command[1],"FIB"))
      {
        if (ShowFibonacci)
          Comment("");
        ShowFibonacci  = false;
      }

  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    string     otParams[];
  
    InitializeTick();

    GetManualRequest();

    while (AppCommand(otParams,15))
      ExecAppCommands(otParams);

    OrderMonitor();
    GetData(); 

    RefreshScreen();
    
    if (AutoTrade())
      Execute();
    
    ReconcileTick();        
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    ManualInit();
    
    NewLine("oTop");
    NewLine("oBottom");
    NewLine("oPrice");

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete fractal;
  }