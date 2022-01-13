//+------------------------------------------------------------------+
//|                                                    CPanel-v3.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "2.00"
#property strict
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   8

#include <Class\PipMA.mqh>
#include <std_utility.mqh>

int       IndWinId = -1;
string    ShortName             = "CPanel-v3";
string    cpSessionTypes[4]     = {"Daily","Asia","Europe","US"};

//--- plot plOpen
#property indicator_label1  "plOpen"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrForestGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot plClose
#property indicator_label2  "plClose"
#property indicator_type2   DRAW_SECTION
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- plot plSlope
#property indicator_label3  "plHigh"
#property indicator_type3   DRAW_SECTION
#property indicator_color3  clrSilver
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- plot plMA
#property indicator_label4  "plLow"
#property indicator_type4   DRAW_SECTION
#property indicator_color4  clrGoldenrod
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- plot plOpen
#property indicator_label5  "plOpenSMA"
#property indicator_type5   DRAW_SECTION
#property indicator_color5  clrForestGreen
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

//--- plot plClose
#property indicator_label6  "plCloseSMA"
#property indicator_type6   DRAW_SECTION
#property indicator_color6  clrFireBrick
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//--- plot plSlope
#property indicator_label7  "plHighSMA"
#property indicator_type7   DRAW_SECTION
#property indicator_color7  clrSilver
#property indicator_style7  STYLE_DOT
#property indicator_width7  1

//--- plot plMA
#property indicator_label8  "plLowSMA"
#property indicator_type8   DRAW_SECTION
#property indicator_color8  clrGoldenrod
#property indicator_style8  STYLE_DOT
#property indicator_width8  1

//--- input parameters
input int      inpRetention           =  90;   // Retention
input int      inpRegr                =   9;   // Regression Periods
input int      inpSMA                 =   3;   // SMA Smoothing
input double   inpAgg                 = 2.5;   // Tick Aggregation

//--- indicator buffers
double         plOpenBuffer[];
double         plCloseBuffer[];
double         plHighBuffer[];
double         plLowBuffer[];
double         plOpenSMABuffer[];
double         plCloseSMABuffer[];
double         plHighSMABuffer[];
double         plLowSMABuffer[];

CPipMA        *pma           = new CPipMA(inpRetention,inpRegr,inpSMA,inpAgg);

//+------------------------------------------------------------------+
//| RefreshScreen - Repaint indicator display                        |
//+------------------------------------------------------------------+
void RefreshScreen(void)
  {
    UpdateLabel("Clock",TimeToStr(Time[0]),clrDodgerBlue,16);
    UpdateLabel("Price",Symbol()+"  "+DoubleToStr(Close[0],Digits),Color(Close[0]-Open[0]),16);
  }

//+------------------------------------------------------------------+
//| LoadBuffer - Insert Regression buffer value                      |
//+------------------------------------------------------------------+
void LoadBuffer(double &Buffer[], double Price)
  {
    double copy[];
    
    ArrayCopy(copy,Buffer,1,0,inpRetention-1);
    ArrayInitialize(Buffer,0.00);
    ArrayCopy(Buffer,copy,0,0,inpRetention);
    
    Buffer[0]          = Price;
  }

