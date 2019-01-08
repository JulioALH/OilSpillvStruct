% This software (OilSpill_vStruct) was developed by Julio Antonio Lara
% Hernandez (lara.hernandez.julio.a@gmail.com) and Dr. Jorge Zavala Hidalgo
% (jzavala@atmosfera.unam.mx). An analogous version implemented in 
% object-oriented programming was developed by Olmo Zavala-Hidalgo, and an 
% analogous version implemented in Julia was developed by Andrea Isabel
% Anguiano. The free use of this software is allowed as long as the
% corresponding credit is given to the developers.
function [last_ID,Particles,PartsPerTS] =...
    releaseParticles(day_abs,ts,spillTiming,spillLocation,DailySpill,first_time,...
    PartsPerTS,Particles,last_ID,Params,LagrTimeStep)
    % This function creates particles each time step 

    % day_abs       --> Current day in the simulation (integer value starting at 1 )
    % ts            --> Current time step 
    % spillTiming   --> Structure with the time information (start date, end date, spill date, etc. )
    % spillLocation --> Structure with the location and depth information (depths, lat, lon, etc.)
    % DailySpill    --> Structure with the oil information (particles per day, surface, subsurface, burned, evaporated, etc.)
    % first_time    --> Bool variable that indicates if its the first time we enter in this function
    % PartsPerTS    --> Number of particles per time step (TODO verify it is correct)
    % Particles     --> Structure of arrays with the information of ALL the particles
    % last_ID       --> Pointer to the last particle that was created
    % Params        --> Structure with main parameters of the model (RK, domainLimits, particlesPerBarrel, etc.)
    % LagrTimeStep  --> Structure with information about the lagratian time steps (in hours, in seconds, etc.)

% We initialize the fist and last dates and the particles array
if first_time
    firstSpillDay_Idx = find(DailySpill.SerialDates == spillTiming.startDay_serial);
    finalSpillDay_Idx = find(DailySpill.SerialDates == spillTiming.lastSpillDay_serial);
    surf_Idx = find(spillLocation.Depths == 0);
    % Obtain total particles per timestep in the surface for all the dates
    if isempty(surf_Idx)
        PartsPerTS.dailySurface = 0;
    else
        PartsPerTS.dailySurface = DailySpill.Surface(firstSpillDay_Idx:finalSpillDay_Idx)/LagrTimeStep.PerDay;
    end
    subs_Idx = find(spillLocation.Depths > 0);
    % Obtain total particles per timestep in the subsurface for all the dates
    if isempty(subs_Idx)
        PartsPerTS.dailySubsurf = 0;
    else
        tot_fraction = sum(Params.subsurfaceFractions(1:numel(subs_Idx)));
        PartsPerTS.dailySubsurf = DailySpill.Subsurf(firstSpillDay_Idx:finalSpillDay_Idx)*tot_fraction/LagrTimeStep.PerDay;
    end
    PartsPerTS.dailyTotal = PartsPerTS.dailySurface + PartsPerTS.dailySubsurf;
    % As percentages
    PartsPerTS.dailySurfaceBTWtotal = PartsPerTS.dailySurface./PartsPerTS.dailyTotal;
    PartsPerTS.dailySubsurfBTWtotal = PartsPerTS.dailySubsurf./PartsPerTS.dailyTotal;
    % Sets the thresholds (used to create particles statistically) by depth
    PartsPerTS.dailyDepthThresholds = nan(spillTiming.spillDays,spillLocation.n_Depths);
    if ~isempty(surf_Idx)
      PartsPerTS.dailyDepthThresholds(:,surf_Idx) = PartsPerTS.dailySurfaceBTWtotal;
    end
    count_cicle = 0;
    % TODO review and comment this part
    for subsurf_cicle = subs_Idx
        count_cicle = count_cicle + 1;
        PartsPerTS.dailyDepthThresholds(:,subsurf_cicle) = PartsPerTS.dailySubsurfBTWtotal*Params.subsurfaceFractions(count_cicle);
    end
    PartsPerTS.dailyDepthThresholds = cumsum(PartsPerTS.dailyDepthThresholds,2);
    
    % Computes the final number of particles for each time step
    PartsPerTS.finalNumPart = nan(LagrTimeStep.PerDay,spillTiming.spillDays);
    for day_cicle = 1 : spillTiming.spillDays
        for TS_cicle = 1 : LagrTimeStep.PerDay
            PartsPerTS.finalNumPart(TS_cicle,day_cicle) = roundStat(PartsPerTS.dailyTotal(day_cicle));
        end
    end
    PartsPerTS.finalParticlesSum = sum(sum(PartsPerTS.finalNumPart));
    PartsPerTS.finalParticlesSumAllSites = PartsPerTS.finalParticlesSum * spillLocation.nSites; % ADDED
    
    Particles.Age_days      = nan(1,PartsPerTS.finalParticlesSumAllSites);
    Particles.Status        = Particles.Age_days;
    Particles.Depth         = Particles.Age_days;
    Particles.Comp          = Particles.Age_days;
    Particles.Lat           = Particles.Age_days;
    Particles.Lon           = Particles.Age_days;
    Particles.Site          = Particles.Age_days;
    Particles.ID            = Particles.Age_days;
    Particles.birthDate     = Particles.Age_days;
