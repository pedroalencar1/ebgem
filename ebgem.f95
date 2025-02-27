! Entropy based gully erosion model V 1.0
! Initial incision using Watson (1986) equations 
! Detachment rate calculated by proporcionality od net shear stress
! Shear stress calculated using the Principle of Minimum Cross-Entropy
! Wall erosion by Siorchuk (1999)

prograg ebgem_v1
    implicit none
    character file1*30,file2*30,file3*30
    integer No,i,i0, io,test_depth2, j
    logical test_depth1
    real Q(1500), qi, t, n, S, Kr, tauC, rhoB, rhoW, g, Gw, NEL, ch, phi, pi, Lim
    real par1, tauA, w0, Mr, width, depth, area, flow_w, flow_d, w_step, b_step
    real dt_w(21), dt_b(21), Dr_w(21), Dr_b(21), da_w, da_b, new_area, new_depth, new_width
    real flow_a, flow_p, Rh, T0, Lb, Lw, Lr, Cfs, SFw, Tw_a, Tb_a, Tw_m, Tb_m, tau
    real points, erro_s2m, erro_s2w, erro_s2b, kw, kb, x_w, x_b, x_new, gy, fx, dfx
    real T_w(21), T_b(21), tau_w(21), tau_b(21), max_increase_depth, area_SM, width_SM
    real k1, k2, x, xa, f1, df1, Ang, lbd_w, lbd_b, Dvcr, es

    !common variables
    common /grands/ flow_w, flow_d, S, Gw, Tw_a, Tb_a, Tw_m, Tb_m, lbd_w, lbd_b, tau_w, tau_b
    common /NewtonPhi/Ch,g,rhoB,es,Phi,depth,Ang,pi

    write(*,*)'******************************************'
    write(*,*)'       Entropy-based Gully erosion        '
    write(*,*)'             model - V 1.0                '
    write(*,*)'                                          '
    write(*,*)'                                          '
    write(*,*)'       TUB - Institut fur Okologie        '
    write(*,*)'         UFC - PPGEA - Hidrosed           '
    write(*,*)'                                          '
    write(*,*)'                                          '
    write(*,*)'         Pedro Alencar, 02.2021           '
    write(*,*)'                                          '
    write(*,*)'******************************************'

!1. Load input data
   write(*,'(a)')'Insert the name of the file containing the runoff data (Discharge e Duration): ' 
   read(*,'(a30)')file1 !in the absense of measured data we sugest use the 30-min intensity
   write(*,'(a)')'Insert the name of the file containing the hillslope and soil data: '
   read(*,'(a30)')file2
   write(*,'(a)',advance='no') 'Insert the name of the output file: '
   read(*,'(a30)')file3


!
!1.1 count number of events
    open(50, file = file1, iostat=io, status='old')
    if (io/=0) stop 'Cannot open file!'
    No = 0
    do
        read(50,*,iostat=io)
        if (io/=0) exit
        No = No + 1
    end do
    write(*,*)No
    close(50)

!1.2 Read and load all discharges (30-min intensities)
    open(50,file=file1,status='old')
        do i=1, No
            read(50,*) Q(i)
        end do
    close(50)
    t = 1800. ! in seconds - I30
    open(60,file=file2, status='old')
    open(70,file=file3,status='new')

!1.3 Read parameterisation file
    read(60,*)n,S,tauC,kr,rhoB,es,nel,ch,phi,Lim
    write(*,*)'The number of Manning of the channel is....',n
    write(*,*)'The declivity of the hillslope is..........',S
    write(*,*)'The critical shear stress is...............',tauC
    write(*,*)'The rill erodibility coefficient is........',Kr
    write(*,*)'The soil Bulk density is...................',rhoB
    write(*,*)'The porosity of the soil is................',es
    write(*,*)'The depth of the nonerodible layer is......',nel
    write(*,*)'The soil cohesion is.......................',ch
    write(*,*)'The internal friction angle is.............',phi
    write(*,*)'The threshold for wall erosion is..........',Lim
    close(60)

