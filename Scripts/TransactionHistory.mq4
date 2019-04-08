//+------------------------------------------------------------------+
//|                                           TransactionHistory.mq4 |
//|                                                 Dennis Jorgenson |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dennis Jorgenson"
#property link      ""
#property version   "1.00"
#property strict
static int mPrev;
int m;

int init()
  {
   mPrev=Minute();
   return(0);
  }
//+------------------------------------------------------------------+
int start()
  {
   int i,handle,hstTotal=HistoryTotal();
   m=Minute();
   if(1==1)
      {
      mPrev=m;
      handle=FileOpen("OrdersReport1.csv",FILE_WRITE|FILE_CSV,",");
      if(handle<0) return(0);
      FileWrite(handle,"#,Open Time,Type,Lots,Symbol,Price,Stop/Loss,Take Profit,Close Time,Close Price,Swap,Commission,Profit,Comment");
      for(i=0;i<hstTotal;i++)
         {
         if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==true)
            {
            FileWrite(handle,OrderTicket(),TimeToStr(OrderOpenTime(),TIME_DATE|TIME_MINUTES),OrderType(),OrderLots(),OrderSymbol(),OrderOpenPrice(),OrderStopLoss(),OrderTakeProfit(),TimeToStr(OrderCloseTime(),TIME_DATE|TIME_MINUTES),OrderClosePrice(),OrderSwap(),OrderCommission(),OrderProfit(),OrderComment());
            }
         }
      FileClose(handle);
      }
   return(0);
  }