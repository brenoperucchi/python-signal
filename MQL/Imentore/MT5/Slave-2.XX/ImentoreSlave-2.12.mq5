//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
#property version "2.12"
#property copyright   "Copyright"
#property description "Coded by Breno Perucchi"
#property strict

#define EXPERTNAME "imentore_slave"
#define VERSION "2_12"

#define APPNAME "Imentore Slave"
#define APPVERSION "2.12"

#include <MT4Orders.mqh>
#include <MQL4_to_MQL5.mqh>
#include <Trade\Trade.mqh>
#include <JAson.mqh>
// #include <math_utils.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input ulong  MaxSeconds              = 30;                      // Limit the maximum of seconds to open a order (Default is 60)
input double MinLots                 = 0.00;                    // Limit the minimum lots (Default is 0.00)
input double MaxLots                 = 0.00;                    // Limit the maximum lots (Default is 0.00)
input double PercentLots             = 100;                     // Lots Percent from Signal (Default is 100)
input int    Slippage                = 30;
input bool   EnvironmentLocal        = false;
bool   EnvironmentTest         = false;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string ACCOUNTLOGIN            = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
string API_VERSION             = "v2";
int    MILLISECOND_TIMER       = 1600;
string ACCOUNT_SERVER_NAME     = "";

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

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

string store_state;
string store_message;
string account_state;
string account_margin_mode;
string account_mode;                // Under real server (Default is false)
string api_server_hostname;
int timecurrent = int(TimeCurrent());

string commentOnChart[];
long comment_mfe_mae_line_item = 0;
long commentLineItemMakeOrder = 0;
long commentLineItemOrderModify = 0;
long commentLineItemServerStatus = 0;
long commentLineItemServerStatusError = 0;
string comment_order_status;
string comment_order_ticket;

CTrade trade;
CJAVal jv;

//+------------------------------------------------------------------+
//| Struct Order Container                                           |
//+------------------------------------------------------------------+
struct OrderStruct
 {
  long               type;
  long               ticket_master;
  long               ticket_slave;
  long               trace_id;
  long               slave_id;
  long               magicnumber;
  long               transaction_id;
  double             profit;
  double             price_open;
  double             price_close;
  double             lot;
  double             stop_loss;
  double             take_profit;
  string             state;
  string             symbol;
  string             comment;
  ulong              deal_ticket;
  ulong              seconds_ago;
  string             open_at;
 };