98      format(A43, 10X, I4)
99      format(A43, 4X, F10.4)
!!!!!!!!!!!!!!! OUTPUT PREAMBLE !!!!!!!!!!!!!!!!!!!
      write(70,*)'******************************************'
      write(70,*)'       Entropy-based Gully erosion        '
      write(70,*)'             model - V 0.2                '
      write(70,*)'                                          '
      write(70,*)'       TUB - Institut fur Okologie        '
      write(70,*)'         UFC - PPGEA - Hidrosed           '
      write(70,*)'                                          '
      write(70,*)'           Pedro Alencar, 2020            '
      write(70,*)'                                          '
      write(70,*)'******************************************'
      write(70,*)' '
      write(70,99)'The number of Manning of the channel is....',n
      write(70,99)'The declivity of the hillslope is..........',S
      write(70,99)'The critical shear stress is...............',TauC
      write(70,99)'The rill erodibility coefficient is........',Kr
      write(70,99)'The soil Bulk density is...................',rhoB
      write(70,99)'The porosity of the soil is................',es
      write(70,99)'The depth of the nonerodible layer is......',nel
      write(70,99)'The soil cohesion is.......................',ch
      write(70,99)'The internal friction angle is.............',phi
      write(70,99)'The threshold for wall erosion is..........',Lim
      write(70,98)'The number of rainfall events is...........',No
      write(70,*)' '
      write(70,*)' event   discharge (m3)   depth (m)    width (m)     area (m2)    lambda_wall    lambda_bed'
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
100     format(2X,I4,4X,F10.4,4X,A12)
101     format(2X,I4,4X,F10.4,4X,F10.4,4X,F10.4,4X,F10.4,4X,A10,4X,A10)
102     format(2X,I4,4X,F10.4,4X,F10.4,4X,F10.4,4X,F10.4,4X,F10.4,4X,F10.4)

!1.4 Definition of important constants
    g = 9.7804 !m.s-2 - gravity, see extended documentation
    rhoW = 1000. !kg.m-3
    Gw = 9780.4 !N.m-3
    pi = 3.1415926536
    phi = phi*pi/180 !convert from degrees to radians

!1.5 Initialize important variables
    i = 1 !i is a counter
    depth = 0.
    area = 0.

!2. First erosion event
    do while (i .le. No)
        qi = Q(i)
        par1 = (n*qi/(S**(0.5)))**0.375 !flow parameter defined by Foster and Lane 1983
        tau = 4867*par1*S !effective shear stress by Watson (1986), used in the initial incision
        if (tau .le. tauC) then
            write(70,100) i, qi,'NO EROSION'
            i = i+1
            else

                w0 = 2.66 * (qi**0.396) * (n**0.387) * (S**(-0.16)) * (tauC**(-0.24)) !initial incision's width
                Mr = Kr * (tau - tauC) / rhoB !downward moviment rate
                depth = min(nel, Mr*1800) !lower is a function that compares two numbers  and delivers the lower one.
                i0 = i !i0 is the event that causes the inicial incision
                write(*,*)i,qi, depth, w0, tau, 'watson1'
                write(70,101)i, qi, depth, width, area, '-', '-'
!                
                exit !end the loop, the value of i is preserved!
        end if
    end do

    width = w0 !of the channel
    area = width*depth !of the channel

    i = i0+1
    !downward erosion
    do while (i.le.No)
        qi = Q(i)
        par1 = (n*qi/(S**(0.5)))**0.375
        flow_w = width
        flow_d = flow_depth(par1, flow_w)!function that calculates the depth using newton-raphson


        if (flow_d .gt. depth) then
            tau = 4867*par1*S
            w0 = 2.66 * (qi**0.396) * (n**0.387) * (S**(-0.16)) * (tauC**(-0.24)) !initial incision's width
            Mr = Kr * dim(tau, tauC) / rhoB !downward moviment rate
            depth = min(nel, depth + Mr*1800) !lower is a function that compares two numbers  and delivers the lower one.
