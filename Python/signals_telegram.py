import pdb
import json
import re
import sys
import time, datetime

from signals_api import SignalApi
from signals_meta import SignalsMeta

class SignalTelegram():
	def __init__(self, sc, tg, config={}):
		self._sc = sc
		self._tg = tg
		self._hostname = config['HOSTNAME']
		self._environment = config['ENVIRONMENT']
		self._signal_image = False

	# pdb.set_trace()

	def prepare(self):
		signal_list = SignalApi.query_collection(hostname=self._hostname).json()		
		if signal_list:
			for trace in signal_list['traces']:
				#CLOSE ORDER
				SignalsMeta(trace['meta_host'], trace['meta_port']).order_closed()
				
				signal_name = trace['name']
				self._signal_image = bool(trace['telegram_image'])
				if trace['telegram_option'] == 'query_name':
					telegram_query = self._tg.call_method('searchChatsOnServer',   params={'query': signal_name, 'limit':10})
					telegram_query.wait()
					telegram_chat = self._tg.get_chat(telegram_query.update['chat_ids'][0])

				if trace['telegram_option'] == 'query_name_id':
					telegram_query = self._tg.call_method('searchChatsOnServer',   params={'query': signal_name, 'limit':10})
					telegram_query.wait()
					telegram_chat = self._tg.get_chat(trace['name_id'])

				telegram_chat.wait()
				telegram_chat.update
				telegram_chat.wait()
				chat_id = telegram_chat.update['id']
				# self._signal_image = True #######################################################
				telegram_message_chat = self._get_chat_history(telegram_chat.update['id'])
				telegram_message_id = telegram_message_chat['messages'][0]['id']
				telegram_username = telegram_chat.update['title']
				telegram_message = self._get_message(telegram_message_chat)
				print(f'##### {signal_name.upper()} / Message ID: {telegram_message_id} #####' )
				print(f'##### {signal_name.upper()} / Message: {telegram_message} #####' )
				information = SignalApi.query_data(hostname=self._hostname, params={'message_id': telegram_message_id})
				if(information.json() is None):
					photo_path    = self._get_photo_path(telegram_message_chat)
					print(f'{telegram_message_id} Telegram User:', telegram_username)
					print(f'{telegram_message_id} text:', telegram_message)
					print(f'{telegram_message_id} Photo Path:', photo_path)
					SignalApi.save_data(hostname=self._hostname, params={'message_id': telegram_message_id, 'message':telegram_message, 'photo_path':photo_path, 'name':signal_name, 'name_id':telegram_chat.update['id']})

					# telegram_chat.wait()
					# telegram_chat.update
					# telegram_chat.wait()
					# chat_id = telegram_chat.update['id']

					# telegram_message = self._get_chat_history(telegram_chat.update['id'])
					# telegram_message_id = telegram_message['messages'][0]['id']
					# telegram_username = telegram_chat.update['title']
					# print(f'{telegram_message_id} Signal: {signal_name}' )

				
					# information = SignalApi.query_data(hostname=self._hostname, params={'message_id': telegram_message_id})
					# if(information.json() is None):
					# 	telegram_message = self._get_message(telegram_message)
					# 	photo_path    = self._get_photo_path(telegram_message)
					# 	print('Telegram User:', telegram_username)
					# 	print('Text:', telegram_message)
					# 	print('Photo Path:', photo_path)
					# 	SignalApi.save_data(hostname=self._hostname, params={'message_id': telegram_message_id, 'message':telegram_message, 'photo_path':photo_path, 'name':signal_name, 'name_id':telegram_chat.update['id']})

	
	def _get_photo_path(self, message, timer=0.5):
		try:
			if self._signal_image and self._signal_image_check:
				if 'photo' in message['messages'][0]['content'].keys():
					remote_file_id = message['messages'][0]['content']['photo']['sizes'][0]['photo']['remote']['id']
				elif "image" in message['messages'][0]['content']['document']['mime_type']:
					remote_file_id = message['messages'][0]['content']['document']['thumbnail']['photo']['remote']['id']
				remote_file = self._tg.call_method('getRemoteFile', params={'remote_file_id': remote_file_id})
				time.sleep(timer)
				remote_file.update
				time.sleep(timer)
				file_id = remote_file.update['id']
				file = self._tg.call_method('downloadFile', params={'file_id': file_id, 'priority': 1, 'offset':0, 'limit':10, 'synchronous':True})
				time.sleep(3)
				path = file.update['local']['path']
				return path
			else:
				return None
		except:
			if timer < 2:
				timer += 0.5 
				return self._get_photo_path(message, timer)
			else:
				return None

	def _get_message(self, message):
		if self._signal_image and 'photo' in message['messages'][0]['content'].keys():
			self._signal_image_check = True
			message =  message['messages'][0]['content']['caption']['text']
		else:
			message = message['messages'][0]['content']['text']['text']
		return message

	def _deEmojify(self, message):
		regrex_pattern = re.compile(pattern = "["
			u"\U0001F600-\U0001F64F"  # emoticons
			u"\U0001F300-\U0001F5FF"  # symbols & pictographs
			u"\U0001F680-\U0001F6FF"  # transport & map symbols
			u"\U0001F1E0-\U0001F1FF"  # flags (iOS)
							   "]+", flags = re.UNICODE)
		return regrex_pattern.sub(r'',message)

	def _get_chat_history(self, chat_id):
		result = self._tg.get_chat_history(chat_id)
		result.wait()
		if result.error:
			print(f'Error Get Message: {result.error_info}')
		else:
			return result.update
# check_chat_id = self._tg.get_chat('-1001490464609')
# chat_id = -1001389557656 #- technicalPips VIP
# chat_id = -1001287502434 #- technicalPips
# check_chat_id = self._tg.call_method('checkChatInviteLink', params={'invite_link': 'https://t.me/joinchat/AAAAAFLS95gUnQM_N75uoA'})
# check_chat_id = self._tg.get_chat('-1001389557656')
# chat_id = -1001159029077 # Swing Trading ViP
# check_chat_id = self._tg.get_chat('-1001222448337')
# chat_id = 60866983
# chat_id = 487330707 #- Breno Perucchi
# chat_id = -481414224 # RoboSignalGroup
# chat_id = -1001436795976 # MirFx
# chat_id = -340961920 # Perucchi Inc	