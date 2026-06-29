# Python Signal

Python Signal contains the Python utilities and MQL4/MQL5 Expert Advisor source used by the MT5 Web Replicator stack. It is the terminal/client-side companion to the Rails backend in [`mt5-web-replicator`](https://github.com/brenoperucchi/mt5-web-replicator).

The codebase includes:

- MQL4/MQL5 copy and slave Expert Advisors.
- Shared MQL include files used by the MT5 integrations.
- Python scripts for polling Telegram, sending signal/order data to the web API, and communicating with MetaTrader through ZeroMQ/PyTrader experiments.
- Legacy experiments and reference code under `MQL/Imentore/Old` and `Python/DwX-Others`.

## Related Repository

- Backend and web dashboard: [`brenoperucchi/mt5-web-replicator`](https://github.com/brenoperucchi/mt5-web-replicator)

Use both repositories together when running the full stack:

1. `python-signal` runs close to MetaTrader and external signal sources.
2. `mt5-web-replicator` receives, stores, validates, and manages the replicated order/account data.

## Repository Layout

```text
MQL/
  Ema/                         MQL strategy experiments
  Imentore/MT4/                MT4 include/expert code
  Imentore/MT5/                Current MT5 copy/slave experts and libraries
  Imentore/Old/                Historical experiments and legacy versions

Python/
  signals.py                   Scheduler entrypoint
  signals_api.py               HTTP client for the Rails API
  signals_telegram.py          Telegram polling workflow
  signals_order.py             Order processing workflow
  signals_meta.py              MetaTrader bridge helper
  PyTraderApi/                 PyTrader API experiments and compiled EAs
  DwX-Others/                  ZeroMQ/OCR experiments and helper code
```

## Requirements

- Python 3.x
- MetaTrader 4 or MetaTrader 5, depending on the Expert Advisor used
- TDLib when using Telegram polling through `python-telegram`
- A running MT5 Web Replicator backend

Install Python dependencies:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Configuration

Runtime configuration is provided through environment variables.

```bash
export SIGNAL_API_HOST="localhost:3000"
export TELEGRAM_API_ID=""
export TELEGRAM_API_HASH=""
export TELEGRAM_PHONE_NUMBER=""
export TELEGRAM_DATABASE_ENCRYPTION_KEY="change-me"
export TDLIB_LIBRARY_PATH="/path/to/libtdjson.so"
```

`SIGNAL_API_HOST` should point to the Rails backend host, without protocol. For example:

```bash
export SIGNAL_API_HOST="localhost:3000"
```

The MQL Expert Advisors also contain server defaults. For public use, those defaults are placeholders such as `mt5-web-replicator.example.com` or local development hosts. Update the EA input/configuration to point to the running web backend before attaching it to a MetaTrader terminal.

## Running

Run the order polling workflow:

```bash
python Python/signals.py --environment local --option order
```

Run the Telegram polling workflow:

```bash
python Python/signals.py --environment local --option telegram_api
```

The `--environment` option accepts `local`, `development`, or `production`. Environment variables override host, Telegram, TDLib, and local database settings.

## Public Release Notes

This repository was prepared as the public client/MQL side of MT5 Web Replicator. Local runtime files, editor workspaces, Telegram database files, and hardcoded credentials are intentionally excluded.
