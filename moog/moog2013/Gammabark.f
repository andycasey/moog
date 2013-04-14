
      subroutine gammabark
c******************************************************************************
c     This subroutine pulls in damping factors from Barklem data
c     So far, these data have been compiled from:
c                  1. Barklem, P. S., Piskunov, N., & O'Mara, B. J. 2000, 
c                     A&ApS, 142, 467 for (mostly) neutral species
c                  2. Barklem, P. S., & Aspelund-Johansson, J. 2005, A&Ap, 
c                     435, 373 for Fe II lines with E_lower < 70000 cm-1
c******************************************************************************

      implicit real*8 (a-h,o-z)
      include 'Pstuff.com'
      include 'Atmos.com'
      include 'Linex.com'
      include 'Dampdat.com'
      data firstread/0/


c*****on first entry to this routine, read in either 'Barklem.dat' or 
c     'BarklemUV.dat', depending on the wavelength region of the linelist
      if (firstread .eq. 0) then
         if (wave1(nlines) .gt. 3000.) then
            nwant = 35
         else
            nwant = 36
         endif
         k = 1
5        read (nwant,*,end=10) wavebk(k), idbk(k), gammabk(k), 
     .                         alphabk(k)
         k = k + 1
         go to 5
10       numbark = k -1
         firstread = 1
      endif
     

c*****identify the Barklem list positions of the wavelength limits of
c     the input line list
      wavemin = 10000000.
      do j=1,nlines+nstrong
         if (wave1(j) .lt. wavemin) wavemin = wave1(j)
      enddo
      wavemax = 0.
      do j=1,nlines+nstrong
         if (wave1(j) .gt. wavemax) wavemax = wave1(j)
      enddo
      do k=1,numbark
         if (wavemin-wavebk(k) .lt. 1.0) then
            nummin = k
            go to 15
         endif
      enddo
15    do k=nummin,numbark
         if (wavebk(k)-wavemax .gt. 1.0) then
            nummax = k
            go to 25
         endif
      enddo


c*****search for Barklem data
25     do 20 j=1,nlines+nstrong
         gambark(j) = -1.
         alpbark(j) = -1.
         if (atom1(j) .lt. 100.) then 
            iatom10 = int(10.*atom1(j)+0.0001)
            do k=nummin,nummax
               waveerror = (wave1(j) - wavebk(k))/wavebk(k)
               iii = int(10.*idbk(k)+0.0001)
               if (dabs(waveerror) .lt. 5.0d-06) then
                  if (iii .eq. iatom10) then
                     gambark(j) = 10.**gammabk(k)
                     alpbark(j) = (1.-alphabk(k))/2.
                     go to 20
                  endif
               if (waveerror .gt. 5.0d-06) go to 20
               endif
            enddo
         endif
20    enddo


      return
      end




