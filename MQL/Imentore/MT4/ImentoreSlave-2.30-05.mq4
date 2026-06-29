//+------------------------------------------------------------------+
//#property version "2.30"

#define VERSION         "2_30"
#define VERSION_UPDATE  "05"
#define EXPERTNAME      "imentore_slave"

#define APPNAME         "Imentore Slave"
#define APPVERSION      "2.30"
#define EXPERT_KIND     "slave"

#property copyright   "Update "+ VERSION_UPDATE +" - Copyright IMENTORE.COM"
#property description "Breno Perucchi"
#property strict

//+-Includes--------------------------------------------------------------------+
#include <JAson.mqh>
#include <ImentoreLib.mqh>

//+-Input-----------------------------------------------------------------------+
input bool   InputEnvironmentLocal  = false;        // Admin only (default is false)

long   Slippage                     = 30;           // Spread for price   
ulong  MaxSeconds                   = 30;           // Time Max Operation - limit for waiting open a order (default is 30)
double PercentLots                  = 100;          // Lots Percent from Signal (Default is 100)
double MaxLots                      = 0.00;         // Limit the maximum lots (Default is 0.00)
bool   EnvironmentLocal             = false;        // EnvironmentLocal - Admin only (default is false)

//+--COMMOM EXPERTS--------------------------------------------------------------+
string SERVER                  = "http://mt5-web-replicator.example.com";
string ACCOUNTLOGIN            = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
string API_VERSION             = "v2";
string ACCOUNT_SERVER_NAME     = "";
int    MILLISECOND_TIMER       = 3000;

//+--Globales Order--------------------------------------------------------------+
bool   ReachMfeTargetBool      = false;  
bool   ReachLossSetBool        = false; 
double ReachProfitDay          = 0.0;
double ReachLossDay            = 0.0;
double ReachProfitDayLast      = 0.0;
double ReachLossDayLast        = 0.0;

bool   order_allowopen         = true;      
bool   order_allowclose        = true;
bool   order_allowmodify       = true;
bool   order_invert            = false;
double account_minmarginfree   = 0.00;
long   order_slippage          = 0;
int    SleepTimer              = 2;
int    file_handle_out         = 0;
int    TimeCurrentTimer        = int(TimeLocal());
int    TimeCurrentTick         = int(TimeLocal());

datetime  TimeCurrentReachMfe  = TimeCurrent();
//datetime  TimeCurrentReachMfe  = TimeCurrent() - 86400;

const string DEFAULT_TIME = "1970.01.01 00:00:00";

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
  SetCommentImentore(true);
  ACCOUNT_SERVER_NAME     = RemoveSpecialChars(AccountInfoString(ACCOUNT_SERVER));
  
  if(DetectEnvironment() == false)
   {
    AddCommentOnChart("Expert " + APPNAME + " " + APPVERSION + " - Update " + VERSION_UPDATE + " não inicializado. Contacte o suporte.", 2);
    return(INIT_FAILED);
   }
  else
   {
    AddCommentOnChart("Expert " + APPNAME + " " + APPVERSION + " - Update " + VERSION_UPDATE +" inicializado com sucesso.", 2);
    EventSetMillisecondTimer(MilliSecondsTimer);
    return(INIT_SUCCEEDED);    
   }
 }

//+------------------------------------------------------------------+
//| OnTimer                                                          |
//+------------------------------------------------------------------+
void OnTimer(){
  CheckAnotherDay();

  if(EventOnTimer){  
    OrdersExecute();
    CheckFreeze();
    SetLogFileName();

    if(DebugMode && DebugModeLevel  > 2){
      string message = ("OnTimer - " + TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS));
      Print(message);
      SaveLogToFile(message);
    }
  }

  if(DebugMode)
    SendLogFileToServer();

  if(!CheckServerInformations())      
    ExpertRemove();    
}

