//+------------------------------------------------------------------+
#define VERSION "3.00"
#define VERSION_UPDATE "02"
#define VERSION_LOCAL "19"

#define APPNAME "Imentore Slave"
#define APPVERSION "3.00"

#define EXPERTNAME "imentore_slave"
#define EXPERTKIND "slave"

#property copyright "Update " + VERSION_UPDATE + " - Copyright IMENTORE.COM"
#property description "Breno Perucchi"
#property strict


//+-Includes--------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/TerminalInfo.mqh>
#include <ImentoreLib_12.mqh>
#include <ImentoreSettings.mqh>

//+--Objects--------------------------------------------------------------------+
CTrade trade;
CTerminalInfo cterminal;
Settings* AppSettings = Settings::Instance();

//+-Input-----------------------------------------------------------------------+
input bool InputEnvironmentLocal         = true; // Admin only (default: false)
bool iOrderPendingModifySendChange = true; // Send Change Order Pending to Server (default: true)

//+--Globales Order--------------------------------------------------------------+
bool order_allowopen          = true;
bool order_allowclose         = true;
bool order_allowmodify        = true;
bool order_invert             = false;
double account_minmarginfree  = 0.00;

bool TicketOpen;
bool TicketClosed;
bool TicketPending;
bool TicketPendingHistory;
bool TicketPositionOrders;
bool TicketHistoryOrders;

int SleepTimer                 = 2;
int TimeCurrentTimer = int(TimeLocal());
int TimeCurrentTick  = int(TimeLocal());
int TimeCurrentLocal = int(TimeLocal());

const string DEFAULT_TIME = "1970.01.01 00:00:00";
datetime OrdersHistoryStart, OrdersHistoryEnd;

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
  AppSettings.appMaxSeconds         = 30;
  AppSettings.appSlipPage           = 30;
  AppSettings.apiVersion            = "v3";
  AppSettings.InputEnvironmentLocal = InputEnvironmentLocal;
  AppSettings.appEnvironmentLocal   = InputEnvironmentLocal;
  
  EventSetMillisecondTimer(AppSettings.appMilliSecondsTimer);
  
  SetLogFileName();
  SetCommentImentore(true, true);
  
  AddCommentOnChart(AppSettings.accountName + " - " + AppSettings.accountLogin + " - " + AppSettings.accountServerName + " - " + AccountMarginMode() + " - " + ((AppSettings.appEnvironmentLocal || InputEnvironmentLocal) ? "Local" : "Produção"), 3);
  
  if (DetectEnvironment() == false){
    AddCommentOnChart("Expert " + StringToCameCase(AppSettings.appExpertName) + " não inicializado. Contacte o SUPORTE.", 4);
    return (INIT_FAILED);
  } else {
    AddCommentOnChart("Expert " + StringToCameCase(AppSettings.appExpertName) + " inicializado com SUCESSO", 4);
    //UpdatePendingOrders();
    //MfeMaeDisplay = false;    
    //AppSettings.appSendOrdersHistory = true;
    //TrasmitOrders();
    
    long ordersTtotal = OrdersTotal();
    long historyOrdersTotal = HistoryOrdersTotal();
    long historyDealsTotal = HistoryDealsTotal();
    
    return (INIT_SUCCEEDED);    
  }
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason){
  EventsOnDeinit();
  return;
}

//+------------------------------------------------------------------+
void OnTick(){
  

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
  EventsToExecute();     // Periodically check if OrdersStruct is up-to-date  
}

