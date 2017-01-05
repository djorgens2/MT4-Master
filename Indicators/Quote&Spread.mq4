#property indicator_chart_window

int deinit()
  {
  ObjectDelete("Spread_Label");
  ObjectDelete("BidA_Label");
  ObjectDelete("BidB_Label");
  ObjectDelete("AskA_Label");
  ObjectDelete("AskB_Label");
  return(0);
  }

int start()
  {
   double Spread = NormalizeDouble((MarketInfo(Symbol(), MODE_SPREAD)/10),1);
   double SpreadColour;
   if(Spread <= 1.6)
   {SpreadColour = C'80,80,80';}
   if(Spread >1.6)
   {SpreadColour = OrangeRed;}
 
   ObjectCreate("Spread_Label",OBJ_LABEL,0,0,0);
   ObjectSet("Spread_Label", OBJPROP_CORNER, 4);
   ObjectSet("Spread_Label",OBJPROP_XDISTANCE,300);
   ObjectSet("Spread_Label",OBJPROP_YDISTANCE,20);
   ObjectSetText("Spread_Label",DoubleToStr(Spread,1),24,"Centuary",SpreadColour);

   string BidA, BidB, Base_Bid; 
   
   Base_Bid = DoubleToStr(Bid, Digits);
   int SLengthBid = StringLen(Base_Bid);
   
   BidA = StringSubstr(Base_Bid, 0, SLengthBid-1);
   BidB = StringSubstr(Base_Bid, SLengthBid-1, 1);
   
   ObjectCreate("BidA_Label", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("BidA_Label", BidA,40, "Centuary", FireBrick);
   ObjectSet("BidA_Label", OBJPROP_CORNER, 4);
   ObjectSet("BidA_Label", OBJPROP_XDISTANCE, 1);
   ObjectSet("BidA_Label", OBJPROP_YDISTANCE, 1);
   
   ObjectCreate("BidB_Label", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("BidB_Label", BidB, 25, "Centuary", FireBrick);
   ObjectSet("BidB_Label", OBJPROP_CORNER, 4);
   ObjectSet("BidB_Label", OBJPROP_XDISTANCE, 165);
   ObjectSet("BidB_Label", OBJPROP_YDISTANCE, 4);

  string AskA, AskB, Base_Ask; 
   
   Base_Ask = DoubleToStr(Ask, Digits);
   int SLengthAsk = StringLen(Base_Ask);
   
   AskA = StringSubstr(Base_Ask, SLengthAsk-3, 2 );
   AskB = StringSubstr(Base_Ask, SLengthAsk-1, 1);
   
   ObjectCreate("AskA_Label", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("AskA_Label", AskA,40, "Centuary", Green);
   ObjectSet("AskA_Label", OBJPROP_CORNER, 4);
   ObjectSet("AskA_Label", OBJPROP_XDISTANCE, 200);
   ObjectSet("AskA_Label", OBJPROP_YDISTANCE, 1);
   
   ObjectCreate("AskB_Label", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("AskB_Label", AskB, 25, "Centuary", Green);
   ObjectSet("AskB_Label", OBJPROP_CORNER, 4);
   ObjectSet("AskB_Label", OBJPROP_XDISTANCE, 260);
   ObjectSet("AskB_Label", OBJPROP_YDISTANCE, 4);
   
   return(0);
  }
  
  
  