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

Classically, `MOOG <http://www.as.utexas.edu/~chris/moog.html>`_ has been difficult to install. Or at least, it has been
for me because I'm bad at computers. Now it's easy!

Just open a terminal and type:

``sudo pip install smh``

Or,

``sudo easy_install smh``

And that's it. Happy spectroscopy-ing!

**NB**: You don't have to be ``sudo`` to have MOOG compile correctly. You
can install MOOG without these priviledges. However, if you don't have
sudo access you will need to copy the ``MOOG`` and ``MOOGSILENT`` files to
a folder somewhere on your ``$PATH`` to make your life easier.
