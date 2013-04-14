
      subroutine synth                   
c******************************************************************************
c     This program synthesizes a section of spectrum and compares it
c     to an observation file.
c******************************************************************************

      implicit real*8 (a-h,o-z)
      include 'Atmos.com'
      include 'Factor.com'
      include 'Mol.com'
      include 'Linex.com'
      include 'Pstuff.com'
      include 'Dummy.com'


c*****examine the parameter file
      call params


c*****open the files for: standard output, raw spectrum depths, smoothed 
c     spectra, and (if desired) IRAF-style smoothed spectra
      nf1out = 20     
      lscreen = 4
      array = 'STANDARD OUTPUT'
      nchars = 15
      call infile ('output ',nf1out,'formatted  ',0,nchars,
     .             f1out,lscreen)
      nf2out = 21               
      lscreen = lscreen + 2
      array = 'RAW SYNTHESIS OUTPUT'
      nchars = 20
      call infile ('output ',nf2out,'formatted  ',0,nchars,
     .             f2out,lscreen)
      if (plotopt .ne. 0) then
         nf3out = 22               
         lscreen = lscreen + 2
         array = 'SMOOTHED SYNTHESES OUTPUT'
         nchars = 25
         call infile ('output ',nf3out,'formatted  ',0,nchars,
     .                f3out,lscreen)
         if (f5out .ne. 'optional_output_file') then
            nf5out = 26
            lscreen = lscreen + 2
            array = 'POSTSCRIPT PLOT OUTPUT'
            nchars = 22
            call infile ('output ',nf5out,'formatted  ',0,nchars,
     .                   f5out,lscreen)
         endif
      endif
      if (iraf .ne. 0) then
         nf4out = 23               
         lscreen = lscreen + 2
         array = 'IRAF ("rtext") OUTPUT'
         nchars = 24
         call infile ('output ',nf4out,'formatted  ',0,nchars,
     .                f4out,lscreen)
      endif


c*****open and read the model atmosphere file
      nfmodel = 30
      lscreen = lscreen + 2
      array = 'THE MODEL ATMOSPHERE'
      nchars = 20
      call infile ('input  ',nfmodel,'formatted  ',0,nchars,
     .             fmodel,lscreen)
      call inmodel


c*****open the line list file and the strong line list file
      nflines = 31
      lscreen = lscreen + 2
      array = 'THE LINE LIST'
      nchars = 13
      call infile ('input  ',nflines,'formatted  ',0,nchars,
     .              flines,lscreen)
      if (dostrong .gt. 0) then
         nfslines = 32
         lscreen = lscreen + 2
         array = 'THE STRONG LINE LIST'
         nchars = 20
         call infile ('input  ',nfslines,'formatted  ',0,nchars,
     .                 fslines,lscreen)
      endif
      

c*****do the syntheses
      ncall = 1
10    if (numpecatom .eq. 0 .or. numatomsyn .eq. 0) then
         isynth = 1
         isorun = 1
         nlines = 0
         mode = 3
         call inlines (1)
         call eqlib
         call nearly (1)
         call synspec
      else
         do n=1,numatomsyn
            isynth = n
            isorun = n
            start = oldstart
            sstop = oldstop
            mode = 3
            call inlines (1)
              molopt = 2
            call eqlib
            call nearly (1)
            call synspec
            linprintopt = 0
         enddo
      endif
         

c*****now plot the spectrum
20    if (plotopt.eq.2 .and. specfileopt.gt.0) then
         nfobs = 33               
         lscreen = lscreen + 2
         array = 'THE OBSERVED SPECTRUM'
         nchars = 21
         if (specfileopt.eq.1 .or. specfileopt.eq.3) then
            call infile ('input  ',nfobs,'unformatted',2880,nchars,
     .                   fobs,lscreen)
         else
            call infile ('input  ',nfobs,'formatted  ',0,nchars,
     .                   fobs,lscreen)
         endif
      endif
      if (plotopt .ne. 0) then
         call pltspec (lscreen,ncall)
      endif


c*****if the syntheses need to be redone: first rewind the output files,
c     then close/reopen line list(s), then rewrite model atmosphere output
      if (choice .eq. 'n') then
         call chabund
         if (choice .eq. 'x') go to 20
         rewind nf1out
         rewind nf2out
         if (nflines .ne. 0) then
            close (unit=nflines)
            open (unit=nflines,file=flines,access='sequential',
     .            form='formatted',blank='null',status='old',
     .            iostat=jstat,err=10)
         endif
         if (nfslines .ne. 0) then
            close (unit=nfslines)
            open (unit=nfslines,file=fslines,access='sequential',
     .            form='formatted',blank='null',status='old',
     .            iostat=jstat,err=10)
         endif
         if (plotopt .ne. 0) then
            rewind nf3out
         endif
         write (nf1out,1002) modtype
         if (modprintopt .ge. 1) then
            if (modtype .eq. 'begn      ' .or.
     .          modtype .eq. 'BEGN      ') write (nf1out,1003)
            write (nf1out,1102) moditle
            do i=1,ntau
               dummy1(i) = dlog10(pgas(i))
               dummy2(i) = dlog10(ne(i)*1.38054d-16*t(i))
            enddo
            write (nf1out,1103) wavref,(i,xref(i),tauref(i),t(i),
     .                          dummy1(i), pgas(i),dummy2(i),ne(i),
     .                          vturb(i),i=1,ntau)
            write (nf1out,1104)
            do i=1,95
               dummy1(i) = dlog10(xabund(i)) + 12.0
            enddo
            write (nf1out,1105) (names(i),i,dummy1(i),i=1,95)
            write (nf1out,1106) modprintopt, molopt, linprintopt, 
     .                          fluxintopt
            write (nf1out,1107) (kapref(i),i=1,ntau)
         endif
         linprintopt = linprintalt
         ncall = 2
         choice = '1'
         go to 10


c*****otherwise end the code gracefully
      else
         call finish (0)
      endif


c*****format statements
1002  format (13('-'),'MOOG OUTPUT FILE',10('-'),
     .        '(MOOG version from 23/04/07)',13('-')//
     .        'THE MODEL TYPE: ',a10)
1003  format ('   The Rosseland opacities and optical depths have ',
     .        'been read in')
1102  format (/'MODEL ATMOSPHERE HEADER:'/a80/)
1103  format ('INPUT ATMOSPHERE QUANTITIES',10x,
     .        '(reference wavelength =',f10.2,')'/3x,'i',2x,'xref',3x,
     .        'tauref',7x,'T',6x,'logPg',4x,'Pgas',6x,'logPe',
     .        5x,'Ne',9x,'Vturb'/
     .        (i4,0pf6.2,1pd11.4,0pf9.1,f8.3,1pd11.4,0pf8.3,
     .        1pd11.4,d11.2))
1104  format (/'INPUT ABUNDANCES: (log10 number densities, log H=12)'/
     .       '      Default solar abundances: Anders and Grevesse 1989')
1105  format (5(3x,a2,'(',i2,')=',f5.2))
1106  format (/'OPTIONS: atmosphere = ',i1,5x,'molecules  = ',i1/
     .        '         lines      = ',i1,5x,'flux/int   = ',i1)
1107  format (/'KAPREF ARRAY:'/(6(1pd12.4)))



      end 





