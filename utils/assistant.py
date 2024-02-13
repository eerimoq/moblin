import json
import random
import argparse
from aiohttp import web
import aiohttp
from websockets.sync.client import connect
from hashlib import sha256
from base64 import b64encode
import asyncio

DEFAULT_PORT = 2345
API_VERSION = '0.1'


def random_string():
    return random.randbytes(64).hex()


class Assistant:

    def __init__(self, password):
        self.password = password
        self.challenge = None
        self.salt = None
        self.streamer = None
        self.request_id = 0
        self.client_completions = {}
        
    async def handle_streamer(self, request):
        self.streamer = web.WebSocketResponse()
        await self.streamer.prepare(request)

        self.challenge = random_string()
        self.salt = random_string()
        await self.send_to_streamer({
            'hello': {
                'apiVersion': API_VERSION,
                'authentication': {
                    'challenge': self.challenge,
                    'salt': self.salt
                }
            }
        })

        async for message in self.streamer:
            if message.type == aiohttp.WSMsgType.TEXT:
                message = json.loads(message.data)

                for kind, data in message.items():
                    if kind == 'identify':
                        await self.handle_identify(data['authentication'])
                    elif kind == 'event':
                        await self.handle_event(data['data'])
                    elif kind == 'response':
                        await self.handle_response(data)
                    else:
                        print('Unknown message', message)
            else:
                print('Ignoring', message)

        return self.streamer

    async def send_to_streamer(self, message):
        await self.streamer.send_str(json.dumps(message))

    def next_id(self):
        self.request_id += 1

        return self.request_id

    def hash_password(self):
        concatenated = self.password + self.salt
        hash = b64encode(sha256(
            concatenated.encode('utf-8')).digest()).decode('utf-8')
        concatenated = hash + self.challenge

        return b64encode(sha256(
            concatenated.encode('utf-8')).digest()).decode('utf-8')

    async def handle_identify(self, authentication):
        if authentication == self.hash_password():
            await self.send_to_streamer({
                'identified': {
                    'result': {
                        'ok':{}
                    }
                }
            })
        else:
            print('identify failed')

    async def handle_event(self, data):
        for kind, data in data.items():
            if kind == 'log':
                print(data['entry'])
            else:
                print('ignoring event', kind, data)

    async def handle_response(self, data):
        print(data)
        try:
            request_id = data['id']
            queue = self.client_completions[request_id]
            await queue.put(data)
        except Exception:
            pass

    async def handle_client(self, request):
        client = web.WebSocketResponse()
        await client.prepare(request)

        async for message in client:
            if message.type == aiohttp.WSMsgType.TEXT:
                message = json.loads(message.data)

                if message['type'] == 'request':
                    request_id = self.next_id()
                    queue = asyncio.Queue()
                    self.client_completions[request_id] = queue
                    await self.send_to_streamer({
                        'request': {
                            'id': request_id,
                            'data': message['data']
                        }
                    })
                    await client.send_str(json.dumps({
                        'type': 'response',
                        'data': await queue.get()
                    }))
                else:
                    print('Not supported', message)
            else:
                print('Ignoring', message)

        return client


def do_run(args):
    app = web.Application()
    assistant = Assistant(args.password)
    app.add_routes([web.get('/', assistant.handle_streamer)])
    app.add_routes([web.get('/client', assistant.handle_client)])
    web.run_app(app, port=args.port)


def do_get_settings(args):
    with connect(f'ws://localhost:{args.port}/client') as server:
        server.send(json.dumps({
            'type': 'request',
            'data': {
                'getSettings': {
                }
            }
        }))
        data = json.loads(server.recv())['data']['data']['getSettings']['data']
        print(json.dumps(data, indent=4))


def do_set_zoom(args):
    with connect(f'ws://localhost:{args.port}/client') as server:
        server.send(json.dumps({
            'type': 'request',
            'data': {
                'setZoom': {
                    'x': float(args.level)
                }
            }
        }))
        server.recv()


def do_set_scene(args):
    with connect(f'ws://localhost:{args.port}/client') as server:
        server.send(json.dumps({
            'type': 'request',
            'data': {
                'setScene': {
                    'id': args.name
                }
            }
        }))
        server.recv()


def main():
    parser = argparse.ArgumentParser()

    subparsers = parser.add_subparsers(title='subcommands',
                                       dest='subcommand')
    subparsers.required = True

    subparser = subparsers.add_parser('run')
    subparser.add_argument('--password', required=True)
    subparser.add_argument('--port', type=int, default=DEFAULT_PORT)
    subparser.set_defaults(func=do_run)

    subparser = subparsers.add_parser('get_settings')
    subparser.add_argument('--port', type=int, default=DEFAULT_PORT)
    subparser.set_defaults(func=do_get_settings)

    subparser = subparsers.add_parser('set_zoom')
    subparser.add_argument('--port', type=int, default=DEFAULT_PORT)
    subparser.add_argument('level')
    subparser.set_defaults(func=do_set_zoom)

    subparser = subparsers.add_parser('set_scene')
    subparser.add_argument('--port', type=int, default=DEFAULT_PORT)
    subparser.add_argument('name')
    subparser.set_defaults(func=do_set_scene)

    args = parser.parse_args()

    args.func(args)


main()