!            i0 = i
            width = max(w0, width) !of the channel
            area = width*depth !of the channel
            write(70,101)i, qi, depth, width, area, '-', '-'
            i = i+1
        else

        call shear_const


        call calib_ldb
        write(*,*) i,Tw_a, Tb_a, Tw_m, Tb_m, lbd_w, lbd_b !###########################
        w_step = flow_d/20 !shear step on the wall
        b_step = flow_w/40 !shear step on the bed. the shear stress in computed on half the section
        call dist_shear
        test_depth1 = (depth .lt. nel) test if the erosion reached the non-erosive layer
        test_depth2 = test_depth1

        j = 1
        do while (j .le. 21) !calculate the available shear stress
            dt_w(j) =  dim(tau_w(j), tauC) 
            dt_b(j) =  dim(tau_b(j), tauC)
            !dim(X,Y) returns the difference X-Y if the result is positive; otherwise returns zero.


            j = j+1
        end do

        Dr_w = Kr*dt_w
        Dr_b = Kr*dt_b
        max_increase_depth = Dr_b(21)*1800/rhoB

        da_w = w_step*sum(Dr_w)*1800/rhoB !D_r * \delta t / \rho_b ; \delta t is fixed at 1800 seconds 
        da_b = b_step*sum(Dr_b)*1800/rhoB * test_depth2

        new_area = area + da_w + da_b
        new_depth = depth + max_increase_depth
        new_depth = min(new_depth, NEL)
        new_width = new_area/new_depth

        width = new_width
        depth = new_depth
        area = new_area
        write(*,*)i, qi, flow_w, flow_d, width, depth, area, 'entropy'     !#######################
        write(70,102)i, qi, depth, width, area, lbd_w, lbd_b
        i = i+1
        end if
    end do

if (area.gt.Lim) then
    Dvcr = (2.*ch*cos(phi)/(g*rhoB))/(sin(0.5*(phi+pi/2.)))**2.
    if  (depth .gt. Dvcr) then
        CALL Newton_PHI
        width_SM = width +2.*depth/tan(Ang)
        area = depth*(width+width_SM)/2.
        write(70,102) 9999, qi, depth, width_SM, area, -999., -999.
        write(70,*)''
        write(70,*)''
        write(70,*)'**ATENCION: The eroded channel has wall erosion (Sidorchuk, 1999)'
        write(70,*)'-------- Width displayed in the last line (9999) is the top with!'
        write(70,*)''

    end if
end if


!Declaration of functions
contains
!F1. function to select the lower value (substituted by function min)
function lower(a1,b1)
    real a1, b1, lower
    if (a1.le.b1) then
        lower = a1
        else
            lower = b1
    end if
end function lower

!F2. function to calculate flow depth using manning equation and newton-raphson optimisation method
function flow_depth(a2,b2)
    real a2, b2, flow_depth, erro2, erro_M2, f2, df2, x2, xn2
    erro_M2 = 0.0001

    x2 = 0.01
    erro2 = 1000.
    do while (erro2 .gt. erro_M2)
        f2 = b2**5 * x2**5
        f2 = f2/(b2 + 2*x2)**2 - a2**8

        df2 = (b2**5)*(x2**4)*(5*b2 + 6*x2)
        df2 = df2/((b2+ 2*x2)**3)

        xn2 = x2 - f2/df2
        erro2 = abs(xn2-x2)
        x2 = xn2
    end do

    flow_depth = x2

  end function flow_depth

end program


!subroutines

!S1. Subroutine to calculate the shear stress parameters (max and avg) by Knight 1994
subroutine shear_const
  implicit none
  real flow_w, flow_d, flow_a, flow_p, Rh, T0, S, Gw, Lb, Lw, Lr, Csf, Sfw
  real Tw_a, Tb_a, Tw_m, Tb_m

common /grands/ flow_w, flow_d, S, Gw, Tw_a, Tb_a, Tw_m, Tb_m

  flow_a = flow_w*flow_d
  flow_p = flow_w + 2.*flow_d

  Rh = flow_a/flow_p
  T0 = Gw*S*Rh

  Lb = flow_w/2.
  Lw = flow_d

  !1.1 Calculating shear stress parameters based on Knight and Sterling (2000)
  Lr = Lb/Lw

  if (Lr .lt. 4.374) then
        Csf = 1.
        else
            Csf = 0.6603*(Lr**0.28125)
  end if

  Sfw = -3.23*log10(Lr/1.38 + 1) + 4.6052
  Sfw = 0.01*Csf*exp(Sfw)

  Tw_a = T0 * Sfw * (1+Lr)
  Tb_a = T0 * (1-Sfw) * (1 + 1/Lr)
  Tw_m = T0 * Sfw * 2.0372 * (Lr**0.7108)
  Tb_m = T0 * (1-Sfw) * 2.1697 * (Lr**(-0.3287))
