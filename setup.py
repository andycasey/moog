from distutils.core import setup
import os
import sys
import fileinput
import platform

from platform import system as current_platform
from shutil import copyfile, move
from glob import glob

# Distutils setup information
setup(
    name='moog',
    version='2013.02',
    author='Chris Sneden',
    author_email='chris@verdi.as.utexas.edu',
    maintainer='Andy Casey',
    maintainer_email='andy@the.astrowizici.st',
    url='http://www.as.utexas.edu/~chris/moog.html',
    download_url='http://github.com/andycasey/moog',
    description='Spectrum synthesis and LTE line analysis.',
    long_description='MOOG is a code that performs a variety of LTE line '  \
    +'analysis and spectrum synthesis tasks. The typical use of MOOG is to' \
    +'assist in the determination of the chemical composition of a star.',
    keywords='high-resolution, stellar, spectroscopy, astronomy, astrophysics',
    classifiers=[
        'Development Status :: 5 - Production/Stable',
        'Environment :: MacOS X',
        'Environment :: X11 Applications',
        'Intended Audience :: Science/Research',
        'Natural Language :: English',
        'Operating System :: MacOS',
        'Operating System :: POSIX',
        'Operating System :: Unix',
        'Programming Language :: Fortran',
        'Programming Language :: Python :: 2.5',
        'Topic :: Scientific/Engineering :: Astronomy',
        'Topic :: Scientific/Engineering :: Physics',
    ]
    )


# Identify the platform
platform = current_platform()

# Check for platform first
if platform not in ('Darwin', 'Linux'):
    sys.stderr.write("Platform '%s' not recognised!" % platform)
    sys.exit()

# Which system are we on?
if platform == 'Darwin':
    run_make_files = ('Makefile.mac', 'Makefile.macsilent')
    machine = 'mac'

elif platform == 'Linux':

    machine = 'pcl'
    is_64bits = sys.maxsize > 2**32

    if is_64bits:
        run_make_files = ('Makefile.rh64', 'Makefile.rh64silent')

    else:
        run_make_files = ('Makefile.rh', 'Makefile.rhsilent')

# Get our directories relative to the current path
repository_dir = os.path.dirname(os.path.realpath(__file__))

aqlib = os.path.join(repository_dir, 'lib/aqlib')
smlib = os.path.join(repository_dir, 'lib/smlib')
srcdir = os.path.join(repository_dir, 'moog')

# Update the makefiles with the proper SMLIB and AQLIB
hardcoded_moog_files = [os.path.join(repository_dir, 'moog', filename) for filename in ('Moog.f', 'Moogsilent.f')]
make_files = glob(os.path.join(repository_dir, 'moog/Makefile*'))

# Setup: Create copies of the original
[copyfile(make_file, make_file + '.original') for make_file in make_files]
[copyfile(moog_file, moog_file + '.original') for moog_file in hardcoded_moog_files]

# Update the Makefiles
for line in fileinput.input(make_files, inplace=True):
    line = line.replace('$SMLIB', smlib)
    line = line.replace('$AQLIB', aqlib)
    sys.stdout.write(line)

# Update the MOOG files
for line in fileinput.input(hardcoded_moog_files, inplace=True):
    line = line.replace('$SRCDIR', srcdir)
    line = line.replace('$MACHINE', machine)
    sys.stdout.write(line)

# Run the appropriate make files
for run_make_file in run_make_files:
    os.system('cd moog;make -f %s' % run_make_file)

# Cleanup files: Replace with original files
[move(make_file + '.original', make_file) for make_file in make_files if os.path.exists(make_file + '.original')]
[move(moog_file + '.original', moog_file) for moog_file in hardcoded_moog_files if os.path.exists(moog_file + '.original')]

if os.getuid() == 0:
    # We are sudo; with great power comes great responsibility.

    # Copy the MOOG & MOOGSILENT to /usr/local/bin/
    copyfile(os.path.join(srcdir, 'MOOG'), '/usr/local/bin/MOOG')
    copyfile(os.path.join(srcdir, 'MOOGSILENT'), '/usr/local/bin/MOOGSILENT')

else:
    sys.stderr.write("\nPermission denied!\n\t Could not copy MOOG and MOOGSILENT (in %s) " % srcdir \
                    +"to /usr/local/bin\n\t You should re-run as sudo to remove this message, or "   \
                    +"copy MOOG and MOOGSILENT to somewhere on your $PATH\n\n")