//+------------------------------------------------------------------+
void OnTimer(){
  if (EventOnTimer){    
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

  OrdersExecute();      
  EventsToExecute();  
}

//+------------------------------------------------------------------+
long OrderCreate(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string action){
  ResetLastError();
  bool changes = false;
  long ticketId = -1;

  for (int count = 0; count <= 1; count++){    
    if (action == "MODIFY_VOLUME"){
      double lot = PositionGetDouble(POSITION_VOLUME);
      request.volume -= lot;
    }
    changes = PreSendChecks(request, result, order);

    if (changes){
      bool orderResult = OrderSend(request, result);      
      if (orderResult)
        ticketId = long(result.order);
    }
    ProcessOrderResult(result, request, order, action, count);
    if (count == 1 || (result.retcode == 90013 || result.retcode == 10008 || result.retcode == 10009 || result.retcode == 90099 || result.retcode == 90016 || result.retcode == 90090 || result.retcode == 90091))
      break;
  }
  return ticketId;
}

//+------------------------------------------------------------------+
long OrderModify(MqlTradeResult &result, MqlTradeRequest &request,
                     OrderStruct &order, string action){
  long change = -1;
  string meta_state;
 
  if(OrderSelect(order.ticketSlave)){
    change = trade.OrderModify(order.ticketSlave, order.priceOpen, order.stopLoss, order.takeProfit, ORDER_TIME_DAY, 0);
  } 
  if(PositionSelectByTicket(order.ticketSlave)){    
    change = trade.PositionModify(order.ticketSlave, order.stopLoss, order.takeProfit);
  }

  result.comment = trade.ResultComment();
  result.retcode = trade.ResultRetcode();
  request.symbol = order.symbol;
  request.sl = order.stopLoss;
  request.tp = order.takeProfit;
  meta_state = change ? "MODIFY" : "NOTMODIFY";
  change = change ? long(order.ticketSlave) : INVALID_HANDLE;

  string log_message = SetLogInfo(order, GetLastError(), result.retcode, result.comment, 0, action);
  SendMessageToServer(result, request, order, action, order.state, meta_state, "MakeOrderModify", log_message);  
  
  return change;
}

//+------------------------------------------------------------------+
bool OrderModifyVolume(MqlTradeResult &result, MqlTradeRequest &request,
                           OrderStruct &order, string action){
  bool   change = false;    
  double volume = PositionGetDouble(POSITION_VOLUME);

  if (order.volume > volume)
    change = MakeOrderOpen(result, request, order, action);
  else if(order.volume < volume){
    long digits = SymbolInfoInteger(order.symbol, SYMBOL_DIGITS);
    order.volume = NormalizeDouble(volume - order.volume, int(digits));
    change = MakeOrderClose(result, request, order, action);
  }    
  return change;
}

//+------------------------------------------------------------------+
int OrdersExecute(){
  TrasmitOrders();
  UpdateSlavePositionOrders();
  
  int orders_size = ArraySize(PositionOrders);
  int changed_ticket = 0;

  for (int i = 0; i < orders_size; i++){
        
    if (PositionOrders[i].state == "pending")
      changed_ticket = MakeOrder(PositionOrders[i], "OPEN");
    else if (PositionOrders[i].state == "executed")
      changed_ticket += MakeOrder(PositionOrders[i], "MODIFY");
    else if (PositionOrders[i].state == "remove")
      changed_ticket += MakeOrder(PositionOrders[i], "CLOSED");
  }
  UpdateSlavePositionOrders();
  return changed_ticket;
}

//+------------------------------------------------------------------+
void EventsToExecute(){
  static datetime last60seconds = 0;
  static datetime last02seconds = 0;
  datetime now = TimeCurrent();
  
  CheckOrdersClosed(PositionOrders);
  CheckOrdersDuplicate();  
  CheckAnotherDay();
  CheckReachMfeAndSetLoss();
  CalculateOrdersMFEMAE();
  EventsFromAppApi();
  SetCommentImentore();
  
  if (now - last02seconds > 02){
    SetLogFileName();
    last02seconds = now;
  }

  if (now - last60seconds > 60){
    HistorySelect(0, TimeCurrent());
    last60seconds = now;  
  }
  
  UpdateSlavePositionOrders();
}

//+------------------------------------------------------------------+
//+ Functions                                                        +
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
double CalculateProfitTotalByOrdersHistory(){
  double profit = 0;
  for (int i = 0; i < ArraySize(HistoryOrders); i++){
    //OrderObj *order = (OrderObj *)HistoryOrders.At(i);
    if(StringLen(HistoryOrders[i].comment) > 0 && HistoryOrders[i].magicNumber != 0 && HistoryOrders[i].entry != DEAL_ENTRY_IN)
      profit += HistoryOrders[i].profit;
  }
  return profit; // Add a return statement here
}

//+------------------------------------------------------------------+
double CalculateTotalProfitForOrder(long order_ticket){
  double totalProfit = 0.0;
  double totalVolumeClosed = 0.0;

  // Iterar pelas transações para coletar dados de volumes e lucros fechados
  for (int i = HistoryDealsTotal(); i > 0; i--){
    ulong deal_ticket = HistoryDealGetTicket(i);
    long dealOrderTicket = HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
    long position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
    ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);

    if ((position_id == order_ticket) && (entry_type == DEAL_ENTRY_OUT)){
      double dealProfit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
      double dealVolume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
      totalVolumeClosed += dealVolume;
      totalProfit += dealProfit;
    }
  }
  return totalProfit;
}

//+------------------------------------------------------------------+
void CheckOrdersDuplicate(){
  string commentsOnChart = ""; // Inicializa a string que acumulará os comentários para o gráfico

  for (int i = 0; i < PositionsTotal(); i++){
    ulong ticket_slave1 = PositionGetTicket(i);
    string comment1 = PositionGetString(POSITION_COMMENT);

    // Comece 'x' de 'i + 1' para evitar comparações desnecessárias e duplicadas
    for (int x = i + 1; x < PositionsTotal(); x++){
      ulong ticket_slave2 = PositionGetTicket(x);
      string comment2 = PositionGetString(POSITION_COMMENT); // A correção aqui é para usar POSITION_COMMENT
      if (PositionSelectByTicket(ticket_slave2) == false)
        continue;

      // Checa se os tickets são diferentes e os comentários são iguais
      if (ticket_slave1 != ticket_slave2 && comment1 == comment2){
        AddCommentOnChart("CheckOrdersDuplicate - Duplicate Order Ticket 1 #" + IntegerToString(ticket_slave1) + " - Ticket 2 #" + IntegerToString(ticket_slave2) + " Comment: " + comment1 + "\n");
        CloseOrderByComment(ticket_slave2, comment2); // Pode ser 'comment1' ou 'comment2', ambos são iguais aqui
      }
    }
  }
}

