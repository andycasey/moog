# coding: utf-8

""" A Pythonic Interface to MOOG(SILENT) """

__author__ = "Andy Casey <andy@astrowizici.st>"


# Standard library
import logging
import os
import re
import shutil
from operator import itemgetter
from random import choice
from signal import alarm, signal, SIGALRM, SIGKILL
from string import ascii_letters
from subprocess import PIPE, Popen
from textwrap import dedent

# Third party
import numpy as np

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

__all__ = ["instance"]

def element_to_species(element_repr):
    """ Converts a string representation of an element and its ionization state
    to a floating point """
    
    periodic_table = """H                                                  He
                        Li Be                               B  C  N  O  F  Ne
                        Na Mg                               Al Si P  S  Cl Ar
                        K  Ca Sc Ti V  Cr Mn Fe Co Ni Cu Zn Ga Ge As Se Br Kr
                        Rb Sr Y  Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I  Xe
                        Cs Ba Lu Hf Ta W  Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn
                        Fr Ra Lr Rf Db Sg Bh Hs Mt Ds Rg Cn UUt"""
    
    lanthanoids    =   "La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb"
    actinoids      =   "Ac Th Pa U  Np Pu Am Cm Bk Cf Es Fm Md No"
    
    periodic_table = periodic_table.replace(" Ba ", " Ba " + lanthanoids + " ") \
        .replace(" Ra ", " Ra " + actinoids + " ").split()
    del actinoids, lanthanoids
    
    if not isinstance(element_repr, (unicode, str)):
        raise TypeError("element must be represented by a string-type")
        
    if element_repr.count(" ") > 0:
        element, ionization = element_repr.split()[:2]
    else:
        element, ionization = element_repr, "I"
    
    if element not in periodic_table:
        # Don"t know what this element is
        return float(element_repr)
    
    ionization = max([0, ionization.upper().count("I") - 1]) /10.
    transition = periodic_table.index(element) + 1 + ionization
    return transition


class MOOGError(BaseException):
    pass


