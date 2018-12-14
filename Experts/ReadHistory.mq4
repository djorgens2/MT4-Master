//+------------------------------------------------------------------+
//|                                                  ReadHistory.mq4 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#import "kernel32.dll"
int CreateFileW(string,uint,int,int,int,int,int);
int GetFileSize(int,int);
int SetFilePointer(int,int,int&[],int);
int ReadFile(int,uchar&[],int,int&[],int);
int CloseHandle(int);
#import


int   previousBar=0;
int BytesToRead=0;
int hst_handle;
string result;
string account_server,datapath;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
union Price
  {
   uchar             buffer[8];
   double            close;
  };

Price price;

double data[][2];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   account_server=AccountInfoString(ACCOUNT_SERVER);
   if(account_server=="") account_server="default";

   datapath=TerminalInfoString(TERMINAL_DATA_PATH)+"\\history\\"+
            account_server+"\\"+Symbol()+"240"+".hst";

   result=ReadFileHst(datapath);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(BytesToRead>0)Comment("History data loaded");

   if(previousBar!=Bars)
     {
      previousBar=Bars;
     }
   else
     {
      return;
     }


   if(BytesToRead>0)
     {
      int pos=-1;
      for(int i=0;i<BytesToRead-1;i++)
        {
         if(data[i][0]<Time[0])

           {
            pos=i+1;
           }
         else break;

        }

     }

  }
//+------------------------------------------------------------------+
string ReadFileHst(string Filename)
  {

   int j=0;

   string strFileContents="";
   int Handle=CreateFileW(Filename,0x80000000,3,0,3,0,0);

   if(Handle==-1)
     {
      Print("Error open history!");
      return ("");
     }

   else
     {
      int LogFileSize=GetFileSize(Handle,0);

      if(LogFileSize<=0)
        {
         return ("");
        }

      else
        {

         int movehigh[1];

         SetFilePointer(Handle,148,movehigh,0);

         uchar buffer[];
         BytesToRead=(LogFileSize-148)/60;

         ArrayResize(data,BytesToRead);

         int nNumberOfBytesToRead=60;

         ArrayResize(buffer,nNumberOfBytesToRead);
         int read[1];

         for(int i=0;i<BytesToRead;i++)
           {
            ReadFile(Handle,buffer,nNumberOfBytesToRead,read,0);
            if(read[0]==nNumberOfBytesToRead)
              {
               result="";
               result=StringFormat("0x%02x%02x%02x%02x%02x%02x%02x%02x",buffer[7],buffer[6],buffer[5],buffer[4],buffer[3],buffer[2],buffer[1],buffer[0]);

               price.buffer[0]=buffer[32];
               price.buffer[1]=buffer[33];
               price.buffer[2]=buffer[34];
               price.buffer[3]=buffer[35];
               price.buffer[4]=buffer[36];
               price.buffer[5]=buffer[37];
               price.buffer[6]=buffer[38];
               price.buffer[7]=buffer[39];

               double mm=price.close;

               data[j][0]=StrToDouble(result);
               data[j][1]=mm;
               j++;

               strFileContents=TimeToStr((datetime)StrToDouble(result),TIME_DATE|TIME_MINUTES)+" "+DoubleToStr(mm,8);
              }
            else
              {
               CloseHandle(Handle);
               return ("");
              }
           }
        }

      CloseHandle(Handle);
     }

   strFileContents=TimeToStr((datetime)(data[j-1][0]),TIME_DATE|TIME_MINUTES)+" "+DoubleToStr(data[j-1][1],8)+" "+
                   TimeToStr((datetime)(data[j-2][0]),TIME_DATE|TIME_MINUTES)+" "+DoubleToStr(data[j-2][1],8);

   return strFileContents;
  }
//+------------------------------------------------------------------+
