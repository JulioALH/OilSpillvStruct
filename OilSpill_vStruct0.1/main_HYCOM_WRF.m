% This software (OilSpill_vStruct) was developed by Julio Antonio Lara
% Hernandez (lara.hernandez.julio.a@gmail.com) and Dr. Jorge Zavala Hidalgo
% (jzavala@atmosfera.unam.mx). An analogous version implemented in 
% object-oriented programming was developed by Olmo Zavala-Hidalgo, and an 
% analogous version implemented in Julia was developed by Andrea Isabel
% Anguiano Garcia. The free use of this software is allowed as long as the
% corresponding credit is given to the developers.

% Oil spill v.Struct
% Lagrangian algorithm to simulate oil spills in the Gulf of Mexico
close all; clear; clc; format compact; clc
sites_lat = [25.97096444, 25.36115583, 24.75155556, 23.51224639, 20.97098889, 20.04058889];
sites_lon =-[95.01622889, 95.25811667, 96.56495556, 96.82528583, 96.71577028, 94.76735833];
%----------------------- Spill timing (yyyy,mm,dd) -----------------------%
spillTiming.startDay_date     = [1992,01,01]; %
spillTiming.lastSpillDay_date = [2011,12,31]; %
spillTiming.endSimDay_date    = [2012,02,28]; %
%---------------------------- Spill location -----------------------------%
spillLocation.Lat      =  sites_lat;
spillLocation.Lon      =  sites_lon;
spillLocation.Depths   = [1500,  500,  100,     0];
spillLocation.Radius_m = [1000, 6000, 9000, 10000]; % 1 STD for random initialization of particles
%------------------------- Local Paths filename --------------------------%
Params.LocalPaths = 'local_paths_HYCOM_WRF.m';
%--------------------------- Output directorie ---------------------------%
Params.OutputDir = '/media/julio/My Passport/results_HYCOMWRF_full/';
%----------------------- Runge-Kutta method: 2 | 4 -----------------------%
Params.RungeKutta = 4;
%---- Velocity Fields Type: 1 (BP) | 2 (Usumacinta) | 3 (climatology) ----%
Params.velocityFieldsType = 5;
%----------------------------- Model domain ------------------------------%
Params.domainLimits = [-98, -80, 18.1, 31.9]; % [-98, -80, 18.1, 31.9]
%------------- Number of particles representing one barrel ---------------%
Params.particlesPerBarrel  = 1;
%--------------- Turbulent-diffusion parameter per depth -----------------%
Params.TurbDiff_b          = [0.2, 0.4, 0.8, 1.0];
%------ Wind fraction used to advect particles (only for 0 m depth) ------%
Params.windcontrib         = 0.035;
%--------------- Distribution of oil at surface (0 m depth)---------------%
Params.surfaceFraction = 1/4; % x/y | 'auto'
%--------- Distribution of oil per subsurface depth (> 0 m depth)---------%
Params.subsurfaceFractions = [1/3, 1/3, 1/3]; % x/y
%------------Oil components (component proportions per depth) ------------%
Params.components_proportions = [...
      [1/3,1/3,1/3];
      [1/3,1/3,1/3];
      [1/3,1/3,1/3];
      [1/3,1/3,1/3]];
%--------------- Ocean and Wind files (time step in hours) ---------------%
OceanFile.timeStep_hrs = 24;
WindFile.timeStep_hrs  = 24;
%----------------------- Lagrangian time step (h) ------------------------%
LagrTimeStep.InHrs = 1;
%------------------------------ Oil decay --------------------------------%
% Burning
decay.burn                  = 0;
decay.burn_radius_m         = 300000;
% Collection
decay.collect               = 0;
% Evaporation
decay.evaporate             = 0;
% Natural dispersion
decay.surfNatrDispr         = 0;
% Chemical dispersion
decay.surfChemDispr         = 0;
% Exponential degradation
decay.expDegrade            = 1;
decay.expDegrade_Percentage = 99;
decay.expDegrade_Days       = [20,40,60];
%----------------------- Get daily spill quantities ----------------------%
% 'filename.csv' | '0'. Set csv_file == '0' if you DONOT have a csv file
DS.csv_file = '0';
% Next DS block is required if you DONOT have a csv file (DS.csv_file = '0')
% Indicate mean daily spill quantities (oil barrels)
DS.Net                = 100*4*3;
DS.Burned             = 0;
DS.OilyWater          = 0;
DS.SurfaceDispersants = 0;
DS.SubsurfDispersants = 0;
%-------------- Visualization (mapping particles positions) --------------%
% 'on' | 'off'. Set 'on' for visualizing maps as the model runs
vis_maps.visible         = 'off';
vis_maps.visible_step_hr = 24; % nan
% Bathymetry file name. 'BAT_FUS_GLOBAL_PIXEDIT_V4.mat' | 'gebco_1min_-98_18_-78_31.nc'
vis_maps.bathymetry      = 'BATI100_s10_fixLC.mat';
% Visualization Type (2D and/or 3D)
vis_maps.twoDim          = false;
vis_maps.threeDim        = false;
vis_maps.threeDim_angles = [98, 53];% [Az, El] [0, 90] [-6, 55]
% Visualization region [minLon, maxLon, minLat, maxLat, minDepth, maxDepth]
vis_maps.boundaries      = [-98, -88, 18.1, 30, -2500, 0]; % [-98, -90, 18.1, 22]
% Isobaths to plot
vis_maps.isobaths        = [-0, -200];
% Colormap to use
vis_maps.cmap            = 'copper'; % e.g.: [1 1 1], 'copper', 'gray', 'jet',...
vis_maps.fontSize        = 16;
vis_maps.markerSize      = 5;
vis_maps.axesPosition    = [2,2,10,8];
vis_maps.figPosition     = [2,2,2*vis_maps.axesPosition(1)+vis_maps.axesPosition(3)+2.5,...
      2*vis_maps.axesPosition(2)+vis_maps.axesPosition(4)-.5];
