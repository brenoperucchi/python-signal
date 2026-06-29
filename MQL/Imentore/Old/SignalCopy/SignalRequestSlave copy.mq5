//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
#property version "1.48"
#property copyright   "Copyright"
#property description "Coded by Breno Perucchi"
#property strict

#define EXPERTNAME "signal_request_slave"
#define VERSION "1_48"

#define APPNAME "Signal Slave"
#define APPVERSION "1.48"

#include <MT4Orders.mqh>
#include <MQL4_to_MQL5.mqh>
#include <Trade\Trade.mqh>
#include <JAson.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input ulong  MaxSeconds              = 60;                      // Limit the maximum of seconds to open a order (Default is 60)
input double MinLots                 = 0.00;                    // Limit the minimum lots (Default is 0.00)
input double MaxLots                 = 0.00;                    // Limit the maximum lots (Default is 0.00)
input double PercentLots             = 100;                     // Lots Percent from Signal (Default is 100)
input int    Slippage                = 30;
input bool   EnvironmentLocal        = false;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool   ServerReal = false;                   // Under real server (Default is false)
string Server     = "mt5-web-replicator.example.com";

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
int MILLISECOND_TIMER = 2500;
string ACCOUNTLOGIN = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));

CTrade trade;
COrderInfo orderinfo;

//+------------------------------------------------------------------+
//| Struct Order Container                                           |
//+------------------------------------------------------------------+
struct OrdersStruct
 {
  long               type;
  long               order_id;
  long               trace_id;
  long               slave_id;
  long               magicnumber;
  long               transaction_id;
  double             price;
  double             lot;
  string             stoploss;
  string             takeprofit;
  string             state;
  string             symbol;
  string             comment;
  ulong              deal_ticket;
  ulong              seconds_ago;
 };
struct DealsStruct
 {
  string             deal_symbol;
  ulong              deal_ticket;
  long               deal_order;
  long               deal_position_id;
  int                deal_entry;
  long               deal_type;
  long               deal_datetime;
  double             deal_commission;
  double             deal_swap;
  double             deal_profit;
  double             deal_sl;
  double             deal_tp;
  double             deal_price;
  double             deal_fee;
 };

