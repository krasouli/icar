###################################################################
# Makefile rules:
# <default> all: makes real
#			install: makes and installs real in INSTALLDIR
#			clean: removes objects and module files
#			allclean: makes clean and removes executables
#			cleanall: alias for allclean
#			tests: makes various unit tests (does not always work)
#			real: makes the primary model
#			ideal: makes an idealized version of the model (does not not always work)
# 
#	MODE = fast, debug, debugomp, debugslow, debugompslow
#
###################################################################
# Variables that need to be set by the user: 
# 
# INSTALLDIR : default = ~/bin/ 
# LIBFFT	 : location of fftw libraries		default = /usr/local/lib
# INCFFT	 : location of fftw headers			default = /usr/local/include
# LIBNETCDF	 : location of netdcdf libraries	default = compiler/machine dependant /usr/local/lib
# INCNETCDF	 : location of netcdf headers		default = compiler/machine dependant /usr/local/include
# 
# Dependencies: fftw, netcdf
#	FFTW is available here: http://www.fftw.org/
#		FFTW is a C library with fortran headers
#	netcdf is available here: http://www.unidata.ucar.edu/software/netcdf/
#		netcdf is a fortran library and must be compiled with the same fortran
#		compiler you are using to be compatible

###################################################################
#  Specify where you want the resulting executable installed
###################################################################
INSTALLDIR=~/bin/

###################################################################
#	Various compiler specific flags, may need to edit
###################################################################
# on hydro-c1:
# note on hydro-c1 /usr/local is not available on compute nodes so 
# the ifort libraries must be copied to an available directory (e.g. ~/)
# it is HIGHLY recommended that you set :
# LD_RUN_PATH=$LD_RUN_PATH:/usr/local/netcdf-4.1.3/ifort-12.0.5/lib:/home/gutmann/usr/local/lib:/usr/local/netcdf3-ifort/lib
# in your environment to point to the libraries you will need so the locations will be encoded in the 
#  compiled binary and you don't need to set LD_LIBRARY_PATH at runtime. 

########################################################################################
# These are default parameters
# They are overwritten with machine specific options below if known
########################################################################################
F90=gfortran
RM=/bin/rm
LIBFFT=/usr/local/lib
INCFFT=/usr/local/include
NCDF_PATH = /usr/local
LIBNETCDF = -L$(NCDF_PATH)/lib -lnetcdff -lnetcdf
INCNETCDF = -I$(NCDF_PATH)/include

########################################################################################
# Try to find the machine information
########################################################################################
NODENAME := $(shell uname -n)
ifeq ($(NODENAME), Patthar.local)
	NODENAME=Nomad.local
endif
ifeq ($(patsubst vpn%.ucar.edu,vpn.ucar.edu,$(NODENAME)), vpn.ucar.edu)
	NODENAME=Nomad.local
endif
# traveling laptop / home computer
ifeq ($(NODENAME), Nomad.local)
	F90=gfortran
	LIBFFT=/Users/gutmann/usr/local/lib
	INCFFT=/Users/gutmann/usr/local/include
	NCDF_PATH = /usr/local/
	LIBNETCDF = -L/usr/local/gfortran/lib -L$(NCDF_PATH)/lib -lnetcdff -lnetcdf
	INCNETCDF = -I$(NCDF_PATH)/include
endif
ifeq ($(NODENAME), dablam.rap.ucar.edu)
	F90=gfortran
	LIBFFT=/usr/local/fftw-3.3.4/lib
	INCFFT=/usr/local/fftw-3.3.4/include
	NCDF_PATH = /usr/local/netcdf
	LIBNETCDF = -L$(NCDF_PATH)/lib -lnetcdff -lnetcdf
	INCNETCDF = -I$(NCDF_PATH)/include
