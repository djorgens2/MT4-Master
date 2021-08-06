//+------------------------------------------------------------------+
//|                                                    CPanel-v2.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
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
        
    //-- App Comms
    NewLabel("lbhAC-Trade","Trading",365,7,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhAC-Option","Options",445,7,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbvAC-Trading","Trade",408,7,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvAC-Options","Options",490,7,clrDarkGray,SCREEN_UL,IndWinId);

    NewLabel("lbhAI-Bal","----- Balance/Equity -----",155,30,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-Bal","",140,42,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-Eq","",140,60,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-EqBal","",140,78,clrDarkGray,SCREEN_UL,IndWinId);

    UpdateLabel("lbvAI-Bal","$ 999999999",clrDarkGray,16,"Consolas");
    UpdateLabel("lbvAI-Eq","$-999999999",clrDarkGray,16,"Consolas");
    UpdateLabel("lbvAI-EqBal","$ 999999999",clrDarkGray,16,"Consolas");

    NewLabel("lbhAI-Eq%","------  Equity % ------",24,30,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-EqOpen%","Open",38,86,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-EqVar%","Var",98,86,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-Eq%","",36,42,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-EqOpen%","",16,68,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-EqVar%","",75,68,clrNONE,SCREEN_UL,IndWinId);
    UpdateLabel("lbvAI-Eq%","-999.9%",clrDarkGray,16);
    UpdateLabel("lbvAI-EqOpen%","-99.9%",clrDarkGray,12);
    UpdateLabel("lbvAI-EqVar%","-99.9%",clrDarkGray,12);

    NewLabel("lbhAI-Spread","-- Spread --",290,30,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-Spread","",290,42,clrNONE,SCREEN_UL,IndWinId);
    UpdateLabel("lbvAI-Spread","999.9",clrDarkGray,14);

    NewLabel("lbhAI-Margin","-- Margin --",290,66,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-Margin","",284,78,clrNONE,SCREEN_UL,IndWinId);
    UpdateLabel("lbvAI-Margin","999.9%",clrDarkGray,14);

    NewLabel("lbhAI-OrderBias","Bias",27,153,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-OrderBias","",20,116,clrDarkGray,SCREEN_UL,IndWinId);
    UpdateDirection("lbvAI-OrderBias",DirectionNone,clrDarkGray,30);

    NewLabel("lbhAI-Orders","----------------------  Order Aggregates ----------------------",70,102,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-"+"#","#",108,116,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-"+"L","Lots",144,116,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-"+"V","----  Value ----",188,116,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-"+"M","Mrg%",274,116,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-"+"E","Eq%",320,116,clrWhite,SCREEN_UL,IndWinId);


    DrawBox("bxf-OM",663,28,294,144,clrNONE,BORDER_FLAT,IndWinId);

    //-- Order Details
    DrawBox("bxfOD-Long",361,28,298,144,C'0,42,0',BORDER_FLAT,IndWinId);
    DrawBox("bxfOD-Short",961,28,298,144,C'42,0,0',BORDER_FLAT,IndWinId);

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


    //-- Second Row ----------------------------------------------------------

    //-- Request Queue    
    DrawBox("bxfRQ-Request",5,176,910,309,C'0,42,0',BORDER_FLAT,IndWinId);

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

    //-- Request Queue Headers
    NewLabel("lbhOQ-"+"-Key","Request #",12,191,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Status","Status",72,191,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Requestor","Requestor",130,191,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Type","Type",215,191,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Price","Price",266,191,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Lots","Lots",314,191,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Target","Target",354,191,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Stop","Stop",411,191,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Expiry","Expiration",464,191,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Limit","Limit",555,191,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Cancel","Cancel",600,191,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Resubmit","Resubmit",648,191,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Step","Step",704,191,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-"+"-Memo","Order Comments",738,191,clrGoldenrod,SCREEN_UL,IndWinId);

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

