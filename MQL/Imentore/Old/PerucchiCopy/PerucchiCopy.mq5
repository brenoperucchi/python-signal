//VERSAO BRENO 29/09/2019
//+------------------------------------------------------------------+
//|                     Automaticaly Copy and Delete Order           |
//|                                Copyright 2022, V                 |
//+------------------------------------------------------------------+
#property version "2.0"
#property copyright "Breno Perucchi - Copyright © 2022"
#property description ""
#property strict

#include <MT4Orders.mqh> // если есть #include <Trade/Trade.mqh>, вставить эту строчку ПОСЛЕ
#include <MQL4_to_MQL5.mqh> // ТОЛЬКО для данного примера

//+------------------------------------------------------------------+
//| Enumerator of working mode                                       |
//+------------------------------------------------------------------+
input int slip=3;                // Slippage (in pips)
input double mult=1.0;           // Multiplier (for copied trade)
input uint delay=1000;            // Check frequency (milliseconds)
input string prefix="VCPY_";     // Copied trade comment prefix
input int maxAge=10;             // Max age of the trade to be copied in sec
input string CommentCopy="";     // CommentPrefix to should be copy

int    prev_ordersize         = 0;
int    ordersize              = 0;
int    changed                = 0;
uint   ticketstart = 0; 
uint   tickcount   = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Struct Order Container                                           |
//+------------------------------------------------------------------+
struct OrdersStruct
 {
   long               ticket;
   long               copiedFrom;
   string            symbol;
   string            state;
   int               type;
   double            price;
   double            lot;
   double            stoploss;
   double            takeprofit;
   datetime          opentime;
   string            comment;
 };
OrdersStruct history_orders[];

// class OrderContainer
//   {
// public:
//    long               ticket;
//    long               copiedFrom;
//    string            symbol;
//    int               type;
//    double            price;
//    double            lot;
//    double            stoploss;
//    double            takeprofit;
//    datetime          opentime;
//    string            comment;

//                      OrderContainer(void);
//                     ~OrderContainer(void)
//      {
//      }

//                      OrderContainer(long pticket,
//                                                       string psymbol,
//                                                       int ptype,
//                                                       double pprice,
//                                                       double plot,
//                                                       double pstoploss,
//                                                       double ptakeprofit,
//                                                       datetime popentime,
//                                                       string pcomment)
//      {
//       ticket = pticket;
//       symbol = psymbol;
//       type=ptype;
//       price=pprice;
//       lot=plot;
//       stoploss=pstoploss;
//       takeprofit=takeprofit;
//       opentime= popentime;
//       comment = pcomment;

//       if(StringSubstr(pcomment,0,StringLen(prefix))==prefix)
//         {
//          copiedFrom=StringToInteger(StringSubstr(pcomment,StringLen(prefix)));
//         }
//      }
//   };
  
  

  
//+------------------------------------------------------------------+
//|Initialisation function                                           |
//+------------------------------------------------------------------+          
int OnInit()
  {
  

  
    prev_ordersize = 0;
    ordersize = OrdersTotal();
    prev_ordersize = ordersize;
    
    
    GetCurrentOrdersOnStart();
    EventSetMillisecondTimer(delay);     // Set Millisecond Timer to get client socket input
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|Deinitialisation function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
  EventKillTimer();

  }
   
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
 {
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
 {

      
      ticketstart = GetTickCount();

      StateOfOrder();           
      int orderCount=OrdersTotal();
      
      //tickcount = GetTickCount() - ticketstart;
        
     // if (delay > tickcount)
      //  Sleep(delay-tickcount-2);
    }

//+------------------------------------------------------------------+
//| Get all of the orders                                            |
//+------------------------------------------------------------------+
//int GetCurrentOrdersOnTicket()
 void StateOfOrder()
  { 
    ordersize = OrdersTotal();
    // OrderContainer *orders[100];
    OrdersStruct orders[];
             
    if (ordersize > prev_ordersize)
      {
       // Trade has been added
        PushOpenOrder(orders);
        GetCurrentOrdersOnStart();
      }
    else if (ordersize < prev_ordersize)
      {
        // Trade has been closed
        PushCloseOrder(orders);
        GetCurrentOrdersOnStart();
      }
  } 
  
void PushOpenOrder(OrdersStruct &orders[])
   {
     int orderCount=OrdersTotal();
     GetOrders(orders);
     if(!OrderSelect( ( OrdersTotal() -1 ), SELECT_BY_POS)) return; 
     //Print(OrderComment());
     //if(CommentCopy == OrderComment())
     OpenMarketOrder(OrderTicket(),OrderSymbol(), OrderType(),OrderOpenPrice(),(OrderLots() *mult));
   }  
   
   
void PushCloseOrder(OrdersStruct &orders[])
  {
     int orderCount=OrdersTotal();
     GetOrders(orders);
     
     for(int i=0;i<orderCount;i++)
       {
        int orderCloseReturnValue=-1;

        long commentID = StringToInteger(StringSubstr(orders[i].comment,StringLen(prefix)));
        bool toClose=true;
        if(StringSubstr((orders[i]).comment,0,StringLen(prefix))==prefix)
          {
            for(int j=0;j<orderCount;j++)
              {
               if(orders[j].ticket == commentID)
                 toClose=false;
              }
            if(toClose)
              {
                if(OrderSelect(orders[i].ticket, SELECT_BY_TICKET)==true)
                  {
                   Print("order", OrderTicket(), "open price is ", OrderOpenPrice());
                   Print("order", OrderTicket(), "close price is ", OrderClosePrice());
                   if(OrderType()<2)
                     orderCloseReturnValue=OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),slip);
                   else 
                     orderCloseReturnValue=OrderDelete(OrderTicket());
                  }
                else
                  Print("OrderSelect returned the error of ",GetLastError());
         
               if(orderCloseReturnValue==-1)
                 {
                  Print("Error: ",GetLastError()," during closing the market order.");
                 }
               else
                 {
                  OrderPrint();
                  Print("Market order ",IntegerToString(OrderTicket())," (",OrderComment(),") closed as parent trade was also closed.");
                 }
              }
            
          }
       }  
   } 


