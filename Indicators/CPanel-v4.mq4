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
#property indicator_buffers 2

#include <std_utility.mqh>

input     int inpPeriods        = 9;

int       IndWinId = -1;
string    ShortName             = "CPanel-v4";
string    cpSessionTypes[4]     = {"Daily","Asia","Europe","US"};

//--- plot indTLine
#property indicator_type1   DRAW_SECTION
#property indicator_label1  "indOpenLine"
#property indicator_color1  clrGoldenrod
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- plot indPLine
#property indicator_label2  "indCloseLine"
#property indicator_type2   DRAW_SECTION
#property indicator_color2  clrCrimson
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

  //--- Buffers
  double       indOLineBuffer[];
  double       indCLineBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
    IndWinId = ChartWindowFind(0,ShortName);
  
    //-- Session Buttons
    for (int type=0;type<4;type++)
    {
      DrawBox("bxhAI-Session"+cpSessionTypes[type],(75*type)+128,5,70,20,C'60,60,60',BORDER_RAISED,IndWinId);
      DrawBox("bxbAI-OpenInd"+cpSessionTypes[type],(75*type)+132,9,7,12,C'60,60,60',BORDER_RAISED,IndWinId);
      NewLabel("lbhAI-Session"+cpSessionTypes[type],LPad(cpSessionTypes[type]," ",4),153+(74*type),7,clrWhite,SCREEN_UL,IndWinId);
    }
        
    //-- Fractal Area
    DrawBox("bxfFA-PipMA",6,28,30,106,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("bxfFA-Fractal",6,139,30,107,clrNONE,BORDER_FLAT,IndWinId);
    DrawBox("bxfFA-Session",6,250,30,213,clrNONE,BORDER_FLAT,IndWinId);

    NewLabel("lbhFA-PipMA","PipMA",14,90,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhFA-Fractal","Fractal",14,202,clrGoldenrod,SCREEN_UL,IndWinId);
    NewLabel("lbhFA-Session","Session",14,360,clrGoldenrod,SCREEN_UL,IndWinId);

    ObjectSet("lbhFA-Fractal",OBJPROP_ANGLE,90);
    ObjectSet("lbhFA-Session",OBJPROP_ANGLE,90);
    ObjectSet("lbhFA-PipMA",OBJPROP_ANGLE,90);

    for (int row=0;row<8;row++)
    {
      DrawBox("bxfFA-Bias:"+(string)row,42,BoolToInt(row>3,38,BoolToInt(row>1,33,28))+(row*53),45,54,clrNONE,BORDER_FLAT,IndWinId);
      DrawBox("bxfFA-Info:"+(string)row,92,BoolToInt(row>3,38,BoolToInt(row>1,33,28))+(row*53),330,54,clrNONE,BORDER_FLAT,IndWinId);

      for (int col=0;col<3;col++)
      {
        DrawBox("bxfFA-"+(string)row+":"+(string)col,426+(col*90),BoolToInt(row>3,38,BoolToInt(row>1,33,28))+(row*53),85,54,clrNONE,BORDER_FLAT,IndWinId);
        NewLabel("lbvFA-H"+(string)row+":"+(string)col,"Convergent",440+(col*90),BoolToInt(row>3,38,BoolToInt(row>1,35,32))+(row*54),clrGoldenrod,SCREEN_UL,IndWinId);
        NewLabel("lbvFA-E"+(string)row+":"+(string)col,LPad("-999.9%"," ",10),440+(col*90),
                                   BoolToInt(row>3,53,BoolToInt(row>1,50,47))+(row*54),clrDarkGray,SCREEN_UL,IndWinId);
        NewLabel("lbvFA-R"+(string)row+":"+(string)col,LPad("-999.9%"," ",10),440+(col*90),
                                   BoolToInt(row>3,67,BoolToInt(row>1,64,61))+(row*54),clrDarkGray,SCREEN_UL,IndWinId);
      }

      NewLabel("lbvFA-HD0:"+(string)row,"",104,BoolToInt(row>3,38,BoolToInt(row>1,35,32))+(row*54),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvFA-HD1:"+(string)row,"",292,BoolToInt(row>3,38,BoolToInt(row>1,35,32))+(row*54),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvFA-HD2:"+(string)row,"",104,BoolToInt(row>3,64,BoolToInt(row>1,62,59))+(row*54),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvFA-ADir:"+(string)row,"",44,BoolToInt(row>3,40,BoolToInt(row>1,37,34))+(row*54),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvFA-BDir:"+(string)row,"",70,BoolToInt(row>3,40,BoolToInt(row>1,37,34))+(row*54),clrDarkGray,SCREEN_UL,IndWinId);
      NewLabel("lbvFA-Trigger:"+(string)row,"",68,BoolToInt(row>3,62,BoolToInt(row>1,59,56))+(row*54),clrDarkGray,SCREEN_UL,IndWinId);

      UpdateDirection("lbvFA-ADir:"+(string)row,DirectionUp,clrLawnGreen,28);
      UpdateDirection("lbvFA-BDir:"+(string)row,DirectionDown,clrRed,12);
      UpdateLabel("lbvFA-Trigger:"+(string)row,CharToStr(177),clrFireBrick,14,"Wingdings");

      UpdateLabel("lbvFA-HD0:"+(string)row,"Heading Line "+(string)row,clrDarkGray,14);
      UpdateLabel("lbvFA-HD1:"+(string)row,"Correction",clrDarkGray,14);
      UpdateLabel("lbvFA-HD2:"+(string)row,"Sub-Head Line "+(string)row,clrDarkGray,10);
    }

    SetIndexBuffer(0,indOLineBuffer);
    SetIndexBuffer(1,indCLineBuffer);
 
    SetIndexEmptyValue(0,0.00);
    SetIndexEmptyValue(1,0.00);
   
    ArrayInitialize(indOLineBuffer,0.00);
    ArrayInitialize(indCLineBuffer,0.00);

    return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
void LoadBuffer(double &Buffer[], string Parse)
  {
    string params[];
    
    ArrayInitialize(Buffer,0.00);
    StringSplit(Parse,";",params);
    
    Buffer[0]                    = StringToDouble(params[0]);
    Buffer[inpPeriods]           = StringToDouble(params[1]);
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
    LoadBuffer(indOLineBuffer,ObjectGetString(0,"lbv-Open",OBJPROP_TEXT));
    LoadBuffer(indCLineBuffer,ObjectGetString(0,"lbv-Close",OBJPROP_TEXT));
    
    return(rates_total);
  }
