#
# Support for module sm
#
"""Provide python bindings for the SM plotting package using numpy;

Copyright
    Robert Lupton    and     Patricia Monger
   (rhl@astro.princeton.edu; monger@mcmaster.ca)
"""

import smLib
from smLib import *

import numpy
import atexit, threading, time
#
# Symbolic names for colours
#
DEFAULT = "default"
WHITE = "white"; BLACK = "black"
RED = "red"; GREEN = "green"; BLUE = "blue"
CYAN = "cyan"; MAGENTA = "magenta"; YELLOW = "yellow"

#
# Subclass threading to ensure that output is flushed to the screen
#
class thread(threading.Thread):
    def __init__(self, dev = None, verbose = False):
        self._verbose = verbose
        if self._verbose:
            print "Creating main thread"

        self._running = True            # only run while True
        threading.Thread.__init__(self)
        #self.setDaemon(True)
        if dev:
            device(dev)

    def run(self):
        while self._running:
            try:
                gflush()
                redraw(-1)
            except:
                pass

            time.sleep(0.05)

    def stop(self):
        if self._verbose:
            print "Stopping main thread"
        self._running = False
#
# Make sure that there's a refresh thread running
#
try:
    type(mainThread)
except NameError:
    mainThread = thread('nodevice', verbose = False)
    mainThread.start()

    atexit.register(mainThread.stop)
    atexit.register(hardcopy)
#
# Provide some of interactive SM's useful functionality
#
def connect(x, y, logical = None):
    """Connect points (x, y), optionally only using points where logical is true.
    Uses current ctype and ltype"""
    
    if not isinstance(logical, type(None)):
        smLib.connect_if(x, y, logical)
    else:
        smLib.connect(x,y)

def histogram(x, y, logical = None):
    """Draw a histogram of x against y, optionally only using points where logical is true.
    Uses current ctype and ltype"""
    
    if not isinstance(logical, type(None)):
        smLib.histogram_if(x, y, logical)
    else:
        smLib.histogram(x,y)

def points(x, y, logical = None):
    """Plot x against y, optionally only using points where logical is true.
    Uses current ctype, ptype, angle, and expand"""
    
    if not isinstance(logical, type(None)):
        smLib.points_if(x, y, logical)
    else:
        smLib.points(x,y)

def limits(x, y):
    """Set the x- and y-limits.  You may specify
arrays or lists, or tuples of 2 exact limits. E.g.
       limits(x, y)
       limits([1, 10], y)
       limits((1, 10), y)
The tuple will be obeyed exactly; the list will be treated
as an array and used to find a `good' interval
       """

    def limits_from_array(vec, extra = 0.05):
        min = vec.min(); max = vec.max()
        range = max - min
        return (min - extra*range, max + extra*range)
    
    if isinstance(x, list) or isinstance(x, tuple):
        (x0, x1) = x
    else:
        (x0, x1) = limits_from_array(x)

    if isinstance(y, list) or isinstance(y, tuple):
        (y0, y1) = y
    else:
        (y0, y1) = limits_from_array(y)

    smLib.limits(x0, x1, y0, y1)


def contour(arr, x = None, y = None):
    """Draw a contour plot of arr. The ranges of values
    on the axes are specified as x or y (default: 0..N-1). Note that
    the current limits are obeyed --- x and y specify the range of
    data present in the array.

    You may specify arrays or lists, or tuples specifying the min and
    max values. E.g.
       contour(arr, x, y)
       contour(arr, [1, 10], y)
       contour(arr, (1, 10), y)
       """

    if x == None:
        (x0, x1) = (0, 0)
    elif isinstance(x, list) or isinstance(x, tuple):
        (x0, x1) = x
    else:
        (x0, x1) = (x.min(), x.max())

    if y == None:
        (y0, y1) = (0, 0)
    elif isinstance(y, list) or isinstance(y, tuple):
        (y0, y1) = y
    else:
        (y0, y1) = (y.min(), y.max())

    smLib.contour(arr, x0, x1, y0, y1)

def frelocate(x, y):
    """Relocate to a point (x, y) where x and y run from 0 to 1 within the box"""

    relocate(cvar.fx1 + x*(cvar.fx2 - cvar.fx1), cvar.fy1 + y*(cvar.fy2 - cvar.fy1))

def where():
    """Return the current plot position, (x, y)"""
    return ((cvar.xp - cvar.ffx)/cvar.fsx,(cvar.yp - cvar.ffy)/cvar.fsy)

def x11(dev = None):
    """Open the current X11 device, or switch if a device is specified"""
    if dev == None:
        smLib.device('x11')
    else:
        smLib.device('x11 -dev %d' % dev)

# A possibly-useful demo
#
def demo(dev = None):
    """Make a demo plot, optionally first opening the specified device."""

    if dev:
        device(dev)
        erase()

    x = numpy.arange(0, 20)
    y = x*x
    err = 10 + 0*x

    limits((-1, 22), y)
    box()
    
    angle(45)
    points(x,y)
    angle()

    expand(2)
    identification("Robert \int f(x) dx")
    expand()

    for l in (2, 4):
        errorbar(x,y,err,l)

    xlabel("x axis")
    ylabel("Y")

    ptype([40, 50, 60]); expand(3)
    points([5, 10, 15], [125, 200, 325])
    ptype(); expand()

    lweight(3)
    histogram(x, y)
    lweight()

    ltype(2)
    connect(x,y)
    ltype()

    ltype(1)
    ctype(RED)
    grid(1)
    ltype()
    ctype(MAGENTA)
    grid()
    ctype()
    
    relocate(11, 100)
    label("Hello ")
    dot()
    draw(15.5, 100)
    dot()
    (uxp, uyp) = where()
    relocate(uxp + 0.5, uyp)
    putlabel(6,"Goodbye \point 6 0")
