//+------------------------------------------------------------------+
//|                                                       ordman.mqh |
//|                                 Copyright 2013, Dennis Jorgenson |
//+------------------------------------------------------------------+
#property copyright "Copyright 2013 (c) Dennis Jorgenson"
#property strict

#include <Class/Order.mqh>

//-- Record Defs
struct GroupRec 
       {
        int           Action;
        OrderGroup    Group;
        double        Price;
        bool          InPips;
        int           Key;
       };

struct MethodRec
       {
         int          Action;
         OrderMethod  Method;
         OrderGroup   Group;
         int          Key;
       };

//-- Operational vars
string                params[];
string                commands[];
string                comfile;
long                  fTime  = NoValue;

//+------------------------------------------------------------------+
//| ParseGroup - returns group extracted from comline                |
//+------------------------------------------------------------------+
GroupRec ParseGroup(void)
  {
    GroupRec parser     = {NoAction,NoValue,NoValue,false,NoValue};

    parser.Action       = ActionCode(params[1]);
    parser.InPips       = StringSubstr(params[2],StringLen(params[2])-1)=="P";
    parser.Price        = FormatPrice(parser.Action,params[2],parser.InPips);
    
    if (IsBetween(parser.Action,OP_BUY,OP_SELL))
      if (StringSubstr(params[3],0,1)=="Z")
      {
        parser.Group    = ByZone;
        parser.Key      = (int)StringSubstr(params[3],1);
      }
      else
      if (MethodCode(params[3])>NoValue)
      {
        parser.Group    = ByMethod;
        parser.Key      = MethodCode(params[3]);
      }      
      else parser.Group = ByAction;
    else
    if (InStr("+-",StringSubstr(params[1],0,1),1))
    {
      parser.Action     = ActionCode(StringSubstr(params[1],1));
      parser.Group      = (OrderGroup)BoolToInt(StringSubstr(params[1],0,1)=="+",ByProfit,ByLoss);
    }
    else
    if (StringSubstr(params[1],0,1)=="T")
    {
      parser.Group      = ByTicket;
      parser.Key        = (int)StringSubstr(params[1],1);
    }

    return parser;
  }

//+------------------------------------------------------------------+
//| ParseMethod - returns method extracted from comline              |
//+------------------------------------------------------------------+
MethodRec ParseMethod(void)
  {
    MethodRec parser = {NoAction,NoValue,NoValue,NoValue};

    parser.Action       = ActionCode(params[1]);
    parser.Method       = MethodCode(params[0]);

    if (IsBetween(parser.Action,OP_BUY,OP_SELL))
      if (StringSubstr(params[2],0,1)=="Z")
      {
        parser.Group    = ByZone;
        parser.Key      = (int)StringSubstr(params[2],1);
      }
      else
      if (MethodCode(params[2])>NoValue)
      {
        parser.Group    = ByMethod;
        parser.Key      = MethodCode(params[2]);
      }      
      else parser.Group = ByAction;
    else
    if (InStr("+-",StringSubstr(params[1],0,1),1))
    {
      parser.Action     = ActionCode(StringSubstr(params[1],1));
      parser.Group      = (OrderGroup)BoolToInt(StringSubstr(params[1],0,1)=="+",ByProfit,ByLoss);
    }
    else
    if (StringSubstr(params[1],0,1)=="T")
    {
      parser.Group      = ByTicket;
      parser.Key        = BoolToInt(parser.Group==ByTicket,(int)StringSubstr(params[1],1),NoValue);
    }

    return parser;
  }

