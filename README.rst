=======
Installing MOOG the Easy Way™
=======

:Info: See the `GitHub repository <http://www.github.com/andycasey/moog>`_ for the latest source
:Author: Andy Casey, Australian National University (andy@the.astrowizici.st)
:Website: `astrowizici.st <http://astrowizici.st>`_
:License: Distribute to anyone you see fit, as long as you adhere to the licenses set by the dependencies (`SuperMongo <http://www.astro.princeton.edu/~rhl/sm/>`_, `MOOG <http://www.as.utexas.edu/~chris/moog.html>`_, etc). Improvements are welcome!


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
operating system, MOOG uses `g77
<http://hpc.sourceforge.net/>`_ to compile so you will need that too.
If you have these, just open a terminal and type:

``sudo pip install moog``

And that's it. Happy spectroscopy-ing!

If you don't have ``pip``, you have two options:

**1)** Install ``pip`` and try re-installing MOOG:

``sudo easy_install pip``

``sudo pip install moog``

**or**

**2)** Download this repository. extract the files and type:

``sudo python setup.py install``

The installer will compile MOOG and MOOGSILENT and place them in the
``/usr/local/bin`` directory so that they are accessible on your
``$PATH``. If you
don't install the code as sudo then you will get an error telling you that
MOOG and MOOGSILENT could not be copied to ``/usr/local/bin``. In that
case,
just copy the MOOG and MOOGSILENT files from the folder specified in the
error message and place them somewhere on your ``$PATH``.


Uninstall
---------
Just remove the following files to uninstall MOOG:

``/usr/local/bin/MOOG``

``/usr/local/bin/MOOGSILENT``

and type:

``pip uninstall moog``

