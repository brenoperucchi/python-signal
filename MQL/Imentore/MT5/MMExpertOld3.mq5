//+------------------------------------------------------------------+
//|                                                       Expert.mq5 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                                       Expert     |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>

CTrade         trade;
COrderInfo     OrderInfo;     //Library for Orders information
CPositionInfo  PositionInfo;  // Library for all position features and information
MqlDateTime    mqlTime;

// Coloração
enum EnumStrategyMode{
    iStrModeHLo = 2,           //High and low
    iStrModeRsiMa = 1,         //RSI + MA cross
    iStrModeDefault = 0,       //RSI + MA cross + High/Low
  };
enum EnumOrderType{
    iOrderTypeLimit = 1,       //Order Limit
    iOrderTypeMarket = 0,      //Order Market
  };
enum EnumCrossMode{
    iOrderCrossMa2  = 2,      //2 Averages Moving
    iOrderCrossMa3  = 3,      //3 Averages Moving
  };
enum EnumGapMode{
    iGapModeKind3  = 3,      //DayOfDay + Cross Ma
    iGapModeKind2  = 2,      //Cross Ma
    iGapModeKind1  = 1,      //DayOfDay
  };
enum EnumStopLossMode{
    iStopLossMode2 = 2,      //Stop Loss Ma9
    iStopLossMode1 = 1,      //Stop Loss Points
  };
enum EnumProfitMode{
    iProfitModePercent = 2,      //Percent    
    iProfitModePoint   = 1,      //Point
  };  
  
input EnumStrategyMode iStrMode      = iStrModeDefault;  // StrategyMode 
input EnumOrderType    iOrderType    = iOrderTypeLimit;  // EnumOrderType 
input EnumCrossMode    iCrossMode    = iOrderCrossMa3;   // EnumCrossMode  


input group           "Management"
input double  lot_size               = 1;
input long    iMagicNumber           = 9901;
input int     take_profit_points     = 500;
input int     stop_loss_points       = 500;
input EnumStopLossMode iStopLossMode = iStopLossMode1;   // EnumStopLossMode

input group           "Tralling"
input bool iTrallingStop           = true; 
input int  trailing_stop_start     = 150;
input int  trailing_stop_distance  = 50;

input group           "RSI"
input int rsi_period              = 9;                // Período do RSI
input int rsi_level_buy           = 70;               // Nível do RSI para compra
input int rsi_level_sell          = 30;               // Nível do RSI para venda

input group           "Gap"
input EnumGapMode iGapMode        = iGapModeKind1;    // EnumGapMode
input int         iGapPrice1      = 500;
input int         iGapPrice2      = 500;

input group           "Risk/Management"
input EnumProfitMode    iProfitMode    = iProfitModePercent;   // EnumCrossMode  
input double iDailyProfitLimit   = 1.0;  // Limite diário  em Point/Percent
input double iWeeklyProfitLimit  = 5.0;  // Limite semanal em Point/Percent
input double iMonthlyProfitLimit = 10.0; // Limite mensal  em Point/Percent

ENUM_POSITION_TYPE currentPositionType;  

bool      FirstRun                     = true;
bool      iPositionOpen                = false;
bool      iCrossUp, iCrossDown         = false;
bool      ConditionBuy, ConditionSell  = false;
double    initialBalance               = AccountInfoDouble(ACCOUNT_BALANCE);  // Salva o saldo inicial da conta

int       handleMa9, handleMa20, handleMa50,handleRsi;
ulong     TicketID;
double    PriceClose[], close[], LastCandlePrice1, LastCandlePrice2, CandleCrossPrice;
double    ma9[], ma20[], ma50[], rsi[];

datetime  LastBarTime, iLastTradeTime;
datetime  CurrentDay = TimeLocal() - TimeLocal() % 86400;
datetime  DailyDate;
datetime  WeekDate; 
datetime  MonthDate; 

double initialCapital;
//GainLimits percentageLimits;

double DailyProfitAmount      = 0;
double WeeklyProfitAmount     = 0;
double MonthlyProfitAmount    = 0;

