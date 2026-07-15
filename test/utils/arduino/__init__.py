import sys

from simba_soam.soam import SlipSerialClient


class Arduino:
    def __init__(self, serial_port: str) -> None:
        self.client = SlipSerialClient(
            serial_port=serial_port,
            baudrate=38400,
            database="utils/arduino/soam.soamdb",
            ostream=sys.stdout,
            debug=False,
        )
        self.client.execute_command("drivers/pin/set_mode d8 output")
        self.client.execute_command("drivers/pin/set_mode d52 output")
        self.back_motor_off()
        self.front_motor_off()

    def back_motor_on(self):
        self.client.execute_command("drivers/pin/write d52 high")

    def back_motor_off(self):
        self.client.execute_command("drivers/pin/write d52 low")

    def front_motor_on(self):
        self.client.execute_command("drivers/pin/write d8 high")

    def front_motor_off(self):
        self.client.execute_command("drivers/pin/write d8 low")