//+------------------------------------------------------------------+
bool CheckOrderAlreadyOpen(string comment){
  string commentsOnChart = ""; // Inicializa a string que acumulará os comentários para o gráfico

  for (int i = 0; i < PositionsTotal(); i++){
    ulong ticket = PositionGetTicket(i);
    if (ticket > 0){
      if (PositionGetString(POSITION_COMMENT) == comment){
        AddCommentOnChart("CheckOrderAlreadyOpen - Opened Order Ticket #" + IntegerToString(ticket) + " Comment :" + comment + "\n");
        return true;
      }
    }
  }
  return false;
}

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
bool MakeOrder(OrderStruct &order, const string action){
  bool orderstatus     = false;
  bool change          = 0;  
        
  if(order.ticketSlave <= 0 && action != "OPEN"){
    order.ticketSlave = FindOpenOrderByComment(order.comment);
    if(order.ticketSlave <= 0)
      order.ticketSlave = FindOrdersHistoryByPositionIdLong(order.positionID);
    if (order.ticketSlave <= 0){
      order.ticketSlave = FindOpenOrderByComment(order.comment);
      if(order.ticketSlave <= 0)
        return change;    
    }
  }
  
  if(order.ticketDeal <= 0){
    long indexHistory = FindOrdersHistoryByPositionIDIndex(order.ticketSlave, DEAL_ENTRY_OUT);
    if(indexHistory >= 0)
      order.ticketDeal = HistoryOrders[indexHistory].ticketDeal;
  }  

  if (order_allowmodify == false || order.symbol == "")
    return change;

  if (!cterminal.IsConnected() || cterminal.IsTradeAllowed() == false){
    AddCommentOnChart("Conexão com o servidor perdida. Por favor, verifique a conexão com a internet.");
    SymbolSelect(order.symbol, false);
    return false;
  }

  TicketOpen           = PositionSelectByTicket(order.ticketSlave);  
  TicketPending        = OrderSelect(order.ticketSlave);
  TicketPendingHistory = HistoryOrderSelect(order.ticketSlave);    
  TicketHistoryOrders  = FindOrdersHistoryByPositionIdBool(order.ticketSlave);
  TicketPositionOrders = FindOrdersPositionByPositionIDBool(order.ticketSlave);

  MqlTradeResult mqlResult = {};
  MqlTradeRequest mqlRequest = {};
  ZeroMemory(mqlResult);
  ZeroMemory(mqlRequest);  
  ResetLastError();

  if (action == "OPEN"){
    change = MakeOrderOpen(mqlResult, mqlRequest, order, action);
    if (change > 0)
      orderstatus = true;
  } else if (action == "CLOSED"){
    orderstatus = MakeOrderClose(mqlResult, mqlRequest, order, action);
  } else if (action == "MODIFY"){
    orderstatus = MakeOrderModify(mqlResult, mqlRequest, order, action);
  }
 
  return (change > 0 && orderstatus) ? true : false;
}

//+------------------------------------------------------------------+
long MakeOrderClose(MqlTradeResult &result, MqlTradeRequest &request,
                    OrderStruct &order, string action){  
  string meta_state;
  bool close_result = false;
  
  if (order_allowclose == false) // || order.ticketSlave <= 0)
    return close_result;      

  request.position = order.ticketSlave;                // ticket of the position
  request.symbol = order.symbol;                       // symbol
  request.volume = order.volume; // volume of the position
  request.deviation = AppSettings.appSlipPage;         // allowed deviation from the price
  request.comment = order.comment;
  request.magic = order.magicNumber;
  
  if(TicketPending && !TicketPendingHistory){
    close_result = trade.OrderDelete(order.ticketSlave);       
    if(close_result > 0){
      result.retcode = 10009;
      meta_state = "CLOSED";
    } else{
      result.retcode = 94017;
      meta_state = "NOTCLOSED";
    }
  } else{
    if (!TicketOpen && !TicketClosed && !TicketPending && !TicketPendingHistory){
      result.retcode = 94016;
      result.comment = "Not Find for Closed";
      meta_state = "NOTFIND";
      close_result = INVALID_HANDLE;
    } else if ((TicketPendingHistory || TicketClosed) && !TicketOpen){
      GetOrderInfoOnOrderHasClosed(order, request, result);
      meta_state = "HASCLOSED";
      close_result++;
    } else if(action == "MODIFY_VOLUME"){      
      close_result = trade.PositionClosePartial(order.ticketSlave, order.volume);
      if(close_result)
        meta_state = action;
    } else {
      close_result = trade.PositionClose(order.ticketSlave);
      if (close_result)
        meta_state = "CLOSED";                 
    }
     
    if(!close_result)
      meta_state = "NOTCLOSED"; 
    
    if(result.deal > 0)
      order.ticketDeal = long(result.deal);
    order.priceClose = result.price;
    
    HistorySelect(0, TimeCurrent());    
    order.closeAt = TimeToString(HistoryDealGetInteger(order.ticketDeal, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));          
    close_result++;
  }
  string log_message = SetLogInfo(order, GetLastError(), result.retcode, result.comment, 0, meta_state);
  
  if(CheckReachMfeAndSetLoss()){
    string logMfeAndLoss = CheckReachMfeAndSetLossInfo(order);
    AddCommentOnChart(logMfeAndLoss);
    log_message += " - MoreInfo: " + logMfeAndLoss;
  }  

  SendMessageToServer(result, request, order, action, order.state, meta_state, "MakeOrderClose", log_message);
  return close_result;
}

//+------------------------------------------------------------------+
bool CheckReachMfeAndSetLoss(){
  //EventsFromAppApi();
  bool change = false;
  string mfeMmessage;
  string lossMmessage;
  
  if(AppSettings.appReachMfeTarget > 0){
  //if (AppSettings.ReachMfeTargetBool()){      
    mfeMmessage = StringFormat("MFeTarget: %s - Profit Day: %s:", DoubleToString(AppSettings.appReachMfeTarget, 2), DoubleToString(AppSettings.appReachProfitDay,2));
    bool mfe_target = AppSettings.ReachMfeTargetBool();
    mfeMmessage += StringFormat(" - ReachMfe: %s", string(mfe_target));    
    AddCommentOnChart(mfeMmessage, 6, false);

    if(mfe_target)
      return true;    
    
  }
  if (AppSettings.appReachLossSet < 0){
    lossMmessage = StringFormat("LossTarget: %s - Loss Day: %s", DoubleToString(AppSettings.appReachLossSet, 2), DoubleToString(AppSettings.appReachLossDay,2));
    bool loss_target = AppSettings.ReachLossSetBool();
    lossMmessage += StringFormat(" - ReachLoss: %s", string(loss_target));    
    
    AddCommentOnChart(lossMmessage, 7, false);
    
    if(loss_target)
      return true;
  }
  
  //if(change){
  //  if(StringLen(mfeMmessage) > 0)    
  //    AddCommentOnChart(mfeMmessage, 6, false);
  //  else
  //    RemoveCommentOnChart(6);
  //  if(StringLen(lossMmessage) > 0)
  //    AddCommentOnChart(lossMmessage, 7, false);
  //  else
  //    RemoveCommentOnChart(7);
  // return change;
  //}
  
  return false;
}
//+------------------------------------------------------------------+
string CheckReachMfeAndSetLossInfo(OrderStruct &order){  
  if(AppSettings.ReachMfeTargetBool() || AppSettings.ReachLossSetBool()){
    bool mfe_target  = AppSettings.ReachMfeTargetBool();
    bool loss_target  = AppSettings.ReachLossSetBool();
    string reach_state  = AppSettings.ReachMfeTargetBool() ? "MfeTarget" : "LossSet";
    string reach_symbol = AppSettings.ReachMfeTargetBool() ? ">=" : "<=";
    double value        = reach_state == "MfeTarget" ? AppSettings.appReachProfitDay : AppSettings.appReachLossDay;
    double target       = AppSettings.ReachMfeTargetBool() ? AppSettings.appReachMfeTarget : AppSettings.appReachLossSet;
    string action_msg   = StringFormat("#%s - %s: %s %s %s", order.comment, "ReachProfitDay", DoubleToString(value, 2), reach_symbol, DoubleToString(target, 2));
    
    return action_msg;
  }
  return "";
}

