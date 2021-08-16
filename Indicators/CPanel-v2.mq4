//+------------------------------------------------------------------+
//|                                                    CPanel-v2.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |CHARTEVENT_OBJECT_CLICK
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict
#property indicator_separate_window

#include <std_utility.mqh>

int       IndWinId = -1;
string    ShortName             = "CPanel-v2";
string    cpSessionTypes[4]     = {"Daily","Asia","Europe","US"};

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    IndWinId = ChartWindowFind(0,ShortName);
  
    //-- Account Information Box
    DrawBox("bxfAI",5,28,352,144,clrNONE,BORDER_FLAT,IndWinId);

    for (int type=0;type<4;type++)
    {
      DrawBox("bxhAI-Session"+cpSessionTypes[type],(75*type)+60,5,70,20,C'60,60,60',BORDER_RAISED,IndWinId);
      DrawBox("bxbAI-OpenInd"+cpSessionTypes[type],(75*type)+64,9,7,12,C'60,60,60',BORDER_RAISED,IndWinId);
      NewLabel("lbhAI-Session"+cpSessionTypes[type],LPad(cpSessionTypes[type]," ",4),85+(74*type),7,clrWhite,SCREEN_UL,IndWinId);
    }
        
    NewLabel("lbhAI-Bal","----- Balance/Equity -----",155,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-Bal","",140,42,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-Eq","",140,60,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-EqBal","",140,78,clrDarkGray,SCREEN_UL,IndWinId);

    UpdateLabel("lbvAI-Bal","$ 999999999",clrDarkGray,16,"Consolas");
    UpdateLabel("lbvAI-Eq","$-999999999",clrDarkGray,16,"Consolas");
    UpdateLabel("lbvAI-EqBal","$ 999999999",clrDarkGray,16,"Consolas");

    NewLabel("lbhAI-Eq%","------  Equity % ------",24,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-EqOpen%","Open",35,86,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-EqVar%","Var",96,86,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-Eq%","",36,42,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-EqOpen%","",16,68,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-EqVar%","",75,68,clrNONE,SCREEN_UL,IndWinId);
    UpdateLabel("lbvAI-Eq%","-999.9%",clrDarkGray,16);
    UpdateLabel("lbvAI-EqOpen%","-99.9%",clrDarkGray,12);
    UpdateLabel("lbvAI-EqVar%","-99.9%",clrDarkGray,12);

    NewLabel("lbhAI-Spread","-- Spread --",290,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-Spread","",290,42,clrNONE,SCREEN_UL,IndWinId);
    UpdateLabel("lbvAI-Spread","999.9",clrDarkGray,14);

    NewLabel("lbhAI-Margin","-- Margin --",290,66,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-Margin","",284,78,clrNONE,SCREEN_UL,IndWinId);
    UpdateLabel("lbvAI-Margin","999.9%",clrDarkGray,14);

    NewLabel("lbhAI-OrderBias","Bias",27,153,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-OrderBias","",20,116,clrDarkGray,SCREEN_UL,IndWinId);
    UpdateDirection("lbvAI-OrderBias",DirectionNone,clrDarkGray,30);

    NewLabel("lbhAI-Orders","----------------------  Order Aggregates ----------------------",70,102,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-"+"#","#",108,116,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-"+"L","Lots",144,116,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-"+"V","----  Value ----",188,116,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-"+"M","Mrg%",274,116,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-"+"E","Eq%",320,116,clrWhite,SCREEN_UL,IndWinId);

    string key;
    
    for (int row=0;row<=2;row++)
    {
      key = BoolToStr(row==2,"Net",proper(ActionText(row)));
      NewLabel("lbhAI-"+key+"Action","",70,128+(row*12),clrDarkGray,SCREEN_UL,IndWinId);

      NewLabel("lbvAI-"+key+"#","",104,128+(12*row),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvAI-"+key+"L","",130,128+(12*row),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvAI-"+key+"V","",186,128+(12*row),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvAI-"+key+"M","",266,128+(12*row),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvAI-"+key+"E","",310,128+(12*row),clrDarkGray,SCREEN_UL,IndWinId);

      UpdateLabel("lbhAI-"+key+"Action",key,clrDarkGray,10);

      UpdateLabel("lbvAI-"+key+"#","99",clrDarkGray,10,"Consolas");
      UpdateLabel("lbvAI-"+key+"L","000.00",clrDarkGray,10,"Consolas");
      UpdateLabel("lbvAI-"+key+"V","-000000000",clrDarkGray,10,"Consolas");
      UpdateLabel("lbvAI-"+key+"M","-00.0",clrDarkGray,10,"Consolas");
      UpdateLabel("lbvAI-"+key+"E","999.9",clrDarkGray,10,"Consolas");
    }


    //-- App Comms
    NewLabel("lbhAC-Trade","Trading",365,7,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhAC-Option","Options",445,7,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbvAC-Trading","Trade",408,7,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvAC-Options","Options",490,7,clrDarkGray,SCREEN_UL,IndWinId);

    //-- Order Config
    DrawBox("bxfOC-Long",361,28,298,144,C'0,42,0',BORDER_FLAT,IndWinId);
    DrawBox("bxfOC-Short",663,28,298,144,C'42,0,0',BORDER_FLAT,IndWinId);
    
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      NewLabel("lbhOC-"+ActionText(action)+"-Trading","Trading",368+(300*action),30,clrWhite,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-Equity","--------  Equity  ---------",378+(301*action),44,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-EQTarget","Target",377+(301*action),70,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-EQMin","Min",430+(301*action),70,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-EQPrice","Price",472+(301*action),70,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-Risk","---------  Risk  ----------",532+(301*action),44,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-RKBalance","Target",522+(301*action),70,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-RKMaxMargin","Margin",570+(301*action),70,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-RKPrice","Price",622+(301*action),70,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-EQBase","P/L",374+(301*action),100,clrGold,SCREEN_UL,IndWinId);
      UpdateLabel("lbhOC-"+ActionText(action)+"-EQBase","P/L",clrWhite,10);
      NewLabel("lbhOC-"+ActionText(action)+"-DCA","DCA",522+(301*action),100,clrGold,SCREEN_UL,IndWinId);
      UpdateLabel("lbhOC-"+ActionText(action)+"-DCA","DCA",clrWhite,10);
      NewLabel("lbhOC-"+ActionText(action)+"-Lots","------- Lot Sizing --------",378+(301*action),118,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-LotMax","Max",468+(301*action),144,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-LotSize","Target",372+(301*action),144,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-LotMin","Min",423+(301*action),144,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-LotMax","Max",468+(301*action),144,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-Zone","---------  Zone  ----------",532+(301*action),118,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-ZStep","Step",536+(301*action),144,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-ZMaxMargin","Margin",574+(301*action),144,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-ZZoneNow","Zone",620+(301*action),144,clrGold,SCREEN_UL,IndWinId);

      NewLabel("lbvOC-"+ActionText(action)+"-Enabled","Enabled",408+(301*action),30,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-EqTarget","999.9%",370+(301*action),56,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-EqMin","99.9%",420+(301*action),56,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-Target","9.99999",460+(301*action),56,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-DfltTarget","Default 9.99999 50p",384+(301*action),82,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MaxRisk","99.9%",520+(301*action),56,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MaxMargin","99.9%",570+(301*action),56,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-Stop","9.99999",610+(301*action),56,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-DfltStop","Default 9.99999 50p",538+(301*action),82,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-EQBase","999999999 (999%)",396+(301*action),100,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-DCA","9.99999 (9.9%)",552+(301*action),100,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-LotSize","99.99",370+(301*action),130,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MinLotSize","99.99",414+(301*action),130,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MaxLotSize","999.99",452+(301*action),130,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-DfltLotSize","Default 99.99",408+(301*action),155,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-ZoneStep","99.9",532+(301*action),130,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MaxZoneMargin","99.9%",574+(301*action),130,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MaxZoneNow","-99",620+(301*action),130,clrDarkGray,SCREEN_UL,IndWinId);
    }

    //-- Zone Margin frames
    DrawBox("bxfOZ-Long",965,28,298,144,C'0,42,0',BORDER_FLAT,IndWinId);
    DrawBox("bxfOZ-Short",1271,28,298,144,C'42,0,0',BORDER_FLAT,IndWinId);

    //-- Zone Metrics
    for (int row=0;row<11;row++)
      for (int col=0;col<=OP_SELL;col++)
      {
        if (row==0)
        {
          NewLabel("lbhOZ-"+ActionText(col)+"Z","Zone",979+(col*304),30,clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"#","#",1023+(col*304),30,clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"L","Lots",1049+(col*304),30,clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"V","------ Value -------",1087+(col*304),30,clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"M","Mrg%",1183+(col*304),30,clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"E","Eq%",1230+(col*304),30,clrGold,SCREEN_UL,IndWinId);
        }

        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"Z","-999.9",973+(col*304),44+(11*row),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"#","99",1017+(col*304),44+(11*row),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"L","000.00",1032+(col*304),44+(11*row),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"V","-0000000",1087+(col*304),44+(11*row),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"M","00.0",1161+(col*304),44+(11*row),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"E","999.9",1205+(col*304),44+(11*row),clrDarkGray,SCREEN_UL,IndWinId);
      }

    //-- Second Row ----------------------------------------------------------

    //-- Request Queue    
    DrawBox("bxfRQ-Request",5,176,957,309,C'0,42,0',BORDER_FLAT,IndWinId);
    NewLabel("lbhOQ-Request","Order Request Queue",10,178,clrWhite,SCREEN_UL,IndWinId);

    //-- Request Queue Headers
    NewLabel("lbhOQ-"+"-Key","Request #",12,191,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Status","Status",72,191,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Requestor","Requestor",130,191,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Type","Type",215,191,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Price","Price",266,191,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Lots","Lots",314,191,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Target","Target",354,191,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Stop","Stop",411,191,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Expiry","Expiration",464,191,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Limit","Limit",555,191,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Cancel","Cancel",600,191,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Resubmit","Resubmit",648,191,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Step","Step",704,191,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Memo","Order Comments",738,191,clrGold,SCREEN_UL,IndWinId);

    //-- Request Queue Fields
    for (int row=0;row<25;row++)
    {
      NewLabel("lbvOQ-"+(string)row+"-Key","00000000",12,204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      UpdateLabel("lbvOQ-"+(string)row+"-Key","00000000",clrDarkGray,8,"Consolas");
      NewLabel("lbvOQ-"+(string)row+"-Status","Pending",72,204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOQ-"+(string)row+"-Requestor","Bellwether",130,204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOQ-"+(string)row+"-Type","Sell Limit",210,204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOQ-"+(string)row+"-Price","0.00000",259,204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOQ-"+(string)row+"-Lots","0.00",314,204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOQ-"+(string)row+"-Target","0.00000",349,204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOQ-"+(string)row+"-Stop","0.00000",402,204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOQ-"+(string)row+"-Expiry","12/1/2019 11:00",451,204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOQ-"+(string)row+"-Limit","0.00000",544,204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOQ-"+(string)row+"-Cancel","0.00000",596,204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOQ-"+(string)row+"-Resubmit","Sell Limit",650,204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOQ-"+(string)row+"-Step","99.9",704,204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOQ-"+(string)row+"-Memo","123456789012345678901234567890123456789012345678901234567890123",738,204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
    }

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

