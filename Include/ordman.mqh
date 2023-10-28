//+------------------------------------------------------------------+
//|                                                       manual.mqh |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2013 (c) Dennis Jorgenson"
#property link      "http://www.mql5.com"
#property strict

#include <Class/Order.mqh>

//-- Operational vars
string    params[];
string    commands[];
string    comfile;

//+------------------------------------------------------------------+
//| ActionCode - returns order action id (buy/sell)                  |
//+------------------------------------------------------------------+
int ActionCode(string Action, double Price=0.00, bool Contrarian=false)
  {
    int action                             = NoAction;
    
    if (InStr("BUYLONG",Action))   action   = BoolToInt(Contrarian,OP_SELL,OP_BUY);
    if (InStr("SELLSHORT",Action)) action   = BoolToInt(Contrarian,OP_BUY,OP_SELL);
    
    if (Price>0)
      switch (action)
      {
        case OP_BUY:   if (Price<Ask)        return (OP_BUYLIMIT);
                       return (OP_BUYSTOP);

        case OP_SELL:  if (Price>Bid)        return (OP_SELLLIMIT);
                       return (OP_SELLSTOP);
      }

    return (action);
  }

//+------------------------------------------------------------------+
//| MethodCode - returns method code from command text               |
//+------------------------------------------------------------------+
OrderMethod MethodCode(string Method)
  {
    if (trim(Method)=="HOLD")        return (Hold);
    if (trim(Method)=="FULL")        return (Full);
    if (InStr("SPLITEQH",Method))    return (Split);
    if (InStr("RETAINEQR",Method))   return (Retain);
    if (trim(Method)=="DCA")         return (DCA);
    if (InStr("HEDGE",Method))       return (Hedge);
    if (InStr("RECAPTURE",Method))   return (Recapture);
    if (InStr("CLOSEKILL",Method))   return (Kill);

    return (NoValue);
  }

//+------------------------------------------------------------------+
//| GroupCode - returns group code from command text                 |
//+------------------------------------------------------------------+
TicketGroup GroupCode(string Group)
  {
    if (trim(Group)=="ZONE")        return (ByZone);
    if (trim(Group)=="TICKET")      return (ByTicket);
    if (trim(Group)=="PROFIT")      return (ByProfit);
    if (trim(Group)=="LOSS")        return (ByLoss);
    if (trim(Group)=="ACTION")      return (ByAction);
    if (trim(Group)=="METHOD")      return (ByMethod);

    return (NoValue);
  }

//+------------------------------------------------------------------+
//| FormatTrade - Extracts trade command params; sets defaults       |
//+------------------------------------------------------------------+
void FormatTrade(string &Trade[])
  {
    string defaults[5] = {"","","","",""};

    for (int arg=0;arg<ArraySize(Trade);arg++)
      if (arg<ArraySize(defaults))
        defaults[arg]  = Trade[arg];

    if (InStr("TICKET",defaults[1]))
    {
      defaults[1]      = "";
      defaults[3]      = defaults[2];
      defaults[2]      = "TICKET";
    }
    if (defaults[2]=="") defaults[2]  = "ACTION";
    if (defaults[3]=="")
      if (MethodCode(defaults[2])>NoValue)
      {
        defaults[3]    = (string)MethodCode(defaults[2]);
        defaults[2]    = "METHOD";
      }
    ArrayCopy(Trade,defaults);
  }

//+------------------------------------------------------------------+
//| FormatOrder - Extracts order params and sets defaults            |
//+------------------------------------------------------------------+
void FormatOrder(string &Order[])
  {
    string defaults[12] = {"","0.00","0.00","0.00","0.00","","","","","0.00","0.00","0.00"};

    for (int arg=0;arg<ArraySize(Order);arg++)
      if (arg<ArraySize(defaults))
        defaults[arg] = Order[arg];
      
    ArrayCopy(Order,defaults);
  }

//+------------------------------------------------------------------+
//| FormatConfig - Extracts config command params; sets defaults     |
//+------------------------------------------------------------------+
void FormatConfig(string &Config[])
  {
    string defaults[7] = {"","","","","","",""};

    for (int arg=0;arg<ArraySize(Config);arg++)
      if (arg<ArraySize(defaults))
        defaults[arg] = Config[arg];
      
    ArrayCopy(Config,defaults);
  }

//+------------------------------------------------------------------+
//| FormatPrice - Formats manual entered price from text             |
//+------------------------------------------------------------------+
double FormatPrice(int Action, string Price, bool Pips=false)
  {
    double pips     = 0.00;
    double price    = StringToDouble(Price);

    if (StringSubstr(Price,StringLen(Price)-1,1)=="P")
    {
      pips          = point(StringToDouble(StringSubstr(Price,0,StringLen(Price)-1)));

      switch (Action)
      {
        case OP_SELLLIMIT:
        case OP_SELL:       price = Bid+pips;
                            break;

        case OP_BUYLIMIT:
        case OP_BUY:        price = Ask-pips;
                            break;

        case OP_BUYSTOP:    price = Ask+pips;
                            break;

        case OP_SELLSTOP:   price = Bid-pips;
                            break;

        default:            return (NoValue);
      }
    }

    return BoolToDouble(Pips,pip(pips),price,Digits);
  }
  

