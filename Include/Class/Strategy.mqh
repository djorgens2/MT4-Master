//+------------------------------------------------------------------+
//|                                                     Strategy.mqh |
//|                                 Copyright 2017, Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict

#include <Class\PipFractal.mqh>

#define OpenStatistics    0
#define CloseStatistics   1
#define AllStatistics     2

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CStrategy
{
  private:

    enum ClassType
         {
           Fractal,
           PipFractal
         };

    enum FractalType
         {
           FractalOrigin,
           FractalMajor,
           FractalMinor
         };
         
    enum DirectionType
         {
           Down  = -1,
           None  =  0,
           Up    =  1
         };
  
    struct FibonacciRec
         {
           double          Value;
         };
         
    struct ElementRec
         {
           int             GroupId;
           ClassType       ClassId;
           FractalType     FractalId;
           DirectionType   DirectionId;
         };
  
    struct GroupRec
         {
           int             StrategyId;
           int             Count;
         };

    struct StatisticRec
         {
           int             GroupId;
           DirectionType   Direction;
           datetime        OpenTime;
           double          OpenPrice;
           double          OpenRange;
           double          MaxGain;
           double          MaxDraw;
           double          AdverseDraw;
           double          ActualDraw;
           datetime        CloseTime;
           double          ClosePrice;
         };

    ElementRec        Element[];
    GroupRec          Group[];
    FibonacciRec      Fibonacci[];

    string            CSV_Record[];
    
    CFractal         *fractal;
    CPipFractal      *pfractal;

    void              LoadFibonacci(void);
    void              LoadElements(void);
    void              LoadGroups(void);
    void              LoadData(void);

    bool              UpdateStrategy(void);

    void              UpdateStatistics(void);
    void              OpenStatistic(double MaxDraw);
    void              CloseStatistic(double MaxDraw, double AdverseDraw, double DrawPrice);
    
  public:
                      CStrategy(CFractal &Fractal, CPipFractal &PipFractal);
                     ~CStrategy();
                
    void              Update(void);
    void              Show(int Measure);
    

  protected:

    static const string  GroupName[6];

    int                  GroupDirection[6];
    int                  GroupId;
    int                  Groups;
    int                  Elements;
    int                  Degree;        //--- DoC value (degree of change)
    StatisticRec         Statistic[];
  };

const string CStrategy::GroupName[6]      = {"fo","fm","fn","pfo","pfm","pfn"};

//+------------------------------------------------------------------+
//| UpdateStrategy - Calc strategy based current fractal pattern     |
//+------------------------------------------------------------------+
bool CStrategy::UpdateStrategy(void)
  {
    int    ssGroupId    = 0;
    int    ssElementId  = Elements;
    
    if (   IsChanged(GroupDirection[0],this.fractal.Origin(Direction))
        || IsChanged(GroupDirection[1],this.fractal.Direction(Expansion))
        || IsChanged(GroupDirection[2],this.fractal.Direction(fractal.State(Major)))
        || IsChanged(GroupDirection[3],this.pfractal.Direction(Origin))
        || IsChanged(GroupDirection[4],this.pfractal.Direction(Trend))
        || IsChanged(GroupDirection[5],this.pfractal.Direction(Term))
       )
    {
      Degree            = 1;

      if (IsChanged(GroupDirection[0],this.fractal.Origin(Direction))) Degree++;
      if (IsChanged(GroupDirection[1],this.fractal.Direction(Expansion))) Degree++;
      if (IsChanged(GroupDirection[2],this.fractal.Direction(fractal.State(Major)))) Degree++;
      if (IsChanged(GroupDirection[3],this.pfractal.Direction(Origin))) Degree++;
      if (IsChanged(GroupDirection[4],this.pfractal.Direction(Trend))) Degree++;
      if (IsChanged(GroupDirection[5],this.pfractal.Direction(Term))) Degree++;
      
      for (int idx=0; idx<6; idx++)
      {
        ssElementId /= 2;
        
        if (GroupDirection[idx]==DirectionUp)
          ssGroupId += ssElementId;
      }
      
      GroupId = Element[ssGroupId].GroupId;
      Group[GroupId].Count++;
      
      return true;
    }

    return false;
  }
  
