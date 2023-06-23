#!/usr/bin/python3
import sys
import websocket
import json

VERSION='0.0.2'
ws = websocket.WebSocket()
ws.connect("ws://ws.qreader.htb:5789/version")
ws.send(json.dumps({'version': sys.argv[1]}))
print(ws.recv())
