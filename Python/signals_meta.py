import requests
import pdb
import numpy as np
import pandas as pd
import configparser
import pytz

from datetime import datetime, timedelta 
from pytrader_api.Pytrader_API_V1_04 import Pytrader_API
from signals_api import SignalApi

class SignalsMeta():
	def __init__(self, meta_host, meta_port):
		self.meta_host = meta_host
		self.meta_port = int(meta_port)
		self.meta = self.connect()

	def config_instruments(self, config, section):
	    dict1 = {}
	    options = config.options(section)
	    for option in options:
	        try:
	            option = option.upper()
	            dict1[option] = config.get(section, option)
	            if dict1[option] == -1:
	                print("skip: %s" % option)
	        except BaseException:
	            print("exception on %s!" % option)
	            dict1[option] = None
	    return dict1

	def connect(self):
		meta = Pytrader_API()
		# Read in config
		CONFIG_FILE = "pytrader_api/Instrument.conf"
		config = configparser.ConfigParser()
		config.read(CONFIG_FILE)

		brokerInstrumentsLookup = self.config_instruments(config, "ICMarkets")

		Connected = meta.Connect(
			server=self.meta_host,
			port=self.meta_port,
			instrument_lookup=brokerInstrumentsLookup)
		meta.debug = False

		IsAlive = meta.connected
		# print(IsAlive)

		CheckAlive = meta.Check_connection()

		meta.Set_timeout(timeout_in_seconds=120)

		ServerTime = meta.Get_broker_server_time()

		return meta

	def order_send(self, _my_trade):
		print('MY_Trade: ', _my_trade)
		
		MT = self.meta
		ticket = self.meta.Open_order(**_my_trade)

		if(ticket == -1):
			print(MT.order_error)
			print(MT.order_return_message)
		else:
			print(ticket)	

		trades = self.meta.Get_all_open_positions()
		_my_trade['response_value'] = self.meta.order_error
		_my_trade['response']	    = self.meta.order_return_message
		if (ticket == -1):  # opening order failed
			_my_trade['open_price'] = None
			_my_trade['open_time'] = None
			_my_trade['ticket'] = None
			_my_trade['account_login'] = None
		else:
			_my_trade['ticket'] = ticket
			for num in trades.index:
				if trades['ticket'][num] == ticket:
					_my_trade['open_price'] = trades['open_price'][num]
					_my_trade['open_time'] = datetime.fromtimestamp(trades['open_time'][num]).strftime('%Y-%m-%d %H:%M:%S')
		return _my_trade

	def order_closed(self):
		orders = SignalApi().transaction_execute().json()
		timezone = pytz.timezone("Etc/UTC")
		account_login = self.meta.Get_static_account_info()['login']
		trades = self.meta.Get_all_closed_positions(date_from=datetime(2021, 1, 1, tzinfo=timezone), date_to=datetime.now() + timedelta(hours=5))		
		if orders:
			for order in orders:
				ticket = order['ticket']
				for num in trades.index:
					if trades['position_ticket'][num] == int(ticket):
						message = f"{account_login}|CLOSED|{trades['instrument'][num]}|{trades['position_ticket'][num]}|{trades['position_type'][num]}|{trades['open_price'][num]}|{trades['close_price'][num]}|{trades['volume'][num]}|{trades['profit'][num]}"
						pload = {'message':message}
						r = requests.post('http://192.168.1.240/api/v1/traces/master', data = pload)

