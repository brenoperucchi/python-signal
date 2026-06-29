from lib.mq import DwxZmqConnector
from typing import Callable
import datetime as dt
import time


class DwxZmqClient:
    def __init__(self, _zmq: DwxZmqConnector = None):
        if _zmq is None:
            _zmq = DwxZmqConnector(_verbose=False)
        self._zmq = _zmq

    def _reset_response(self):
        self._zmq._set_response_(None)

    def _wait_response(self, delay: float = 0.05, timeout: float = 2.5) -> dict:
        a = time.perf_counter()

        # While data not received, sleep until timeout
        while self._zmq._valid_response_("zmq") is False:
            time.sleep(delay)

            b = time.perf_counter()
            if (b - a) > timeout:
                raise Exception("Server Timeout.")

        return self._zmq._get_response_()

    def get_candle_history(
        self,
        symbol: str,
        timeframe: int,
        start: str = "2020.01.01",
        end: str = dt.datetime.now().strftime("%Y.%m.%d %H:%M:00"),
    ) -> dict:
        """ Retrieves MqlRates in TOHLCV form from MT4Server. """
        self._reset_response()

        self._zmq._DWX_MTX_SEND_MARKETDATA_REQUEST_(symbol, timeframe, start, end)
        response = self._wait_response()

        if "_data" in response.keys():
            return response
        else:
            _response = response["_response"]
            raise Exception(f"Mkt Data Error: {_response}")

    def get_open_trades(self):
        """ Retrieves all open trades from mt4 """
        self._reset_response()
        self._zmq._DWX_MTX_GET_ALL_OPEN_TRADES_()
        return self._wait_response()

    def new_trade(
        self,
        symbol: str,
        order_type: int = 0,
        price: float = 0.0,
        sl_pts: int = 500,
        tp_pts: int = 500,
        comment: str = None,
        size: float = 0.01,
        magic: int = 123456,
    ) -> dict:
        """ Places new trade order based on given arguments. """

        self._reset_response()

        if comment is None:
            comment = self._zmq._ClientID

        order = self._zmq._generate_default_order_dict()
        order["_symbol"] = symbol
        order["_type"] = order_type
        order["_price"] = price
        order["_SL"] = sl_pts
        order["_TP"] = tp_pts
        order["_comment"] = comment
        order["_lots"] = size
        order["_magic"] = magic

        self._zmq._DWX_MTX_NEW_TRADE_(_order=order)

        response = self._wait_response()
        if "_response" not in response.keys():
            return response
        else:
            _response = response["_response"]
            _response_value = response.get("_response_value")
            raise Exception(f"Order Error: {_response};{_response_value}")

    def close_trade_by_ticket(self, ticket: int) -> dict:
        """ Closes the trade with the matching ticket number. """

        self._reset_response()
        self._zmq._DWX_MTX_CLOSE_TRADE_BY_TICKET_(_ticket=ticket)

        response = self._wait_response()
        if "_response_value" in response.keys():
            return response
        else:
            raise Exception(f"Order Error: No Trade with ticket#{ticket} was found.")

    def close_trades_by_magic(self, magic: int) -> dict:
        """ Closes all trades with the matching magic number. """

        self._reset_response()
        self._zmq._DWX_MTX_CLOSE_TRADES_BY_MAGIC_(_magic=magic)

        response = self._wait_response()
        if "_response_value" in response.keys():
            return response
        else:
            raise Exception(f"Order Error: No Trades with magic#{magic} was found.")

    def subscribe_to_ticks(self, symbol: str, tick_handler: Callable = None):
        """ Sets tick handler and subscribes to ticks. """

        if tick_handler is not None:
            self._zmq._tick_handler = tick_handler

        self._zmq._DWX_MTX_SUBSCRIBE_MARKETDATA_(symbol)

    def unsubscribe_to_ticks(self, symbol: str):
        """ Removes ticks subscription from the matching symbol. """

        self._zmq._DWX_MTX_UNSUBSCRIBE_MARKETDATA_(symbol)

    def unsubscribe_all_ticks(self):
        """ Removes all ticks subscription and tick handler. """

        self._zmq._tick_handler = None
        self._zmq._DWX_MTX_UNSUBSCRIBE_ALL_MARKETDATA_REQUESTS_()