long DailyProfitPoint         = 0;
long WeeklyProfitPoint        = 0;
long MonthlyProfitPoint       = 0;

#include <Arrays\ArrayObj.mqh>

// Classe OrderHistory herda de CObject
class OrderHistory : public CObject {
public:
    ulong dealTicket;
    ulong orderTicket;
    ulong positionID;
    double openPrice;
    double closePrice;
    double profit;
    double comission;
    double fee;
    double swap;
    datetime openTime;
    datetime closeTime;
    long type;
    long direction;

    // Construtor com parâmetros renomeados
    OrderHistory(ulong _dealTicket, ulong _orderTicket, ulong _positionID, double _openPrice, double _closePrice,
                 double _profit, double _comission, double _fee, double _swap, datetime _openTime, datetime _closeTime,
                 long _type, long _direction) {
        dealTicket = _dealTicket;
        orderTicket = _orderTicket;
        positionID = _positionID;
        openPrice = _openPrice;
        closePrice = _closePrice;
        profit = _profit;
        comission = _comission;
        fee = _fee;
        swap = _swap;
        openTime = _openTime;
        closeTime = _closeTime;
        type = _type;
        direction = _direction;
    }
};

// Declarando e instanciando o array de objetos
CArrayObj OrderHistoryArray;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
  trade.SetExpertMagicNumber(iMagicNumber);
   
// Definindo as cores das médias móveis
  color ma_color_1 = clrGreen;
  color ma_color_2 = clrYellow;
  color ma_color_3 = clrLightBlue;

// Criando as médias móveis
  CreateMovingAverage(9, ma_color_1);
  CreateMovingAverage(20, ma_color_2);
  CreateMovingAverage(50, ma_color_3);

  handleMa9 = iMA(Symbol(),  PERIOD_CURRENT, 9, 0,  MODE_SMA, PRICE_CLOSE);
  handleMa20 = iMA(Symbol(), PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
  handleMa50 = iMA(Symbol(), PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
  handleRsi = iRSI(NULL, 0, rsi_period, PRICE_CLOSE);

  ArraySetAsSeries(ma9, true);
  ArraySetAsSeries(ma20, true);
  ArraySetAsSeries(ma50, true);
  ArraySetAsSeries(rsi, true);
  ArraySetAsSeries(PriceClose, true);
  
  CopyClose(Symbol(),PERIOD_CURRENT ,0, 3, PriceClose);
  LastCandlePrice2 = PriceClose[1];
  
  TimeToStruct(TimeTradeServer(), mqlTime);

  datetime now = TimeCurrent();
  DailyDate = now - (now % 86400);
  WeekDate  = DailyDate - ((mqlTime.day_of_week - 1) * 86400);
  MonthDate = DailyDate - ((mqlTime.day - 1) * 86400);

  LoadHistoricalTrades();

  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
  Print("Profit orderHistory ->", GetProfitOrdersHistory());
  Print("Profit HistoryDeals ->", GetProfitHistoryDeals());
  for(int i = 0; i < OrderHistoryArray.Total(); i++) {
      delete OrderHistoryArray.At(i);
  }
  OrderHistoryArray.Clear();
  ObjectsDeleteAll(0);

}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
  CopyBuffer(handleMa9, 0, 0, 3, ma9);  // Obter os três últimos valores da MA9
  CopyBuffer(handleMa20, 0, 0, 3, ma20);
  CopyBuffer(handleMa50, 0, 0, 3, ma50);
  CopyBuffer(handleRsi, 0, 0, 3, rsi);  
  CopyClose(Symbol(),PERIOD_CURRENT ,0, 3, PriceClose);

  datetime currentBarTime = iTime(_Symbol, _Period, 0);
  static datetime lastTradeTime = 0;
  TimeToStruct(TimeCurrent(), mqlTime);
  
  // Close All Positions by Time
  if ((OrdersTotal() > 0 || PositionsTotal() > 0) && mqlTime.hour >= 17 && mqlTime.min >= 30)
    CloseAllPositions();
  
  // Execute only on New Candle
  if(currentBarTime != LastBarTime) {
    // New Current BarTime
    LastBarTime = currentBarTime;
    LastCandlePrice1 = LastCandlePrice2;
    LastCandlePrice2 = PriceClose[1];
  }

  datetime currentNextDay = TimeTradeServer() - TimeLocal() % 86400;

  if (CurrentDay != currentNextDay) {
    CurrentDay      = currentNextDay;
    iCrossUp        = false;
    iCrossDown      = false;
    initialBalance  = AccountInfoDouble(ACCOUNT_BALANCE);
  }

  // Verifica se o limite de lucro foi atingido antes de abrir novas posições
  if (CheckProfitLimit()) {
      return;
  }   

  if(PositionsTotal() == 0 && OrdersTotal() == 0 && iPositionOpen) {
    iCrossUp      = false;
    iCrossDown    = false;
    iPositionOpen = false;
    TicketID      = 0;
  }
  // Verificar se já temos uma posição aberta ou ordem pendente
  if(PositionsTotal() > 0 || OrdersTotal() > 0) {
    iPositionOpen = true;
    //} else if(!hasPendingOrder()){
    // TicketID     = 0;
    // positionOpen = false;
  }

  if(CrossedAbove(ma9, ma20)) {
    iCrossUp = true;
    iCrossDown = false;
    CandleCrossPrice = ma9[0];
  } else if(CrossedBelow(ma9, ma20)) {
    iCrossUp = false;
    iCrossDown = true;
    CandleCrossPrice = ma9[0];
  }
  
  bool rsiConditionBuy  = (rsi[1] > rsi_level_buy ); // || (rsi[1]) > rsi_level_buy);
  bool rsiConditionSell = (rsi[1] < rsi_level_sell); // || (rsi[1]) < rsi_level_sell);
  
  if(iStrMode == 0){
    bool maAboveCondition = MaAbove(PriceClose, ma9, ma20, ma50);
    bool maBelowCondition = MaBelow(PriceClose, ma9, ma20, ma50);    
    ConditionBuy  = maAboveCondition && rsiConditionBuy  && iCrossUp;
    ConditionSell = maBelowCondition && rsiConditionSell && iCrossDown;
  }
  else if(iStrMode == 1){
    ConditionBuy  = rsiConditionBuy && iCrossUp;
    ConditionSell = rsiConditionSell && iCrossDown;
  }
    
  if (mqlTime.hour >= 9 || mqlTime.hour >= 16){
    if(GapInitialPrice()){
      if(ConditionBuy){OpenPositionBuy();}
      else if(ConditionSell){OpenPositionSell();}    
    }
  }
  
  //Tralling Stop
  if(iTrallingStop)
    TrallingStop();
}

