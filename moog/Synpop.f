
      subroutine synpop
c******************************************************************************
c     Special abfind for Andy
c******************************************************************************

      implicit real*8 (a-h,o-z)
      include 'Atmos.com'
      include 'Linex.com'
      include 'Factor.com'
      include 'Mol.com'
      include 'Pstuff.com'
      include 'Multimod.com'
      real*8 tempspec(5,10000), rspec(10000)
      character*80 holdline(5,30)
      character*80 line
      character*30 char1
      character*10 char2

  
c*****read the parameter file 
      call params


c*****open the model table input file and the summary table output file;
c     read the information from the table input file
      nftable = 18
      lscreen = 4
      array = 'MODEL TABLE INPUT FILE'
      nchars = 22
      call infile ('input ',nftable,'formatted  ',0,nchars,
     .             ftable,lscreen)      
      nf7out = 24
      lscreen = 6
      array = 'MODEL TABLE OUTPUT FILE'
      nchars = 18
      call infile ('output ',nf7out,'formatted  ',0,nchars,
     .             f7out,lscreen)
      write (nf7out,1002)
      weighttot = 0.
      do m=1,30
         read (nftable,1004,end=10) char1, char2, temp, 
     .                              rad, relcount(m)
         fmodinput(m) = char1
         fmodoutput(m) = char2
         weighttot = weighttot + relcount(m)
         write (nf7out,1006) m, fmodinput(m), fmodoutput(m), temp,
     .                       rad, relcount(m)
      enddo
10    modtot = m - 1
      do m=1,modtot
         relcount(m) = relcount(m)/weighttot
      enddo
      write (nf7out,1005) modtot, weighttot, 
     .                    (m, relcount(m),m=1,modtot)
      close (unit=nf7out)


c*****open the standard output file
      nf1out = 20
      lscreen = 8
      array = 'STANDARD OUTPUT'
      nchars = 15
      call infile ('output ',nf1out,'formatted  ',0,nchars,
     .             f1out,lscreen)


c*****FIRST PASS:  For each model, compute a raw synthetic spectrum
      do mmod=1,modtot


c*****read in the model atmospheres and their summary output files
         nf2out = 21
         f2out = fmodoutput(mmod)
         lscreen = 12
         array = 'INDIVIDUAL MODEL RAW SYNTHESIS OUTPUT'
         nchars = 37
         call infile ('output ',nf2out,'formatted  ',0,nchars,
     .                f2out,lscreen)
         nfmodel = 30
         fmodel = fmodinput(mmod)
         array = 'INDIVIDUAL MODEL ATMOSPHERE'
         nchars = 27
         lscreen = 14
         call infile ('input  ',nfmodel,'formatted  ',0,nchars,
     .                fmodel,lscreen)
         call inmodel
         write (nf2out,1001) moditle


c*****open the line list file and the strong line list file
         nflines = 31
         lscreen = 16
         array = 'THE LINE LIST'
         nchars = 13
         call infile ('input  ',nflines,'formatted  ',0,nchars,
     .                flines,lscreen)
         if (dostrong .gt. 0) then
            nfslines = 32
            lscreen = 18
            array = 'THE STRONG LINE LIST'
            nchars = 20
            call infile ('input  ',nfslines,'formatted  ',0,nchars,
     .                   fslines,lscreen)
         endif


c*****do the syntheses
         ncall = 1
         if (numpecatom .eq. 0 .or. numatomsyn .eq. 0) then
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
               isorun = 1
               start = oldstart
               sstop = oldstop
               mode = 3
               call inlines (1)
               call eqlib
               call nearly (1)
               call synspec
               linprintopt = 0
            enddo
         endif
         call finish (0)
      enddo


c*****clear the mean spectrum array and the information array
      do i=1,5
         do j=1,10000
            tempspec(i,j) = 0.
         enddo
      enddo
      do i=1,5
         do j=1,30
            write (holdline(i,j),1008)
         enddo
      enddo


c*****open the file with the mean raw spectrucm      
      nf9out = 23
      lscreen = 10
      array = 'MEAN RAW SYNTHESIS OUTPUT'
      nchars = 25
      call infile ('output ',nf9out,'formatted  ',0,nchars,
     .             f9out,lscreen)


c*****read back the syntheses, compute the weighted average 
      do m=1,modtot
         newunit = 26
         open (newunit,file=fmodoutput(m))
         read (newunit,1001) line
         do j=1,numatomsyn
            lincount = 0
50          read (newunit,1001) line
            lincount = lincount + 1
            if (m .eq. 1) write (holdline(j,lincount),1001) line
            if (line(1:5) .eq. 'MODEL') then
               read (newunit,1001) line
               lincount = lincount + 1
               if (m .eq. 1) write (holdline(j,lincount),1001) line
               read (line,*) wavemod1, wavemod2, wavestep
               nw1 = int(1000.*wavemod1+0.00001)
               nw2 = int(1000.*wavemod2+0.00001)
               nws = int(1000.*wavestep+0.00001)
               nnn = (nw2-nw1)/nws + 1
               read (newunit,*) (rspec(n),n=1,nnn)
               do n=1,nnn
                  tempspec(j,n) = tempspec(j,n) + relcount(m)*rspec(n)
               enddo
            else
               go to 50
            endif
         enddo
         close (unit=newunit)
      enddo


c     write the average spectrum back to disk.
      do j=1,numatomsyn
         write (nf9out,1001) (holdline(j,l),l=1,lincount)
         write (nf9out,1003) (tempspec(j,n),n=1,nnn)
      enddo
      close (unit=nf9out)


c*****now plot the spectrum
      if (plotopt.eq.2 .and. specfileopt.gt.0) then
         nfobs = 33
         lscreen = 12
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
         nf2out = nf9out
         call pltspec (lscreen,ncall)
      endif

            pause


      stop


         


c*****format statements
1001  format (a80)
1002  format ('POPULATION SYNTHESIS FOR INTEGRATED-LIGHT SPECTRA')
1003  format (10f7.4)
1004  format (a30, 2x, a10, 3f8.0)
1005  format ('#models =', i3, 5x, 'total weight =', f7.2//
     .        ('model#', i5, 5x, 'relative weight', f8.2))
1006  format (i3, a30, a10, f8.0, 2f8.2)
1008  format (80(' '))



      end








