import json
import re
import sys

from selenium import webdriver
from selenium.webdriver.firefox.options import Options
import asyncio
import json
import logging
import platform
import subprocess
import sys
from urllib.parse import parse_qs
from xml.etree import ElementTree

import cpuinfo
from aiohttp import web
from aiohttp_middlewares import cors_middleware
from iso8601 import parse_date


RE_BODY = re.compile(r'^<html><head></head><body>(.*)</body></html>$')


class Handler:

    def __init__(self, driver):
        self._driver = driver

    async def index(self, request):
        request = await request.json()
        user = request['user']
        self._driver.get(f"https://kick.com/api/v1/channels/{user}")
        page_source = self._driver.page_source
        info = json.loads(RE_BODY.match(page_source).group(1))
        channel_id = info['chatroom']['id']

        return web.json_response({'channelId': channel_id})


async def run(driver):
    app = web.Application(
        middlewares=[
            cors_middleware(allow_all=True)
        ])
    handler = Handler(driver)
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



def main():
    options = Options()
    options.add_argument('-headless')
    driver = webdriver.Firefox(options=options)
    asyncio.run(run(driver))
    driver.quit()


main()
