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
                  fpBounce,
                  fpRisk,
                  fpHalt,
                  fpCheck,
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
    
    NewLabel("lbh-0A","Order Management",1200,4,clrGoldenrod,SCREEN_UL,IndWinId);
    
    NewLabel("lbh-OML1A","Long:",1200,16,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-OML2A","Short:",1500,16,clrWhite,SCREEN_UL,IndWinId);

    NewLabel("lbLongPlan","No Plan",1240,16,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbShortPlan","No Plan",1540,16,clrDarkGray,SCREEN_UL,IndWinId);

    NewLabel("lbh-WS1","State:",600,124,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-WS2","Flags:",600,137,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-WS3","Action:",600,150,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-WS4","Long:",870,124,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-WS5","Short:",870,137,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbLongState","No State",910,124,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbShortState","No State",910,137,clrDarkGray,SCREEN_UL,IndWinId);

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
        
        if (row==0&&col<ftPrior)
          DrawBox("hdAN"+StringSubstr(EnumToString(col),2),(90*col)+70,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
      }

    DrawBox("hdAnalyst",5,32,330,140,clrNONE,BORDER_FLAT,IndWinId);
//    DrawBox("hdActionLong",405,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
//    DrawBox("hdActionShort",495,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    
    DrawBox("hdActionState",345,32,235,140,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("hdActionLong",405,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdActionShort",495,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    
    DrawBox("hdSegment",590,32,490,85,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("hdWave",590,120,490,52,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("hdLong",635,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdShort",725,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdCrest",815,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdTrough",905,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdDecay",995,9,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdInterlace",1090,9,90,20,C'60,60,60',BORDER_RAISED,IndWinId);

    return(INIT_SUCCEEDED);
  }
