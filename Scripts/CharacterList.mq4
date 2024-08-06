//+------------------------------------------------------------------+
//|                                                 CleanObjects.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict
#property script_show_inputs

#include <stdutil.mqh>

//--- input parameters
input string   Charset;


//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
    //-- Set up the frame
    int pchar             = 0;
    
    DrawBox("frCharset",660,5,655,430,C'0,12,24',BORDER_FLAT,SCREEN_UR,0);
    for (int chr=0;chr<255;chr++)
    {
      NewLabel("lbh"+string(chr),string(chr)+":",630-((chr/32)*80),36+((int)fmod(chr,32)*12),clrDarkGray,SCREEN_UR);
      NewLabel("lbv"+string(chr),CharToStr((uchar)chr),605-((chr/32)*80),36+((int)fmod(chr,32)*12),clrDarkGray,SCREEN_UR);
      UpdateLabel("lbv"+string(chr),CharToStr((uchar)chr),clrDarkGray,8,Charset);
    }
  }
