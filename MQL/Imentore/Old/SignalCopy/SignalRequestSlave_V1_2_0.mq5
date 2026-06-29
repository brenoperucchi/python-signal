//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
#property version "1.20"
#property copyright   "Copyright 2021"
#property description "Coded by Breno Perucchi"
#property strict

#define EXPERTNAME "signal_request_slave"
#define VERSION "1_20"

#define APPNAME "Signal Slave"
#define APPVERSION "1.20"

//--- Declaration of constants
#define OP_BUY 0           //Buy 
#define OP_SELL 1          //Sell 
#define OP_BUYLIMIT 2      //Pending order of BUY LIMIT type 
#define OP_SELLLIMIT 3     //Pending order of SELL LIMIT type 
#define OP_BUYSTOP 4       //Pending order of BUY STOP type 
#define OP_SELLSTOP 5      //Pending order of SELL STOP type 
//---
#define MODE_OPEN 0
#define MODE_CLOSE 3
#define MODE_VOLUME 4
#define MODE_REAL_VOLUME 5
#define MODE_TRADES 0
#define MODE_HISTORY 1
#define SELECT_BY_POS 0
#define SELECT_BY_TICKET 1
//---
#define DOUBLE_VALUE 0
#define FLOAT_VALUE 1
#define LONG_VALUE INT_VALUE
//---
#define CHART_BAR 0
#define CHART_CANDLE 1
//---
#define MODE_ASCEND 0
#define MODE_DESCEND 1
//---
#define MODE_LOW 1
#define MODE_HIGH 2
#define MODE_TIME 5
#define MODE_BID 9
#define MODE_ASK 10
#define MODE_POINT 11
#define MODE_DIGITS 12
#define MODE_SPREAD 13
#define MODE_STOPLEVEL 14
#define MODE_LOTSIZE 15
#define MODE_TICKVALUE 16
#define MODE_TICKSIZE 17
#define MODE_SWAPLONG 18
#define MODE_SWAPSHORT 19
#define MODE_STARTING 20
#define MODE_EXPIRATION 21
#define MODE_TRADEALLOWED 22
#define MODE_MINLOT 23
#define MODE_LOTSTEP 24
#define MODE_MAXLOT 25
#define MODE_SWAPTYPE 26
#define MODE_PROFITCALCMODE 27
#define MODE_MARGINCALCMODE 28
#define MODE_MARGININIT 29
#define MODE_MARGINMAINTENANCE 30
#define MODE_MARGINHEDGED 31
#define MODE_MARGINREQUIRED 32
#define MODE_FREEZELEVEL 33
//---
#define EMPTY -1

#include <MT4Orders.mqh> 
#include <MQL4_to_MQL5.mqh> 
#include<Trade\Trade.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input double MinLots                 = 0.00;                    // Limit the minimum lots (Default is 0.00)
input double MaxLots                 = 0.00;                    // Limit the maximum lots (Default is 0.00)
input double PercentLots             = 100;                     // Lots Percent from Signal (Default is 100)
input int    Slippage                = 30;
input bool   ServerReal              = false;                   // Under real server (Default is false)
string prefix                        = "";                      // Copied trade comment prefix
string Server                        = "192.168.1.240";  // Subscribe server ip

int    prev_ordersize    = 0;
int    ordersize         = 0;
long   orderids[];
double orderopenprice[];
double orderlot[];
double ordersl[];
double ordertp[];
bool   orderchanged      = false;
//--- Globales Order
bool   order_allowopen   = true;
bool   order_allowclose  = true;
bool   order_allowmodify = true;
bool   order_invert      = false;
double account_minmarginfree = 0.00;
double order_minlots     = 0.00;
double order_maxlots     = 0.00;
double order_percentlots = 1;
int    order_slippage    = 0;
int MILLISECOND_TIMER = 1500;

CTrade trade;

//+------------------------------------------------------------------+
//| Struct Order Container                                           |
//+------------------------------------------------------------------+
struct OrdersStruct{
   long              type;
   long              order_id;
   long              trace_id;
   long              slave_id;
   long              magicnumber;
   long              transaction_id;
   double            price;
   double            lot;
   double            stoploss;
   double            takeprofit;
   string            state;
   string            symbol;
   string            comment;
};