//+------------------------------------------------------------------+
//|Initialisation function                                           |
//+------------------------------------------------------------------+
int OnInit()
 {
  string message = StringFormat("Iniciando Expert %s %s ", APPNAME, APPVERSION);
  AddCommentOnChart(message);

  EventSetMillisecondTimer(MILLISECOND_TIMER);     // Set Millisecond Timer to get client socket input
  ACCOUNT_SERVER_NAME     = RemoveSpecialChars(AccountInfoString(ACCOUNT_SERVER));

  if(DetectEnvironment() == false)
   {
    Print("Expert ", APPNAME + " " + APPVERSION, " não inicializado. Contacte o suporte.");
    string comment = ("Expert "+ APPNAME + " " + APPVERSION + " não inicializado. Contacte o suporte.");
    AddCommentOnChart(comment);

    return(INIT_FAILED);
   }
  else
   {
    Print("Expert ", APPNAME + " " + APPVERSION, " inicializado com sucesso.");
    string comment = ("Expert " + APPNAME + " " + APPVERSION + " inicializado com sucesso.");
    AddCommentOnChart(comment);

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
  
  changed = OrdersExecute();

  if(changed > 0)
    prev_ordersize = ordersize;

// Loop for 60 seconds
  int timeago = int(TimeCurrent() - timecurrent);
  if(timeago > 60)
   {
    if(CheckServerInformations() == false)
      ExpertRemove();
    timecurrent = int(TimeCurrent());
   }
 }

//+------------------------------------------------------------------+
//|Deinitialisation function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
 {
  EventKillTimer();
  return;
 }

//+------------------------------------------------------------------+
//| Check Store Conditions                                           |
//+------------------------------------------------------------------+
bool CheckServerInformations()
{

  bool changes = true;
  string orderdata[];

  if(ApiRequestInformation(orderdata, "store"))
   {
    jv.Deserialize(orderdata[0]);
    store_state = jv["store_state"].ToStr();
    store_message = jv["store_message"].ToStr();
    account_state = jv["account_state"].ToStr();                    // enable/disable
    account_mode = jv["account_mode"].ToStr();                    // demo/real
    account_margin_mode = jv["account_margin_mode"].ToStr();        // hedging/netting
    api_server_hostname = jv["api_server_hostname"].ToStr();        // server api
    
   }
  else
   {
    changes = false;
   }

  if(StringLen(store_message) > 0)
   {
    Print(store_message);
    AddCommentOnChart(store_message);
    changes = false;
   }

  if(store_state == "" || store_state != "enable")
   {
    Print("Sua conta está desabilitada em nosso sistema. Fale com o suporte");
    string comment = ("Sua conta está desabilitada em nosso sistema. Fale com o suporte");
    AddCommentOnChart(comment);

    changes = false;
   }

  if(account_mode == "demo" && IsDemoMQL4() == false)
   {
    Print("Seu acesso é somente para conta demo. Fale com o suporte");
    string comment = ("Seu acesso é somente para conta demo. Fale com o suporte");
    AddCommentOnChart(comment);
    changes = false;
   }

  if(account_state == "disable")
   {
    Print("Sua conta está desabilitada em nosso sistema. Fale com o suporte");
    string comment = ("Sua conta está desabilitada em nosso sistema. Fale com o suporte");
    AddCommentOnChart(comment);
    changes = false;
   }
  if(account_margin_mode == "hedging" && AccountMarginMode() == "NETTING")
   {
    Print("Sua conta está habilitada para modo HEDGE em nosso sistema, porém conta na corretora está configurada para modo NETTING. Efetue a mudança com a sua corretora.");
    string comment = ("Sua conta está habilitada para modo HEDGE em nosso sistema, porém conta na corretora está configurada para modo NETTING. Efetue a mudança com a sua corretora.");
    AddCommentOnChart(comment);

    changes = false;
   }
  if(account_margin_mode == "netting" && AccountMarginMode() == "HEDGING")
   {
    Print("Sua conta está habilitada para modo NETTING em nosso sistema, porém a conta na corretora está configurada para modo HEDGE. Efetue a mudança com a sua corretora.");
    string comment = ("Sua conta está habilitada para modo NETTING em nosso sistema, porém a conta na corretora está configurada para modo HEDGE. Efetue a mudança com a sua corretora.");
    AddCommentOnChart(comment);

    changes = false;
   }

  if(changes == false){
    Alert("Settings Errors - Expert disable");
    string comment = ("Settings Errors - Expert disable");
    AddCommentOnChart(comment);
   }

  return changes;
 }

//+------------------------------------------------------------------+
//| Detect the script parameters                                     |
//+------------------------------------------------------------------+
bool DetectEnvironment()
 {

  if(EnvironmentLocal)
    Server = "localhost:80";

  if(CheckServerInformations() == false)
    return false;

  order_minlots = MinLots;
  order_maxlots = MaxLots;
  order_percentlots = (order_percentlots > 0) ? PercentLots : 100;
  order_slippage = Slippage;
  prev_ordersize = OrdersTotal();

  return true;
 }

//+------------------------------------------------------------------+
//| Get all of the orders                                            |
//+------------------------------------------------------------------+
int OrdersExecute()
 {
  OrderStruct orders[];
  UpdateOrderStruct(orders);
  int orders_size = ArraySize(orders);
  int changed_ticket = 0;

  for(int i = 0; i < orders_size; i++)
   {
    if(orders[i].state == "pending")
      changed_ticket = PushOrderOpen(orders[i]);
    else
      if(orders[i].state == "executed")
        changed_ticket += PushOrderModify(orders[i]);
      // else if(ticketid > 0 && orders[i].state == "remove")
      else
        if(orders[i].state == "remove")
          changed_ticket += PushOrderClosed(orders[i]);
   }

  CheckOrdersClosed(orders);

  return changed_ticket;
 }

//+------------------------------------------------------------------+
//| Push the open order to all of the subscriber                     |
//+------------------------------------------------------------------+
int PushOrderOpen(OrderStruct &order)
 {
  int changed    = 0;
  int count = 0;

  long ticketid = FindOpenOrderByComment(order.comment);

  if(ticketid != -1 && order.state == "pending")
   {
    string meta_message = StringFormat("Operation(AlreadyOpened) | OPEN | Symbol: %s | Type: %d | Ticket Master: %d | Ticket Slave: %d | Comment: %s", order.symbol, order.type, order.ticket_master, ticketid, order.comment);
    Print(meta_message);
    string message_format = MessageSendFormat(order.magicnumber, "OPEN", order.state, "OPEN", ticketid, order.deal_ticket, order.symbol, order.type, OrderOpenPrice(), 0, order.lot, OrderStopLoss(), OrderTakeProfit(), "0", order.comment, DoubleToStr(OrderOpenTime()), meta_message);
    ApiTrasmitInformation(message_format, "OPENED");

   }
  else
    if(order.seconds_ago < MaxSeconds)
     {
      bool change = MakeOrder(order, "OPEN");
      change ? (changed ++) : changed;
     }
    else
     {
      string meta_message = StringFormat("Operation(TimeMax) | OPEN | Symbol: %s | Type: %d | Ticket Master: %d | Ticket Slave: %d | Comment: %s | OrderTime %d < %d TimeMax", order.symbol, order.type, order.ticket_master, order.ticket_slave, order.comment, order.seconds_ago, MaxSeconds);
      Print(meta_message);
      string message_format = MessageSendFormat(order.magicnumber, "OPEN", order.state, "TIMEMAX", order.ticket_slave, order.deal_ticket, order.symbol, order.type, order.price_open, 0, order.lot, order.stop_loss, order.take_profit, "0" , order.comment, "0", meta_message);
      ApiTrasmitInformation(message_format, "TIMEMAX");
     }
  return changed;
 }

//+------------------------------------------------------------------+
//| Push the modify order to all of the subscriber                   |
//+------------------------------------------------------------------+
int PushOrderModify(OrderStruct &order)
 {
  int changed    = 0;
  orderchanged = false;
  string order_string_changed = "";

  long ticketid = FindOpenOrderByComment(order.comment);

  bool position = PositionSelectByTicket(ticketid);
  bool ordered = OrderSelect(ticketid);

  string comment = PositionGetString(POSITION_COMMENT);

  if(ticketid != -1)
   {
    if(comment == order.comment)
     {
      if(CompareDoubles(PositionGetDouble(POSITION_SL), order.stop_loss)){
        orderchanged = true;
        order_string_changed += AttributeChangeString("stop_loss", PositionGetDouble(POSITION_SL), order.stop_loss);
      }

      if(CompareDoubles(PositionGetDouble(POSITION_TP), order.take_profit)){
        orderchanged = true;
        order_string_changed += AttributeChangeString("stop_loss", PositionGetDouble(POSITION_TP), order.take_profit); 
      }

      double lot = PositionGetDouble(POSITION_VOLUME);

      if(CompareDoubles(lot, order.lot)){
        orderchanged = true;
        order_string_changed += AttributeChangeString("volume", lot, order.lot);
      }

      if(CompareDoubles(lot, order.lot))
       {
        //double volume_change = order.lot - lot;
        //order.lot = volume_change;
        // bool change = MakeOrder(order.trace_id, "MODIFY_VOLUME", order.symbol, order.ticket_master, ticketid, order.deal_ticket, -1, order.type, order.price, 0, volume_change, order.stop_loss, order.take_profit, order.magicnumber, order.comment, order.state);
        bool change = MakeOrder(order, "MODIFY_VOLUME");
        change ? (changed ++) : 0;
       }

      if(orderchanged == true)
      {
        bool change = MakeOrder(order, "MODIFY");
        if(change){
          comment_order_status = ("\nPush Order Modify - Ticket: " + IntegerToString(ticketid) +", Symbol: " + PositionGetString(POSITION_SYMBOL) + ", Type: " + IntegerToString(PositionGetInteger(POSITION_TYPE)) + " TicketDealID: " + IntegerToString(ticketid));
          Print(comment_order_status);
          comment_order_status = "\nOrder Changed: " + order_string_changed;
          Print(comment_order_status);
          commentLineItemOrderModify = AddCommentOnChart(comment_order_status, commentLineItemOrderModify);
          
          changed ++;
        }
      }
    }
  }
  else
    if(FindCloseOrderByComment(order.comment) && order.state == "executed")
      PushOrderClosed(order);
//}
  return changed;
 }

//+------------------------------------------------------------------+
//| Push the close order to all of the subscriber                    |
//+------------------------------------------------------------------+
int PushOrderClosed(OrderStruct &order)
 {
  int    changed  = 0;
  changed = MakeOrder(order, "CLOSED");

  return changed;
 }

//+------------------------------------------------------------------+
//| Make a order by signal message (Market and Pending Order)        |
//+------------------------------------------------------------------+
bool MakeOrder(OrderStruct &order, const string action)
{
  long ticketid    = order.ticket_slave;
  bool orderstatus = false;
  bool select = SymbolSelect(order.symbol, true);

  // if(login <= 0 || symbol == "")
  if(order.trace_id <= 0 || order.symbol == "")
    return false;

  MqlTradeResult  result = {};
  MqlTradeRequest request = {};
  ZeroMemory(request);
  ZeroMemory(result);
  ResetLastError();

  comment_order_status = "\nMake Order : " + action + ", Symbol: " + order.symbol + ", Type: " + IntegerToString(order.type) + ", TicketID: " + IntegerToString(ticketid) + ", Comment: " + order.comment;
  Print(comment_order_status);
  
  commentLineItemMakeOrder = AddCommentOnChart(comment_order_status, commentLineItemMakeOrder);

  if(action == "OPEN")
   {

    if(ticketid <= 0)
     {
      ticketid = MakeOrderOpen(order.symbol, order.type, order.price_open, order.lot, order.stop_loss, order.take_profit, order.comment, order.magicnumber, order.state, action);

      if(ticketid > 0)
       {
        orderstatus = true;
       }
     }
   }
  else
    if(action == "CLOSED")
     {
      if(ticketid > 0)
      {
        orderstatus = MakeOrderClose(result, request, order, action);
        if(orderstatus){
          order.price_close = result.price;
          SendMessageToServer(result, request, order, action, order.state, "CLOSED");
        }
      }
      if(FindOpenOrderByComment(order.comment) == -1 && FindCloseOrderByTicketId(order.ticket_slave) == -1)
        SendMessageToServer(result, request, order, action, order.state, "NOTFIND");
     }
    else
      if(action == "MODIFY")
       {
        if(ticketid > 0)
         {
          orderstatus = MakeOrderModify(order.ticket_slave, order.symbol, order.price_open, order.stop_loss, order.take_profit, action);

          if(orderstatus > 0)
           {
            orderstatus = true;
            if(OrderSelect(ticketid, SELECT_BY_TICKET, MODE_TRADES) == true)
             {
              string message_format = MessageSendFormat(order.magicnumber, action,  order.state, "MODIFY", order.ticket_slave, order.deal_ticket, order.symbol, order.type, order.price_open, order.price_close, order.lot, order.stop_loss, order.take_profit, DoubleToString(order.profit), order.comment, order.open_at);
              ApiTrasmitInformation(message_format, "MODIFY");
             }
           }
         }
       }
   if(action == "MODIFY_VOLUME")
   {
    if(ticketid > 0)
     {
      orderstatus = MakeOrderModifyVolume(order.ticket_slave, order.symbol, order.price_open, order.stop_loss, order.take_profit, order.lot, order.state, action);
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
                   double vsl,
                   double vtp,
                   const string comment,
                   const long magicnumber,
                   const string state,
                   const string action)
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
    SymbolInfoTick(symbol, last_tick);
    if(vtype == 0)
      vprice = SymbolInfoDouble(symbol, SYMBOL_ASK);
    if(vtype == 1)
      vprice = SymbolInfoDouble(symbol, SYMBOL_BID);
   }

//double sl = NormalizeNumber(vsl, symbol);
//double tp = NormalizeNumber(vsl, symbol);

//vprice = GetRandomPrice(symbol, vtype);  // open price
  double sl = calculatePips(vprice, DoubleToStr(vsl), vtype, symbol, "sl");
  double tp = calculatePips(vprice, DoubleToStr(vtp), vtype, symbol, "tp");

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
  MqlTradeRequest request = {};
  MqlTradeResult  result = {};
  request.symbol   = symbol;                                // símbolo
  request.volume   = vlots;                                 // volume de 0.2 lotes
  request.price    = vprice;                                // preço para a abertura
  request.deviation = 5;                                    // desvio permitido do preço
  request.magic    = magicnumber;                           // MagicNumber da ordem
  request.sl       = sl;
  request.tp       = tp;
  request.comment  = comment;


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

  OrderCreate(result, request, state, action);
  ticketid = long(result.order);
  return ticketid;
 }

//+------------------------------------------------------------------+
//| Make a order close by signal message                             |
//+------------------------------------------------------------------+
long MakeOrderClose(MqlTradeResult &result,
                    MqlTradeRequest &request,
                    OrderStruct &order,
                    string action)
 {
  long close_result = 0;

// Allow signal to close the order
// The parameter ticketid must be greater than zero
  if(order_allowclose == false || order.ticket_slave <= 0)
    return close_result;

// Allow Expert Advisor to close the order
  if(IsTradeAllowed() == false)
    return close_result;

  if(OrderSelect(order.ticket_slave, SELECT_BY_TICKET, MODE_TRADES) == true)
   {
    //double price  = order.price_close;

    //if(price_close <= 0.00)
    //  price = SymbolInfoDouble(symbol, SYMBOL_ASK);

    switch(int(order.type))
     {
      case ORDER_TYPE_BUY_LIMIT:
      case ORDER_TYPE_BUY_STOP:
      case ORDER_TYPE_BUY_STOP_LIMIT:
      case ORDER_TYPE_SELL_LIMIT:
      case ORDER_TYPE_SELL_STOP:
      case ORDER_TYPE_SELL_STOP_LIMIT:
        close_result = OrderDelete(order.ticket_slave);
        break;

      default:
        request.action    = TRADE_ACTION_DEAL;        // type of trade operation
        request.position  = order.ticket_slave;          // ticket of the position
        request.symbol    = order.symbol;          // symbol
        request.volume    = PositionGetDouble(POSITION_VOLUME);                   // volume of the position
        request.deviation = 30;                        // allowed deviation from the price
        request.comment   = order.comment;
        request.magic     = order.magicnumber;
        request.type_filling = ORDER_FILLING_IOC;         

        //--- set the price and order type depending on the position type
        if(order.type == POSITION_TYPE_BUY)
         {
          request.price = SymbolInfoDouble(order.symbol, SYMBOL_BID);
          request.type = ORDER_TYPE_SELL;
         }
        else
         {
          request.price = SymbolInfoDouble(order.symbol, SYMBOL_ASK);
          request.type = ORDER_TYPE_BUY;
         }
        //--- output information about the closure
        PrintFormat("Close #%I64d %s %d", order.ticket_slave, order.symbol, order.type);
        //--- send the request
        if(FindCloseOrderByTicketId(order.ticket_slave) > 0){
          result.retcode = 10009;
          result.comment = "Manual Closed";
          result.order   = order.ticket_slave;
          result.price   = OrderClosePrice();
          result.deal    = order.deal_ticket;
          close_result++;
        } 
        else if(OrderSend(request, result))
          // PrintFormat("OrderSend error %d", GetLastError()); // if unable to send the request, output the error code
          close_result++;
        PrintFormat("Action: %s | Symbol: %s | TransactionID: %d | Ticket Master: %d | Ticket Slave: %s | Type: %d | LastError: %d | Result Code: %u | Result Comment: %s", action, order.symbol, order.transaction_id, order.ticket_master, order.comment, order.type, GetLastError(), result.retcode, result.comment);     // se não for possível enviar o pedido, exibir um código de erro

     }
   }
  return close_result;
 }

//+------------------------------------------------------------------+
//| Make a order modify by signal message                            |
//+------------------------------------------------------------------+
long MakeOrderModify(const long ticketid,
                     const string symbol,
                     const double openprice,
                     const double vsl,
                     const double vtp,
                     const string op)
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
    double sl = vsl;
    double tp = vtp;
    result = OrderModify(ticketid, openprice, sl, tp, 0, clrYellow);
    result ? result++ : -1;
   }
  return result;
 }
