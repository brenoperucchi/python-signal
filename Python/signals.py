import os
import argparse
import pdb
import sched, time, datetime
import json

from telegram.client import Telegram
from signals_telegram import SignalTelegram
from signals_order import SignalOrder
from signals_meta import SignalsMeta

ap = argparse.ArgumentParser()
ap.add_argument("-e", "--environment", type=str, required=True, help="Environment: development / production / local", action="store")
ap.add_argument("-o", "--option", type=str, required=True, help="Option: order / telegram_api",  action="store")
arguments = vars(ap.parse_args())
dir_path = os.path.dirname(os.path.realpath(__file__))

environment = arguments['environment'].lower()
host_defaults = {
	'local': 'localhost:3000',
	'development': 'localhost:3000',
	'production': 'localhost:3000'
}
library_defaults = {
	'local': F'{dir_path}/dwx/tdlib/libtdjson.dylib',
	'development': F'{dir_path}/dwx/tdlib/libtdjson_64.so',
	'production': F'{dir_path}/dwx/tdlib/libtdjson_64.so'
}

if environment not in host_defaults:
	raise ValueError('Environment must be one of: local, development, production')

config = {
	'HOSTNAME': os.environ.get('SIGNAL_API_HOST', host_defaults[environment]),
	'ENVIRONMENT': environment,
	'API_ID': os.environ.get('TELEGRAM_API_ID'),
	'API_HASH': os.environ.get('TELEGRAM_API_HASH'),
	'PHONE_NUMBER': os.environ.get('TELEGRAM_PHONE_NUMBER'),
	'DATABASE_ENCRYPT': os.environ.get('TELEGRAM_DATABASE_ENCRYPTION_KEY', 'change-me'),
	'LIBRARY_PATH': os.environ.get('TDLIB_LIBRARY_PATH', library_defaults[environment]),
	'DATABASE_PATH': os.environ.get('TELEGRAM_DATABASE_PATH', F'{dir_path}/database.json')
}


telegram_client = None

def get_telegram_client():
	global telegram_client
	if telegram_client is None:
		missing = [key for key in ['API_ID', 'API_HASH', 'PHONE_NUMBER'] if not config.get(key)]
		if missing:
			raise RuntimeError(f"Missing Telegram configuration: {', '.join(missing)}")
		telegram_client = Telegram(api_id=config['API_ID'], api_hash=config['API_HASH'], phone=config['PHONE_NUMBER'], database_encryption_key=config['DATABASE_ENCRYPT'], library_path=config['LIBRARY_PATH'])
	return telegram_client

def telegram_api(sc):
	tg = get_telegram_client()
	tg.login()
	SignalTelegram(sc, tg, config).prepare()
	s.enter(2, 1, telegram_api, (sc,))
def order(sc):
	SignalOrder(sc, config).prepare()
	s.enter(2, 1, order, (sc,))

s = sched.scheduler(time.time, time.sleep)
option = locals()[arguments['option'].lower()]
s.enter(2, 1, option, (s,))
s.run()	
