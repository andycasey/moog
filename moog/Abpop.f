
      subroutine abpop
c******************************************************************************
c     Special abfind for Andy
c******************************************************************************

      implicit real*8 (a-h,o-z)
      include 'Atmos.com'
      include 'Linex.com'
      include 'Mol.com'
      include 'Pstuff.com'
      include 'Multimod.com'

  
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
      read (nftable,1001) array(1:80)
      write (nf7out,1002) array(1:80)
      m = 1
1     read (nftable,*,end=10) fmodinput(m), fmodoutput(m), temp, 
     .                        radius(m), relcount(m)
      m = m + 1
      if (m .le. 30) go to 1
10    modtot = m - 1


c*****open the standard output file
      nf1out = 20
      lscreen = 8
      array = 'STANDARD OUTPUT'
      nchars = 15
      call infile ('output ',nf1out,'formatted  ',0,nchars,
     .             f1out,lscreen)


c*****FIRST PASS:  For each model, for each line, create a curve-of-growth
c     finely divided in steps of 0.01 in "Ngf"
      do mmod=1,modtot


c*****read in the model atmospheres and their summary output files
         nf2out = 21
         f2out = fmodoutput(mmod)
         lscreen = 10
         array = 'SUMMARY C-O-G OUTPUT'
         nchars = 20
         call infile ('output ',nf2out,'formatted  ',0,nchars,
     .                f2out,lscreen)
         nfmodel = 30
         fmodel = fmodinput(mmod)
         array = 'THE MODEL ATMOSPHERE'
         nchars = 20
         lscreen = 12
         call infile ('input  ',nfmodel,'formatted  ',0,nchars,
     .                fmodel,lscreen)
         call inmodel
         write (nf2out,1001) moditle


c*****open and read the line list; this will internally be broken down
c     into 1-line lists for computational efficiency
         array = 'THE LINE LIST'
         nchars = 13
         nflines = 31
         lscreen = 14
         call infile ('input  ',nflines,'formatted  ',0,nchars,
     .                flines,lscreen)
         call inlines (1)
         call eqlib
         call nearly (1)


c*****define the range of lines (the whole list, in this case)
         mode = 1
         call linlimit
         if (lim1line .lt. 0) then
            call finish (0)
            return
         endif


c*****do the curves of growth; store the results
         rwlow = -6.5
         rwhigh = -3.5
         rwstep = 0.15
         do lim1=lim1line,lim2line
            lim2 = lim1
            waveold = 0.
            call curve
            if (ncurve .gt. 50) then
               nmodcurve(mmod,lim1) = 50
            else
               nmodcurve(mmod,lim1) = ncurve
            endif
            fluxmod(mmod,lim1) = flux
            lastcurve = nmodcurve(mmod,lim1)
            iatom = int(atom1(lim1)+0.00001)
            xxab = dlog10(xabund(iatom))
            weightmod(mmod,lim1) = fluxmod(mmod,lim1)*radius(mmod)**2*
     .                             relcount(mmod)
            do icurve=1,lastcurve
               gfmodtab(mmod,lim1,icurve) = gf1(icurve) + xxab
               rwmodtab(mmod,lim1,icurve) = w(icurve)
            enddo
         enddo
      enddo


c*****for just the first model atmosphere, interpolate in the curve-of-growth
c     at very small log(Ngf) steps for just the first line in the list,
c     in order to make a lookup table for later abundance iterations
      ncurve = nmodcurve(1,1)
      do i=2,ncurve-2
         k = 30*(i-2)
         l = -1
         do m=k+1,k+30
           l = l + 1
           pp       = 0.005/0.15*(l-1)
           gftab(m) = gfmodtab(1,1,2) + 0.005*(m-1)
           rwtab(m) = rwmodtab(1,1,i-1)*(-pp)*(pp-1.)*(pp-2.)/6. +
     .                rwmodtab(1,1,i)*(pp*pp-1.)*(pp-2.)/2. +
     .                rwmodtab(1,1,i+1)*(-pp)*(pp+1.)*(pp-2.)/2. +
     .                rwmodtab(1,1,i+2)*pp*(pp*pp-1.)/6.
         enddo
      enddo
      ntabtot = m - 1


c*****now consider each line at a time; use these curve-of-growth to 
c     compute a weighted <EW_calc> 
      do lim1=lim1line,lim2line
         write (nf7out,1003) atom1(lim1), wave1(lim1), e(lim1,1),
     .                       dlog10(gf(lim1))
         rwlgerror = 50.
         deltangf = 0.
15       call ewweighted
         rwlgcal = dlog10(ewmod(lim1)/wave1(lim1))
         do i=2,ntabtot
            if (rwtab(i) .gt. rwlgcal) then
               gflgcal = gftab(i-1) + (gftab(i)-gftab(i-1))*
     .                   (rwlgcal-rwtab(i-1))/(rwtab(i)-rwtab(i-1))
               go to 20
            endif
         enddo
20       rwlgobs = dlog10(width(lim1)/wave1(lim1))
         do i=2,ntabtot
            if (rwtab(i) .gt. rwlgobs) then
               gflgobs = gftab(i-1) + (gftab(i)-gftab(i-1))*
     .                   (rwlgobs-rwtab(i-1))/(rwtab(i)-rwtab(i-1))
               go to 30
            endif
         enddo
30       rwlgerror = rwlgobs - rwlgcal
         diffngf = gflgobs - gflgcal
         deltangf = deltangf + diffngf
         if (dabs(rwlgerror) .gt. 0.01) go to 15


c*****here we go for a final iteration on a line, or finish
         call ewweighted
      enddo
 

c*****format statements
1001  format (a80)
1002  format ('EQUIVALENT WIDTH ANALYSIS FOR INTEGRATED-LIGHT SPECTRA'//
     .        a80)
1003  format (/'species=',f5.1, 3x, 'lambda=', f8.2, 3x, 'EP=', f6.2,
     .        3x, 'log(gf)=', f7.2)

      end