endif
# hydro-c1 cluster
ifeq ($(NODENAME),hydro-c1)
	F90=ifort
	NCDF_PATH = /usr/local/netcdf-4.3.0+ifort-12.1
	# NCDF_PATH = /usr/local/netcdf-4.1.3/ifort-12.0.5
	# NCDF_PATH = /home/gutmann/.usr/local/intel
	
	# F90=gfortran
	# NCDF_PATH = /usr/local/netcdf-4.3.3.1+gcc-4.7.2
	
	LIBNETCDF = -L$(NCDF_PATH)/lib -lnetcdff -lnetcdf
	INCNETCDF = -I$(NCDF_PATH)/include
	
	LIBFFT=/home/gutmann/.usr/local/lib
	INCFFT=/home/gutmann/.usr/local/include
endif
# on yellowstone:
ifeq ($(LMOD_FAMILY_COMPILER),gnu)
	F90=gfortran
	LIBFFT=/glade/u/home/gutmann/usr/local/lib
	INCFFT=/glade/u/home/gutmann/usr/local/include
	NCDF_PATH=/glade/apps/opt/netcdf/4.3.0/gnu/4.9.2
	# LIBNETCDF = $(LIB_NCAR) # when netcdf includes are setup by the yellowstone module system
	# INCNETCDF = $(INC_NCAR) 
	LIBNETCDF = -Wl,-rpath,$(NCDF_PATH)/lib -L$(NCDF_PATH)/lib -lnetcdff -lnetcdf # if using a compiler for which netcdf includes are 
	INCNETCDF = -I$(NCDF_PATH)/include # NOT setup correctly by the yellowstone module system
endif 
ifeq ($(LMOD_FAMILY_COMPILER),intel)
	F90=ifort
	LIBFFT=/glade/u/home/gutmann/usr/local/lib
	INCFFT=/glade/u/home/gutmann/usr/local/include
	NCDF_PATH=/glade/apps/opt/netcdf/4.3.0/intel/default
	LIBNETCDF = $(LIB_NCAR) #-L$(NCDF_PATH)/lib -lnetcdff -lnetcdf
	INCNETCDF = $(INC_NCAR) #-I$(NCDF_PATH)/include # netcdf includes are setup by the yellowstone module system
endif 
ifeq ($(LMOD_FAMILY_COMPILER),pgi)
	F90=pgf90
	LIBFFT=/glade/u/home/gutmann/usr/local/lib
	INCFFT=/glade/u/home/gutmann/usr/local/include
	NCDF_PATH=/glade/apps/opt/netcdf/4.3.0/pgi/default
	LIBNETCDF = -rpath $(NCDF_PATH)/lib -L$(NCDF_PATH)/lib -lnetcdff -lnetcdf # if using a compiler for which netcdf includes are 
	INCNETCDF = -I$(NCDF_PATH)/include # NOT setup correctly by the yellowstone module system
endif	

# get GIT version info
GIT_VERSION := $(shell git describe --long --dirty --all --always | sed -e's/heads\///')


########################################################################################
# 
# Once machine specific information is entered and compiler is specified, 
# now we can set up compiler specific flags (may be overwritten later if MODE is set)
# 
########################################################################################
# Consider adding vectorization "encouragement" to the compile lines
#  ifort should vectorize to SSE with -fast, may need -axAVX to add AVX
#  gcc should vectorize with -Ofast (adds -ftree-vectorize) and optionally -mavx -march=corei7-avx
#  could also add alignment in ifort with -align array64byte not sure why that isn't included in -fast

# GNU fortran
ifeq ($(F90), gfortran)
	COMP=-fopenmp -lgomp -O3 -c -ffree-line-length-none -ftree-vectorize -fimplicit-none -funroll-loops -march=native  -fno-protect-parens # -ffast-math #-flto #
	LINK=-fopenmp -lgomp -Wl,-no_compact_unwind
	PREPROC=-cpp
	MODOUTPUT=-J $(BUILD)
endif
# Intel fortran
ifeq ($(F90), ifort)
	COMP=-c -u -openmp -liomp5 -O3 -no-prec-div -xHost -ftz
	LINK= -openmp -liomp5
	PREPROC=-fpp
	MODOUTPUT=-module $(BUILD)
