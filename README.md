# Python Signal

[![CI](https://github.com/brenoperucchi/python-signal/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/brenoperucchi/python-signal/actions/workflows/ci.yml)
[![Python](https://img.shields.io/badge/python-3.10%20%7C%203.11%20%7C%203.12%20%7C%203.13-3776AB?logo=python&logoColor=white)](.github/workflows/ci.yml)
[![MQL5](https://img.shields.io/badge/MetaTrader-MQL4%20%7C%20MQL5-4A76A8)](MQL)
[![License: PolyForm Noncommercial](https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-blue)](LICENSE.md)

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

## License

This project is **source-available** under the [PolyForm Noncommercial License 1.0.0](LICENSE.md), the same terms as [MT5 Web Replicator](https://github.com/brenoperucchi/mt5-web-replicator).

- **Free for noncommercial use.** You can read, run, test, modify and share it for personal use, study, research, evaluation, or at a nonprofit, school or public institution.
- **Commercial use needs a separate license.** This includes running the EAs or client for a business, offering copy trading as a service, or managing paying customers' accounts. Contact bperucchi@gmail.com to discuss terms.

## Contributing

Pull requests are welcome, including improvements to the EAs (order handling, symbol mapping, lot scaling, reconnect logic) and the Python client. Before your first pull request can be merged, you will be asked to sign the [Contributor License Agreement](CLA.md) by leaving a comment on the pull request. It keeps the project able to offer commercial licenses while your contribution stays credited to you.

## Partnership

Interested in collaborating on this project or building something on top of it commercially? Get in touch at bperucchi@gmail.com.