//+------------------------------------------------------------------+
bool GapInitialPrice(){
  int gapDay   = int(MathAbs(PriceClose[0] - LastCandlePrice1));
  int gapMA    = int(MathAbs(ma20[0] - PriceClose[0]));
  int gapCross = int(MathAbs(PriceClose[0] - CandleCrossPrice));
  bool condition1 = gapDay   > iGapPrice1;
  bool condition2 = gapMA    > iGapPrice2;
  bool condition3 = (gapCross > iGapPrice1) && (iCrossUp || iCrossDown);
  bool condition  = condition1 && condition2;
  
  switch(iGapMode)
    {
     case 1:
       condition = condition1 && condition2;
       break;
     case 2:
       condition = condition3;
       break;
     case 3:
       condition = condition1 && condition2 && condition3;
       break;
    }
  return !condition;
}

//+------------------------------------------------------------------+
void TrallingStop(){
// Trailing stop
  for (int i = 0; i < PositionsTotal(); i++) {
    ulong ticket = PositionGetTicket(i);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double stopLoss = PositionGetDouble(POSITION_SL);
    double takeProfit = PositionGetDouble(POSITION_TP);
    
    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
      double point = Point();
      bool condition1 = (PriceClose[0] - openPrice) >= trailing_stop_start * point;
      bool condition2 = (PriceClose[0] - stopLoss) >= trailing_stop_start * point;

      if (condition1 && condition2) {
        trade.PositionModify(ticket, (PriceClose[0] - trailing_stop_distance * point), takeProfit);
      }
    }
    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
      double point = Point();
      openPrice = openPrice - PriceClose[0];
      stopLoss = stopLoss  - PriceClose[0];
      bool condition1 = openPrice >= trailing_stop_start;
      bool condition2 = stopLoss >= trailing_stop_start;

      if (condition1 && condition2) {
        trade.PositionModify(ticket, (PriceClose[0] + trailing_stop_distance * point), takeProfit);
      }
    }
  }
}