endif
# PGI fortran
ifeq ($(F90), pgf90)
	COMP=-O2 -mp -c -Mdclchk #-fast -O3 -mp -c -Mdclchk
	LINK=-mp
	PREPROC=-Mpreprocess
	MODOUTPUT=-module $(BUILD)
endif

# Cray fortran
ifeq ($(F90), ftn)
	COMP=-O2 -c
	LINK=
	PREPROC=-e z
	MODOUTPUT=-e m -J $(BUILD)
endif


# Various compiling options.  Set the MODE variable with "make MODE=debugslow" etc.
ifeq ($(MODE), debugslow)
	ifeq ($(F90), ifort)
		COMP= -debug -debug-parameters all -traceback -ftrapuv -g -fpe0 -c -u -check all -check noarg_temp_created -CB
		LINK=  
	endif
	ifeq ($(F90), gfortran)
		COMP= -c -g -fbounds-check -fbacktrace -finit-real=nan -ffree-line-length-none
		LINK=  
	endif
	ifeq ($(F90), pgf90)
		COMP= -c -g -Mbounds -Mlist -Minfo  -Mdclchk
		LINK=  
	endif
	ifeq ($(F90), ftn)
		COMP=-h noomp -c -g -m 0 -R abcsp
		LINK=-h noomp
		PREPROC=-e z
		MODOUTPUT=-e m -J $(BUILD)
	endif
endif
ifeq ($(MODE), debug)
	ifeq ($(F90), ifort)
		COMP= -debug -c -O1 -u -check all -check noarg_temp_created -traceback -fpe0 -fast-transcendentals -xhost
		LINK=  
	endif
	ifeq ($(F90), gfortran)
		COMP= -c -O1 -g -fbounds-check -fbacktrace -finit-real=nan -ffree-line-length-none
		LINK=  
	endif
	ifeq ($(F90), pgf90)
		COMP= -c -gopt -O1 -Mbounds -Mlist -Minfo  -Mdclchk
		LINK=  
	endif
	ifeq ($(F90), ftn)
		COMP=-O1 -h noomp -c -g
		LINK=-h noomp
		PREPROC=-e z
		MODOUTPUT=-e m -J $(BUILD)
	endif
endif
ifeq ($(MODE), debugompslow)
	ifeq ($(F90), ifort)
		# COMP= -openmp -liomp5 -debug -debug-parameters all -traceback -ftrapuv -g -fpe0 -c -u -check all -check noarg_temp_created -CB
		COMP= -openmp -liomp5 -debug -c -u	-fpe0 -traceback -check all -check noarg_temp_created -fp-stack-check
		LINK= -openmp -liomp5
	endif
	ifeq ($(F90), gfortran)
		COMP= -fopenmp -lgomp -c -g -fbounds-check -fbacktrace -finit-real=nan -ffree-line-length-none
		LINK= -fopenmp -lgomp  
	endif
	ifeq ($(F90), pgf90)
		COMP= -c -g -Mbounds -Mlist -Minfo -mp -Mdclchk
		LINK= -mp
	endif
	ifeq ($(F90), ftn)
		COMP=-c -g -m 0 -R abcsp
		LINK=
		PREPROC=-e z
		MODOUTPUT=-e m -J $(BUILD)
	endif
endif
ifeq ($(MODE), debugomp)
	ifeq ($(F90), ifort)
		COMP= -openmp -liomp5 -debug -c -O1 -u -traceback -check all -check noarg_temp_created -fpe0 -fast-transcendentals -xhost
		LINK= -openmp -liomp5
	endif
	ifeq ($(F90), gfortran)
		COMP= -fopenmp -lgomp -c -O1 -g -fbounds-check -fbacktrace -finit-real=nan -ffree-line-length-none
		LINK= -fopenmp -lgomp  
	endif
	ifeq ($(F90), pgf90)
		COMP= -c -g -O1 -Mbounds -Mlist -Minfo -mp -Mdclchk
		LINK= -mp
	endif
	ifeq ($(F90), ftn)
		COMP=-O1 -c -g
		LINK=
		PREPROC=-e z
		MODOUTPUT=-e m -J $(BUILD)
	endif