//+------------------------------------------------------------------+
//| ActionCode - returns order action id (buy/sell)                  |
//+------------------------------------------------------------------+
int ActionCode(string Action, double Price=0.00, bool Contrarian=false)
  {
    int action                                    = NoAction;
    
    if (Action=="BUY"||Action=="LONG")   action   = BoolToInt(Contrarian,OP_SELL,OP_BUY);
    if (Action=="SELL"||Action=="SHORT") action   = BoolToInt(Contrarian,OP_BUY,OP_SELL);
    
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
    if (trim(Method)=="HOLD")           return (Hold);
    if (trim(Method)=="FULL")           return (Full);
    if (InStr("SPLITEQH",Method,3))     return (Split);
    if (InStr("RETAINEQR",Method,3))    return (Retain);
    if (trim(Method)=="DCA")            return (DCA);
    if (trim(Method)=="HEDGE")          return (Hedge);
    if (InStr("RECAPTURE",Method,5))    return (Recapture);
    if (InStr("CLOSEKILL",Method,4))    return (Kill);

    return (NoValue);
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
double FormatPrice(int Action, string Price, bool OutPips=false)
  {
    double pips     = 0.00;
    double price    = StringToDouble(Price);

    if (StringSubstr(Price,StringLen(Price)-1,1)=="P")
    {
      pips          = point(StringToDouble(StringSubstr(Price,0,StringLen(Price)-1)));
      price         = BoolToDouble(Action==OP_BUY,Ask+pips,Bid+pips,Digits);
    }

    return BoolToDouble(OutPips,pip(pips),price,Digits);
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

    if (IsChanged(fTime,FileGetInteger(fHandle,FILE_MODIFY_DATE)))
    {
      UpdateLabel("lbvAC-File",comfile,clrYellow);
      UpdateLabel("lbvAC-Processed",TimeToStr((datetime)fTime,TIME_DATE|TIME_MINUTES|TIME_SECONDS),clrYellow);
    }
    else
    {
      ObjectSet("lbvAC-Processed",OBJPROP_COLOR,clrDarkGray);
      FileClose(fHandle);
      return;
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
          go = MessageBoxW(0,Symbol()+"> Verify Command\n"+"  Execute command ["+(string)pCount+"]: "+fRecord,"Command Verification",MB_ICONHAND|MB_YESNO)==IDYES;

        //--- Verify Mode
        if (go)
        {
          //-- Print utilities
          if (params[0]=="PRINT")
            switch (pCount)
            {
              case 2:     if (InStr("REQUEST",params[1],3))
                            Print(Order.QueueStr());

                          if (InStr("ORDER",params[1],3))
                            Print(Order.OrderStr());

                          if (InStr("LOG",params[1],3))
                            Order.PrintLog();

                          if (InStr("SUMMARY",params[1],3))
                            Print(Order.SummaryStr());
                          break;

              case 3:     if (InStr("REQUEST",params[1],3))
                            Print(Order.QueueStr(ActionCode(params[2])));

                          if (InStr("ORDER",params[1],3))
                            Print(Order.OrderStr(ActionCode(params[2])));

                          if (InStr("LOG",params[1],3))
                            Order.PrintLog((int)params[2]);

                          if (InStr("MASTER",params[1],6))
                            Print(Order.MasterStr(ActionCode(params[2])));
            }
          else

          //-- Hide Stops/TPs
          if (params[0]=="HIDE"||params[0]=="SHOW")
          {
            FormatConfig(params);

            if (IsBetween(ActionCode(params[1]),OP_BUY,OP_SELL))
            {
              if (pCount<3||InStr("STOPLOSSL",params[2],2)) Order.SetDefaultStop(ActionCode(params[1]),NoValue,NoValue,params[0]=="HIDE");
              if (pCount<3||InStr("TAKEPROFITP",params[2],2)) Order.SetDefaultTarget(ActionCode(params[1]),NoValue,NoValue,params[0]=="HIDE");
            }
          }
          else

          //-- Hedge Requests
          if (params[0]=="HEDGE")
            if (fabs(Order[Net].Lots)>0)
              Order.ProcessHedge(StringSubstr(comfile,0,StringLen(comfile)-4));
            else
              Alert("Nothing to hedge");
          else

          //-- Order Requests
          if (IsBetween(ActionCode(params[0]),OP_BUY,OP_SELL))
          {
            FormatOrder(params);

            request                  = Order.BlankRequest(StringSubstr(comfile,0,StringLen(comfile)-4));
            request.Action           = ActionCode(params[0]);
            request.Price            = FormatPrice(request.Action,params[2]);
            request.Type             = ActionCode(params[0],request.Price);
            request.Lots             = StringToDouble(params[1]);
            request.TakeProfit       = Order.Price(Profit,request.Action,FormatPrice(request.Action,params[4],InStr(params[4],"P")),request.Price,InStr(params[4],"P"));
            request.StopLoss         = Order.Price(Loss,request.Action,FormatPrice(request.Action,params[5],InStr(params[5],"P")),request.Price,InStr(params[5],"P"));
            request.Memo             = params[3];
            request.Expiry           = BoolToDate(StringLen(params[6])>9,StringToTime(params[6]),
                                         BoolToDate(StringSubstr(params[6],0,1)=="H",TimeCurrent()+(Period()*60*(int)StringSubstr(params[6],1)),
                                         BoolToDate(StringSubstr(params[6],0,1)=="D",TimeCurrent()+(Period()*60*24*(int)StringSubstr(params[6],1)),
                                         TimeCurrent()+(Period()*60))));
            
            switch (ActionCode(params[7]))
            {
              case OP_BUY:             request.Pend.Type      = BoolToInt(InStr("MITSTOP",params[8]),OP_BUYSTOP,
                                                                BoolToInt(InStr("LIMIT",params[8]),OP_BUYLIMIT));
                                       request.Pend.LBound    = FormatPrice(Action(OP_BUY,InAction,InContrarian),params[9]);
                                       request.Pend.UBound    = FormatPrice(OP_BUY,params[10]);
                                       request.Pend.Step      = StringToDouble(params[11]);
                                       break;

              case OP_SELL:            request.Pend.Type      = BoolToInt(InStr("MITSTOP",params[8]),OP_SELLSTOP,
                                                                BoolToInt(InStr("LIMIT",params[8]),OP_SELLLIMIT));
                                       request.Pend.LBound    = FormatPrice(Action(OP_SELL,InAction,InContrarian),params[9]);
                                       request.Pend.UBound    = FormatPrice(OP_SELL,params[10]);
                                       request.Pend.Step      = StringToDouble(params[11]);
                                       break;

              default:                 request.Pend.Type      = NoAction;
                                       request.Pend.LBound    = 0.00;
                                       request.Pend.UBound    = 0.00;
                                       request.Pend.Step      = 0.00;
            }
            
            if (Order.Submitted(request))
              Print(Order.RequestStr(request));
            else
            {
              Print("Bad Request Format: FileString: "+fRecord+" RequestStr: "+Order.RequestStr(request));
              Order.PrintLog(0);
            }
          }
          else

          //-- System/Action Halt
          if (params[0]=="DISABLE"||params[0]=="HALT")
            switch (pCount)
            {
              case 1:  Order.Disable("Manual System Halt");
                       break;
              default: if (IsBetween(ActionCode(params[1]),OP_BUY,OP_SELL))
                         Order.Disable(ActionCode(params[1]),"Manual "+proper(params[1])+" Halt");
            }
          else

          //-- System/Action Resume
          if (params[0]=="ENABLE"||params[0]=="RESUME"||params[0]=="START")
            switch (pCount)
            {
              case 1:  Order.Enable("Manual System Enabled");
                       break;
              default: if (IsBetween(ActionCode(params[1]),OP_BUY,OP_SELL))
                         Order.Enable(ActionCode(params[1]),"Manual "+proper(params[1])+" Enabled");
            }
          else

          //-- Order Cancelations
          if (InStr("CANCEL",params[0],3))
            switch (pCount)
            {
              case 2:   if (InStr("ALL",params[1],3))
                          Order.Cancel(NoAction,"Manual Close [All Requests]");
                        else
                        if (IsBetween(ActionCode(params[1]),OP_BUY,OP_SELL))
                          Order.Cancel(ActionCode(params[1]),"Manual Close [All "+proper(params[1])+"]");
                        break;

              case 3:   if (InStr("REQUEST",params[1],3))
                          Order.Cancel(Order.Request((int)params[2]),"Manual Close [By Request #]");
                        else
                        switch (ActionCode(params[1]))
                        {
                          case OP_BUY:  request.Type      = BoolToInt(InStr("MITSTOP",params[2],3),OP_BUYSTOP,
                                                            BoolToInt(params[2]=="LIMIT",OP_BUYLIMIT));

                                        Order.Cancel(request.Type,"Manual Close [All "+proper(ActionText(request.Type))+"]");
                                        break;
                                                           
                          case OP_SELL: request.Type     = BoolToInt(InStr("MITSTOP",params[2],3),OP_SELLSTOP,
                                                           BoolToInt(params[2]=="LIMIT",OP_SELLLIMIT));

                                        Order.Cancel(request.Type,"Manual Close [All "+proper(ActionText(request.Type))+"]");
                                        break;
                        }
            }
          else

          if (InStr("EQFUNDRISKZONE",params[0],2))
          {
            FormatConfig(params);
            
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
            FormatConfig(params);
            MethodRec method = ParseMethod();
            Order.SetMethod(method.Action,method.Method,method.Group,method.Key);
          }
          else

          //-- Order State Configuration
          {
            FormatConfig(params);
            GroupRec group = ParseGroup();
            
            //-- Risk Management
            if (InStr("STOPLOSSL",params[0]))
                Order.SetStopLoss(group.Action,group.Group,group.Price,group.InPips,group.Key);
            else

            //-- Target Management
            if (InStr("TAKEPROFITARGETP",params[0]))
                Order.SetTakeProfit(group.Action,group.Group,group.Price,group.InPips,group.Key);
//            else

          }
        }
      }
    }

    FileClose(fHandle);
  }

//+------------------------------------------------------------------+
//| ManualConfig - Configures Manual for operation                   |
//+------------------------------------------------------------------+
void ManualConfig(string ComFile)
  {        
    int         fHandle;
    
    comfile             = ComFile;

    //---- If not Exists, create file
    fHandle=FileOpen(ComFile,FILE_CSV|FILE_READ|FILE_WRITE);
    
    if(fHandle!=INVALID_HANDLE)
      FileClose(fHandle);
  }