//+------------------------------------------------------------------+
//| UpdatePipMA - refreshes indicator data                           |
//+------------------------------------------------------------------+
void UpdatePipMA(void)
  {
    pma.Update();
    
    if (pma[NewTick])
      if (pma[0].Segment>inpSMA)
      {
        LoadBuffer(plOpenBuffer,pma.Master().History[0].Open);
        LoadBuffer(plCloseBuffer,pma.Master().History[1].Close);
        LoadBuffer(plHighBuffer,pma.Master().History[1].High);
        LoadBuffer(plLowBuffer,pma.Master().History[1].Low);
        LoadBuffer(plOpenSMABuffer,pma.Master().SMA.Open);
        LoadBuffer(plCloseSMABuffer,pma.Master().SMA.Close);
        LoadBuffer(plHighSMABuffer,pma.Master().SMA.High);
        LoadBuffer(plLowSMABuffer,pma.Master().SMA.Low);
      }
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    IndWinId = ChartWindowFind(0,ShortName);
  
    //-- Account Information Box
    DrawBox("bxfAI",5,28,352,144,C'5,10,25',BORDER_FLAT,IndWinId);

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
    DrawBox("bxfOC-Long",5,174,352,144,C'0,42,0',BORDER_FLAT,IndWinId);
    DrawBox("bxfOC-Short",5,320,352,144,C'42,0,0',BORDER_FLAT,IndWinId);
    
    for (int action=OP_BUY;action<=OP_SELL;action++)
    {
      NewLabel("lbhOC-"+ActionText(action)+"-Trading","Trading",10,(146*(action+1))+30,clrWhite,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-Equity","--------  Equity  ---------",36,(146*(action+1))+44,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-EQTarget","Target",22,(146*(action+1))+70,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-EQMin","Min",78,(146*(action+1))+70,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-EQPrice","T/P",130,(146*(action+1))+70,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-Risk","---------  Risk  ----------",204,(146*(action+1))+44,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-RKBalance","Target",190,(146*(action+1))+70,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-RKMaxMargin","Margin",240,(146*(action+1))+70,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-RKPrice","S/L",296,(146*(action+1))+70,clrGold,SCREEN_UL,IndWinId);
      
      NewLabel("lbhOC-"+ActionText(action)+"-EQBase","P/L",24,(146*(action+1))+100,clrGold,SCREEN_UL,IndWinId);
      UpdateLabel("lbhOC-"+ActionText(action)+"-EQBase","P/L",clrWhite,10);
      NewLabel("lbhOC-"+ActionText(action)+"-DCA","DCA",194,(146*(action+1))+100,clrGold,SCREEN_UL,IndWinId);
      UpdateLabel("lbhOC-"+ActionText(action)+"-DCA","DCA",clrWhite,10);
      
      NewLabel("lbhOC-"+ActionText(action)+"-Lots","------- Lot Sizing --------",36,(146*(action+1))+118,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-LotSize","Size",28,(146*(action+1))+144,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-LotMin","Min",78,(146*(action+1))+144,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-LotMax","Max",120,(146*(action+1))+144,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-Zone","---------  Zone  ----------",204,(146*(action+1))+118,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-ZStep","Step",194,(146*(action+1))+144,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-ZMaxMargin","Margin",240,(146*(action+1))+144,clrGold,SCREEN_UL,IndWinId);
      NewLabel("lbhOC-"+ActionText(action)+"-ZZoneNow","Zone",294,(146*(action+1))+144,clrGold,SCREEN_UL,IndWinId);

      NewLabel("lbvOC-"+ActionText(action)+"-Enabled","Enabled",50,(146*(action+1))+30,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-EqTarget","999.9%",20,(146*(action+1))+56,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-EqMin","99.9%",70,(146*(action+1))+56,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-Target","9.99999",116,(146*(action+1))+56,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-DfltTarget","Default 9.99999 50p",36,(146*(action+1))+82,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MaxRisk","99.9%",190,(146*(action+1))+56,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MaxMargin","99.9%",238,(146*(action+1))+56,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-Stop","9.99999",282,(146*(action+1))+56,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-DfltStop","Default 9.99999 50p",206,(146*(action+1))+82,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-EQBase","999999999 (999%)",46,(146*(action+1))+100,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-DCA","9.99999 (9.9%)",224,(146*(action+1))+100,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-LotSize","99.99",16,(146*(action+1))+130,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MinLotSize","99.99",68,(146*(action+1))+130,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MaxLotSize","999.99",110,(146*(action+1))+130,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-DfltLotSize","Default 99.99",60,(146*(action+1))+155,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-ZoneStep","99.9",194,(146*(action+1))+130,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MaxZoneMargin","99.9%",236,(146*(action+1))+130,clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvOC-"+ActionText(action)+"-MaxZoneNow","-99",294,(146*(action+1))+130,clrDarkGray,SCREEN_UL,IndWinId);
    }

    //-- Zone Margin frames
    DrawBox("bxfOZ-Long",360,174,960,144,C'0,42,0',BORDER_FLAT,IndWinId);
    DrawBox("bxfOZ-Short",360,320,960,144,C'42,0,0',BORDER_FLAT,IndWinId);

    //-- Zone Metrics
    for (int row=0;row<11;row++)
      for (int col=0;col<=OP_SELL;col++)
      {
        if (row==0)
        {
          NewLabel("lbhOZ-"+ActionText(col)+"Z","Zone",370,176+(col*146),clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"#","#",404,176+(col*146),clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"L","Lots",436,176+(col*146),clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"V","-------- Value ---------",482,176+(col*146),clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"M","Mrg%",592,176+(col*146),clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbhOZ-"+ActionText(col)+"E","Eq%",634,176+(col*146),clrGold,SCREEN_UL,IndWinId);

          NewLabel("lbhOQ-"+ActionText(col)+"-Ticket","Ticket",674,176+(col*146),clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-State","State",760,176+(col*146),clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Price","Open",840,176+(col*146),clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Lots","Lots",906,176+(col*146),clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Target","Target",966,176+(col*146),clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Stop","Stop",1026,176+(col*146),clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Profit","Profit",1108,176+(col*146),clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Swap","Swap",1188,176+(col*146),clrGold,SCREEN_UL,IndWinId);
          NewLabel("lbvOQ-"+ActionText(col)+"-Net","Net",1270,176+(col*146),clrGold,SCREEN_UL,IndWinId);
        }

        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"Z","",370,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"#","",400,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"L","",424,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"V","",482,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"M","",592,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOZ-"+ActionText(col)+(string)row+"E","",630,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);

        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-Ticket","",674,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-State","",760,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-Price","",840,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-Lots","",906,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-TP","",966,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-SL","",1026,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-Profit","",1082,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-Swap","",1166,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvOQ-"+ActionText(col)+(string)row+"-Net","",1236,(180+(col*146))+(11*(row+1)),clrDarkGray,SCREEN_UL,IndWinId);

        UpdateLabel("lbvOZ-"+ActionText(col)+(string)row+"Z","-99",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOZ-"+ActionText(col)+(string)row+"#","99",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOZ-"+ActionText(col)+(string)row+"L","0000.00",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOZ-"+ActionText(col)+(string)row+"V",dollar(-9999999999,14,false),clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOZ-"+ActionText(col)+(string)row+"M","00.0",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOZ-"+ActionText(col)+(string)row+"E","999.9",clrDarkGray,9,"Consolas");
        
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-Ticket",IntegerToString(99999999,10,'-'),clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-State","Hold",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-Price","9.99999",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-Lots","9999.99",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-TP","9.99999",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-SL","9.99999",clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-Profit",dollar(-9999999,11,false),clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-Swap",dollar(-9999999,8,false),clrDarkGray,9,"Consolas");
        UpdateLabel("lbvOQ-"+ActionText(col)+(string)row+"-Net",dollar(-9999999,11,false),clrDarkGray,9,"Consolas");
      }

    //-- Request Queue    
    DrawBox("bxfRQ-Request",360,28,960,144,C'0,12,24',BORDER_FLAT,IndWinId);

    //-- Request Queue Headers
    NewLabel("lbhRQ-"+"-Key","Request #",366,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhRQ-"+"-Status","Status",426,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhRQ-"+"-Requestor","Requestor",484,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhRQ-"+"-Type","Type",569,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhRQ-"+"-Price","Price",620,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhRQ-"+"-Lots","Lots",668,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhRQ-"+"-Target","Target",716,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhRQ-"+"-Stop","Stop",764,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhRQ-"+"-Expiry","Expiration",810,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhRQ-"+"-Limit","Limit",906,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhRQ-"+"-Cancel","Cancel",954,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhRQ-"+"-Resubmit","Resubmit",1002,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhRQ-"+"-Step","Step",1058,30,clrGold,SCREEN_UL,IndWinId);
    NewLabel("lbhRQ-"+"-Memo","Order Comments",1092,30,clrGold,SCREEN_UL,IndWinId);

    //-- Request Queue Fields
    for (int row=0;row<11;row++)
    {
      NewLabel("lbvRQ-"+(string)row+"-Key","00000000",366,44+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      UpdateLabel("lbvRQ-"+(string)row+"-Key","00000000",clrDarkGray,8,"Consolas");
      NewLabel("lbvRQ-"+(string)row+"-Status","Pending",426,44+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvRQ-"+(string)row+"-Requestor","Bellwether",484,44+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvRQ-"+(string)row+"-Type","Sell Limit",569,44+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvRQ-"+(string)row+"-Price","0.00000",620,44+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvRQ-"+(string)row+"-Lots","0000.00",668,44+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvRQ-"+(string)row+"-Target","0.00000",716,44+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvRQ-"+(string)row+"-Stop","0.00000",764,44+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvRQ-"+(string)row+"-Expiry","12/1/2019 11:00",810,44+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvRQ-"+(string)row+"-Limit","0.00000",906,44+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvRQ-"+(string)row+"-Cancel","0.00000",954,44+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvRQ-"+(string)row+"-Resubmit","Sell Limit",1002,44+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvRQ-"+(string)row+"-Step","99.9",1058,44+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvRQ-"+(string)row+"-Memo","1234567890123456789012345678901234567",1092,44+(row*11),clrDarkGray,SCREEN_UL,IndWinId);
    }

    NewLabel("Clock","",10,5,clrDarkGray,SCREEN_LR,IndWinId);
    NewLabel("Price","",10,30,clrDarkGray,SCREEN_LR,IndWinId);

    //--- indicator buffers mapping
    SetIndexBuffer(0,plOpenBuffer);
    SetIndexBuffer(1,plCloseBuffer);
    SetIndexBuffer(2,plHighBuffer);
    SetIndexBuffer(3,plLowBuffer);
    SetIndexBuffer(4,plOpenSMABuffer);
    SetIndexBuffer(5,plCloseSMABuffer);
    SetIndexBuffer(6,plHighSMABuffer);
    SetIndexBuffer(7,plLowSMABuffer);
    
    SetIndexEmptyValue(0,0.00);
    SetIndexEmptyValue(1,0.00);
    SetIndexEmptyValue(2,0.00);
    SetIndexEmptyValue(3,0.00);
    SetIndexEmptyValue(4,0.00);
    SetIndexEmptyValue(5,0.00);
    SetIndexEmptyValue(6,0.00);
    SetIndexEmptyValue(7,0.00);
  
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
    UpdatePipMA();
    RefreshScreen();

    return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    delete pma;
  }