//+------------------------------------------------------------------+
//|Initialisation function                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(DetectEnvironment() == false)
     {
      Print("Consultor Expert ", APPNAME + " " + APPVERSION, " não inicializado. Contante o suporte.");
      return(INIT_FAILED);
     }
   else
     {      
      Print("Consultor Expert ", APPNAME + " " + APPVERSION, " inicializado com sucesso.");
      return(INIT_SUCCEEDED);
     }
  }

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
   int  changed = 0;
   changed = GetCurrentOrdersOnTicket();

   if(changed > 0)
    prev_ordersize = ordersize;
  }

//+------------------------------------------------------------------+
//|Deinitialisation function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   return;
  }

//+------------------------------------------------------------------+
//| Detect the script parameters                                     |
//+------------------------------------------------------------------+
bool DetectEnvironment()
  {

   if(ServerReal == true && IsDemoMQL4())
     {
      Print("Conta MetaTrader é demo, por favor troque para a real.");
      return false;
     }

   order_minlots = MinLots;
   order_maxlots = MaxLots;
   order_percentlots = (order_percentlots > 0) ? PercentLots : 100;
   order_slippage = Slippage;
   prev_ordersize = OrdersTotal();
   
   EventSetMillisecondTimer(MILLISECOND_TIMER);     // Set Millisecond Timer to get client socket input

   return true;
  }

