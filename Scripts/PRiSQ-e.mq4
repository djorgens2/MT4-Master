
#property  copyright "ANG3110@latchess.com"
//-----------------------------------------
#property show_inputs
//--------------------
extern int m = 2;
extern double ksq=2;
//------------------------------------------
double fx,fx1;
double a[10,10],b[10],x[10],sx[20];
double sum,sum1,sq; 
int p,nn,kt;
//---------------------
int i0,ip,pn,i0n,ipn;
int t0,tp,te,te1;
//----------------------------------------
void init() 
{
  //----------------------
  p=50; 
  kt=Period()*60;
  nn=m+1; 
  //----------------------
  t0=TimeOnDropped();
  i0=iBarShift(Symbol(),Period(),t0);
  ip=i0+p;
  tp=Time[ip];
  pn=p;
  //----------------------ar------------------------------
  for (int j=-p/2; j<p; j++)
  {
    ObjectCreate("ar"+j,2,0,Time[i0+1+j],0,Time[i0+j],0); 
    ObjectSet("ar"+j,OBJPROP_RAY,0);  
    ObjectCreate("arH"+j,2,0,Time[i0+1+j],0,Time[i0+j],0); 
    ObjectSet("arH"+j,OBJPROP_RAY,0);
    ObjectCreate("arL"+j,2,0,Time[i0+1+j],0,Time[i0+j],0); 
    ObjectSet("arL"+j,OBJPROP_RAY,0);  
  }
  //----------------------LR------------------------------
  ObjectCreate("LR",4,0,Time[ip],0,Time[i0],0);
  ObjectSet("LR",OBJPROP_COLOR,SkyBlue); 
  ObjectSet("LR",OBJPROP_RAY,1);
}
//************************************************
int start() 
{
  int i,n,k;
  //---- 
  while(IsStopped()==false) 
  {
    if (i0n!=i0 || ipn!=ip)
    {
      p=ip-i0;
      i0n=ip;
      ipn=ip;
      //--------------------------------------------------------
      if (pn<p)
      {
        for(int j=pn; j<=p; j++) {ObjectCreate("ar"+j,2,0,Time[i0+1+j],0,Time[i0+j],0); ObjectSet("ar"+j,OBJPROP_RAY,0); ObjectCreate("arH"+j,2,0,Time[i0+1+j],0,Time[i0+j],0); ObjectSet("arH"+j,OBJPROP_RAY,0); ObjectCreate("arL"+j,2,0,Time[i0+1+j],0,Time[i0+j],0); ObjectSet("arL"+j,OBJPROP_RAY,0);}  
        for (j=-pn/2; j>=-p/2; j--) {ObjectCreate("ar"+j,2,0,Time[i0+1+j],0,Time[i0+j],0); ObjectSet("ar"+j,OBJPROP_RAY,0); ObjectCreate("arH"+j,2,0,Time[i0+1+j],0,Time[i0+j],0); ObjectSet("arH"+j,OBJPROP_RAY,0); ObjectCreate("arL"+j,2,0,Time[i0+1+j],0,Time[i0+j],0); ObjectSet("arL"+j,OBJPROP_RAY,0);} 
        pn=p;    
      }
      if (pn>p)
      {
        for(j=pn; j>=p; j--) {ObjectDelete("ar"+j); ObjectDelete("arH"+j); ObjectDelete("arL"+j);}
        for (j=-p/2; j>=-pn/2; j--){ObjectDelete("ar"+j); ObjectDelete("arH"+j); ObjectDelete("arL"+j);}   
        pn=p;
      }
    }
    //===========================PR============================================================
    sx[1]=p+1;
    //----------------------sx---------------------------------------------------------------
    for(i=1; i<=nn*2-2; i++) 
    {
      sum=0.0; 
      for(n=i0; n<=i0+p; n++) sum+=MathPow(n,i); 
      sx[i+1]=sum;
    }  
    //----------------------syx---------------------------------------------------------------
    for(i=1; i<=nn; i++) 
    {
      sum=0.0; 
      for(n=i0; n<=i0+p; n++) 
      {
        if (i==1) sum+=Close[n]; 
        else 
        sum+=Close[n]*MathPow(n,i-1);
      } 
      b[i]=sum;
    } 
    //===============Matrix====================================================================================================
    for(j=1; j<=nn; j++) 
    {
      for(i=1; i<=nn; i++) {k=i+j-1; a[i,j]=sx[k];}
    }  
    //===============Gauss===================================================
    af_Gauss(nn,a,b,x);
    //=======================SQ==============================================
    sq=0.0;
    for (n=p; n>=0; n--)
    {
      sum=0.0;
      for(k=1; k<=m; k++) {sum+=x[k+1]*MathPow(i0+n,k); sum1+=x[k+1]*MathPow(i0+n+1,k);}
      fx=x[1]+sum;
      sq+=MathPow(Close[n+i0]-fx,2);
    }
    sq=ksq*MathSqrt(sq/(p+1));
    //=======================================================================
    for (n=p; n>=-p/2; n--) 
    {
      sum=0.0; 
      sum1=0.0; 
      for(k=1; k<=m; k++) {sum+=x[k+1]*MathPow(i0+n,k); sum1+=x[k+1]*MathPow(i0+n+1,k);}  
      fx=x[1]+sum;
      fx1=x[1]+sum1;
        
      if (n>=0 && n<p)
      {
        ObjectMove("ar"+n,0,Time[n+i0+1],fx1); 
        ObjectMove("ar"+n,1,Time[n+i0],fx);
        ObjectMove("arH"+n,0,Time[n+i0+1],fx1+sq); 
        ObjectMove("arH"+n,1,Time[n+i0],fx+sq);
        ObjectMove("arL"+n,0,Time[n+i0+1],fx1-sq); 
        ObjectMove("arL"+n,1,Time[n+i0],fx-sq);
        
        if (fx>fx1) {ObjectSet("ar"+n,OBJPROP_COLOR,Lime); ObjectSet("arH"+n,OBJPROP_COLOR,Lime); ObjectSet("arL"+n,OBJPROP_COLOR,Lime);}
        if (fx<fx1) {ObjectSet("ar"+n,OBJPROP_COLOR,Yellow); ObjectSet("arH"+n,OBJPROP_COLOR,Yellow); ObjectSet("arL"+n,OBJPROP_COLOR,Yellow);}  
      }
        
      if (n<0)
      {
        if ((n+i0)>=0) 
        {
          ObjectMove("ar"+n,0,Time[n+i0+1],fx1); 
          ObjectMove("ar"+n,1,Time[n+i0],fx);
          ObjectMove("arH"+n,0,Time[n+i0+1],fx1+sq); 
          ObjectMove("arH"+n,1,Time[n+i0],fx+sq);
          ObjectMove("arL"+n,0,Time[n+i0+1],fx1-sq); 
          ObjectMove("arL"+n,1,Time[n+i0],fx-sq);
        }
        if ((n+i0)<0) 
        {
          te=Time[0]-(n+i0)*kt; 
          te1=Time[0]-(n+i0+1)*kt;
          ObjectMove("ar"+n,0,te1,fx1); 
          ObjectMove("ar"+n,1,te,fx);
          ObjectMove("arH"+n,0,te1,fx1+sq); 
          ObjectMove("arH"+n,1,te,fx+sq);
          ObjectMove("arL"+n,0,te1,fx1-sq); 
          ObjectMove("arL"+n,1,te,fx-sq);
        } 
        
        if (fx>fx1) {ObjectSet("ar"+n,OBJPROP_COLOR,Blue); ObjectSet("arH"+n,OBJPROP_COLOR,Blue); ObjectSet("arL"+n,OBJPROP_COLOR,Blue);}
        if (fx<fx1) {ObjectSet("ar"+n,OBJPROP_COLOR,Red); ObjectSet("arH"+n,OBJPROP_COLOR,Red); ObjectSet("arL"+n,OBJPROP_COLOR,Red);}
      }
    }
    //==========================ObjMove===================================
    if (fx!=0)
    {
      ObjectMove("LR",0,Time[ip],0); 
      ObjectMove("LR",1,Time[i0],0);
    }
    //========================Comment=====================================
    Comment
    (
      "t0 = ",TimeToStr(t0,TIME_DATE|TIME_MINUTES),"\n",
      "tp = ",TimeToStr(tp,TIME_DATE|TIME_MINUTES),"\n",
      "2*SQ = ",DoubleToStr(2*sq/Point,1)
    );
    //====================================================================
    t0=ObjectGet("LR",OBJPROP_TIME2); 
    if (t0>Time[0]) t0=Time[0]; 
    tp=ObjectGet("LR",OBJPROP_TIME1);
    if (tp>Time[i0+2]) tp=Time[i0+2]; 
    i0=iBarShift(Symbol(),Period(),t0);
    ip=iBarShift(Symbol(),Period(),tp);
    //====================================================================
    Sleep(500);
  }//---while---
  //----
  return(0);
}
//************************************************************************
void deinit() 
{
  for (int j=p; j>=-p/2; j--)
  { 
    ObjectDelete("ar"+j);
    ObjectDelete("arH"+j);
    ObjectDelete("arL"+j);
  }  
  ObjectDelete("LR");  
  Comment("");
}
//*************************************************************** 
void af_Gauss(int n, double& a[][],double& b[], double& x[])
{
  int i,j,k,l;
  double q,m,t;

  for(k=1; k<=n-1; k++) 
  {
    l=0; 
    m=0; 
    for(i=k; i<=n; i++) 
    {
      if (MathAbs(a[i,k])>m) {m=MathAbs(a[i,k]); l=i;}
    } 
    if (l==0) return(0);   

    if (l!=k) 
    {
      for(j=1; j<=n; j++) 
      {
        t=a[k,j]; 
        a[k,j]=a[l,j]; 
        a[l,j]=t;
      } 
      t=b[k]; 
      b[k]=b[l]; 
      b[l]=t;
    }  

    for(i=k+1;i<=n;i++) 
    {
      q=a[i,k]/a[k,k]; 
      for(j=1;j<=n;j++) 
      {
        if (j==k) a[i,j]=0; 
        else 
        a[i,j]=a[i,j]-q*a[k,j];
      } 
      b[i]=b[i]-q*b[k];
    }
  }  
  
  x[n]=b[n]/a[n,n]; 
  
  for(i=n-1;i>=1;i--) 
  {
    t=0; 
    for(j=1;j<=n-i;j++) 
    {
      t=t+a[i,i+j]*x[i+j]; 
      x[i]=(1/a[i,i])*(b[i]-t);
    }
  }
  return;
}
//********************************************************************** 
   