end subroutine

!S2. Subroutine to calibrate the lagrange multipliers to assess shear stress in open channels' boundaries
subroutine calib_ldb

!References - Sterling and Knight (2002)
!           - Bonakdari et al. (2014)
!           - Nocedal and Wright (2006)
  implicit none
  integer cont1w, cont1b
  real Tw_a, Tb_a, Tw_m, Tb_m, lbd_w, lbd_b
  real Tr_w, Tr_b, erro_s1m, erro_s1w, erro_s1b, xs1, xs1_n,xs1s, xs1s_n
  real fp, dfp,lbd1_w, lbd1_b
  real flow_w, flow_d, S, Gw, tau_w, tau_b
  common /grands/ flow_w, flow_d, S, Gw, Tw_a, Tb_a, Tw_m, Tb_m, lbd_w, lbd_b, tau_w, tau_b


Tr_b = min(0.99,Tb_a/Tb_m) !For a Tr equal or larger than 1 there is no solution. 
Tr_w = min(0.99,Tw_a/Tw_m)

erro_s1m = 1E-5 !Defines precision of approximation

!Sterling's routine was removed
! 2. Calculates POMCE's lambdas

        !2.1 Calibrating lambda for the wall

        if (Tr_w .lt. 0.97) then !check if it is possible a direct solution

            cont1w = 0
            xs1 = -10
            erro_s1w = 1000.0
            do while(erro_s1w .gt. erro_s1m)
                fp = exp(xs1) - xs1 - 1.
                fp = 2/xs1 - xs1/fp - Tr_w

                dfp = (exp(xs1) - xs1 - 1)
                dfp = (xs1*exp(xs1) - xs1)/dfp**2 - 2/(xs1**2) - 1/dfp

                xs1_n = xs1 - fp/dfp     !Newton-Raphson method

                erro_s1w = abs(xs1 - xs1_n)
                xs1 = xs1_n
                cont1w = cont1w+1
            end do
            lbd1_w = xs1

            else !for indirect solution
                xs1 = ((Tr_w + 2.)**2) - 8.
                xs1 = (Tr_w - 2) - sqrt(xs1)
                xs1 = xs1/(2 - 2*Tr_w)

                erro_s1w = -1
                cont1w = 1
                lbd1_w = xs1
        end if

        !2.2 Calibrating lambda for the bed
        if (Tr_b .lt. 0.97) then
            cont1b = 0
            xs1= -10 !initial guess
            erro_s1b = 1000.0

            do while(erro_s1b .gt. erro_s1m)
                fp = exp(xs1) - xs1 - 1.
                fp = 2/xs1 - xs1/fp - Tr_b

                dfp = (exp(xs1) - xs1 - 1)
                dfp = (xs1*exp(xs1) - xs1)/dfp**2 - 2/(xs1**2) - 1/dfp

                xs1_n = xs1 - fp/dfp     !m�todo de newton

                erro_s1b = abs(xs1 - xs1_n)
                xs1 = xs1_n

                cont1b = cont1b+1
            end do
            lbd1_b = xs1

            else !for indirect solution
                xs1 = ((Tr_b + 2.)**2) - 8.
                xs1 = (Tr_b - 2) - sqrt(xs1)
                xs1 = xs1/(2 - 2*Tr_b)

                erro_s1b = -1
                cont1b = 1
                lbd1_b = xs1
        end if

   lbd_w = lbd1_w
   lbd_b = lbd1_b

end subroutine

!S3. Subroutine to distribute the shear stress
subroutine dist_shear
  implicit none
  integer points, kw, kb
  real lbd_w, lbd_b, T_w(21), T_b(21), tau_w(21), tau_b(21), Tw_m, Tb_m !shear stress variables
  real gy, x_w, x_b, x_new, fx, dfx, erro_s2m, erro_s2w, erro_s2b, frac
  real flow_w, flow_d, S, Gw, Tw_a, Tb_a
  common /grands/ flow_w, flow_d, S, Gw, Tw_a, Tb_a, Tw_m, Tb_m, lbd_w, lbd_b, tau_w, tau_b

  points = 21 !number of points for calculation of shear stress in each sector
  erro_s2m = 1E-5 !for calibration of T in the PoMCE method