void PushClosedOrders(){
  bool changes = false;
  int history_orders_size = ArraySize(history_orders);
  int i = HistoryDealsTotal()-1;
  for (i; i >= 0; i--) {
    ulong ticketid = HistoryDealGetTicket(i);
    for( int ii = 0; ii <= history_orders_size; i++ ){
      if(history_orders_size > 0 && history_orders[ii].ticket == ticketid){
        if(history_orders[ii].state != "CLOSED"){
          //PushOrderClosed(history_orders[ii].ticket)  
        }
      } else {
        history_orders[ii].ticket = ticketid;
        history_orders[ii].state = "EXECUTED";
      }

    }
    // history_orders[history_orders_size + 1].ticket = ticketid
  }
}

//+------------------------------------------------------------------+
//|Open market execution orders                                      |
//+------------------------------------------------------------------+
void OpenMarketOrder(long ticket_,string symbol_,int type_,double price_,double lot_)
  {
   long orderSendReturnValue=-1;
   double market_price=MarketInfo(symbol_,MODE_BID);
   if(type_==0) market_price=MarketInfo(symbol_,MODE_ASK);
   double delta;
   double market_info = SymbolInfoDouble(symbol_, SYMBOL_POINT);
   delta=MathAbs(market_price-price_)/market_info;
   OrderPrint();
   
   if(type_ < 2)
     {
      orderSendReturnValue=OrderSend(symbol_,type_,lot_,market_price,slip,0,0,prefix+IntegerToString(ticket_),0,0,clrYellow);
     }
   else
     {   
      if(delta<slip)
         return;
   
      orderSendReturnValue=OrderSend(symbol_,type_,lot_,price_,slip,0,0,prefix+IntegerToString(ticket_),0,0,clrYellow);
                                //OrderSend(symbol, OP_BUY, vlots, vprice, order_slippage, sl, tp, comment, 0, 0, clrYellow);
   }   
   if(orderSendReturnValue==-1)
     {
      Print("Error: ",GetLastError()," during opening the market order.");
     }
   else
     {
      Print("Market order ",IntegerToString(ticket_)," copied as ",prefix+IntegerToString(ticket_),".");
     }
   return;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GetOrders(OrdersStruct &orders[])
  {
   //OrderContainer *orders[100];
   int orderCount=OrdersTotal();
   ArrayResize(orders, orderCount);

   if(orderCount==0)
      return;

//--- Saving information about all deals
   for(int i=0; i<orderCount; i++)
     {
      if(!OrderSelect(i,SELECT_BY_POS)) break;
      orders[i].ticket = OrderTicket();
      orders[i].symbol = OrderSymbol();
      orders[i].type = OrderType();
      orders[i].price = OrderOpenPrice();
      orders[i].lot = OrderLots();
      orders[i].stoploss = OrderStopLoss();
      orders[i].takeprofit = OrderTakeProfit();
      orders[i].opentime = OrderOpenTime();
      orders[i].comment = OrderComment();
     }
  }
  

//+------------------------------------------------------------------+
//| Get all of the orders                                            |
//+------------------------------------------------------------------+
void GetCurrentOrdersOnStart()
  {
    prev_ordersize = 0;
    ordersize = OrdersTotal();
    PushClosedOrders();
    
    if (ordersize == prev_ordersize)
      return;

    prev_ordersize = ordersize;   

  }