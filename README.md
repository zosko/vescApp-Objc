# VESC_Dashboard
iOS application for VESC controller

Setup VESC controller baud to work with Bluetooth baud.
Run application and find TX and RX characters.

Mine TX/RX<br />
Found RX service: <br />
<CBCharacteristic: 0x1c02a2400, UUID = 713D0002-503E-4C75-BA94-3148F18D941E, properties = 0x10, value = (null), notifying = NO><br />
Found TX service: <br />
<CBCharacteristic: 0x1c02a8580, UUID = 713D0003-503E-4C75-BA94-3148F18D941E, properties = 0x4, value = (null), notifying = NO>

Mine setup<br />
BAUD BleMini   57600<br />
RX BleMini:    713D0003-503E-4C75-BA94-3148F18D941E<br />
TX BleMini:    713D0002-503E-4C75-BA94-3148F18D941E<br />
