import sys
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
        if self.streamer is None:
            raise Exception('Streamer not connected')

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


def make_client_request(port, data):
    with connect(f'ws://localhost:{port}/client') as server:
        server.send(json.dumps({
            'type': 'request',
            'data': data
        }))

        return json.loads(server.recv())['data']


def get_settings(port):
    data = make_client_request(
        port,
        {
            'getSettings': {
            }
        })

    return data['data']['getSettings']['data']


def get_scene_id(port, name):
    settings = get_settings(port)

    for scene in settings['scenes']:
        if scene['name'] == name:
            return scene['id']
    else:
        raise Exception(f'Unknown scene {name}')


def do_get_settings(args):
    print(json.dumps(get_settings(args.port), indent=4))


def do_set_zoom(args):
    make_client_request(
        args.port,
        {
            'setZoom': {
                'x': float(args.level)
            }
        })


def do_set_scene(args):
    make_client_request(
        args.port,
        {
            'setScene': {
                'id': get_scene_id(args.port, args.name)
            }
        })


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-d', '--debug', action='store_true')
    parser.add_argument('--port', type=int, default=DEFAULT_PORT)

    subparsers = parser.add_subparsers(title='subcommands',
                                       dest='subcommand')
    subparsers.required = True

    subparser = subparsers.add_parser('run')
    subparser.add_argument('--password', required=True)
    subparser.set_defaults(func=do_run)

    subparser = subparsers.add_parser('get_settings')
    subparser.set_defaults(func=do_get_settings)

    subparser = subparsers.add_parser('set_zoom')
    subparser.add_argument('level')
    subparser.set_defaults(func=do_set_zoom)

    subparser = subparsers.add_parser('set_scene')
    subparser.add_argument('name')
    subparser.set_defaults(func=do_set_scene)

    args = parser.parse_args()

    if args.debug:
        args.func(args)
    else:
        try:
            args.func(args)
        except BaseException as e:
            sys.exit('error: ' + str(e))


main()
