//+------------------------------------------------------------------+
//|                                                    CPanel-v1.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_separate_window

#include <std_utility.mqh>
#include <stdutil.mqh>
    
int       IndWinId = -1;
string    ShortName             = "CPanel-v1";    

    enum        FractalPoint
                {
                  fpTarget,
                  fpYield,
                  fpLoad,
                  fpBalance,
                  fpRisk,
                  fpHalt,
                  FractalPoints
                };
                
    enum        FractalType
                {
                  ftOrigin,
                  ftTrend,
                  ftTerm,
                  ftPrior,
                  ftCorrection,
                  FractalTypes
                };

     //--- Action States
    enum        ActionState
                {
                  Bank,         //--- Profit management slider         
                  Goal,
                  Yield,
                  Go,
                  Build,
                  Risk,
                  Opportunity,
                  Chance,       //--- Recovery management slider
                  Mercy,
                  Stop,
                  Halt,
                  Kill,         //--- Risk Management slider
                  Hold
                };
                                
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

    return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    IndWinId = ChartWindowFind(0,ShortName);
  
    NewLabel("lbState","",20,130,clrNONE,SCREEN_UL,IndWinId);
    
    NewLabel("lbh-0A","Order Management",1650,4,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbAN-Strategy","Strategy",1750,4,clrWhite,SCREEN_UL,IndWinId);
    
    NewLabel("lbh-OML1A","Long:",1200,16,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-OML2A","Short:",1830,16,clrWhite,SCREEN_UL,IndWinId);

    NewLabel("lbLongPlan","No Plan",1240,16,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbShortPlan","No Plan",1870,16,clrDarkGray,SCREEN_UL,IndWinId);
    
    for (int row=0;row<25;row++)
      for (int col=0;col<2;col++)
      {
        NewLabel("lb-OM"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Key","00000000",1200+(col*630),45+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        UpdateLabel("lb-OM"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Key","00000000",clrDarkGray,8,"Consolas");
        NewLabel("lb-OM"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Status","Pending",1260+(col*630),45+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lb-OM"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Requestor","Bellwether",1312+(col*630),45+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lb-OM"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Type","Market",1376+(col*630),45+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lb-OM"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Price","0.00000",1420+(col*630),45+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lb-OM"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Lots","0.00",1475+(col*630),45+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lb-OM"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Target","0.00000",1510+(col*630),45+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lb-OM"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Stop","0.00000",1563+(col*630),45+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lb-OM"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Expiry","12/1/2019 11:00",1612+(col*630),45+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lb-OM"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Memo","Yadda Yadda Yadda",1705+(col*630),45+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      }

      for (int col=0;col<2;col++)
      {
        NewLabel("lh-OM"+StringSubstr(ActionText(col),0,1)+"-Key","Order No.",1200+(col*630),30,clrGoldenrod,SCREEN_UL,IndWinId);
        NewLabel("lh-OM"+StringSubstr(ActionText(col),0,1)+"-Status","Status",1260+(col*630),30,clrGoldenrod,SCREEN_UL,IndWinId);
        NewLabel("lh-OM"+StringSubstr(ActionText(col),0,1)+"-Requestor","Requestor",1312+(col*630),30,clrGoldenrod,SCREEN_UL,IndWinId);
        NewLabel("lh-OM"+StringSubstr(ActionText(col),0,1)+"-Type","Type",1376+(col*630),30,clrGoldenrod,SCREEN_UL,IndWinId);
        NewLabel("lh-OM"+StringSubstr(ActionText(col),0,1)+"-Price","Price",1427+(col*630),30,clrGoldenrod,SCREEN_UL,IndWinId);
        NewLabel("lh-OM"+StringSubstr(ActionText(col),0,1)+"-Lots","Lots",1475+(col*630),30,clrGoldenrod,SCREEN_UL,IndWinId);
        NewLabel("lh-OM"+StringSubstr(ActionText(col),0,1)+"-Target","Target",1515+(col*630),30,clrGoldenrod,SCREEN_UL,IndWinId);
        NewLabel("lh-OM"+StringSubstr(ActionText(col),0,1)+"-Stop","Stop",1572+(col*630),30,clrGoldenrod,SCREEN_UL,IndWinId);
        NewLabel("lh-OM"+StringSubstr(ActionText(col),0,1)+"-Expiry","Expiration",1625+(col*630),30,clrGoldenrod,SCREEN_UL,IndWinId);
        NewLabel("lh-OM"+StringSubstr(ActionText(col),0,1)+"-Memo","Order Comments",1705+(col*630),30,clrGoldenrod,SCREEN_UL,IndWinId);
      }
      

    NewLabel("lbh-WS1","State:",600,124,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-WS2","Flags:",600,137,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-WS3","Action:",600,150,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-WS4","Long:",830,124,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-WS5","Short:",830,137,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-WS6","Pivot:",955,154,clrWhite,SCREEN_UL,IndWinId);

    NewLabel("lbLongState","No State",870,124,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbShortState","No State",870,137,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbIntBrkDir","^",1038,127,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbIntDir","^",1058,127,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbIntDev","-999.9",955,124,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbIntPivot","1.99990",990,154,clrDarkGray,SCREEN_UL,IndWinId);
    
    NewLabel("lbWaveState","No State",650,124,clrDarkGray,SCREEN_UL,IndWinId);    
    NewLabel("lbRetrace","Retrace",650,137,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbBreakout","Breakout",700,137,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbReversal","Reversal",755,137,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbBank","Bank",650,150,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbKill","Kill",685,150,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbMercy","Mercy",710,150,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbChance","Chance",755,150,clrDarkGray,SCREEN_UL,IndWinId);
        
    NewLabel("lbh-AN-Origin","Origin",100,12,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-AN-Trend","Trend",185,12,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-AN-Term","Term",280,12,clrWhite,SCREEN_UL,IndWinId);

    NewLabel("lbh-AL","Long",435,12,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-AS","Short",525,12,clrWhite,SCREEN_UL,IndWinId);

    NewLabel("lbh-L","Long",670,12,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-S","Short",755,12,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-C","Crest",845,12,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-T","Trough",932,12,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-D","Decay",1022,12,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-I","Interlace",1112,12,clrWhite,SCREEN_UL,IndWinId);

    NewLabel("lbLongCount","1",675,34,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbShortCount","1",765,34,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbCrestCount","1:1",850,34,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbTroughCount","1:1",940,34,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbDecayCount","1",1035,34,clrDarkGray,SCREEN_UL,IndWinId);

    NewLabel("lbLongNetRetrace","==",670,45,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbShortNetRetrace","==",760,45,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbCrestNetRetrace","==",850,45,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbTroughNetRetrace","==",940,45,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbDecayNetRetrace","==",1030,45,clrDarkGray,SCREEN_UL,IndWinId);
    
    string colHead[5]  = {"L","S","C","T","D"};
    for (int row=0;row<5;row++)
      for (int col=0;col<5;col++)
        NewLabel("lb"+colHead[col]+(string)row,"0.0000",660+(90*col),56+(11*row),clrDarkGray,SCREEN_UL,IndWinId);
    
    for (int row=0;row<25;row++)
      NewLabel("lbInterlace"+(string)row,"0.0000",1110,30+(11*row),clrDarkGray,SCREEN_UL,IndWinId);

    for (ActionState row=Bank;row<Hold;row++)
      for (int col=OP_NO_ACTION;col<=OP_SELL;col++)
        NewLabel("lbPL"+(string)col+":"+(string)row,EnumToString(row),430+BoolToInt(col==OP_NO_ACTION,-70,90*col),34+(11*row),clrWhite,SCREEN_UL,IndWinId);
        
    for (FractalPoint row=0;row<FractalPoints;row++)
      for (FractalType col=ftOrigin;col<=ftPrior;col++)
      {
        NewLabel("lbAN"+(string)(col-1)+":"+(string)row,StringSubstr(EnumToString(row),2),5+BoolToInt(col==0,15,90*col),34+(11*row),clrWhite,SCREEN_UL,IndWinId);
        
        if (col==0)
        {
          NewLabel("lhAN"+(string)col+":Flag","Flag:",60+(90*col),45+(11*FractalPoints),clrGoldenrod,SCREEN_UL,IndWinId);
          NewLabel("lhAN"+(string)col+":(e)","( e ):",60+(90*col),58+(11*FractalPoints),clrGoldenrod,SCREEN_UL,IndWinId);
          NewLabel("lhAN"+(string)col+":(r)","( r ):",60+(90*col),71+(11*FractalPoints),clrGoldenrod,SCREEN_UL,IndWinId);
          UpdateLabel("lhAN"+(string)col+":(e)","[e]:",clrGoldenrod,8,"Consolas");
          UpdateLabel("lhAN"+(string)col+":(r)","[r]:",clrGoldenrod,8,"Consolas");
          
        }

        if (row==0&&col<ftPrior)
        {
          DrawBox("hdAN"+StringSubstr(EnumToString(col),2),(90*col)+70,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
          NewLabel("lbAN"+(string)col+":Flag","====",100+(90*col),45+(11*FractalPoints),clrWhite,SCREEN_UL,IndWinId);
          NewLabel("lbAN"+(string)col+":(e)","====",100+(90*col),58+(11*FractalPoints),clrWhite,SCREEN_UL,IndWinId);
          NewLabel("lbAN"+(string)col+":(r)","====",100+(90*col),71+(11*FractalPoints),clrWhite,SCREEN_UL,IndWinId);
        }
      }

    DrawBox("hdAnalyst",5,32,330,140,clrNONE,BORDER_FLAT,IndWinId);
//    DrawBox("hdActionLong",405,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
//    DrawBox("hdActionShort",495,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    
    DrawBox("hdActionState",345,32,235,140,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("hdActionLong",405,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdActionShort",495,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    
    DrawBox("hdSegment",590,32,490,85,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("hdWave",590,120,350,52,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("hdIntDetail",945,120,135,52,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("hdLong",635,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdShort",725,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdCrest",815,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdTrough",905,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdDecay",995,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdInterlace",1090,9,90,20,C'60,60,60',BORDER_RAISED,IndWinId);

    return(INIT_SUCCEEDED);
  }
