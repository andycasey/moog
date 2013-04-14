
      subroutine linlimit 
c******************************************************************************
c     This routine marks the range of lines to be considered in a 
c     particular line calculations, depending on the type of calculation
c     (e.g. synthetic spectrum, single line curve-of-growth, etc.)
c******************************************************************************

      implicit real*8 (a-h,o-z)
      include 'Linex.com'
      include 'Pstuff.com'


c*****for single-line computations, the line rage is the whole line set;
c     this will be called from "ewfind"
      if     (mode .eq. 1) then
         lim1line = 1
         lim2line = nlines
          return
       endif


c*****for deriving abundances from single of lines of one species, delimit
c     the lines of that species as the range; called from "abfind"
      if (mode .eq. 2) then
         if (lim2line .eq. nlines) then
            if (nlines .eq. 1) then
               lim1line = 1
               lim2line = 1
               mode = -1
            else
               lim1line = -1
            endif
            return
         endif
         if (lim1line .eq. 0) then
            lim1line = 1 
         else
            lim1line = lim2line + 1
         endif
         if (lim1line .eq. nlines) then
            lim2line = lim1line
            return
         else
            oldatom = atom1(lim1line)
            do j=lim1line+1,nlines
               if (atom1(j) .ne. oldatom) then
                  lim2line = j - 1
                  return
               endif
            enddo
         endif
         lim2line = nlines
         return
      endif


c*****for spectrum synthesis, find the range of lines to include at each
c     wavelength step; called from "synspec"
      if (mode .eq. 3) then
         if (wave .gt. wave1(nlines)+delta) then
            lim1line = nlines
            lim2line = nlines
            return
         endif
         if (lim1line .eq. 0) lim1line = 1
111      do j=lim1line,nlines
            if (wave1(j) .ge. wave-delta) then
               lim1line = j
               go to 10
            endif
         enddo
         call inlines (5)
         call nearly (1)
         go to 111
10       do j=lim1line,nlines
            if (wave1(j) .gt. wave+delta) then
               lim2line = max0(1,j-1)
               return
            endif
         enddo   
         if (nlines+nstrong .eq. 2500) then
            lim2line = -1
         else
            lim2line = nlines
         endif
         return
      endif


c*****for blended line force fits to the EWs, the range is a set of
c     lines in a particular blend
      if (mode .eq. 4) then
         if (lim1line .eq. 0) lim1line = 1
         if (group(lim1line) .ne. 0.) then
            write (array,1001)
            call prinfo (10)
            write (array,1002)
            call prinfo (11)
            stop
         endif
         if (lim1line .eq. nlines) then
            lim2line = lim1line
         else
            do j=lim1line+1,nlines
               if (group(j) .ne. 1) then
                  lim2line = j - 1
                  return
               endif
            enddo
            lim2line = nlines
         endif
         return
      endif


c*****format statements
1001  format ('TROUBLE! THE FIRST LINE IN THE GROUP')
1002  format ('DOES NOT DEFINE A NEW GROUP OF LINES!  I QUIT!')
      end

