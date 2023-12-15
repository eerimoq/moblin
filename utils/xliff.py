import argparse
from xml.etree import ElementTree

NS = {
    '': "urn:oasis:names:tc:xliff:document:1.2"
}

ElementTree.register_namespace('', "urn:oasis:names:tc:xliff:document:1.2")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('xliff')
    args = parser.parse_args()

    tree = ElementTree.parse(args.xliff)

    for body in tree.findall('./file/body', namespaces=NS):
        sorted_trans_units = []

        for trans_unit in body.findall('./trans-unit', namespaces=NS):
            target = trans_unit.find("./target", namespaces=NS)

            if target is None:
                sorted_trans_units.insert(0, trans_unit)
            else:
                if target.attrib.get('state') == 'translated':
                    sorted_trans_units.append(trans_unit)
                else:
                    sorted_trans_units.insert(0, trans_unit)

        body.clear()
        body.extend(sorted_trans_units)

    ElementTree.indent(tree)
    tree.write(args.xliff, xml_declaration=True, encoding='utf-8')


main()