void SetCommentImentore(bool print_log = false){
  //MqlDateTime currentDateTime;
  //TimeToStruct(currentTime, currentDateTime); // Converter para estrutura de data/hora
  string datetime_now = TimeToString(TimeCurrent(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS));
  string message = StringFormat("Iniciando Expert %s %s - Update %s - Date: %s", APPNAME, APPVERSION, VERSION_UPDATE, datetime_now);
  AddCommentOnChart(message, 1, print_log);

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckAnotherDay(){
  // Obter a data e hora atual do servidor
  datetime currentTime = TimeCurrent();
  
  MqlDateTime currentDateTime;
  TimeToStruct(currentTime, currentDateTime); // Converter para estrutura de data/hora
  
  MqlDateTime lastDateTime;
  TimeToStruct(TimeCurrentReachMfe, lastDateTime); // Converter última data de ReachMfeTargetBoolLo
  
  // Verificar se mudou o dia
  if(currentDateTime.day != lastDateTime.day){
    AddCommentOnChart("CheckAnotherDay - change day: "+ IntegerToString(lastDateTime.day) + " to: " + IntegerToString(currentDateTime.day));
    ReachMfeTargetBool  = false;
    ReachLossSetBool    = false;
    ReachProfitDay      = 0;
    ReachLossDay        = 0;
    TimeCurrentReachMfe = currentTime; // Atualizar a última data de verificação
  }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
 {

  SetCommentImentore();
  CheckAnotherDay();

  int timeAgo = int(TimeLocal() - TimeCurrentTick);
  
  if(EventOnTick && (timeAgo*1000 >= MilliSecondsTick)){
    TimeCurrentTick = int(TimeLocal());
    
    if(DebugMode){
      SendLogFileToServer();

      if(DebugModeLevel > 2){
        string message = ("OnTick - " + TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS));
        Print(message);
        SaveLogToFile(message);
      }
    }

    if(!CheckServerInformations())      
      ExpertRemove();
    
    OrdersExecute();
    CheckFreeze();
    SetLogFileName();
  }

 }

//+------------------------------------------------------------------+
//|Deinitialisation function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
 {
  AddCommentOnChart("Expert " + APPNAME + " " + APPVERSION + " - Update " + VERSION_UPDATE + " removido com sucesso.");
  return;
 }


//+------------------------------------------------------------------+
//| Get all of the orders                                            |
//+------------------------------------------------------------------+
string SetLogInfo(string comment, long ticketid, int lastError, uint retcode, string resultComment, int attempt) {
    return StringFormat("#%s - Ticket: %d - Log Info - LastError: %d - Retcode: %u - ResultComment: %s - Attempt: %d",
                        comment,
                        ticketid,
                        lastError,
                        retcode,
                        resultComment,
                        attempt);
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
    else if(orders[i].state == "executed")
      changed_ticket += PushOrderModify(orders[i]);
    else if(orders[i].state == "remove")
      changed_ticket += PushOrderClosed(orders[i]);
  }
  CheckTargetsAndCloseTrades(orders);
  CheckOrdersAlreadyClosed(orders);
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
  
  
  
  int changed    = 0;
  string comment_modify_stop_loss, comment_modify_take_profit, comment_modify_volume;

  long ticketid = FindOpenOrderByCommentLong(order.comment);

  bool position = OrderSelect(int(ticketid), SELECT_BY_TICKET);
  
  //bool order_select = OrderSelect(ticketid);

  string comment = OrderComment();

  if(ticketid != -1)
   {
    if(comment == order.comment)
     {
      if(CompareDoubles(OrderStopLoss(), order.stop_loss)){
        orderchanged = true;
        comment_modify_stop_loss += AttributeChangeString(order.comment, ticketid, "stop_loss", OrderStopLoss(), order.stop_loss, order.symbol);
        
        if(StringLen(comment_modify_stop_loss)   > 0) 
          AddCommentOnChart(comment_modify_stop_loss);
        
      }

      if(CompareDoubles(OrderTakeProfit(), order.take_profit)){
        orderchanged = true;
        comment_modify_take_profit += AttributeChangeString(order.comment, ticketid, "take_profit", OrderTakeProfit(), order.take_profit, order.symbol); 
  
        if(StringLen(comment_modify_take_profit) > 0) 
          AddCommentOnChart(comment_modify_take_profit);
      }

      double lot = OrderLots();

      if(CompareDoubles(lot, order.lot)){
        orderchanged = true;
        comment_modify_volume += AttributeChangeString(order.comment, ticketid, "volume", lot, order.lot, order.symbol);

        if(StringLen(comment_modify_volume) > 0) 
          AddCommentOnChart(comment_modify_volume);
      }

      if(CompareDoubles(lot, order.lot)) // Only Netting Accounts
       {
        bool change = MakeOrder(order, "MODIFY_VOLUME");
        change ? (changed ++) : 0;
       }

      if(orderchanged == true)
      {
        //vprice = GetRandomPrice(symbol, vtype);  // open price
        order.stop_loss   = CalculatePips(OrderOpenPrice(), DoubleToString(order.stop_loss, symbol_digit), order.type, order.symbol);
        order.take_profit = CalculatePips(OrderOpenPrice(), DoubleToString(order.take_profit, symbol_digit), order.type, order.symbol);
        
        bool change = MakeOrder(order, "MODIFY");
        
        if(change)        
          changed ++;
      }
    }
  }
  else
    if(FindCloseOrderByCommentBool(order.comment) && order.state == "executed")
      PushOrderClosed(order);
  
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
   ticketid = FindOpenOrderByCommentLong(order.comment);
   order.ticket_slave = ticketid;
  }
  
  bool orderstatus =    false;

  if(order.trace_id <= 0 || order.symbol == "")
    return false;

  SymbolSelect(order.symbol, true);
  ResetLastError();

  if(action == "OPEN"){
    ticketid = MakeOrderOpen(order, action);
    if(ticketid > 0) orderstatus = true;
  }else 
  
  if(action == "CLOSED"){
    orderstatus = MakeOrderClose(order, action);      
  } else 
  
  if(action == "MODIFY"){
    orderstatus = MakeOrderModify(order, action);
  }

  if(action == "MODIFY_VOLUME"){
    orderstatus = MakeOrderModifyVolume(order, action);
  }

  return (ticketid > 0 && orderstatus) ? true : false;
}

