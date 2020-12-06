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

    //-- Session Types
    enum        SessionType
                {
                  Daily,
                  Asia,
                  Europe,
                  US,
                  SessionTypes
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
  
    //-- Account Information Box
//    NewLabel("lbState","",20,130,clrNONE,SCREEN_UL,IndWinId);
    DrawBox("bxfAI",5,28,352,144,clrNONE,BORDER_FLAT,IndWinId);

    for (SessionType type=0;type<SessionTypes;type++)
    {
      DrawBox("bxhAI-Session"+EnumToString(type),(75*type)+60,5,70,20,C'60,60,60',BORDER_RAISED,IndWinId);
      DrawBox("bxbAI-OpenInd"+EnumToString(type),(75*type)+64,9,7,12,C'60,60,60',BORDER_RAISED,IndWinId);
      NewLabel("lbhAI-Session"+EnumToString(type),LPad(EnumToString(type)," ",4),85+(74*type),7,clrWhite,SCREEN_UL,IndWinId);
    }
        
    //-- App Comms
    NewLabel("lbhAC-Trade","Trading",365,7,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhAC-Option","Options",445,7,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbvAC-Trading","Trade",408,7,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvAC-Options","Options",490,7,clrDarkGray,SCREEN_UL,IndWinId);

    NewLabel("lbhAI-Bal","----- Balance/Equity -----",145,30,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-Bal","",130,42,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-Eq","",130,60,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-EqBal","",130,78,clrDarkGray,SCREEN_UL,IndWinId);

    UpdateLabel("lbvAI-Bal","$ 999999999",clrDarkGray,16,"Consolas");
    UpdateLabel("lbvAI-Eq","$-999999999",clrDarkGray,16,"Consolas");
    UpdateLabel("lbvAI-EqBal","$ 999999999",clrDarkGray,16,"Consolas");

    NewLabel("lbhAI-Eq%","Equity %",50,74,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhAI-Spread","Spread",290,74,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-Eq%","",36,48,clrNONE,SCREEN_UL,IndWinId);
    NewLabel("lbvAI-Spread","",280,48,clrNONE,SCREEN_UL,IndWinId);
    UpdateLabel("lbvAI-Eq%","-99.9%",clrDarkGray,16);
    UpdateLabel("lbvAI-Spread","999.9",clrDarkGray,16);

    //-- Order Management
    DrawBox("bxf-OM",663,28,294,144,clrNONE,BORDER_FLAT,IndWinId);
    NewLabel("lbhOM-Strategy","Strategy:",670,30,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbvOM-Strategy","Strategy",722,30,clrDarkGray,SCREEN_UL,IndWinId);

    //-- Order Details
    DrawBox("bxfOD-Long",361,28,298,144,C'0,42,0',BORDER_FLAT,IndWinId);
    DrawBox("bxfOD-Short",961,28,298,144,C'42,0,0',BORDER_FLAT,IndWinId);

    for (int row=0;row<11;row++)
      for (int col=0;col<=OP_SELL;col++)
      {
        if (row==0)
        {
          NewLabel("lbhOD-"+ActionText(col)+"F","Fibo%",374+(col*600),30,clrGoldenrod,SCREEN_UL,IndWinId);
          NewLabel("lbhOD-"+ActionText(col)+"#","#",418+(col*600),30,clrGoldenrod,SCREEN_UL,IndWinId);
          NewLabel("lbhOD-"+ActionText(col)+"L","Lots",444+(col*600),30,clrGoldenrod,SCREEN_UL,IndWinId);
          NewLabel("lbhOD-"+ActionText(col)+"V","------ Value -------",482+(col*600),30,clrGoldenrod,SCREEN_UL,IndWinId);
          NewLabel("lbhOD-"+ActionText(col)+"M","Mrg%",574+(col*600),30,clrGoldenrod,SCREEN_UL,IndWinId);
          NewLabel("lbhOD-"+ActionText(col)+"E","Eq%",625+(col*600),30,clrGoldenrod,SCREEN_UL,IndWinId);
        }

        NewLabel("lbvOD-"+ActionText(col)+(string)row+"F","-999.9",368+(col*600),44+(11*row),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOD-"+ActionText(col)+(string)row+"#","99",412+(col*600),44+(11*row),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOD-"+ActionText(col)+(string)row+"L","000.00",427+(col*600),44+(11*row),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOD-"+ActionText(col)+(string)row+"V","-0000000",482+(col*600),44+(11*row),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOD-"+ActionText(col)+(string)row+"M","00.0",552+(col*600),44+(11*row),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOD-"+ActionText(col)+(string)row+"E","999.9",613+(col*600),44+(11*row),clrDarkGray,SCREEN_UL,IndWinId);
      }

    //-- Wave Action
    DrawBox("bxfWA",1265,28,235,144,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("bxhWA-Long",1336,5,80,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("bxhWA-Short",1420,5,80,20,C'60,60,60',BORDER_RAISED,IndWinId);
    
    NewLabel("lbhWA-Long","Long",1366,7,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhWA-Short","Short",1446,7,clrWhite,SCREEN_UL,IndWinId);

    for (ActionState row=Bank;row<Hold;row++)
      for (int col=OP_NO_ACTION;col<=OP_SELL;col++)
        NewLabel("lbvWA-"+(string)col+":"+(string)row,BoolToStr(col==NoValue,EnumToString(row),"9.99999"),
          1360+BoolToInt(col==OP_NO_ACTION,-86,80*col),32+(11*row),
          BoolToInt(col==OP_NO_ACTION,clrWhite,clrDarkGray),SCREEN_UL,IndWinId);

    //-- Wave State
    DrawBox("bxfWS-Segment",1504,28,490,85,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("bxhWS-Long",1550,5,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("bxhWS-Short",1640,5,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("bxhWS-Crest",1730,5,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("bxhWS-Trough",1820,5,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    DrawBox("bxhWS-Decay",1910,5,85,20,C'60,60,60',BORDER_RAISED,IndWinId);
    
    NewLabel("lbhWS-Long","Long",1580,7,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhWS-Short","Short",1668,7,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhWS-Crest","Crest",1758,7,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhWS-Trough","Trough",1845,7,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhWS-Decay","Decay",1936,7,clrWhite,SCREEN_UL,IndWinId);

    string colHead[5]  = {"L","S","C","T","D"};
    for (int row=0;row<5;row++)
      for (int col=0;col<5;col++)
      {
        NewLabel("lbvWS-"+colHead[col]+(string)row,"0.00000",1572+(90*col),50+(11*row),clrDarkGray,SCREEN_UL,IndWinId);

        if (row==0)
        {
          NewLabel("lbvWS-#"+colHead[col]+(string)row,"0.00000",1585+(90*col),28,clrDarkGray,SCREEN_UL,IndWinId);
          UpdateLabel("lbvWS-#"+colHead[col]+(string)row,"1",clrLawnGreen,14);
        }
      }
    
    //-- Wave Flags
    DrawBox("bxfWF-Flags",1504,116,350,56,clrNONE,BORDER_FLAT,IndWinId);
    NewLabel("lbhWF-State","State:",1512,124,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhWF-Flags","Flags:",1512,137,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhWF-Action","Action:",1512,150,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhWF-Long","Long:",1740,124,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhWF-Short","Short:",1740,137,clrWhite,SCREEN_UL,IndWinId);
    
    NewLabel("lbvWF-WaveState","No State",1554,124,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvWF-Retrace","Retrace",1554,137,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvWF-Breakout","Breakout",1605,137,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvWF-Reversal","Reversal",1660,137,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvWF-Bank","Bank",1554,150,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvWF-Kill","Kill",1590,150,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvWF-Mercy","Mercy",1616,150,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvWF-Chance","Chance",1656,150,clrDarkGray,SCREEN_UL,IndWinId);
        
    NewLabel("lbvWF-LongState","No State",1780,124,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvWF-ShortState","No State",1780,137,clrDarkGray,SCREEN_UL,IndWinId);

    //-- Wave Bias
    DrawBox("bxfWB-ias",1858,116,136,56,clrNONE,BORDER_FLAT,IndWinId);
    NewLabel("lbhWB-Pivot","Pivot:",1870,154,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbvWB-IntBrkDir","^",1952,122,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvWB-IntDir","^",1976,122,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvWB-IntDev","-999.9",1870,119,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvWB-IntPivot","1.99990",1910,154,clrDarkGray,SCREEN_UL,IndWinId);

    UpdateLabel("lbvWB-IntDev","-999.9",clrLawnGreen,20);
    UpdateDirection("lbvWB-IntBrkDir",DirectionUp,clrLawnGreen,28);
    UpdateDirection("lbvWB-IntDir",DirectionDown,clrRed,12);

    //-- Second Row ----------------------------------------------------------

    //-- Order Queue    
    DrawBox("bxfOQ-Long",5,176,624,309,C'0,42,0',BORDER_FLAT,IndWinId);
    DrawBox("bxfOQ-Short",635,176,624,309,C'42,0,0',BORDER_FLAT,IndWinId);
    
    NewLabel("lbhOQ-LPlan","Long:",12,178,clrWhite,SCREEN_UL,IndWinId);
    NewLabel("lbhOQ-SPlan","Short:",642,178,clrWhite,SCREEN_UL,IndWinId);

    NewLabel("lbvOQ-LPlan","Waiting...",48,178,clrDarkGray,SCREEN_UL,IndWinId);
    NewLabel("lbvOQ-SPlan","Waiting...",680,178,clrDarkGray,SCREEN_UL,IndWinId);
    
    //-- Order Queue Fields
    for (int row=0;row<25;row++)
      for (int col=0;col<2;col++)
      {
        NewLabel("lbvOQ-"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Key","00000000",12+(col*630),204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        UpdateLabel("lbvOQ-"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Key","00000000",clrDarkGray,8,"Consolas");
        NewLabel("lbvOQ-"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Status","Pending",72+(col*630),204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Requestor","Bellwether",124+(col*630),204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Type","Market",188+(col*630),204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Price","0.00000",232+(col*630),204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Lots","0.00",287+(col*630),204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Target","0.00000",322+(col*630),204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Stop","0.00000",375+(col*630),204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Expiry","12/1/2019 11:00",424+(col*630),204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+StringSubstr(ActionText(col),0,1)+"-"+(string)row+"Memo","Yadda Yadda Yadda",517+(col*630),204+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      }

    //-- Order Queue Headers
    for (int col=0;col<2;col++)
    {
      NewLabel("lbhOQ-"+StringSubstr(ActionText(col),0,1)+"-Key","Order No.",12+(col*630),191,clrGoldenrod,SCREEN_UL,IndWinId);
      NewLabel("lbhOQ-"+StringSubstr(ActionText(col),0,1)+"-Status","Status",72+(col*630),191,clrGoldenrod,SCREEN_UL,IndWinId);
      NewLabel("lbhOQ-"+StringSubstr(ActionText(col),0,1)+"-Requestor","Requestor",124+(col*630),191,clrGoldenrod,SCREEN_UL,IndWinId);
      NewLabel("lbhOQ-"+StringSubstr(ActionText(col),0,1)+"-Type","Type",188+(col*630),191,clrGoldenrod,SCREEN_UL,IndWinId);
      NewLabel("lbhOQ-"+StringSubstr(ActionText(col),0,1)+"-Price","Price",239+(col*630),191,clrGoldenrod,SCREEN_UL,IndWinId);
      NewLabel("lbhOQ-"+StringSubstr(ActionText(col),0,1)+"-Lots","Lots",287+(col*630),191,clrGoldenrod,SCREEN_UL,IndWinId);
      NewLabel("lbhOQ-"+StringSubstr(ActionText(col),0,1)+"-Target","Target",327+(col*630),191,clrGoldenrod,SCREEN_UL,IndWinId);
      NewLabel("lbhOQ-"+StringSubstr(ActionText(col),0,1)+"-Stop","Stop",384+(col*630),191,clrGoldenrod,SCREEN_UL,IndWinId);
      NewLabel("lbhOQ-"+StringSubstr(ActionText(col),0,1)+"-Expiry","Expiration",437+(col*630),191,clrGoldenrod,SCREEN_UL,IndWinId);
      NewLabel("lbhOQ-"+StringSubstr(ActionText(col),0,1)+"-Memo","Order Comments",517+(col*630),191,clrGoldenrod,SCREEN_UL,IndWinId);
    }

    //-- Interlace Queue
    DrawBox("bxfIQ",1265,200,92,285,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("bxhIQ",1266,178,90,20,C'60,60,60',BORDER_RAISED,IndWinId);
    NewLabel("lbhIQ","Interlace",1288,181,clrWhite,SCREEN_UL,IndWinId);

    for (int row=0;row<25;row++)
      NewLabel("lbvIQ"+(string)row,"0.00000",1294,203+(11*row),clrDarkGray,SCREEN_UL,IndWinId);

    //-- Fractal Area
    string faHead[6]   = {"Origin","Trend","Term","Base","Expansion","Retrace"};
    string faVar[6]    = {"o","tr","tm","b","e","rt"};

    DrawBox("bxfFA-Fractal",1362,176,30,89,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("bxfFA-Session",1362,264,30,177,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("bxfFA-PipMA",1362,440,30,45,clrNONE,BORDER_FLAT,IndWinId);

    NewLabel("lbhFA-Fractal","Fractal",1370,236,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhFA-Session","Session",1370,360,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhFA-PipMA","PipMA",1370,477,clrGoldenrod,SCREEN_UL,IndWinId);

    ObjectSet("lbhFA-Fractal",OBJPROP_ANGLE,90);
    ObjectSet("lbhFA-Session",OBJPROP_ANGLE,90);
    ObjectSet("lbhFA-PipMA",OBJPROP_ANGLE,90);

    for (int row=0;row<7;row++)
    {
      DrawBox("bxfFA-Info:"+(string)row,1396,176+(row*44),330,45,clrNONE,BORDER_FLAT,IndWinId);

      for (int col=0;col<3;col++)
      {
        DrawBox("bxfFA-"+BoolToStr(row==0,faVar[col+3],faVar[col])+":"+(string)row,1730+(col*90),176+(row*44),85,45,clrNONE,BORDER_FLAT,IndWinId);
        NewLabel("lbhFA-"+BoolToStr(row==0,faVar[col+3],faVar[col])+":"+(string)row,LPad(BoolToStr(row==0,faHead[col+3],faHead[col])," ",10),1746+(col*90),176+(row*44),clrGoldenrod,SCREEN_UL,IndWinId);
        NewLabel("lbvFA-"+BoolToStr(row==0,faVar[col+3],faVar[col])+":"+(string)row+"e",LPad("-999.9%"," ",10),1732+(col*90),187+(row*44),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvFA-"+BoolToStr(row==0,faVar[col+3],faVar[col])+":"+(string)row+"rt",LPad("-999.9%"," ",10),1732+(col*90),201+(row*44),clrDarkGray,SCREEN_UL,IndWinId);
      }

      NewLabel("lbvFA-H1:"+(string)row,"",1402,179+(row*44),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvFA-H2:"+(string)row,"",1402,201+(row*44),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvFA-State:"+(string)row,"",1576,184+(row*44),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvFA-ADir:"+(string)row,"",1684,180+(row*44),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvFA-BDir:"+(string)row,"",1708,180+(row*44),clrDarkGray,SCREEN_UL,IndWinId);

      UpdateDirection("lbvFA-ADir:"+(string)row,DirectionUp,clrLawnGreen,28);
      UpdateDirection("lbvFA-BDir:"+(string)row,DirectionDown,clrRed,12);

      UpdateLabel("lbvFA-H1:"+(string)row,"Heading Line "+(string)row,clrDarkGray,14);
      UpdateLabel("lbvFA-H2:"+(string)row,"Sub-Head Line "+(string)row,clrDarkGray,10);
      UpdateLabel("lbvFA-State:"+(string)row,"Correction",clrDarkGray,14);
    }

    return(INIT_SUCCEEDED);
  }
