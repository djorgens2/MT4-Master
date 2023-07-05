//+------------------------------------------------------------------+
//|                                                       manual.mqh |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2013 (c) Dennis Jorgenson"
#property link      "http://www.mql5.com"
#property strict

#include <Order.mqh>

input TradeMode manTradeMode   = Legacy;        // Trade Mode
input string    manComFile     = "manual.csv";  // Command File Name

  //-- Operational vars
  TradeMode trademode;

  string    params[];
  string    commands[];


//+------------------------------------------------------------------+
//| IsChanged - Returns true on TradeMode change                     |
//+------------------------------------------------------------------+
bool IsChanged(TradeMode &Mode, TradeMode Change)
  {
    if (Mode==Change)
      return (false);

    Mode                  = Change;

    return (true);
  }

//+------------------------------------------------------------------+
//| Mode - returns active trading mode                               |
//+------------------------------------------------------------------+
TradeMode Mode(void)
  {
    return (trademode);
  }

//+------------------------------------------------------------------+
//| AutoTrade - returns true if auto trading is authorized           |
//+------------------------------------------------------------------+
bool AutoTrade(void)
  {
    if (IsEqual(trademode,Legacy))
      if (!eqhalt)
        return (true);
        
    return (false);
  }

//+------------------------------------------------------------------+
//| SetTradeMode - Enables/Disables auto trade                       |
//+------------------------------------------------------------------+
void SetTradeMode(TradeMode Mode, bool Default=false)
  {    
    if (IsChanged(trademode,Mode))
    {
      UpdateLabel("manMode",EnumToString(Mode)+" ("+manComFile+")",LawnGreen,8);

      if (Default)
        SetDefaults();
    }
  }

//+------------------------------------------------------------------+
//| ActionCode - returns order action id (buy/sell)                  |
//+------------------------------------------------------------------+
int ActionCode(string Action, string Operation="")
  {
    int operation     = NoAction;
    
    if (Action=="BUY"||Action=="LONG")   operation   = OP_BUY;
    if (Action=="SELL"||Action=="SHORT") operation   = OP_SELL;
    
    switch (operation)
    {
      case OP_BUY:   if (IsEqual(Operation,"LIMIT",true)) return (OP_BUYLIMIT);
                     if (InStr("MITSTOP",Operation))      return (OP_BUYSTOP);
                     return (operation);

      case OP_SELL:  if (IsEqual(Operation,"LIMIT",true)) return (OP_SELLLIMIT);
                     if (InStr("MITSTOP",Operation))      return (OP_SELLSTOP);
                     return (operation);                  
    }

    return (NoAction);
  }

//+------------------------------------------------------------------+
//| SetQueueParams - Extracts queue params and sets defaults         |
//+------------------------------------------------------------------+
void SetQueueParams(string &Queue[])
  {
    string queue[7] = {"","","","0.00","0.00",(string)NoValue,"0.00"};
    
    for (int idx=0;idx<ArraySize(Queue)&&idx<7;idx++)
      queue[idx] = Queue[idx];
      
    ArrayResize(Queue,7);
    ArrayCopy(Queue,queue);
  }

//+------------------------------------------------------------------+
//| SetOrderParams - Extracts order params and sets defaults         |
//+------------------------------------------------------------------+
void SetOrderParams(string &Order[])
  {
    string ordDefault[7] = {"","","0.00","0.00","0.00","0.00",""};
    
    for (int idx=0; idx<ArraySize(Order) && idx<7;idx++)
      ordDefault[idx] = Order[idx];
      
    ArrayResize(Order,7);
    ArrayCopy(Order,ordDefault);
  }
  
//+------------------------------------------------------------------+
//| FormatPrice - Converts manual requests from Pips to Price        |
//+------------------------------------------------------------------+
bool FormatPrice(string &Price, int Operation)
  {
    double sopPips  = 0.00;

    if (upper(StringSubstr(Price,StringLen(Price)-1,1))=="P")
    {
      sopPips       = point(StringToDouble(StringSubstr(Price,0,StringLen(Price)-1)));
      
      switch (Operation)
      {
        case OP_SELLLIMIT:
        case OP_SELL:       Price = DoubleToStr(Bid+sopPips,Digits);
                            return (true);

        case OP_BUYLIMIT:
        case OP_BUY:        Price = DoubleToStr(Ask-sopPips,Digits);
                            return (true);
                       
        case OP_BUYSTOP:    Price = DoubleToStr(Ask+sopPips,Digits);
                            return (true);

        case OP_SELLSTOP:   Price = DoubleToStr(Bid-sopPips,Digits);
                            return (true);
                            
        default:            return (false);
      }
    }

    if (Price=="")
      Price  = "0.00";

    return (true);
  }
  
