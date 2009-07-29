#
# Provider information sources for `Horizon' - a false horizon display using
# accelerometer information.                (c) Andrew Flegg 2009
#                                           Released under the Artistic Licence

import os.path
from math import sin, cos, pi

class Dummy:
    """One of the simplest providers: returns dead-on, flat."""
    def position(self):
        #return (0, 0, -1000) # Back down
        #return (0, 0, 1000)  # Front down
        #return (-1000, 0, 0) # Right edge down
        #return (1000, 0, 0)  # Left edge down
        #return (0, -1000, 0) # Bottom edge down
        return (-500, -500, 0) # Bottom right down


class Demo:
    """A demonstration provider which will take the user on a tour through
       the air."""
    x = 0.0
    y = 0.0
    z = 0.0
    
    def position(self):
        self.x += 0.1
        self.y += 0.04
        self.z += 0.03
        return (sin(self.x) * 550,
                sin(self.y) * 400 - 200,
                sin(self.z) * 450)


class NokiaAccelerometer:
    """An accelerometer provider which actually reads an RX-51's
       accelerometers, based on http://wiki.maemo.org/Accelerometers"""
       
    global ACCELEROMETER_PATH
    ACCELEROMETER_PATH = '/sys/class/i2c-adapter/i2c-3/3-001d/coord'
    
    def position(self):
        f = open(ACCELEROMETER_PATH, 'r')
        coords = [int(w) for w in f.readline().split()]
        f.close()
        return coords

    @classmethod
    def available(cls):
        return os.path.isfile(ACCELEROMETER_PATH)

