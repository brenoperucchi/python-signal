import pdb
import os

from DWX_ZeroMQ_Connector_v2_0_1_RC8 import DWX_ZeroMQ_Connector

_zmq = DWX_ZeroMQ_Connector()
_zmq._DWX_ZMQ_HEARTBEAT_()
_my_trade = _zmq._generate_default_order_dict()
_zmq._DWX_MTX_NEW_TRADE_(_order=_my_trade)

pdb.set_trace()
_zmq.remote_recv(_zmq._PULL_SOCKET)
