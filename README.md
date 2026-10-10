# MT5-EA-VWAP-9EMA

Expert Advisor for MetaTrader 5 using a VWAP + 9 EMA trend-following strategy.

## Strategy idea

This EA combines:
- VWAP (Volume Weighted Average Price) as the intraday trend anchor
- 9-period EMA as the short-term momentum filter

Core idea:
- Long only when price is above VWAP and the 9 EMA is rising
- Short only when price is below VWAP and the 9 EMA is falling
- Use fixed stop loss and take profit levels
- Optional trailing stop to lock in profits

## Included in the initial version

- VWAP calculation over a configurable lookback
- 9 EMA trend confirmation
- Long/short entry logic
- Stop loss / take profit
- Trailing stop
- Spread filter
- Trade comment and magic number
- Basic risk controls

## Files

- `MT5VWAP9EMA.mq5` — the main Expert Advisor source code

## How to use in MetaEditor

1. Copy `MT5VWAP9EMA.mq5` into your MetaEditor `MQL5/Experts` folder.
2. Compile the EA.
3. Attach it to a chart in MetaTrader 5.
4. Choose a liquid instrument such as EURUSD, GBPUSD, XAUUSD, or major FX pairs.
5. Adjust the inputs for your broker and style.

## Recommended defaults

- `EMAPeriod` = 9
- `VWAPPeriod` = 200
- `Lots` = 0.10
- `StopLossPoints` = 120
- `TakeProfitPoints` = 240
- `MaxSpreadPoints` = 40

## Important notes

- This is a starting EA for learning and strategy testing.
- Always backtest and forward test before using on a live account.
- Trading costs and spread conditions can materially affect results.
- This EA is not financial advice.

## Planned upgrades

- Session filters
- Partial exits
- Multi-timeframe confirmation
- News filter
- Smart lot sizing / risk percentage
- Better trade management rules
