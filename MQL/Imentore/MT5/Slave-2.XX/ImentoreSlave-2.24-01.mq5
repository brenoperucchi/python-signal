//+------------------------------------------------------------------+
//#property version "2.24"

#define EXPERTNAME "imentore_slave"
#define VERSION "2_24"
#define VERSION_UPDATE "01"

#define APPNAME "Imentore Slave"
#define APPVERSION "2.24"

#include <Trade\Trade.mqh>
#include <Trade\TerminalInfo.mqh>
#include <JAson.mqh>

#property copyright   "Update "+ VERSION_UPDATE +"- Copyright IMENTORE.COM"
#property description "Breno Perucchi"
#property strict
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input ulong  MaxSeconds              = 30;     // Time Max Operation - limit for waiting open a order (default is 30)
input int    Slippage                = 30;     // Spread for price   
input bool   EnvironmentLocal        = false;  // Admin only (default is false)

double PercentLots             = 100;                     // Lots Percent from Signal (Default is 100)
double MaxLots                 = 0.00;                    // Limit the maximum lots (Default is 0.00)
double MinLots                 = 0.00;                    // Limit the minimum lots (Default is 0.00)

string SERVER                  = "mt5-web-replicator.example.com";
string ACCOUNTLOGIN            = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
string API_VERSION             = "v2";
string ACCOUNT_SERVER_NAME     = "";
int    MILLISECOND_TIMER       = 3500;

//+------------------------------------------------------------------+
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
int    SleepTries        = 2;

//+------------------------------------------------------------------+
string store_state;
string store_message;
string account_state;
string account_margin_mode;
string account_mode;                // Under real server (Default is false)
string api_server_hostname;
int timecurrent = int(TimeCurrent());


//+------------------------------------------------------------------+ Current
int file_handle_out             = 0;
long commentLineItemOrder       = 0;
long commentLineItemMakeOrder   = 0;
long comment_mfe_mae_line_item  = 0;
long commentOnChartInitPosition[];

string LogFileName;
string commentOnChartInit[];
string commentOnChartTick[];
string comment_order_status;

//+------------------------------------------------------------------+ Objects
CTrade trade;
CTerminalInfo cterminal;
CJAVal jv;

//+------------------------------------------------------------------+
//| Struct Order Container                                           |
//+------------------------------------------------------------------+
struct OrderStruct
 {
  long               type;
  long               ticket_master;
  long               ticket_slave;
  long               ticket_deal;
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
  double             contract_volume;
  string             state;
  string             symbol;
  string             comment;
  ulong              seconds_ago;
  string             open_at;
  string             closed_at;
 };

//+------------------------------------------------------------------+
//|Initialisation function                                           |
//+------------------------------------------------------------------+
int OnInit()
 {
  SetLogFileName();
  string message = StringFormat("Iniciando Expert %s %s - Update %s", APPNAME, APPVERSION, VERSION_UPDATE);
  AddCommentOnChart(message, 1);
  EventSetMillisecondTimer(MILLISECOND_TIMER);

  ACCOUNT_SERVER_NAME     = RemoveSpecialChars(AccountInfoString(ACCOUNT_SERVER));
  if(DetectEnvironment() == false)
   {
    Print("Expert ", APPNAME + " " + APPVERSION + " - Update " + VERSION_UPDATE + " não inicializado. Contacte o suporte.");
    string comment = ("Expert " + APPNAME + " " + APPVERSION + " - Update " + VERSION_UPDATE + " não inicializado. Contacte o suporte.");
    AddCommentOnChart(comment, 2);
    return(INIT_FAILED);
   }
  else
   {
    Print("Expert ", APPNAME + " " + APPVERSION + "- Update " + VERSION_UPDATE + " inicializado com sucesso.");
    string comment = ("Expert " + APPNAME + " " + APPVERSION + " - Update " + VERSION_UPDATE +" inicializado com sucesso.");
    AddCommentOnChart(comment, 2);
    return(INIT_SUCCEEDED);
   }
 }