!1. distribution on the wall
    if (lbd_w .gt. -38) then
!        write(*,*)'here'

        kw = 1
        do while (kw .le. points)
            frac = (kw*1.)/(points*1.) !convert from integer to real
            gy = 1. - exp(-lbd_w) * (lbd_w + 1.)
            gy = 1. - gy * frac
            erro_s2w = 1000.
            x_w = 0.9
            do while (erro_s2w .gt. erro_s2m)
                fx = exp(-lbd_w * x_w) * (lbd_w * x_w + 1.) - gy
                dfx = -1. * (lbd_w**2) * x_w * exp(-lbd_w * x_w)
                x_new = x_w - fx/dfx
                erro_s2w = abs(x_new - x_w)
                x_w = x_new
            end do
            T_w(kw) = x_w

            kw = kw + 1
        end do
        else 

        kw = 1
            do while (kw .le. points)
            frac = (kw*1.)/(points*1.)
            gy = log(-lbd_w*frac) - lbd_w
            erro_s2w = 1000.
            x_w = 0.9
                do while (erro_s2w .gt. erro_s2m)
                    fx = log(-lbd_w*x_w) - lbd_w*x_w - gy
                    dfx = 1/x_w - lbd_w
                    x_new = x_w - fx/dfx
                    erro_s2w = abs(x_new - x_w)
                    x_w = x_new
                end do
                T_w(kw) = x_w
                kw = kw + 1
            end do
    end if


    !3.1 Shear stress distribution in the bed
    if (lbd_b .gt. -38) then
        kb = 1
!        cont2 = 0
        do while (kb .le. points)
            frac = (kb*1.)/(points*1.)
            gy = 1. - exp(-lbd_b) * (lbd_b + 1.)
            gy = 1. - gy * frac
            erro_s2b = 1000.
            x_b = 0.9
            do while (erro_s2b .gt. erro_s2m)
                fx = exp(-lbd_b * x_b) * (lbd_b * x_b + 1.) - gy
                dfx = -1. * (lbd_b**2) * x_b * exp(-lbd_b * x_b)
                x_new = x_b - fx/dfx
                erro_s2b = abs(x_new - x_b)
                x_b = x_new
            end do
            T_b(kb) = x_b
            kb = kb + 1
        end do

        else !lbd_b <= -38
            do while (kb .le. points)
                frac = (kb*1.)/(points*1.)
                gy = log(-lbd_b*frac) - lbd_b
                erro_s2b = 1000.
                x_b = 0.9
                do while (erro_s2b .gt. erro_s2m)
                    fx = log(-lbd_b*x_b) - lbd_b*x_b - gy
                    dfx = 1/x_b - lbd_b

                    x_new = x_b - fx/dfx
                    erro_s2b = abs(x_new - x_b)
                    x_b = x_new
                end do
                T_b(kb) = x_b
                kb = kb + 1

            end do
        end if

        tau_w = T_w*Tw_m
        tau_b = T_b*Tb_m
end subroutine

!S4. Subroutine to calculate wall stable angle
subroutine Newton_PHI
    implicit none
    integer i
    real k1,k2,f1,df1,x,xa,erro,Ch,g,rhoB,es,Pa,Phi,depth,Ang,pi
    COMMON /NewtonPhi/Ch,g,rhoB,es,Phi,depth,Ang,pi

    i=0
    k1 = Ch/(g*rhoB*depth)
    k2 = tan(Phi)*(rhoB - es*1000.)/1000.

    erro=1000000.
    x = pi/4.
        do while (erro.gt.0.00001)

        f1 = k2*(cos(x))**2 - sin(2*x)/2. - k1
        df1 = -2*k2*cos(x) - cos(2*x)

        xa = x - f1/df1
        erro = abs(x-xa)
        x=xa
        i=i+1

    end do
Ang = x
end subroutine