//+------------------------------------------------------------------+
int MakeOrderModify(MqlTradeResult &result, MqlTradeRequest &request,
                     OrderStruct &order, string action) {
  bool changed = 0;
  int symbol_digit = (int)SymbolInfoInteger(order.symbol, SYMBOL_DIGITS);
  //long ticketid = FindOpenOrderByComment(order.comment);
  bool orderchanged = false;
  string comment_modify_stop_loss, comment_modify_take_profit, comment_modify_volume, comment_modify_priceOpen;
  
  TicketOpen           = PositionSelectByTicket(order.ticketSlave);
  TicketPending        = OrderSelect(order.ticketSlave);
  
  if(!TicketOpen && !TicketPending && TicketClosed)
    return orderchanged;
      
  if (PositionSelectByTicket(order.ticketSlave)){  // Market orders
    bool position = PositionSelectByTicket(order.ticketSlave);
    
    if(order.priceOpen == 0)
      order.priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
          
    if ((TicketOpen) && iOrderPendingModifySendChange) {
      
      double lot = GetOrderLots(order.symbol, order.volume, order.contractVolume);
      double symbol_volume = SymbolInfoDouble(order.symbol, SYMBOL_VOLUME_MIN);
      
      if(order.contractVolume == 0){
        if(UpdateOrderAttribute(PositionGetDouble(POSITION_VOLUME), order.volume, "volume", comment_modify_volume, order.comment, order.ticketSlave, order.symbol))
          changed = OrderModifyVolume(result, request, order, "MODIFY_VOLUME");
      }
    
      orderchanged |= UpdateOrderAttribute(PositionGetDouble(POSITION_SL), order.stopLoss, "stop_loss", comment_modify_stop_loss, order.comment, order.ticketSlave, order.symbol);
      orderchanged |= UpdateOrderAttribute(PositionGetDouble(POSITION_TP), order.takeProfit, "take_profit", comment_modify_take_profit, order.comment, order.ticketSlave, order.symbol);

      if (orderchanged) {
          order.stopLoss = CalculatePips(PositionGetDouble(POSITION_PRICE_OPEN), DoubleToString(order.stopLoss, symbol_digit), order.type, order.symbol);
          order.takeProfit = CalculatePips(PositionGetDouble(POSITION_PRICE_OPEN), DoubleToString(order.takeProfit, symbol_digit), order.type, order.symbol);          
      }
    }
  }   
  if (OrderSelect(order.ticketSlave)) {  // Pending orders
    if(order.priceOpen == 0)
      order.priceOpen = OrderGetDouble(ORDER_PRICE_OPEN);   

    if (OrderSelect(order.ticketSlave)) {
      orderchanged |= UpdateOrderAttribute(OrderGetDouble(ORDER_PRICE_OPEN), order.priceOpen, "price_open", comment_modify_priceOpen, order.comment, order.ticketSlave, order.symbol);
      orderchanged |= UpdateOrderAttribute(OrderGetDouble(ORDER_SL), order.stopLoss, "stop_loss", comment_modify_stop_loss, order.comment, order.ticketSlave, order.symbol);
      orderchanged |= UpdateOrderAttribute(OrderGetDouble(ORDER_TP), order.takeProfit, "take_profit", comment_modify_take_profit, order.comment, order.ticketSlave, order.symbol);
    } 
  }
  
  if (orderchanged){
    if (OrderModify(result, request, order, "MODIFY"))
      changed++;
  } 


  if (order.type <= 1 && !TicketPositionOrders && TicketHistoryOrders && order.state == "executed")
      MakeOrder(order, "CLOSED");

  return changed;
}