//+------------------------------------------------------------------+
//| OnTimer                                                          |
//+------------------------------------------------------------------+
void OnTimer(){
  OrdersExecute();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
 {
  int  changed = 0;
  changed = OrdersExecute();

  SetLogFileName();

// Loop for 60 seconds
  int timeago = int(TimeCurrent() - timecurrent);
  if(timeago > 60){
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
  string comment = ("Expert " + APPNAME + " " + APPVERSION + " - Update " + VERSION_UPDATE + " removido com sucesso.");
  Print(comment);
  Comment(comment);
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
    SERVER = "localhost:8080";

  if(CheckServerInformations() == false)
    return false;

  order_minlots = MinLots;
  order_maxlots = MaxLots;
  order_percentlots = (order_percentlots > 0) ? PercentLots : 100;
  order_slippage = Slippage;

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
  bool change = MakeOrder(order, "OPEN");
  change ? (changed ++) : changed;

  return changed;
 }

//+------------------------------------------------------------------+
//| Push the modify order to all of the subscriber                   |
//+------------------------------------------------------------------+
int PushOrderModify(OrderStruct &order)
 {
  bool orderchanged = false;
  int symbol_digit = (int)SymbolInfoInteger(order.symbol, SYMBOL_DIGITS);
  order_minlots = order.contract_volume;
  
  int changed    = 0;
  string comment_modify_stop_loss, comment_modify_take_profit, comment_modify_volume;

  long ticketid = FindOpenOrderByComment(order.comment);

  bool position = PositionSelectByTicket(ticketid);
  
  //bool order_select = OrderSelect(ticketid);

  string comment = PositionGetString(POSITION_COMMENT);

  if(ticketid != -1)
   {
    if(comment == order.comment)
     {
      if(CompareDoubles(PositionGetDouble(POSITION_SL), order.stop_loss)){
        orderchanged = true;
        comment_modify_stop_loss += AttributeChangeString("stop_loss", PositionGetDouble(POSITION_SL), order.stop_loss, order.symbol);
      }

      if(CompareDoubles(PositionGetDouble(POSITION_TP), order.take_profit)){
        orderchanged = true;
        comment_modify_take_profit += AttributeChangeString("take_profit", PositionGetDouble(POSITION_TP), order.take_profit, order.symbol); 
      }

      double lot = PositionGetDouble(POSITION_VOLUME);

      if(CompareDoubles(lot, order.lot)){
        orderchanged = true;
        comment_modify_volume += AttributeChangeString("volume", lot, order.lot, order.symbol);
      }

      if(CompareDoubles(lot, order.lot)) // Only Netting Accounts
       {
        bool change = MakeOrder(order, "MODIFY_VOLUME");
        change ? (changed ++) : 0;
       }

      if(orderchanged == true)
      {
        //vprice = GetRandomPrice(symbol, vtype);  // open price
        order.stop_loss   = CalculatePips(PositionGetDouble(POSITION_PRICE_OPEN), DoubleToString(order.stop_loss, symbol_digit), order.type, order.symbol);
        order.take_profit = CalculatePips(PositionGetDouble(POSITION_PRICE_OPEN), DoubleToString(order.take_profit, symbol_digit), order.type, order.symbol);
        
        bool change = MakeOrder(order, "MODIFY");
        if(change){
          
          if(StringLen(comment_modify_volume)      > 0) Print(comment_modify_volume);
          if(StringLen(comment_modify_stop_loss)   > 0) Print(comment_modify_stop_loss);
          if(StringLen(comment_modify_take_profit) > 0) Print(comment_modify_take_profit);
          
          AddCommentOnChart(comment_modify_volume);
          AddCommentOnChart(comment_modify_stop_loss);
          AddCommentOnChart(comment_modify_take_profit);
          
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
  
  if(ticketid <= 0){
   ticketid = FindOpenOrderByComment(order.comment);
   order.ticket_slave = ticketid;
  }
  
  bool orderstatus =    false;

  if(order.trace_id <= 0 || order.symbol == "")
    return false;

  SymbolSelect(order.symbol, true);
  MqlTradeResult  result = {};
  MqlTradeRequest request = {};
  ZeroMemory(request);
  ZeroMemory(result);
  ResetLastError();

  if(action == "OPEN"){
    ticketid = MakeOrderOpen(result, request, order, action);
    if(ticketid > 0) orderstatus = true;
  }else 
  
  if(action == "CLOSED"){
    orderstatus = MakeOrderClose(result, request, order, action);      
  } else 
  
  if(action == "MODIFY"){
    orderstatus = MakeOrderModify(result, request, order, action);
  }

  if(action == "MODIFY_VOLUME"){
    orderstatus = MakeOrderModifyVolume(result, request, order, action);
  }

  return (ticketid > 0 && orderstatus) ? true : false;
}

//+------------------------------------------------------------------+
//| Make a market or pending order by signal message                 |
//+------------------------------------------------------------------+
long MakeOrderOpen(MqlTradeResult &result,
                    MqlTradeRequest &request,
                    OrderStruct &order,
                    string action)
 {
  long ticketid = -1;
  bool response = false;
  string symbol = order.symbol;

// Allow signal to open the order
// Symbol must not be empty
  if(order_allowopen == false || order.symbol == "")
    return ticketid;

// Allow Expert Advisor to open the order
  if(cterminal.IsTradeAllowed() == false)
    return ticketid;

// Check if account margin free is less than settings
  if(account_minmarginfree > 0.00 && AccountInfoDouble(ACCOUNT_MARGIN_FREE) < account_minmarginfree)
    return ticketid;

  double vprice = 0;
  double vsl    = order.stop_loss;
  double vtp    = order.take_profit;
  double vlots  = GetOrderLots(order.symbol, order.lot, order.contract_volume);
  long   vtype  = order.type;

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

//vprice = GetRandomPrice(symbol, vtype);  // open price
  double sl = CalculatePips(vprice, DoubleToString(vsl, int(SymbolInfoInteger(symbol, SYMBOL_DIGITS))), vtype, symbol);
  double tp = CalculatePips(vprice, DoubleToString(vtp, int(SymbolInfoInteger(symbol, SYMBOL_DIGITS))), vtype, symbol);
  //DoubleToString();Symbo
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
  request.symbol    = symbol;                                // símbolo
  request.volume    = vlots;                                 // volume de 0.2 lotes
  request.price     = vprice;                                // preço para a abertura
  request.deviation = order_slippage;                        // desvio permitido do preço
  request.magic     = order.magicnumber;                     // MagicNumber da ordem
  request.sl        = sl;
  request.tp        = tp;
  request.comment   = order.comment;


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
      request.action       = TRADE_ACTION_PENDING;                     // tipo de operação de negociação
      request.type         = ORDER_TYPE_BUY_LIMIT;                     // tipo da ordem
      request.type_filling = ORDER_FILLING_FOK;
      request.type_time    = ORDER_TIME_DAY;
      request.price        = order.price_open;                                // preço para a abertura
      break;
    case 3:
      request.action       = TRADE_ACTION_PENDING;                     // tipo de operação de negociação
      request.type         = ORDER_TYPE_SELL_LIMIT;                      // tipo da ordem
      request.type_filling = ORDER_FILLING_FOK;
      request.type_time    = ORDER_TIME_DAY;
      request.price        = order.price_open;                                // preço para a abertura

      break;
    case 4:
      request.action       = TRADE_ACTION_PENDING;                     // tipo de operação de negociação
      request.type         = ORDER_TYPE_BUY_STOP;                    // tipo da ordem
      request.type_filling = ORDER_FILLING_RETURN;
      request.type_time    = ORDER_TIME_DAY;
      request.price        = order.price_open;                                // preço para a abertura
      request.stoplimit    = 0;
      break;
    case 5:
      request.action       = TRADE_ACTION_PENDING;                     // tipo de operação de negociação
      request.type         = ORDER_TYPE_SELL_STOP;                     // tipo da ordem
      request.type_filling = ORDER_FILLING_RETURN;
      request.type_time    = ORDER_TIME_DAY;
      request.price        = order.price_open;                                // preço para a abertura
      request.stoplimit    = 0;
      break;
    case 6:
      request.action       = TRADE_ACTION_PENDING;                     // tipo de operação de negociação
      request.type         = ORDER_TYPE_BUY_STOP_LIMIT;                // tipo da ordem
      request.type_filling = ORDER_FILLING_FOK;
      request.type_time    = ORDER_TIME_DAY;
      request.price        = order.price_open;                                // preço para a abertura
      break;
    case 7:
      request.action       = TRADE_ACTION_PENDING;                     // tipo de operação de negociação
      request.type         = ORDER_TYPE_SELL_STOP_LIMIT;                // tipo da ordem
      request.type_filling = ORDER_FILLING_FOK;
      request.type_time    = ORDER_TIME_DAY;
      request.price        = order.price_open;                                // preço para a abertura
      break;
   }

  ticketid = OrderCreate(result, request, order, action);
  // ticketid = long(result.order);
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
  long ticket_open_comment = FindOpenOrderByComment(order.comment);
  bool ticket_closed = FindCloseOrderByComment(order.comment);

  string meta_state;
  long close_result = 0;
  
  if(order.ticket_slave < 1 && ticket_open_comment > 0)
   order.ticket_slave = ticket_open_comment;

  // Allow signal to close the order
  // The parameter ticketid must be greater than zero
  if(order_allowclose == false)// || order.ticket_slave <= 0)
    return close_result;

  // Allow Expert Advisor to close the order
  if(cterminal.IsTradeAllowed() == false)
    return close_result;

  
  PositionSelectByTicket(order.ticket_slave);

  switch(int(order.type))
   {
    case ORDER_TYPE_BUY_LIMIT:
    case ORDER_TYPE_BUY_STOP:
    case ORDER_TYPE_BUY_STOP_LIMIT:
    case ORDER_TYPE_SELL_LIMIT:
    case ORDER_TYPE_SELL_STOP:
    case ORDER_TYPE_SELL_STOP_LIMIT:
      close_result = trade.OrderDelete(order.ticket_slave);
      break;

    default:
      request.action       = TRADE_ACTION_DEAL;                   // type of trade operation
      request.position     = order.ticket_slave;                  // ticket of the position
      request.symbol       = order.symbol;                        // symbol
      request.volume       = PositionGetDouble(POSITION_VOLUME);  // volume of the position
      request.deviation    = order_slippage;                      // allowed deviation from the price
      request.comment      = order.comment;
      request.magic        = order.magicnumber;
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
             
      if(ticket_open_comment == -1 && !ticket_closed){
        result.retcode = 94016;
        result.comment = "Not Find for Closed";
        meta_state     = "NOTFIND";
        close_result   = INVALID_HANDLE;
      } else         
      if(ticket_closed && FindOpenOrderByComment(order.comment) == INVALID_HANDLE){          
        order.ticket_deal = FindCloseOrderByCommentLong(order.comment);
        //order.price_close = HistoryDealGetDouble(order.ticket_deal, DEAL_PRICE);            
        result.retcode    = 90013;
        result.comment    = "Manual Closed";
        meta_state        = "HASCLOSED";
        order.closed_at   = TimeToString(HistoryDealGetInteger(order.ticket_deal, DEAL_TIME),  (TIME_DATE | TIME_MINUTES | TIME_SECONDS));    
        close_result++;
      } 
      else{
        close_result = OrderSend(request, result);
        HistorySelect(0, TimeCurrent());
        
        if(close_result)
          meta_state     = "CLOSED";
        else
          meta_state     = "NOTCLOSED";
        
        //if(order.price_open == 0)
        //  order.price_open  = HistoryDealGetDouble(order.ticket_deal, DEAL_PRICE);                          
        order.ticket_deal = long(result.deal);
        order.price_close = result.price;        
        order.closed_at   = TimeToString(HistoryDealGetInteger(order.ticket_deal, DEAL_TIME),  (TIME_DATE | TIME_MINUTES | TIME_SECONDS));       
        close_result++;
      }
      
      if(order.price_open <= 0.0)
        order.price_open = GetOrderPriceOpen(order.ticket_slave);

      if(order.price_close <= 0.00)
        order.price_close = GetOrderPriceClose(order.ticket_slave);                     
   }
   string log_message = StringFormat("Log Info - LastError: %d - Retcode: %u - ResultComment: %s - Attempt: %d", GetLastError(), result.retcode, result.comment, 0);  

   SendMessageToServer(result, request, order, action, order.state, meta_state, "MakeOrderClose", log_message);
      
  return close_result;
 }

//+------------------------------------------------------------------+
//| Make a order modify by signal message                            |
//+------------------------------------------------------------------+
long MakeOrderModify(MqlTradeResult &result,
                    MqlTradeRequest &request,
                    OrderStruct &order,
                    string action)
 {
  long change = -1;
  string meta_state;
  int symbol_digit  = (int)SymbolInfoInteger(order.symbol, SYMBOL_DIGITS);

  // Allow signal to modify the order
  // The parameter ticketid must be greater than zero
  if(order_allowmodify == false || order.ticket_slave <= 0)
    return change;

  // Allow Expert Advisor to modify the order
  if(cterminal.IsTradeAllowed() == false)
    return change;

  if(FindOpenOrderByComment(order.comment) > 0){
    change = trade.PositionModify(order.ticket_slave, order.stop_loss, order.take_profit);
  }
 
  result.comment = trade.ResultComment();
  result.retcode = trade.ResultRetcode();
  request.symbol = order.symbol;
  request.sl     = order.stop_loss;
  request.tp     = order.take_profit;
  meta_state     = change ? "MODIFY" : "NOTMODIFY";
  change         = change ? order.ticket_slave : INVALID_HANDLE;

  string log_message  = StringFormat("Log Info - LastError: %d - Retcode: %u - ResultComment: %s - Attempt: %d", GetLastError(), result.retcode, result.comment, 0);  

  SendMessageToServer(result, request, order, action, order.state, meta_state, "MakeOrderModify", log_message);
  return change;
 }
//+------------------------------------------------------------------+
//| Make a order modify by signal message                            |
//+------------------------------------------------------------------+
long MakeOrderModifyVolume(MqlTradeResult &result,
                           MqlTradeRequest &request,
                           OrderStruct &order,
                           string action)
 {
  long change = -1;

// Allow signal to modify the order
// The parameter ticketid must be greater than zero
  if(order_allowmodify == false || order.ticket_slave <= 0)
    return change;

// Allow Expert Advisor to modify the order
  if(cterminal.IsTradeAllowed() == false)
    return change;

  if(FindCloseOrderByComment(order.comment) > 0)
   {
    PositionSelectByTicket(long(order.comment));
    long magicnumber = PositionGetInteger(POSITION_MAGIC);
    string comment  = PositionGetString(POSITION_COMMENT);


    if(order.lot > 0)
     {
      MakeOrderOpen(result, request, order, action);
     }
    else
     {
      MakeOrderOpen(result, request, order, action);
     }
   }
  return change;
 }

//+------------------------------------------------------------------+
//| Make a order close by signal message                             |
//+------------------------------------------------------------------+
long OrderCreate(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string action)
{
  ResetLastError();  

  long ticketid     = -1;
  bool order_result = false;

  double volume = request.volume;
  
  string meta_message;
  string meta_state, log_message;

  for(int i = 0; i <= 2; i++)
  {
    if(AccountMarginMode() == "HEDGING"){
        //if(FindOpenOrderByComment(request.comment) != -1)
        //    return false;

        if(order.state != "pending")
            return false;
    }

    if(action == "MODIFY_VOLUME"){
        double lot = PositionGetDouble(POSITION_VOLUME);
        request.volume = request.volume - lot;
    }

    if(FindTicketByComment(request.comment) == INVALID_HANDLE){
      if(order.seconds_ago <= MaxSeconds){
        order_result        = OrderSend(request, result); // OrderSend to MetaTrader 
        order.ticket_slave  = long(result.order);
      }
      else
        result.retcode = 90099;        // if seconds_go > MaxSeconds

    } else {
      result.retcode = 90016;        // if already open
    }

    if(result.retcode == 10016 && (request.type == 0 || request.type == 1))       // if problem TP SL
    {
      request.sl       = 0;
      request.tp       = 0;
    }

    string action_msg = StringFormat("TimeGMT %s", TimeToString(TimeGMT(), (TIME_DATE|TIME_MINUTES|TIME_SECONDS)));

    if(result.retcode == 10009)
        meta_state = action;
    else if(result.retcode == 90099){
        meta_state = "TIMEMAX";
        action_msg = action_msg + StringFormat(" | OrderTime %d <= %d TimeMax", order.seconds_ago, MaxSeconds);
    }
    else if(result.retcode == 90016)
        meta_state = "OPENED";
    else if(result.retcode == 10016)
        meta_state = "NOSLTP";
    else
        meta_state = "ERRORDEAL";

    if(meta_state == "OPENED" || meta_state == "OPEN"){
      PositionSelectByTicket(order.ticket_slave);
      
      order.ticket_deal = long(result.deal);
      
      if(order.ticket_deal ==0)
        order.ticket_deal = FindOpenOrderByCommentDealTicket(order.comment);
      
      order.price_open  = result.price;
      order.stop_loss   = request.sl; 
      order.take_profit = request.tp;
      order.lot         = request.volume; 
      order.open_at     = TimeToString(PositionGetInteger(POSITION_TIME),  (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
      
      if(order.price_open == 0)
        order.price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      
    }

    ticketid     = FindOpenOrderByComment(request.comment);
    log_message  = StringFormat("Log Info - LastError: %d - Retcode: %u - ResultComment: %s - Attempt: %d", GetLastError(), result.retcode, result.comment, i);

    SendMessageToServer(result, request, order, action, order.state, meta_state, "OrderCreate", log_message);

    if(result.retcode == 10009 || result.retcode == 90099 || result.retcode == 90016)
      break;
  }

  return ticketid;
}

//+------------------------------------------------------------------+
//| Formats a message for sending, including various order details   |
//+------------------------------------------------------------------+
string MessageSendFormat(
    long magic_number, 
    const string action, 
    const string order_state, 
    const string meta_state, 
    long ticket_slave, 
    long ticket_master, 
    long ticket_deal, 
    string order_symbol, 
    long order_type, 
    double price_open, 
    double price_close, 
    double volume, 
    double stop_loss, 
    double take_profit,
    double profit, 
    string comment, 
    string open_at, 
    string closed_at, 
    string meta_message = ""
) {
  // Get the number of digits for the symbol
  int symbol_digit = int(SymbolInfoInteger(order_symbol, SYMBOL_DIGITS));
  
  // Calculate the time zone offset
  long timezone = long((TimeLocal() - TimeGMT()) / 3600);
  
  // Format the message
  string message = StringFormat(
      "body={'account_login':'%s', 'magic_number':'%d', 'action':'%s', 'order_state':'%s', 'meta_state':'%s', 'ticket_slave_id':'%s', "
      "'ticket_master_id':'%s', 'ticket_deal':'%s', 'order_symbol':'%s', 'order_type':'%d', 'price_open':'%s', 'price_close':'%s', 'volume':'%s', "
      "'stop_loss':'%s', 'take_profit':'%s', 'profit':'%s', 'comment':'%s', 'open_at':'%s', 'closed_at':'%s', 'timezone':'%d', 'time_trader':'%s', 'time_gmt':'%s', 'meta_message':'%s'}",
      ACCOUNTLOGIN,
      magic_number,
      action,
      order_state,
      meta_state,
      IntegerToString(ticket_slave),
      IntegerToString(ticket_master),
      IntegerToString(ticket_deal),
      order_symbol,
      order_type,
      DoubleToString(price_open, symbol_digit),
      DoubleToString(price_close, symbol_digit),
      DoubleToString(volume, 2),
      DoubleToString(stop_loss, symbol_digit),
      DoubleToString(take_profit, symbol_digit),
      DoubleToString(profit, 2),
      comment,
      open_at,
      closed_at,
      timezone,
      TimeToString(TimeTradeServer(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS)),
      TimeToString(TimeGMT(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS)),
      meta_message
  );
  
  return message;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int UpdateOrderStruct(OrderStruct &orders[])
{
  string orderdata[];
  if(!ApiRequestInformation(orderdata, "orders"))
    return -1; // error code indicating API request failed

  int orderdataCount = ArraySize(orderdata);
  if(orderdataCount == 0)
    return -2; // error code indicating no order data

  ArrayResize(orders, orderdataCount);
  for(int i = 0; i < orderdataCount; i++)
  {
    string orderdataparse[];
    if(!ParseMessage(orderdata[i], orderdataparse))
      return -3; // error code indicating parsing failed

    if(ArraySize(orderdataparse) < 17) // check for sufficient data
      return -4; // error code indicating insufficient data
    
    //double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    orders[i].type = StringToInteger(orderdataparse[0]);
    orders[i].ticket_master = StringToInteger(orderdataparse[1]);
    orders[i].ticket_slave = StringToInteger(orderdataparse[2]);
    orders[i].ticket_deal = StringToInteger(orderdataparse[13]);
    orders[i].trace_id = StringToInteger(orderdataparse[3]);
    orders[i].slave_id = StringToInteger(orderdataparse[4]);
    orders[i].magicnumber = StringToInteger(orderdataparse[5]);
    orders[i].transaction_id = StringToInteger(orderdataparse[6]);
    orders[i].price_open = NormalizeDouble(StringToDouble(orderdataparse[7]), int(SymbolInfoInteger(orderdataparse[12], SYMBOL_DIGITS)));
    orders[i].price_close = 0;
    orders[i].lot = StringToDouble(orderdataparse[8]);
    orders[i].stop_loss = NormalizeNumber(orderdataparse[9], orderdataparse[12]);
    orders[i].take_profit = NormalizeNumber(orderdataparse[10], orderdataparse[12]);
    orders[i].state = orderdataparse[11];
    orders[i].symbol = orderdataparse[12];
    orders[i].seconds_ago = StringToInteger(orderdataparse[14]);
    orders[i].comment = orderdataparse[15];
    orders[i].open_at = "";
    orders[i].closed_at = "";
    orders[i].contract_volume = StringToDouble(orderdataparse[17]);
  }

  return 0; // return 0 indicating success
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetDigits(double num){    
  int d = 0; double p = 1;    
    while(MathRound(num * p) / p != num)      
    {
      p = MathPow(10, ++d);      
    }    
  return d;   
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ApiTrasmitInformation(const string message, const string action)
{
    string request = "POST";
    string server_url = SERVER +"/api/"+ API_VERSION +"/transactions/slave/post";
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
    string comment = "Conexão com servidor - Resposta: " + IntegerToString(response) + ", GetLastError: " + IntegerToString(GetLastError());
    Print(comment);
    
    AddCommentOnChart(comment);
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
        server_url = SERVER + "/api/" + API_VERSION + "/stores/config";
        url = "http://" + server_url + "/" + EXPERTNAME + "/" + VERSION + "/" + ACCOUNT_SERVER_NAME + "/" + ACCOUNTLOGIN + "/" + AccountMarginMode() ;
    }
    else if (action == "orders")
    {
        request = "POST";
        server_url = SERVER + "/api/" + API_VERSION + "/transactions/slave/post";
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
            AddCommentOnChart(comment);
            internet_down = false;
        }

        if(response == -1)
        {
            comment = "Api código de erro: " + IntegerToString(GetLastError());
            comment = "É necessário adicionar o endereço '" + ToUpper(SERVER) + "' em Ferramentas->Opções->Experts Advisores->URL WebRequest - Erro: " + IntegerToString(MB_ICONINFORMATION);
            Print(comment);
            AddCommentOnChart(comment);

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
            comment = "Api código de erro: " + IntegerToString(GetLastError()) + ",  resposta: " + IntegerToString(response);
            Print(comment);
            AddCommentOnChart(comment);

        }

        internet_down = true;
        comment = "Verifique a sua conexão com a internet ou servidor fora temporariamente.";
        Print(comment);
        AddCommentOnChart(comment);

    }
    while(response != 201);

    comment = "Conexão com servidor - Resposta: " + IntegerToString(response) + ", GetLastError: " + IntegerToString(GetLastError());
    Print(comment);
    AddCommentOnChart(comment);

    return false;
}

//+------------------------------------------------------------------+
//| SendMessageToServer                                              |
//+------------------------------------------------------------------+
void SendMessageToServer(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string const action, string const state, string const meta_state, const string fuction_name, string log_message)
 {
  int    symbol_digit = int(SymbolInfoInteger(request.symbol, SYMBOL_DIGITS));
  string meta_message = StringFormat("%s - Action: %s - Meta State: %s - Symbol: %s - Type: %s - TicketMaster: %s - TicketSlave: %s - Volume: %s - TP: %s - SL: %s - ", ToUpper(fuction_name), ToUpper(action), meta_state, order.symbol, IntegerToString(order.type), IntegerToString(order.ticket_master), IntegerToString(order.ticket_slave), DoubleToString(order.lot,2), DoubleToString(request.tp, symbol_digit), DoubleToString(request.sl, symbol_digit));
  
  Print(meta_message);
  Print(log_message);
  
  AddCommentOnChart(meta_message);
  AddCommentOnChart(log_message);

  double sprofit = GetOrderProfit(order.ticket_slave);

  string message_format = MessageSendFormat(request.magic, action, state, meta_state, order.ticket_slave, order.ticket_master, order.ticket_deal, order.symbol, order.type, order.price_open, order.price_close, order.lot, order.stop_loss, order.take_profit, sprofit, order.comment, order.open_at, order.closed_at, (meta_message  + log_message));

  ApiTrasmitInformation(message_format, meta_state);
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SendMessageToFile(string message, string const meta_state)
 {
  string InpFileName = "signal_slave.txt";  // file name
  string InpDirectoryName = "Data"; // directory name
  int file_handle = FileOpen(InpDirectoryName + "//" + InpFileName, FILE_READ | FILE_WRITE | FILE_TXT | FILE_UNICODE | FILE_SHARE_READ | FILE_SHARE_WRITE);
  if(file_handle != INVALID_HANDLE)
   {
    FileSeek(file_handle, 0, SEEK_END);
    message = StringFormat("%s; %s; %s", message, meta_state, TimeToString(TimeCurrent()));
    FileWriteString(file_handle, message + "\r\n");
    FileClose(file_handle);
    // PrintFormat("%s file was write", InpFileName);
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
double GetOrderLots(const string symbol, double lots, double contract_volume)
{
    double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

    if(contract_volume == 0.0)
      return lots;
    else
      return NormalizeDouble((volume_step * contract_volume), 2);        
}

//+------------------------------------------------------------------+
//|            FindApiOrdersByTicketId                               |
//+------------------------------------------------------------------+
int FindApiOrdersByTicketId(OrderStruct &orders[], string ticketid)
 {
  int orders_size = ArraySize(orders);

  for(int i = 0; i < orders_size; i++)
   {
    if(orders[i].comment == ticketid)
      return i;
   }
  return INVALID_HANDLE;
 }

//+------------------------------------------------------------------+
//| Find a current order by server signal                            |
//+------------------------------------------------------------------+
long FindTicketByComment(string comment)
{
    HistorySelect(0, TimeCurrent());

    for(int i = HistoryOrdersTotal()-1; i >= 0; i--)
    {
        ulong order_ticket = HistoryOrderGetTicket(i);        
        if(order_ticket > 0)
        {
            string order_comment = HistoryOrderGetString(order_ticket, ORDER_COMMENT);
            if(order_comment == comment)
            {
                return long(order_ticket); // Quando a ordem desejada for encontrada, retorna o ticket
            }
        }
    }
    return INVALID_HANDLE; // Retorna um handle inválido se a ordem não for encontrada
}
//+------------------------------------------------------------------+
//| Find a current order by server signal                            |
//+------------------------------------------------------------------+
long FindOpenOrderByComment(string comment)
{
    ulong ticket;
    
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong order_ticket = PositionGetTicket(i);        
        if(order_ticket > 0)
        {

                string cc = PositionGetString(POSITION_COMMENT);
                if(PositionGetString(POSITION_COMMENT) == comment)
                {
                    ticket = order_ticket;
                    return long(order_ticket);
                    //break;  // Quando a ordem desejada for encontrada, interrompa o loop
                }
            }
        }
    return INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Find a current order by server signal                            |
//+------------------------------------------------------------------+
long FindOpenOrderByCommentDealTicket(string comment)
{

  long deal_ticket = INVALID_HANDLE;
  HistorySelect(0, TimeCurrent());
  for(int i = HistoryDealsTotal(); i > 0; i--)
  {
    deal_ticket = (long)HistoryDealGetTicket(i);
    int entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    ulong ticket = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

    string comment_history = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
    // string comment_history = HistoryOrderGetString(ticket, ORDER_COMMENT);
    if((entry_type == DEAL_ENTRY_IN || entry_type == DEAL_ENTRY_INOUT) && comment == comment_history)
      return deal_ticket;
  }
  return deal_ticket;
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

    string comment_history = HistoryOrderGetString(ticket, ORDER_COMMENT);
    if(entry_type != DEAL_ENTRY_IN && comment == comment_history)
      return true;
  }
  return changed;
}
//+------------------------------------------------------------------+
//| FindCloseOrderByCommentLong                                      |
//+------------------------------------------------------------------+
long FindCloseOrderByCommentLong(const string comment)
{

  bool changed = false;
  HistorySelect(0, TimeCurrent());
  for(int i = HistoryDealsTotal(); i > 0; i--)
  {
    long deal_ticket = long(HistoryDealGetTicket(i));
    int entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    long ticket = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

    string comment_history = HistoryOrderGetString(ticket, ORDER_COMMENT);
    if(entry_type != DEAL_ENTRY_IN && comment == comment_history)
      return deal_ticket;
  }
  return INVALID_HANDLE;
}




//+------------------------------------------------------------------+
//| FindDealInByTicketId                                             |
//+------------------------------------------------------------------+
long FindDealInByTicketId(const ulong ticketid)
{
   HistorySelect(0, TimeCurrent());

   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      long ticket = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

      if(entry_type == DEAL_ENTRY_IN && ticket == ticketid)
      {
         return long(deal_ticket);
      }
   }

   return INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| FindDealOutByTicketId                                            |
//+------------------------------------------------------------------+
long FindDealOutByTicketId(const ulong ticketid)
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
double CalculatePips(double vprice, string snumber, long vtype, string symbol) 
{
  // Obtenha o número de dígitos e o ponto para o símbolo fornecido
  int    vdigits = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  double vpoint = SymbolInfoDouble(symbol, SYMBOL_POINT); 
  double number = StringToDouble(snumber);
  double rnumber = 0;

  // Caso especial para snumber igual a "0"
  if (snumber == "0") {
    return rnumber;
  }

  // Ajuste vpoint de acordo com vdigits
  if (vdigits == 0 || vdigits == 1) {
    vpoint = 1;
  } else {
    vpoint = MathPow(10, -vdigits+1);
  }

  // Calcule a diferença entre number e vprice, ajustada por vpoint
  rnumber = ((number - vprice) / vpoint) * vpoint;

  // Adicione a diferença calculada a vprice
  rnumber = (vprice + rnumber);

  // Retorne o resultado, normalizado para o número de dígitos especificado
  return NormalizeDouble(rnumber, vdigits);
}

//+------------------------------------------------------------------+
//| IsDemoMQL4                                                       |
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
//|                                                                  |
//+------------------------------------------------------------------+
string RemoveSpecialChars(string inputString)
{
    string resultString = "";
    int inputLength = StringLen(inputString);
    uchar charArray[];

    for(int i = 0; i < inputLength; i++)
    {
        string charStr = StringSubstr(inputString, i, 1);
        StringToCharArray(charStr, charArray, 0, WHOLE_ARRAY);
        int charValue = charArray[0];

        if((charValue >= 48 && charValue <= 57) || // números
           (charValue >= 65 && charValue <= 90) || // letras maiúsculas
           (charValue >= 97 && charValue <= 122)) // letras minúsculas
        {
            StringConcatenate(resultString, resultString, charStr);
        }
    }

    return resultString;
}

//+------------------------------------------------------------------+
//| ShowCommentOnChart                                                  |
//+------------------------------------------------------------------+
long ShowCommentOnChart()
 {
  long line_item = 0;
  string finalText = ""; // Inicialize a string final como vazia
  for(int i = 0; i < ArraySize(commentOnChartInit); i++)
   {
    if(StringLen(commentOnChartInit[i]) == 0)
      continue;
    finalText += commentOnChartInit[i] + "\n"; // Adicione cada string do array à string final, seguida por uma quebra de linha
   }
  finalText += "\n";
  for(int i = 0; i < ArraySize(commentOnChartTick); i++)
   {
    if(StringLen(commentOnChartTick[i]) == 0)
      continue;
    line_item = long(i);
    finalText += commentOnChartTick[i] + "\n"; // Adicione cada string do array à string final, seguida por uma quebra de linha
   }
  Comment(finalText);
  return line_item;
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long AddCommentOnChart(string newMessage, long line_item = 0)
{

  if(StringLen(newMessage) == 0)
    return line_item;

  MqlDateTime mqlTime;
  datetime currentTime = TimeCurrent(mqlTime);
  string sDate = TimeToString(TimeCurrent(), TIME_MINUTES | TIME_SECONDS);
  newMessage = sDate + " - " + newMessage;

  if(line_item > 0)
  {
    bool foundLineItem = false;

    for(int i = 0; i < ArraySize(commentOnChartInitPosition); i++)
    {
      if(commentOnChartInitPosition[i] == line_item)
      {
        commentOnChartInit[i] = newMessage;
        foundLineItem = true;
        break;
      }
    }

    if(!foundLineItem)
    {
      ArrayResize(commentOnChartInit, ArraySize(commentOnChartInit) + 1);
      ArrayResize(commentOnChartInitPosition, ArraySize(commentOnChartInitPosition) + 1);
      commentOnChartInit[ArraySize(commentOnChartInit) - 1] = newMessage;
      commentOnChartInitPosition[ArraySize(commentOnChartInitPosition) - 1] = line_item;
    }
  
    // Bubble sort algorithm for sorting arrays
    for(int i = 0; i < ArraySize(commentOnChartInitPosition) - 1; i++)
    {
      for(int j = 0; j < ArraySize(commentOnChartInitPosition) - i - 1; j++)
      {
        if(commentOnChartInitPosition[j] > commentOnChartInitPosition[j + 1])
        {
          // Swap positions
          long tempPos = commentOnChartInitPosition[j];
          commentOnChartInitPosition[j] = commentOnChartInitPosition[j + 1];
          commentOnChartInitPosition[j + 1] = tempPos;
          // Swap messages
          string tempMsg = commentOnChartInit[j];
          commentOnChartInit[j] = commentOnChartInit[j + 1];
          commentOnChartInit[j + 1] = tempMsg;
        }
      }
    }

    ShowCommentOnChart();
  }
  else
  {
    if(ArraySize(commentOnChartTick) > 25)
      ArrayResize(commentOnChartTick, 0);
      
    ArrayResize(commentOnChartTick, ArraySize(commentOnChartTick) + 1);
    commentOnChartTick[ArraySize(commentOnChartTick) - 1] = newMessage;
    line_item = ShowCommentOnChart();
  }

  SaveLogToFile(newMessage);

  return line_item;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string AttributeChangeString(string attributeName, double oldValue, double newValue, string symbol)
{
    string message;
    int symbol_digit; 
    
    if(attributeName == "volume")
      symbol_digit = 2;
    else
      symbol_digit = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));

      message = "Order Modify: " + ToUpper(attributeName) + " changed from: " + ToUpper(DoubleToString(oldValue, symbol_digit)) + " to: " + ToUpper(DoubleToString(newValue, symbol_digit)) + "";

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
  for(int orderindex = 0; orderindex < PositionsTotal(); orderindex++)
  {    
    ulong ticketid = PositionGetTicket(orderindex);
    string comment_id = PositionGetString(POSITION_COMMENT);
    
    if(PositionGetInteger(POSITION_MAGIC) == 0)
      continue;
    
    int orders_index = FindApiOrdersByTicketId(orders, comment_id);

    // Check if the order is closed or not found in the orders array
    if(orders_index >= 0)
    {
      if(FindCloseOrderByComment(orders[orders_index].comment))
        MakeOrder(orders[orders_index], "CLOSED");
    }
    else
    {
      // The order is open but not found in the orders array
      // Add code here to handle this situation
      OrderStruct missingOrder;
      missingOrder.ticket_master  = StringToInteger(comment_id);
      missingOrder.ticket_slave   = long(ticketid);
      missingOrder.comment        = comment_id;
      missingOrder.symbol         = PositionGetString(POSITION_SYMBOL);
      missingOrder.magicnumber    = PositionGetInteger(POSITION_MAGIC);
      missingOrder.type           = PositionGetInteger(POSITION_TYPE);
      MakeOrder(missingOrder, "CLOSED");
    }
  }
}
 

//+------------------------------------------------------------------+
//| SaveLogToFile                                                    |
//+------------------------------------------------------------------+
bool SaveLogToFile(string message)
 {
// Print("SaveLogToFile - Message:", message);
  file_handle_out = FileOpen(LogFileName, FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI | FILE_TXT);
  if(file_handle_out != INVALID_HANDLE)
   {
    FileSeek(file_handle_out, 0, SEEK_END);
    //message = StringFormat("%s;%s; %s"message, meta_state, TimeToString(TimeCurrent()));
    FileWriteString(file_handle_out, message + "\r\n");
    FileClose(file_handle_out);
    // PrintFormat("SaveLogToFile - %s file was write", LogFileName);
    return true;
   }
  else
    PrintFormat("Failed to open %s file, Error code = %d", LogFileName, GetLastError());
  return false;
 }

//+------------------------------------------------------------------+
//| SetLogFileName                                                   |
//+------------------------------------------------------------------+
void SetLogFileName()
 {
  MqlDateTime mqlTime;
  TimeCurrent(mqlTime);
  string eaName = CamelCaseToSnakeCase(EXPERTNAME);
  string newLogFileName = StringFormat("%s/log_%04d%02d%02d.txt", eaName, mqlTime.year, mqlTime.mon, mqlTime.day);
  if(newLogFileName != LogFileName)
   {
    LogFileName = newLogFileName;
    AddCommentOnChart("Log Salvo em Arquivo -> Abrir pasta de dados -> MQL5/Files/" + LogFileName, 3);
   }
 }

//+------------------------------------------------------------------+
//| CamelCaseToSnakeCase                                             |
//+------------------------------------------------------------------+
string CamelCaseToSnakeCase(string s)
 {
  string result = "";
  for(int i = 0; i < StringLen(s); i++)
   {
    string c = StringSubstr(s, i, 1);
    string lower_c = c;
    StringToLower(lower_c);
    if(c != lower_c && i != 0)
     {
      result += "_";
     }
    result += lower_c;
   }
  return result;
 }

//+------------------------------------------------------------------+
//| GetOrderProfit                                                   |
//+------------------------------------------------------------------+
double GetOrderProfit(long ticketid)
{
    long   deal_ticket = FindDealOutByTicketId(ticketid);
    int    tries  = 0;
    double profit = 0;

    while(tries < 50 && profit == 0){
      if(PositionSelectByTicket(ticketid))
        profit = PositionGetDouble(POSITION_PROFIT);
      else if(deal_ticket != INVALID_HANDLE)
        profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);             
      tries++; 
    }
    //Print("Sleep Tries Get Profit: " + (SleepTries * tries)); 
    Sleep(SleepTries * tries);
    return profit;
}

//+------------------------------------------------------------------+
//| GetOrderPriceClose                                               |
//+------------------------------------------------------------------+
double GetOrderPriceClose(long ticketid)
{
    int tries = 0;
    double price = 0;

    while(tries < 50 && price == 0){
    // Primeiro, tentamos selecionar a posição pelo ticket
      // Se a posição não for encontrada, procuramos no histórico de negócios
      long deal_ticket = FindDealOutByTicketId(ticketid);
      if(deal_ticket != INVALID_HANDLE)
        // Se encontrarmos um negócio de fechamento para a posição, retornamos o lucro do negócio
        price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);

    tries++;  
    Sleep(SleepTries * tries);
    }

    // Se não encontrarmos a posição nem no conjunto de posições abertas nem no histórico, retornamos 0
    Print("Sleep Tries Price Close: " + IntegerToString(SleepTries * tries));
    return price;
}
//+------------------------------------------------------------------+
//| GetOrderPriceClose                                               |
//+------------------------------------------------------------------+
double GetOrderPriceOpen(long ticketid)
{
    int tries = 0;
    double price = 0;

    while(tries < 50 && price == 0){
    // Primeiro, tentamos selecionar a posição pelo ticket
      // Se a posição não for encontrada, procuramos no histórico de negócios
      long deal_ticket = FindDealInByTicketId(ticketid);
      if(deal_ticket == INVALID_HANDLE)
        // Se encontrarmos um negócio de fechamento para a posição, retornamos o lucro do negócio
        price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);

    tries++;  
    Sleep(SleepTries * tries);
    }

    // Se não encontrarmos a posição nem no conjunto de posições abertas nem no histórico, retornamos 0
    Print("Sleep Tries Price Open: " + IntegerToString(SleepTries * tries));
    return price;
}

//+------------------------------------------------------------------+