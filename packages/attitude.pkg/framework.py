#! /usr/bin/env python
#
# Cairo Gtk/Hildon/OSSO framework                        (c) Andrew Flegg 2009
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~          Released under the Artistic Licence
# Based on the version at http://www.tortall.net/mu/wiki/PyGTKCairoTutorial.
#                                                  
import pygtk
pygtk.require('2.0')
import gtk, gobject, cairo

global has_hildon, has_osso, osso_context, debug
debug = False # Change this line to enable debug logging
try:
  import hildon
  has_hildon = True
except ImportError:
  has_hildon = False
  
try:
  import osso
  has_osso = True
except ImportError:
  has_osso = False

# Create a GTK+ widget on which we will draw using Cairo
class Screen(gtk.DrawingArea):
    """This class provides a mechanism for doing graphical programs in a
       power-efficient and simple way. Subclasses should override {{draw}},
       and potentially {{set_visible}}."""
    
    # Tracks whether we should do screen updates
    _visible  = None
    paused    = False

    # Draw in response to an expose-event, this isn't done in run() for
    # reasons which aren't clear
    __gsignals__ = { "expose-event": "override" }


    # -----------------------------------------------------------------------
    @property    
    def version(self):
        """Returns the version number which should be given to DBUS, displayed
           in about boxes etc. This can be overridden in subclasses."""
        return "0.01"


    # -----------------------------------------------------------------------
    @property
    def display_name(self):
        """The name of the application. This is displayed in the titlebar, about
           boxes etc. This can be overridden in subclasses, but defaults
           to the class' name."""
        return self.__class__.__name__


    # -----------------------------------------------------------------------
    @property
    def dbus_name(self):
        """The DBUS name of the application. This defaults to the class name
           in lowercase prefixed with {{org.maemo.}}"""
        return 'org.maemo.' + self.__class__.__name__.lower()


    # -----------------------------------------------------------------------
    @property
    def visible(self):
        """Whether the application is visible. This should be used to indicate
           if timers should continue to fire, etc."""
        return self._visible


    # -----------------------------------------------------------------------
    def set_visible(self, value):
        """Update the _visible_ property."""
        self._visible = value


    # -----------------------------------------------------------------------
    def do_window_state_event(self, window, event):
        """Handle normal GTK+ window state events. If the window is withdrawn
           or minimised, the application is no longer visible."""
        self.set_visible(not event.new_window_state &
                                  (gtk.gdk.WINDOW_STATE_ICONIFIED
                                  |gtk.gdk.WINDOW_STATE_WITHDRAWN))


    # -----------------------------------------------------------------------
    def do_focus_in_event(self, widget, event):
        """If the application has focus given to it, assume that it is now
           visible. This is necessary as Maemo 4 does not always provide the
           correct event handling."""
        self.set_visible(True)


    # -----------------------------------------------------------------------
    def do_general_event(self, widget, event):
        """A general event handler which will, on Hildon, check whether the
           application is visible."""
        if (debug):
          print "%s, state = %d, paused = %d" % (event.type, self.window.get_state(), self.paused)
        if (has_hildon):
          topmost = self.app_window.get_property('is-topmost')
          if (debug):
            print "    topmost = %d" % (topmost)
          self.set_visible(not self.paused and topmost)
          
          
    # -----------------------------------------------------------------------
    def do_property_event(self, widget, event):
        """Track property change events. Ideally, this would be used on Hildon
           to check the 'is-topmost' property; however this event does not
           get fired correctly on Maemo 4."""
        self.do_general_event(widget, event)
        if (debug):
          print "    property = %s" % (event.atom)


    # -----------------------------------------------------------------------
    def do_expose_event(self, event):
        """Handle the 'expose' event, which signals a portion of the viewport
           needs redrawing. This sets up a Cairo context and delegates to the
           {{draw}} method."""
        self.do_general_event(event.window, event)
        cr = self.window.cairo_create()
        cr.rectangle(event.area.x, event.area.y,
                     event.area.width, event.area.height)
        cr.clip()

        self.draw(cr, *self.window.get_size())


    # -----------------------------------------------------------------------
    def draw(self, cr, width, height):
        """Draw the Cairo display. This should be overridden in subclasses."""

        # Fill the background with gray
        cr.set_source_rgb(0.5, 0.5, 0.5)
        cr.rectangle(0, 0, width, height)
        cr.fill()


# ---------------------------------------------------------------------------
# Create and set-up the application, window, event handlers etc.
def run(widget):
    if (has_hildon):
      print "+++ Hildon, yay!"
      widget.app = hildon.Program()
      window = hildon.Window()
      gtk.set_application_name(widget.display_name)
    else:
      print "--- No Hildon, sorry"
      window = gtk.Window()
      window.set_title(widget.display_name)
      
    widget.app_window = window
    window.resize(800, 480)
    window.add(widget)

    window.connect("delete-event", gtk.main_quit)
    window.connect("window-state-event", widget.do_window_state_event)
    window.connect("focus-in-event", widget.do_focus_in_event)
    window.connect("property-notify-event", widget.do_property_event)
    
    if (has_osso):
      print "+++ Have osso, yay!"
      try:
        osso_context = osso.Context(widget.dbus_name, widget.version, False)
        device = osso.DeviceState(osso_context)
        device.set_device_state_callback(state_change, system_inactivity=True, user_data=widget)
      except:
        print "*** Failed to initialise OSSO context. Power management disabled..."
        has_osoo = False

    window.present()
    widget.show()
    gtk.main()
    
# ---------------------------------------------------------------------------
def state_change(shutdown, save_unsaved_data, memory_low, system_inactivity, message, widget):
    """Handle OSSO-specific DBUS callbacks, in this case whether the system has
       been paused."""
    if (debug):
      print "State change (%s): shutdown = %d, save = %d, low mem = %d, paused = %d" % (
                  message, shutdown, save_unsaved_data, memory_low, system_inactivity)
    widget.set_visible(not system_inactivity)
    widget.paused = system_inactivity
    
    
if __name__ == "__main__":
    run(Screen)
