!>-----------------------------------------
!!
!! Main Program
!!
!! Initialize options and memory in init_model
!! Read initial conditions in bc_init (from a restart file if requested)
!! initialize physics packages in init_physics (e.g. tiedke and thompson if used)
!! If this run is a restart run, then set start to the restart timestep
!!      in otherwords, ntimesteps is the number of BC updates from the beginning of the entire model 
!!      run, not just from the begining of this restart run
!! calculate model time in seconds based on the time between BC updates (in_dt)
!! Calculate the next model output time from current model time + output time delta (out_dt)
!!
!! Finally, loop until ntimesteps are reached updating boundary conditions and stepping the model forward
!!
!!  Author: Ethan Gutmann (gutmann@ucar.edu)
!!
!!-----------------------------------------
program icar
    use time,               only : calendar_date, date_to_mjd         ! Convert between date and modified Julian Day
    use init,               only : init_model, init_physics           ! Initialize model (not initial conditions)
    use boundary_conditions,only : bc_init,bc_update,bc_find_step     ! Boundary and initial conditions
    use data_structures          ! *_type datatypes                   ! Data-types and physical "constants"
    use output,             only : write_domain                       ! Used to output initial model state
    use time_step,          only : step                               ! Advance the model forward in time
    use string,             only : str                                ! Convert real,integer,double to string
    
    implicit none
    type(options_type) :: options
    type(domain_type)  :: domain
    type(bc_type)      :: boundary
    integer            :: i,nx,ny,start_point
    integer            :: year, month, day, hour, minute, second
    double precision   :: model_time,next_output
        
!-----------------------------------------
!  Model Initialization
!
!   initialize model including options, terrain, lat, lon data. 
    call init_model(options,domain,boundary)
    
!   set up the timeing for the model
    if (options%restart) then
        start_point=options%restart_step
    else
        start_point=bc_find_step(options)
    endif
    model_time=start_point * DBLE(options%in_dt) + options%time_zero
    domain%model_time=model_time
    next_output=model_time+options%out_dt
    call calendar_date(model_time/86400.0D+0 + 50000, year, month, day, hour, minute, second)
    domain%current_month=month
    
!   read initial conditions from the boundary file
    write(*,*) "Initializing Boundary conditions"
    call bc_init(domain, boundary, options)
    
    write(*,*) "Initializing Physics packages"
    call init_physics(options,domain)
!   update the boundary conditions for the next time step so we can integrate from one to the next
!     call bc_update(domain,boundary,options)
    
    ! write the initial state of the model (primarily useful for debugging)
    if (.not.options%restart) then
        call write_domain(domain,options,nint((model_time-options%time_zero)/options%out_dt))
    endif
!
!-----------------------------------------
!-----------------------------------------
!  Time Loop
!
!   note that a timestep here is a forcing input timestep O(1-3hr), not a physics timestep O(20-100s)
    do i=start_point,options%ntimesteps
        write(*,*) ""
        write(*,*) " ----------------------------------------------------------------------"
        write(*,*) "Timestep:", i, "  of ", options%ntimesteps
        write(*,*) "  Model time=", trim(str((model_time-options%time_zero)/3600.0,fmt="(F10.2)")) ,"hrs"
        call calendar_date(model_time/86400.0D+0 + 50000, year, month, day, hour, minute, second)
        domain%current_month=month
        write(*,'(A,i4,"/",i2.2"/"i2.2" "i2.2":"i2.2":"i2.2)') "  Date = ",year,month,day,hour,minute,second
        
!       update boundary conditions (dXdt variables) so we can integrate to the next step
        call bc_update(domain,boundary,options)
        
!       this is the meat of the model physics, run all the physics for the current time step looping over internal timesteps
        call step(domain,options,boundary,model_time,next_output)

    end do
!
!-----------------------------------------
    
end program icar

