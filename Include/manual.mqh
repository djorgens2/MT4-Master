//+------------------------------------------------------------------+
//|                                                       manual.mqh |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2013 (c) Dennis Jorgenson"
#property link      "http://www.mql5.com"
#property strict

#include <Order.mqh>

//---- Trade Modes
enum TradeMode {
                    Manual,
                    Auto
               };

input TradeMode manTradeMode   = Auto;          // Trade Mode
input string    manComFile     = "manual.csv";  // Command File Name

#define MODE_MANUAL            0
#define MODE_AUTO              1

  bool   manualAuto          = false;
  bool   tradeModeChange     = false;
  bool   appCommand          = false;

  string params[];
  string appCommands[];


//+------------------------------------------------------------------+
//| AutoTrade - returns true if auto trading is authorized           |
//+------------------------------------------------------------------+
bool AutoTrade(void)
  {
    if (manualAuto)
      if (!eqhalt)
        return (true);
        
    return (false);
  }

//+------------------------------------------------------------------+
//| SetTradeMode - Enables/Disables auto trade                       |
//+------------------------------------------------------------------+
void SetTradeMode(TradeMode Mode, bool Default=false)
  {    
    bool lastAuto = manualAuto;
    
    if (Mode==Auto)
    {
      manualAuto=true;
      UpdateLabel("manMode","AUTO ("+manComFile+")",LawnGreen,8);
    }
    else
    if (Mode==Manual)
    {
      manualAuto=false;
      UpdateLabel("manMode","MANUAL ("+manComFile+")",Red,8);
    }
    else
    {
      manualAuto=false;
      UpdateLabel("manMode","BAD MODE",Red,8);
    }

    if (Default)
      SetDefaults();
        
    if (lastAuto!=manualAuto)
      tradeModeChange = true;
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
bool FormatPrice(string &Price, int Action)
  {
    double sopPips  = 0.00;

    if (upper(StringSubstr(Price,StringLen(Price)-1,1))=="P")
    {
      sopPips       = Pip(StringToDouble(StringSubstr(Price,0,StringLen(Price)-1)),InPoints);
      
      switch (Action)
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
    if (ArraySize(appCommands)>0)
    {      
      StringSplit(appCommands[0],"|",args);
      ArrayResize(args,Elements);

      for (int idx=1;idx<ArraySize(appCommands);idx++)
        appCommands[idx-1]=appCommands[idx];
        
      ArrayResize(appCommands,ArraySize(appCommands)-1);
      
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
    
    bool   lComment       = false;
    bool   bComment       = false;
    bool   holdeqprofit   = eqprofit;
    bool   holdeqhalf     = eqhalf;
    int    holdeqhold     = eqhold;
    int    closeAction    = OP_NO_ACTION;

    //--- clear trademode change
    tradeModeChange       = false;
    appCommand            = false;
       
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
          if (StringLen(Command) == 0)
            break;
          else
            fRecord = Command;
        
        lComment     = false;
        if (InStr(fRecord,"//"))
          lComment   = true;
          
        if (InStr(fRecord,"/*"))
          bComment   = true;

        if (InStr(fRecord,"*/"))
          bComment   = false;
          
        if (!bComment&&!lComment)
        {
          if (StringToUpper(fRecord))
            StringSplit(fRecord," ",params);
                    
          fRecord = "";
          for (int i=0;i<ArraySize(params);i++)
            fRecord += params[i]+"|";
          Print(fRecord);

          //--- Trade mode
          if (params[0] == "AUTO")
            switch (ArraySize(params))
            {
              case 1: SetTradeMode(MODE_AUTO);
                      break;
              case 2: if (params[1]=="DEFAULT")
                        SetTradeMode(MODE_AUTO,true);
                      break;
            }
          else
          if (params[0] == "MANUAL")
            switch (ArraySize(params))
            {
              case 1: SetTradeMode(MODE_MANUAL);
                      break;
              case 2: if (params[1]=="DEFAULT")
                        SetTradeMode(MODE_MANUAL,true);
                      break;
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
              if (FormatPrice(params[2], ActionCode(params[1]+params[0])))
              {
                if (params[0] == "MIT")
                  if (FormatPrice(params[3], ActionCode(params[1]+"LIMIT")))
                    OpenMITOrder(ActionCode(params[1]), StrToDouble(params[2]), StrToDouble(params[3]), StrToDouble(params[4]), point(StrToDouble(params[5])), params[6]);

                if (params[0] == "LIMIT")
                  if (FormatPrice(params[3], ActionCode(params[1]+"MIT")))
                    OpenLimitOrder(ActionCode(params[1]), StrToDouble(params[2]), StrToDouble(params[3]), StrToDouble(params[4]), point(StrToDouble(params[5])), params[6]);
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

            OpenOrder(ActionCode(params[0]), comment, lots); 
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

                          if (ActionCode(params[1])==OP_BUY)
                            OpenProfitPlan(OP_BUY,StringToDouble(params[2]),StringToDouble(params[3]),StringToDouble(params[4]));
                          else
                          if (ActionCode(params[1])==OP_SELL)
                            OpenProfitPlan(OP_SELL,StringToDouble(params[2])+Spread(InPoints),StringToDouble(params[3]),StringToDouble(params[4]));
                        }                    
                        break;
                      }

              case 2: if (params[1]=="CANCEL")
                      {
                        CloseProfitPlan(OP_BUY);
                        CloseProfitPlan(OP_SELL);
                      }
                      else
                      if (ActionCode(params[1])!=OP_NO_ACTION)
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
                        eqhold   = OP_NO_ACTION;

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
                      if (ActionCode(params[1])!=OP_NO_ACTION)
                      {
                        eqprofit = true;
                        eqhold   = OP_NO_ACTION;

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
                          params[2]=DoubleToStr(StrToDouble(params[2])-Spread(InPoints),Digits);

                        if (ActionCode(params[1])!=OP_NO_ACTION)
                          SetTargetPrice(ActionCode(params[1]),StrToDouble(params[2]));
                      }
                      break;

              case 4: if (params[3]=="HIDE")
                      {
                        if (ActionCode(params[1])==OP_SELL)
                          params[2]=DoubleToStr(StrToDouble(params[2])-Spread(InPoints),Digits);

                        if (ActionCode(params[1])!=OP_NO_ACTION)
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
                          params[2]=DoubleToStr(StrToDouble(params[2])+Spread(InPoints),Digits);

                        if (ActionCode(params[1])!=OP_NO_ACTION)
                          SetStopPrice(ActionCode(params[1]),StrToDouble(params[2]));
                      }
                      break;
              case 4: if (params[3]=="HIDE")
                      {
                        if (ActionCode(params[1])==OP_SELL)
                          params[2]=DoubleToStr(StrToDouble(params[2])+Spread(InPoints),Digits);

                        if (ActionCode(params[1])!=OP_NO_ACTION)
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
              case 1: SetEquityHold(OP_NO_ACTION);
                      break;
              case 2: if (params[1]=="CANCEL")
                        SetEquityHold(OP_NO_ACTION);
                      else
                        SetEquityHold(ActionCode(params[1]));
                      break;
              case 3: if (params[2] == "TRAIL")
                        SetEquityHold(ActionCode(params[1]),inpDefaultStop,true);
                      if (params[2] == "CANCEL")
                        SetEquityHold(OP_NO_ACTION);
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
                        CloseDCAPlan(ActionCode(params[1]));
                      else
                        OpenDCAPlan(ActionCode(params[1]),StringToDouble(params[2]));
                      break;
              case 4: OpenDCAPlan(ActionCode(params[1]),StringToDouble(params[2]),CloseOption(params[3]));
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
            ArrayResize(appCommands,ArraySize(appCommands)+1);
            appCommands[ArraySize(appCommands)-1] = fRecord;
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