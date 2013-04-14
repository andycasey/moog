
      subroutine fakeline
c******************************************************************************
c     This routine creates a representative atomic line with parameters
c     that are arbitrarily set in this routine.  Then this line is used to
c     generate a curve-of-growth for use with the 'abfind' routine.
c******************************************************************************

      implicit real*8 (a-h,o-z)
      include 'Atmos.com'
      include 'Linex.com'
      include 'Dummy.com'
      include 'Quants.com'
      include 'Factor.com'
      include 'Pstuff.com'


c*****specify the input parameters of the fake line
      wave1(1) = 5000.0
      atom1(1) = 26.0
      e(1,1)    = 2.00
      gf(1)    = 1.0e-3
      iatom = atom1(1)
      charge(1) = 1.0
      e(1,2) =  e(1,1) + 1.239d+4/wave1(1)
      amass(1) = xam(iatom)
      chi(1,1) = xchi1(iatom)
      chi(1,2) = xchi2(iatom)
      chi(1,3) = xchi3(iatom)
      if     (dampingopt .eq. 0) then
         damptype(1) = 'UNSLDc6'
      elseif (dampingopt .eq. 1) then
         damptype(1) = 'UNSLDc6'
      elseif (dampingopt .eq. 2) then
         damptype(1) = 'BLKWLc6'
      else
         damptype(1) = 'NEXTGEN'
      endif


c*****do the partition function
      call partfn (atom1(1),int(atom1(1)+0.001))


c*****now calculate the dependent quantities, such as doppler parameters,
c     damping constant, line opacity at line center
      lim1line = 1 
      lim2line = 1 
      nlines   = 1
      idump = nf2out
      nf2out = 0
      call nearly (3)


c*****setting some counting parameters and do a curve-of-growth
      lim1     = 1
      lim2     = 1
      rwlow    = -6.7
      rwhigh   = -2.5
      rwstep   =  0.15
      call curve
      nf2out = idump


c*****make an interpolated curve-of-growth at very small log gf steps 
      do i=2,ncurve-2
         k = 30*(i-2)
         l = -1
         do m=k+1,k+30
           l = l + 1
           pp       = 0.005/0.15*(l-1)
           gftab(m) = gf1(2) + 0.005*(m-1)
           rwtab(m) = w(i-1)*(-pp)*(pp-1.)*(pp-2.)/6. +
     .                w(i)*(pp*pp-1.)*(pp-2.)/2. +
     .                w(i+1)*(-pp)*(pp+1.)*(pp-2.)/2. +
     .                w(i+2)*pp*(pp*pp-1.)/6.
         enddo
      enddo
      ntabtot = m - 1


c*****exit back to the abfind driver
      return
      end




