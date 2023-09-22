import json
import re
import sys
from functools import lru_cache

from selenium import webdriver
from selenium.webdriver.firefox.options import Options
import asyncio

from aiohttp import web
from aiohttp_middlewares import cors_middleware


RE_BODY = re.compile(r'^<html><head></head><body>(.*)</body></html>$')
DRIVER = None


@lru_cache
def get_channel_id(user):
    DRIVER.get(f"https://kick.com/api/v1/channels/{user}")
    page_source = DRIVER.page_source
    info = json.loads(RE_BODY.match(page_source).group(1))

    return info['chatroom']['id']


class Handler:

    async def index(self, request):
        request = await request.json()
        user = request['user']

        return web.json_response({
            'channelId': get_channel_id(user)
        })


async def run():
    app = web.Application(
        middlewares=[
            cors_middleware(allow_all=True)
        ])
    handler = Handler()
    app.add_routes([
        web.post('/', handler.index),
    ])
    runner = web.AppRunner(app)
    await runner.setup()
    address = '0.0.0.0'
    http_server_port = 5010
    site = web.TCPSite(runner, address, http_server_port)
    await site.start()
    http_server_port = runner.addresses[0][1]

    print(f"HTTP server listening on '{address}:{http_server_port}'.")

    while True:
        await asyncio.sleep(3600)



options = Options()
options.add_argument('-headless')
DRIVER = webdriver.Firefox(options=options)
asyncio.run(run())