//+------------------------------------------------------------------+
//| FormatMessage                                                    |
//+------------------------------------------------------------------+
string MessageSendFormat(const string action)
  {
   string send_message = StringFormat("body={'account_login':'%d', 'magic_number':'%d', 'action':'%s', 'order_ticket':'%d', 'order_symbol':'%s', 'order_type':'%d', 'open_price':'%f', 'close_price':'%f', 'volume':'%f', 'stop_loss':'%f', 'take_profit':'%f', 'profit':'%f', 'comment':'%s', 'open_at':'%f'}",
                                      AccountInfoInteger(ACCOUNT_LOGIN),
                                      OrderMagicNumber(),
                                      action,
                                      OrderTicketID(),
                                      OrderSymbol(),
                                      OrderType(),
                                      OrderOpenPrice(),
                                      OrderClosePrice(),
                                      OrderLots(),
                                      OrderStopLoss(),
                                      OrderTakeProfit(),
                                      OrderProfit(),
                                      OrderComment(),
                                      OrderOpenTime()
                                     );
   return send_message;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ApiTrasmitInformation(const string message)
  {
     {
      string account_id = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
      string url="http://"+ Server +"/api/v1/transactions/trasmit/"+ EXPERTNAME +"/"+ VERSION +"/"+ account_id;
      string cookie=NULL,headers,serverHeaders;
      int response = 0;
      char post[],result[];
      int count = 0;
      ResetLastError();
      StringToCharArray(message, post,0, StringLen(message));

      while(response != 201 && count <=1)
        {
         //response=WebRequest("POST",url,cookie,NULL,500,post,ArraySize(post),result,headers);
         //response = WebRequest("POST",url,cookie, 5000, post, result, headers);
         response = WebRequest("POST", url, headers, 5000, post, result, serverHeaders);
         if(response == 201)
           {
            string response_data[];
            string result2 = CharArrayToString(result);
            int    size = StringSplit(result2, '|', response_data);
            if(size !=3)
               continue;
            if(response_data[2] == "OK")
               return true;
           }
         else
           {
            Print("Api código de erro: ",GetLastError(), ",  resposta: ", response);
            // MessageBox("É necessário adicionar um endereço '"+url+"' à lista de URL permitidas na guia 'Experts'","Erro",MB_ICONINFORMATION);
           }
         count++;
        }
      return false;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ApiRequestInformation(string &orderdata[], const string action)
  {
   string account_id = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string cookie=NULL,headers,serverHeaders;
   char   post[],result[];
   string url="http://"+ Server +"/api/v1/transactions/request/"+action+"/"+ EXPERTNAME +"/"+ VERSION +"/"+ account_id;
   ResetLastError();
   int response = WebRequest("POST", url, headers, 5000, post, result, serverHeaders);

   if(response==-1)
     {
      Print("Api código de erro: ",GetLastError());
      // MessageBox("É necessário adicionar um endereço '"+url+"' à lista de URL permitidas na guia 'Experts'","Erro",MB_ICONINFORMATION);
     }
   else
     {
      if(response==201)
        {
         string result2 = CharArrayToString(result);
         int    size = StringSplit(result2, '/', orderdata);
        }
      else
         Print("Api código de erro: ",GetLastError(), ",  resposta: ", response);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ApiGetOrders(OrdersStruct &executed[], OrdersStruct &pending[], OrdersStruct &remove[])
  {
   string orderdata[];
   ApiRequestInformation(orderdata, "entire");
   int orderdataCount = ArraySize(orderdata);
   int size_executed = 0;
   int size_remove = 0;
   int size_pending = 0;
   
   if(orderdataCount==0)
      return;

   for(int i=0; i<orderdataCount; i++)
     {
      string orderdataparse[];
      ParseMessage(orderdata[i], orderdataparse);
      string comment = StringFormat("%s|%s", orderdataparse[2], orderdataparse[3]);
      
      if(orderdataparse[10] == "executed"){      
        ArrayResize(executed, size_executed+1);
        executed[size_executed].type = StringToInteger(orderdataparse[0]);
        executed[size_executed].order_id = StringToInteger(orderdataparse[1]);
        executed[size_executed].trace_id = StringToInteger(orderdataparse[2]);
        executed[size_executed].slave_id = StringToInteger(orderdataparse[3]);
        executed[size_executed].magicnumber = StringToInteger(orderdataparse[4]);
        executed[size_executed].transaction_id = StringToInteger(orderdataparse[5]);
        executed[size_executed].price = StringToDouble(orderdataparse[6]);
        executed[size_executed].lot = StringToDouble(orderdataparse[7]);
        executed[size_executed].stoploss = StringToDouble(orderdataparse[8]);
        executed[size_executed].takeprofit = StringToDouble(orderdataparse[9]);
        executed[size_executed].state = orderdataparse[10];
        executed[size_executed].symbol = orderdataparse[11];
        executed[size_executed].comment = comment;
        size_executed++;        
      }
      if(orderdataparse[10] == "pending"){
        ArrayResize(pending, size_pending+1);      
        pending[size_pending].type = StringToInteger(orderdataparse[0]);
        pending[size_pending].order_id = StringToInteger(orderdataparse[1]);
        pending[size_pending].trace_id = StringToInteger(orderdataparse[2]);
        pending[size_pending].slave_id = StringToInteger(orderdataparse[3]);
        pending[size_pending].magicnumber = StringToInteger(orderdataparse[4]);
        pending[size_pending].transaction_id = StringToInteger(orderdataparse[5]);
        pending[size_pending].price = StringToDouble(orderdataparse[6]);
        pending[size_pending].lot = StringToDouble(orderdataparse[7]);
        pending[size_pending].stoploss = StringToDouble(orderdataparse[8]);
        pending[size_pending].takeprofit = StringToDouble(orderdataparse[9]);
        pending[size_pending].state = orderdataparse[10];
        pending[size_pending].symbol = orderdataparse[11];
        pending[size_pending].comment = comment;
        size_pending++;        
      }
      //ArrayFill(orderdataparse[10],i,i,orderda)
      if(orderdataparse[10] == "remove"){
        ArrayResize(remove, size_remove+1);           
        remove[size_remove].type = StringToInteger(orderdataparse[0]);
        remove[size_remove].order_id = StringToInteger(orderdataparse[1]);
        remove[size_remove].trace_id = StringToInteger(orderdataparse[2]);
        remove[size_remove].slave_id = StringToInteger(orderdataparse[3]);
        remove[size_remove].magicnumber = StringToInteger(orderdataparse[4]);
        remove[size_remove].transaction_id = StringToInteger(orderdataparse[5]);
        remove[size_remove].price = StringToDouble(orderdataparse[6]);
        remove[size_remove].lot = StringToDouble(orderdataparse[7]);
        remove[size_remove].stoploss = StringToDouble(orderdataparse[8]);
        remove[size_remove].takeprofit = StringToDouble(orderdataparse[9]);
        remove[size_remove].state = orderdataparse[10];
        remove[size_remove].symbol = orderdataparse[11];
        remove[size_remove].comment = comment;
        size_remove++;
      }
    }
  }

//+------------------------------------------------------------------+
//| Parse the message from server signal                             |
//+------------------------------------------------------------------+
bool ParseMessage(const string message,
                  string &orderdataparse[])
  {
   if(message == "")
      return false;

   int    size = StringSplit(message, '|', orderdataparse);
   return true;
  }

//+------------------------------------------------------------------+
//| Find a current order by server signal                            |
//+------------------------------------------------------------------+
long FindOpenOrderByComment(const string comment)
  {
   long ticketid = -1;

   ordersize  = OrdersTotal();
   int orderindex = 0;

   for(orderindex=0; orderindex<ordersize; orderindex++)
     {
      if(OrderSelect(orderindex, SELECT_BY_POS, MODE_TRADES) == false)
         continue;

      string order_comment = OrderComment();

      if(order_comment == comment)
         ticketid = OrderTicketID();

      if(ticketid > 0)
         break;
     }

   return ticketid;
  }

//+------------------------------------------------------------------+
//| Make a order by signal message (Market and Pending Order)        |
//+------------------------------------------------------------------+
bool MakeOrder(const long login,
               const string op,
               const string symbol,
               const long orderid,
               const long beforeorderid,
               const long type,
               const double openprice,
               const double closeprice,
               const double lots,
               const double sl,
               const double tp,
               const long magicnumber)
  {
   if(login <= 0 || symbol == "" || orderid == 0)
      return false;

   long    ticketid    = -1;
   string comment     = StringFormat("%d|%d", login, orderid);
   bool orderstatus = false;

   if(op == "OPEN")
     {

      if(ticketid <= 0)
        {
         ticketid = MakeOrderOpen(symbol, type, openprice, lots, sl, tp, comment, magicnumber);

         if(ticketid > 0)
           {
            orderstatus = true;
            Print("Order Status:", op, ", Open:", symbol, ", Type:", type, ", TicketId:", ticketid);

            OrderSelect(ticketid, SELECT_BY_TICKET, MODE_TRADES);

            string send_message = MessageSendFormat("OPENED");
            ApiTrasmitInformation(send_message);
           }

        }
     }
   else
      if(op == "CLOSED")
        {
         ticketid = orderid;
         if(ticketid > 0)
           {
            orderstatus = MakeOrderClose(ticketid, symbol, type, closeprice, lots, sl, tp);

            if(orderstatus > 0)
              {
               Print("Order Status:", op, ", Closed:", symbol, ", Type:", type, ", TicketId:", ticketid);
               orderstatus = true;
               OrderSelect(ticketid, SELECT_BY_TICKET, MODE_TRADES);
               string send_message = MessageSendFormat("CLOSED");
               ApiTrasmitInformation(send_message);
              }
           }
        }
      else
         if(op == "MODIFY")
           {
            ticketid = orderid;
            if(ticketid > 0)
              {
               orderstatus = MakeOrderModify(ticketid, symbol, openprice, sl, tp);

               if(orderstatus > 0)
                 {
                  Print("Order Status:", op, ", Modify:", symbol, ", Type:", type, ", TicketId:", ticketid);
                  orderstatus = true;
                  OrderSelect(ticketid, SELECT_BY_TICKET, MODE_TRADES);
                  string send_message = MessageSendFormat("MODIFY");
                  ApiTrasmitInformation(send_message);
                 }
              }
           }
   return (ticketid > 0 && orderstatus) ? true : false;
  }

//+------------------------------------------------------------------+
//| Make a market or pending order by signal message                 |
//+------------------------------------------------------------------+
long MakeOrderOpen(const string symbol,
                   const long type,
                   const double openprice,
                   const double lots,
                   const double sl,
                   const double tp,
                   const string comment,
                   const long magicnumber)
  {
   long ticketid = -1;
   bool response = false;

// Allow signal to open the order
// Symbol must not be empty
   if(order_allowopen == false || symbol == "")
      return ticketid;

// Allow Expert Advisor to open the order
   if(IsTradeAllowed() == false)
      return ticketid;

// Check if account margin free is less than settings
   if(account_minmarginfree > 0.00 && AccountInfoDouble(ACCOUNT_MARGIN_FREE) < account_minmarginfree)
      return ticketid;

   double vprice = 0;
   double vlots = GetOrderLots(symbol, lots);
   long   vtype = type;

// The parameter price must be greater than zero
   if(vprice <= 0.00)
     {
      MqlTick last_tick;
      SymbolInfoTick(Symbol(),last_tick);
      if(vtype == 0)
         vprice = last_tick.ask;
      if(vtype == 1)
         vprice = last_tick.bid;
     }

// Invert the origional order
   if(order_invert)
     {
      switch(int(vtype))
        {
         case 0:
            vtype = 1;
            break;

         case 1:
            vtype = 2;
            break;

         case 2:
            vtype = 4;
            break;

         case 3:
            vtype = 5;
            break;

         case 4:
            vtype = 2;
            break;

         case 5:
            vtype = 3;
            break;
        }
     }
   switch(int(vtype))
     {
      case 0:
         trade.SetExpertMagicNumber(magicnumber);
         trade.SetDeviationInPoints(order_slippage);
         response = trade.Buy(vlots,symbol, 0, sl, tp, comment);
         response ? ticketid = int(trade.ResultOrder()) : -1;
         break;

      case 1:
         trade.SetExpertMagicNumber(magicnumber);
         trade.SetDeviationInPoints(order_slippage);
         response = trade.Sell(vlots,symbol, 0, sl, tp, comment);
         response ? ticketid = int(trade.ResultOrder()) : -1;
         break;
      case 2:
         if(openprice > 0.00)
            ticketid = OrderSend(symbol, OP_BUYLIMIT, vlots, openprice, order_slippage, sl, tp, comment, magicnumber, 0, clrYellow);
         break;

      case 3:
         if(openprice > 0.00)
            ticketid = OrderSend(symbol, OP_BUYSTOP, vlots, openprice, order_slippage, sl, tp, comment, magicnumber, 0, clrYellow);
         break;

      case 4:
         if(openprice > 0.00)
            ticketid = OrderSend(symbol, OP_SELLLIMIT, vlots, openprice, order_slippage, sl, tp, comment, magicnumber, 0, clrYellow);
         break;

      case 5:
         if(openprice > 0.00)
            ticketid = OrderSend(symbol, OP_SELLSTOP, vlots, openprice, order_slippage, sl, tp, comment, magicnumber, 0, clrYellow);
         break;
     }

   return ticketid;
  }

//+------------------------------------------------------------------+
//| Make a order close by signal message                             |
//+------------------------------------------------------------------+
long MakeOrderClose(const long ticketid,
                    const string symbol,
                    const long type,
                    const double closeprice,
                    const double lots,
                    const double sl,
                    const double tp)
  {
   long result = -1;

// Allow signal to close the order
// The parameter ticketid must be greater than zero
   if(order_allowclose == false || ticketid <= 0)
      return result;

// Allow Expert Advisor to close the order
   if(IsTradeAllowed() == false)
      return result;

   if(OrderSelect(ticketid, SELECT_BY_TICKET, MODE_TRADES) == true)
     {
      double price  = closeprice;

      if(price <= 0.00)
         price = SymbolInfoDouble(symbol, SYMBOL_ASK);

      switch(int(type))
        {
         case OP_BUYLIMIT:
         case OP_BUYSTOP:
         case OP_SELLLIMIT:
         case OP_SELLSTOP:
            result = OrderDelete(ticketid);
            break;

         default:
            //result = OrderClose(ticketid, OrderLots(), price, order_slippage, clrYellow);
            result = trade.PositionClose(ticketid);
            result ? result++ : -1;
            break;
        }
     }

   return result;
  }

//+------------------------------------------------------------------+
//| Make a order modify by signal message                            |
//+------------------------------------------------------------------+
long MakeOrderModify(const long ticketid,
                     const string symbol,
                     const double openprice,
                     const double sl,
                     const double tp)
  {
   long result = -1;

// Allow signal to modify the order
// The parameter ticketid must be greater than zero
   if(order_allowmodify == false || ticketid <= 0)
      return result;

// Allow Expert Advisor to modify the order
   if(IsTradeAllowed() == false)
      return result;

   if(OrderSelect(ticketid, SELECT_BY_TICKET, MODE_TRADES) == true)
     {
      result = OrderModify(ticketid, openprice, sl, tp, 0, clrYellow);
      result ? result++ : -1;
     }

   return result;
  }

//+------------------------------------------------------------------+
//| Get all of the orders                                            |
//+------------------------------------------------------------------+
int GetCurrentOrdersOnTicket()
  {
   OrdersStruct executed[];
   OrdersStruct pending[];
   OrdersStruct remove[];
   ApiGetOrders(executed, pending, remove);

   int orders_size_pending = ArraySize(pending);
   int orders_size_remove = ArraySize(remove);
   int orders_size_executed = ArraySize(executed);
   
   int changed_ticket = 0;

   if(orders_size_pending > 0)
     {
      // Trade has been added
      changed_ticket+= PushOrderOpen(pending);
     }
   else if(orders_size_remove > 0)
     {
     // Trade has been closed
     changed_ticket+= PushOrderClosed(remove);
     if(changed_ticket <= 0)
       CheckOrderRemovedFromHistory(remove)? changed_ticket++ : -1;
     }
     
   ordersize = OrdersTotal();  
   if(ordersize < prev_ordersize)
      {
       // Trade has been closed manual 
       CheckOrderRemovedFromHistory(executed) ? changed_ticket++ : -1;
       // CheckOrderRemovedFromHistory(remove)? changed_ticket++ : -1;
      }
   else if(ordersize == prev_ordersize)
      {
       // Trade has been modify
       changed_ticket+= PushOrderModify(executed);
      }
   
   if(changed_ticket > 0){
      //CheckOrderRemovedFromHistory(executed) ? changed_ticket++ : -1;
      //CheckOrderRemovedFromHistory(remove)? changed_ticket++ : -1;   
   }
   return changed_ticket;
  }

//+------------------------------------------------------------------+
//| Get the order lots is greater than or less than max and min lots |
//+------------------------------------------------------------------+
double GetOrderLots(const string symbol, const double lots)
  {
   double result = lots;

   if(order_percentlots > 0)
     {
      result = lots * (order_percentlots / 100);
     }

   if(order_minlots > 0.00)
      result = (lots <= order_minlots) ? order_minlots : result;

   if(order_maxlots > 0.00)
      result = (lots >= order_maxlots) ? order_maxlots : result;

   if(order_percentlots > 0)
     {
      double s_maxlots = MarketInfo(symbol, MODE_MAXLOT);
      double s_mixlots = MarketInfo(symbol, MODE_MINLOT);

      if(result > s_maxlots)
         result = s_maxlots;

      if(result < s_mixlots)
         result = s_mixlots;
     }

   return result;
  }

//+------------------------------------------------------------------+
//| Push the open order to all of the subscriber                     |
//+------------------------------------------------------------------+
int PushOrderOpen(OrdersStruct &orders[])
  {
   int changed    = 0;
   int count = 0;
   int orders_size  = ArraySize(orders);

   do
     {
      long ticketid = FindOpenOrderByComment(orders[count].comment);

      if(ticketid == -1)
        {
         bool change = MakeOrder(orders[count].trace_id, "OPEN", orders[count].symbol, orders[count].slave_id, -1, orders[count].type, orders[count].price, 0, orders[count].lot, orders[count].stoploss, orders[count].takeprofit, orders[count].magicnumber);
         change ? (changed ++) : changed;
        }

      count++;
     }
   while(count < orders_size);
   return changed;
  }

//+------------------------------------------------------------------+
//| Push the close order to all of the subscriber                    |
//+------------------------------------------------------------------+
int PushOrderClosed(OrdersStruct &orders[])
  {
   int      changed    = 0;
   int      orderindex = 0;
   int      orders_size = ArraySize(orders);

   for(orderindex=0; orderindex<orders_size; orderindex++)
     {
      if(OrderSelect(orders[orderindex].order_id, SELECT_BY_TICKET, MODE_TRADES) == false)
         continue;

      long ticketid = OrderTicketID();            
      string comment = OrderComment();
     
      if(comment != orders[orderindex].comment)
        continue;
     
      if(ticketid != -1)
        {
          if(orders[orderindex].comment != comment)
             continue;

          bool change = MakeOrder(orders[orderindex].trace_id, "CLOSED", OrderSymbol(), orders[orderindex].order_id, -1, OrderType(), OrderOpenPrice(), 0, OrderLots(), OrderStopLoss(), OrderTakeProfit(), OrderMagicNumber());

          change ? (changed ++) : false;
        }
     }
   return changed;
  }

//+------------------------------------------------------------------+
//| Push the modify order to all of the subscriber                   |
//+------------------------------------------------------------------+
int PushOrderModify(OrdersStruct &orders[])
  {
   int changed    = 0;
   int orderindex = 0;
   int order_size = ArraySize(orders);

   for(orderindex=0; orderindex<order_size; orderindex++)
     {
      orderchanged = false;

      if(OrderSelect(orders[orderindex].order_id, SELECT_BY_TICKET, MODE_TRADES) == false)
         continue;

      long ticketid = OrderTicketID();
      
      if(ticketid != -1)
        {
         if(OrderComment() == orders[orderindex].comment)
           {
            if(CompareDoubles(OrderStopLoss(), orders[orderindex].stoploss) == false)
               orderchanged = true;

            if(CompareDoubles(OrderTakeProfit(), orders[orderindex].takeprofit)== false)
               orderchanged = true;

            if(orderchanged == true)
              {
               bool change = MakeOrder(orders[orderindex].trace_id, "MODIFY", OrderSymbol(), OrderTicketID(), -1, OrderType(), OrderOpenPrice(), OrderClosePrice(), OrderLots(), orders[orderindex].stoploss, orders[orderindex].takeprofit, OrderMagicNumber());
               change ? (changed ++) : 0;
              }
           }
        }
     }
   return changed;
  }  
  
//+------------------------------------------------------------------+
//| Check order history has removed                                  |
//+------------------------------------------------------------------+
bool CheckOrderRemovedFromHistory(OrdersStruct &orders[]){
  bool changed_ticket = false;
  int orders_size = ArraySize(orders);    
  for(int i = 0; i < orders_size; i++){
    if(OrderSelect(orders[i].order_id, SELECT_BY_TICKET, MODE_HISTORY) == false)
       continue;
    long ticketid = OrderTicketID();
    if(ticketid != -1)
     {
       string send_message = MessageSendFormat("CLOSED");
       ApiTrasmitInformation(send_message);
       changed_ticket = true;
      }
    }
  return changed_ticket;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CompareDoubles(double number1,double number2)
  {  
    bool ret;
    number1 = NormalizeDouble(number1, 6);
    number2 = NormalizeDouble(number2, 6);
   
    if(number1 == 0.0 && number2 == 0.0){
      if(  (int)MathRound((number1-number2)/100000000.0) == 0 ) 
        return(true);
      else 
      return(false); 
    } else {
      ret = number1 == number2 ? true : false;
    }
  return ret;
  }

//+------------------------------------------------------------------+
//| MQL4 -> MQL5                                                     |
//+------------------------------------------------------------------+
bool IsDemoMQL4()
  {
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO)
      return(true);
   else
      return(false);
  }

//+------------------------------------------------------------------+
