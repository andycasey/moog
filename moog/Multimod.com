c******************************************************************************
c     this common block carries the data for population syntheses,
c     using multiple model calculations
c******************************************************************************


      real*8       gfmodtab(30,200,50), rwmodtab(30,200,50)
      real*8       weightmod(30,200), fluxmod(30,200), ewmod(200)
      real*8       radius(30), relcount(30)
      real*8       deltangf, rwlgerror
      integer      nmodcurve(30,200), modtot
      character*80 fmodinput(30), fmodoutput(30)


      common/multidata/ gfmodtab, rwmodtab,
     .                  weightmod, fluxmod, ewmod,
     .                  radius, relcount,
     .                  deltangf, rwlgerror,
     .                  nmodcurve, modtot
      common/multichar/fmodinput, fmodoutput

