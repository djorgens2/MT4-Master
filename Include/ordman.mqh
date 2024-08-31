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
        int           Key;
        bool          HardStop;
       };

struct MethodRec
       {
         int          Action;
         OrderMethod  Method;
         OrderGroup   Group;
         int          Key;
       };

//-- Operational vars
int                   pcount;

string                params[];
string                commands[];
string                fRecord;

int                   fHandle       = INVALID_HANDLE;
int                   logHandle     = INVALID_HANDLE; 

bool                  fReplay       = false;
long                  fTime         = NoValue;
long                  fTick         = NoValue;
long                  rTick         = NoValue;
datetime              rTime         = NoValue;

string                comfile;


//COrder *order;

//+------------------------------------------------------------------+
//| ParseEntryPrice - Format manual entry price from comfile         |
//+------------------------------------------------------------------+
double ParseEntryPrice(int Action, string Price)
  {
    double pips     = 0.00;
    double price    = StringToDouble(Price);
    int    position = StringFind(Price,"P");

    if (position>0)
    {
      pips          = point(StringToDouble(StringSubstr(Price,0,position)));
      price         = BoolToDouble(Action==OP_BUY,Ask+pips,Bid+pips,_Digits);
    }

    return NormalizeDouble(price,_Digits);
  }

//+------------------------------------------------------------------+
//| ParseExitPrice - Formats manual exit price from comfile          |
//+------------------------------------------------------------------+
double ParseExitPrice(SummaryType Type, int Action, string Price, double Basis=0.00)
  {
    double price    = StringToDouble(Price);
    int    position = StringFind(Price,"P");

    if (position>0)
      price         = StringToDouble(StringSubstr(Price,0,position));

    return NormalizeDouble(order.Price(Type,Action,price,Basis,position>0),_Digits);
  }

