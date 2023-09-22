import json
import re
import sys

from selenium import webdriver
from selenium.webdriver.firefox.options import Options


RE_BODY = re.compile(r'^<html><head></head><body>(.*)</body></html>$')


def main():
    user = sys.argv[1]
    options = Options()
    options.add_argument('-headless')
    driver = webdriver.Firefox(options=options)
    driver.get(f"https://kick.com/api/v1/channels/{user}")
    page_source = driver.page_source
    driver.quit()
    channel_id = json.loads(RE_BODY.match(page_source).group(1))['id']
    print(channel_id)


main()