endif

PROF= 
ifeq ($(MODE), profile)
	ifeq ($(F90), ifort)
		PROF=-pg -debug inline-debug-info -shared-intel
		COMP=-c -u -openmp -liomp5 -O3 -no-prec-div -xHost -ftz #because -fast includes -static # not available in ifort <13 -align array64byte
	endif
	ifeq ($(F90), gfortran)
		PROF=-g
	endif
endif
ifeq ($(MODE), fast) # WARNING -ipo (included in -fast) takes forever for very little gain, and this may be unstable
	ifeq ($(F90), ifort)
		COMP=-c -u -openmp -liomp5 -fast -ftz #-fast-transcendentals # not available in ifort <13: -align array64byte
	endif
endif
###################################################################
###################################################################
# 
# Should not need to edit anything below this line
# 
###################################################################
###################################################################
# copy required libraries into a directory accessible on compute nodes and set LD_RUN_PATH e.g.
# export LD_RUN_PATH=$LD_RUN_PATH:/path/to/libraries/lib:/home/gutmann/usr/local/lib
LFLAGS=$(LINK) $(PROF) ${LIBNETCDF} -L${LIBFFT}
FFLAGS=$(COMP) $(PROF) ${INCNETCDF} -I${INCFFT} ${MODOUTPUT}

# Model directories
BUILD=build/
PHYS=physics/
IO=io/
MAIN=main/
UTIL=utilities/

OBJS=	$(BUILD)driver.o \
		$(BUILD)init.o \
		$(BUILD)init_options.o \
		$(BUILD)model_tracking.o \
		$(BUILD)boundary.o \
		$(BUILD)time_step.o \
		$(BUILD)output.o \
		$(BUILD)io_routines.o \
		$(BUILD)mp_driver.o \
		$(BUILD)mp_thompson.o \
		$(BUILD)mp_simple.o \
		$(BUILD)cu_driver.o \
		$(BUILD)cu_tiedtke.o \
		$(BUILD)cu_kf.o \
		$(BUILD)ra_driver.o \
		$(BUILD)ra_simple.o \
		$(BUILD)lsm_driver.o \
		$(BUILD)lsm_simple.o \
		$(BUILD)lsm_basic.o \
		$(BUILD)lsm_noahdrv.o \
		$(BUILD)lsm_noahlsm.o \
		$(BUILD)water_simple.o \
		$(BUILD)pbl_driver.o \
		$(BUILD)pbl_simple.o \
		$(BUILD)pbl_ysu.o \
		$(BUILD)advection_driver.o \
		$(BUILD)adv_mpdata.o \
		$(BUILD)advect.o \
		$(BUILD)wind.o \
		$(BUILD)linear_winds.o \
		$(BUILD)fftshift.o \
		$(BUILD)geo_reader.o \
		$(BUILD)vinterp.o \
		$(BUILD)time.o \
		$(BUILD)data_structures.o \
		$(BUILD)string.o

# 
# WINDOBJS=io_routines.o $(BUILD)data_structures.o $(BUILD)init.o tests/test_wind.o $(BUILD)wind.o $(BUILD)linear_winds.o $(BUILD)output.o $(BUILD)geo_reader.o
# 
# GEOOBJS=io_routines.o $(BUILD)data_structures.o tests/test_geo.o $(BUILD)geo_reader.o

###################################################################
#	User facing rules
###################################################################

all:icar

install:icar
	cp icar ${INSTALLDIR}

clean:
	rm $(BUILD)*.o $(BUILD)*.mod *.lst

allclean:cleanall

cleanall: clean
	rm icar fftshift_test calendar_test mpdata_test
	# geo_test wind_test #test_init

test: fftshift_test calendar_test mpdata_test #geo_test wind_test #test_init

icar:${OBJS}
	${F90} ${LFLAGS} ${OBJS} -o icar  -lm -lfftw3