//+------------------------------------------------------------------+
void OpenPositionBuy(){
  
// Regras para compra
  if(!iPositionOpen) {
    if(ConditionBuy) {
      bool trade_in;
      if(iOrderType == 1)
        trade_in = trade.BuyLimit(lot_size, PriceBuyLimit(), Symbol(), StopLoss(ORDER_TYPE_BUY_LIMIT), BuyTP(ma9), ORDER_TIME_DAY, 0, "Ordem Pendente Compra");
      else{        
        double askPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        trade_in = trade.Buy(lot_size, Symbol(), 0, StopLoss(ORDER_TYPE_BUY) , (ma9[0] + take_profit_points), "Ordem Pendente Compra");
      }     
      TicketID = trade.ResultOrder();
      
      if(!trade_in)
        Print("ID# ",trade.ResultOrder(), " - Buy method failed. Return code=",trade.ResultRetcode(),". Descrição do código: ",trade.ResultRetcodeDescription());
      else
        Print("Buy method executed successfully. Return code=",trade.ResultRetcode()," (",trade.ResultRetcodeDescription(),")");

      iLastTradeTime = TimeCurrent();
    }
  } else {
    if(hasBuy() && iOrderType == 1) {
          string dateTime = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);

      if(MaAbove(PriceClose, ma9, ma20, ma50))
        trade.OrderModify(TicketID, PriceBuyLimit(), StopLoss(ORDER_TYPE_BUY_LIMIT), NormalizePricePoints(BuyTP(ma9)), ORDER_TIME_DAY, 0, 0);
      else
        trade.OrderDelete(TicketID);
    }
  }
}

//+------------------------------------------------------------------+
void OpenPositionSell(){
// Regras para venda
  if(!iPositionOpen) {

    if(ConditionSell) {
      bool trade_in;
      if(iOrderType == 1)
        trade_in = trade.SellLimit(lot_size, NormalizePricePoints(ma9[0]), Symbol(),  StopLoss(ORDER_TYPE_SELL_LIMIT), SellTP(PriceClose), ORDER_TIME_DAY, 0, "Ordem Pendente Venda");
      else{
        double bidPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        trade_in = trade.Sell(lot_size, Symbol(), 0, StopLoss(ORDER_TYPE_SELL), NormalizePricePoints(ma9[0] - take_profit_points), "Ordem Pendente Compra");
      }     

      TicketID = trade.ResultOrder();
      if(!trade_in)        
        Print("ID# ",trade.ResultOrder(), " - Sell method failed. Return code=",trade.ResultRetcode(),". Descrição do código: ",trade.ResultRetcodeDescription());
      else
        Print("Sell method executed successfully. Return code=",trade.ResultRetcode()," (",trade.ResultRetcodeDescription(),")");
      
      iLastTradeTime = TimeCurrent();
    }
  } else {
    if(hasSell() && iOrderType == 1) {
    string dateTime = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      if(MaBelow(PriceClose, ma9, ma20, ma50))
        trade.OrderModify(TicketID, PriceSellLimit(), StopLoss(ORDER_TYPE_SELL_LIMIT), NormalizePricePoints(SellTP(ma9)), ORDER_TIME_DAY, 0, 0);
      else
        trade.OrderDelete(TicketID);
    }
  }
}

