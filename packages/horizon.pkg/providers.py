#
# Provider information sources for `Horizon' - a false horizon display using
# accelerometer information.                (c) Andrew Flegg 2009
#                                           Released under the Artistic Licence

import os.path
from math import sin, cos, pi

class Dummy:
    """One of the simplest providers: returns dead-on, flat."""
    def position(self):
        return (0, -1000, 0)


class Demo:
    """A demonstration provider which will take the user on a tour through
       the air."""
    x = 0
    y = -1000
    z = 0
    
    def position(self):
        self.x -= 2
        self.y += 1
        self.z += 2
        return (sin(self.x / 150.0 * pi) * 150,
                cos(self.y / 150.0 * pi) * 200,
                sin(self.z / 150.0 * pi) * 300)


class NokiaAccelerometer:
    """An accelerometer provider which actually reads an RX-51's
       accelerometers, based on http://wiki.maemo.org/Accelerometers"""
       
    global ACCELEROMETER_PATH
    ACCELEROMETER_PATH = '/sys/class/i2c-adapter/i2c-3/3-001d/coord'
    
    def position(self):
        f = open(ACCELEROMETER_PATH, 'r')
        return [int(w) for w in f.readline().split()]

    @classmethod
    def available(cls):
        return os.path.isfile(ACCELEROMETER_PATH)

