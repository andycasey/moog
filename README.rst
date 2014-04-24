=======
Installing MOOG the Easy Way™
=======

:Info: See the `GitHub repository <http://www.github.com/andycasey/moog>`_ for the latest source
:Author: Andy Casey, University of Cambridge (andy@astrowizici.st)
:Website: `astrowizici.st <http://astrowizici.st>`_
:License: Distribute to anyone you see fit, as long as you adhere to the licenses set by `MOOG <http://www.as.utexas.edu/~chris/moog.html>`_. Improvements are welcome!


Background
----------
`MOOG <http://www.as.utexas.edu/~chris/moog.html>`_ was written by `Chris
Sneden <mailto:chris@verdi.as.utexas.edu>`_ and has -- and continues to be
-- an
invaluable contribution to modern stellar astrophysics. From the `MOOG <http://www.as.utexas.edu/~chris/moog.html>`_ website:

*MOOG is a code that performs a variety of LTE line analysis and spectrum
synthesis tasks. The typical use of MOOG is to assist in the determination
of the chemical composition of a star.*

The current `MOOG <http://www.as.utexas.edu/~chris/moog.html>`_ version
hosted by this repository is the February, 2013 version.


Installation
------------
Classically, MOOG has been difficult to install. Or at least, it has been
for me because I'm bad at computers. Now it's easy-ier!

If you are on a Mac then you will need to ensure you have `Xcode
<https://developer.apple.com/xcode/>`_ installed
as well as the `Command Line Tools
<http://stackoverflow.com/a/9329325/424731>`_ first. Regardless of your
operating system, you will need either `gfortran
<http://gcc.gnu.org/wiki/GFortran>`_ (recommended) or `g77
<http://hpc.sourceforge.net/>`_ to compile MOOG.
If you have either of these, just open a terminal and type:

``pip install moogsilent``

And that's it. Happy spectroscopy-ing!

**or**

`Download this repository
<https://github.com/andycasey/moog/archive/master.zip>`_, extract the files and type:

``python setup.py install``

The installer will compile ``MOOGSILENT`` and place it in
your ``$PATH``. It will also create a ``~/.moog``
directory to contain data files.


Python Context Manager FTW
--------------------------

I've included a Python context manager with this version. That means you can do the following in Python::


    import moog

    with moog.instance("/tmp/") as moogsilent:
        abundances = moogsilent.abfind(...)

        dispersion, intensities = moogsilent.synth(...)


and get native Python objects returned to you. *Sick*, right?


Uninstall
---------
Just type the following files to uninstall MOOG:

``pip uninstall moog``

And to clean up completely:

``rm -Rf ~/.moog``

