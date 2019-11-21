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
    
int       IndWinId = -1;
string    ShortName             = "CPanel-v1";    

     //--- Action States
     enum       ActionState
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
  
    NewLabel("lbState","",32,10,clrNONE,SCREEN_UL,IndWinId);
    
    NewLabel("lbh-1A","Long:",60,16,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-2A","Short:",60,27,clrWhite,SCREEN_UL,IndWinId);

    NewLabel("lbLongState","No State",100,16,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbShortState","No State",100,27,clrDarkGray,SCREEN_UL,IndWinId);

    NewLabel("lbLongPlan","No Plan",170,16,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbShortPlan","No Plan",170,27,clrDarkGray,SCREEN_UL,IndWinId);

    NewLabel("lbh-0A","Management:",60,5,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbh-0B","Plan:",170,5,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbh-0C","Order Status:",260,5,clrGoldenrod,SCREEN_UL,IndWinId);

    NewLabel("lbh-WS1","State:",600,124,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-WS2","Flags:",600,137,clrWhite,SCREEN_UL,IndWinId);

    NewLabel("lbWaveState","No State",640,124,clrDarkGray,SCREEN_UL,IndWinId);    
    NewLabel("lbRetrace","Retrace",640,137,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbBreakout","Breakout",690,137,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbReversal","Reversal",745,137,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbBank","Bank",800,137,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbKill","Kill",835,137,clrDarkGray,SCREEN_UL,IndWinId);

    NewLabel("lbLongOrder","Waiting",260,16,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbShortOrder","Waiting",260,27,clrDarkGray,SCREEN_UL,IndWinId);
        
    NewLabel("lbh-L","Long",620,12,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-S","Short",718,12,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-C","Crest",818,12,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-T","Trough",915,12,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-D","Decay",1018,12,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-I","Interlace",1112,12,clrWhite,SCREEN_UL,IndWinId);

    NewLabel("lbh-AL","Long",425,12,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbh-AS","Short",495,12,clrWhite,SCREEN_UL,IndWinId);

    NewLabel("lbLongCount","1",625,34,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbShortCount","1",725,34,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbCrestCount","1:1",820,34,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbTroughCount","1:1",920,34,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbDecayCount","1",1025,34,clrDarkGray,SCREEN_UL,IndWinId);

    NewLabel("lbLongNetRetrace","==",620,45,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbShortNetRetrace","==",720,45,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbCrestNetRetrace","==",820,45,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbTroughNetRetrace","==",920,45,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbDecayNetRetrace","==",1020,45,clrDarkGray,SCREEN_UL,IndWinId);
    
    string colHead[5]  = {"L","S","C","T","D"};
    for (int row=0;row<5;row++)
      for (int col=0;col<5;col++)
        NewLabel("lb"+colHead[col]+(string)row,"0.0000",610+(100*col),56+(11*row),clrDarkGray,SCREEN_UL,IndWinId);
    
    for (int row=0;row<25;row++)
      NewLabel("lbInterlace"+(string)row,"0.0000",1110,30+(11*row),clrDarkGray,SCREEN_UL,IndWinId);

    for (ActionState row=Bank;row<Hold;row++)
      for (int col=OP_NO_ACTION;col<=OP_SELL;col++)
        NewLabel("lbPL"+(string)col+":"+(string)row,EnumToString(row),420+(70*col),34+(11*row),clrWhite,SCREEN_UL,IndWinId);

    DrawBox("hdSegment",590,32,495,85,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("hdWave",590,120,495,52,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("hdLong",590,9,95,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdShort",690,9,95,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdCrest",790,9,95,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdTrough",890,9,95,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdDecay",990,9,95,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdInterlace",1090,9,95,20,C'60,60,60',BORDER_RAISED,IndWinId);

    DrawBox("hdActionState",340,32,200,140,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("hdActionLong",407,9,65,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("hdActionShort",477,9,65,20,C'60,60,60',BORDER_RAISED,IndWinId);
    
    return(INIT_SUCCEEDED);
  }