//+------------------------------------------------------------------+
//| ParseGroup - returns group extracted from comline                |
//+------------------------------------------------------------------+
GroupRec ParseGroup(SummaryType Type)
  {
    GroupRec parser     = {NoAction,NoValue,NoValue,false,NoValue};

    parser.Action       = ActionCode(params[1]);
    parser.Price        = ParseExitPrice(Type,parser.Action,params[2]);
    parser.HardStop     = InStr(params[2],"*");
    
    if (IsBetween(parser.Action,OP_BUY,OP_SELL))
    {
      parser.Group      = ByAction;
      
      if (pcount>3)
        if (MethodCode(params[3])>NoValue)
        {
          parser.Group    = ByMethod;
          parser.Key      = MethodCode(params[3]);
        }      
        else
        {
          parser.Group    = ByZone;
          parser.Key      = (int)params[3];
        }
    }
    else
    if (InStr("+-",StringSubstr(params[1],0,1),1))
    {
      parser.Action     = ActionCode(StringSubstr(params[1],1));
      parser.Group      = (OrderGroup)BoolToInt(StringSubstr(params[1],0,1)=="+",ByProfit,ByLoss);
    }
    else
    if ((int)params[1]>0)
    {
      parser.Group      = ByTicket;
      parser.Key        = (int)params[1];
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
//| GroupStr - Returns translated parsed GroupRec text               |
//+------------------------------------------------------------------+
string GroupStr(GroupRec &Group)
  {
    string text    = "";

    Append(text,(string)pcount,"|");
    Append(text,ActionText(Group.Action),"|");
    Append(text,EnumToString(Group.Group),"|");
    Append(text,DoubleToString(Group.Price,_Digits),"|");
    Append(text,BoolToStr(Group.HardStop,"Hard","Soft"),"|");
    
    if (Group.Key>NoValue)
      Append(text,(string)Group.Key,"|");

    return text;
  }

//+------------------------------------------------------------------+
//| MethodStr - Returns translated parsed MetthodRec text            |
//+------------------------------------------------------------------+
string MethodStr(MethodRec &Method)
  {
    string text    = "";

    Append(text,(string)pcount,"|");
    Append(text,ActionText(Method.Action),"|");
    Append(text,EnumToString(Method.Method),"|");
    Append(text,EnumToString(Method.Group),"|");
    
    if (Method.Key>NoValue)
      Append(text,(string)Method.Key,"|");

    return text;
  }

//+------------------------------------------------------------------+
//| ParamStr - Returns parsed pipe delimitted params                 |
//+------------------------------------------------------------------+
string ParamStr(OrderMethod Method=NoValue)
  {
    string text    = BoolToStr(pcount==ArraySize(params),">","!");

    Append(text,(string)pcount,"|");

    for (int i=0;i<ArraySize(params);i++)
      Append(text,params[i],"|");

    Append(text,BoolToStr(Method>NoValue,EnumToString(Method)),"|");

    return text;
  }

//+------------------------------------------------------------------+
//| WriteLog - Writes executed manual commands to logfile            |
//+------------------------------------------------------------------+
void WriteLog(string Command)
  {
    if (logHandle!=INVALID_HANDLE)
    {
      string text = (string)(fmax(1,fTick));
    
      Append(text,TimeToStr((datetime)fTime,TIME_DATE|TIME_MINUTES|TIME_SECONDS),"|");
      Append(text,Command,"|");
    
      FileWrite(logHandle,text);
    }
  }

//+------------------------------------------------------------------+
//| ProcessCommand - Executes commands from ComFile/Replay LogFile   |
//+------------------------------------------------------------------+
void ProcessCommand(string Command)
  {
    OrderRequest request;

    WriteLog(Command);

    //-- Print utilities
    if (params[0]=="REPLAY")
      fReplay                    = true;
    else
    if (params[0]=="PRINT")
      switch (pcount)
      {
        case 2:     if (InStr("REQUEST",params[1],3))
                      Print(order.QueueStr());

                    if (InStr("ORDER",params[1],3))
                      Print(order.OrderStr());

                    if (InStr("LOG",params[1],3))
                      order.PrintLog();

                    if (InStr("SUMMARY",params[1],3))
                      Print(order.SummaryStr());
                    break;

        case 3:     if (InStr("REQUEST",params[1],3))
                      Print(order.QueueStr(ActionCode(params[2])));

                    if (InStr("ORDER",params[1],3))
                      Print(order.OrderStr(ActionCode(params[2])));

                    if (InStr("LOG",params[1],3))
                      order.PrintLog((int)params[2]);

                    if (InStr("MASTER",params[1],6))
                      Print(order.MasterStr(ActionCode(params[2])));
      }
    else

    //-- Hide Stops/TPs
    if (params[0]=="HIDE"||params[0]=="SHOW")
    {
      FormatConfig(params);

      if (IsBetween(ActionCode(params[1]),OP_BUY,OP_SELL))
      {
        if (pcount<3||InStr("STOPLOSSL",params[2],2)) order.SetDefaultStop(ActionCode(params[1]),NoValue,NoValue,params[0]=="HIDE");
        if (pcount<3||InStr("TAKEPROFITP",params[2],2)) order.SetDefaultTarget(ActionCode(params[1]),NoValue,NoValue,params[0]=="HIDE");
      }
    }
    else

    //-- Hedge Requests
    if (params[0]=="HEDGE")
      if (fabs(order[Net].Lots)>0)
        order.ProcessHedge(StringSubstr(comfile,0,StringLen(comfile)-4));
      else
        Alert("Nothing to hedge");
    else

    //-- Order Requests
    if (IsBetween(ActionCode(params[0]),OP_BUY,OP_SELL))
    {
      FormatOrder(params);

      request                  = order.BlankRequest(StringSubstr(comfile,0,StringLen(comfile)-4));
      request.Action           = ActionCode(params[0]);
      request.Price            = ParseEntryPrice(request.Action,params[2]);
      request.Type             = ActionCode(params[0],request.Price);
      request.Lots             = StringToDouble(params[1]);
      request.TakeProfit       = ParseExitPrice(Profit,request.Action,params[4],request.Price);
      request.StopLoss         = ParseExitPrice(Loss,request.Action,params[5],request.Price);
      request.Memo             = params[3];
      request.Expiry           = BoolToDate(StringLen(params[6])>9,StringToTime(params[6]),
                                    BoolToDate(StringSubstr(params[6],0,1)=="H",TimeCurrent()+(Period()*60*(int)StringSubstr(params[6],1)),
                                    BoolToDate(StringSubstr(params[6],0,1)=="D",TimeCurrent()+(Period()*60*24*(int)StringSubstr(params[6],1)),
                                    TimeCurrent()+(Period()*60))));
      
      switch (ActionCode(params[7]))
      {
        case OP_BUY:             request.Pend.Type      = BoolToInt(InStr("MITSTOP",params[8]),OP_BUYSTOP,
                                                          BoolToInt(InStr("LIMIT",params[8]),OP_BUYLIMIT));
                                  request.Pend.LBound    = ParseEntryPrice(Action(OP_BUY,InAction,InContrarian),params[9]);
                                  request.Pend.UBound    = ParseEntryPrice(OP_BUY,params[10]);
                                  request.Pend.Step      = StringToDouble(params[11]);
                                  break;

        case OP_SELL:            request.Pend.Type      = BoolToInt(InStr("MITSTOP",params[8]),OP_SELLSTOP,
                                                          BoolToInt(InStr("LIMIT",params[8]),OP_SELLLIMIT));
                                  request.Pend.LBound    = ParseEntryPrice(Action(OP_SELL,InAction,InContrarian),params[9]);
                                  request.Pend.UBound    = ParseEntryPrice(OP_SELL,params[10]);
                                  request.Pend.Step      = StringToDouble(params[11]);
                                  break;

        default:                 request.Pend.Type      = NoAction;
                                  request.Pend.LBound    = 0.00;
                                  request.Pend.UBound    = 0.00;
                                  request.Pend.Step      = 0.00;
      }
      
      if (order.Submitted(request))
        Print(order.RequestStr(request));
      else
      {
        Print("Bad Request Format: RequestStr: "+order.RequestStr(request));
        order.PrintLog(0);
      }
    }
    else

    //-- System/Action Halt
    if (params[0]=="DISABLE"||params[0]=="HALT")
      switch (pcount)
      {
        case 1:  order.Disable("Manual System Halt");
                  break;
        default: if (IsBetween(ActionCode(params[1]),OP_BUY,OP_SELL))
                    order.Disable(ActionCode(params[1]),"Manual "+proper(params[1])+" Halt");
      }
    else

    //-- System/Action Resume
    if (params[0]=="ENABLE"||params[0]=="RESUME"||params[0]=="START")
      switch (pcount)
      {
        case 1:  order.Enable("Manual System Enabled");
                  break;
        default: if (IsBetween(ActionCode(params[1]),OP_BUY,OP_SELL))
                    order.Enable(ActionCode(params[1]),"Manual "+proper(params[1])+" Enabled");
      }
    else

    //-- Order Cancelations
    if (InStr("CANCEL",params[0],3))
      switch (pcount)
      {
        case 2:   if (InStr("ALL",params[1],3))
                    order.Cancel(NoAction,"Manual Close [All Requests]");
                  else
                  if (IsBetween(ActionCode(params[1]),OP_BUY,OP_SELL))
                    order.Cancel(ActionCode(params[1]),"Manual Close [All "+proper(params[1])+"]");
                  else
                  if ((int)params[1]>0)
                    order.Cancel(order.Request((int)params[1]),"Manual Close [By Request #]");
                  break;

        case 3:   switch (ActionCode(params[1]))
                  {
                    case OP_BUY:  request.Type      = BoolToInt(InStr("MITSTOP",params[2],3),OP_BUYSTOP,
                                                      BoolToInt(params[2]=="LIMIT",OP_BUYLIMIT));

                                  order.Cancel(request.Type,"Manual Close [All "+proper(ActionText(request.Type))+"]");
                                  break;
                                                      
                    case OP_SELL: request.Type     = BoolToInt(InStr("MITSTOP",params[2],3),OP_SELLSTOP,
                                                      BoolToInt(params[2]=="LIMIT",OP_SELLLIMIT));

                                  order.Cancel(request.Type,"Manual Close [All "+proper(ActionText(request.Type))+"]");
                                  break;
                  }
      }
    else

    if (InStr("EQFUNDRISKZONE",params[0],2))
    {
      OrderMethod method   = NoValue;
        
      FormatConfig(params);

      int         item     = 2;
      int         action   = ActionCode(params[1]);

      if (IsBetween(action,OP_BUY,OP_SELL))
      {
        for (int config=item;config<6;config++)
          if (MethodCode(params[config])>NoValue)
            method           = MethodCode(params[config]);
          else
          {
            if (IsEqual(StringToDouble(params[config]),0.00,2))
            {
              //-- Fund Management
              if (params[0]=="EQ"||params[0]=="FUND")
              {
                if (item==2)   params[config]  = DoubleToString(order.Config(action).EquityTarget);
                if (item==3)   params[config]  = DoubleToString(order.Config(action).EquityMin);
              }
              else

              //-- Risk Mitigation
              if (params[0]=="RISK")
              {
                if (item==2)   params[config]  = DoubleToString(order.Config(action).MaxRisk);
                if (item==3)   params[config]  = DoubleToString(order.Config(action).MaxMargin);
                if (item==4)   params[config]  = DoubleToString(order.Config(action).LotScale);
                if (item==5)   params[config]  = BoolToStr(params[config]=="",DoubleToString(order.Config(action).DefaultLotSize));
              }
              else

              //-- Zone Management
              if (params[0]=="ZONE")
              {
                if (item==2)   params[config]  = DoubleToString(order.Config(action).ZoneStep);
                if (item==3)   params[config]  = DoubleToString(order.Config(action).MaxZoneMargin);
              }
            }

            params[item++]   = params[config];
          }

        if (params[0]=="RISK")                  
          order.ConfigureRisk(action,StringToDouble(params[2]),StringToDouble(params[3]),StringToDouble(params[4]),StringToDouble(params[4]));
        else
        if (params[0]=="ZONE")      
          order.ConfigureZone(action,StringToDouble(params[2]),StringToDouble(params[3]));
        else
          order.ConfigureFund(action,StringToDouble(params[2]),StringToDouble(params[3]),(OrderMethod)BoolToInt(method==NoValue,order.Config(action).Method,method));
      }
    }
    else
    
    //-- Order State Management
    if (MethodCode(params[0])>NoValue)
    {
      FormatConfig(params);
      MethodRec method = ParseMethod();
      order.SetMethod(method.Action,method.Method,method.Group,method.Key);
    }
    else

    //-- Order State Configuration
    {
      FormatConfig(params);
      
      //-- Risk Management
      if (InStr("STOPLOSSL",params[0]))
      {
        GroupRec group = ParseGroup(Loss);
        order.SetStopLoss(group.Action,group.Group,group.Price,group.Key);
      }
      else

      //-- Target Management
      if (InStr("TAKEPROFITARGETP",params[0]))
      {
        GroupRec group = ParseGroup(Profit);
        order.SetTakeProfit(group.Action,group.Group,group.Price,group.Key,group.HardStop);
      }
    }
  }


//+------------------------------------------------------------------+
//| ProcessComFile - retrieves and submits manual commands           |
//+------------------------------------------------------------------+
void ProcessComFile(void)
  {
    bool   verify         = false;
    bool   lComment       = false;
    bool   bComment       = false;
    
    if (comfile=="")
      return;

    fTick++;
    
    if (fReplay)
    {
      while (rTick<=fTick)
      {
        if (rTick==fTick)
          ProcessCommand(fRecord);

        if (FileIsEnding(fHandle))
        {
//          fReplay      = false;
          break;
        }
        else
        {
          fRecord      = FileReadString(fHandle);
          fRecord      = StringTrimLeft(StringTrimRight(fRecord));

          SplitStr(fRecord,"|",params);

          pcount       = ArraySize(params)-2;
          rTick        = (int)params[0];
          rTime        = StringToTime(params[1]);

          ArrayCopy(params,params,0,2);
          ArrayResize(params,pcount);
        }
      }
    }
    else
    //--- process command file
    {
      fHandle             = FileOpen(comfile,FILE_CSV|FILE_READ);

      if (fHandle==INVALID_HANDLE)
      {
        Print(">>>Error opening file ("+IntegerToString(fHandle)+") for read: ",GetLastError());
        return;
      }

      if (IsChanged(fTime,FileGetInteger(fHandle,FILE_MODIFY_DATE)))
      {
        UpdateLabel("lbvAC-File",comfile,clrYellow);
        UpdateLabel("lbvAC-Processed",TimeToStr((datetime)fTime,TIME_DATE|TIME_MINUTES|TIME_SECONDS),clrYellow);

        while (!FileIsEnding(fHandle)&&!fReplay)
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
            pcount  = ArraySize(params);

            for (int i=0;i<pcount;i++)
              Append(fRecord,params[i],"|");

            if (params[0]=="VERIFY")
              verify = true;
            else
            if (verify)
            {
              if (MessageBoxW(0,Symbol()+"> Verify Command\n"+"  Execute command ["+(string)pcount+"]: "+fRecord,"Command Verification",MB_ICONHAND|MB_YESNO)==IDYES)
                ProcessCommand(fRecord);
            }
            else ProcessCommand(fRecord);
          }
        }
      }
      else ObjectSet("lbvAC-Processed",OBJPROP_COLOR,clrDarkGray);

      FileClose(fHandle);
    }
  }

//+------------------------------------------------------------------+
//| ManualConfig - Configures Manual for operation                   |
//+------------------------------------------------------------------+
bool ManualConfig(string ComFile="", string LogFile="")
  {    
    comfile            = ComFile;

    if (StringLen(LogFile)>0)
    {
      logHandle        = FileOpen(LogFile,FILE_CSV|FILE_WRITE);

      if (logHandle==INVALID_HANDLE)
      {
        Print(">>>Error opening file ("+IntegerToString(logHandle)+") for write: ",GetLastError());
        return false;
      }
    }

    if (StringLen(comfile)>0)
    {
      ProcessComFile();
      FileClose(fHandle);

      if (fReplay)
      {
        comfile        = params[1];
        fHandle        = FileOpen(comfile,FILE_CSV|FILE_READ);

        if (fHandle==INVALID_HANDLE)
        {
          Print(">>>Error opening file ("+IntegerToString(fHandle)+") for read: ",GetLastError());
          return false;
        }

        UpdateLabel("lbvAC-File",comfile,clrYellow);
        UpdateLabel("lbvAC-Processed",TimeToStr((datetime)fTime,TIME_DATE|TIME_MINUTES|TIME_SECONDS),clrYellow);
      }
    }
      
    return true;
  }