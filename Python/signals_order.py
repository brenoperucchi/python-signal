import pdb
import json
import requests
import re
import sys
import regex
import time, datetime
import numpy as np
import pandas as pd
import configparser
import pytz

from datetime import datetime
from signals_meta import SignalsMeta
from decimal import *
# from lib.ocr_google import detect_text_google
# from lib.ocr_local import detect_text_local
from signals_api import SignalApi

class SignalOrder():
	def __init__(self, sc, config={}):
		self._sc = sc
		self._hostname = config['HOSTNAME']
		self._environment = config['ENVIRONMENT']
	def prepare(self):		
		signal_list = SignalApi.query_collection(hostname=self._hostname).json()
		if signal_list:
			for trace in signal_list['traces']:
				for message in trace['orders']:
					print("STARTED TIME: ", datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
					print("Chat ID: ", trace['id'],"Message ID: ", message['message_id'])

					self._chat_id = trace['id']
					self._signal_name = trace['name']
					self._message_id = message['message_id']

					self._symbol = message['symbol']
					self._type = message['type']
					self._price_request = message['price_request']
					self._SL = message['SL']
					self._TP = message['TP']
					self._volumes = trace['volumes']
					self._meta_host = trace['meta_host']
					self._meta_port = trace['meta_port']

					# SignalsMeta(self._meta_host, self._meta_port).order_closed()
					self._prepare_order_for_metatrader()		

	def meta_order_send(self, _my_trade, chat_id):
		signal_meta = SignalsMeta(self._meta_host, self._meta_port)
		meta = signal_meta.meta
		_my_trade = signal_meta.order_send(_my_trade)		
		self._save_response(_my_trade, self._chat_id, self._signal_name)
		signal_meta.meta.Disconnect()
		
	def _save_response(self, _my_trade, chat_id, telegram_username):
		params = {
			'chat_id': chat_id,
			'message_id': self._message_id,
			'provider': chat_id,
			'provider_name': telegram_username,
			'symbol':_my_trade['instrument'],
			'kind': _my_trade['ordertype'],
			'price_request': _my_trade['openprice'],
			'stop_loss': _my_trade.get('stoploss'),
			'take_profit': _my_trade.get('takeprofit'),
			'lot': _my_trade['volume'],
			'comment': _my_trade['comment'],
			'magic': _my_trade['magicnumber'],
			'ticket':_my_trade['ticket'],
			'price_open': _my_trade['open_price'],
			'response': _my_trade['response'],
			'response_value':_my_trade['response_value'],
			'open_at':_my_trade['open_time'],
			'meta_order_generate': "".join(f" {key}:{value}" for key, value in _my_trade.items())
		 }
		response = SignalApi.save_message(self._hostname , params = params)

	def _prepare_order_for_metatrader(self):
		for i in range(len(self._volumes)):
			lots = self._volumes
			_my_trade = {'instrument':None, 'ordertype':None, 'volume':None, 'openprice':None, 'slippage':10, 'magicnumber':2000, 'stoploss':None, 'takeprofit':None, 'comment': 'Pytrader'}
			_my_trade['ordertype'] = self._type.lower()
			_my_trade['instrument'] = self._symbol
			_my_trade['openprice'] = self._price_request
			_my_trade['stoploss'] = self._SL
			_my_trade['comment'] = (f'{self._signal_name} #{i}')
			_my_trade['takeprofit'] = self._TP[i]
			_my_trade['volume'] = float(lots[i])
			print(f"STOP LOSS: {_my_trade['stoploss']} TAKE PROFIT: {_my_trade['takeprofit']}")
			self.meta_order_send(_my_trade, self._chat_id)

	def _deEmojify(self, message):
		regrex_pattern = re.compile(pattern = "["
			u"\U0001F600-\U0001F64F"  # emoticons
			u"\U0001F300-\U0001F5FF"  # symbols & pictographs
			u"\U0001F680-\U0001F6FF"  # transport & map symbols
			u"\U0001F1E0-\U0001F1FF"  # flags (iOS)
							   "]+", flags = re.UNICODE)
		return regrex_pattern.sub(r'',message)