//+------------------------------------------------------------------+
//| LoadFibonacci - Loads fibonacci data from file                   |
//+------------------------------------------------------------------+
void CStrategy::LoadFibonacci(void)
  {
    //-- Load Groups
    int    arrSize        =  0;
    int    try            =  0;
    int    fHandle        = -1;
    string fRecord;

    //--- process command file
    while(fHandle<0)
    {
      fHandle=FileOpen("Fibonacci.csv",FILE_CSV|FILE_READ);
      
      if (++try==20)
      {
        Print("Error opening file for read: ",GetLastError());
        return;
      }
      
      if (fHandle>0)
        break;
    }

    while (!FileIsEnding(fHandle))
    {
      fRecord=FileReadString(fHandle);

      ArrayResize(Fibonacci,arrSize+1);
      StringSplit(fRecord,44,CSV_Record);
      
      Fibonacci[arrSize].Value  = StrToInteger(CSV_Record[0]);

      arrSize++;

    }
    
    FileClose(fHandle);
    
    Print ("Fibonacci Levels loaded: "+IntegerToString(arrSize));
  }

//+------------------------------------------------------------------+
//| LoadGroups - Loads strategy data from files                      |
//+------------------------------------------------------------------+
void CStrategy::LoadGroups(void)
  {
    //-- Load Groups
    int    try            =  0;
    int    fHandle        = -1;
    string fRecord;

    //--- process command file
    while(fHandle<0)
    {
      fHandle=FileOpen("GroupStrategy.csv",FILE_CSV|FILE_READ);
      
      if (++try==20)
      {
        Print("Error opening file for read: ",GetLastError());
        return;
      }
      
      if (fHandle>0)
        break;
    }

    Groups               = 0;
    
    while (!FileIsEnding(fHandle))
    {
      fRecord=FileReadString(fHandle);

      ArrayResize(Group,Groups+1);
      StringSplit(fRecord,44,CSV_Record);
      
      Group[Groups].StrategyId  = StrToInteger(CSV_Record[1]);
      Group[Groups].Count       = 0;

      Groups++;
    }
    
    FileClose(fHandle);
    
    Print ("Groups loaded: "+IntegerToString(Groups));
  }

//+------------------------------------------------------------------+
//| LoadElements - Loads fractal group elements from external file   |
//+------------------------------------------------------------------+
void CStrategy::LoadElements(void)
  {
    //-- Load Groups
    int    try            =  0;
    int    fHandle        = -1;
    string fRecord;

    //--- process command file
    while(fHandle<0)
    {
      fHandle=FileOpen("Group.csv",FILE_CSV|FILE_READ);
      
      if (++try==20)
      {
        Print("Error opening file for read: ",GetLastError());
        return;
      }
      
      if (fHandle>0)
        break;
    }

    Elements              = 0;
    
    while (!FileIsEnding(fHandle))
    {
      fRecord=FileReadString(fHandle);
 
      ArrayResize(Element,Elements+1);
      StringSplit(fRecord,44,CSV_Record);
      
      Element[Elements].GroupId       = StrToInteger(CSV_Record[0]);
      Element[Elements].ClassId       = (ClassType)StrToInteger(CSV_Record[1]);
      Element[Elements].FractalId     = (FractalType)StrToInteger(CSV_Record[2]);
      Element[Elements].DirectionId   = (DirectionType)StrToInteger(CSV_Record[3]);
      
      Elements++;
    }
    
    FileClose(fHandle);
    
    Print ("Elements loaded: "+IntegerToString(Elements));
  }

