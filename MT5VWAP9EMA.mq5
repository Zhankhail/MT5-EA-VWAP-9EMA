#property strict

#include <Trade/Trade.mqh>

input ulong MagicNumber = 42069;
input double Lots = 0.10;
input int Slippage = 20;
input int EMAPeriod = 9;
input int VWAPPeriod = 200;
input int StopLossPoints = 120;
input int TakeProfitPoints = 240;
input int TrailingStopPoints = 80;
input int MaxSpreadPoints = 60;
input int MaxOpenTrades = 1;
input bool UseTrailingStop = true;
input bool UseVWAPFilter = true;
input bool EnableLongTrades = true;
input bool EnableShortTrades = true;
input string TradeComment = "VWAP9EMA";

CTrade trade;

int OnInit()
{
   if(!IsAllowedSymbol())
   {
      Print("This EA is configured for XAUUSD, NAS100, and DJ30 only.");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   // No extra cleanup required.
}

void OnTick()
{
   if(!IsAllowedSymbol())
      return;

   if(!IsMarketOpenForTrading())
      return;

   if(IsSpreadTooWide())
      return;

   if(UseTrailingStop)
      ManageTrailingStop();

   if(!CanOpenNewTrade())
      return;

   double emaCurrent = iMA(_Symbol, _Period, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaPrevious = iMA(_Symbol, _Period, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double closePrice = iClose(_Symbol, _Period, 0);
   double openPrice = iOpen(_Symbol, _Period, 0);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double vwap = 0.0;
   if(UseVWAPFilter)
      vwap = CalculateVWAP(_Symbol, _Period, VWAPPeriod);

   bool bullishSetup = false;
   bool bearishSetup = false;

   if(UseVWAPFilter)
   {
      bullishSetup = (closePrice > vwap) && (emaCurrent > emaPrevious) && (closePrice > emaCurrent) && (closePrice > openPrice);
      bearishSetup = (closePrice < vwap) && (emaCurrent < emaPrevious) && (closePrice < emaCurrent) && (closePrice < openPrice);
   }
   else
   {
      bullishSetup = (emaCurrent > emaPrevious) && (closePrice > emaCurrent) && (closePrice > openPrice);
      bearishSetup = (emaCurrent < emaPrevious) && (closePrice < emaCurrent) && (closePrice < openPrice);
   }

   if(EnableLongTrades && bullishSetup)
   {
      double stopLoss = NormalizeDouble(ask - StopLossPoints * _Point, _Digits);
      double takeProfit = NormalizeDouble(ask + TakeProfitPoints * _Point, _Digits);

      if(StopLossPoints <= 0)
         stopLoss = 0.0;
      if(TakeProfitPoints <= 0)
         takeProfit = 0.0;

      trade.Buy(Lots, _Symbol, ask, stopLoss, takeProfit, TradeComment);
      return;
   }

   if(EnableShortTrades && bearishSetup)
   {
      double stopLoss = NormalizeDouble(bid + StopLossPoints * _Point, _Digits);
      double takeProfit = NormalizeDouble(bid - TakeProfitPoints * _Point, _Digits);

      if(StopLossPoints <= 0)
         stopLoss = 0.0;
      if(TakeProfitPoints <= 0)
         takeProfit = 0.0;

      trade.Sell(Lots, _Symbol, bid, stopLoss, takeProfit, TradeComment);
   }
}

double CalculateVWAP(string symbol, ENUM_TIMEFRAMES timeframe, int barsBack)
{
   double totalPriceVolume = 0.0;
   double totalVolume = 0.0;

   int barsCount = MathMin(barsBack, iBars(symbol, timeframe));
   if(barsCount <= 0)
      return 0.0;

   for(int i = 0; i < barsCount; i++)
   {
      double high = iHigh(symbol, timeframe, i);
      double low = iLow(symbol, timeframe, i);
      double close = iClose(symbol, timeframe, i);
      double volume = (double)iVolume(symbol, timeframe, i);

      double typicalPrice = (high + low + close) / 3.0;
      double priceVolume = typicalPrice * volume;

      totalPriceVolume += priceVolume;
      totalVolume += volume;
   }

   if(totalVolume <= 0.0)
      return 0.0;

   return (totalPriceVolume / totalVolume);
}

bool IsAllowedSymbol()
{
   return (_Symbol == "XAUUSD" || _Symbol == "NAS100" || _Symbol == "DJ30");
}

bool IsMarketOpenForTrading()
{
   return true;
}

bool IsSpreadTooWide()
{
   long spread = (long)MarketInfo(_Symbol, MODE_SPREAD);
   return (spread > MaxSpreadPoints);
}

bool CanOpenNewTrade()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == _Symbol && OrderMagicNumber() == MagicNumber)
            count++;
      }
   }

   return (count < MaxOpenTrades);
}

void ManageTrailingStop()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != _Symbol)
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY)
      {
         double newStop = NormalizeDouble(Bid - TrailingStopPoints * _Point, _Digits);
         if(OrderStopLoss() == 0.0 || newStop > OrderStopLoss() + _Point)
         {
            trade.ModifyOrder(OrderTicket(), newStop, OrderTakeProfit(), 0, 0, clrNONE);
         }
      }
      else if(OrderType() == OP_SELL)
      {
         double newStop = NormalizeDouble(Ask + TrailingStopPoints * _Point, _Digits);
         if(OrderStopLoss() == 0.0 || newStop < OrderStopLoss() - _Point)
         {
            trade.ModifyOrder(OrderTicket(), newStop, OrderTakeProfit(), 0, 0, clrNONE);
         }
      }
   }
}