###################################################################
#	test cases
###################################################################
# geo_test:${GEOOBJS}
#	${F90} ${LFLAGS} ${GEOOBJS} -o geo_test
# 
# wind_test:${WINDOBJS}
#	${F90} ${LFLAGS} ${WINDOBJS} -o wind_test -lfftw3 -lm
#
fftshift_test: $(BUILD)test_fftshift.o $(BUILD)fftshift.o
	${F90} ${LFLAGS} $(BUILD)test_fftshift.o $(BUILD)fftshift.o -o fftshift_test

calendar_test: $(BUILD)test_calendar.o $(BUILD)time.o
	${F90} ${LFLAGS} $(BUILD)test_calendar.o $(BUILD)time.o -o calendar_test

mpdata_test: $(BUILD)test_mpdata.o $(BUILD)adv_mpdata.o
	${F90} ${LFLAGS} $(BUILD)test_mpdata.o $(BUILD)adv_mpdata.o -o mpdata_test


###################################################################
#	driver code for 
###################################################################

$(BUILD)driver.o:$(MAIN)driver.f90 $(BUILD)data_structures.o $(BUILD)init.o $(BUILD)time_step.o \
					$(BUILD)output.o $(BUILD)boundary.o $(BUILD)time.o $(BUILD)string.o
	${F90} ${FFLAGS} $(MAIN)driver.f90 -o $(BUILD)driver.o


###################################################################
#	Core initial and boundary condition and time steping
###################################################################

$(BUILD)init.o:$(MAIN)init.f90 $(BUILD)data_structures.o $(BUILD)io_routines.o $(BUILD)geo_reader.o $(BUILD)vinterp.o \
					$(BUILD)mp_driver.o $(BUILD)cu_driver.o $(BUILD)pbl_driver.o $(BUILD)wind.o \
					$(BUILD)ra_driver.o $(BUILD)lsm_driver.o $(BUILD)init_options.o $(BUILD)advection_driver.o
	${F90} ${FFLAGS} $(MAIN)init.f90 -o $(BUILD)init.o

$(BUILD)boundary.o:$(MAIN)boundary.f90 $(BUILD)data_structures.o $(BUILD)io_routines.o $(BUILD)wind.o $(BUILD)geo_reader.o \
					$(BUILD)vinterp.o $(BUILD)output.o $(BUILD)linear_winds.o
	${F90} ${FFLAGS} $(MAIN)boundary.f90 -o $(BUILD)boundary.o

$(BUILD)time_step.o:$(MAIN)time_step.f90 $(BUILD)data_structures.o $(BUILD)wind.o $(BUILD)output.o \
					$(BUILD)advection_driver.o $(BUILD)ra_driver.o $(BUILD)lsm_driver.o $(BUILD)cu_driver.o \
					$(BUILD)pbl_driver.o $(BUILD)mp_driver.o $(BUILD)boundary.o
	${F90} ${FFLAGS} $(MAIN)time_step.f90 -o $(BUILD)time_step.o

$(BUILD)init_options.o:$(MAIN)init_options.f90 $(BUILD)data_structures.o  $(BUILD)io_routines.o \
					$(BUILD)model_tracking.o $(BUILD)time.o 
	${F90} ${FFLAGS} $(MAIN)init_options.f90 -o $(BUILD)init_options.o

$(BUILD)time.o:$(UTIL)time.f90
	${F90} ${FFLAGS} $(UTIL)time.f90 -o $(BUILD)time.o

$(BUILD)string.o:$(UTIL)string.f90
	${F90} ${FFLAGS} $(UTIL)string.f90 -o $(BUILD)string.o

###################################################################
#	I/O routines
###################################################################

$(BUILD)output.o:$(IO)output.f90 $(BUILD)data_structures.o $(BUILD)io_routines.o $(BUILD)time.o $(BUILD)string.o
	${F90} ${FFLAGS} -DVERSION=\"$(GIT_VERSION)\" $(PREPROC) $(IO)output.f90 -o $(BUILD)output.o

$(BUILD)io_routines.o:$(IO)io_routines.f90 $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(IO)io_routines.f90 -o $(BUILD)io_routines.o