!Description of variables:
!All units in SI!
!
!integer
!No = Number of events
!i = general counter of evetns (first loop layer)
!j = specific counter of events (second loop layer)
!i0 = event that causes initial incision
!test_depth2 = auxiliar variable to test if depth > nel
!
!logical
!test_depth1 = auxiliar variable to test if depth > nel
!
!real - general variables
!Q(i) = peak discharge (m3/s) > assumed equal to the I30 of the rainfall event - vector
!q = event peak discharge (m3/s)
!t = event duration - fixed at 30 minutes > t = 1800. (Alencar et al, 2019 - HESS)
!n = Maner coefficient > see data in Chow (1959) - Table5-6 page 110
!S = Slope in m/m
!Kr = Rill erodibility (s/m) > see equation from WEPP model (Flanagan 1995) and Alberts 1989
!tauC = Critical shear stress (Pa) > see equation from WEPP model (Flanagan 1995) and Alberts 1989
!rhoB = Bulk density (kg/m3)
!rhoW = Density of water (1000 kg/m3)
!g = gravity acceleration > g = 9.7804 m/s2 > from WGS84 model - g = g45 - 0.5(g90-g0)*cos(2*Lat) 
![g0 = 9.780; g45 = 9.806; g90 = 9.832; Lat = 5�]

!Gw = Specific weight of water > Da*g
!NEL = depth of the Non-Erodible Layer (m) > obtained from measurements
!ch = soil cohesion (Pa)
!phi = internal friction angle (in degrees)
!pi = 3.1415926536
!
!real - event's variables
!par1 = flow parameter = (n Q/S^0.5)^0.375
!tauA = event's average shear stress (Pa) - used on the first incision, in the watson equations
!w0 = width of initial incision (in meters -- watson equations)
!Mr = downward movement rate (m.s-1)
!width = channel width (m)
!depth = channel depth (m)
!area = channel area (m2)
!flow_w = flow width (m)
!flow_d = flow depth (m)
!w_step, b_step = length of the resolution for the calculation of shear stress; by defaut, 
!the section is divided in 80 points.

!dt_w, dt_b = shear stress distributions (vector)
!Dr_w, Dr_b = detachment rate (vectors)
!da_w, da_b = total displaced area (eroded area) due to the detachement rate.
!new_area, new_depth, new_width = geometric properties of the altered (eroded) section. 
!Equations keep rectangular geometry.

!max_increase_depth = test for maximum depth
!area_SM, width_SM = variables if the Sidorchuk model subroutine is triggered
!
!
!variables in subroutine *shear_const*
!flow_a = flow area (m2)
!flow_p = flow wet perimeter (m)
!Rh = hydraulic radius (m)
!T0 = hydraulic average shear stress = g*rhoW*S*Rh (Pa)
!Lb = bed length (m)
!Lw = wall lengh (m)
!Lr = Length ratio (-)
!Cfs, SFw = auxiliar variables (Knight 2000)
!Tw_a = average shear stress on the wall (Pa)
!Tb_a = average shear stress on the bed (Pa)
!Tw_m = max shear stress on the wall (Pa)
!Tb_m = max shear stress on the bed (Pa)
!
!variables in subroutine *calib_lbd*
!Tr_b = shear stress ratio a/m for the bed
!Tr_w = shear stress ratio a/m for the wall
!erro_s1m, erro_s1w, erro_s1b = errors test and max
!cont1w, cont1b = counters
!xs1, xs1_n = variable (lbd1)
!fp, dfp = calibration equations (from pomce)
!lbd1_w, lbd1_b = auxiliar lbds
!lbd_w, lbd_b = calibrated lambdas
!
!variables in subroutine *dist_shear*
!points = number of points on the wall and (half-) bed where the shear stress will be calculated
!erro_s2m, erro_s2w, erro_s2b = errors test and max
!kw, kb = position control
!x_w, x_b, x_new, gy, fx, dfx
!T_w, T_b = auxiliar (intern) vectors
!tau_w, tau_b = vectors of shear stress (length by defaut = 21; extern)
!
!variables in subroutine *Newton_PHI*
!i = counter
!k1, k2 = auxiliars
!x, xa, f1, df1 = newton variables and functions
!Ang = anglw of stability
!
!
!
!auxiliars
!a1, b1, lower =  in funcion *lower*
!a2, b2, flow_depth2, erro2, erro_M2, f2, df2, x2, xn2 = in function *flow_depth*