//+------------------------------------------------------------------+
long MakeOrderOpen(MqlTradeResult &result, MqlTradeRequest &request,
                   OrderStruct &order, string action){
  long ticketid = -1;
  bool response = false;
  string symbol = order.symbol;

  if (order_allowopen == false || order.symbol == "")
    return ticketid;

  if (cterminal.IsTradeAllowed() == false)
    return ticketid;

  if (account_minmarginfree > 0.00 && AccountInfoDouble(ACCOUNT_MARGIN_FREE) < account_minmarginfree)
    return ticketid;

  double vprice = order.priceOpen;
  double vsl = order.stopLoss;
  double vtp = order.takeProfit;
  double vlots = GetOrderLots(order.symbol, order.volume, order.contractVolume);
  long vtype = order.type;

  if (vprice <= 0.00){
    MqlTick last_tick;
    SymbolInfoTick(symbol, last_tick);
    if (vtype == 0)
      vprice = SymbolInfoDouble(symbol, SYMBOL_ASK);
    if (vtype == 1)
      vprice = SymbolInfoDouble(symbol, SYMBOL_BID);
  }

  double sl = CalculatePips(vprice, DoubleToString(vsl, int(SymbolInfoInteger(symbol, SYMBOL_DIGITS))), vtype, symbol);
  double tp = CalculatePips(vprice, DoubleToString(vtp, int(SymbolInfoInteger(symbol, SYMBOL_DIGITS))), vtype, symbol);

  if (order_invert){
    switch (int(vtype)){
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
  request.symbol    = symbol;                  // símbolo
  request.volume    = vlots;                   // volume de 0.2 lotes
  request.price     = vprice;                  // preço para a abertura
  request.deviation = AppSettings.appSlipPage; // desvio permitido do preço
  request.magic     = order.magicNumber;       // MagicNumber da ordem
  request.sl        = sl;
  request.tp        = tp;
  request.comment   = order.comment;

  switch (int(vtype)){
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
    request.type_filling = ORDER_FILLING_RETURN;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.priceOpen; // preço para a abertura
    break;
  case 3:
    request.action = TRADE_ACTION_PENDING; // tipo de operação de negociação
    request.type = ORDER_TYPE_SELL_LIMIT;  // tipo da ordem
    request.type_filling = ORDER_FILLING_RETURN;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.priceOpen; // preço para a abertura
    break;
  case 4:
    request.action = TRADE_ACTION_PENDING; // tipo de operação de negociação
    request.type = ORDER_TYPE_BUY_STOP;    // tipo da ordem
    request.type_filling = ORDER_FILLING_RETURN;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.priceOpen; // preço para a abertura
    request.stoplimit = 0;
    break;
  case 5:
    request.action = TRADE_ACTION_PENDING; // tipo de operação de negociação
    request.type = ORDER_TYPE_SELL_STOP;   // tipo da ordem
    request.type_filling = ORDER_FILLING_RETURN;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.priceOpen; // preço para a abertura
    request.stoplimit = 0;
    break;
  case 6:
    request.action = TRADE_ACTION_PENDING;    // tipo de operação de negociação
    request.type = ORDER_TYPE_BUY_STOP_LIMIT; // tipo da ordem
    request.type_filling = ORDER_FILLING_RETURN;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.priceOpen; // preço para a abertura
    break;
  case 7:
    request.action = TRADE_ACTION_PENDING;     // tipo de operação de negociação
    request.type = ORDER_TYPE_SELL_STOP_LIMIT; // tipo da ordem
    request.type_filling = ORDER_FILLING_RETURN;
    request.type_time = ORDER_TIME_DAY;
    request.price = order.priceOpen; // preço para a abertura
    break;
  }
  ticketid = OrderCreate(result, request, order, action);
  return ticketid;
}

//+------------------------------------------------------------------+
bool PreSendChecks(MqlTradeRequest &request, MqlTradeResult &result, OrderStruct &order){
  if (AccountMarginMode() == "HEDGING" && order.state != "pending")
    return false;
    
  if (!cterminal.IsConnected()){
    result.retcode = 10008; // "Not connected" error code
    return false;
  }
  
  if(FindOrdersHistoryByCommentBool(request.comment)){
    result.retcode = 90013;
    return false;
  }

  if (CheckOrderAlreadyOpen(request.comment)){
    result.retcode = 90016;                                                         // OPENED
    return false;
  }

  if(CheckReachMfeAndSetLoss()){
    result.retcode = AppSettings.ReachMfeTargetBool() ? 90090 : 90091;
    return false;
  }    
  
  //long secondsAgo = long(MathAbs((int)order.createdAt - (int)TimeGMT()));
  if((order.secondsAgo >= AppSettings.appMaxSeconds)){                              // TIMEMAX
    result.retcode = 90099;
    return false;
  }
  
  return true;
}

//+------------------------------------------------------------------+
void GetOrderInfoOnOrderHasClosed(OrderStruct &order, MqlTradeRequest &request, MqlTradeResult &result){
  if(order.type < 2){
    order.ticketSlave = FindOrdersHistoryByPositionIdLong(order.positionID);
    order.ticketDeal  = FindDealOutByTicketId(order.ticketSlave);
    order.closeAt     = TimeToString(HistoryDealGetInteger(order.ticketDeal, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    order.priceClose  = HistoryDealGetDouble(order.ticketDeal, DEAL_PRICE);
    request.volume    = HistoryDealGetDouble(order.ticketDeal, DEAL_VOLUME);
  } else {
    order.ticketDeal  = long(order.ticketSlave);
    order.openAt      = TimeToString(HistoryOrderGetInteger(order.ticketSlave, ORDER_TIME_SETUP), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    order.closeAt     = TimeToString(HistoryOrderGetInteger(order.ticketSlave, ORDER_TIME_DONE), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));    
    order.priceOpen   = HistoryOrderGetDouble(order.ticketSlave, ORDER_PRICE_OPEN);
    order.priceClose  = HistoryOrderGetDouble(order.ticketSlave, ORDER_PRICE_CURRENT);   
  }
  result.retcode    = 90013;
  result.comment    = "Manual Closed";    
}

//+------------------------------------------------------------------+
void ProcessOrderResult(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string action, int count){
  string meta_state, action_msg;
  switch (result.retcode){
  case 10009:
    meta_state = action;
    action_msg = "Order successfully processed";
    break;
  case 90099:
    meta_state = "TIMEMAX";
    action_msg = StringFormat("Time Max: %d >= %d MaxSeconds",order.secondsAgo, AppSettings.appMaxSeconds);
    break;
  case 90013:
    GetOrderInfoOnOrderHasClosed(order, request, result);
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
  case 90090: // Não conectado
    meta_state = "REACHMFE";
    action_msg = CheckReachMfeAndSetLossInfo(order);
    break;
  case 90091: // Não conectado
    meta_state = "REACHLOSS";
    action_msg = CheckReachMfeAndSetLossInfo(order);
    break;
  default:
    meta_state = "ERRORDEAL";
    action_msg = "Error in order processing";
    break;
  }

  if (meta_state == "OPENED" || meta_state == "OPEN"){
    if (meta_state == "OPEN") {
      order.ticketSlave = long(result.order);
      
      if(order.type >= 2 && OrderSelect(order.ticketSlave)){        
        order.priceOpen  = OrderGetDouble(ORDER_PRICE_OPEN);
        order.positionID = OrderGetInteger(ORDER_POSITION_ID);
        order.ticketDeal = OrderGetInteger(ORDER_TICKET);
        order.openAt = TimeToString(TimeTradeServer(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      } else {
        PositionSelectByTicket(order.ticketSlave);
        order.ticketDeal = long(result.deal);      
        order.priceOpen = result.price;
        order.openAt = GetOrderOpenAt(order.comment, order.ticketSlave);
        
        if (order.priceOpen == 0)
          order.priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);        

        if (order.ticketDeal <= 0)
          order.ticketDeal = FindOrdersHistoryByCommentTicketDeal(order.comment);       
          
        if(order.positionID <= 0)        
          order.positionID = PositionGetInteger(POSITION_IDENTIFIER);                     
      }      
    }

    if (order.ticketSlave <= 0 && meta_state == "OPENED"){
      order.ticketSlave = FindOpenOrderByComment(order.comment);
      PositionSelectByTicket(order.ticketSlave);
      order.priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
    }

    order.stopLoss = request.sl;
    order.takeProfit = request.tp;
    order.volume = request.volume;   
  }

  AddCommentOnChart("#" + order.comment +" - "+ action_msg);

  string log_message = SetLogInfo(order, GetLastError(), result.retcode, result.comment, count, action);
  log_message = log_message + (" - Action Msg: "+action_msg);
  SendMessageToServer(result, request, order, action, order.state, meta_state, "OrderCreate", log_message);
}

//+------------------------------------------------------------------+
int GetDigits(double num){
  int d = 0;
  double p = 1;
  while (MathRound(num * p) / p != num){p = MathPow(10, ++d);}
  return d;
}

//+------------------------------------------------------------------+
void SendMessageToServer(MqlTradeResult &result, MqlTradeRequest &request, OrderStruct &order, string const action, string const state, string const meta_state, const string fuction_name, string log_message){
  int symbol_digit = int(SymbolInfoInteger(request.symbol, SYMBOL_DIGITS));
  string meta_message = StringFormat("#%s - Ticket: %s - %s - Symbol: %s - Type: %s  - Volume: %s - TP: %s - SL: %s - Action: %s - Meta State: %s", order.comment, IntegerToString(order.ticketSlave), fuction_name, order.symbol, IntegerToString(order.type), DoubleToString(order.volume, 2), DoubleToString(request.tp, symbol_digit), DoubleToString(request.sl, symbol_digit), ToUpperCase(action), meta_state);

  AddCommentOnChart(meta_message);
  AddCommentOnChart(log_message);

  if (order.profit == 0.0)
    order.profit = GetOrderProfit(order);
  
  order.state = state;
  order.metaAction  = action;
  order.metaState   = meta_state;
  order.metaMessage = meta_message + " - LogMessage: " + log_message;
    
  if(meta_state == "CLOSED")
    CalculateOrdersMFEMAE();
    
  if (meta_state == "CLOSED" || meta_state == "HASCLOSED"){
    if (order.priceOpen <= 0.0)
      order.priceOpen = GetOrderPriceOpen(order.comment, order.ticketSlave);

    if (order.priceClose <= 0.00)
      order.priceClose = GetOrderPriceClose(order.comment, order.ticketSlave);

    if (order.openAt == DEFAULT_TIME || StringLen(order.openAt) == 0)
      order.openAt = GetOrderOpenAt(order.comment, order.ticketSlave);
  }
          
  string updateJson  = JsonOrderStruct(order);
  TrasmitOrders("update", updateJson, false);
}

//+------------------------------------------------------------------+
double GetOrderLots(const string symbol, double lot, double contract_volume){
  double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

  if (contract_volume == 0.0)
    return lot;
  else
    return NormalizeDouble((volume_step * contract_volume), 2);
}

//+------------------------------------------------------------------+
long FindOpenOrderByComment(string comment){
  for (int i = PositionsTotal() - 1; i >= 0; i--){
    ulong order_ticket = PositionGetTicket(i);
    if (order_ticket > 0 && PositionGetString(POSITION_COMMENT) == comment)
      return long(order_ticket);
  }
  return NULL;
}

//+-----------------------------------------`-------------------------+
bool FindOpenOrderByCommentBool(string comment){
  for (int i = PositionsTotal() - 1; i >= 0; i--){
    ulong order_ticket = PositionGetTicket(i);
    if (order_ticket > 0 && PositionGetString(POSITION_COMMENT) == comment)      
      return true;
  }
  return false;
}

//+------------------------------------------------------------------+
double CalculatePips(double vprice, string snumber, long vtype, string symbol){
  int vdigits = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  double vpoint = SymbolInfoDouble(symbol, SYMBOL_POINT);
  double number = StringToDouble(snumber);
  double rnumber = 0;

  if (snumber == "0")
    return rnumber;

  // Ajuste vpoint de acordo com vdigits
  if (vdigits == 0 || vdigits == 1)
    vpoint = 1;
  else
    vpoint = MathPow(10, -vdigits + 1);

  rnumber = ((number - vprice) / vpoint) * vpoint;
  rnumber = (vprice + rnumber);

  return NormalizeDouble(rnumber, vdigits);
}

//+------------------------------------------------------------------+
string AttributeChangeString(string comment, long ticketid, string attributeName, double oldValue, double newValue, string symbol){
  string message;
  int symbol_digit;

  if (attributeName == "volume")
    symbol_digit = 2;
  else
    symbol_digit = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));

  message = StringFormat("#%s - Ticket: %d - Order Modify: %s From: %s To: %s",
                         comment,
                         ticketid,
                         ToUpperCase(attributeName),
                         ToUpperCase(DoubleToString(oldValue, symbol_digit)),
                         ToUpperCase(DoubleToString(newValue, symbol_digit)));

  return message;
}

//+------------------------------------------------------------------+
void CheckOrdersClosed(OrderStruct &orders[]) {
  UpdatePositionOrders();
  UpdatePendingOrders();
  for (int i = 0;(i < OrdersTotal() && OrdersTotal() > 0); i++) {
    ulong ticketID = OrderGetTicket(i);
    long magicNumber = OrderGetInteger(ORDER_MAGIC);
    if(magicNumber == 0)
      continue;
        
    //long indexHistory = FindOrdersStructIndex(HistoryOrders, ticketID);
    bool ticketClosed = FindOrdersHistoryByPositionIdBool(ticketID);
    long indexPosition = FindOrdersStructIndex(PositionOrders, ticketID);
    if(indexPosition != INVALID_HANDLE && ticketClosed){
      MakeOrder(PendingOrders[indexPosition],"CLOSED");
    }
  }
  
  for (int i = 0; i < PositionsTotal(); i++) {
    ulong ticketid = PositionGetTicket(i);
    string comment = PositionGetString(POSITION_COMMENT);
    ulong positionID = PositionGetInteger(POSITION_TICKET);
    bool checkOrder = !FindOrdersHistoryByCommentBool(comment);
    checkOrder = !FindOrdersHistoryByPositionIdBool(positionID);
    bool position = FindOrdersPositionByPositionIDBool(positionID);
    
    if (position || checkOrder || PositionGetInteger(POSITION_MAGIC) == 0)
      continue;

    long ii = FindOrdersHistoryByCommentIndex(comment, DEAL_ENTRY_OUT);

    if (ii >= 0) {
        MakeOrder(HistoryOrders[ii], "CLOSED");
    } else {
      // A ordem está aberta, mas não foi encontrada no array de ordens
      // Adicione código aqui para lidar com essa situação
      AddCommentOnChart("CheckOrdersClosed - Order Ticket to Close #" + IntegerToString(ticketid) + " Comment: " + comment + "\n");
      OrderStruct missingOrder;
      missingOrder.ticketMaster = StringToInteger(comment);
      missingOrder.ticketSlave  = long(ticketid);
      missingOrder.comment      = comment;
      missingOrder.symbol       = PositionGetString(POSITION_SYMBOL);
      missingOrder.magicNumber  = PositionGetInteger(POSITION_MAGIC);
      missingOrder.type         = PositionGetInteger(POSITION_TYPE);
      
      MakeOrder(missingOrder, "CLOSED");
    }
  }

  // Verificar se há ordens fechadas no array orders[]
  for (int i = 0; i < ArraySize(orders); i++) {
    bool history  = FindOrdersHistoryByPositionIdBool(orders[i].positionID);
    bool position = FindOpenOrderByCommentBool(orders[i].comment);
    if(history && !position)
      MakeOrder(orders[i], "CLOSED");
  }  
}

//+------------------------------------------------------------------+
double GetOrderProfit(OrderStruct &order){
  double profit = 0;
  string comment = order.comment;
  long ticket_slave = long(order.ticketSlave);
  long deal_ticket = FindDealOutByTicketId(ticket_slave);

  if (ticket_slave <= 0)
    ticket_slave = FindOrdersHistoryByPositionIdLong(order.positionID);
  if (ticket_slave == -1 || order.type >= 2)
    return profit;

  for (int tries = 0; tries < 50; tries++){
    if (tries > 0 || profit == 0)
    {
      int multi = int(tries / 2);
      Sleep(SleepTimer * multi);
      if (DebugMode && DebugModeLevel == 2)
        AddCommentOnChart("SleepTime: " + IntegerToString(SleepTimer) + " - tries: " + IntegerToString(tries) + " - multi: " + IntegerToString(multi), 0, false, true);
    } else {
      break;
    }

    if (PositionSelectByTicket(ticket_slave))
      profit = PositionGetDouble(POSITION_PROFIT);
    else if (deal_ticket != INVALID_HANDLE){
      long position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      profit = CalculateTotalProfitForOrder(ticket_slave);
    }
    // Log debug information if in debug mode
    if (DebugMode && DebugModeLevel == 2){
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
double GetOrderPriceClose(string comment, long ticketid){
  int tries = 0;
  double price = 0;

  for (tries; (tries < 50 && price == 0); tries++){
    if (tries > 0)
      Sleep(SleepTimer * tries);

    long deal_ticket = FindDealOutByTicketId(ticketid);
    if (deal_ticket != INVALID_HANDLE)
      price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);

    if (DebugMode){
      string timestamp = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceClose Price: " + DoubleToString(price));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceClose Tries: " + IntegerToString(tries));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceClose SleepTimer: " + IntegerToString(SleepTimer * tries));
    }
  }
  return price;
}

//+------------------------------------------------------------------+
double GetOrderPriceOpen(string comment, long ticketid){
  int tries = 0;
  double price = 0;

  for (tries; (tries < 50 && price == 0); tries++){
    if (tries > 0)
      Sleep(SleepTimer * tries);

    long deal_ticket = FindDealInByTicketId(ticketid);
    if (deal_ticket != INVALID_HANDLE)
      price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);

    if (DebugMode){
      string timestamp = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceOpen Price: " + DoubleToString(price));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceOpen Tries: " + IntegerToString(tries));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderPriceOpen SleepTimer: " + IntegerToString(SleepTimer * tries));
    }
  }
  return price;
}

//+------------------------------------------------------------------+
string GetOrderOpenAt(string comment, long ticketid){
  int tries = 0;
  string open_at = DEFAULT_TIME;
  long deal_ticket = FindDealInByTicketId(ticketid);

  for (tries; (tries < 50 && open_at == DEFAULT_TIME); tries++){
    if (tries > 0)
      Sleep(SleepTimer * tries);

    if (PositionSelectByTicket(ticketid))
      open_at = TimeToString(PositionGetInteger(POSITION_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
    else if (deal_ticket != INVALID_HANDLE)
      open_at = TimeToString(HistoryDealGetInteger(deal_ticket, DEAL_TIME), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));

    if (DebugMode){
      string timestamp = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderOpenAt Ticket " + "#" + comment + " - Ticket: " + IntegerToString(ticketid));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderOpenAt open_at: " + open_at);
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderOpenAt Tries: " + IntegerToString(tries));
      AddCommentOnChart("#" + comment + " - Ticket: " + IntegerToString(ticketid) + " - GetOrderOpenAt SleepTimer: " + IntegerToString(SleepTimer * tries));
    }
  }
  if (open_at == DEFAULT_TIME)
    Print("Position Open At not found for ticket ID: " + "#" + comment + " - Ticket: " + IntegerToString(ticketid));
  
  return open_at;
}

//+------------------------------------------------------------------+
void EventsFromAppApi(){
  AppSettings.appReachLossDay   = 0;
  AppSettings.appReachProfitDay = 0;

  datetime today = TimeTradeServer() - (TimeTradeServer() % 86400);
  int deals = ArraySize(HistoryOrders)-1;

  for (int i = 0; i <= deals; i++){
    ulong deal_ticket = HistoryOrders[i].ticketDeal;
        
    if(HistoryOrders[i].magicNumber == 0){
      long iIndex = FindOrdersStructIndex(HistoryOrders, HistoryOrders[i].positionID, DEAL_ENTRY_IN);
      if(iIndex >= 0)
        HistoryOrders[i].magicNumber = HistoryOrders[iIndex].magicNumber;
    }
       
    int entry_type = (ENUM_DEAL_ENTRY)HistoryOrders[i].entry;

    if (entry_type == DEAL_ENTRY_IN || HistoryOrders[i].magicNumber == 0)
      continue;

    //datetime order_date = datetime(HistoryDealGetInteger(deal_ticket, DEAL_TIME));
    datetime order_date = datetime(HistoryOrders[i].closeAt);
    if (order_date < today)
      continue;

    AppSettings.appReachLossDay += HistoryOrders[i].profit;
    AppSettings.appReachProfitDay += HistoryOrders[i].profit;;
  }
  
  for (int i = 0; i < ArraySize(PositionOrders); i++){
    if (PositionSelectByTicket(PositionOrders[i].ticketSlave  ))
      AppSettings.appReachProfitDay += GetOrderProfit(PositionOrders[i].positionID);  
  }

  // check should close all positions
  if (AppSettings.ReachLossSetBool() || AppSettings.ReachMfeTargetBool())
    CloseAllOrdersStruct(PositionOrders);

  if(DebugMode && CloseAllOrders)
    CloseAllPositionOrders();    
}

//+------------------------------------------------------------------+
void CloseAllOrdersStruct(OrderStruct &orders[]){
  for (int i = 0; i < ArraySize(orders); i++){
    MakeOrder(orders[i], "CLOSED");
  }
}

//+------------------------------------------------------------------+
void CloseAllPositionOrders(){
  for (int i = 0; i < PositionsTotal(); i++){
    ulong ticket_slave = PositionGetTicket(i);
    string comment = PositionGetString(POSITION_COMMENT);
    long magic_number = PositionGetInteger(POSITION_MAGIC);
    if (StringLen(comment) > 0 && magic_number > 0)
      CloseOrderByComment(ticket_slave, comment);
  }
}

//+------------------------------------------------------------------+
void CloseOrderByComment(ulong ticket_slave, string comment){
  OrderStruct order;

  PositionSelectByTicket(ticket_slave);
  order.ticketSlave = long(ticket_slave);
  order.symbol      = PositionGetString(POSITION_SYMBOL);
  order.type        = PositionGetInteger(POSITION_TYPE);
  order.volume      = PositionGetDouble(POSITION_VOLUME);
  order.magicNumber = PositionGetInteger(POSITION_MAGIC);
  order.slipPage    = AppSettings.appSlipPage;
  order.comment     = comment;
  if (MakeOrder(order, "CLOSED") > 1)
    AddCommentOnChart("CloseOrderByComment: Close True - Comment: " + comment + " Ticket #" + IntegerToString(ticket_slave));
  else
    AddCommentOnChart("CloseOrderByComment: Close False - Comment: " + comment + " Ticket #" + IntegerToString(ticket_slave));
}

//+------------------------------------------------------------------+
bool UpdateOrderAttribute(double currentValue, double newValue, const string &attributeName, string &comment, const string &orderComment, ulong ticket, const string &symbol) {
    if (CompareDoubles(currentValue, newValue)) {
        comment += AttributeChangeString(orderComment, ticket, attributeName, currentValue, newValue, symbol);
        if (StringLen(comment) > 0)
            AddCommentOnChart(comment);
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+