import plistlib
import socket
import struct
import sys

USBMUX_UNIX_PATH = "/var/run/usbmuxd"
USBMUX_TCP_ADDRESS = ("127.0.0.1", 27015)

_HEADER = struct.Struct("<IIII")
_VERSION_PLIST = 1
_TYPE_PLIST = 8


class UsbmuxError(Exception):
    pass


def _connect_to_usbmuxd():
    if sys.platform == "win32":
        return socket.create_connection(USBMUX_TCP_ADDRESS)
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(USBMUX_UNIX_PATH)
    return sock


def _receive_exactly(sock, length):
    data = b""
    while len(data) < length:
        chunk = sock.recv(length - len(data))
        if not chunk:
            raise UsbmuxError("usbmuxd closed the connection")
        data += chunk
    return data


class _Session:
    def __init__(self):
        self.sock = _connect_to_usbmuxd()
        self.tag = 0

    def request(self, message):
        self.tag += 1
        payload = plistlib.dumps(
            {
                "ClientVersionString": "moblin-usb-host",
                "ProgName": "moblin-usb-host",
                **message,
            }
        )
        header = _HEADER.pack(_HEADER.size + len(payload), _VERSION_PLIST, _TYPE_PLIST, self.tag)
        self.sock.sendall(header + payload)
        length, _, _, _ = _HEADER.unpack(_receive_exactly(self.sock, _HEADER.size))
        return plistlib.loads(_receive_exactly(self.sock, length - _HEADER.size))


def list_devices():
    session = _Session()
    try:
        reply = session.request({"MessageType": "ListDevices"})
    finally:
        session.sock.close()
    return [
        (device["DeviceID"], device["Properties"].get("SerialNumber", "?"))
        for device in reply.get("DeviceList", [])
    ]


def connect(port, serial=None):
    devices = list_devices()
    if not devices:
        raise UsbmuxError("No device connected over USB")
    if serial is None:
        device_id, serial = devices[0]
    else:
        matching = [device for device in devices if device[1] == serial]
        if not matching:
            raise UsbmuxError(f"Device {serial} not connected over USB")
        device_id = matching[0][0]
    session = _Session()
    reply = session.request(
        {
            "MessageType": "Connect",
            "DeviceID": device_id,
            "PortNumber": socket.htons(port),
        }
    )
    if reply.get("Number") != 0:
        session.sock.close()
        raise UsbmuxError(
            f"Failed to connect to port {port} on {serial} (error {reply.get('Number')}). "
            "Is Moblin live with a usb:// stream URL?"
        )
    return session.sock, serial
