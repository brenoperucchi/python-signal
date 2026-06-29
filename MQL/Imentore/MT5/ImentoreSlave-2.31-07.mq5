//+------------------------------------------------------------------+
// #property version "2.31"

#define VERSION "2_31"
#define VERSION_UPDATE "07"
#define VERSION_LOCAL "04"

#define APPNAME "Imentore Slave"
#define APPVERSION "2.31"

#define EXPERTNAME "imentore_slave"
#define EXPERTKIND "slave"

#property copyright "Update " + VERSION_UPDATE + " - Copyright IMENTORE.COM"
#property description "Breno Perucchi"
#property strict

//+-Includes--------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/TerminalInfo.mqh>
//#include <JAson.mqh>
#include <ImentoreLib_11.mqh>
#include <ImentoreSettings.mqh>

//+--Objects--------------------------------------------------------------------+
CTrade trade;
CTerminalInfo cterminal;
Settings* AppSettings = Settings::Instance();

//+-Input-----------------------------------------------------------------------+
input bool InputEnvironmentLocal = true;   // Admin only (default is false)
input bool iOrderModifySendChange = true; // Send Change Order to Server (default is true)

long Slippage = 30;            // Spread for price
ulong MaxSeconds = 30;         // Time Max Operation - limit for waiting open a order (default is 30)
double PercentLots = 100;      // Lots Percent from Signal (Default is 100)
double MaxLots = 0.00;         // Limit the maximum lots (Default is 0.00)
bool EnvironmentLocal = false; // EnvironmentLocal - Admin only (default is false)


//+--Globales Order--------------------------------------------------------------+
bool order_allowopen = true;
bool order_allowclose = true;
bool order_allowmodify = true;
bool order_invert = false;
double account_minmarginfree = 0.00;
// long   order_slippage          = 0;
int SleepTimer = 2;
int TimeCurrentTimer = int(TimeLocal());
int TimeCurrentTick = int(TimeLocal());
int TimeCurrentLocal = int(TimeLocal());

datetime TimeCurrentReachMfe = TimeTradeServer();
// datetime  TimeCurrentReachMfe  = TimeCurrent() - 86400;

const string DEFAULT_TIME = "1970.01.01 00:00:00";
datetime OrdersHistoryStart, OrdersHistoryEnd;

//+------------------------------------------------------------------+
//| Struct Order Container                                           |
//+------------------------------------------------------------------+
struct OrderStruct
{
  ulong ticketMaster;
  ulong ticketSlave;
  ulong ticketDeal;
  long trace_id;
  long slave_id;
  long magicnumber;
  long transaction_id;
  long slip_page;
  long digits;
  long type;
  long entry;
  double profit;
  double price_open;
  double price_close;
  double lot;
  double fees;
  double stop_loss;
  double take_profit;
  double contract_volume;
  string state;
  string symbol;
  string comment;
  ulong seconds_ago;
  string open_at;
  string closed_at;
  string time_gmt;
  string time_trader;
  string timezone;
  long created_at;
};

//+------------------------------------------------------------------+
//|Initialization function                                           |
//+------------------------------------------------------------------+
int OnInit(){  
  AppSettings.appName               = APPNAME;
  AppSettings.appVersion            = APPVERSION;
  AppSettings.appVersionLocal       = VERSION_LOCAL;
  AppSettings.appVersionUpdate      = VERSION_UPDATE;        
  AppSettings.appExpertKind         = EXPERTKIND;
  AppSettings.appExpertName         = EXPERTNAME;
  AppSettings.appMilliSecondsTimer  = 2400;
  AppSettings.appMilliSecondsTicker = 2400;
  AppSettings.appEnvironmentLocal   = InputEnvironmentLocal; 
  AppSettings.appMaxSeconds         = 30;
  AppSettings.appSlipPage           = 30;
  AppSettings.apiVersion            = "v2";
  
  EventSetMillisecondTimer(AppSettings.appMilliSecondsTimer);
  
  SetLogFileName();
  SetCommentImentore(true, true);
  
  AddCommentOnChart(AppSettings.accountName + " - " + AppSettings.accountLogin + " - " + AppSettings.accountServerName + " - " + AccountMarginMode() + " - " + ((EnvironmentLocal || InputEnvironmentLocal) ? "Local" : "Produção"), 3);
  
  if (DetectEnvironment() == false){
    AddCommentOnChart("Expert " + StringToCameCase(AppSettings.appExpertName) + " não inicializado. Contacte o SUPORTE.", 4);
    return (INIT_FAILED);
  } else {
    AddCommentOnChart("Expert " + StringToCameCase(AppSettings.appExpertName) + " inicializado com SUCESSO", 4);    
    TrasmitOrdersHistory();
    return (INIT_SUCCEEDED);
    
  }
}

//+------------------------------------------------------------------+
void OnTick(){
  SetCommentImentore();
  EventsOnSeconds();     // Periodically check if OrdersStruct is up-to-date
  CheckAnotherDay();

  int timeAgo = int(TimeLocal() - TimeCurrentTick);
  int timeAgo2 = int(TimeLocal() - TimeCurrentLocal);

  if (timeAgo2 >= 3600){
    CheckTimeDiscrepancy();
    TimeCurrentLocal = int(TimeLocal());
  }

  if (EventOnTick && (timeAgo * 1000 >= MilliSecondsTick)){
    TimeCurrentTick = int(TimeLocal());
    if (DebugMode){
      SendLogFileToServer();
      if (DebugModeLevel > 2){
        string message = ("OnTick - " + TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS));
        Print(message);
        SaveLogToFile(message);
      }
    }
    if (!CheckServerInformations())
      ExpertRemove();

    OrdersExecute();
    CheckFreeze();
  }
}

//+------------------------------------------------------------------+
void OnTimer()
{
  CheckAnotherDay();
  EventsOnSeconds();

  if (EventOnTimer){
    OrdersExecute();
    CheckFreeze();
    SetLogFileName();

    if (DebugMode && DebugModeLevel > 2){
      string message = ("OnTimer - " + TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS));
      Print(message);
      SaveLogToFile(message);
    }
  }

  if (DebugMode)
    SendLogFileToServer();

  if (!CheckServerInformations())
    ExpertRemove();

  // UpdateOrdersHistory();
}


//+------------------------------------------------------------------+
void CheckAnotherDay(){
  // Obter a data e hora atual do servidor
  datetime currentTime = TimeTradeServer();

  MqlDateTime currentDateTime;
  TimeToStruct(currentTime, currentDateTime); // Converter para estrutura de data/hora

  MqlDateTime lastDateTime;
  TimeToStruct(TimeCurrentReachMfe, lastDateTime); // Converter última data de AppSettings.ReachMfeTargetBool

  // Verificar se mudou o dia
  if (currentDateTime.day != lastDateTime.day){
    AddCommentOnChart("CheckAnotherDay - change day: " + IntegerToString(lastDateTime.day) + " to: " + IntegerToString(currentDateTime.day));
    // AppSettings.ReachMfeTargetBool = false;
    // AppSettings.ReachLossSetBool = false;
    AppSettings.appReachProfitDay = 0;
    AppSettings.appReachLossDay = 0;
    TimeCurrentReachMfe = currentTime; // Atualizar a última data de verificação
  }
}