//+------------------------------------------------------------------+
//| ProcessComFile - retrieves and submits manual commands           |
//+------------------------------------------------------------------+
void ProcessComFile(COrder &Order)
  {
    OrderRequest request;

    int    try            =  0;
    int    fHandle        = INVALID_HANDLE;
    string fRecord;
    string memo           = "Manual Entry";

    bool   go             = true;
    bool   verify         = false;

    int    pCount         = NoValue;
    bool   lComment       = false;
    bool   bComment       = false;

    if (comfile=="")
      return;
    
    //--- process command file
    while(fHandle==INVALID_HANDLE)
    {
      fHandle=FileOpen(comfile,FILE_CSV|FILE_READ);
      
      if (++try==20)
      {
        Print(">>>Error opening file ("+IntegerToString(fHandle)+") for read: ",GetLastError());
        return;
      }
    }
    
    while (!FileIsEnding(fHandle))
    {
      fRecord      = FileReadString(fHandle);
      fRecord      = StringTrimLeft(StringTrimRight(fRecord));

      lComment     = false;
      if (InStr(fRecord,"//"))
        lComment   = true;
          
      if (InStr(fRecord,"/*"))
        bComment   = true;

      if (InStr(fRecord,"*/"))
        bComment   = false;
          
      if (StringLen(fRecord)>0&&!lComment&&!bComment&&!InStr(fRecord,"*/"))
      {
        SplitStr(fRecord," ",params);

        fRecord = "";
        pCount  = ArraySize(params);
        for (int i=0;i<pCount;i++)
          Append(fRecord,params[i],"|");

        if (params[0]=="VERIFY")
        {
          verify = true;
          go     = false;
        }
        else
        if (verify)
          go = MessageBoxW(0,Symbol()+"> Verify Command\n"+"  Execute command: "+fRecord,"Command Verification",MB_ICONHAND|MB_YESNO)==IDYES;

        //--- Verify Mode
        if (go)
        {
          //-- Print utilities
          if (params[0]=="PRINT")
            switch (pCount)
            {
              case 2:     if (InStr("REQUEST",params[1]))
                            Print(Order.QueueStr());

                          if (InStr("SUMMARY",params[1]))
                            Print(Order.SummaryStr());

                          if (InStr("ORDER",params[1]))
                            Print(Order.OrderStr());
                          break;
              case 3:     if (InStr("ORDER",params[1]))
                            Print(Order.OrderStr(ActionCode(params[2])));

                          if (InStr("MASTER",params[1]))
                            Print(Order.MasterStr(ActionCode(params[2])));
            }
          else

          //-- Order Requests
          if (IsBetween(ActionCode(params[0]),OP_BUY,OP_SELL))
          {
            FormatOrder(params);

            request.Status           = Initial;
            request.Key              = NoValue;
            request.Ticket           = NoValue;
            request.Action           = ActionCode(params[0]);
            request.Price            = FormatPrice(request.Action,params[2]);

            request.Type             = ActionCode(params[0],request.Price);
            request.Lots             = StringToDouble(params[1]);
            request.TakeProfit       = BoolToDouble(InStr(params[3],"P"),request.Price+
                                          point(StringToDouble(StringSubstr(params[3],0,StringLen(params[3])-1)))*BoolToInt(IsEqual(request.Action,OP_BUY),1,NoValue),
                                          FormatPrice(request.Action,params[3]));
            request.StopLoss         = BoolToDouble(InStr(params[4],"P"),request.Price+
                                          point(StringToDouble(StringSubstr(params[4],0,StringLen(params[4])-1)))*BoolToInt(IsEqual(request.Action,OP_BUY),NoValue,1),
                                          FormatPrice(request.Action,params[4]));
            request.Requestor        = "Manual";
            request.Memo             = params[5];
            request.Expiry           = BoolToDate(StringLen(params[6])>9,StringToTime(params[6]),TimeCurrent()+(Period()*60));
            
            switch (ActionCode(params[7]))
            {
              case OP_BUY:             request.Pend.Type      = BoolToInt(InStr("MITSTOP",params[8]),OP_BUYSTOP,
                                                                BoolToInt(InStr("LIMIT",params[8]),OP_BUYLIMIT));
                                       request.Pend.Limit     = FormatPrice(Action(OP_BUY,InAction,InContrarian),params[9]);
                                       request.Pend.Cancel    = FormatPrice(OP_BUY,params[10]);
                                       request.Pend.Step      = StringToDouble(params[11]);
                                       break;

              case OP_SELL:            request.Pend.Type      = BoolToInt(InStr("MITSTOP",params[8]),OP_SELLSTOP,
                                                                BoolToInt(InStr("LIMIT",params[8]),OP_SELLLIMIT));
                                       request.Pend.Limit     = FormatPrice(Action(OP_SELL,InAction,InContrarian),params[9]);
                                       request.Pend.Cancel    = FormatPrice(OP_SELL,params[10]);
                                       request.Pend.Step      = StringToDouble(params[11]);
                                       break;

              default:                 request.Pend.Type      = NoAction;
                                       request.Pend.Limit     = 0.00;
                                       request.Pend.Cancel    = 0.00;
                                       request.Pend.Step      = 0.00;
            }
            
            if (Order.Submitted(request))
              Print(Order.OrderDetailStr(Order.Ticket(request.Ticket)));
            else
              Print(Order.RequestStr(request));
          }
          else

          //-- System/Action Halt
          if (InStr("DISABLEHALT",params[0]))
            switch (pCount)
            {
              case 1:  Order.Disable("Manual System Halt");
                       break;
              default: if (IsBetween(ActionCode(params[1]),OP_BUY,OP_SELL))
                         Order.Disable(ActionCode(params[1]),"Manual "+proper(params[1])+" Halt");
            }
          else

          //-- System/Action Resume
          if (InStr("ENABLERESUME",params[0]))
            switch (pCount)
            {
              case 1:  Order.Enable("Manual System Enabled");
                       break;
              default: if (IsBetween(ActionCode(params[1]),OP_BUY,OP_SELL))
                         Order.Enable(ActionCode(params[1]),"Manual "+proper(params[1])+" Enabled");
            }
          else

          //-- Order Cancelations
          if (InStr("CANCEL",params[0]))
            switch (pCount)
            {
              case 2:   if (InStr("ALL",params[1]))
                          Order.Cancel(NoAction,"Manual Close [All Requests]");
                        else
                        if (IsBetween(ActionCode(params[1]),OP_BUY,OP_SELL))
                          Order.Cancel(ActionCode(params[1]),"Manual Close [All "+proper(params[1])+"]");
                        break;

              case 3:   if (InStr("REQUEST",params[1]))
                          Order.Cancel(Order.Request((int)params[2]),"Manual Close [By Request #]");
                        else
                        switch (ActionCode(params[1]))
                        {
                          case OP_BUY:  request.Type      = BoolToInt(InStr("MITSTOP",params[8]),OP_BUYSTOP,
                                                            BoolToInt(InStr("LIMIT",params[8]),OP_BUYLIMIT));

                                        Order.Cancel(request.Type,"Manual Close [All "+proper(ActionText(request.Type))+"]");
                                        break;
                                                           
                          case OP_SELL: request.Type     = BoolToInt(InStr("MITSTOP",params[8]),OP_SELLSTOP,
                                                           BoolToInt(InStr("LIMIT",params[8]),OP_SELLLIMIT));

                                        Order.Cancel(request.Type,"Manual Close [All "+proper(ActionText(request.Type))+"]");
                                        break;
                        }
            }
          else

          //-- Default Configuration
          if (InStr("STOPLOSSLTAKEPROFITPTARGETEQFUNDRISKZONE",params[0]))
          {
            FormatConfig(params);

            //-- Risk Management
            if (InStr("STOPLOSSL",params[0]))
              Order.SetStopLoss(ActionCode(params[1]),FormatPrice(ActionCode(params[1]),params[2],InStr(params[2],"P")),InStr("HIDDENHIDE",params[3]),InStr(params[2],"P"));
            else

            //-- Target Management
            if (InStr("TAKEPROFITPTARGET",params[0]))
              Order.SetTakeProfit(ActionCode(params[1]),FormatPrice(ActionCode(params[1]),params[2],InStr(params[2],"P")),InStr("HIDDENHIDE",params[3]),InStr(params[2],"P"));
            else
            
            //-- Fund Management
            if (params[0]=="EQ"||params[0]=="FUND")
              Order.SetFundLimits(ActionCode(params[1]),StringToDouble(params[2]),StringToDouble(params[3]),StringToDouble(params[4]));
            else

            //-- Risk Mitigation
            if (params[0]=="RISK")
              Order.SetRiskLimits(ActionCode(params[1]),StringToDouble(params[2]),StringToDouble(params[3]),StringToDouble(params[4]));
            else
          
            //-- Zone Management
            if (params[0]=="ZONE")
              Order.SetZoneLimits(ActionCode(params[1]),StringToDouble(params[2]),StringToDouble(params[3]));
          }
          else

          //-- Order State Management
          if (MethodCode(params[0])>NoValue)
          {
            FormatTrade(params);            
            Order.SetMethod(ActionCode(params[1]),MethodCode(params[0]),GroupCode(params[2]),(int)params[3]);
          }
        }
      }
    }

    UpdateLabel("lbvAC-File",comfile,clrDarkGray);

    FileClose(fHandle);

    fHandle=FileOpen(comfile,FILE_CSV|FILE_WRITE);

    if(fHandle!=INVALID_HANDLE)
    {
      FileWrite(fHandle,"");
      FileClose(fHandle);
    }
  }

//+------------------------------------------------------------------+
//| Init - Configures Manual for operation                           |
//+------------------------------------------------------------------+
void ManualInit(string ComFile)
  {        
    int         fHandle;
    
    comfile             = ComFile;

    //---- If not Exists, create file
    fHandle=FileOpen(ComFile,FILE_CSV|FILE_READ|FILE_WRITE);
    
    if(fHandle!=INVALID_HANDLE)
      FileClose(fHandle);
  }