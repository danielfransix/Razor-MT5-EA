//+------------------------------------------------------------------+
//|                                                        RAZOR.mq5 |
//|                                  Copyright 2024, Razor Trading EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Razor Trading EA"
#property link      "https://www.mql5.com"
#property version   "1.00"

//--- Include necessary libraries
#include <Trade\Trade.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

//--- Global objects
CTrade trade;
CChartObjectButton btnKillAll, btnKillBuys, btnKillSells;
CChartObjectLabel lblInfo;

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== TIMEFRAME & TRIGGER ==="
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M1;           // Chart timeframe to monitor for trigger signals
input double InpTriggerDistance = 0.00100;                // Minimum candle movement to trigger trades (pure price distance)

input group "=== TRADING MODE ==="
enum ENUM_TRADING_MODE
{
   MODE_COUNTER_TREND = 0,    // Counter-trend (immediate retracement)
   MODE_TREND_FOLLOWING = 1   // Trend-following (delayed entry with limits)
};
input ENUM_TRADING_MODE InpTradingMode = MODE_COUNTER_TREND;  // Direction of trade relative to trigger candle

input double InpLimitDistance = 0.00050;                  // How far to place pending orders (Mode 2 only)

input group "=== RISK MANAGEMENT ==="
enum ENUM_SL_TYPE
{
   SL_FIXED = 0,             // Fixed stop loss
   SL_TRAILING = 1           // Ghost trailing stop loss
};
input ENUM_SL_TYPE InpStopLossType = SL_FIXED;            // Stop loss management type

input double InpStopLossDistance = 0.00200;               // Stop loss distance from entry (pure price)
input double InpTakeProfitDistance = 0.00300;             // Profit target distance from entry (pure price)
input double InpTrailingDistance = 0.00100;               // Trailing stop distance (for trailing SL)

input group "=== POSITION SIZING ==="
enum ENUM_LOT_MODE
{
   LOT_FIXED = 0,            // Fixed lot size
   LOT_RISK_PERCENT = 1      // Equity risk percentage
};
input ENUM_LOT_MODE InpLotMode = LOT_FIXED;               // Trade size determination method

input double InpFixedLotSize = 0.01;                      // Fixed lot size (minimum 0.01)
input double InpRiskPercent = 2.0;                        // Risk percentage of equity for position sizing

input group "=== EQUITY PROTECTION ==="
input double InpMinimumEquity = 1000.0;                   // Minimum account equity to continue trading

input group "=== CHART DISPLAY ==="
input bool InpShowInfo = true;                            // Show information panel on chart
input int InpInfoXPos = 20;                               // Info panel X position
input int InpInfoYPos = 50;                               // Info panel Y position

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
datetime lastCandleTime = 0;
bool isNewCandle = false;
string eaMagicComment = "RAZOR_EA";
int eaMagicNumber = 123456;

// Position tracking
struct PositionInfo
{
   ulong ticket;
   double openPrice;
   double currentSL;
   double currentTP;
   ENUM_POSITION_TYPE type;
   datetime openTime;
};

PositionInfo activePositions[];
int positionCount = 0;
PositionInfo trackedPositions[];