//+------------------------------------------------------------------+
double StopLoss(const int orderType){
  double stopLoss = 0;
  
  if(iStopLossMode == 1){
    if(orderType == 2)
      stopLoss  = ma9[0] - stop_loss_points;
    if(orderType == 3)
      stopLoss  = ma9[0] + stop_loss_points;
    else if(orderType == 0)
      stopLoss  = ma9[0] - stop_loss_points;
    else if(orderType == 1)
      stopLoss = ma9[0] + stop_loss_points;

  } else if(iStopLossMode == 2)
    stopLoss = ma9[1];
  return NormalizePricePoints(stopLoss);
}
double BuyTP(double& maPrice[]) { return NormalizePricePoints(maPrice[0] + take_profit_points); }
double SellTP(double& maPrice[]) { return NormalizePricePoints(maPrice[0] - take_profit_points); }

double PriceBuyLimit() { return NormalizePricePoints(ma9[0] - 50); }
double PriceSellLimit() { return NormalizePricePoints(ma9[0] + 50); }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Função para criar média móvel                                    |
//+------------------------------------------------------------------+
void CreateMovingAverage(int period, color ma_color) {
  string name = "MA" + IntegerToString(period);
  if (ObjectFind(0, name) != 0) {
    ObjectCreate(0, name, OBJ_TREND, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_PERIOD, period);
    ObjectSetInteger(0, name, OBJPROP_COLOR, ma_color);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
  }
}