$(BUILD)geo_reader.o:$(UTIL)geo_reader.f90 $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(UTIL)geo_reader.f90 -o $(BUILD)geo_reader.o

$(BUILD)vinterp.o: $(UTIL)vinterp.f90 $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(UTIL)vinterp.f90 -o $(BUILD)vinterp.o
	

###################################################################
#	Microphysics code
###################################################################

$(BUILD)mp_driver.o:$(PHYS)mp_driver.f90 $(BUILD)mp_thompson.o $(BUILD)mp_simple.o $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(PHYS)mp_driver.f90 -o $(BUILD)mp_driver.o

$(BUILD)mp_thompson.o:$(PHYS)mp_thompson.f90 $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(PHYS)mp_thompson.f90 -o $(BUILD)mp_thompson.o

$(BUILD)mp_simple.o:$(PHYS)mp_simple.f90 $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(PHYS)mp_simple.f90 -o $(BUILD)mp_simple.o
	
###################################################################
#	Convection code
###################################################################
$(BUILD)cu_driver.o:$(PHYS)cu_driver.f90 $(BUILD)cu_tiedtke.o $(BUILD)cu_kf.o $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(PHYS)cu_driver.f90 -o $(BUILD)cu_driver.o

$(BUILD)cu_tiedtke.o:$(PHYS)cu_tiedtke.f90
	${F90} ${FFLAGS} $(PHYS)cu_tiedtke.f90 -o $(BUILD)cu_tiedtke.o

$(BUILD)cu_kf.o:$(PHYS)cu_kf.f90
	${F90} ${FFLAGS} $(PHYS)cu_kf.f90 -o $(BUILD)cu_kf.o

###################################################################
#	Radiation code
###################################################################

$(BUILD)ra_driver.o:$(PHYS)ra_driver.f90 $(BUILD)ra_simple.o $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(PHYS)ra_driver.f90 -o $(BUILD)ra_driver.o

$(BUILD)ra_simple.o:$(PHYS)ra_simple.f90 $(BUILD)data_structures.o $(BUILD)time.o
	${F90} ${FFLAGS} $(PHYS)ra_simple.f90 -o $(BUILD)ra_simple.o
###################################################################
#	Land Surface code
###################################################################
$(BUILD)lsm_driver.o: $(PHYS)lsm_driver.f90 $(BUILD)data_structures.o $(BUILD)lsm_simple.o \
						$(BUILD)lsm_basic.o $(BUILD)lsm_noahdrv.o $(BUILD)lsm_noahlsm.o \
						$(BUILD)water_simple.o
	${F90} ${FFLAGS} $(PHYS)lsm_driver.f90 -o $(BUILD)lsm_driver.o

$(BUILD)water_simple.o: $(PHYS)water_simple.f90 $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(PHYS)water_simple.f90 -o $(BUILD)water_simple.o

$(BUILD)lsm_simple.o: $(PHYS)lsm_simple.f90 $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(PHYS)lsm_simple.f90 -o $(BUILD)lsm_simple.o

$(BUILD)lsm_basic.o: $(PHYS)lsm_basic.f90 $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(PHYS)lsm_basic.f90 -o $(BUILD)lsm_basic.o

$(BUILD)lsm_noahdrv.o: $(PHYS)lsm_noahdrv.f90 $(BUILD)lsm_noahlsm.o
	${F90} ${FFLAGS} $(PHYS)lsm_noahdrv.f90 -o $(BUILD)lsm_noahdrv.o
	
$(BUILD)lsm_noahlsm.o: $(PHYS)lsm_noahlsm.f90
	${F90} ${FFLAGS} $(PHYS)lsm_noahlsm.f90 -o $(BUILD)lsm_noahlsm.o


###################################################################
#	Planetary Boundary Layer code
###################################################################
$(BUILD)pbl_driver.o: $(PHYS)pbl_driver.f90 $(BUILD)pbl_simple.o $(BUILD)pbl_ysu.o $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(PHYS)pbl_driver.f90 -o $(BUILD)pbl_driver.o

