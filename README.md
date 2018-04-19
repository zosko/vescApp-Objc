# VESC_Dashboard
iOS application for VESC controller

Setup VESC controller baud to work with Bluetooth baud.
Run application and find TX and RX characters.

Mine TX/RX
Found RX service: <CBCharacteristic: 0x1c02a2400, UUID = 713D0002-503E-4C75-BA94-3148F18D941E, properties = 0x10, value = (null), notifying = NO>
Found TX service: <CBCharacteristic: 0x1c02a8580, UUID = 713D0003-503E-4C75-BA94-3148F18D941E, properties = 0x4, value = (null), notifying = NO>

Mine setup
BAUD BleMini   57600
RX BleMini:    713D0003-503E-4C75-BA94-3148F18D941E
TX BleMini:    713D0002-503E-4C75-BA94-3148F18D941E
