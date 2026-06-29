require 'rubygems'
require 'byebug'
require 'pycall/import'
include PyCall::Import
PyCall.sys.path.append File.dirname('connector')
# PyCall.import_module('connector')

pyfrom 'connector', import: :'DWX_ZeroMQ_Connector'

zmq = DWX_ZeroMQ_Connector.new
sleep(1)
zmq._DWX_ZMQ_HEARTBEAT_
zmq.remote_recv(zmq._PULL_SOCKET)
