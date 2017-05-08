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
         
    enum MeasureType
         {
           MaxGain,
           ActualGain,
           MaxDraw,
           ActualDraw
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
           int             Direction;
         };
  
    struct GroupRec
         {
           int             StrategyId;   //--- Assigned strategy id
           int             Degree;       //--- DoC value (degree of change)
           int             Count;        //--- Count of occurrences
         };

    struct StatisticRec
         {
           int             GroupId;
           int             Direction;
           datetime        TimeOpen;
           double          RangeOpen;
           double          PriceOpen;
           double          PriceHigh;
           double          PriceLow;
           double          PriceClose;
           bool            AdverseDraw;
           datetime        TimeClose;
         };

    ElementRec             Element[];
    GroupRec               Group[];
    FibonacciRec           Fibonacci[];

    string                 CSV_Record[];
    
    CFractal              *fractal;
    CPipFractal           *pfractal;

    void                   LoadFibonacci(void);
    void                   LoadElements(void);
    void                   LoadGroups(void);
    void                   LoadData(void);

    void                   UpdateStatistics(void);

    void                   InitCurrent(void);
    void                   OpenRunning(void);
    void                   CloseRunning(void);
    
    string                 FormatData(StatisticRec &Data, string Format="PAD");
    double                 Measure(StatisticRec &Data, int Measure);


  public:
                           CStrategy(CFractal &Fractal, CPipFractal &PipFractal);
                          ~CStrategy();
                
    void                   Update(void);
    void                   Show(void);

  protected:

    StatisticRec           Running[];    //--- running statistics
    StatisticRec           History[];    //--- closed statistics
    StatisticRec           Current;      //--- most recent running statistic

    int                    GroupId(void);
    int                    Groups;

    static const string    ElementName[6];
    int                    ElementDirection[6];
    int                    Elements;
  };

const string CStrategy::ElementName[6] = {"fo","fm","fn","pfo","pfm","pfn"};


