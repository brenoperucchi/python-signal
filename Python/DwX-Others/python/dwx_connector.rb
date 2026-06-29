require 'rubygems'
require 'byebug'
require 'pycall/import'
include PyCall::Import
PyCall.sys.path.append File.dirname('connector')
# PyCall.import_module('connector')

pyfrom 'DWX_ZeroMQ_Connector_v2_0_1_RC8', import: :'DWX_ZeroMQ_Connector'

zmq = DWX_ZeroMQ_Connector.new
zmq._DWX_ZMQ_HEARTBEAT_
# zmq.remote_recv(zmq._PULL_SOCKET)