//+------------------------------------------------------------------+
//| Make a market or pending order by signal message                 |
//+------------------------------------------------------------------+
long MakeOrderOpen(OrderStruct &order,
                    string action)
 {
  long ticketid = -1;
  bool response = false;
  string symbol = order.symbol;

// Allow signal to open the order
// Symbol must not be empty
  if(order_allowopen == false || order.symbol == "")
    return ticketid;

   // Verifica se a negociação está permitida
   if(!IsTradeAllowed())
   {
       Print("Negociação não permitida no momento.");
       return ticketid;
   }

  // Check if account margin free is less than settings
  if(account_minmarginfree > 0.00 && AccountInfoDouble(ACCOUNT_MARGIN_FREE) < account_minmarginfree)
    return ticketid;

  double vprice = 0;
  double vsl    = order.stop_loss;
  double vtp    = order.take_profit;
  order.lot = GetOrderLots(order.symbol, order.lot, order.contract_volume);
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
  order.stop_loss = CalculatePips(vprice, DoubleToString(vsl, int(SymbolInfoInteger(symbol, SYMBOL_DIGITS))), vtype, symbol);
  order.take_profit = CalculatePips(vprice, DoubleToString(vtp, int(SymbolInfoInteger(symbol, SYMBOL_DIGITS))), vtype, symbol);
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
  //request.symbol    = symbol;                                // símbolo
  //request.volume    = vlots;                                 // volume de 0.2 lotes
  //request.price     = vprice;                                // preço para a abertura
  //request.deviation = order_slippage;                        // desvio permitido do preço
  //request.magic     = order.magicnumber;                     // MagicNumber da ordem
  //request.sl        = sl;
  //request.tp        = tp;
  //request.comment   = order.comment;


  ticketid = OrderCreate(order, action);
  // ticketid = long(result.order);
  return ticketid;
 }