//+------------------------------------------------------------------+
//| Make a order modify by signal message                            |
//+------------------------------------------------------------------+
long MakeOrderModifyVolume(const long ticketid,
                           const string symbol,
                           const double openprice,
                           const double vsl,
                           const double vtp,
                           const double lots,
                           const string state,
                           const string op)
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
    long magicnumber = OrderMagicNumber();
    string comment  = OrderComment();


    if(lots > 0)
     {
      MakeOrderOpen(symbol, 0, 0, MathAbs(lots), vsl, vtp, comment, magicnumber, state, op);
     }
    else
     {
      MakeOrderOpen(symbol, 1, 0, MathAbs(lots), vsl, vtp, comment, magicnumber, state, op);
     }
   }
  return result;
 }

//+------------------------------------------------------------------+
//| Make a order close by signal message                             |
//+------------------------------------------------------------------+
bool OrderCreate(MqlTradeResult &result, MqlTradeRequest &request, string state, const string action)
 {
  string meta_state;
  bool order_result = false;
  double volume = request.volume;

  for(int i = 0; i < 2; i++)
   {
    string api_data_message;
    string meta_message;

    if(FindCloseOrderByComment(request.comment))
      return false;

    if(AccountMarginMode() == "HEDGING")
     {
      if(FindOpenOrderByComment(request.comment) != -1)
        return false;

      if(state != "pending")
        return false;
     }

    if(action == "MODIFY_VOLUME"){
      double lot = PositionGetDouble(POSITION_VOLUME);
      request.volume = request.volume - lot;
    }

    order_result = OrderSend(request, result);

    if(result.retcode == 10016)
     {
      if(request.type == 0 || request.type == 1)
       {
        request.sl       = 0;
        request.tp       = 0;
       }
     }

    if(result.retcode == 10009)
      meta_state = action;
    else
      if(result.retcode == 10016)
        meta_state = "NOSLTP";
      else
        meta_state = "ERRORDEAL";

    OrderSelect(result.order, SELECT_BY_TICKET, MODE_TRADES);

    meta_message = StringFormat("\nOrder Status OPEN: %d | OrderID: %d | Retcode: %u | Comment: %s | Result-Comment: %s | Attempt: %d", GetLastError(), result.order, result.retcode, request.comment, result.comment, i);     // se não for possível enviar o pedido, exibir um código de erro
    Print(meta_message);
    commentLineItemOrderModify = AddCommentOnChart(meta_message, commentLineItemOrderModify);

    api_data_message = MessageSendFormat(request.magic, action, state, meta_state, result.order, result.deal, request.symbol, request.type, result.price, 0, volume, request.sl, request.tp, "0", request.comment, DoubleToStr(double(TimeGMT())), meta_message);
    ApiTrasmitInformation(api_data_message, meta_state);

    if(result.retcode == 10009)
      break;

   }

  return order_result;
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string MessageSendFormat(long magic_number, const string action, const string order_state, const string meta_state, long order_ticket, long ticket_deal, string order_symbol, long order_type, double price_open, double price_close, double volume, double stop_loss, double take_profit,
                         string profit, string comment, string open_at, string meta_message = "")
 {
  long timezone = long((TimeLocal() - TimeGMT()) / 3600);
  string message = StringFormat("body={'account_login':'%s', 'magic_number':'%d', 'action':'%s', 'order_state':'%s', 'meta_state':'%s', 'ticket_slave_id':'%s', 'ticket_deal':'%d', 'order_symbol':'%s', 'order_type':'%d', 'price_open':'%g', 'price_close':'%g', 'volume':'%g', 'stop_loss':'%g', 'take_profit':'%g', 'profit':'%s', 'comment':'%s', 'open_at':'%s', 'timezone':'%d', 'meta_message':'%s'}",
                                ACCOUNTLOGIN,
                                magic_number,
                                action,
                                order_state,
                                meta_state,
                                IntegerToString(order_ticket),
                                ticket_deal,
                                order_symbol,
                                order_type,
                                price_open,
                                price_close,
                                volume,
                                stop_loss,
                                take_profit,
                                profit,
                                comment,
                                open_at,
                                timezone,
                                meta_message
                               );
                               
  return message;
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateOrderStruct(OrderStruct &orders[])
 {
  string orderdata[];
  ApiRequestInformation(orderdata, "orders");
  int orderdataCount = ArraySize(orderdata);
  int index = 0;

  if(orderdataCount == 0)
    return;

  for(int i = 0; i < orderdataCount; i++)
   {
    string orderdataparse[];
    ParseMessage(orderdata[i], orderdataparse);
    ArrayResize(orders, orderdataCount);
    orders[index].type = StringToInteger(orderdataparse[0]);
    orders[index].ticket_master = StringToInteger(orderdataparse[1]);
    orders[index].ticket_slave = StringToInteger(orderdataparse[2]);
    orders[index].trace_id = StringToInteger(orderdataparse[3]);
    orders[index].slave_id = StringToInteger(orderdataparse[4]);
    orders[index].magicnumber = StringToInteger(orderdataparse[5]);
    orders[index].transaction_id = StringToInteger(orderdataparse[6]);
    orders[index].price_open = StringToDouble(orderdataparse[7]);
    orders[index].lot = StringToDouble(orderdataparse[8]);
    orders[index].stop_loss = NormalizeNumber(orderdataparse[9], orderdataparse[12]);
    orders[index].take_profit = NormalizeNumber(orderdataparse[10], orderdataparse[12]);
    orders[index].state = orderdataparse[11];
    orders[index].symbol = orderdataparse[12];
    orders[index].deal_ticket = StringToInteger(orderdataparse[13]);
    orders[index].seconds_ago = StringToInteger(orderdataparse[14]);
    orders[index].comment = orderdataparse[15];
    orders[index].open_at = orderdataparse[16];
    index++;
   }
 }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ApiTrasmitInformation(const string message, const string action)
{
    string request = "POST";
    string server_url = Server +"/api/"+ API_VERSION +"/transactions/slave/post";
    string url = "http://" + server_url + "/" + EXPERTNAME + "/" + VERSION + "/"  + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode();

    string cookie = NULL;
    string headers;
    int response = 0;
    char post[];
    char result[];
    int count = 0;

    ResetLastError();
    StringToCharArray(message, post, 0, StringLen(message));

    while(response != 201 && count <= 1)
    {
        if(MQLInfoInteger(MQL_TESTER))
        {
            SendMessageToFile(message, action);
            return true;
        }
        else
        {
            response = WebRequest("POST", url, cookie, NULL, 35000, post, 0, result, headers);
        }

        if(response == 201)
        {
            string response_string = CharArrayToString(result);

            if(StringFind("OK|OK|OK", response_string) != -1)
                return true;
        }

        count++;
    }

    // Print("Conexão com servidor - Resposta: " + IntegerToString(response) + ", GetLastError: ", GetLastError());
    string comment = "Conexão com servidor - Resposta: " + IntegerToString(response) + ", GetLastError: " + IntegerToString(GetLastError());
    Print(comment);
    
    commentLineItemServerStatus = AddCommentOnChart(comment, commentLineItemServerStatus);
    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ApiRequestInformation(string &orderdata[], const string action)
{
    string comment;
    string request;
    string cookie = NULL;
    string headers;
    string serverHeaders;
    char   post[];
    char   result[];

    string str = "EnvironmentLocal=" + IntegerToString(EnvironmentLocal);
    ArrayResize(post, StringToCharArray(str, post, 0, WHOLE_ARRAY, CP_UTF8) - 1);

    string server_url;
    string url;

    if(action == "store")
    {
        request = "POST";
        server_url = Server + "/api/" + API_VERSION + "/stores/config";
        url = "http://" + server_url + "/" + EXPERTNAME + "/" + VERSION + "/" + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode() ;
    }
    else if (action == "orders")
    {
        request = "POST";
        server_url = Server + "/api/" + API_VERSION + "/transactions/slave/post";
        url = "http://" + server_url + "/" + action + "/" + EXPERTNAME + "/" + VERSION + "/" + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode() ;
    }

    int response = 0;
    bool internet_down = false;

    do
    {
        ResetLastError();

        response = WebRequest(request, url, headers, 5000, post, result, serverHeaders);

        if(response != 1001 && internet_down)
        {
            comment = "Conexão estabelecida";
            Print(comment);

            commentLineItemServerStatusError = AddCommentOnChart(comment, commentLineItemServerStatusError);
            internet_down = false;
        }

        if(response == -1)
        {
            comment += "\nApi código de erro: " + IntegerToString(GetLastError());
            comment += "\nÉ necessário adicionar o endereço '" + ToUpper(Server) + "' em Ferramentas->Opções->Experts Advisores->URL WebRequest - Erro: " + IntegerToString(MB_ICONINFORMATION);
            Print(comment);

            commentLineItemServerStatusError = AddCommentOnChart(comment, commentLineItemServerStatusError);


            return false;
        }
        else if(response == 201)
        {
            string result2 = CharArrayToString(result);
            int size = StringSplit(result2, '/', orderdata);
            return true;
        }
        else
        {
            comment += "\nApi código de erro: " + IntegerToString(GetLastError()) + ",  resposta: " + IntegerToString(response);
            Print(comment);

            commentLineItemServerStatusError = AddCommentOnChart(comment, commentLineItemServerStatusError);

        }

        internet_down = true;
        comment += "\nVerifique a sua conexão com a internet ou servidor fora temporariamente.";
        Print(comment);

        commentLineItemServerStatusError = AddCommentOnChart(comment, commentLineItemServerStatusError);

    }
    while(response != 201);

    comment = "Conexão com servidor - Resposta: " + IntegerToString(response) + ", GetLastError: " + IntegerToString(GetLastError());
    Print(comment);
    
    commentLineItemServerStatus = AddCommentOnChart(comment, commentLineItemServerStatus);

    return false;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SendMessageToServer(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string const action, string const state, string const meta_state)
 {
  string meta_message = StringFormat("Action: %s | Symbol: %s | TransactionID: %d | Ticket Master: %d | Ticket Slave: %d | Type: %d | LastError: %d | Result Code: %u | Result Comment: %s", action, order.symbol, order.transaction_id, order.ticket_master, order.ticket_slave, order.type, GetLastError(), result.retcode, result.comment);     // se não for possível enviar o pedido, exibir um código de erro

  Print(meta_message);

  string sprofit = DoubleToString(OrderProfit());
  string message_format = MessageSendFormat(request.magic, action, state, meta_state, order.ticket_slave, order.deal_ticket, order.symbol, order.type, order.price_open, order.price_close, order.lot, order.stop_loss, order.take_profit, sprofit, order.comment, order.open_at, meta_message);

  ApiTrasmitInformation(message_format, meta_state);
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SendMessageToFile(string message, string const meta_state)
 {
  string InpFileName = "signal_slave.txt";  // file name
  string InpDirectoryName = "Data"; // directory name
  int file_handle = FileOpen(InpDirectoryName + "//" + InpFileName, FILE_READ | FILE_WRITE | FILE_TXT | FILE_UNICODE);
  if(file_handle != INVALID_HANDLE)
   {
    FileSeek(file_handle, 0, SEEK_END);
    message = StringFormat("%s; %s; %s", message, meta_state, TimeToString(TimeCurrent()));
    FileWriteString(file_handle, message + "\r\n");
    FileClose(file_handle);
    PrintFormat("%s file was write", InpFileName);
    return true;
   }
  else
    PrintFormat("Failed to open %s file, Error code = %d", InpFileName, GetLastError());
  return false;
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
//|            FindCommentIdOnApiOrders                              |
//+------------------------------------------------------------------+
int FindCommentIdOnApiOrders(OrderStruct &orders[], string ticketid)
 {
  int orders_size = ArraySize(orders);
  int changes = -1;

  for(int i = 0; i < orders_size; i++)
   {
    if(orders[i].ticket_master == StringToInteger(ticketid))
      changes = i;
   }
  return changes;
 }

//+------------------------------------------------------------------+
//| Find a current order by server signal                            |
//+------------------------------------------------------------------+
long FindOpenOrderByComment(const string comment)
{
  long ticketid = -1;

  ordersize  = OrdersTotal();

  for(int orderindex = 0; orderindex < ordersize; orderindex++)
   {
    if(OrderSelect(orderindex, SELECT_BY_POS, MODE_TRADES) == false)
      continue;

    string order_comment = OrderComment();

    if(order_comment == comment)
     {
      ticketid = OrderTicketID();
      if(OrderSelect(ticketid, SELECT_BY_TICKET, MODE_TRADES))
        return ticketid;
     }

    if(ticketid > 0)
      break;
   }

  return ticketid;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool FindCloseOrderByComment(const string comment)
{

  bool changed = false;
  HistorySelect(0, TimeCurrent());
  for(int i = HistoryDealsTotal(); i > 0; i--)
   {
    ulong deal_ticket = HistoryDealGetTicket(i);
    int entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    ulong ticket = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

    if(entry_type == DEAL_ENTRY_OUT)
     {
      string comment_history = HistoryOrderGetString(ticket, ORDER_COMMENT);
      if(comment == comment_history)
       {
        if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY) == false)
          continue;
        return true;
       }
     }
   }
  return changed;
}

//+------------------------------------------------------------------+
//| FindCloseOrderByTicketId                                         |
//+------------------------------------------------------------------+
long FindCloseOrderByTicketId(const ulong ticketid)
{
   HistorySelect(0, TimeCurrent());

   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      long ticket = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

      if(entry_type != DEAL_ENTRY_IN && ticket == ticketid)
      {
         return long(deal_ticket);
      }
   }

   return INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CompareDoubles(double number1, double number2)
{
  bool ret;
  number1 = NormalizeDouble(number1, 6);
  number2 = NormalizeDouble(number2, 6);

  if(number1 == 0.0 && number2 == 0.0)
   {
    if((int)MathRound((number1 - number2) / 100000000.0) == 0)
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
double NormalizeNumber(string snumber, string symbol)
{
  int    vdigits = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  double number = MathAbs(NormalizeDouble(StringToDouble(snumber), vdigits));

  return number;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculatePips(double vprice, string snumber, long vtype, string symbol, string kind)
{

  int    vdigits = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  double vpoint  = SymbolInfoDouble(symbol, SYMBOL_POINT);
  double number = StringToDouble(snumber);

  if(StringFind(snumber, ".") == -1)
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
      number = NormalizeDouble(vprice - number * mod * vpoint, vdigits);
    else
     {
      if(kind == "tp")
        mod = -1;
      number = NormalizeDouble(vprice + number * mod * vpoint, vdigits);
     }
   }
  return number;
}

//+------------------------------------------------------------------+
//| MQL4 -> MQL5                                                     |
//+------------------------------------------------------------------+
bool IsDemoMQL4()
{
  if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO)
    return(true);
  else
    return(false);
}

//+------------------------------------------------------------------+
string AccountMarginMode()
{
  int modetype = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
  string mode;
  switch(modetype)
   {
    case 0:
      mode = "NETTING";
      break;
    case 1:
      mode = "EXCHANGE";
      break;
    case 2:
      mode = "HEDGING";
      break;
   }
  return mode;
}

//+------------------------------------------------------------------+
//| Returns price in a random way                                    |
//+------------------------------------------------------------------+
double GetSymbolPrice(string symbol, long type)
{
  int t = (int)type;
  //--- stop levels for the symbol
  MqlTick last_tick = {};
  SymbolInfoTick(symbol, last_tick);
  //--- calculate price according to the type
  double price = 0;
  
  if(t == 0)
   {
    price = SymbolInfoDouble(symbol, SYMBOL_ASK);
   }
  else
    if(t == 1)
     {
      price = SymbolInfoDouble(symbol, SYMBOL_BID);
      //price=price+(distance+(MathRand()%10)*5)*_Point;
     }
  //---
  return(price);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string RemoveSpecialChars(string inputString)
{
    string resultString = "";
    int inputLength = StringLen(inputString);

    for(int i = 0; i < inputLength; i++)
    {
        int charValue = StringGetChar(inputString, i);

        if((charValue >= 48 && charValue <= 57) || // números
           (charValue >= 65 && charValue <= 90) || // letras maiúsculas
           (charValue >= 97 && charValue <= 122)) // letras minúsculas
        {
            //string stringArgument1 = StringSubstr(inputString, i, 1);
            StringConcatenate(resultString, resultString,  StringSubstr(inputString, i, 1));
        }
    }

    return resultString;
}

//+------------------------------------------------------------------+
//| DrawTextOnChart                                                  |
//+------------------------------------------------------------------+
long ShowCommentOnChart()
{
    long line_item = 0;
    string finalText = ""; // Inicialize a string final como vazia

    for (int i = 0; i < ArraySize(commentOnChart); i++) {
        line_item = long(i);
        finalText += commentOnChart[i] + "\n"; // Adicione cada string do array à string final, seguida por uma quebra de linha
    }

    Comment(finalText);

    return line_item;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long AddCommentOnChart(string newMessage, long line_item=0)
{
    
    if(line_item > 0){
      commentOnChart[line_item] = newMessage;
      ShowCommentOnChart();
      
    } else {
      ArrayResize(commentOnChart, ArraySize(commentOnChart) + 1); // Redimensiona o array para ser um elemento maior
      commentOnChart[ArraySize(commentOnChart) - 1] = newMessage; // Adiciona a nova mensagem na última posição do array
      line_item = ShowCommentOnChart();            
    }  
  
    return line_item;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string AttributeChangeString(string attributeName, double oldValue, double newValue)
{
    string message = ToUpper(attributeName) + " changed from: " + ToUpper(DoubleToString(oldValue)) + " to: " + ToUpper(DoubleToString(newValue)) + "\n";
    return message;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

string ToUpper(string str) {
    if (StringToUpper(str)) {
        return str;
    } else {
        Print("Falha ao converter a string para maiúsculas.");
        return str;
    }
}

//+------------------------------------------------------------------+
//|            CheckOrdersClosed                                     |
//+------------------------------------------------------------------+
void CheckOrdersClosed(OrderStruct &orders[])
 {
  if(ArraySize(orders) == 0)
    return;
  for(int orderindex = 0; orderindex < PositionsTotal(); orderindex++)
   {
    if(PositionGetInteger(POSITION_MAGIC) == 0)
      continue;

    ulong ticketid = PositionGetTicket(orderindex);
    string comment_id = PositionGetString(POSITION_COMMENT);
    int orders_index = FindCommentIdOnApiOrders(orders, comment_id);

    if(orders_index >= 0)
     {
      if(FindCloseOrderByComment(orders[orders_index].comment))
        MakeOrder(orders[orders_index] , "CLOSED");
     }
   }
 }

//+------------------------------------------------------------------+
//| FormatMessage                                                    |
//+------------------------------------------------------------------+
int GetDigitFromNumber(string number)
 {
  int digit = 0;
  string result[];
  StringSplit(number, '.', result);
  if(ArraySize(result) > 0)
    digit = StringLen(result[1]);
  return digit;
 }
 
//+------------------------------------------------------------------+
//| DigitsCount                                                      |
//+------------------------------------------------------------------+ 
int DigitsCount(double number)
{
   int digits = 0;

   while (NormalizeDouble(number, digits) != number) {digits +=1;}

   return digits;
}

//+------------------------------------------------------------------+