DealsStruct dealOrders[1];
//+------------------------------------------------------------------+
//|Initialisation function                                           |
//+------------------------------------------------------------------+
int OnInit()
 {
  if(DetectEnvironment() == false)
   {
    Print("Consultor Expert ", APPNAME + " " + APPVERSION, " não inicializado. Contacte o suporte.");
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
    // UpdateCurrentOrdersOnTicket();
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

  if(EnvironmentLocal)
   Server = "192.168.1.240:8080";  

  string orderdata[];
  string server_state;
  CJAVal jv;

  if(ApiRequestInformation(orderdata, "none", "stores"))
   {
    jv.Deserialize(orderdata[0]);
    server_state = jv["state"].ToStr();
    ServerReal = bool(jv["server_real"].ToInt());
   }

  if(server_state == "" || server_state != "enable")
   {
    Print("Sua conta não está habilitada em nosso sistema. Fale com o suporte");
    return false;
   }

  if(ServerReal == false && IsDemoMQL4() == false)
   {
    Print("Sua conta não está habilitada para a conta real. Fale com o suporte");
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
string MessageSendFormat(long magic_number, const string action, long order_ticket, long deal_ticket, string order_symbol, long order_type, double open_price, double close_price, double volume, string stop_loss, string take_profit,
                         double profit, string comment, double open_at, string meta_message="")
 {
  string message = StringFormat("body={'account_login':'%s', 'magic_number':'%d', 'action':'%s', 'order_ticket':'%s', 'deal_ticket':'%d', 'order_symbol':'%s', 'order_type':'%d', 'open_price':'%f', 'close_price':'%f', 'volume':'%f', 'stop_loss':'%s', 'take_profit':'%s', 'profit':'%f', 'comment':'%s', 'open_at':'%f', 'meta_message':'%s'}",
                                ACCOUNTLOGIN,
                                magic_number,
                                action,
                                IntegerToString(order_ticket),
                                deal_ticket,
                                order_symbol,
                                order_type,
                                open_price,
                                close_price,
                                volume,
                                stop_loss,
                                take_profit,
                                profit,
                                comment,
                                open_at,
                                meta_message
                               );
  return message;
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ApiTrasmitInformation(const string message)
 {
   {
    // string account_id = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
    string url="http://"+ Server +"/api/v1/transactions/trasmit/"+ EXPERTNAME +"/"+ VERSION +"/"+ ACCOUNTLOGIN;
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
bool ApiRequestInformation(string &orderdata[], const string action, const string kind)
 {
// string account_id = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
  string cookie=NULL,headers,serverHeaders;
  char   post[],result[];

  string server_url = "";
  if(kind == "orders")
    server_url = Server +"/api/v1/transactions/request/"+action;
  else
    server_url = Server +"/api/v1/stores/config";

  string url="http://"+ server_url +"/"+ EXPERTNAME +"/"+ VERSION +"/"+ ACCOUNTLOGIN;
  ResetLastError();
  int response = WebRequest("POST", url, headers, 5000, post, result, serverHeaders);

  if(response==-1)
   {
    Print("Api código de erro: ",GetLastError());
    return false;
    // MessageBox("É necessário adicionar um endereço '"+url+"' à lista de URL permitidas na guia 'Experts'","Erro",MB_ICONINFORMATION);
   }
  else
   {
    if(response==201)
     {
      string result2 = CharArrayToString(result);
      int    size = StringSplit(result2, '/', orderdata);
      return true;
     }
    else
      Print("Api código de erro: ",GetLastError(), ",  resposta: ", response);
    return false;
   }
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ApiGetOrders(OrdersStruct &executed[], OrdersStruct &pending[], OrdersStruct &remove[])
 {
  string orderdata[];
  ApiRequestInformation(orderdata, "entire", "orders");
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

    if(orderdataparse[10] == "executed")
     {
      ArrayResize(executed, size_executed+1);
      executed[size_executed].type = StringToInteger(orderdataparse[0]);
      executed[size_executed].order_id = StringToInteger(orderdataparse[1]);
      executed[size_executed].trace_id = StringToInteger(orderdataparse[2]);
      executed[size_executed].slave_id = StringToInteger(orderdataparse[3]);
      executed[size_executed].magicnumber = StringToInteger(orderdataparse[4]);
      executed[size_executed].transaction_id = StringToInteger(orderdataparse[5]);
      executed[size_executed].price = StringToDouble(orderdataparse[6]);
      executed[size_executed].lot = StringToDouble(orderdataparse[7]);
      executed[size_executed].stoploss = orderdataparse[8];
      executed[size_executed].takeprofit = orderdataparse[9];
      executed[size_executed].state = orderdataparse[10];
      executed[size_executed].symbol = orderdataparse[11];
      executed[size_executed].deal_ticket = StringToInteger(orderdataparse[12]);
      executed[size_executed].seconds_ago = StringToInteger(orderdataparse[13]);
      executed[size_executed].comment = orderdataparse[14];
      size_executed++;
     }
    if(orderdataparse[10] == "pending")
     {
      ArrayResize(pending, size_pending+1);
      pending[size_pending].type = StringToInteger(orderdataparse[0]);
      pending[size_pending].order_id = StringToInteger(orderdataparse[1]);
      pending[size_pending].trace_id = StringToInteger(orderdataparse[2]);
      pending[size_pending].slave_id = StringToInteger(orderdataparse[3]);
      pending[size_pending].magicnumber = StringToInteger(orderdataparse[4]);
      pending[size_pending].transaction_id = StringToInteger(orderdataparse[5]);
      pending[size_pending].price = StringToDouble(orderdataparse[6]);
      pending[size_pending].lot = StringToDouble(orderdataparse[7]);
      pending[size_pending].stoploss = orderdataparse[8];
      pending[size_pending].takeprofit = orderdataparse[9];
      pending[size_pending].state = orderdataparse[10];
      pending[size_pending].symbol = orderdataparse[11];
      pending[size_pending].deal_ticket = StringToInteger(orderdataparse[12]);
      pending[size_pending].seconds_ago = StringToInteger(orderdataparse[13]);
      pending[size_pending].comment = orderdataparse[14];
      size_pending++;
     }
    //ArrayFill(orderdataparse[10],i,i,orderda)
    if(orderdataparse[10] == "remove")
     {
      ArrayResize(remove, size_remove+1);
      remove[size_remove].type = StringToInteger(orderdataparse[0]);
      remove[size_remove].order_id = StringToInteger(orderdataparse[1]);
      remove[size_remove].trace_id = StringToInteger(orderdataparse[2]);
      remove[size_remove].slave_id = StringToInteger(orderdataparse[3]);
      remove[size_remove].magicnumber = StringToInteger(orderdataparse[4]);
      remove[size_remove].transaction_id = StringToInteger(orderdataparse[5]);
      remove[size_remove].price = StringToDouble(orderdataparse[6]);
      remove[size_remove].lot = StringToDouble(orderdataparse[7]);
      remove[size_remove].stoploss = orderdataparse[8];
      remove[size_remove].takeprofit = orderdataparse[9];
      remove[size_remove].state = orderdataparse[10];
      remove[size_remove].symbol = orderdataparse[11];
      remove[size_remove].deal_ticket = StringToInteger(orderdataparse[12]);
      remove[size_remove].seconds_ago = StringToInteger(orderdataparse[13]);
      remove[size_remove].comment = orderdataparse[14];
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

  for(int orderindex=0; orderindex<ordersize; orderindex++)
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
               const long deal_ticket,
               const long beforeorderid,
               const long type,
               const double openprice,
               const double closeprice,
               const double lots,
               const string sl,
               const string tp,
               const long magicnumber,
               const string comment)
 {
  if(login <= 0 || symbol == "" || orderid == 0)
    return false;

  long    ticketid    = -1;
//string comment     = StringFormat("%d|%d", login, orderid);
  bool orderstatus = false;

  Print("MakeOrder Operation:", op, ", Symbol:", symbol, ", Type:", type, ", TicketId:", orderid, " Comment:", comment);
  if(op == "OPEN")
   {

    if(ticketid <= 0)
     {
      ticketid = MakeOrderOpen(symbol, type, openprice, lots, sl, tp, comment, magicnumber);

      if(ticketid > 0)
       {
        orderstatus = true;
        // Print("Order Status:", op, ", Open:", symbol, ", Type:", type, ", TicketId:", ticketid);
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
          // Print("Order Status:", op, ", Closed:", symbol, ", Type:", type, ", TicketId:", ticketid);
          orderstatus = true;
          if(OrderSelect(ticketid, SELECT_BY_TICKET, MODE_TRADES) == true)
           {
            string message_format = MessageSendFormat(magicnumber, "CLOSED", ticketid, deal_ticket, symbol, type, OrderOpenPrice(), OrderClosePrice(), lots, sl, tp, OrderProfit(), comment, OrderOpenTime());
            ApiTrasmitInformation(message_format);
           }
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
            // Print("Order Status:", op, ", Modify:", symbol, ", Type:", type, ", TicketId:", ticketid);
            orderstatus = true;
            if(OrderSelect(ticketid, SELECT_BY_TICKET, MODE_TRADES) == true)
             {
              string message_format = MessageSendFormat(magicnumber, "MODIFY", ticketid, deal_ticket, symbol, type, OrderOpenPrice(), 0, lots, sl, tp, 0, comment, OrderOpenTime());
              ApiTrasmitInformation(message_format);
             }
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
                   string vsl,
                   string vtp,
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
    SymbolInfoTick(symbol,last_tick);
    if(vtype == 0)
      vprice = last_tick.ask;
    if(vtype == 1)
      vprice = last_tick.bid;
   }

  double sl = calculatePips(vprice, vsl, vtype, symbol, "sl");
  double tp = calculatePips(vprice, vtp, vtype, symbol, "tp");

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
  MqlTradeRequest request= {};
  MqlTradeResult  result= {};
  request.symbol   =symbol;                                 // símbolo
  request.volume   =vlots;                                  // volume de 0.2 lotes
  request.price    =vprice;                                 // preço para a abertura
  request.deviation=5;                                      // desvio permitido do preço
  request.magic    =magicnumber;                            // MagicNumber da ordem
  request.sl       =sl;
  request.tp       =tp;
  request.comment  =comment;


  switch(int(vtype))
   {
    case 0:
      request.action   = TRADE_ACTION_DEAL;                        // tipo de operação de negociação
      request.type     = ORDER_TYPE_BUY;                           // tipo da ordem
      break;
    case 1:
      request.action   = TRADE_ACTION_DEAL;                        // tipo de operação de negociação
      request.type     = ORDER_TYPE_SELL;                          // tipo da ordem
      break;
    case 2:
      request.action   = TRADE_ACTION_PENDING;                     // tipo de operação de negociação
      request.type     = ORDER_TYPE_BUY_LIMIT;                     // tipo da ordem
      request.type_filling = ORDER_FILLING_FOK;
      request.type_time = ORDER_TIME_DAY;
      request.price    = openprice;                                // preço para a abertura
      break;
    case 3:
      request.action   = TRADE_ACTION_PENDING;                     // tipo de operação de negociação
      request.type     = ORDER_TYPE_SELL_LIMIT;                      // tipo da ordem
      request.type_filling = ORDER_FILLING_FOK;
      request.type_time = ORDER_TIME_DAY;
      request.price    = openprice;                                // preço para a abertura

      break;
    case 4:
      request.action   = TRADE_ACTION_PENDING;                     // tipo de operação de negociação
      request.type     = ORDER_TYPE_BUY_STOP;                    // tipo da ordem
      request.type_filling = ORDER_FILLING_RETURN;
      request.type_time = ORDER_TIME_DAY;
      request.price    = openprice;                                // preço para a abertura
      request.stoplimit = 0;
      break;
    case 5:
      request.action   = TRADE_ACTION_PENDING;                     // tipo de operação de negociação
      request.type     = ORDER_TYPE_SELL_STOP;                     // tipo da ordem
      request.type_filling = ORDER_FILLING_RETURN;
      request.type_time = ORDER_TIME_DAY;
      request.price    = openprice;                                // preço para a abertura
      request.stoplimit = 0;
      break;
    case 6:
      request.action   = TRADE_ACTION_PENDING;                     // tipo de operação de negociação
      request.type     = ORDER_TYPE_BUY_STOP_LIMIT;                // tipo da ordem
      request.type_filling = ORDER_FILLING_FOK;
      request.type_time = ORDER_TIME_DAY;
      request.price    = openprice;                                // preço para a abertura
      break;
    case 7:
      request.action   = TRADE_ACTION_PENDING;                     // tipo de operação de negociação
      request.type     = ORDER_TYPE_SELL_STOP_LIMIT;                // tipo da ordem
      request.type_filling = ORDER_FILLING_FOK;
      request.type_time = ORDER_TIME_DAY;
      request.price    = openprice;                                // preço para a abertura
      break;

   }

  string api_data_message;
  string meta_message;
  bool order_send = OrderSend(request,result);

  if(!order_send && result.retcode == 10016)
   {
    meta_message = StringFormat("OrderSend error: %d | Retcode: %u | Error message: %s | Comment: %s",GetLastError(),result.retcode, result.comment, comment);     // se não for possível enviar o pedido, exibir um código de erro
    api_data_message = MessageSendFormat(magicnumber, "NOSLTP", result.order, result.deal, symbol, vtype, request.price, 0, vlots, DoubleToString(sl), DoubleToString(tp), 0, comment, OrderOpenTime(), meta_message);
    ApiTrasmitInformation(api_data_message);
    Print(meta_message);

    if(vtype == 0 || vtype == 1)
     {
      request.sl       =0;
      request.tp       =0;
      order_send = OrderSend(request,result);
     }
   }
  if(order_send)
   {
    meta_message = StringFormat("OrderSend Done | Retcode: %u | Deal: %I64u | Order: %I64u | Comment: %s",result.retcode,result.deal,result.order,comment);
    api_data_message = MessageSendFormat(magicnumber, "OPENED", result.order, result.deal, symbol, vtype, request.price, 0, vlots, DoubleToString(request.sl), DoubleToString(request.tp), 0, comment, OrderOpenTime(), meta_message);
    ApiTrasmitInformation(api_data_message);
    Print(meta_message);
   }
  else
   {
    meta_message = StringFormat("OrderSend error: %d | Retcode: %u | Error message: %s | Comment: %s",GetLastError(),result.retcode, result.comment, comment);     // se não for possível enviar o pedido, exibir um código de erro
    api_data_message = MessageSendFormat(magicnumber, "ERRORDEAL", result.order, result.deal, symbol, vtype, request.price, 0, vlots, DoubleToString(request.sl), DoubleToString(request.tp), 0, comment, OrderOpenTime(), meta_message);
    ApiTrasmitInformation(api_data_message);
    Print(meta_message);
   }
  ticketid = long(result.order);
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
                    const string sl,
                    const string tp)
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
      case ORDER_TYPE_BUY_LIMIT:
      case ORDER_TYPE_BUY_STOP:
      case ORDER_TYPE_BUY_STOP_LIMIT:
      case ORDER_TYPE_SELL_LIMIT:
      case ORDER_TYPE_SELL_STOP:
      case ORDER_TYPE_SELL_STOP_LIMIT:
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
                     const string vsl,
                     const string vtp)
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
    double sl = StringToDouble(vsl);
    double tp = StringToDouble(vtp);
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
  else
    if(orders_size_remove > 0)
     {
      // Trade has been closed
      changed_ticket+= PushOrderClosed(remove);
      if(changed_ticket <= 0)
        CheckOrdersRemovedFromHistory(remove)? changed_ticket++ : -1;
     }

  ordersize = OrdersTotal();
  if(ordersize < prev_ordersize)
   {
    // Trade has been closed manual
    CheckOrdersRemovedFromHistory(executed) ? changed_ticket++ : -1;
    // CheckOrdersRemovedFromHistory(remove)? changed_ticket++ : -1;
   }
  else
    if(ordersize == prev_ordersize)
     {
      // Trade has been modify
      changed_ticket+= PushOrderModify(executed);
     }

  return changed_ticket;
 }

//+------------------------------------------------------------------+
//| Update all of the orders status                                  |
//+------------------------------------------------------------------+
void UpdateCurrentOrdersOnTicket(long ticket)
 {
  dealOrders[0].deal_ticket      = ticket;
  dealOrders[0].deal_symbol      = HistoryDealGetString(ticket,DEAL_SYMBOL);
  dealOrders[0].deal_order       = HistoryDealGetInteger(ticket,DEAL_ORDER);
  dealOrders[0].deal_position_id = HistoryDealGetInteger(ticket,DEAL_POSITION_ID);
  dealOrders[0].deal_entry       = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket,DEAL_ENTRY);
  dealOrders[0].deal_type        = HistoryDealGetInteger(ticket,DEAL_TYPE);
  dealOrders[0].deal_datetime    = HistoryDealGetInteger(ticket,DEAL_TIME);
  dealOrders[0].deal_profit      = HistoryDealGetDouble(ticket,DEAL_PROFIT);
  dealOrders[0].deal_price       = HistoryDealGetDouble(ticket,DEAL_PRICE);
  dealOrders[0].deal_sl          = HistoryDealGetDouble(ticket,DEAL_SL);
  dealOrders[0].deal_tp          = HistoryDealGetDouble(ticket,DEAL_TP);
  dealOrders[0].deal_commission  = HistoryDealGetDouble(ticket,DEAL_COMMISSION);
  dealOrders[0].deal_fee         = HistoryDealGetDouble(ticket,DEAL_FEE);
  dealOrders[0].deal_swap        = HistoryDealGetDouble(ticket,DEAL_SWAP);
 }

//+------------------------------------------------------------------+
//| Get the order lots is greater than or less than max and min lots |
//+------------------------------------------------------------------+
double GetOrderLots(const string symbol, double lots)
 {
  lots = MathAbs(lots);
  double result = MathAbs(lots);

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

      if(orders[count].seconds_ago < MaxSeconds){
        bool change = MakeOrder(orders[count].trace_id, "OPEN", orders[count].symbol, orders[count].slave_id, orders[count].deal_ticket, -1, orders[count].type, orders[count].price, 0, orders[count].lot, orders[count].stoploss, orders[count].takeprofit, orders[count].magicnumber, orders[count].comment);
        change ? (changed ++) : changed;
      } else {
        Print("Operation(TimeMax):", "OPEN", ", Symbol:", orders[count].symbol, ", Type:", orders[count].type, ", TicketId:", ticketid, " Comment:", orders[count].comment);
        string message_format = MessageSendFormat(orders[count].magicnumber, "TIMEMAX", orders[count].order_id, orders[count].deal_ticket, orders[count].symbol, orders[count].type, orders[count].price, 0, orders[count].lot, orders[count].stoploss, orders[count].stoploss, 0, orders[count].comment, 0);
        ApiTrasmitInformation(message_format);
      }
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
  int      orders_size = ArraySize(orders);

  for(int i=0; i<orders_size; i++)
   {
    ulong ticket = orders[i].order_id;
    ulong ticketid;
    string comment;
    long vtype;

    if(OrderSelect(ticket) || PositionSelectByTicket(ticket))
     {
      if(OrderSelect(ticket))
       {
        ticketid = OrderGetInteger(ORDER_TICKET);
        comment = OrderGetString(ORDER_COMMENT);
        vtype = OrderGetInteger(ORDER_TYPE);
       }
      else
       {
        ticketid = PositionGetInteger(POSITION_TICKET);
        comment = PositionGetString(POSITION_COMMENT);
        vtype = PositionGetInteger(POSITION_TYPE);
       }

      if(orders[i].state != "remove")
        continue;

      if(comment != orders[i].comment)
        continue;

      if(ticketid != -1)
       {
        bool change = MakeOrder(orders[i].trace_id, "CLOSED", orders[i].symbol, orders[i].order_id, orders[i].deal_ticket, -1, vtype, orders[i].price, 0, orders[i].lot, orders[i].stoploss, orders[i].takeprofit, orders[i].magicnumber, orders[i].comment);
        change ? (changed ++) : false;
       }
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
  int order_size = ArraySize(orders);

  for(int i=0; i<order_size; i++)
   {
    orderchanged = false;
    long ticketid = orders[i].order_id;
    //int position_id;

    if(CheckOrderRemovedFromHistory(ticketid, orders[i]))
      continue;
      
    if(!PositionSelectByTicket(ticketid))
      continue;    

    string comment = PositionGetString(POSITION_COMMENT);

    if(ticketid != -1)
     {
      if(comment == orders[i].comment)
       {
        if(CompareDoubles(PositionGetDouble(POSITION_SL), StringToDouble(orders[i].stoploss)))
          orderchanged = true;

        if(CompareDoubles(PositionGetDouble(POSITION_TP), StringToDouble(orders[i].takeprofit)))
          orderchanged = true;

        if(orderchanged == true)
         {
          bool change = MakeOrder(orders[i].trace_id, "MODIFY", orders[i].symbol, ticketid, orders[i].deal_ticket, -1, orders[i].type, orders[i].price, 0, orders[i].lot, orders[i].stoploss, orders[i].takeprofit, orders[i].magicnumber, orders[i].comment);
          change ? (changed ++) : 0;
         }
       }
     }
   }
  return changed;
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong CheckTicketOnHistory(long ticketid)
 {
  ulong changed = 0;
  HistorySelectByPosition(ticketid);
  for(int i=HistoryOrdersTotal(); i>0; i--)
   {
    ulong deal_ticket = HistoryDealGetTicket(i);
    int entry_type=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket,DEAL_ENTRY);
    if(entry_type==DEAL_ENTRY_OUT)
     {

      changed = deal_ticket;
     }
   }
  return changed;
 }

//+------------------------------------------------------------------+
//| Check order history has removed                                  |
//+------------------------------------------------------------------+
bool CheckOrdersRemovedFromHistory(OrdersStruct &orders[])
 {
  bool changed = false;
  int orders_size = ArraySize(orders);
  for(int i = 0; i < orders_size; i++)
   {
    if(CheckOrderRemovedFromHistory(orders[i].order_id, orders[i]))
      changed = true;
   }
  return changed;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckOrderRemovedFromHistory(long ticketid, OrdersStruct &order)
 {
  bool changed = false;
  ulong deal_ticket = CheckTicketOnHistory(ticketid);

  if(bool(deal_ticket))
    UpdateCurrentOrdersOnTicket(deal_ticket);
  else
    return changed;

  if(PositionSelectByTicket(ticketid))
    return changed;

  double  deal_profit      = dealOrders[0].deal_profit;
  long    deal_time        = dealOrders[0].deal_datetime;
  long    deal_position_id = dealOrders[0].deal_position_id;
  string  history_comment  = HistoryOrderGetString(ticketid, ORDER_COMMENT);

  if(history_comment == order.comment)
   {
    Print("CheckOrder Operation:", "CLOSED", ", Symbol:", order.symbol, ", Type:", order.type, ", TicketId:", ticketid, " Comment:", order.comment);
    string message_format = MessageSendFormat(order.magicnumber, "CLOSED", order.order_id, order.deal_ticket, order.symbol, order.type, order.price, dealOrders[0].deal_price, order.lot, DoubleToString(dealOrders[0].deal_sl), DoubleToString(dealOrders[0].deal_tp), deal_profit, order.comment, deal_time);
    ApiTrasmitInformation(message_format);
    changed = true;
   }
  return changed;
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CompareDoubles(double number1,double number2)
 {
  bool ret;
  number1 = NormalizeDouble(number1, 6);
  number2 = NormalizeDouble(number2, 6);

  if(number1 == 0.0 && number2 == 0.0)
   {
    if((int)MathRound((number1-number2)/100000000.0) == 0)
      return(false);
    else
      return(true);
   }
  else
   {
    ret = number1 != number2 ? true : false;
   }
  return ret;
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculatePips(double vprice, string snumber, long vtype, string symbol, string kind)
 {

  int    vdigits = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  double vpoint  = SymbolInfoDouble(symbol, SYMBOL_POINT);
  double number = StringToDouble(snumber);

  if(StringFind(snumber,".") == -1)
   {
    //vprice = NormalizeDouble(vprice, vdigits-1);
    if(vdigits == 2)
      vpoint = 0.1;
    else
      if(vdigits == 3)
        vpoint = 0.01;
      else
        if(vdigits >= 4)
          vpoint = 0.0001;

    float mod = 1;

    if(vtype == 0 || vtype == 2 || vtype == 4 || vtype == 6)
      number = NormalizeDouble(vprice-number*mod*vpoint, vdigits);
    else
     {
      if(kind == "tp")
        mod = -1;
      number = NormalizeDouble(vprice+number*mod*vpoint, vdigits);
     }
   }
  return number;
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
