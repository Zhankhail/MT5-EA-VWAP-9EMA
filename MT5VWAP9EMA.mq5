#property strict

#include <Trade/Trade.mqh>

input ulong MagicNumber = 42069;
input double Lots = 0.10;
input int Slippage = 30;
input int StopLossPoints = 120;
input int TakeProfitPoints = 240;
input bool UseTrailingStop = true;
input int TrailingStopPoints = 80;
input int MaxSpreadPoints = 40;
input int MaxOpenTrades = 1;
input int EMAPeriod = 9;
input int VWAPPeriod = 200;
input bool UseVWAPFilter = true;
input bool EnableLongTrades = true;
input bool EnableShortTrades = true;
input string TradeComment = "VWAP9EMA";

CTrade trade;

int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   // Nothing special to do on exit.
}

void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, _Period, 0);

   if(currentBarTime == lastBarTime)
      return;

   lastBarTime = currentBarTime;

   if(UseTrailingStop)
      ManageTrailingStop();

   CheckAndOpenTrades();
}

void CheckAndOpenTrades()
{
   if(GetOpenTradesCount() >= MaxOpenTrades)
      return;

   if(!IsMarketOpenForTrading())
      return;

   if(IsSpreadTooWide())
      return;

   double currentVWAP = 0.0;
   if(UseVWAPFilter)
      currentVWAP = CalculateVWAP(VWAPPeriod);

   double emaCurrent = iMA(_Symbol, _Period, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaPrevious = iMA(_Symbol, _Period, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);

   double closePrice = iClose(_Symbol, _Period, 0);
   double openPrice = iOpen(_Symbol, _Period, 0);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool bullishSetup = false;
   bool bearishSetup = false;

   if(UseVWAPFilter)
   {
      bullishSetup = (closePrice > currentVWAP) && (emaCurrent > emaPrevious) && (closePrice > emaCurrent) && (closePrice > openPrice);
      bearishSetup = (closePrice < currentVWAP) && (emaCurrent < emaPrevious) && (closePrice < emaCurrent) && (closePrice < openPrice);
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

      if(StopLossPoints > 0 && stopLoss <= 0)
         stopLoss = 0.0;
      if(TakeProfitPoints > 0 && takeProfit <= 0)
         takeProfit = 0.0;

      trade.Buy(Lots, _Symbol, ask, stopLoss, takeProfit, TradeComment);
   }
   else if(EnableShortTrades && bearishSetup)
   {
      double stopLoss = NormalizeDouble(bid + StopLossPoints * _Point, _Digits);
      double takeProfit = NormalizeDouble(bid - TakeProfitPoints * _Point, _Digits);

      if(StopLossPoints > 0 && stopLoss <= 0)
         stopLoss = 0.0;
      if(TakeProfitPoints > 0 && takeProfit <= 0)
         takeProfit = 0.0;

      trade.Sell(Lots, _Symbol, bid, stopLoss, takeProfit, TradeComment);
   }
}

double CalculateVWAP(int barsBack)
{
   double totalPriceVolume = 0.0;
   double totalVolume = 0.0;

   int lookback = MathMin(barsBack, Bars(_Symbol, _Period));
   if(lookback <= 0)
      return 0.0;

   for(int i = 0; i < lookback; i++)
   {
      double high = iHigh(_Symbol, _Period, i);
      double low = iLow(_Symbol, _Period, i);
      double close = iClose(_Symbol, _Period, i);
      double volume = (double)iVolume(_Symbol, _Period, i);

      double typicalPrice = (high + low + close) / 3.0;
      double priceVolume = typicalPrice * volume;

      totalPriceVolume += priceVolume;
      totalVolume += volume;
   }

   if(totalVolume <= 0.0)
      return 0.0;

   return totalPriceVolume / totalVolume;
}

bool IsMarketOpenForTrading()
{
   return true;
}

bool IsSpreadTooWide()
{
   long spread = (long)MarketInfo(_Symbol, MODE_SPREAD);
   if(spread > MaxSpreadPoints)
      return true;
   return false;
}

int GetOpenTradesCount()
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

   return count;
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
         if(newStop > OrderStopLoss() + _Point)
         {
            trade.ModifyOrder(OrderTicket(), newStop, OrderTakeProfit(), 0, 0, clrNONE);
         }
      }
      else if(OrderType() == OP_SELL)
      {
         double newStop = NormalizeDouble(Ask + TrailingStopPoints * _Point, _Digits);
         if(newStop < OrderStopLoss() - _Point)
         {
            trade.ModifyOrder(OrderTicket(), newStop, OrderTakeProfit(), 0, 0, clrNONE);
         }
      }
   }
}