% Create the colors for the oil
vis_maps.colors_SpillLocation = 'w';
vis_maps.colors_InLand        = 'w';
vis_maps.colors_ByDepth       = ['g';'r';'b';'c';'y'];
vis_maps.colors_BySite_on     = true; % true | false
vis_maps.colors_BySite        = {'g';'r';'b';'c';'m';'y'};
vis_maps.colors_ByComponent   = {...
  'y';...                          % yellow
  'r';...                          % red
  'b';...                          % blue
  'c';...                          % cyan
  [0.4660    0.7740    0.1880];... % green
  [0.9290    0.6940    0.1250];... % orange
  'm';...                          % magenta
  [0.4940    0.1840    0.5560]};   % purple
%------------------ Visualization (plotting statistics) ------------------%
% 'on' | 'off'. Set 'on' for visualizing statistics as the model runs
vis_stat.visible         = 'off'; % 'on' | 'off'
vis_stat.visible_step_hr = nan;
vis_stat.axesLimits      = 'auto'; % 'auto' | [xmin xmax ymin ymax]
vis_stat.fontSize        = 16;
vis_stat.markerSize      = 5;
vis_stat.lineColors      = {...
  [0.0357    0.8491    0.9340];... % cyan
  [0.1419    0.4218    0.9157];... % blue
  [0.6160    0.4733    0.3517];... % brown
  [0.7149    0.7173    0.7187];... % gray
  [1.0000    0.0000    0.0000];... % red
  [0.0000    0.0000    0.0000];... % black
  [0.5499    0.1450    0.8530];... % purple
  [0.5407    0.8699    0.2648];... % green
  [0.9649    0.1576    0.9706];... % magenta
  [0.8611    0.4849    0.3935]};   % orange
vis_stat.axesPosition    = [2,2,10,8];
vis_stat.figPosition     = [2,2,2*vis_stat.axesPosition(1)+vis_stat.axesPosition(3)+4,...
      2*vis_stat.axesPosition(2)+vis_stat.axesPosition(4)-.5];
%---------------------------- Saving options -----------------------------%
% Data
saving.Data_on                   = 1;
saving.Data_step_hr              = 24;
% maps_videos
saving.MapsVideo_on              = 0;
saving.MapsVideo_quality         = 100; % 0 (worst) --> 100 (best)
saving.MapsVideo_framesPerSecond = 3;
saving.MapsVideo_step_hr         = 24;
% maps_images
saving.MapsImage_on              = 0;
saving.MapsImage_quality         = '-r200'; % Resolution in dpi
saving.MapsImage_step_hr         = 24;
% stat_videos
saving.StatVideo_on              = 0;
saving.StatVideo_quality         = 100; % 0 (worst) --> 100 (best)
saving.StatVideo_framesPerSecond = 3;
saving.StatVideo_step_hr         = 24;
% stat_images
saving.StatImage_on              = 0;
saving.StatImage_quality         = '-r100'; % Resolution in dpi
saving.StatImage_step_hr         = 24;
%---------------------------- Add local paths ----------------------------%
run(Params.LocalPaths);
%-------------------------- Call model routine ---------------------------%
tic
oilSpillModel(spillTiming,spillLocation,Params,OceanFile,WindFile,...
  LagrTimeStep,decay,DS,vis_maps,vis_stat,saving);
toc
close all
