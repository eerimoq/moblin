import json
import re
import sys

from selenium import webdriver
from selenium.webdriver.firefox.options import Options


RE_BODY = re.compile(r'^<html><head></head><body>(.*)</body></html>$')


def main():
    options = Options()
    options.add_argument('-headless')
    driver = webdriver.Firefox(options=options)

    while True:
        user = sys.stdin.readline().strip()

        if not user:
            break

        driver.get(f"https://kick.com/api/v1/channels/{user}")
        page_source = driver.page_source
        info = json.loads(RE_BODY.match(page_source).group(1))
        channel_id = info['chatroom']['id']
        print(channel_id)

    driver.quit()


main()