// Chart objects
string infoLabelName = "RazorInfo";
string btnKillAllName = "RazorKillAll";
string btnKillBuysName = "RazorKillBuys";
string btnKillSellsName = "RazorKillSells";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set trade parameters
   trade.SetExpertMagicNumber(eaMagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(Symbol());
   
   // Initialize chart objects
   if(InpShowInfo)
   {
      CreateChartObjects();
   }
   
   // Initialize position tracking
   ArrayResize(activePositions, 0);
   positionCount = 0;
   
   // Get initial candle time
   lastCandleTime = iTime(Symbol(), InpTimeframe, 0);
   
   Print("Razor EA initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up chart objects
   DeleteChartObjects();
   
   Print("Razor EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new candle
   CheckNewCandle();
   
   // Update position tracking
   UpdatePositions();
   
   // Handle trailing stops
   if(InpStopLossType == SL_TRAILING)
   {
      HandleTrailingStops();
   }
   
   // Check equity protection
   if(!CheckEquityProtection())
   {
      return;
   }
   
   // Process new candle if available
   if(isNewCandle)
   {
      ProcessNewCandle();
      isNewCandle = false;
   }
   
   // Update chart display
   if(InpShowInfo)
   {
      UpdateChartInfo();
   }
}

//+------------------------------------------------------------------+
//| Check for new candle                                            |
//+------------------------------------------------------------------+
void CheckNewCandle()
{
   datetime currentCandleTime = iTime(Symbol(), InpTimeframe, 0);
   
   if(currentCandleTime != lastCandleTime)
   {
      isNewCandle = true;
      lastCandleTime = currentCandleTime;
   }
}

//+------------------------------------------------------------------+
//| Process new candle for trigger detection                        |
//+------------------------------------------------------------------+
void ProcessNewCandle()
{
   // Get previous candle data (index 1 = completed candle)
   double high = iHigh(Symbol(), InpTimeframe, 1);
   double low = iLow(Symbol(), InpTimeframe, 1);
   double open = iOpen(Symbol(), InpTimeframe, 1);
   double close = iClose(Symbol(), InpTimeframe, 1);
   
   // Calculate pure price movement
   double candleRange = high - low;
   
   // Check if trigger condition is met
   if(candleRange >= InpTriggerDistance)
   {
      // Determine candle direction
      bool isBullish = close > open;
      bool isBearish = close < open;
      
      if(isBullish || isBearish)
      {
         ProcessTrigger(isBullish, high, low, close);
      }
   }
}

//+------------------------------------------------------------------+
//| Process trigger and execute trades                              |
//+------------------------------------------------------------------+
void ProcessTrigger(bool isBullish, double high, double low, double currentPrice)
{
   if(InpTradingMode == MODE_COUNTER_TREND)
   {
      // Counter-trend: trade opposite to candle direction
      if(isBullish)
      {
         // Large bullish candle -> open SELL
         OpenMarketPosition(POSITION_TYPE_SELL, currentPrice);
      }
      else
      {
         // Large bearish candle -> open BUY
         OpenMarketPosition(POSITION_TYPE_BUY, currentPrice);
      }
   }
   else if(InpTradingMode == MODE_TREND_FOLLOWING)
   {
      // Trend-following: place limit orders in same direction
      if(isBullish)
      {
         // Large bullish candle -> place BUY LIMIT below current price
         double limitPrice = currentPrice - InpLimitDistance;
         PlaceLimitOrder(ORDER_TYPE_BUY_LIMIT, limitPrice);
      }
      else
      {
         // Large bearish candle -> place SELL LIMIT above current price
         double limitPrice = currentPrice + InpLimitDistance;
         PlaceLimitOrder(ORDER_TYPE_SELL_LIMIT, limitPrice);
      }
   }
}

//+------------------------------------------------------------------+
//| Open market position                                            |
//+------------------------------------------------------------------+
void OpenMarketPosition(ENUM_POSITION_TYPE posType, double currentPrice)
{
   double lotSize = CalculateLotSize();
   double sl, tp;
   
   if(posType == POSITION_TYPE_BUY)
   {
      sl = currentPrice - InpStopLossDistance;
      tp = currentPrice + InpTakeProfitDistance;
      
      if(trade.Buy(lotSize, Symbol(), 0, NormalizePrice(sl), NormalizePrice(tp), eaMagicComment))
      {
         ulong ticket = trade.ResultOrder();
         AddPositionToTracking(ticket, currentPrice, sl, tp, posType);
         Print("BUY position opened. Ticket: ", ticket);
      }
   }
   else
   {
      sl = currentPrice + InpStopLossDistance;
      tp = currentPrice - InpTakeProfitDistance;
      
      if(trade.Sell(lotSize, Symbol(), 0, NormalizePrice(sl), NormalizePrice(tp), eaMagicComment))
      {
         ulong ticket = trade.ResultOrder();
         AddPositionToTracking(ticket, currentPrice, sl, tp, posType);
         Print("SELL position opened. Ticket: ", ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Place limit order                                               |
//+------------------------------------------------------------------+
void PlaceLimitOrder(ENUM_ORDER_TYPE orderType, double limitPrice)
{
   double lotSize = CalculateLotSize();
   double sl, tp;
   
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      sl = limitPrice - InpStopLossDistance;
      tp = limitPrice + InpTakeProfitDistance;
      
      if(trade.BuyLimit(lotSize, NormalizePrice(limitPrice), Symbol(), NormalizePrice(sl), NormalizePrice(tp), ORDER_TIME_GTC, 0, eaMagicComment))
      {
         Print("BUY LIMIT order placed at: ", limitPrice);
      }
   }
   else
   {
      sl = limitPrice + InpStopLossDistance;
      tp = limitPrice - InpTakeProfitDistance;
      
      if(trade.SellLimit(lotSize, NormalizePrice(limitPrice), Symbol(), NormalizePrice(sl), NormalizePrice(tp), ORDER_TIME_GTC, 0, eaMagicComment))
      {
         Print("SELL LIMIT order placed at: ", limitPrice);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on settings                            |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   if(InpLotMode == LOT_FIXED)
   {
      return MathMax(0.01, InpFixedLotSize);
   }
   else
   {
      // Risk percentage calculation
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskAmount = equity * InpRiskPercent / 100.0;
      double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
      
      if(tickValue > 0 && tickSize > 0)
      {
         double lotSize = riskAmount / (InpStopLossDistance / tickSize * tickValue);
         return MathMax(0.01, NormalizeDouble(lotSize, 2));
      }
      
      return 0.01; // Fallback to minimum
   }
}

//+------------------------------------------------------------------+
//| Position tracking functions                                     |
//+------------------------------------------------------------------+
void AddPositionToTracking(ulong ticket, double openPrice, double sl, double tp, ENUM_POSITION_TYPE type)
{
   ArrayResize(activePositions, positionCount + 1);
   activePositions[positionCount].ticket = ticket;
   activePositions[positionCount].openPrice = openPrice;
   activePositions[positionCount].currentSL = sl;
   activePositions[positionCount].currentTP = tp;
   activePositions[positionCount].type = type;
   activePositions[positionCount].openTime = TimeCurrent();
   positionCount++;
}

void UpdatePositions()
{
   // Update position tracking array
   for(int i = positionCount - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(activePositions[i].ticket))
      {
         // Position closed, remove from tracking
         RemovePositionFromTracking(i);
      }
      else
      {
         // Update current SL/TP if they changed
         activePositions[i].currentSL = PositionGetDouble(POSITION_SL);
         activePositions[i].currentTP = PositionGetDouble(POSITION_TP);
      }
   }
   
   // Check for parameter changes and update existing positions
   UpdatePositionsForConfigChanges();
}

void RemovePositionFromTracking(int index)
{
   for(int i = index; i < positionCount - 1; i++)
   {
      activePositions[i] = activePositions[i + 1];
   }
   positionCount--;
   ArrayResize(activePositions, positionCount);
}

void RemovePositionFromTracking(ulong ticket)
{
   for(int i = 0; i < positionCount; i++)
   {
      if(activePositions[i].ticket == ticket)
      {
         RemovePositionFromTracking(i);
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Update positions when configuration changes                     |
//+------------------------------------------------------------------+
void UpdatePositionsForConfigChanges()
{
   for(int i = 0; i < positionCount; i++)
   {
      if(PositionSelectByTicket(activePositions[i].ticket))
      {
         double openPrice = activePositions[i].openPrice;
         
         // Calculate new SL and TP based on current settings
         double newSL, newTP;
         
         if(activePositions[i].type == POSITION_TYPE_BUY)
         {
            newSL = openPrice - InpStopLossDistance;
            newTP = openPrice + InpTakeProfitDistance;
         }
         else
         {
            newSL = openPrice + InpStopLossDistance;
            newTP = openPrice - InpTakeProfitDistance;
         }
         
         newSL = NormalizeDouble(newSL, _Digits);
         newTP = NormalizeDouble(newTP, _Digits);
         
         // Update if different from current values
         if(MathAbs(newSL - activePositions[i].currentSL) > _Point || 
            MathAbs(newTP - activePositions[i].currentTP) > _Point)
         {
            if(trade.PositionModify(activePositions[i].ticket, newSL, newTP))
            {
               activePositions[i].currentSL = newSL;
               activePositions[i].currentTP = newTP;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Equity protection check                                         |
//+------------------------------------------------------------------+
bool CheckEquityProtection()
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(currentEquity < InpMinimumEquity)
   {
      // Close all EA positions
      CloseAllEAPositions();
      Print("Equity protection triggered. Current equity: ", currentEquity, " Minimum: ", InpMinimumEquity);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Position closing functions                                      |
//+------------------------------------------------------------------+
void CloseAllEAPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0)
      {
         if(PositionGetString(POSITION_COMMENT) == eaMagicComment || 
            PositionGetInteger(POSITION_MAGIC) == eaMagicNumber)
         {
            trade.PositionClose(PositionGetTicket(i));
         }
      }
   }
   
   // Clear tracking arrays
   positionCount = 0;
   ArrayResize(activePositions, 0);
   
   Print("All EA positions closed");
}

void ClosePositionsByType(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0)
      {
         if((PositionGetString(POSITION_COMMENT) == eaMagicComment || 
             PositionGetInteger(POSITION_MAGIC) == eaMagicNumber) &&
            PositionGetInteger(POSITION_TYPE) == posType)
         {
            trade.PositionClose(PositionGetTicket(i));
            
            // Remove from tracking
            ulong ticket = PositionGetTicket(i);
            RemovePositionFromTracking(ticket);
         }
      }
   }
   
   string typeStr = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   Print("All EA ", typeStr, " positions closed");
}

//+------------------------------------------------------------------+
//| Chart object functions                                          |
//+------------------------------------------------------------------+
void CreateChartObjects()
{
   // Create info label
   if(ObjectCreate(0, infoLabelName, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, infoLabelName, OBJPROP_XDISTANCE, InpInfoXPos);
      ObjectSetInteger(0, infoLabelName, OBJPROP_YDISTANCE, InpInfoYPos);
      ObjectSetInteger(0, infoLabelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, infoLabelName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, infoLabelName, OBJPROP_FONT, "Arial");
   }
   
   // Create Kill All button
   if(ObjectCreate(0, btnKillAllName, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, btnKillAllName, OBJPROP_XDISTANCE, InpInfoXPos);
      ObjectSetInteger(0, btnKillAllName, OBJPROP_YDISTANCE, InpInfoYPos + 150);
      ObjectSetInteger(0, btnKillAllName, OBJPROP_XSIZE, 100);
      ObjectSetInteger(0, btnKillAllName, OBJPROP_YSIZE, 30);
      ObjectSetString(0, btnKillAllName, OBJPROP_TEXT, "Kill All");
      ObjectSetInteger(0, btnKillAllName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btnKillAllName, OBJPROP_BGCOLOR, clrRed);
   }
   
   // Create Kill Buys button
   if(ObjectCreate(0, btnKillBuysName, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, btnKillBuysName, OBJPROP_XDISTANCE, InpInfoXPos + 110);
      ObjectSetInteger(0, btnKillBuysName, OBJPROP_YDISTANCE, InpInfoYPos + 150);
      ObjectSetInteger(0, btnKillBuysName, OBJPROP_XSIZE, 100);
      ObjectSetInteger(0, btnKillBuysName, OBJPROP_YSIZE, 30);
      ObjectSetString(0, btnKillBuysName, OBJPROP_TEXT, "Kill Buys");
      ObjectSetInteger(0, btnKillBuysName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btnKillBuysName, OBJPROP_BGCOLOR, clrOrange);
   }
   
   // Create Kill Sells button
   if(ObjectCreate(0, btnKillSellsName, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, btnKillSellsName, OBJPROP_XDISTANCE, InpInfoXPos + 220);
      ObjectSetInteger(0, btnKillSellsName, OBJPROP_YDISTANCE, InpInfoYPos + 150);
      ObjectSetInteger(0, btnKillSellsName, OBJPROP_XSIZE, 100);
      ObjectSetInteger(0, btnKillSellsName, OBJPROP_YSIZE, 30);
      ObjectSetString(0, btnKillSellsName, OBJPROP_TEXT, "Kill Sells");
      ObjectSetInteger(0, btnKillSellsName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btnKillSellsName, OBJPROP_BGCOLOR, clrBlue);
   }
}

void DeleteChartObjects()
{
   ObjectDelete(0, infoLabelName);
   ObjectDelete(0, btnKillAllName);
   ObjectDelete(0, btnKillBuysName);
   ObjectDelete(0, btnKillSellsName);
}

void UpdateChartInfo()
{
   string info = "RAZOR EA Status\n";
   info += "Timeframe: " + EnumToString(InpTimeframe) + "\n";
   info += "Trigger Distance: " + DoubleToString(InpTriggerDistance, 5) + "\n";
   info += "Trading Mode: " + (InpTradingMode == MODE_COUNTER_TREND ? "Counter-Trend" : "Trend-Following") + "\n";
   info += "SL Type: " + (InpStopLossType == SL_FIXED ? "Fixed" : "Trailing") + "\n";
   info += "Active Positions: " + IntegerToString(positionCount) + "\n";
   info += "Current Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
   
   ObjectSetString(0, infoLabelName, OBJPROP_TEXT, info);
}

//+------------------------------------------------------------------+
//| Chart event handler                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == btnKillAllName)
      {
         CloseAllEAPositions();
         ObjectSetInteger(0, btnKillAllName, OBJPROP_STATE, false);
      }
      else if(sparam == btnKillBuysName)
      {
         ClosePositionsByType(POSITION_TYPE_BUY);
         ObjectSetInteger(0, btnKillBuysName, OBJPROP_STATE, false);
      }
      else if(sparam == btnKillSellsName)
      {
         ClosePositionsByType(POSITION_TYPE_SELL);
         ObjectSetInteger(0, btnKillSellsName, OBJPROP_STATE, false);
      }
   }
}

//+------------------------------------------------------------------+
//| Utility functions                                               |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
   return NormalizeDouble(price, _Digits);
}

double GetCurrentSpread()
{
   return (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID));
}

bool IsNewBar(ENUM_TIMEFRAMES timeframe)
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, timeframe, 0);
   
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Handle trailing stops                                           |
//+------------------------------------------------------------------+
void HandleTrailingStops()
{
   for(int i = 0; i < positionCount; i++)
   {
      if(PositionSelectByTicket(activePositions[i].ticket))
      {
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double currentSL = PositionGetDouble(POSITION_SL);
         double openPrice = activePositions[i].openPrice;
         
         double newSL = currentSL;
         bool shouldUpdate = false;
         
         if(activePositions[i].type == POSITION_TYPE_BUY)
         {
            // For BUY positions, trail SL upward
            double trailSL = currentPrice - InpTrailingDistance;
            if(trailSL > currentSL)
            {
               newSL = trailSL;
               shouldUpdate = true;
            }
         }
         else
         {
            // For SELL positions, trail SL downward
            double trailSL = currentPrice + InpTrailingDistance;
            if(trailSL < currentSL)
            {
               newSL = trailSL;
               shouldUpdate = true;
            }
         }
         
         if(shouldUpdate)
         {
            newSL = NormalizeDouble(newSL, _Digits);
            if(trade.PositionModify(activePositions[i].ticket, newSL, activePositions[i].currentTP))
            {
               activePositions[i].currentSL = newSL;
            }
         }
      }
   }
}