//+------------------------------------------------------------------+
//| GroupId - Returns the current GroupId of the fractal pattern     |
//+------------------------------------------------------------------+
int CStrategy::GroupId(void)
  {
    static int  ssGroupId    = 0;
    int         ssDegree     = 0;
    int         ssElementId  = Elements;
    
    if (IsChanged(ElementDirection[0],fractal.Origin(Direction)))
      ssDegree++;
    if (IsChanged(ElementDirection[1],fractal.Direction(Expansion)))
      ssDegree++;
    if (IsChanged(ElementDirection[2],fractal.Direction(fractal.State(Major))))
      ssDegree++;
    if (IsChanged(ElementDirection[3],pfractal.Direction(Origin)))
      ssDegree++;
    if (IsChanged(ElementDirection[4],pfractal.Direction(Trend)))
      ssDegree++;
    if (IsChanged(ElementDirection[5],pfractal.Direction(Term)))
      ssDegree++;
      
    if (ssDegree>0)
    {
      ssGroupId              = 0;
      
      for (int idx=0; idx<6; idx++)
      {
        ssElementId /= 2;
        
        if (ElementDirection[idx]==DirectionUp)
          ssGroupId += ssElementId;
      }
      
      Group[Element[ssGroupId].GroupId].Degree  = ssDegree;
      Group[Element[ssGroupId].GroupId].Count++;
    }

    return Element[ssGroupId].GroupId;
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
      Group[Groups].Degree      = 0;
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
      Element[Elements].Direction     = StrToInteger(CSV_Record[3]);
      
      Elements++;
    }
    
    FileClose(fHandle);
    
    Print ("Elements loaded: "+IntegerToString(Elements));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::InitCurrent(void)
  {
    Current.GroupId        = this.GroupId();
    Current.Direction      = pfractal.Direction(Term);
    Current.TimeOpen       = TimeCurrent();
    Current.RangeOpen      = Pip(pfractal.Range(Size));
    Current.PriceOpen      = Close[0];
    Current.PriceHigh      = Close[0];
    Current.PriceLow       = Close[0];
    Current.PriceClose     = Close[0];
    Current.AdverseDraw    = false;
    Current.TimeClose      = 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::OpenRunning(void)
  {
    int osSize = ArraySize(Running);
    
    InitCurrent();
    
    ArrayResize(Running,osSize+1);
    
    Running[osSize]     = Current;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::CloseRunning(void)
  {
    if (ArraySize(Running)>0)
    {
      for (int idx=0;idx<ArraySize(Running);idx++)
      {
        Running[idx].PriceClose        = Close[0];
        Running[idx].TimeClose         = TimeCurrent();
        
        if (Running[idx].AdverseDraw)
          if (Running[idx].Direction!=pfractal.Direction(Term))
            Running[idx].AdverseDraw   = false;
      }
        
      ArrayResize(History,ArraySize(History)+ArraySize(Running));
      ArrayCopy(History,Running,ArraySize(History)-ArraySize(Running),0,WHOLE_ARRAY);
    }
    
    ArrayResize(Running,0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::UpdateStatistics(void)
  {
    int usRunIdx;
    
    if (pfractal.HistoryLoaded())
    {
      if (IsChanged(Current.GroupId,this.GroupId()))
      {
        if (IsChanged(Current.Direction,pfractal.Direction(Term)))
          CloseRunning();

        OpenRunning();
      }

      Current.PriceHigh                  = fmax(Current.PriceHigh,Close[0]);
      Current.PriceLow                   = fmin(Current.PriceLow,Close[0]);
          
      if (pfractal.Event(NewBoundary))
      {
        if ((pfractal.Event(NewHigh)&&Current.Direction==DirectionDown)||
            (pfractal.Event(NewLow)&&Current.Direction==DirectionUp))
          Current.AdverseDraw            = true;
          
        for (usRunIdx=0;usRunIdx<ArraySize(Running);usRunIdx++)
        {
          if (Running[usRunIdx].Direction==DirectionUp)
            Running[usRunIdx].PriceHigh  = Current.PriceHigh;

          if (Running[usRunIdx].Direction==DirectionDown)
            Running[usRunIdx].PriceLow   = Current.PriceLow;
        }

        usRunIdx--;
        
        if (Running[usRunIdx].Direction==DirectionUp)
          Running[usRunIdx].PriceLow     = Current.PriceLow;

        if (Running[usRunIdx].Direction==DirectionDown)
          Running[usRunIdx].PriceHigh    = Current.PriceHigh;

        Running[usRunIdx].AdverseDraw    = Current.AdverseDraw;
      }

{
  UpdateLine("Open",Current.PriceOpen,STYLE_SOLID,clrYellow);
  UpdateLine("High",Current.PriceHigh,STYLE_SOLID,clrLawnGreen);
  UpdateLine("Low",Current.PriceLow,STYLE_SOLID,clrRed);

  Comment(  "Group: "+IntegerToString(Current.GroupId)+" "+DirText(Current.Direction)+"\n"
           +"Open: "+DoubleToStr(Current.PriceOpen,Digits)+" ("+DoubleToStr(Pip(Current.PriceOpen-Close[0])*Current.Direction,1)+")\n"
           +"High: "+DoubleToStr(Current.PriceHigh,Digits)+"\n"
           +"Low: "+DoubleToStr(Current.PriceLow,Digits)+"\n"
           +BoolToStr(Current.AdverseDraw,"Yes","No")
         );
}
    }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CStrategy::FormatData(StatisticRec &Data, string Format="PAD")
  {
    if (Format == "PAD")
      return( LPad(IntegerToString(Data.GroupId)+"-"
             +StringSubstr(DirText(Data.Direction),0,1)," ",1)
             +LPad(DoubleToString(Data.RangeOpen,1)," ",8)
             +LPad(DoubleToString(Data.PriceOpen,Digits)," ",10)
             +LPad(DoubleToString(Measure(Data,MaxGain),1)," ",9)
             +LPad(DoubleToString(Measure(Data,MaxDraw),1)," ",9)
             +LPad(BoolToStr(Data.AdverseDraw,"Yes","No ")," ",9)
             +LPad(DoubleToString(Measure(Data,ActualDraw),1)," ",9)+"\n");

    if (Format == "CSV")
      return( IntegerToString(Data.GroupId)+"|"
             +DirText(Data.Direction)+"|"
             +TimeToStr(Data.TimeOpen)+"|"
             +DoubleToString(Data.RangeOpen,1)+"|"
             +DoubleToString(Data.PriceOpen,Digits)+"|"
             +DoubleToString(Data.PriceHigh,Digits)+"|"
             +DoubleToString(Data.PriceLow,Digits)+"|"
             +DoubleToString(Data.PriceClose,Digits)+"|"             
             +DoubleToString(Measure(Data,MaxGain),1)+"|"
             +DoubleToString(Measure(Data,MaxDraw),1)+"|"
             +TimeToStr(Data.TimeClose)+"|"             
             +BoolToStr(Data.AdverseDraw,"Yes","No "));
             
    return( " " );
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStrategy::CStrategy(CFractal &Fractal, CPipFractal &PipFractal)
  {
    this.fractal  = GetPointer(Fractal);
    this.pfractal = GetPointer(PipFractal);
    
    Current.GroupId   = NoValue;
    Current.Direction = DirectionNone;

    ArrayInitialize(ElementDirection,DirectionNone);
    
    LoadElements();
    LoadGroups();
    LoadFibonacci();

    NewLine("Open");
    NewLine("High");
    NewLine("Low");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStrategy::~CStrategy()
  {
    Print("Strategy summary");
    for (int idx=0;idx<Groups;idx++)
      Print("Group: "+IntegerToString(idx)
           +" Count: "+IntegerToString(Group[idx].Count)
           +" Degree: "+IntegerToString(Group[idx].Degree));

    Print("*----- History ------*");
    Print("Grp|Dir|tOpen|Range|Open|High|Low|Close|Gain|Draw|tClose|Adv");

    for (int idx=0;idx<ArraySize(History);idx++)
      Print(FormatData(History[idx],"CSV"));
      
    Print("*----- Running ------*");
    Print("Grp|Dir|tOpen|Range|Open|High|Low|Close|Gain|Draw|tClose|Adv");

    for (int idx=0;idx<ArraySize(Running);idx++)
      Print(FormatData(Running[idx],"CSV"));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CStrategy::Measure(StatisticRec &Data, int Measure)
  {    
    switch (Measure)
    {
      case MaxGain:     if (Data.Direction==DirectionUp)
                          return(Pip(Data.PriceHigh-Data.PriceOpen));
                        if (Data.Direction==DirectionDown)
                          return(Pip(Data.PriceOpen-Data.PriceLow));
                        break;

      case ActualGain:  if (Data.TimeClose>0)
                          return(Measure(Data,MaxGain));
                        if (Data.Direction==DirectionUp)
                          return(fmax(Pip(Close[0]-Data.PriceOpen),0.00));
                        if (Data.Direction==DirectionDown)
                          return(fmax(Pip(Data.PriceOpen-Close[0]),0.00));
                        break;

      case MaxDraw:     if (Data.Direction==DirectionUp)
                          return(Pip(Data.PriceOpen-Data.PriceLow));
                        if (Data.Direction==DirectionDown)
                          return(Pip(Data.PriceHigh-Data.PriceOpen));
                        break;

      case ActualDraw:  if (Data.TimeClose>0)
                          return(Measure(Data,MaxDraw));
                        if (Data.Direction==DirectionUp)
                          return(fmax(Pip(Data.PriceOpen-Close[0]),0.00));
                        if (Data.Direction==DirectionDown)
                          return(fmax(Pip(Close[0]-Data.PriceOpen),0.00));
                        break;
                        
      default:          return(0);
    }
    
    return (NoValue);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::Show(void)
  {
    string uMessage = "";
    
    if (Current.GroupId>NoValue)
    {
      uMessage     = "New Fractal Group\n";
      uMessage    += "  Group ID: "+IntegerToString(Current.GroupId)+"\n"
                    +"  Occurs: "+IntegerToString(Group[Current.GroupId].Count)+"\n"
                    +"  Degree (DoC): "+IntegerToString(Group[Current.GroupId].Degree)+"\n\n";

      uMessage    += "*----- History ------*\n";
      uMessage    += "Grp  Range   Price        Gain    Draw    Adv     Act\n";

      for (int idx=0;idx<ArraySize(History);idx++)
        uMessage += FormatData(History[idx]);
      
      uMessage    += "\n*----- Running ------*\n";
      uMessage    += "Grp  Range   Price        Gain    Draw    Adv     Act\n";

      for (int idx=0;idx<ArraySize(Running);idx++)
        uMessage += FormatData(Running[idx]);

      Comment(uMessage);
    }
  }
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStrategy::Update(void)
  {    
    UpdateStatistics();
  }
