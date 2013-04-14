

c******************************************************************************
c     this common block has data relating (so far) to Barklem damping
c     quantities; in the future it may be expanded
c******************************************************************************

      real*8 wavebk(10000), idbk(10000), gammabk(10000), alphabk(10000)
      real*8 wavemin, wavemax
      integer firstread, numbark, nummin, nummax

      common/dampdat/ wavebk, idbk, gammabk, alphabk,
     .                wavemin, wavemax,
     .                firstread, numbark, nummin, nummax

