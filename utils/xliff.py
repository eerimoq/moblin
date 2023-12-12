import argparse
from xml.etree import ElementTree

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('xliff')
    args = parser.parse_args()

    ElementTree.register_namespace('', "urn:oasis:names:tc:xliff:document:1.2")

    tree = ElementTree.parse(args.xliff)
    tree.write(args.xliff, xml_declaration=True, encoding='utf-8')


main()
