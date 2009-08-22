#!/usr/bin/env python
#
# Main class for `Attitude' - a false horizon display using accelerometer
# information.                              (c) Andrew Flegg 2009
#                                           Released under the Artistic Licence

import providers
import framework
from framework import Screen

import gobject
import cairo
import gtk
from math import pi, sin, atan2, degrees

class Attitude(Screen):
    """Create and manage a Cairo display using an external information
    system providing accelerometer information.
    
    This uses the `Screen' framework as described in the Cairo tutorials
    at http://www.tortall.net/mu/wiki/PyGTKCairoTutorial.
    """
    
    provider = None
    
    rotation = None
    boundary = None
    freq     = 4
    count    = 0
    average  = 3
    total    = (0, 0, 0)

    ground = None
    sky    = None

    # -----------------------------------------------------------------------
    def __init__(self, provider):
        """Initialise the information provider. This is responsible for
        having a {{position}} method which returns an x, y, z tuple."""
        Screen.__init__(self)
        self.provider = provider

    # -----------------------------------------------------------------------
    def set_visible(self, visible):
        """Override visibility setter to re-enable timeout."""
        if (visible == self.visible):
          return
          
        super(Attitude, self).set_visible(visible)
        print "Visibility change: %d" % (visible)
        if (visible):
          self.update_display()
          gobject.timeout_add(self.freq, Attitude.update_display, self)
        
    # -----------------------------------------------------------------------
    def show(self):
        """Override initial display to create update schedule and reused
        gradient fills."""
        Screen.show(self)
     
        self.ground = cairo.LinearGradient(0, -0.5, 0, 0.5)
        self.ground.add_color_stop_rgb(0, 87/255.0, 153/255.0, 10/255.0)
        self.ground.add_color_stop_rgb(1, 0, 123/255.0, 0)
        
        self.sky = cairo.LinearGradient(0, -0.5, 0, 0.5)
        self.sky.add_color_stop_rgb(0, 0, 107/255.0, 214/255.0)
        self.sky.add_color_stop_rgb(1, 30/255.0, 148/255.0, 1)
        
        self.set_visible(True)

    # -----------------------------------------------------------------------
    def update_display(self):
        """Call the configured position provider's {{position}} method which
        returns x, y, z tuple. The values should be in the range -1000 - 1000."""
        
        (x, y, z) = self.provider.position()
        self.total = (self.total[0] + x, self.total[1] + y, self.total[2] + z)
        if (++self.count % self.average <> 0):
          return self.visible

        (x, y, z) = (self.total[0] / self.average, self.total[1] / self.average, self.total[2] / self.average)
        self.total = (0, 0, 0)
        self.count = 0

        boundary = max(min(z / 1000.0, 1), -1)
        rotation = atan2(x, -y)
        
        if (self.rotation <> rotation or self.boundary <> boundary):
          self.rotation = rotation
          self.boundary = boundary
          self.window.invalidate_region(
                  gtk.gdk.region_rectangle((0, 0,
                                            self.window.get_size()[0],
                                            self.window.get_size()[1])),
                  True)

        return self.visible

    # -----------------------------------------------------------------------
    def draw(self, cr, width, height):
        """Responsible for the actual drawing of: the ground, sky, false
        horizon, height bar and roll display."""
        
        cr.save()
        cr.scale(height, height)
        cr.translate(0.5 * width / height, 0.5)
        cr.rotate(self.rotation)

        # -- Draw the ground...
        #
        cr.set_source(self.ground)
        cr.rectangle(-2, self.boundary, 4, 2)
        cr.fill()
        
        # -- Draw the sky...
        #
        cr.rectangle(-2, self.boundary - 2, 4, 2)
        cr.set_source(self.sky)
        cr.fill()

        # -- Draw the false horizon...
        #
        cr.set_source_rgba(1, 1, 1, 0.8)
        cr.set_line_width(0.004)

        cr.move_to(-0.14, 0)
        cr.line_to(-0.03, 0)
        cr.move_to(0.03, 0)
        cr.line_to(0.14, 0)
        cr.stroke()

        # -- Draw the height bars...
        #
        bar_height = self.boundary / 4.0
        cr.move_to(-0.04, bar_height - 0.25)
        cr.line_to(0, bar_height - 0.25)
        cr.line_to(0, bar_height + 0.25)
        cr.line_to(0.04, bar_height + 0.25)
        for i in range(1, 10):
          y = (bar_height - 0.25) + (i * 0.05)
          cr.move_to(-0.018, y)
          cr.line_to(0.018, y)
        cr.stroke()

        # -- Draw the down arrow...
        #
        cr.set_line_width(0.003)
        cr.move_to(-0.02, 0.45)
        cr.line_to(0.02, 0.45)
        cr.line_to(0, 0.5)
        cr.close_path()
        cr.stroke()
        
        # -- Show the telemetry...
        #
        cr.restore()
        cr.set_source_rgba(1, 1, 1, 0.8)
        cr.select_font_face("sans-serif")
        cr.set_font_size(32)
        angle = unicode(round(degrees(self.rotation), 1)) + u'\u00b0'
        (x, y, w, h, xa, ya) = cr.text_extents(angle)
        cr.move_to(width - 40 - w, 40)
        cr.show_text(angle)


if __name__ == "__main__":
    provider = None
    if (providers.NokiaAccelerometer.available()):
      provider = providers.NokiaAccelerometer()
    else:
      provider = providers.Demo()
      
    framework.run(Attitude(provider))

