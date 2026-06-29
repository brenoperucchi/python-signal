import pdb
import json
import requests
import re
import sys
import regex
import time, datetime
import inspect

class SignalApi():
		def __init__(self, hostname="localhost:80"):
			self.hostname = hostname

		def transaction_execute(self, params={}):
			# print("SignalTelegram Api / save_data / STARTED TIME: ", datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
			# print(f"SignalTelegram Api / save_data / POST / http://{hostname}/api/v1/orders params:", params)
			request = requests.get(f'http://{self.hostname}/api/v1/transactions')
			return request

		def save_data(hostname, params={}):
			# print("SignalTelegram Api / save_data / STARTED TIME: ", datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
			# print(f"SignalTelegram Api / save_data / POST / http://{hostname}/api/v1/orders params:", params)
			request = requests.post(f'http://{hostname}/api/v1/orders', data = params)
			return request

		def query_data(hostname, params={}):
			# print("SignalTelegram Api / query_data / STARTED TIME: ", datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
			# print(f"SignalTelegram Api / query_data / GET / http://{hostname}/api/v1/orders/{params['message_id']}")
			request = requests.get(f"http://{hostname}/api/v1/orders/{params['message_id']}") 
			return request

		def save_message(hostname, params={}):
			# print("Order Api / save_message / STARTED TIME: ", datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
			# print(f"Order Api / save_message / POST / http://{hostname}/api/v1/orders/transaction params:", params)
			request = requests.post(f'http://{hostname}/api/v1/orders/transaction', data = params)
			return request

		def query_collection(hostname, params={}):
			class_caller = inspect.currentframe().f_back.f_locals['self'].__class__.__name__
			# print(f"{class_caller} Api / query_collection / STARTED TIME: ", datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
			# print(f"{class_caller} Api / query_collection / GET / http://{hostname}/api/v1/stores")
			request = requests.get(f"http://{hostname}/api/v1/stores") 
			return request