//+------------------------------------------------------------------+
void EventsOnSeconds(){
  static datetime last60seconds = 0;
  static datetime last02seconds = 0;
  datetime now = TimeCurrent();
  
  if (now - last02seconds > 02){
    SetLogFileName();
    last02seconds = now;
  }

  if (now - last60seconds > 60)
  { // Check every 60 seconds
    HistorySelect(0, TimeCurrent());
    
    //REMOVER 
    TrasmitOrdersHistory();
     
    if (HistoryOrders.Total() != HistoryDealsTotal() -1)
      TrasmitOrdersHistory();
      
    last60seconds = now;  
  }
  
  // check should close all positions
  if(DebugMode && CloseAllOrders)
    CloseAllPositionOrders();  
}


//+------------------------------------------------------------------+
double CalculateProfitTotalByOrdersHistory(){
  double profit = 0;
  for (int i = 0; i < HistoryOrders.Total(); i++)
  {
    OrderObj *order = (OrderObj *)HistoryOrders.At(i);
    if(StringLen(order.comment) > 0 && order.magicNumber != 0 && order.entry != DEAL_ENTRY_IN)
      profit += order.profit;
  }

  return profit; // Add a return statement here
}


//+------------------------------------------------------------------+
void SetCommentImentore(bool print_log = false, bool set_log = false){
  // MqlDateTime currentDateTime;
  // TimeToStruct(currentTime, currentDateTime); // Converter para estrutura de data/hora
  string datetime_now = TimeToString(TimeTradeServer(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
  string message = StringFormat("Iniciando Expert %s %s - Update %s - Date: %s", StringToCameCase(AppSettings.appExpertName), AppSettings.appVersion, AppSettings.appVersionUpdate, datetime_now);
  if (InputEnvironmentLocal || EnvironmentLocal)
    message += " - LocalVersion: " + AppSettings.appVersionLocal;
  AddCommentOnChart(message, 1, print_log, set_log);
}

//+------------------------------------------------------------------+
//| Get all of the orders                                            |
//+------------------------------------------------------------------+
string SetLogInfo(OrderStruct &order, int lastError, uint retcode, string resultComment, int attempt, string action){
  string logMessage = StringFormat("#%s - Ticket: %s - Log Info - LastError: %d - Retcode: %u - ResultComment: %s - Attempt: %d",
                                   order.comment,
                                   IntegerToString(order.ticketSlave),
                                   lastError,
                                   retcode,
                                   resultComment,
                                   attempt);

  // Adiciona informação sobre o lucro se a ação for 'CLOSED'
  if ((action == "CLOSED") || (action == "HASCLOSED")){
    order.profit = GetOrderProfit(order);
    logMessage += StringFormat(" - Profit: %.2f", order.profit);
  }
  return logMessage;
}

//+------------------------------------------------------------------+
//| Get all of the orders                                            |
//+------------------------------------------------------------------+
int OrdersExecute(){
  OrderStruct orders[];
  UpdateOrderStruct(orders);

  int orders_size = ArraySize(orders);
  int changed_ticket = 0;

  for (int i = 0; i < orders_size; i++){
    if (orders[i].state == "pending")
      changed_ticket = PushOrderOpen(orders[i]);
    else if (orders[i].state == "executed")
      changed_ticket += PushOrderModify(orders[i]);
    else if (orders[i].state == "remove")
      changed_ticket += PushOrderClosed(orders[i]);
  }
  CheckOrdersClosed(orders);
  CheckOrdersDuplicate();
  CheckTargetsAndCloseTrades(orders);
  return changed_ticket;
}

//+------------------------------------------------------------------+
//| Push the open order to all of the subscriber                     |
//+------------------------------------------------------------------+
int PushOrderOpen(OrderStruct &order){
  int changed = 0;
  bool change = MakeOrder(order, "OPEN");
  change ? (changed++) : changed;
  return changed;
}

//+------------------------------------------------------------------+
//| Push the modify order to all of the subscriber                   |
//+------------------------------------------------------------------+
int PushOrderModify(OrderStruct &order){
  int   changed       = 0;
  int   symbol_digit  = (int)SymbolInfoInteger(order.symbol, SYMBOL_DIGITS);
  long  ticketid      = FindOpenOrderByComment(order.comment);
  bool  orderchanged  = false;
  bool  position      = PositionSelectByTicket(ticketid);
  string comment      = PositionGetString(POSITION_COMMENT);
  
  string comment_modify_stop_loss, comment_modify_take_profit, comment_modify_volume;

  if (ticketid != -1 && iOrderModifySendChange){
    if (comment == order.comment){
      if (CompareDoubles(PositionGetDouble(POSITION_SL), order.stop_loss)){
        orderchanged = true;
        comment_modify_stop_loss += AttributeChangeString(order.comment, ticketid, "stop_loss", PositionGetDouble(POSITION_SL), order.stop_loss, order.symbol);

        if (StringLen(comment_modify_stop_loss) > 0)
          AddCommentOnChart(comment_modify_stop_loss);
      }

      if (CompareDoubles(PositionGetDouble(POSITION_TP), order.take_profit)){
        orderchanged = true;
        comment_modify_take_profit += AttributeChangeString(order.comment, ticketid, "take_profit", PositionGetDouble(POSITION_TP), order.take_profit, order.symbol);

        if (StringLen(comment_modify_take_profit) > 0)
          AddCommentOnChart(comment_modify_take_profit);
      }

      double lot = PositionGetDouble(POSITION_VOLUME);

      if (CompareDoubles(lot, order.lot)){
        orderchanged = true;
        comment_modify_volume += AttributeChangeString(order.comment, ticketid, "volume", lot, order.lot, order.symbol);

        if (StringLen(comment_modify_volume) > 0)
          AddCommentOnChart(comment_modify_volume);
      }

      if (CompareDoubles(lot, order.lot)){ // Only Netting Accounts
        bool change = MakeOrder(order, "MODIFY_VOLUME");
        change ? (changed++) : 0;
      }

      if (orderchanged == true){
        // vprice = GetRandomPrice(symbol, vtype);  // open price
        order.stop_loss = CalculatePips(PositionGetDouble(POSITION_PRICE_OPEN), DoubleToString(order.stop_loss, symbol_digit), order.type, order.symbol);
        order.take_profit = CalculatePips(PositionGetDouble(POSITION_PRICE_OPEN), DoubleToString(order.take_profit, symbol_digit), order.type, order.symbol);

        bool change = MakeOrder(order, "MODIFY");

        if (change)
          changed++;
      }
    }
  }
  // else if (FindCloseOrderByComment(order.comment) && order.state == "executed")
  else if (FindOrdersHistoryByCommentBool(order.comment) && order.state == "executed")
    PushOrderClosed(order);

  return changed;
}

//+------------------------------------------------------------------+
//| Push the close order to all of the subscriber                    |
//+------------------------------------------------------------------+
int PushOrderClosed(OrderStruct &order)
{
  int changed = 0;
  changed = MakeOrder(order, "CLOSED");

  return changed;
}

//+------------------------------------------------------------------+
//| Make a order by signal message (Market and Pending Order)        |
//+------------------------------------------------------------------+
bool MakeOrder(OrderStruct &order, const string action)
{
  ulong ticketid = order.ticketSlave;

  if (ticketid <= 0)
  {
    ticketid = FindOpenOrderByComment(order.comment);
    order.ticketSlave = ticketid;
  }

  bool orderstatus = false;

  if (order.trace_id <= 0 || order.symbol == "")
    return false;

  if (!cterminal.IsConnected())
  {
    AddCommentOnChart("Conexão com o servidor perdida. Por favor, verifique a conexão com a internet.");
    SymbolSelect(order.symbol, false);
  }

  SymbolSelect(order.symbol, true);
  MqlTradeResult result = {};
  MqlTradeRequest request = {};
  ZeroMemory(request);
  ZeroMemory(result);
  ResetLastError();

  if (action == "OPEN")
  {
    ticketid = MakeOrderOpen(result, request, order, action);
    if (ticketid > 0)
      orderstatus = true;
  }
  else

      if (action == "CLOSED")
  {
    orderstatus = MakeOrderClose(result, request, order, action);
  }
  else

      if (action == "MODIFY")
  {
    orderstatus = MakeOrderModify(result, request, order, action);
  }

  if (action == "MODIFY_VOLUME")
  {
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
  if (order_allowopen == false || order.symbol == "")
    return ticketid;

  // Allow Expert Advisor to open the order
  if (cterminal.IsTradeAllowed() == false)
    return ticketid;

  // Check if account margin free is less than settings
  if (account_minmarginfree > 0.00 && AccountInfoDouble(ACCOUNT_MARGIN_FREE) < account_minmarginfree)
    return ticketid;

  double vprice = 0;
  double vsl = order.stop_loss;
  double vtp = order.take_profit;
  double vlots = GetOrderLots(order.symbol, order.lot, order.contract_volume);
  long vtype = order.type;

  // The parameter price must be greater than zero
  if (vprice <= 0.00)
  {
    MqlTick last_tick;
    SymbolInfoTick(symbol, last_tick);
    if (vtype == 0)
      vprice = SymbolInfoDouble(symbol, SYMBOL_ASK);
    if (vtype == 1)
      vprice = SymbolInfoDouble(symbol, SYMBOL_BID);
  }

  // vprice = GetRandomPrice(symbol, vtype);  // open price
  double sl = CalculatePips(vprice, DoubleToString(vsl, int(SymbolInfoInteger(symbol, SYMBOL_DIGITS))), vtype, symbol);
  double tp = CalculatePips(vprice, DoubleToString(vtp, int(SymbolInfoInteger(symbol, SYMBOL_DIGITS))), vtype, symbol);
  // DoubleToString();Symbo
  // Invert the origional order
  if (order_invert)
  {
    switch (int(vtype))
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
  request.symbol = symbol;           // símbolo
  request.volume = vlots;            // volume de 0.2 lotes
  request.price = vprice;            // preço para a abertura
  request.deviation = Slippage;      // desvio permitido do preço
  request.magic = order.magicnumber; // MagicNumber da ordem
  request.sl = sl;
  request.tp = tp;
  request.comment = order.comment;

  switch (int(vtype))
  {
  case 0:
    request.action = TRADE_ACTION_DEAL; // tipo de operação de negociação
    request.type = ORDER_TYPE_BUY;      // tipo da ordem
    break;
  case 1:
    request.action = TRADE_ACTION_DEAL; // tipo de operação de negociação
    request.type = ORDER_TYPE_SELL;     // tipo da ordem
    break;
  case 2:
    request.action = TRADE_ACTION_PENDING; // tipo de operação de negociação
    request.type = ORDER_TYPE_BUY_LIMIT;   // tipo da ordem
    request.type_filling = ORDER_FILLING_FOK;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.price_open; // preço para a abertura
    break;
  case 3:
    request.action = TRADE_ACTION_PENDING; // tipo de operação de negociação
    request.type = ORDER_TYPE_SELL_LIMIT;  // tipo da ordem
    request.type_filling = ORDER_FILLING_FOK;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.price_open; // preço para a abertura

    break;
  case 4:
    request.action = TRADE_ACTION_PENDING; // tipo de operação de negociação
    request.type = ORDER_TYPE_BUY_STOP;    // tipo da ordem
    request.type_filling = ORDER_FILLING_RETURN;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.price_open; // preço para a abertura
    request.stoplimit = 0;
    break;
  case 5:
    request.action = TRADE_ACTION_PENDING; // tipo de operação de negociação
    request.type = ORDER_TYPE_SELL_STOP;   // tipo da ordem
    request.type_filling = ORDER_FILLING_RETURN;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.price_open; // preço para a abertura
    request.stoplimit = 0;
    break;
  case 6:
    request.action = TRADE_ACTION_PENDING;    // tipo de operação de negociação
    request.type = ORDER_TYPE_BUY_STOP_LIMIT; // tipo da ordem
    request.type_filling = ORDER_FILLING_FOK;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.price_open; // preço para a abertura
    break;
  case 7:
    request.action = TRADE_ACTION_PENDING;     // tipo de operação de negociação
    request.type = ORDER_TYPE_SELL_STOP_LIMIT; // tipo da ordem
    request.type_filling = ORDER_FILLING_FOK;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.price_open; // preço para a abertura
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
  long ticket_slave = FindOpenOrderByComment(order.comment);
  // bool ticket_closed = FindCloseOrderByComment(order.comment);
  bool checkTicketClosed = FindOrdersHistoryByCommentBool(order.comment);

  string meta_state;
  long close_result = 0;

  if ((order.ticketSlave < 1 && ticket_slave > 0) || (PositionSelectByTicket(order.ticketSlave) == false))
    order.ticketSlave = ticket_slave;

  // Allow signal to close the order
  // The parameter ticketid must be greater than zero
  if (order_allowclose == false) // || order.ticketSlave <= 0)
    return close_result;

  // Allow Expert Advisor to close the order
  if (cterminal.IsTradeAllowed() == false)
    return close_result;

  PositionSelectByTicket(order.ticketSlave);

  switch (int(order.type))
  {
  case ORDER_TYPE_BUY_LIMIT:
  case ORDER_TYPE_BUY_STOP:
  case ORDER_TYPE_BUY_STOP_LIMIT:
  case ORDER_TYPE_SELL_LIMIT:
  case ORDER_TYPE_SELL_STOP:
  case ORDER_TYPE_SELL_STOP_LIMIT:
    close_result = trade.OrderDelete(order.ticketSlave);
    break;

  default:
    request.action = TRADE_ACTION_DEAL;                  // type of trade operation
    request.position = order.ticketSlave;               // ticket of the position
    request.symbol = order.symbol;                       // symbol
    request.volume = PositionGetDouble(POSITION_VOLUME); // volume of the position
    request.deviation = Slippage;                        // allowed deviation from the price
    request.comment = order.comment;
    request.magic = order.magicnumber;
    request.type_filling = ORDER_FILLING_IOC;

    //--- set the price and order type depending on the position type
    if (order.type == POSITION_TYPE_BUY)
    {
      request.price = SymbolInfoDouble(order.symbol, SYMBOL_BID);
      request.type = ORDER_TYPE_SELL;
    }
    else
    {
      request.price = SymbolInfoDouble(order.symbol, SYMBOL_ASK);
      request.type = ORDER_TYPE_BUY;
    }

    if (order.ticketSlave == -1 && !checkTicketClosed)
    {
      result.retcode = 94016;
      result.comment = "Not Find for Closed";
      meta_state = "NOTFIND";
      close_result = INVALID_HANDLE;
    }
    else if (checkTicketClosed && FindOpenOrderByComment(order.comment) == INVALID_HANDLE && (!AppSettings.ReachMfeTargetBool() && !AppSettings.ReachLossSetBool()))
    {
      PosCheckOrderAlreadyClosed(order, request, result);
      meta_state = "HASCLOSED";
      close_result++;
    }
    else
    {
      close_result = OrderSend(request, result);
      HistorySelect(0, TimeCurrent());

      if (close_result)
        meta_state = "CLOSED";
      else
        meta_state = "NOTCLOSED";

      // if(order.price_open == 0)
      //   order.price_open  = HistoryDealGetDouble(order.ticket_deal, DEAL_PRICE);
      order.ticketDeal = long(result.deal);
      order.price_close = result.price;
      order.closed_at = TimeToString(HistoryDealGetInteger(order.ticketDeal, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
      close_result++;
    }

    if (meta_state != "NOTFIND")
    {
      if (order.price_open <= 0.0)
        order.price_open = GetOrderPriceOpen(order.comment, order.ticketSlave);

      if (order.price_close <= 0.00)
        order.price_close = GetOrderPriceClose(order.comment, order.ticketSlave);

      // If order.open_at is not set or has a default value, fetch the actual opening time
      if (order.open_at == DEFAULT_TIME || StringLen(order.open_at) == 0)
        order.open_at = GetOrderOpenAt(order.comment, order.ticketSlave);
    }
  }

  string log_message = SetLogInfo(order, GetLastError(), result.retcode, result.comment, 0, meta_state);

  if (AppSettings.ReachMfeTargetBool() || AppSettings.ReachLossSetBool())
  {
    // result.retcode = AppSettings.ReachMfeTargetBool ? 90090 : 90091;
    // meta_state = AppSettings.ReachMfeTargetBool ? "REACHMFE" : "REACHLOSS";
    string reach_state = AppSettings.ReachMfeTargetBool() ? "MfeTarget" : "LossSet";
    string reach_symbol = AppSettings.ReachMfeTargetBool() ? ">=" : "<=";
    string action_msg = StringFormat("#%s - %s: %s %s %s %s", order.comment, "ReachProfitDay", DoubleToString(AppSettings.appReachProfitDay, 2), reach_symbol, AppSettings.ReachMfeTargetBool() ? DoubleToString(AppSettings.appReachMfeTarget, 2) : DoubleToString(AppSettings.appReachLossSet, 2), reach_state);
    AddCommentOnChart(action_msg);
    log_message += " - MoreInfo:" + action_msg;
  }

  SendMessageToServer(result, request, order, action, order.state, meta_state, "MakeOrderClose", log_message);

  return close_result;
}

//+------------------------------------------------------------------+
//| Make a order modify by signal message                            |
//+------------------------------------------------------------------+
ulong MakeOrderModify(MqlTradeResult &result,
                     MqlTradeRequest &request,
                     OrderStruct &order,
                     string action){
  ulong change = -1;
  string meta_state;

  int symbol_digit = (int)SymbolInfoInteger(order.symbol, SYMBOL_DIGITS);
  long ticket_slave = FindOpenOrderByComment(order.comment);

  if ((order.ticketSlave < 1 && ticket_slave > 0) || (PositionSelectByTicket(order.ticketSlave) == false))
    order.ticketSlave = ticket_slave;

  // Allow signal to modify the order
  // The parameter ticketid must be greater than zero
  if (order_allowmodify == false || order.ticketSlave <= 0)
    return change;

  // Allow Expert Advisor to modify the order
  if (cterminal.IsTradeAllowed() == false)
    return change;

  if (FindOpenOrderByComment(order.comment) > 0)
  {
    change = trade.PositionModify(order.ticketSlave, order.stop_loss, order.take_profit);
  }

  result.comment = trade.ResultComment();
  result.retcode = trade.ResultRetcode();
  request.symbol = order.symbol;
  request.sl = order.stop_loss;
  request.tp = order.take_profit;
  meta_state = change ? "MODIFY" : "NOTMODIFY";
  change = change ? order.ticketSlave : INVALID_HANDLE;

  // string log_message = StringFormat("#%s - Log Info - LastError: %d - Retcode: %u - ResultComment: %s - Attempt: %d", order.comment, GetLastError(), result.retcode, result.comment, 0);
  string log_message = SetLogInfo(order, GetLastError(), result.retcode, result.comment, 0, action);

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
  if (order_allowmodify == false || order.ticketSlave <= 0)
    return change;

  // Allow Expert Advisor to modify the order
  if (cterminal.IsTradeAllowed() == false)
    return change;

  // if (FindCloseOrderByComment(order.comment) > 0)
  if(FindOrdersHistoryByCommentBool(order.comment))
  {
    change = trade.PositionClose(order.ticketSlave);
  }
  {
    result.retcode = 90013;
    return change;
  }
  {
    PositionSelectByTicket(long(order.comment));
    long magicnumber = PositionGetInteger(POSITION_MAGIC);

    if (order.lot > 0)
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
//| Check conditions before sending order                            |
//+------------------------------------------------------------------+
bool PreSendChecks(MqlTradeRequest &request, MqlTradeResult &result, OrderStruct &order)
{
  if (AccountMarginMode() == "HEDGING" && order.state != "pending")
  {
    return false;
  }

  // if (FindCloseOrderByComment(request.comment))
  if(FindOrdersHistoryByCommentBool(request.comment))
  {
    result.retcode = 90013;
    return false;
  }

  if (CheckOrderAlreadyOpen(request.comment) || AppSettings.ReachMfeTargetBool() || AppSettings.ReachLossSetBool())
  {
    result.retcode = 90016;
    return false;
  }

  ulong secondsAgo = MathAbs((int)order.created_at - (int)TimeGMT());
  if (order.seconds_ago >= MaxSeconds && secondsAgo >= MaxSeconds)
  {
    result.retcode = 90099;
    return false;
  }

  return true;
}

//+------------------------------------------------------------------+
void PosCheckOrderAlreadyClosed(OrderStruct &order, MqlTradeRequest &request, MqlTradeResult &result)
{
  // order.ticketSlave = FindCloseOrderByCommentLong(order.comment);
  order.ticketSlave = FindOrdersHistoryByCommentLong(order.comment);
  order.ticketDeal  = FindDealOutByTicketId(order.ticketSlave);
  order.closed_at   = TimeToString(HistoryDealGetInteger(order.ticketDeal, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
  order.price_close = HistoryDealGetDouble(order.ticketDeal, DEAL_PRICE);
  request.volume    = HistoryDealGetDouble(order.ticketDeal, DEAL_VOLUME);
  result.retcode    = 90013;
  result.comment    = "Manual Closed";
}

//+------------------------------------------------------------------+
//| Modify request based on action                                   |
//+------------------------------------------------------------------+
void ModifyRequestBasedOnAction(string action, MqlTradeRequest &request)
{
  if (action == "MODIFY_VOLUME")
  {
    double lot = PositionGetDouble(POSITION_VOLUME);
    request.volume -= lot;
  }
}

//+------------------------------------------------------------------+
//| Send order and handle results                                    |
//+------------------------------------------------------------------+
bool SendOrder(MqlTradeRequest &request, MqlTradeResult &result)
{
  if (!cterminal.IsConnected())
  {
    result.retcode = 10008; // "Not connected" error code
    return false;
  }
  return OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Process the order result                                         |
//+------------------------------------------------------------------+
void ProcessOrderResult(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string action, int count)
{
  string meta_state, action_msg;
  switch (result.retcode)
  {
  case 10009:
    meta_state = action;
    action_msg = "Order successfully processed";
    break;
  case 90099:
    meta_state = "TIMEMAX";
    action_msg = StringFormat("#%s - Time Max: %d >= %d MaxSeconds", order.comment, order.seconds_ago, MaxSeconds);
    break;
  case 90013:
    PosCheckOrderAlreadyClosed(order, request, result);
    meta_state = "HASCLOSED";
    action_msg = "Order has manual closed";
    break;
  case 90016:
    meta_state = "OPENED";
    action_msg = "Order already open";
    break;
  case 10016:
    meta_state = "NOSLTP";
    action_msg = "Ordem sem SL e/ou TP";
    break;
  case 10008: // Não conectado
    meta_state = "NOTCONNECTION";
    action_msg = "Não conectado à rede";
    break;
  default:
    meta_state = "ERRORDEAL";
    action_msg = "Error in order processing";
    break;
  }
  if (AppSettings.ReachMfeTargetBool() || AppSettings.ReachLossSetBool())
  {
    result.retcode = AppSettings.ReachMfeTargetBool() ? 90090 : 90091;
    meta_state = AppSettings.ReachMfeTargetBool() ? "REACHMFE" : "REACHLOSS";
    action_msg = StringFormat("#%s - %s: %s >= %s", order.comment, meta_state, DoubleToString(AppSettings.appReachProfitDay, 2), AppSettings.ReachMfeTargetBool() ? DoubleToString(ReachMfeTarget, 2) : DoubleToString(ReachLossSet, 2));
  }

  if (meta_state == "OPENED" || meta_state == "OPEN")
  {

    if (meta_state == "OPEN")
    {
      order.ticketSlave = long(result.order);
      order.ticketDeal = long(result.deal);
      order.price_open = result.price;
    }

    if (order.ticketSlave <= 0 && meta_state == "OPENED")
    {
      order.ticketSlave = FindOpenOrderByComment(order.comment);
      PositionSelectByTicket(order.ticketSlave);
      order.price_open = PositionGetDouble(POSITION_PRICE_OPEN);
    }

    if (order.ticketDeal <= 0)
      order.ticketDeal = FindOpenOrderByCommentDealTicket(order.comment);

    order.stop_loss = request.sl;
    order.take_profit = request.tp;
    order.lot = request.volume;
    order.open_at = GetOrderOpenAt(order.comment, order.ticketSlave);

    if (order.price_open == 0)
      order.price_open = PositionGetDouble(POSITION_PRICE_OPEN);
  }

  AddCommentOnChart(action_msg);

  string log_message = SetLogInfo(order, GetLastError(), result.retcode, result.comment, count, action);

  SendMessageToServer(result, request, order, action, order.state, meta_state, "OrderCreate", log_message);
}

//+------------------------------------------------------------------+
//| Main function to create an order                                 |
//+------------------------------------------------------------------+
long OrderCreate(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string action)
{
  ResetLastError();
  bool changes = false;
  long ticketId = -1;

  for (int count = 0; count <= 1; count++)
  {
    ModifyRequestBasedOnAction(action, request);
    changes = PreSendChecks(request, result, order);

    if (changes)
    {
      bool orderResult = SendOrder(request, result);
      if (orderResult)
        ticketId = long(result.order);
    }

    string actionMsg;
    ProcessOrderResult(result, request, order, action, count);
    if (count == 1 || (result.retcode == 90013 || result.retcode == 10008 || result.retcode == 10009 || result.retcode == 90099 || result.retcode == 90016 || result.retcode == 90090 || result.retcode == 90091))
      break;
  }
  return ticketId;
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
    string meta_message = "")
{
  // Get the number of digits for the symbol
  int symbol_digit = int(SymbolInfoInteger(order_symbol, SYMBOL_DIGITS));

  // Calculate the time zone offset
  long timezone = long((TimeLocal() - TimeGMT()) / 3600);

  // Format the message
  string message = StringFormat(
      "body={'account_login':'%s', 'magic_number':'%d', 'action':'%s', 'order_state':'%s', 'meta_state':'%s', 'ticket_slave_id':'%s', "
      "'ticket_master_id':'%s', 'ticket_deal':'%s', 'order_symbol':'%s', 'order_type':'%d', 'price_open':'%s', 'price_close':'%s', 'volume':'%s', "
      "'stop_loss':'%s', 'take_profit':'%s', 'profit':'%s', 'comment':'%s', 'open_at':'%s', 'closed_at':'%s', 'timezone':'%d', 'time_trader':'%s', 'time_gmt':'%s', 'meta_message':'%s'}",
      AppSettings.accountLogin,
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
      meta_message);

  return message;
}

//+------------------------------------------------------------------+
bool TrasmitOrdersHistory()
{
  bool change = false;

  UpdateHistoryOrders();
  string jason_message = OrdersToJSON(HistoryOrders, "HistoryOrders");
  change = ApiTransmitData("orders_history", jason_message);

  return change;  
}

//+------------------------------------------------------------------+
void UpdateHistoryOrdersStruct(OrderStruct &OrdersStruct[])
{
  double profit = 0;

  int timeDay = 24 * 60 * 60;
  // datetime startMonth = iTime(_Symbol, PERIOD_MN1, 1);
  // datetime endMonth   = iTime(_Symbol, PERIOD_MN1, 0) - timeDay;;
  // HistorySelect(startMonth, endMonth);
  HistorySelect(0, TimeCurrent());

  int total_orders = HistoryDealsTotal();
  int countOrders = 0;

  for (int i = 0; i < total_orders; i++)
  {
    ulong deal_ticket = HistoryDealGetTicket(i);
    ulong deal_position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
    datetime orderTime = datetime(HistoryDealGetInteger(deal_ticket, DEAL_TIME));
    ulong ticket_id = deal_position_id;
    ulong deal_ticket_in = FindDealInByTicketId(deal_position_id);

    ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);

    // bool comment = HistoryDealGetString(deal_ticket_in, DEAL_COMMENT);
    long magic_number = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);

    // if (entry_type == DEAL_ENTRY_IN)
    //   continue;

    countOrders =+ 1;
    ArrayResize(OrdersStruct, countOrders);

    string symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
    string aTicketId = IntegerToString(ticket_id);

    long order_type = HistoryDealGetInteger(deal_ticket_in, DEAL_TYPE);
    double price_open = HistoryDealGetDouble(deal_ticket_in, DEAL_PRICE);
    double price_close = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);

    int symbol_digit = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
    string vsl = DoubleToString(HistoryDealGetDouble(deal_ticket, DEAL_SL), symbol_digit);
    string vtp = DoubleToString(HistoryDealGetDouble(deal_ticket, DEAL_TP), symbol_digit);

    OrderStruct order_deal;

    order_deal.lot = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
    order_deal.comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);

    OrdersStruct[i].symbol        = symbol;
    OrdersStruct[i].ticketSlave   = long(ticket_id);  
    OrdersStruct[i].ticketDeal    = FindDealInByTicketId(long(ticket_id));
    OrdersStruct[i].type          = order_type;
    OrdersStruct[i].entry         = entry_type;
    OrdersStruct[i].price_open    = price_open;
    OrdersStruct[i].price_close   = price_close;
    OrdersStruct[i].digits        = symbol_digit;
    OrdersStruct[i].lot           = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
    OrdersStruct[i].profit        = GetOrderProfit(order_deal);
    OrdersStruct[i].fees          = GetFeesOrderHistory(deal_ticket);
    OrdersStruct[i].stop_loss     = NormalizeNumber(vsl, symbol);
    OrdersStruct[i].take_profit   = NormalizeNumber(vtp, symbol);
    OrdersStruct[i].open_at       = TimeToString(HistoryDealGetInteger(deal_ticket_in, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    OrdersStruct[i].closed_at     = TimeToString(HistoryDealGetInteger(deal_ticket, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    OrdersStruct[i].time_gmt      = TimeToString(TimeGMT(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    OrdersStruct[i].time_trader   = TimeToString(TimeTradeServer(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    OrdersStruct[i].timezone      = string((TimeLocal() - TimeTradeServer()) / 3600);
    OrdersStruct[i].magicnumber   = HistoryDealGetInteger(deal_ticket_in, DEAL_MAGIC);
    OrdersStruct[i].state         = "closed";
    OrdersStruct[i].comment       = HistoryDealGetString(deal_ticket_in, DEAL_COMMENT);
  }
}

//+------------------------------------------------------------------+
int UpdateOrderStruct(OrderStruct &orders[])
{
  string orderdata[];
  if (!ApiRequestInformation(orderdata, "orders"))
    return -1; // error code indicating API request failed

  int orderdataCount = ArraySize(orderdata);
  if (orderdataCount == 0)
    return -2; // error code indicating no order data

  ArrayResize(orders, orderdataCount);
  for (int i = 0; i < orderdataCount; i++)
  {
    string orderdataparse[];
    if (!ParseMessage(orderdata[i], orderdataparse))
      return -3; // error code indicating parsing failed

    if (ArraySize(orderdataparse) < 17) // check for sufficient data
      return -4;                        // error code indicating insufficient data

    // double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

    orders[i].type = StringToInteger(orderdataparse[0]);
    orders[i].ticketMaster = StringToInteger(orderdataparse[1]);
    orders[i].ticketSlave  = StringToInteger(orderdataparse[2]);
    orders[i].ticketDeal   = StringToInteger(orderdataparse[13]);
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
    orders[i].created_at = StringToInteger(orderdataparse[16]);
    orders[i].open_at = "";
    orders[i].closed_at = "";
    orders[i].contract_volume = StringToDouble(orderdataparse[17]);
    orders[i].profit = 0;
  }

  return 0; // return 0 indicating success
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetDigits(double num)
{
  int d = 0;
  double p = 1;
  while (MathRound(num * p) / p != num)
  {
    p = MathPow(10, ++d);
  }
  return d;
}

//+------------------------------------------------------------------+
//| SendMessageToServer                                              |
//+------------------------------------------------------------------+
void SendMessageToServer(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string const action, string const state, string const meta_state, const string fuction_name, string log_message)
{
  int symbol_digit = int(SymbolInfoInteger(request.symbol, SYMBOL_DIGITS));
  string meta_message = StringFormat("#%s - Ticket: %s - %s - Symbol: %s - Type: %s  - Volume: %s - TP: %s - SL: %s - Action: %s - Meta State: %s", order.comment, IntegerToString(order.ticketSlave), fuction_name, order.symbol, IntegerToString(order.type), DoubleToString(order.lot, 2), DoubleToString(request.tp, symbol_digit), DoubleToString(request.sl, symbol_digit), ToUpperCase(action), meta_state);

  AddCommentOnChart(meta_message);
  AddCommentOnChart(log_message);

  if (order.profit == 0.0)
    order.profit = GetOrderProfit(order);

  string message_format = MessageSendFormat(request.magic, action, state, meta_state, order.ticketSlave, order.ticketMaster, order.ticketDeal, order.symbol, order.type, order.price_open, order.price_close, order.lot, order.stop_loss, order.take_profit, order.profit, order.comment, order.open_at, order.closed_at, (meta_message + " - LogMessage: " + log_message));

  ApiTrasmitInformation(message_format, meta_state);
}

//+------------------------------------------------------------------+
//| Parse the message from server signal                             |
//+------------------------------------------------------------------+
bool ParseMessage(const string message,
                  string &orderdataparse[])
{
  if (message == "")
    return false;

  int size = StringSplit(message, '|', orderdataparse);
  return true;
}

//+------------------------------------------------------------------+
//| Get the order lots is greater than or less than max and min lots |
//+------------------------------------------------------------------+
double GetOrderLots(const string symbol, double lots, double contract_volume)
{
  double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

  if (contract_volume == 0.0)
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

  for (int i = 0; i < orders_size; i++)
  {
    if (orders[i].comment == ticketid)
      return i;
  }
  return INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Find a current order by server signal                            |
//+------------------------------------------------------------------+
long FindOpenOrderByComment(string comment)
{
  ulong ticket;

  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong order_ticket = PositionGetTicket(i);
    if (order_ticket > 0)
    {

      string cc = PositionGetString(POSITION_COMMENT);
      if (PositionGetString(POSITION_COMMENT) == comment)
      {
        ticket = order_ticket;
        return long(order_ticket);
        // break;  // Quando a ordem desejada for encontrada, interrompa o loop
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
  for (int i = HistoryDealsTotal(); i > 0; i--)
  {
    deal_ticket = (long)HistoryDealGetTicket(i);
    int entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    ulong ticket = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

    string comment_history = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
    // string comment_history = HistoryOrderGetString(ticket, ORDER_COMMENT);
    if ((entry_type == DEAL_ENTRY_IN || entry_type == DEAL_ENTRY_INOUT) && comment == comment_history)
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
  for (int i = HistoryDealsTotal(); i > 0; i--)
  {
    ulong deal_ticket = HistoryDealGetTicket(i);
    int entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    ulong ticket = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

    string comment_history = HistoryOrderGetString(ticket, ORDER_COMMENT);
    if (entry_type != DEAL_ENTRY_IN && comment == comment_history)
      return true;
  }
  return changed;
}
//+------------------------------------------------------------------+
//| FindCloseOrderByCommentLong                                      |
//+------------------------------------------------------------------+
// long FindCloseOrderByCommentLong(const string comment)
long FindCloseOrderByCommentLong(const string comment)
{

  bool changed = false;
  HistorySelect(0, TimeCurrent());
  for (int i = HistoryDealsTotal(); i > 0; i--)
  {
    long deal_ticket = long(HistoryDealGetTicket(i));
    int entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    long ticket = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

    string comment_history = HistoryOrderGetString(ticket, ORDER_COMMENT);
    if (entry_type != DEAL_ENTRY_IN && comment == comment_history)
      return ticket;
  }
  return INVALID_HANDLE;
}


//+------------------------------------------------------------------+
double CalculatePips(double vprice, string snumber, long vtype, string symbol)
{
  // Obtenha o número de dígitos e o ponto para o símbolo fornecido
  int vdigits = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  double vpoint = SymbolInfoDouble(symbol, SYMBOL_POINT);
  double number = StringToDouble(snumber);
  double rnumber = 0;

  // Caso especial para snumber igual a "0"
  if (snumber == "0")
  {
    return rnumber;
  }

  // Ajuste vpoint de acordo com vdigits
  if (vdigits == 0 || vdigits == 1)
  {
    vpoint = 1;
  }
  else
  {
    vpoint = MathPow(10, -vdigits + 1);
  }

  // Calcule a diferença entre number e vprice, ajustada por vpoint
  rnumber = ((number - vprice) / vpoint) * vpoint;

  // Adicione a diferença calculada a vprice
  rnumber = (vprice + rnumber);

  // Retorne o resultado, normalizado para o número de dígitos especificado
  return NormalizeDouble(rnumber, vdigits);
}

//+------------------------------------------------------------------+
string AttributeChangeString(string comment, long ticketid, string attributeName, double oldValue, double newValue, string symbol)
{
  string message;
  int symbol_digit;

  if (attributeName == "volume")
    symbol_digit = 2;
  else
    symbol_digit = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));

  message = StringFormat("#%s - Ticket: %d - Order Modify: %s changed from: %s to: %s",
                         comment,
                         ticketid,
                         ToUpperCase(attributeName),
                         ToUpperCase(DoubleToString(oldValue, symbol_digit)),
                         ToUpperCase(DoubleToString(newValue, symbol_digit)));

  return message;
}

//+------------------------------------------------------------------+
void CheckOrdersClosed(OrderStruct &orders[])
{
  for (int orderindex = 0; orderindex < PositionsTotal(); orderindex++)
  {
    ulong ticketid = PositionGetTicket(orderindex);
    string comment_id = PositionGetString(POSITION_COMMENT);

    if (PositionGetInteger(POSITION_MAGIC) == 0)
      continue;

    int orders_index = FindApiOrdersByTicketId(orders, comment_id);

    // Check if the order is closed or not found in the orders array
    if (orders_index >= 0)
    {
      // if (FindCloseOrderByComment(orders[orders_index].comment))
      if (FindOrdersHistoryByCommentBool(orders[orders_index].comment))
        MakeOrder(orders[orders_index], "CLOSED");
    }
    else
    {
      // The order is open but not found in the orders array
      // Add code here to handle this situation
      AddCommentOnChart("CheckOrdersClosed - Order Ticket to Close #" + IntegerToString(ticketid) + " Comment: " + comment_id + "\n");
      OrderStruct missingOrder;
      missingOrder.ticketMaster = StringToInteger(comment_id);
      missingOrder.ticketSlave = long(ticketid);
      missingOrder.comment = comment_id;
      missingOrder.symbol = PositionGetString(POSITION_SYMBOL);
      missingOrder.magicnumber = PositionGetInteger(POSITION_MAGIC);
      missingOrder.type = PositionGetInteger(POSITION_TYPE);
      MakeOrder(missingOrder, "CLOSED");
    }
  }
}

//+------------------------------------------------------------------+
double GetOrderProfit(OrderStruct &order)
{
  double profit = 0;
  string comment = order.comment;
  ulong ticket_slave = order.ticketSlave;
  ulong deal_ticket = FindDealOutByTicketId(ticket_slave);

  if (ticket_slave <= 0)
    // ticket_slave = FindCloseOrderByCommentLong(comment);
    ticket_slave = FindOrdersHistoryByCommentLong(comment);
  if (ticket_slave == -1)
  {
    return profit;
  }

  for (int tries = 0; tries < 50; tries++)
  {
    if (tries > 0 || profit == 0)
    {
      int multi = int(tries / 2);
      Sleep(SleepTimer * multi);
      if (DebugMode && DebugModeLevel == 2)
        AddCommentOnChart("SleepTime: " + IntegerToString(SleepTimer) + " - tries: " + IntegerToString(tries) + " - multi: " + IntegerToString(multi), 0, false, true);
    }
    else
    {
      break;
    }

    if (PositionSelectByTicket(ticket_slave))
      profit = PositionGetDouble(POSITION_PROFIT);
    else if (deal_ticket != INVALID_HANDLE)
    {

      long position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      profit = CalculateTotalProfitForOrder(ticket_slave, order.lot);
    }
    // Log debug information if in debug mode
    if (DebugMode && DebugModeLevel == 2)
    {
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticket_slave) + " - GetOrderProfit Profit: " + DoubleToString(profit));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticket_slave) + " - GetOrderProfit Tries: " + IntegerToString(tries));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticket_slave) + " - GetOrderProfit SleepTimer: " + IntegerToString(SleepTimer * tries));
    }
    // Break the loop if a non-zero profit is found
    if (profit != 0)
      break;
  }
  return profit;
}

//+------------------------------------------------------------------+
double CalculateTotalProfitForOrder(long order_ticket, double originalVolume)
{
  double totalProfit = 0.0;
  double totalVolumeClosed = 0.0;

  // Iterar pelas transações para coletar dados de volumes e lucros fechados
  for (int i = HistoryDealsTotal(); i > 0; i--)
  {
    ulong deal_ticket = HistoryDealGetTicket(i);
    long dealOrderTicket = HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
    long position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
    ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);

    if ((position_id == order_ticket) && (entry_type == DEAL_ENTRY_OUT))
    {
      double dealProfit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
      double dealVolume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);

      totalVolumeClosed += dealVolume;
      totalProfit += dealProfit;
    }
  }

  // Ajustar o lucro baseado na proporção do volume fechado
  if (totalVolumeClosed != 0 && totalVolumeClosed != originalVolume)
  {
    totalProfit = (totalProfit / totalVolumeClosed) * originalVolume;
  }

  return totalProfit;
}

//+------------------------------------------------------------------+
double GetOrderPriceClose(string comment, long ticketid)
{
  int tries = 0;
  double price = 0;

  for (tries; (tries < 50 && price == 0); tries++)
  {
    if (tries > 0)
      Sleep(SleepTimer * tries);

    long deal_ticket = FindDealOutByTicketId(ticketid);
    if (deal_ticket != INVALID_HANDLE)
      // Se encontrarmos um negócio de fechamento para a posição, retornamos o lucro do negócio
      price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);

    if (DebugMode)
    {
      string timestamp = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceClose Price: " + DoubleToString(price));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceClose Tries: " + IntegerToString(tries));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceClose SleepTimer: " + IntegerToString(SleepTimer * tries));
    }
  }
  return price;
}

//+------------------------------------------------------------------+
double GetOrderPriceOpen(string comment, long ticketid)
{
  int tries = 0;
  double price = 0;

  for (tries; (tries < 50 && price == 0); tries++)
  {
    if (tries > 0)
      Sleep(SleepTimer * tries);

    long deal_ticket = FindDealInByTicketId(ticketid);
    if (deal_ticket != INVALID_HANDLE)
      price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);

    if (DebugMode)
    {
      string timestamp = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceOpen Price: " + DoubleToString(price));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceOpen Tries: " + IntegerToString(tries));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceOpen SleepTimer: " + IntegerToString(SleepTimer * tries));
    }
  }
  return price;
}

//+------------------------------------------------------------------+
string GetOrderOpenAt(string comment, long ticketid)
{
  int tries = 0;
  string open_at = DEFAULT_TIME;
  long deal_ticket = FindDealInByTicketId(ticketid);

  for (tries; (tries < 50 && open_at == DEFAULT_TIME); tries++)
  {
    if (tries > 0)
      Sleep(SleepTimer * tries);

    if (PositionSelectByTicket(ticketid))
      open_at = TimeToString(PositionGetInteger(POSITION_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    else if (deal_ticket != INVALID_HANDLE)
      open_at = TimeToString(HistoryDealGetInteger(deal_ticket, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));

    if (DebugMode)
    {
      string timestamp = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderOpenAt Ticket " + "#" + comment + " - Ticket: " + IntegerToString(ticketid));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderOpenAt open_at: " + open_at);
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderOpenAt Tries: " + IntegerToString(tries));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderOpenAt SleepTimer: " + IntegerToString(SleepTimer * tries));
    }
  }

  if (open_at == DEFAULT_TIME)
  {
    Print("Position Open At not found for ticket ID: " + "#" + comment + " - Ticket: " + IntegerToString(ticketid));
  }
  return open_at;
}

//+------------------------------------------------------------------+
void CheckTargetsAndCloseTrades(OrderStruct &orders[])
{
  AppSettings.appReachLossDay = 0;

  if (AppSettings.appReachMfeTarget == 0 || AppSettings.appReachLossSet == 0)
  {
    RemoveCommentOnChart(5);
    RemoveCommentOnChart(6);
    return;
  }

  datetime today = TimeTradeServer() - (TimeTradeServer() % 86400);

  HistorySelect(0, TimeCurrent());
  int deals = HistoryDealsTotal();

  for (int i = deals - 1; i >= 0; i--)
  {
    ulong deal_ticket = HistoryDealGetTicket(i);

    int entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);

    long ticketid = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

    long deal_ticket_in = FindDealInByTicketId(ticketid);
    long magic_number = HistoryDealGetInteger(deal_ticket_in, DEAL_MAGIC);

    if (entry_type == DEAL_ENTRY_IN || magic_number == 0)
      continue;

    datetime order_date = datetime(HistoryDealGetInteger(deal_ticket, DEAL_TIME));
    if (order_date < today)
      break;

    OrderStruct order_deal;

    order_deal.lot = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
    order_deal.ticketSlave = ticketid;
    order_deal.comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);

    AppSettings.appReachLossDay += GetOrderProfit(order_deal);
    // if (ReachLossSet != 0 && ReachLossDay <= ReachLossSet)
    // {
    //   ReachLossSetBool = true;
    // }
  }
  // Calcular lucro/perda total de todas as operações
  AppSettings.appReachProfitDay = AppSettings.appReachLossDay;
  for (int i = 0; i < ArraySize(orders); i++)
  {
    if (PositionSelectByTicket(orders[i].ticketSlave  ))
      AppSettings.appReachProfitDay += GetOrderProfit(orders[i]);  
  }
  // Verificar MFE Target e Loss Target
  if (ReachMfeTarget != 0 && AppSettings.appReachProfitDay >= AppSettings.appReachMfeTarget)
    AppSettings.appReachLossDay = 0;

  if (AppSettings.ReachLossSetBool() || AppSettings.ReachMfeTargetBool())
    CloseAllOrdersStruct(orders);

  // if(ReachProfitDayLast != ReachProfitDay && ReachProfitDay != 0){
  if (AppSettings.appReachProfitDayLast != AppSettings.appReachProfitDay && (AppSettings.ReachMfeTargetBool() || AppSettings.ReachLossSetBool()))
  {
    AppSettings.appReachProfitDayLast = AppSettings.appReachProfitDay;
    AddCommentOnChart("MFE Target: " + ToUpperCase(string(AppSettings.ReachMfeTargetBool())) + " - | - Day Profit " + DoubleToString(AppSettings.appReachProfitDay, 2) + " > " + DoubleToString(ReachMfeTarget, 2) + " Mfe Target", 5);
  }

  // if(ReachLossDayLast != ReachLossDay && ReachProfitDay != 0){
  if (AppSettings.appReachLossDayLast != AppSettings.appReachLossDay && (AppSettings.ReachMfeTargetBool() || AppSettings.ReachLossSetBool()))
  {
    AppSettings.appReachLossDayLast = AppSettings.appReachLossDay;
    AddCommentOnChart("LOSS Set: " + ToUpperCase(string(AppSettings.ReachLossSetBool())) + " - | - Day Loss " + DoubleToString(AppSettings.appReachLossDay, 2) + " < " + DoubleToString(AppSettings.appReachLossSet, 2) + " Loss Set", 6);
  }
}

//+------------------------------------------------------------------+
void CloseAllOrdersStruct(OrderStruct &orders[])
{
  for (int i = 0; i < ArraySize(orders); i++)
  {
    MakeOrder(orders[i], "CLOSED");
  }
}

//+------------------------------------------------------------------+
void CloseAllPositionOrders()
{
  for (int i = 0; i < PositionsTotal(); i++)
  {
    ulong ticket_slave = PositionGetTicket(i);
    string comment = PositionGetString(POSITION_COMMENT);
    long magic_number = PositionGetInteger(POSITION_MAGIC);
    if (StringLen(comment) > 0 && magic_number > 0)
      CloseOrderByComment(ticket_slave, comment);
  }
}

//+------------------------------------------------------------------+
void CloseOrderByComment(ulong ticket_slave, string comment)
{
  OrderStruct order;
  MqlTradeResult result = {};
  MqlTradeRequest request = {};
  ZeroMemory(request);
  ZeroMemory(result);
  ResetLastError();

  PositionSelectByTicket(ticket_slave);
  order.ticketSlave = long(ticket_slave);
  order.symbol = PositionGetString(POSITION_SYMBOL);
  order.type = PositionGetInteger(POSITION_TYPE);
  order.lot = PositionGetDouble(POSITION_VOLUME);
  order.magicnumber = PositionGetInteger(POSITION_MAGIC);
  order.slip_page = Slippage;
  order.comment = comment;
  if (MakeOrderClose(result, request, order, "CLOSED") > 1)
    AddCommentOnChart("CloseOrderByComment: Close True - Comment: " + comment + " Ticket #" + IntegerToString(ticket_slave));
  else
    AddCommentOnChart("CloseOrderByComment: Close False - Comment: " + comment + " Ticket #" + IntegerToString(ticket_slave));
}

//+------------------------------------------------------------------+
void CheckOrdersDuplicate()
{
  string commentsOnChart = ""; // Inicializa a string que acumulará os comentários para o gráfico

  for (int i = 0; i < PositionsTotal(); i++)
  {
    ulong ticket_slave1 = PositionGetTicket(i);
    string comment1 = PositionGetString(POSITION_COMMENT);

    // Comece 'x' de 'i + 1' para evitar comparações desnecessárias e duplicadas
    for (int x = i + 1; x < PositionsTotal(); x++)
    {
      ulong ticket_slave2 = PositionGetTicket(x);
      string comment2 = PositionGetString(POSITION_COMMENT); // A correção aqui é para usar POSITION_COMMENT
      if (PositionSelectByTicket(ticket_slave2) == false)
        continue;

      // Checa se os tickets são diferentes e os comentários são iguais
      if (ticket_slave1 != ticket_slave2 && comment1 == comment2)
      {
        AddCommentOnChart("CheckOrdersDuplicate - Duplicate Order Ticket 1 #" + IntegerToString(ticket_slave1) + " - Ticket 2 #" + IntegerToString(ticket_slave2) + " Comment: " + comment1 + "\n");
        CloseOrderByComment(ticket_slave2, comment2); // Pode ser 'comment1' ou 'comment2', ambos são iguais aqui
      }
    }
  }
}

//+------------------------------------------------------------------+
bool CheckOrderAlreadyOpen(string comment)
{
  string commentsOnChart = ""; // Inicializa a string que acumulará os comentários para o gráfico

  for (int i = 0; i < PositionsTotal(); i++)
  {
    ulong ticket = PositionGetTicket(i);
    if (ticket > 0)
    {
      if (PositionGetString(POSITION_COMMENT) == comment)
      {
        AddCommentOnChart("CheckOrderAlreadyOpen - Opened Order Ticket #" + IntegerToString(ticket) + " Comment :" + comment + "\n");
        return true;
      }
    }
  }
  return false;
}

//+------------------------------------------------------------------+