end

PartsPerDepth_threshold = PartsPerTS.dailyDepthThresholds(day_abs,:);

PartsPerTimeStep = PartsPerTS.finalNumPart(ts,day_abs);
PartsPerTimeStepAllsites = PartsPerTimeStep * spillLocation.nSites; % ADDED

NewAges       = zeros(spillLocation.nSites,PartsPerTimeStep);
NewBirthDates = NewAges + spillTiming.startDay_serial + day_abs - 1 + LagrTimeStep.InDays * (ts-1);
NewStatus     = ones(spillLocation.nSites,PartsPerTimeStep);
NewDepths     = nan(spillLocation.nSites,PartsPerTimeStep);
NewComps      = NewDepths;
NewLats       = NewDepths;
NewLons       = NewDepths;
NewSites      = repmat((1:spillLocation.nSites)',1,PartsPerTimeStep);
first_ID      = last_ID + 1;
last_ID       = last_ID + PartsPerTimeStepAllsites;
NewIDs        = first_ID:last_ID;
rand_Depths   = rand(spillLocation.nSites,PartsPerTimeStep);

for Site_cicle = 1 : spillLocation.nSites  % ADDED
  for depth_cicle = 1 : spillLocation.n_Depths
    NewDepths_Idx = find(rand_Depths(Site_cicle,:) <= PartsPerDepth_threshold(depth_cicle));
    NewDepths(Site_cicle,NewDepths_Idx) = spillLocation.Depths(depth_cicle);
    numel_NewDepths_Idx = numel(NewDepths_Idx);
    NewLats(Site_cicle,NewDepths_Idx) = spillLocation.Lat(Site_cicle) + randn(1,numel_NewDepths_Idx) .*...
      spillLocation.Radius_degLat(depth_cicle);
    NewLons(Site_cicle,NewDepths_Idx) = spillLocation.Lon(Site_cicle) + randn(1,numel_NewDepths_Idx) .*...
      spillLocation.Radius_degLon(depth_cicle);
    rand_Comps = rand(1,numel_NewDepths_Idx);
    for comp_cicle = 1 : Params.components_number
      comps_threshold = max(cumsum(Params.components_proportions(depth_cicle,1:comp_cicle)));
      NewComps(Site_cicle,NewDepths_Idx(rand_Comps <= comps_threshold)) = comp_cicle;
      rand_Comps(rand_Comps <= comps_threshold) = nan;
    end
      rand_Depths(Site_cicle,find(rand_Depths(Site_cicle,:) <= PartsPerDepth_threshold(depth_cicle))) = nan;
  end
end
Particles.Age_days(first_ID:last_ID) = NewAges(1:end);
Particles.Status(first_ID:last_ID)   = NewStatus(1:end);
Particles.Depth(first_ID:last_ID)    = NewDepths(1:end);
Particles.Comp(first_ID:last_ID)     = NewComps(1:end);
Particles.Lat(first_ID:last_ID)      = NewLats(1:end);
Particles.Lon(first_ID:last_ID)      = NewLons(1:end);
Particles.Site (first_ID:last_ID)    = NewSites(1:end);
Particles.birthDate(first_ID:last_ID)= NewBirthDates(1:end);
Particles.ID (first_ID:last_ID)      = NewIDs(1:end);

% Status:
% 1 = In water
% 2 = In land
% 3 = Out of domain
% 4 = Burned
% 5 = Collected
% 6 = Evaporated
% 7 = Naturally dispersed
% 8 = Chemically dispersed
% 9 = Exponentially degraded
end