//+------------------------------------------------------------------+
//| Make a order close by signal message                             |
//+------------------------------------------------------------------+
long MakeOrderClose(OrderStruct &order,
                    string action)
{

  long ticket_open_comment = FindOpenOrderByCommentLong(order.comment);
  bool ticket_closed = FindCloseOrderByCommentBool(order.comment);

  string meta_state;
  bool close_result = 0;
  
  if(order.ticket_slave < 1 && ticket_open_comment > 0)
   order.ticket_slave = ticket_open_comment;

  // Allow signal to close the order
  // The parameter ticketid must be greater than zero
  if(order_allowclose == false)// || order.ticket_slave <= 0)
    return close_result;
  
  bool alowed =  IsTradeAllowed();
  // Verifica se a negociação está permitida
  if(!IsTradeAllowed()){
    Print("Negociação não permitida no momento.");
    return close_result;
  }
      
  double price = 0;
  int result_retcode = 0;
  string result_comment;
  if(OrderSelect(int(order.ticket_slave), SELECT_BY_TICKET)) {
      if(OrderType() == OP_BUY)
          price = Bid; // Para ordens de compra, fechar ao preço de venda (Bid)
      else if(OrderType() == OP_SELL)
          price = Ask; // Para ordens de venda, fechar ao preço de compra (Ask)
  
      // Fechando a ordem
      close_result = int(OrderClose(int(order.ticket_slave), order.lot, price, int(Slippage), clrNONE));
      
      if (!bool(close_result)) {
          result_retcode = GetLastError();
          Print("Falha ao fechar a ordem: ", result_retcode);
      }
  } else {
      result_retcode = GetLastError();
      Print("Falha ao selecionar a ordem: ", result_retcode);
  }

      
      if(ticket_open_comment == -1 && !ticket_closed){
        result_retcode = 94016;
        result_comment = "Not Find for Closed";
        meta_state     = "NOTFIND";
        close_result   = INVALID_HANDLE;
      } else         
      if(ticket_closed && FindOpenOrderByCommentBool(order.comment) == false && (!ReachMfeTargetBool && !ReachLossSetBool)){          
        order.ticket_deal = 0;
        //order.price_close = HistoryDealGetDouble(order.ticket_deal, DEAL_PRICE);            
        result_retcode    = 90013;
        result_comment    = "Manual Closed";
        meta_state        = "HASCLOSED";
        order.closed_at   = TimeToString(OrderCloseTime(),  (TIME_DATE | TIME_MINUTES | TIME_SECONDS));    
        close_result++;
      } 
      else{
        //close_result = OrderSend(request, result);
        if(close_result)
          meta_state     = "CLOSED";
        else
          meta_state     = "NOTCLOSED";
        
        //if(order.price_open == 0)
        //  order.price_open  = HistoryDealGetDouble(order.ticket_deal, DEAL_PRICE);                          
        order.ticket_deal = 0;
        order.price_close = OrderClosePrice();        
        order.closed_at   = TimeToString(OrderCloseTime(),  (TIME_DATE | TIME_MINUTES | TIME_SECONDS));       
        close_result++;
      }
      
      if(meta_state != "NOTFIND"){
        if(order.price_open <= 0.0)
          order.price_open = OrderOpenPrice();

        if(order.price_close <= 0.00)
          order.price_close = OrderClosePrice();

        // If order.open_at is not set or has a default value, fetch the actual opening time
        if(order.open_at == DEFAULT_TIME || StringLen(order.open_at) == 0)
          order.open_at = TimeToString(OrderOpenTime(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      }
      

   // string log_message = StringFormat("#%s - Log Info - LastError: %d - Retcode: %u - ResultComment: %s - Attempt: %d", order.comment, GetLastError(), result_retcode, result_comment, 0);  
   string log_message = SetLogInfo(order.comment, order.ticket_slave, GetLastError(), result_retcode, result_comment, 0);  

   if(ReachMfeTargetBool || ReachLossSetBool) {
     // result_retcode = ReachMfeTargetBool ? 90090 : 90091;
     //meta_state = ReachMfeTargetBool ? "REACHMFE" : "REACHLOSS";
     string reach_state = ReachMfeTargetBool ? "MfeTarget" : "LossSet";
     string reach_symbol = ReachMfeTargetBool ? ">=" : "<=";
     string action_msg = StringFormat("#%s - %s: %s %s %s %s", order.comment, "ReachProfitDay", DoubleToString(ReachProfitDay, 2), reach_symbol, ReachMfeTargetBool ? DoubleToString(ReachMfeTarget, 2) : DoubleToString(ReachLossSet, 2), reach_state);
     AddCommentOnChart(action_msg);
     log_message += " - MoreInfo:"+ action_msg;
   }


   SendMessageToServer(order, action, order.state, meta_state, "MakeOrderClose", log_message);
      
  return close_result;
 }

//+------------------------------------------------------------------+
//| Make a order modify by signal message                            |
//+------------------------------------------------------------------+
long MakeOrderModify(OrderStruct &order,
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
  if(IsTradeAllowed() == false)
    return change;

  if(FindOpenOrderByCommentBool(order.comment) > 0){
    //change = trade.PositionModify(order.ticket_slave, order.stop_loss, order.take_profit);
    change = OrderModify(int(order.ticket_slave), order.price_open, order.stop_loss, order.take_profit, 0, clrNONE);
  }
 
  string result_comment = OrderComment();
  int result_retcode = GetLastError();
  //request.symbol = order.symbol;
  //request.sl     = order.stop_loss;
  //request.tp     = order.take_profit;
  meta_state     = change ? "MODIFY" : "NOTMODIFY";
  change         = change ? order.ticket_slave : INVALID_HANDLE;

  // string log_message = StringFormat("#%s - Log Info - LastError: %d - Retcode: %u - ResultComment: %s - Attempt: %d", order.comment, GetLastError(), result_retcode, result_comment, 0);  
  string log_message = SetLogInfo(order.comment, order.ticket_slave, GetLastError(), result_retcode, result_comment, 0);  

  SendMessageToServer(order, action, order.state, meta_state, "MakeOrderModify", log_message);
  return change;
 }
//+------------------------------------------------------------------+
//| Make a order modify by signal message                            |
//+------------------------------------------------------------------+
long MakeOrderModifyVolume(OrderStruct &order,
                           string action)
 {
  long change = -1;

// Allow signal to modify the order
// The parameter ticketid must be greater than zero
  if(order_allowmodify == false || order.ticket_slave <= 0)
    return change;

// Allow Expert Advisor to modify the order
  if(IsTradeAllowed() == false)
    return change;

  if(FindCloseOrderByCommentBool(order.comment) > 0)
   {
    if(OrderSelect(int(order.ticket_slave), SELECT_BY_TICKET, MODE_TRADES)){;
    
    
    long magicnumber = OrderMagicNumber();
    string comment  = OrderComment();
    }

    if(order.lot > 0)
     {
      MakeOrderOpen(order, action);
     }
    else
     {
      MakeOrderOpen(order, action);
     }
   }
  return change;
 }

//+------------------------------------------------------------------+
//| Make a order close by signal message                             |
//+------------------------------------------------------------------+
long OrderCreate(OrderStruct &order, string action)
{
  ResetLastError();  

  //long ticketid     = -1;
  int order_result = false;

  //double volume = order.lot;
  
  string meta_message, result_comment;
  string meta_state, log_message, action_msg;

  for(int count = 0; count <= 2; count++)
  {
    if(AccountMarginMode() == "HEDGING"){
        //if(FindOpenOrderByComment(request.comment) != -1)
        //    return false;

        if(order.state != "pending")
            return false;
    }

    if(action == "MODIFY_VOLUME"){
      double lot = OrderLots();
      order.lot = order.lot - lot;
    }
    int result_retcode = GetLastError();
    if(count == 2 || (result_retcode == 130 && (order.type == 0 || order.type == 1)))       // if problem TP SL
    {
      order.stop_loss   = 0;
      order.take_profit = 0;
    }

    if(FindCloseOrderByCommentBool(order.comment) == false && ReachMfeTargetBool == false && ReachLossSetBool == false){
      if(order.seconds_ago <= MaxSeconds){
        order.ticket_slave  = OrderSend(order.symbol, int(order.type), order.lot, order.price_open, int(Slippage), order.stop_loss, order.take_profit, order.comment, int(order.magicnumber), 0, clrNONE); // OrderSend to MetaTrader         
        result_retcode = GetLastError();
      } else {
        result_retcode = 90099;        // if seconds_go > MaxSeconds
      }
    } else {
      result_retcode = 90016;        // if already open
      meta_state = "OPENED";
    }

    if(ReachMfeTargetBool || ReachLossSetBool) {
      result_retcode = ReachMfeTargetBool ? 90090 : 90091;
      meta_state = ReachMfeTargetBool ? "REACHMFE" : "REACHLOSS";
      action_msg = StringFormat("#%s - %s: %s >= %s", order.comment, meta_state, DoubleToString(ReachProfitDay, 2), ReachMfeTargetBool ? DoubleToString(ReachMfeTarget, 2) : DoubleToString(ReachLossSet, 2));
      AddCommentOnChart(action_msg);
    } else if(result_retcode == 0){
        meta_state = action;      
    } else if(result_retcode == 90099){
        meta_state = "TIMEMAX";
        action_msg = StringFormat("#%s - Time Max: OrderSeconds: %d >= %d MaxSeconds", order.comment, order.seconds_ago, MaxSeconds);
        AddCommentOnChart(action_msg);
    } else if(result_retcode == 90016){
        meta_state = "OPENED";
    } else if(result_retcode == 130){
        meta_state = "NOSLTP";
    } else
      meta_state = "ERRORDEAL";


    if(result_retcode == 0)
      result_comment = "Accept Order";
     else
      result_comment = "Deny Order";
        
    if(meta_state == "OPENED" || meta_state == "OPEN"){
      if(OrderSelect(int(order.ticket_slave), SELECT_BY_TICKET, MODE_TRADES)){        
        order.ticket_deal = 0;
        
        order.price_open  = OrderOpenPrice();
        order.stop_loss   = OrderStopLoss();
        order.take_profit = OrderTakeProfit();
        order.lot         = OrderLots();
        order.open_at     = TimeToString(OrderOpenTime(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
        
        if(order.price_open == 0)
          order.price_open = OrderOpenPrice();
      }
    }

    //ticketid = FindOpenOrderByComment(order.comment);
    
    // log_message = StringFormat("#%s - Log Info - LastError: %d - Retcode: %u - ResultComment: %s - Attempt: %d", order.comment, GetLastError(), result_retcode, result_comment, count);
    log_message = SetLogInfo(order.comment, order.ticket_slave, GetLastError(), result_retcode, result_comment, count);  

    SendMessageToServer(order, action, order.state, meta_state, "OrderCreate", log_message);

    if(result_retcode == 0 || result_retcode == 90099 || result_retcode == 90016 || result_retcode == 90090 || result_retcode == 90091)
      break;
  }

  return order.ticket_slave;
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
      TimeToString(TimeCurrent(), (TIME_DATE | TIME_MINUTES | TIME_SECONDS)),
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
//| SendMessageToServer                                              |
//+------------------------------------------------------------------+
void SendMessageToServer(OrderStruct &order, string const action, string const state, string const meta_state, const string fuction_name, string log_message)
 {
  int    symbol_digit = int(MarketInfo(order.symbol, MODE_DIGITS));
  string meta_message = StringFormat("#%s - Ticket: %d - %s - Symbol: %s - Type: %s  - Volume: %s - TP: %s - SL: %s - Action: %s - Meta State: %s", order.comment, order.ticket_slave, fuction_name, order.symbol, IntegerToString(order.type), DoubleToString(order.lot,2), DoubleToString(order.stop_loss, symbol_digit), DoubleToString(order.take_profit, symbol_digit), ToUpper(action), meta_state);

  AddCommentOnChart(meta_message);
  AddCommentOnChart(log_message);

  double sprofit = OrderProfit();

  string message_format = MessageSendFormat(order.magicnumber, action, state, meta_state, order.ticket_slave, order.ticket_master, order.ticket_deal, order.symbol, order.type, order.price_open, order.price_close, order.lot, order.stop_loss, order.take_profit, sprofit, order.comment, order.open_at, order.closed_at, (meta_message +" - LogMessage: "+ log_message));

  ApiTrasmitInformation(message_format, meta_state);
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
long FindOpenOrderByCommentLong(string comment){
  for(int i = OrdersTotal()-1; i >= 0; i--){
    if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
      int order_ticket = OrderTicket();        
      if(OrderComment() == comment)
        return order_ticket;
    }
  }
  return INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Find a current order by server signal                            |
//+------------------------------------------------------------------+
bool FindOpenOrderByCommentBool(string comment){
  for(int i = OrdersTotal()-1; i >= 0; i--){
    if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
      int order_ticket = OrderTicket();        
      if(OrderComment() == comment)
        return true;
    }
  }
  return false;
}

//+------------------------------------------------------------------+
//| Find a current order by server signal                            |
//+------------------------------------------------------------------+
long FindCloseOrderTicketByCommentLong(string comment){
  for(int i = OrdersHistoryTotal()-1; i >= 0; i--){
    if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
      int order_ticket = OrderTicket();        
      if(OrderComment() == comment)
        return long(order_ticket); // Quando a ordem desejada for encontrada, retorna o ticket
    }
  }
  return INVALID_HANDLE; // Retorna um handle inválido se a ordem não for encontrada
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool FindCloseOrderByCommentBool(const string comment){
  for(int i = OrdersHistoryTotal()-1; i >= 0; i--){
    if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)){
      ulong order_ticket = OrderTicket();        
      if(OrderComment() == comment)
        return true;
    }
  }
  return false;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long FindCloseOrderByCommentLong(const string comment){
  for(int i = OrdersHistoryTotal()-1; i >= 0; i--){
    if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)){
      long order_ticket = OrderTicket();        
      if(OrderComment() == comment)
        return order_ticket;
    }
  }
  return false;
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
//|                                                                  |
//+------------------------------------------------------------------+
string AttributeChangeString(string comment, long ticketid, string attributeName, double oldValue, double newValue, string symbol)
{
    string message;
    int symbol_digit; 
    
    if(attributeName == "volume")
      symbol_digit = 2;
    else
      symbol_digit = int(SymbolInfoInteger(symbol, SYMBOL_DIGITS));

    message = StringFormat("#%s - Ticket: %d - Order Modify: %s changed from: %s to: %s",
                                    comment,
                                    ticketid,
                                    ToUpper(attributeName),
                                    ToUpper(DoubleToString(oldValue, symbol_digit)),
                                    ToUpper(DoubleToString(newValue, symbol_digit)));


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
//|            CheckOrdersAlreadyClosed                                     |
//+------------------------------------------------------------------+
void CheckOrdersAlreadyClosed(OrderStruct &orders[])
{
  for(int i = 0; i < OrdersTotal(); i++){
    if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)){    
      ulong ticketid = OrderTicket();
      string comment = OrderComment();
      
      if(OrderMagicNumber() == 0)
        continue;
      
      int order_index = FindApiOrdersByTicketId(orders, comment);

      // Check if the order is closed or not found in the orders array
      if(order_index >= 0){
        if(FindCloseOrderByCommentBool(orders[order_index].comment))
          MakeOrder(orders[order_index], "CLOSED");
      }
      //else
      //{
      //  // The order is open but not found in the orders array
      //  // Add code here to handle this situation
      //  OrderStruct missingOrder;
      //  missingOrder.ticket_master  = StringToInteger(comment);
      //  missingOrder.ticket_slave   = long(ticketid);
      //  missingOrder.comment        = comment;
      //  missingOrder.symbol         = OrderSymbol();
      //  missingOrder.magicnumber    = OrderMagicNumber();
      //  missingOrder.type           = OrderType();
      //  MakeOrder(missingOrder, "CLOSED");
      //}
    }
  }
}
   
//+------------------------------------------------------------------+
//|                                                    |
//+------------------------------------------------------------------+

// Função para verificar e fechar todas as operações se necessário
void CheckTargetsAndCloseTrades(OrderStruct &orders[]){
  ReachLossDay = 0;
 
  if((ReachMfeTargetBool || ReachLossSetBool) || (ReachMfeTarget == 0 || ReachLossSet == 0))
    return;
    
  datetime today = TimeCurrent() - (TimeCurrent() % 86400);

  for(int i = OrdersHistoryTotal()-1; i >= 0; i--){
    ulong deal_ticket = 0;   
    long ticketid  = OrderTicket();
    long magic_number = OrderMagicNumber();
      
    if(magic_number == 0)
      continue;                 
      
    datetime order_date = datetime(OrderCloseTime());
    if(order_date < today)
      break;
      
    string comment = OrderComment();    
      
    ReachLossDay += OrderProfit();
    if(ReachLossSet != 0 && ReachLossDay <= ReachLossSet) {      
      ReachLossSetBool = true;
    }         
  }
   
  // Calcular lucro/perda total de todas as operações
  ReachProfitDay = ReachLossDay;
  for(int i = 0; i < ArraySize(orders); i++ ){
    if(OrderSelect((int)orders[i].ticket_slave, SELECT_BY_TICKET, MODE_TRADES))        
      ReachProfitDay += OrderProfit();
  }
  // Verificar MFE Target e Loss Target
  if(ReachMfeTarget != 0 && ReachProfitDay >= ReachMfeTarget) {
   ReachMfeTargetBool = true;
   ReachLossSetBool = false;
   ReachLossDay     = 0;
  }
  
  if(ReachLossSetBool || ReachMfeTargetBool)
    CloseAllTrades(orders);

  // if(ReachProfitDayLast != ReachProfitDay && ReachProfitDay != 0){
  if(ReachProfitDayLast != ReachProfitDay && ReachMfeTargetBool){
    ReachProfitDayLast = ReachProfitDay;
    AddCommentOnChart("MFE Target: "+ ToUpper(string(ReachMfeTargetBool))+" - | - Day Profit " +DoubleToString(ReachProfitDay, 2)+ " > " +DoubleToString(ReachMfeTarget, 2)+ " Mfe Target", 5);
  }
  
  // if(ReachLossDayLast != ReachLossDay && ReachProfitDay != 0){
  if(ReachLossDayLast != ReachLossDay && ReachLossSetBool){
    ReachLossDayLast = ReachLossDay;
    AddCommentOnChart("LOSS Set: "+ ToUpper(string(ReachLossSetBool))+" - | - Day Loss " +DoubleToString(ReachLossDay,   2)+ " < " +DoubleToString(ReachLossSet,   2)+ " Loss Set",   4);
  } 
}

//+------------------------------------------------------------------+
//|                                                    |
//+------------------------------------------------------------------+
// Função para fechar todas as operações
void CloseAllTrades(OrderStruct &orders[]){
  for(int i = 0; i < ArraySize(orders); i++ ){
    MakeOrder(orders[i], "CLOSED");
  }
}

//+------------------------------------------------------------------+