//+------------------------------------------------------------------+
//| AppCommand - Extracts order params and sets defaults             |
//+------------------------------------------------------------------+
bool AppCommand(string &args[], int Elements=0)
  {    
    if (ArraySize(commands)>0)
    {      
      SplitStr(commands[0],"|",args);
      ArrayResize(args,Elements);

      for (int idx=1;idx<ArraySize(commands);idx++)
        commands[idx-1]=commands[idx];
        
      ArrayResize(commands,ArraySize(commands)-1);
      
      return (true);
    }
    
    return (false);
  }

//+------------------------------------------------------------------+
//| GetManualRequest - retrieves and submits manual commands         |
//+------------------------------------------------------------------+
void GetManualRequest(string Command="")
  {
    int    try            =  0;
    int    fHandle        = INVALID_HANDLE;
    string fRecord;
    double lots           = 0.00;
    string comment        = "MANUAL";

    bool go               = true;
    bool verify           = false;

    bool   lComment       = false;
    bool   bComment       = false;
    bool   holdeqprofit   = eqprofit;
    bool   holdeqhalf     = eqhalf;
    int    holdeqhold     = eqhold;
    int    closeAction    = NoAction;

    QueueRec qrec;

    //--- process command file
    while(fHandle==INVALID_HANDLE)
    {
      fHandle=FileOpen(manComFile,FILE_CSV|FILE_READ);
      
      if (++try==20)
      {
        Print(">>>Error opening file ("+IntegerToString(fHandle)+") for read: ",GetLastError());
        return;
      }
    }
    
    while (!FileIsEnding(fHandle))
    {
        fRecord=FileReadString(fHandle);

        if (StringLen(fRecord) == 0)
          if (StringLen(Command) > 0)
            break;
          else
            fRecord  = Command;

        fRecord      = StringTrimLeft(StringTrimRight(fRecord));

        lComment     = false;
        if (InStr(fRecord,"//"))
          lComment   = true;
          
        if (InStr(fRecord,"/*"))
          bComment   = true;

        if (InStr(fRecord,"*/"))
          bComment   = false;
          
        if (StringLen(fRecord)>0&&!bComment&&!lComment)
        {
          SplitStr(fRecord," ",params);
                    
          fRecord = "";
          for (int i=0;i<ArraySize(params);i++)
            Append(fRecord,params[i],"|");
          Print(fRecord);

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

          //--- Trade mode
          if (params[0] == "AUTO")
            SetTradeMode(Auto);
          else
          if (params[0] == "LEGACY")
            switch (ArraySize(params))
            {
              case 1: SetTradeMode(Legacy);
                      break;
              case 2: if (params[1]=="DEFAULT")
                        SetTradeMode(Legacy,true);
                      break;
            }
          else
          if (params[0] == "MANUAL")
            switch (ArraySize(params))
            {
              case 1: SetTradeMode(Manual);
                      break;
              case 2: if (params[1]=="DEFAULT")
                        SetTradeMode(Manual,true);
                      break;
            }
          else

          //--- Queue orders
          if (params[0]=="Q")
          {
            SetQueueParams(params);

            if (params[1] == "CANCEL")
              CloseQueueOrder(ActionCode(params[2]));
            
            if (IsBetween(ActionCode(params[2],params[1]),OP_BUYLIMIT,OP_SELLSTOP))
            {
              qrec.Type          = ActionCode(params[2],params[1]);
              qrec.Price         = StrToDouble(params[3]);
              qrec.Step          = StrToDouble(params[4]);
              qrec.Stop          = StrToDouble(params[5]);
              qrec.Lots          = StrToDouble(params[6]);
            }
            
            OpenQueueOrder(qrec);
          }
          else          
          
          //--- Hedge orders
          if (InStr(params[0],"HED"))
          {
            if (IsBetween(Action(LotCount(NoAction,Net)),OP_BUY,OP_SELL))
              OpenOrder(Action(LotCount(NoAction,Net),InDirection,InContrarian),"Hedge ["+
                 DoubleToStr(fabs(LotCount(NoAction,Net)),ordLotPrecision)+"] "+DirText(Direction(LotCount(NoAction,Net))),fabs(LotCount(NoAction,Net)));
          }
          else          
          
          //--- Pending orders
          if (InStr(params[0],"MIT"))
          {
            SetOrderParams(params);
            
            if (params[1] == "CANCEL")
            {
              if (params[0] == "MIT")
                CloseMITOrder();

              if (params[0] == "LIMIT")
                CloseLimitOrder();
            }
            else
            {
              //--- Compute entry price
              if (FormatPrice(params[2],ActionCode(params[1],params[0])))
              {
                if (params[0] == "MIT")
                  if (FormatPrice(params[3],ActionCode(params[1],"LIMIT")))
                    OpenMITOrder(ActionCode(params[1]),StrToDouble(params[2]),StrToDouble(params[3]),StrToDouble(params[4]),point(StrToDouble(params[5])),params[6]);

                if (params[0] == "LIMIT")
                  if (FormatPrice(params[3], ActionCode(params[1],"MIT")))
                    OpenLimitOrder(ActionCode(params[1]),StrToDouble(params[2]),StrToDouble(params[3]),StrToDouble(params[4]),point(StrToDouble(params[5])),params[6]);
              }
            }
          }
          else

          // -- Manual market orders
          if (params[0] == "BUY" || params[0] == "SELL")
          {
            if (ArraySize(params)>1)
            {
              if (params[1]=="HALF")
                lots = HalfLot();
              else
              if (StrToDouble(params[1])>0)
                lots = StrToDouble(params[1]);
              else
                lots = 0.00;
            }
            else lots = LotSize();
            
            if (ArraySize(params)>2)
              comment = params[2];

            OpenOrder(ActionCode(params[0]),comment,lots);
          }
          else
          
          //---- Instant manual market closes
          if (params[0] == "CLOSE")
          {
            switch (ArraySize(params))
            {
              case 1:            CloseOrders(CloseAll);
                                 break;

              case 2:            if (params[1]=="ALL")
                                   CloseOrders(CloseAll);
                                 if (params[1]=="FIFO")
                                   CloseOrders(CloseFIFO);
                                 if (params[1]=="HALF")
                                   KillHalf();
                                 if (params[1]=="MIN")
                                   CloseOrders(CloseMin);
                                 if (params[1]=="MAX")
                                   CloseOrders(CloseMax);
                                 if (params[1]=="PROFIT")
                                   CloseOrders(CloseProfit);
                                 if (params[1]=="LOSS")
                                   CloseOrders(CloseLoss);
                                 if (ActionCode(params[1])==OP_BUY)
                                   CloseOrders(CloseAll,OP_BUY);
                                 if (ActionCode(params[1])==OP_SELL)
                                   CloseOrders(CloseAll,OP_SELL);
                                 break;
                                 
              case 3:            if (params[1]=="HALF")
                                   KillHalf(ActionCode(params[2]));
                                 if (params[1]=="MIN")
                                   CloseOrders(CloseMin,ActionCode(params[2]));
                                 if (params[1]=="MAX")
                                   CloseOrders(CloseMax,ActionCode(params[2]));
                                 if (params[1]=="PROFIT")
                                   CloseOrders(CloseProfit,ActionCode(params[2]));
                                 if (params[1]=="LOSS")
                                   CloseOrders(CloseLoss,ActionCode(params[2]));
                                 if (params[1]=="TICKET")
                                   CloseOrder((int)StringToInteger(params[2]),true);
                                 break;

              case 4:            if (params[1]=="PROFIT")
                                   CloseOrders(CloseProfit, ActionCode(params[2]),StrToDouble(params[3]));
                                 if (params[1]=="LOSS")
                                   CloseOrders(CloseLoss, ActionCode(params[2]),StrToDouble(params[3]));
                                 break;

              case 5:            if (params[1]=="PROFIT")
                                   CloseOrders(CloseProfit, ActionCode(params[2]),StrToDouble(params[3]),params[4]);
                                 if (params[1]=="LOSS")
                                   CloseOrders(CloseLoss, ActionCode(params[2]),StrToDouble(params[3]),params[4]);
            }
          }
          else
          
          if (params[0]=="PP")   //--- Close Profit Plan
          {
            switch (ArraySize(params))
            {
              case 5:
              case 4:
              case 3: { 
                        if (params[2]=="CANCEL")
                          CloseProfitPlan(ActionCode(params[1]));
                        else
                        {
                          SetOrderParams(params);
                          OpenProfitPlan(ActionCode(params[1]),StringToDouble(params[2]),StringToDouble(params[3]),StringToDouble(params[4]));
                        }                    
                        break;
                      }

              case 2: if (params[1]=="CANCEL")
                      {
                        CloseProfitPlan(OP_BUY);
                        CloseProfitPlan(OP_SELL);
                      }
                      else
                      if (ActionCode(params[1])!=NoAction)
                        CloseProfitPlan(ActionCode(params[1]));
                      break;

              case 1: {
                        break;
                      }
            }
          }
          else

          //---- Close profit trades
          if (params[0] == "TP")
          {
            if (ArraySize(params)>2)
              if (InStr(params[2],"P"))
              {
                if (ActionCode(params[1])==OP_SELL)
                  params[2]=DoubleToStr(Ask-point(StringToInteger(StringSubstr(params[2],0,StringLen(params[2])-1))),Digits);

                if (ActionCode(params[1])==OP_BUY)
                  params[2]=DoubleToStr(Bid+point(StringToInteger(StringSubstr(params[2],0,StringLen(params[2])-1))),Digits);
              }
          
            switch (ArraySize(params))
            {
              case 1: {
                        eqprofit = true;
                        eqhold   = NoAction;

                        if(CloseOrders(CloseConditional))
                        {
                          CloseProfitPlan(OP_BUY);
                          CloseProfitPlan(OP_SELL);
                        }
                        
                        eqprofit = holdeqprofit;
                        eqhold   = holdeqhold;
                      }
                      break;

              case 2: if (params[1] == "CANCEL")
                      {
                        SetTargetPrice(OP_BUY);
                        SetTargetPrice(OP_SELL);
                      }              
                      else
                      if (ActionCode(params[1])!=NoAction)
                      {
                        eqprofit = true;
                        eqhold   = NoAction;

                        if (CloseOrders(CloseConditional, ActionCode(params[1])))
                          CloseProfitPlan(ActionCode(params[1]));

                        eqprofit = holdeqprofit;
                        eqhold   = holdeqhold;
                      }
                      break;

              case 3: if (params[2]=="CANCEL")
                        SetTargetPrice(ActionCode(params[1]));
                      else
                      {
                        if (ActionCode(params[1])==OP_SELL)
                          params[2]=DoubleToStr(StrToDouble(params[2])-(Ask-Bid),Digits);

                        if (ActionCode(params[1])!=NoAction)
                          SetTargetPrice(ActionCode(params[1]),StrToDouble(params[2]));
                      }
                      break;

              case 4: if (params[3]=="HIDE")
                      {
                        if (ActionCode(params[1])==OP_SELL)
                          params[2]=DoubleToStr(StrToDouble(params[2])-(Ask-Bid),Digits);

                        if (ActionCode(params[1])!=NoAction)
                          SetTargetPrice(ActionCode(params[1]),StrToDouble(params[2]),true);
                      }
                      break;                      
            }
          }
          else

          //---- Sets risk
          if (params[0] == "RISK")
            switch (ArraySize(params))
            {
              case 1: SetRisk(inpMaxRisk,inpLotFactor);
                      break;
              case 2: SetRisk(StrToDouble(params[1]),inpLotFactor);
                      break;
              case 3: SetRisk(StrToDouble(params[1]),StrToDouble(params[2]));
                      break;
            }
          else

          //---- Sets stop price
          if (params[0] == "STOP")
          {
            if (ArraySize(params)>2)
              if (InStr(params[2],"P"))
              {
                if (ActionCode(params[1])==OP_SELL)
                  params[2]=DoubleToStr(Bid+point(StringToInteger(StringSubstr(params[2],0,StringLen(params[2])-1))),Digits);

                if (ActionCode(params[1])==OP_BUY)
                  params[2]=DoubleToStr(Bid-point(StringToInteger(StringSubstr(params[2],0,StringLen(params[2])-1))),Digits);
              }
                      
            switch (ArraySize(params))
            {
              case 1: 
              case 2: if (params[1]=="CANCEL")
                      {
                        SetStopPrice(OP_BUY);
                        SetStopPrice(OP_SELL);
                      }
                      break;
              case 3: if (params[2]=="CANCEL")
                        SetStopPrice(ActionCode(params[1]));
                      else
                      {
                        if (ActionCode(params[1])==OP_SELL)
                          params[2]=DoubleToStr(StrToDouble(params[2])+(Ask-Bid),Digits);

                        if (ActionCode(params[1])!=NoAction)
                          SetStopPrice(ActionCode(params[1]),StrToDouble(params[2]));
                      }
                      break;
              case 4: if (params[3]=="HIDE")
                      {
                        if (ActionCode(params[1])==OP_SELL)
                          params[2]=DoubleToStr(StrToDouble(params[2])+(Ask-Bid),Digits);

                        if (ActionCode(params[1])!=NoAction)
                          SetStopPrice(ActionCode(params[1]),StrToDouble(params[2]),true);
                      }
                      break;
            }
          }          
          else
          
          //---- Don't close trades if EQ% is met.
          if (params[0]=="HOLD")
            switch (ArraySize(params))
            {
              case 1: SetEquityHold(NoAction);
                      break;
              case 2: if (params[1]=="CANCEL")
                        SetEquityHold(NoAction);
                      else
                        SetEquityHold(ActionCode(params[1]));
                      break;
              case 3: if (params[2] == "TRAIL")
                        SetEquityHold(ActionCode(params[1]),inpDefaultStop,true);
                      if (params[2] == "CANCEL")
                        SetEquityHold(NoAction);
                      break;
              case 4: if (params[2] == "TRAIL")
                        SetEquityHold(ActionCode(params[1]),StringToDouble(params[3]),true);
                      break;
            }
          else
          
          //---- set DCA action
          if (params[0] == "DCA")
          {
            switch (ArraySize(params))
            {
              case 1: CloseDCAPlan(OP_BUY);
                      CloseDCAPlan(OP_SELL);
                      break;
              case 2: if (params[1]=="CANCEL")
                      {
                        CloseDCAPlan(OP_BUY);
                        CloseDCAPlan(OP_SELL);
                      }
                      else
                        OpenDCAPlan(ActionCode(params[1]));
                      break;
              case 3: if (params[1]=="CANCEL")
                        CloseDCAPlan(ActionCode(params[2]));
                      else
                        OpenDCAPlan(ActionCode(params[1]),StringToDouble(params[2]));
                      break;
              case 4: OpenDCAPlan(ActionCode(params[1]),StringToDouble(params[2]),CloseOption(params[3]));
                      break;
              case 5: OpenDCAPlan(ActionCode(params[1]),StringToDouble(params[2]),CloseOption(params[3]),params[4]=="KEEP");
                      break;
              case 6: OpenDCAPlan(ActionCode(params[1]),StringToDouble(params[2]),CloseOption(params[3]),params[4]=="KEEP",StringToDouble(params[5]));
                      break;
            }
          }
          else          

          //---- Suspend trading; denies new order requests
          if (params[0]=="HALT")
            switch (ArraySize(params))
            {
              case 1: SetProfitPolicy(eqhalt);
                      break;
              case 2: SetActionHold(ActionCode(params[1]));
                      break;
            }
          else

          //---- Resume trading;
          if (params[0]=="RESUME")
            switch (ArraySize(params))
            {
              case 1: SetTradeResume();
                      break;
              case 2: SetTradeResume(ActionCode(params[1]));
                      break;
            }
          else

          //---- Close Half/Full only profitable trades if EQ% is met.
          if (params[0]=="EQP")
            SetProfitPolicy(eqprofit);
          else

          if (params[0]=="EQH")
            SetProfitPolicy(eqhalf);
          else

          if (params[0]=="EQR")
            SetProfitPolicy(eqretain);
          else

          //---- Sets EQ% default; overrides input param defaults
          if (params[0]=="EQ")
            switch (ArraySize(params))
            {
              case 1: SetEquityTarget(inpMinTarget,inpMinProfit);
                      break;

              case 2: SetEquityTarget(StrToDouble(params[1]),inpMinProfit);
                      break;

              case 3: SetEquityTarget(StrToDouble(params[1]),StrToDouble(params[2]));
                      break;            
            }
          else

          //--- Pass command back to App
          {
            ArrayResize(commands,ArraySize(commands)+1);
            commands[ArraySize(commands)-1] = fRecord;
          }
        }
    }

    FileClose(fHandle);

    fHandle=FileOpen(manComFile,FILE_CSV|FILE_WRITE);

    if(fHandle!=INVALID_HANDLE)
    {
      FileWrite(fHandle,"");
      FileClose(fHandle);
    }
  }

//+------------------------------------------------------------------+
//| Init - Configures Manual for operation                           |
//+------------------------------------------------------------------+
void ManualInit()
  {        
    int    fHandle = -1;
    
    NewLabel("manMode","",72,2,White,SCREEN_UR);

    OrderInit();
    SetTradeMode(manTradeMode);
    
    //---- If not Exists, create file
    fHandle=FileOpen(manComFile,FILE_CSV|FILE_READ|FILE_WRITE);
    
    if(fHandle!=INVALID_HANDLE)
      FileClose(fHandle);
}