$(BUILD)pbl_simple.o: $(PHYS)pbl_simple.f90 $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(PHYS)pbl_simple.f90 -o $(BUILD)pbl_simple.o

$(BUILD)pbl_ysu.o: $(PHYS)pbl_ysu.f90
	${F90} ${FFLAGS} $(PHYS)pbl_ysu.f90 -o $(BUILD)pbl_ysu.o


###################################################################
#	Advection related code
###################################################################
$(BUILD)advection_driver.o:$(PHYS)advection_driver.f90 $(BUILD)data_structures.o $(BUILD)advect.o $(BUILD)adv_mpdata.o
	${F90} ${FFLAGS} $(PHYS)advection_driver.f90 -o $(BUILD)advection_driver.o

$(BUILD)advect.o:$(PHYS)advect.f90 $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(PHYS)advect.f90 -o $(BUILD)advect.o

$(BUILD)adv_mpdata.o:$(PHYS)adv_mpdata.f90 $(PHYS)adv_mpdata_FCT_core.f90 $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(PHYS)adv_mpdata.f90 -o $(BUILD)adv_mpdata.o


###################################################################
#	Wind related code
###################################################################
$(BUILD)wind.o:$(PHYS)wind.f90 $(BUILD)linear_winds.o $(BUILD)data_structures.o
	${F90} ${FFLAGS} $(PHYS)wind.f90 -o $(BUILD)wind.o

$(BUILD)linear_winds.o:$(PHYS)linear_winds.f90 $(BUILD)io_routines.o $(BUILD)data_structures.o $(BUILD)output.o $(BUILD)fftshift.o
	${F90} ${FFLAGS} $(PHYS)linear_winds.f90 -o $(BUILD)linear_winds.o

$(BUILD)fftshift.o:$(UTIL)fftshift.f90
	${F90} ${FFLAGS} $(UTIL)fftshift.f90 -o $(BUILD)fftshift.o


###################################################################
#	Generic data structures, used by almost everything
###################################################################
$(BUILD)data_structures.o:$(MAIN)data_structures.f90
	${F90} ${FFLAGS} $(MAIN)data_structures.f90 -o $(BUILD)data_structures.o

###################################################################
#	Keep track of model versions for user information
###################################################################
$(BUILD)model_tracking.o:$(MAIN)model_tracking.f90
	${F90} ${FFLAGS} $(MAIN)model_tracking.f90 -o $(BUILD)model_tracking.o

###################################################################
#	Unit tests
###################################################################
$(BUILD)test_fftshift.o:$(BUILD)fftshift.o tests/test_fftshift.f90
	${F90} ${FFLAGS} tests/test_fftshift.f90 -o $(BUILD)test_fftshift.o

$(BUILD)test_calendar.o:$(BUILD)time.o tests/test_calendar.f90
	${F90} ${FFLAGS} tests/test_calendar.f90 -o $(BUILD)test_calendar.o

$(BUILD)test_mpdata.o:$(BUILD)adv_mpdata.o tests/test_mpdata.f90
	${F90} ${FFLAGS} tests/test_mpdata.f90 -o $(BUILD)test_mpdata.o


# 
# NOTE: too many changes in data structures/init have broken most of these tests, 
#		not worth fixing right now. 
#
# tests/test_$(BUILD)wind.o:tests/test_$(PHYS)wind.f90 $(BUILD)wind.o $(BUILD)linear_winds.o
#	${F90} ${FFLAGS} tests/test_$(PHYS)wind.f90 -o tests/test_$(BUILD)wind.o
# 
# tests/test_geo.o:tests/test_geo.f90 $(BUILD)geo_reader.o $(BUILD)data_structures.o
#	${F90} ${FFLAGS} tests/test_geo.f90 -o tests/test_geo.o
# 
# test_init:tests/test_$(MAIN)init.f90 $(BUILD)init.o
#	${F90} ${FFLAGS} tests/test_$(MAIN)init.f90 $(IO)io_routines.f90 $(MAIN)data_structures.f90 $(MAIN)init.f90 -o test_init

