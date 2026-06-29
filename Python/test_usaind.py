import requests
import pdb
import numpy as np
import pandas as pd
import configparser
import pytz

from datetime import datetime, timedelta 
from pytrader_api.Pytrader_API_V1_04 import Pytrader_API
from signals_api import SignalApi


MT = Pytrader_API()
brokerInstrumentsLookup = {
	'EURUSD': 'EURUSD',
	'GBPNZD': 'GBPNZD',
	'GOLD': 'XAUUSD',
	'DAX': 'GER30',
	'EURAUD': 'EURAUD',
	'US30': 'US30'}
Connected = MT.Connect(
	server='192.168.1.245',
	port=1125,
	instrument_lookup=brokerInstrumentsLookup)
MT.debug = True

IsAlive = MT.connected
# print(IsAlive)

CheckAlive = MT.Check_connection()

MT.Set_timeout(timeout_in_seconds=120)

ServerTime = MT.Get_broker_server_time()

NewOrder = MT.Open_order(
						instrument='US30',
						ordertype='sell',
						volume=1.0,
						openprice=0.0,
						slippage=10,
						magicnumber=2000,
						stoploss=33000.0,
						takeprofit=30010.0,
						comment='test')
if(NewOrder == -1):
	print(MT.order_error)
	print(MT.order_return_message)
else:
	print(NewOrder)