//+------------------------------------------------------------------+
//| Funções para detectar cruzamentos                                |
//+------------------------------------------------------------------+
bool MaAbove(const double& price[], const double& maFast[], const double& maSlow[], const double& maSSlow[]) {
  if(iCrossMode == 3)
    if (price[0] > maFast[0] && price[0] > maSlow[0] && price[0] > maSSlow[0]) { return true; }
  if(iCrossMode == 2)
    if (price[0] > maFast[0] && price[0] > maSlow[0]){ return true; }
  return false;         
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool MaBelow(const double& price[], const double& maFast[], const double& maSlow[], const double& maSSlow[]) {
  if(iCrossMode == 3)
    if (price[0] < maFast[0] && price[0] < maSlow[0] && price[0] < maSSlow[0]) { return true; }
  if(iCrossMode == 2)
    if (price[0] < maFast[0] && price[0] < maSlow[0]){ return true; }
  return false;
}

//+------------------------------------------------------------------+
//| Funções para detectar cruzamentos                                |
//+------------------------------------------------------------------+
bool CrossedAbove(const double& maFast[], const double& maSlow[]) {
  if (maFast[1] <= maSlow[1] && maFast[0] > maSlow[0])
    return true;
  else
    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CrossedBelow(const double& maFast[], const double& maSlow[]) {
  if (maFast[1] >= maSlow[1] && maFast[0] < maSlow[0]) 
    return true;
  else
    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizePricePoints(double price) {
  double roundedPrice = 0;
  double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  long precision = long(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
  currentPositionType =  ENUM_POSITION_TYPE(PositionGetInteger(POSITION_TYPE));

  if(currentPositionType == POSITION_TYPE_BUY)
    roundedPrice = MathFloor(price / precision) * precision;
  else
    roundedPrice = MathCeil(price / precision) * precision;

  roundedPrice = NormalizeDouble(roundedPrice, _Digits);
  return roundedPrice;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool hasOrder(const string kind) {

  if(kind == "POSITION"){
    if (PositionSelectByTicket(TicketID)) {  
      ENUM_POSITION_TYPE type = ENUM_POSITION_TYPE(PositionGetInteger(POSITION_TYPE));
      return (PositionsTotal() > 0 && ENUM_POSITION_TYPE(PositionGetInteger(POSITION_TYPE)) == type);
    }
  }
  if(kind == "LIMIT"){
    if (OrderSelect(TicketID)) {        
      ENUM_ORDER_TYPE type = ENUM_ORDER_TYPE(OrderGetInteger(ORDER_TYPE));
      return (OrdersTotal() > 0 && ENUM_ORDER_TYPE(OrderGetInteger(ORDER_TYPE)) == type);
    }
  }
      
  return false; // Nada encontrado    
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool hasSell() {
  if(OrderSelect(TicketID)){
    ENUM_ORDER_TYPE orderType = ENUM_ORDER_TYPE(OrderGetInteger(ORDER_TYPE));
    return (OrdersTotal() > 0 && OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT);
  }
  return false;    
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool hasBuy() {
  if(OrderSelect(TicketID)){
    ENUM_ORDER_TYPE orderType = ENUM_ORDER_TYPE(OrderGetInteger(ORDER_TYPE));
    return (OrdersTotal() > 0 && ENUM_ORDER_TYPE(OrderGetInteger(ORDER_TYPE)) == ORDER_TYPE_BUY_LIMIT);
  }
  return false;    
}
//+------------------------------------------------------------------+
void CloseAllPositions(){
   

  for(int i = OrdersTotal() - 1; i >= 0; i--) // loop all Orders
    if(OrderInfo.SelectByIndex(i))  // select an order      
       trade.OrderDelete(OrderInfo.Ticket()); // then delete it --period
  
  for(int i = PositionsTotal() - 1; i >= 0; i--) // loop all Open Positions
    if(PositionInfo.SelectByIndex(i))  // select a position
       trade.PositionClose(PositionInfo.Ticket()); // then close it --period
} 
//+------------------------------------------------------------------+
//| Checa se o limite de lucro foi atingido e retorna verdadeiro     |
//+------------------------------------------------------------------+
bool CheckProfitLimit() {
  bool profit_condition = false;   
  datetime now = TimeCurrent();
  datetime today = now - (now % 86400);
  datetime weekStart = today - ((mqlTime.day_of_week - 1) * 86400);
  datetime monthStart = today - ((mqlTime.day - 1) * 86400);

  if(today > DailyDate){
    DailyProfitAmount = 0;
    FirstRun = true;
  }
  if(weekStart > WeekDate)
    WeeklyProfitAmount = 0;  
  if(monthStart > MonthDate)
    MonthlyProfitAmount = 0;


  if(iDailyProfitLimit > 0 || iWeeklyProfitLimit > 0 || iMonthlyProfitLimit > 0){
    Comment("");

    if(iProfitMode == iProfitModePercent)      
      profit_condition = CheckProfitLimitsPercent();
    //else
    //  profit_condition = CheckProfitLimitsPoint();     
    
    if(profit_condition){
      Comment("Limite diário de lucro atingido.");
      Print("Limite diário de lucro atingido.");
      CloseAllPositions();
      return true;
    }  
  }
  return false;
}
   
//+------------------------------------------------------------------+
bool CheckProfitLimitsPercent(){
  DailyProfitAmount = 0;
  WeeklyProfitAmount = 0;
  MonthlyProfitAmount = 0;
  datetime now = TimeCurrent();
  datetime today = now - (now % 86400);
  TimeToStruct(TimeTradeServer(), mqlTime);
  
  DailyProfitAmount = GetOrderProfitByDate("day");
  WeeklyProfitAmount = GetOrderProfitByDate("week");
  MonthlyProfitAmount = GetOrderProfitByDate("month");

  for(int i=0; i< PositionsTotal(); i++){
    ulong positionTicket = PositionGetTicket(i);
    DailyProfitAmount += PositionGetDouble(POSITION_PROFIT);
  }
  double conditionCalc = (initialBalance * (iDailyProfitLimit / 100.0));
  bool conditionReturn = DailyProfitAmount >= conditionCalc;
  return conditionReturn;
}
   
//+------------------------------------------------------------------+
double GetOrderProfitByTicket(long orderTicket) {
  double profit = 0;
  // Iterar pelas transações para coletar dados de volumes e lucros fechados
  for(int i = HistoryDealsTotal(); i > 0; i--){
    ulong dealTicket = HistoryDealGetTicket(i);
    long position_id = HistoryDealGetInteger(dealTicket, DEAL_ORDER);
    ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
    if((position_id == orderTicket) && (entry_type == DEAL_ENTRY_OUT)){            
      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      profit += dealProfit;
    }
  }
  return profit;
}

//+------------------------------------------------------------------+
double GetOrderProfitByDate(const string dateCondition) {
  double profit = 0;
  
  //Iterar pelas transações para coletar dados de volumes e lucros fechados
  if(dateCondition == "day"){
    profit = DailyProfitAmount;  
  } else if(dateCondition == "week"){
    profit =  WeeklyProfitAmount; 
  } else if(dateCondition == "month"){
    profit =  MonthlyProfitAmount;
  }        

  return profit;

}
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result) {
  // Definindo as condições para clareza e reutilização
  HistorySelect(0, TimeCurrent());
  bool isDealAddedOrRequest = (trans.type == TRADE_TRANSACTION_DEAL_ADD);   
  bool isEntryNotIn = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY) != DEAL_ENTRY_IN;
  // Verificar se a transação deve ser processada
  if (isDealAddedOrRequest && isEntryNotIn) {
    double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
    DailyProfitAmount      += profit;
    WeeklyProfitAmount     += profit;
    MonthlyProfitAmount    += profit;

    // Criar uma nova instância de OrderHistory
    OrderHistory* order = new OrderHistory(
      trans.deal,
      trans.order,
      trans.position,
      trans.price,
      HistoryDealGetDouble(trans.deal, DEAL_PRICE),
      profit,
      HistoryDealGetDouble(trans.deal, DEAL_COMMISSION),
      HistoryDealGetDouble(trans.deal, DEAL_FEE),
      HistoryDealGetDouble(trans.deal, DEAL_SWAP),
      (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME),
      (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME),
      trans.type,
      (long)HistoryDealGetInteger(trans.deal, DEAL_ENTRY)
    );   
    // Adicionar o novo objeto OrderHistory à array
    OrderHistoryArray.Add(order);
  }
}

//+------------------------------------------------------------------+
void LoadHistoricalTrades() {
  HistorySelect(0, TimeCurrent());  // Seleciona todo o histórico disponível até agora
  for (int i = 0; i < HistoryDealsTotal(); i++) {
    ulong  ticket     = HistoryDealGetTicket(i);
    ulong  positionID = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
    double profit     = HistoryDealGetDouble(ticket, DEAL_PROFIT);
    
    DailyProfitAmount      += profit;
    WeeklyProfitAmount     += profit;
    MonthlyProfitAmount    += profit;
    
    if (HistoryDealSelect(ticket) && positionID > 0) {
      // Crie o objeto diretamente com os valores
      OrderHistory* order = new OrderHistory(
          ticket,
          HistoryDealGetInteger(ticket, DEAL_ORDER),
          HistoryDealGetInteger(ticket, DEAL_POSITION_ID),
          HistoryDealGetDouble(ticket, DEAL_PRICE),
          HistoryDealGetDouble(ticket, DEAL_PRICE),
          HistoryDealGetDouble(ticket, DEAL_PROFIT),
          HistoryDealGetDouble(ticket, DEAL_COMMISSION),
          HistoryDealGetDouble(ticket, DEAL_FEE),
          HistoryDealGetDouble(ticket, DEAL_SWAP),
          (datetime)HistoryDealGetInteger(ticket, DEAL_TIME),
          (datetime)HistoryDealGetInteger(ticket, DEAL_TIME),
          HistoryDealGetInteger(ticket, DEAL_TYPE),
          (long)HistoryDealGetInteger(ticket, DEAL_ENTRY)
      );
      OrderHistoryArray.Add(order);
    }
  }
}

//+------------------------------------------------------------------+
double GetProfitOrdersHistory() {  
  double profit = 0;
  // Iterar pelas transações para coletar dados de volumes e lucros fechados
  for(int i = 0; i < OrderHistoryArray.Total(); i++) {
    OrderHistory* order = (OrderHistory*)OrderHistoryArray.At(i); // Cast correto para ponteiro
    if (order != NULL)
      profit += order.profit; // Acesso correto via ponteiro
  }
  return profit;
}

//+------------------------------------------------------------------+
double GetProfitHistoryDeals() {
  double profit = 0;
  HistorySelect(0, TimeCurrent());  // Seleciona todo o histórico disponível até agora
  // Iterar pelas transações para coletar dados de volumes e lucros fechados
  for(int i =0; i < HistoryDealsTotal(); i++){
    ulong dealTicket = HistoryDealGetTicket(i);    
    ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
    if(entry_type != DEAL_ENTRY_IN) {     
      profit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
    }
  }
  return profit;
}