//+------------------------------------------------------------------+
//| LoadData - Loads Strategy data from files                        |
//+------------------------------------------------------------------+
void CStrategy::LoadData(void)
  {
    ArrayInitialize(GroupDirection,None);
    
    GroupId                = NoValue;
    
    LoadElements();
    LoadGroups();
    LoadFibonacci();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::OpenStatistic(double MaxDraw)
  {
    static int osStatistic  = 0;

    if (osStatistic>0)
      Statistic[osStatistic-1].MaxDraw    = MaxDraw;
      
    ArrayResize(Statistic,osStatistic+1);
    
    Statistic[osStatistic].ClosePrice     = 0.00;
    Statistic[osStatistic].CloseTime      = 0;
    Statistic[osStatistic].Direction      = (DirectionType)pfractal.Direction(Term);
    Statistic[osStatistic].GroupId        = GroupId;
    Statistic[osStatistic].MaxDraw        = 0.00;
    Statistic[osStatistic].AdverseDraw    = 0.00;
    Statistic[osStatistic].ActualDraw     = 0.00;
    Statistic[osStatistic].OpenPrice      = Close[0];
    Statistic[osStatistic].OpenRange      = Pip(pfractal.Range(Size));
    Statistic[osStatistic].OpenTime       = TimeCurrent();
    
    osStatistic++;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::CloseStatistic(double MaxDraw, double AdverseDraw, double DrawPrice)
  {
    int csIdxNow      = ArraySize(Statistic)-1;
    
    for (int idx=0;idx<ArraySize(Statistic);idx++)
      if (Statistic[idx].CloseTime == 0)
        Statistic[idx].CloseTime       = TimeCurrent();
    
    Statistic[csIdxNow].MaxDraw        = MaxDraw;
    Statistic[csIdxNow].AdverseDraw    = AdverseDraw;
    Statistic[csIdxNow].ActualDraw     = Pip(fabs(Statistic[csIdxNow].OpenPrice-DrawPrice));
    
    Print(Statistic[csIdxNow].GroupId+" "
         +Statistic[csIdxNow].Direction+" "
         +Statistic[csIdxNow].OpenTime+" "
         +Statistic[csIdxNow].OpenPrice+" "
         +Statistic[csIdxNow].OpenRange+" "
         +Statistic[csIdxNow].MaxGain+" "
         +Statistic[csIdxNow].MaxDraw+" "
         +Statistic[csIdxNow].AdverseDraw+" "
         +Statistic[csIdxNow].ActualDraw+" "
         +DrawPrice+" ");    
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::UpdateStatistics(void)
  {
    static int    usGroupId        = NoValue;
    static int    usDirection      = None;
    static double usMaxDraw        = 0.00;
    static double usAdvDraw        = 0.00;
    static double usCurrent        = 0.00;
    static double usTermPrice      = 0.00;
    static double usDrawPrice      = 0.00;
    static double usBndryPrice     = 0.00;
    static double usAdvBndryPrice  = 0.00;
    
    if (pfractal.HistoryLoaded())
    {
      if (pfractal.Event(NewBoundary))
      {        
        if (IsChanged(usDirection,pfractal.Direction(Term)))
        {
          CloseStatistic(usMaxDraw,usAdvDraw,usDrawPrice);
          usAdvBndryPrice          = 0.00;
        }
        else
        {
          for (int idx=0;idx<ArraySize(Statistic);idx++)
            if (Statistic[idx].CloseTime == 0)
              Statistic[idx].MaxGain = fmax(Statistic[idx].MaxGain,Pip(Close[0]-Statistic[idx].OpenPrice)*Statistic[idx].Direction); 
          
          if ((pfractal.Event(NewHigh)&&pfractal.Direction(Term)==DirectionUp)||
              (pfractal.Event(NewLow)&&pfractal.Direction(Term)==DirectionDown))
          {
            if (IsHigher(usCurrent,usMaxDraw))
              usCurrent        = 0.00;
              
            if (!IsEqual(usAdvBndryPrice,0.00))
              usAdvDraw        = fabs(usTermPrice-usAdvBndryPrice);

            usBndryPrice       = Close[0];
          }
          else
            usAdvBndryPrice    = Close[0];
        }
      }
      else
        usCurrent              = fmax(usCurrent,Pip(usBndryPrice-Close[0])*usDirection);
      
      if (IsChanged(usGroupId,GroupId))
      {
        OpenStatistic(usMaxDraw);
      
        usTermPrice            = Close[0];
        usDrawPrice            = Close[0];
      
        usMaxDraw              = 0.00;
        usCurrent              = 0.00;
      }
      
      if (pfractal.Direction(Term)==DirectionUp)
        usDrawPrice            = fmin(usDrawPrice,Close[0]);

      if (pfractal.Direction(Term)==DirectionDown)
        usDrawPrice            = fmax(usDrawPrice,Close[0]);

if (!IsEqual(usTermPrice,0.00))
{
  UpdateLine("usTermPrice",usTermPrice,STYLE_SOLID,clrLawnGreen);
  UpdateLine("usActPrice",usDrawPrice,STYLE_SOLID,clrYellow);
  UpdateLine("usBndryPivot",usBndryPrice,STYLE_SOLID,clrDodgerBlue);
  UpdateLine("usAdvBndryPivot",usAdvBndryPrice,STYLE_SOLID,clrRed);

  Comment(  "Group: "+IntegerToString(usGroupId)+" "+DirText(usDirection)+"\n"
           +"Term Price: "+DoubleToStr(usTermPrice,Digits)+" ("+DoubleToStr(Pip(usTermPrice-Close[0])*usDirection,1)+")\n"
           +"Max Draw: "+DoubleToStr(usMaxDraw,1)+"\n"
           +"Cur Draw: "+DoubleToStr(usCurrent,1)+"\n"
         );
}
    }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStrategy::CStrategy(CFractal &Fractal, CPipFractal &PipFractal)
  {
    this.fractal  = GetPointer(Fractal);
    this.pfractal = GetPointer(PipFractal);
    
    NewLine("usTermPrice");
    NewLine("usBndryPivot");
    NewLine("usAdvBndryPivot");
    NewLine("usActPrice");

    LoadData();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStrategy::~CStrategy()
  {
    Print("Strategy summary");
    for (int idx=0;idx<Groups;idx++)
      Print("Group: "+IntegerToString(idx)+" Count: "+IntegerToString(Group[idx].Count));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStrategy::Show(int Measure)
  {
    string uMessage = "";
    bool   uShow    = false;
    
    uMessage     = "New Fractal Group\n";
    uMessage    += "  Group ID: "+IntegerToString(GroupId)+"\n"
                  +"  Degree (DoC): "+IntegerToString(Degree)+"\n"+"\n";
    uMessage    += "Active Statistics\n\n";
    uMessage    += "Grp  Range   Price        Gain    Draw    Adv     Act\n";

    for (int idx=0;idx<ArraySize(Statistic);idx++)
    {
      uShow        = false;

      switch (Measure)
      {
        case OpenStatistics:  if (Statistic[idx].CloseTime == 0)
                                uShow     = true;
                              break;
                              
        case CloseStatistics: if (Statistic[idx].CloseTime > 0)
                                uShow     = true;
                              break;
                              
        case AllStatistics:   uShow     = true;
      }
      
      if (uShow)       
      {
        uMessage += LPad(IntegerToString(Statistic[idx].GroupId)+"-"+StringSubstr(DirText(Statistic[idx].Direction),0,1)," ",1)
                   +LPad(DoubleToString(Statistic[idx].OpenRange,1)," ",8)
                   +LPad(DoubleToString(Statistic[idx].OpenPrice,Digits)," ",10)
                   +LPad(DoubleToString(Statistic[idx].MaxGain,1)," ",9)
                   +LPad(DoubleToString(Statistic[idx].MaxDraw,1)," ",9)
                   +LPad(DoubleToString(Statistic[idx].AdverseDraw,1)," ",9)
                   +LPad(DoubleToString(Statistic[idx].ActualDraw,1)," ",9)+"\n";
      }
    }

    Comment(uMessage);    
  }
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStrategy::Update(void)
  {
    string uMessage = "";
    
    if (UpdateStrategy())
    {
      uMessage     = "New Fractal Group\n";
      uMessage    += "  Group ID: "+IntegerToString(GroupId)+"\n"
                    +"  Degree (DoC): "+IntegerToString(Degree)+"\n"+"\n";
//      uMessage    += "Active Statistics\n";
//      uMessage    += " Grp Range Price   Gain   Draw   Adv   Act\n";
    }
    
    UpdateStatistics();
    
    if (uMessage != "")
    {
//      for (int idx=0;idx<ArraySize(Statistic);idx++)
//        if (Statistic[idx].CloseTime == 0)
//        uMessage +="  "+IntegerToString(Statistic[idx].GroupId)+"   "
//                   +DoubleToString(Statistic[idx].OpenRange,1)+"   "
//                   +DoubleToString(Statistic[idx].OpenPrice,Digits)+"     "
//                   +DoubleToString(Statistic[idx].MaxGain,1)+"     "
//                   +DoubleToString(Statistic[idx].MaxDraw,1)+"     "
//                   +DoubleToString(Statistic[idx].AdverseDraw,1)+"     "
//                   +DoubleToString(Statistic[idx].ActualDraw,1)+"\n";

        //printf("  %i   %3.1f   %3.5f    %4.1f    %4.1f    %4.1f    %4.1f\n",
        //           Statistic[idx].GroupId,
        //           Statistic[idx].OpenRange,
        //           Statistic[idx].OpenPrice,
        //           Statistic[idx].MaxGain,
        //           Statistic[idx].MaxDraw,
        //           Statistic[idx].AdverseDraw,
        //           Statistic[idx].ActualDraw);

      if (this.pfractal.HistoryLoaded())
        Pause(uMessage,"PatternChange()");    
    }
  }