class instance(object):
    """ A context manager for dealing with MOOG """

    _executable = "MOOGSILENT"
    _acceptable_return_codes = (0, )

    def __init__(self, twd_base_dir="/tmp/", chars=10):
        """ Initialisation class allows the user to specify a base temporary
        working directory """

        self.chars = chars
        self.twd_base_dir = twd_base_dir
        if not os.path.exists(self.twd_base_dir):
            os.mkdir(self.twd_base_dir)

    def __enter__(self):
        # Create a temporary working directory
        self.twd = os.path.join(self.twd_base_dir, "".join([choice(ascii_letters) for _ in xrange(self.chars)]))
        while os.path.exists(self.twd):
            self.twd = os.path.join(self.twd_base_dir, "".join([choice(ascii_letters) for _ in xrange(self.chars)]))
        
        os.mkdir(self.twd)
        if len(self.twd) > 40:
            warnings.warn("MOOG has trouble dealing with absolute paths greater than 40 characters long. Consider"
                " a shorter absolute path for your temporary working directory.")
        return self


    def execute(self, filename=None, timeout=30, shell=False, env=None):
        """ Execute a MOOG input file with a timeout after which it will be forcibly killed. """

        if filename is None:
            filename = os.path.join(self.twd, "batch.par")

        logger.info("Executing input file: {0}".format(filename))

        class Alarm(Exception):
            pass

        def alarm_handler(signum, frame):
            raise Alarm

        if env is None and len(os.path.dirname(self._executable)) > 0:
            env = {"PATH": os.path.dirname(self._executable)}

        p = Popen([os.path.basename(self._executable)], shell=shell, bufsize=2056, cwd=self.twd, stdin=PIPE, stdout=PIPE, 
            stderr=PIPE, env=env, close_fds=True)

        if timeout != -1:
            signal(SIGALRM, alarm_handler)
            alarm(timeout)
        try:
            # Stromlo clusters may need a "\n" prefixed to the input for p.communicate
            pipe_input = "\n" if -6 in self._acceptable_return_codes else ""
            pipe_input += os.path.basename(filename) + "\n"*100

            stdout, stderr = p.communicate(input=pipe_input)
            if timeout != -1:
                alarm(0)
        except Alarm:

            # process might have died before getting to this line
            # so wrap to avoid OSError: no such process
            try:
                os.kill(p.pid, SIGKILL)
            except OSError:
                pass
            return (-9, '', '')

        if p.returncode not in self._acceptable_return_codes:
            logger.warn("MOOG returned the following message (code: {0:d}:".format(p.returncode))
            logger.warn(stdout)

            raise MOOGError(stderr)
            

        return (p.returncode, stdout, stderr)


    def _cp_to_twd(self, filename):

        if os.path.dirname(filename) != self.twd:
            shutil.copy(filename, self.twd)
            filename = os.path.join(self.twd, os.path.basename(filename))

        elif not os.path.exists(filename):
            raise IOError("filename {0} does not exist".format(filename))

        return filename


    def _format_ew_input(self, measurements, comment=None):
        """
        measurments should be recarray
        """
        
        output = comment.rstrip() if comment is not None else ""
        output += "\n"

        line = "{0:10.3f} {1:9.3f} {2:8.2f} {3:6.2f}                             {4:5.1f}\n"

        # Sort all the lines first transition, then by wavelength
        measurements = sorted(measurements, key=itemgetter("species", "wavelength"))

        include_uncertainties = "u_equivalent_width" in measurements.dtype.names
        for i, measurement in enumerate(measurements):

            # TODO: Ignoring van Der Waal damping coefficients for the moment << implement if they exist!
            output += line.format(*[measurement[col] for col in ["wavelength", "species",
                "excitation_potential", "loggf", "equivalent_width"]])

            # If we have an uncertainty in equivalent width, we will propagate this to an
            # uncertainty in abundance, so we will have two lines for each measurement
            if include_uncertainties:
                additional_line_data = [measurement[col] for col in ["wavelength", "species",
                    "excitation_potential", "loggf"]]
                additional_line_data.append(measurement["equivalent_width"] \
                    + measurement["u_equivalent_width"])
                output += line.format(*additional_line_data)


        if force_loggf and np.all(measurements["loggf"] > 0):
            warnings.warn("The atomic line list contains no lines with positive oscillator "
                "strengths. MOOG will not treat these as logarithmic oscillator strengths!")

        return output
        


    def _format_abfind_input(self, model_atmosphere_filename, line_list_filename, standard_out,
        summary_out, terminal="x11", atmosphere=1, molecules=1, truedamp=1, lines=1,
        freeform=0, flux_int=0, damping=0, units=0):

        output = """
        abfind
        terminal '{terminal}'
        standard_out '{standard_out}'
        summary_out '{summary_out}'
        model_in '{model_atmosphere_filename}'
        lines_in '{line_list_filename}'
        atmosphere {atmosphere}
        molecules {molecules}
        lines {lines}
        freeform {freeform}
        flux/int {flux_int}
        damping {damping}
        plot 0
        """.format(**locals())
        
        return dedent(output).lstrip()


    def _parse_abfind_summary_output(self, filename):
        """ Reads the summary output filename after MOOG's `abfind` has been
        called and returns a numpy record array """

        with open(filename, "r") as fp:
            output = fp.readlines()

        data = []
        columns = ("wavelength", "species", "excitation_potential", "loggf", "equivalent_width",
            "abundance")

        for i, line in enumerate(output):
            if line.startswith("Abundance Results for Species "):
                element, ionization = line.split()[4:6]
                current_species = element_to_species("{0} {1}".format(element, ionization))
                
                # Check if we already had this species. If so then MOOG has run >1 iteration.
                if len(data) > 0:
                    exists = np.where(np.array(data)[:, 1] == current_species)

                    if len(exists[0]) > 0:
                        logger.debug("Detecting more than one iteration from MOOG")
                        data = list(np.delete(np.array(data), exists, axis=0))
                continue

            elif re.match("^   [0-9]", line):
                line_data = map(float, line.split())
                # Delete the logRW column
                del line_data[4]
                # Delete the del_avg column
                del line_data[-1] 

                # Insert a species column
                line_data.insert(1, current_species)
                data.append(line_data)
                continue

        return np.core.records.fromarrays(np.array(data).T,
            names=columns, formats=["f8"] * len(columns))


    def _format_synth_input(self, model_atmosphere_filename, line_list_filename, standard_out,
        summary_out, abundances=None, terminal="x11", atmosphere=1, molecules=1, truedamp=1,
        lines=1, freeform=0, flux_int=0, damping=0, units=0, wl_step=0.01, wl_cont=2, **kwargs):

        # Set wavelength ranges if they don't exist
        if not kwargs.has_key("wl_min") or not kwargs.has_key("wl_max"):
            wavelengths = np.loadtxt(line_list_filename, usecols=(0, ))
            kwargs.setdefault("wl_min", min(wavelengths) - wl_cont)
            kwargs.setdefault("wl_max", max(wavelengths) + wl_cont)

        if abundances is not None:

            if isinstance(abundances.values()[0], (tuple, list, np.ndarray)):
                if len(set(map(len, abundances.values()))) > 1:
                    raise ValueError("same number of abundances must be provided for all species")

                num_requested_spectra = len(abundances.values()[0])
                if num_requested_spectra > 5:
                    raise ValueError("MOOG will fall over if you request more than 5 spectra from synth driver")

            else:
                num_requested_spectra = 1

            abundance_str = "abundances    {0:.0f} {1:.0f}\n".format(len(abundances), num_requested_spectra)
            for species, species_abundances in abundances.iteritems():
                abundance_str += "          {0:.0f} {1}\n".format(species, \
                    " ".join(["{0:.3f}".format(s) for s in np.array(species_abundances).flatten()]))

        else:
            abundance_str = ""

        kwargs.update(locals())

        output = """
        synth
        terminal '{terminal}'
        standard_out '{standard_out}'
        summary_out '{summary_out}'
        model_in '{model_atmosphere_filename}'
        lines_in '{line_list_filename}'
        atmosphere {atmosphere}
        molecules {molecules}
        lines {lines}
        freeform {freeform}
        flux/int {flux_int}
        damping {damping}
        plot 0
        synlimits
          {wl_min:.2f} {wl_max:.2f} {wl_step:.4f} {wl_cont:.2f}
        plotpars 1
          {wl_min:.2f} {wl_max:.2f} 0 1
          0 0 0 1
          g 0 0 0 0 0 
        obspectrum 0
        {abundance_str}
        """.format(**kwargs)
        
        return dedent(output).strip()


    def _parse_synth_standard_output(self, filename, num_spectra):

        with open(filename, "r") as fp:
            output = fp.readlines()

        depths = []
        for i, line in enumerate(output):
            if line.startswith("SYNTHETIC SPECTRUM PARAMETERS"):

                next_line = output[i + 1].split()
                wl_min, wl_max = map(float, [next_line[2], next_line[5]])
                wl_step = float(output[i + 2].split()[-1])
                
                dispersion = np.arange(wl_min, wl_max + wl_step, wl_step)
    
            elif ': depths=' in line:
                flux_data = line[19:].rstrip()
                depths.extend(map(float, [flux_data[j:j+6] for j in xrange(0, len(flux_data), 6)]))

        if len(depths) == 0:
            raise MOOGError("no flux depths found in {0}".format(filename))

        depths = np.array(depths)
        num_pixels = len(depths)/num_spectra
        
        if len(dispersion) > num_pixels:
            logger.warn("Dispersion points ({0}) did not equal flux points ({1}) for spectrum"
                " returned by MOOG".format(len(dispersion), num_pixels))
            dispersion = dispersion[:num_pixels]

        fluxes = []
        for i in xrange(num_spectra):
            fluxes.append(1. - depths[i*num_pixels:(i+1)*num_pixels])

        return (dispersion, fluxes)


    def synth(self, atmosphere_filename, line_list_filename, parallel=False, **kwargs):

        # Prepare a synth file
        line_list_filename = self._cp_to_twd(line_list_filename)
        atmosphere_filename = self._cp_to_twd(atmosphere_filename)
        
        # Prepare the input and output filenames
        if not parallel:
            input_filename, standard_out, summary_out = [os.path.join(self.twd, filename) \
                for filename in ("batch.par", "abfind.std", "abfind.sum")]
        
        else:
            input_filename = os.path.join(self.twd, "".join([choice(ascii_letters) for _ in xrange(5)]) + ".in")
            while os.path.exists(input_filename):
                input_filename = os.path.join(self.twd, "".join([choice(ascii_letters) for _ in xrange(5)]) + ".in")

            standard_out = input_filename[:-3] + ".out"
            summary_out = os.path.join(self.twd, "abfind.sum")

        # Write the synth file
        with open(input_filename, "w") as fp:
            fp.write(self._format_synth_input(atmosphere_filename, line_list_filename, standard_out,
                summary_out, **kwargs))

        # Execute it, retrieve spectra
        result, stdout, stderr = self.execute(input_filename)

        num_spectra = len(kwargs["abundances"].values()[0]) if "abundances" in kwargs else 1
        output = self._parse_synth_standard_output(standard_out, num_spectra)

        if not parallel:
            # Remove in/out files
            map(os.remove, [input_filename, standard_out, summary_out])

        return output


    def abfind(self, model_atmosphere, line_list_filename, **kwargs):
        """ Call `abfind` in MOOG """

        model_atmosphere = self._cp_to_twd(model_atmosphere)
        line_list_filename = self._cp_to_twd(line_list_filename)

        """
        # Write the equivalent widths to file
        os.path.join(self.twd, "ews")
        with open(line_list_filename, "w") as fp:
            fp.write(self._format_ew_input(measurements, **kwargs))
        """

        # Prepare the input and output filenames
        input_filename, standard_out, summary_out = [os.path.join(self.twd, filename) \
            for filename in ("batch.par", "abfind.std", "abfind.sum")]
        
        # Write the abfind file
        with open(input_filename, "w") as fp:
            fp.write(self._format_abfind_input(line_list_filename, model_atmosphere, standard_out,
                summary_out, **kwargs))

        # Execute MOOG
        result, stdout, stderr = self.execute()

        abundances = self._parse_abfind_summary_output(summary_out)

        # Did we propagate uncertainties in equivalent width to MOOG?
        # TODO: These are one-sided 68% CIs as "uncertainties". We should really be propagating
        # the whole distribution of measured equivalent widths and rest wavelengths!
        if "u_equivalent_width" in measurements.dtype.names:

            # Create a new table with the uncertainties included
            abundances = nprcf.append_fields(abundances[::2], "u_abundance",
                abundances[1::2] - abundances[::2], usemask=False)

        return abundances


    def __exit__(self, exit_type, value, traceback):
        # Remove the temporary working directory and any files in it
        if exit_type not in (IOError, MOOGError):
            shutil.rmtree(self.twd)
        else:
            logger.info("Temporary directory {0} has been kept to allow debugging".format(self.twd))
        return False



def abundance_differences(composition_a, composition_b, tolerance=1e-2):
    """Returns a key containing the abundance differences for elements that are
    common to `composition_a` and `composition_b`. This is particularly handy
    when scaling from one Solar composition to another.

    Inputs
    ----
    composition_a : `dict`
        The initial composition where elements are represented as keys and the
        abundances are inputted as values. The keys are agnostic (strings, floats,
        ints), as long as they have the same structure as composition_b.

    composition_b : `dict`
        The second composition to compare to. This should have the same format
        as composition_a

    Returns
    ----
    scaled_composition : `dict`
        A scaled composition dictionary for elements that are common to both
        input compositions."""

    tolerance = abs(tolerance)
    if not isinstance(composition_a, dict) or not isinstance(composition_b, dict):
        raise TypeError("Chemical compositions must be dictionary types")

    common_elements = set(composition_a.keys()).intersection(composition_b.keys())

    scaled_composition = {}
    for element in common_elements:
        if np.abs(composition_a[element] - composition_b[element]) >= tolerance:
            scaled_composition[element] = composition_a[element] - composition_b[element]

    return scaled_composition
   
