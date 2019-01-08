% This software (OilSpill_vStruct) was developed by Julio Antonio Lara
% Hernandez (lara.hernandez.julio.a@gmail.com) and Dr. Jorge Zavala Hidalgo
% (jzavala@atmosfera.unam.mx). An analogous version implemented in 
% object-oriented programming was developed by Olmo Zavala-Hidalgo, and an 
% analogous version implemented in Julia was developed by Andrea Isabel
% Anguiano Garcia. The free use of this software is allowed as long as the
% corresponding credit is given to the developers.
function [velocities,WindFile,OceanFile] = velocityFields_4(first_time,SerialDay,ts,LagrTimeStep,spillLocation,OceanFile,WindFile,Params)
% first_time    --> Bool variable that indicates if its the first time we enter in this function
% SerialDay     --> Indicates which day are we computing
% ts            --> Current time step
% LagrTimeStep  --> Structure with information about the lagrantian time steps (in hours, in seconds, etc.)
% spillLocation --> Structure with the location and depth information (depths, lat, lon, etc.)
% OceanFile     --> Indicates the time step for the currents
% WindFile      --> Indicates the time step for the winds
% Params        --> Structure with main parameters of the model (RK, domainLimits, particlesPerBarrel, etc.)
date_time = datetime(SerialDay,'ConvertFrom','datenum');
date_time_next = datetime(SerialDay+1,'ConvertFrom','datenum');
date_str = datestr(date_time,'_yyyymmdd');
month_curr = date_str(end-3:end-2);
date_str_next = datestr(date_time_next,'_yyyymmdd');
month_next = date_str_next(end-3:end-2);
%-------------------------Get ocean VectorFields--------------------------%
if first_time
  % Ocean file names and variable names
  OceanFile.Uname         = 'vozocrtx';
  OceanFile.Vname         = 'vomecrty';
  OceanFile.LatName       = 'nav_lat';
  OceanFile.LonName       = 'nav_lon';
  OceanFile.DepthName     = 'depthu';
  % Define variables
  firstFileName = 'GOLFO36-AGR02_1d_coords_grid_U.nc';
  % Reads Lat and Lon
  lat_O         = double(ncread(firstFileName,OceanFile.LatName,[1 1],[1 inf]))';
  lon_O         = double(ncread(firstFileName,OceanFile.LonName,[1 1],[inf 1]))';
  % Obtains the indexes inside the netCDF that corresponds to the BBOX of our run
  OceanFile.Lat_min = find(lat_O <= Params.domainLimits(3),1,'last');
  OceanFile.Lat_max = find(lat_O >= Params.domainLimits(4),1,'first');
  OceanFile.Lon_min = find(lon_O <= Params.domainLimits(1),1,'last');
  OceanFile.Lon_max = find(lon_O >= Params.domainLimits(2),1,'first');
  % Reduces the size of the lat and lon arrays with the limits of the BBOX
  lat_O = lat_O(OceanFile.Lat_min:OceanFile.Lat_max);
  lon_O = lon_O(OceanFile.Lon_min:OceanFile.Lon_max);
  OceanFile.Lat_numel = numel(lat_O);
  OceanFile.Lon_numel = numel(lon_O);
  [OceanFile.Lon,OceanFile.Lat] = meshgrid(lon_O,lat_O);
  % Reads depth
  OceanFile.depths        = double(ncread(firstFileName,OceanFile.DepthName));
  OceanFile.depths(1)     = 0;
  % Obtains the indexes inside the netCDF that corresponds to the limits of the depth
  OceanFile.minDepth_Idx  = find(OceanFile.depths <= min(spillLocation.Depths),1,'last');
  OceanFile.maxDepth_Idx  = find(OceanFile.depths >= max(spillLocation.Depths),1,'first');
  OceanFile.tempDepths    = OceanFile.depths(OceanFile.minDepth_Idx:OceanFile.maxDepth_Idx);
  OceanFile.n_tempDepths  = numel(OceanFile.tempDepths);
  OceanFile.toInterpolate = ismember(spillLocation.Depths,OceanFile.tempDepths);
  OceanFile.auxArray      = nan([size(OceanFile.Lat),spillLocation.n_Depths]);
  % Read ocean VectorFields for the current and next day
  readOceanFileT1 = 'GOLFO36-AGR02_1d_20110315_20110413_grid_';
  TT = ncread([readOceanFileT1,'U.nc'],'time_counter');
  TT_datenum = 693962 + TT/86400;
  TT_datestr = datestr(TT_datenum,'_yyyymmdd');
  idx_time_T1 = find(sum(TT_datestr ~= repmat(date_str,size(TT_datestr,1),1),2) == 0);
  if sum(month_curr ~= month_next) == 0
    readOceanFileT2 = readOceanFileT1;
    idx_time_T2 = idx_time_T1+1;
  else
    readOceanFileT2 = 'GOLFO36-AGR02_1d_20110414_20110513_grid_';
    idx_time_T2 = 1;
  end
  OceanFile.U_T1 = ncread([readOceanFileT1,'U.nc'],OceanFile.Uname,...
    [OceanFile.Lon_min,OceanFile.Lat_min,OceanFile.minDepth_Idx,idx_time_T1],...
    [OceanFile.Lon_numel,OceanFile.Lat_numel,OceanFile.n_tempDepths,1]);
  OceanFile.V_T1 = ncread([readOceanFileT1,'V.nc'],OceanFile.Vname,...
    [OceanFile.Lon_min,OceanFile.Lat_min,OceanFile.minDepth_Idx,idx_time_T1],...
    [OceanFile.Lon_numel,OceanFile.Lat_numel,OceanFile.n_tempDepths,1]);
  OceanFile.U_T1(OceanFile.U_T1 == 0 & OceanFile.V_T1 == 0) = nan;
  OceanFile.V_T1(isnan(OceanFile.U_T1)) = nan;
  OceanFile.U_T1 = permute(OceanFile.U_T1,[2 1 3]);
  OceanFile.V_T1 = permute(OceanFile.V_T1,[2 1 3]);
  OceanFile.U_T2 = ncread([readOceanFileT2,'U.nc'],OceanFile.Uname,...
    [OceanFile.Lon_min,OceanFile.Lat_min,OceanFile.minDepth_Idx,idx_time_T2],...
    [OceanFile.Lon_numel,OceanFile.Lat_numel,OceanFile.n_tempDepths,1]);
  OceanFile.V_T2 = ncread([readOceanFileT2,'V.nc'],OceanFile.Vname,...
    [OceanFile.Lon_min,OceanFile.Lat_min,OceanFile.minDepth_Idx,idx_time_T2],...
    [OceanFile.Lon_numel,OceanFile.Lat_numel,OceanFile.n_tempDepths,1]);
  OceanFile.U_T2(OceanFile.U_T2 == 0 & OceanFile.V_T2 == 0) = nan;
  OceanFile.V_T2(isnan(OceanFile.U_T2)) = nan;
  OceanFile.U_T2 = permute(OceanFile.U_T2,[2 1 3]);
  OceanFile.V_T2 = permute(OceanFile.V_T2,[2 1 3]);
  % Get ocean VectorFields layers acording to the user depths
  ocean_U_T1_temp = OceanFile.auxArray;
  ocean_V_T1_temp = OceanFile.auxArray;
  ocean_U_T2_temp = OceanFile.auxArray;
  ocean_V_T2_temp = OceanFile.auxArray;
  if spillLocation.n_Depths ~= OceanFile.n_tempDepths || any(~OceanFile.toInterpolate)
    for layer = 1 : spillLocation.n_Depths
      if ~OceanFile.toInterpolate(layer)
        % Interpolate depth
        lower_layer                = find(OceanFile.tempDepths < spillLocation.Depths(layer),1,'last');
        upper_layer                = find(OceanFile.tempDepths > spillLocation.Depths(layer),1,'first');
        layers_mtr_diff            = OceanFile.tempDepths(upper_layer) - OceanFile.tempDepths(lower_layer);
        Depth_mtr_diff             = spillLocation.Depths(layer) - OceanFile.tempDepths(lower_layer);
        DepthDiff_BTW_layersDiff   = Depth_mtr_diff./layers_mtr_diff;
        layers_U_diff_T1           = OceanFile.U_T1(:,:,upper_layer) - OceanFile.U_T1(:,:,lower_layer);
        layers_V_diff_T1           = OceanFile.V_T1(:,:,upper_layer) - OceanFile.V_T1(:,:,lower_layer);
        ocean_U_T1_temp(:,:,layer) = OceanFile.U_T1(:,:,lower_layer) + layers_U_diff_T1.* DepthDiff_BTW_layersDiff;
        ocean_V_T1_temp(:,:,layer) = OceanFile.V_T1(:,:,lower_layer) + layers_V_diff_T1.* DepthDiff_BTW_layersDiff;
        layers_U_diff_T2           = OceanFile.U_T2(:,:,upper_layer) - OceanFile.U_T2(:,:,lower_layer);
        layers_V_diff_T2           = OceanFile.V_T2(:,:,upper_layer) - OceanFile.V_T2(:,:,lower_layer);
        ocean_U_T2_temp(:,:,layer) = OceanFile.U_T2(:,:,lower_layer) + layers_U_diff_T2.* DepthDiff_BTW_layersDiff;
        ocean_V_T2_temp(:,:,layer) = OceanFile.V_T2(:,:,lower_layer) + layers_V_diff_T2.* DepthDiff_BTW_layersDiff;
      else
        % Allocate layer
        correct_layer = find(spillLocation.Depths(layer) == OceanFile.tempDepths); % CORREGIDO
        ocean_U_T1_temp(:,:,layer) = OceanFile.U_T1(:,:,correct_layer);
        ocean_V_T1_temp(:,:,layer) = OceanFile.V_T1(:,:,correct_layer);
        ocean_U_T2_temp(:,:,layer) = OceanFile.U_T2(:,:,correct_layer);
        ocean_V_T2_temp(:,:,layer) = OceanFile.V_T2(:,:,correct_layer);
      end
    end
    OceanFile.U_T1 = ocean_U_T1_temp;
    OceanFile.V_T1 = ocean_V_T1_temp;
    OceanFile.U_T2 = ocean_U_T2_temp;
    OceanFile.V_T2 = ocean_V_T2_temp;
  else
    misplaced = OceanFile.tempDepths ~= spillLocation.Depths';
    if any(misplaced)
      for layer = 1 : spillLocation.n_Depths
        if misplaced(layer)
          correct_layer = find(OceanFile.tempDepths==spillLocation.Depths(layer));
          ocean_U_T1_temp(:,:,layer) = OceanFile.U_T1(:,:,correct_layer);
          ocean_V_T1_temp(:,:,layer) = OceanFile.V_T1(:,:,correct_layer);
          ocean_U_T2_temp(:,:,layer) = OceanFile.U_T2(:,:,correct_layer);
          ocean_V_T2_temp(:,:,layer) = OceanFile.V_T2(:,:,correct_layer);
        else
          ocean_U_T1_temp(:,:,layer) = OceanFile.U_T1(:,:,layer);
          ocean_V_T1_temp(:,:,layer) = OceanFile.V_T1(:,:,layer);
          ocean_U_T2_temp(:,:,layer) = OceanFile.U_T2(:,:,layer);
          ocean_V_T2_temp(:,:,layer) = OceanFile.V_T2(:,:,layer);
        end
      end
      OceanFile.U_T1 = ocean_U_T1_temp;
      OceanFile.V_T1 = ocean_V_T1_temp;
      OceanFile.U_T2 = ocean_U_T2_temp;
      OceanFile.V_T2 = ocean_V_T2_temp;
    end
  end
else
  flag_one = floor((ts-2)*LagrTimeStep.BTW_oceanTS);
  flag_two = floor((ts-1)*LagrTimeStep.BTW_oceanTS);
  if flag_one ~= flag_two
    % Rename and read ocean VectorFields for the next day
    OceanFile.U_T1 = OceanFile.U_T2;
    OceanFile.V_T1 = OceanFile.V_T2;
    if SerialDay > datenum([2011,04,13])
      readOceanFile = 'GOLFO36-AGR02_1d_20110414_20110513_grid_';
    else
      readOceanFile = 'GOLFO36-AGR02_1d_20110315_20110413_grid_';
    end
    TT = ncread([readOceanFile,'U.nc'],'time_counter');
    TT_datenum = 693962 + TT/86400;
    TT_datestr = datestr(TT_datenum,'_yyyymmdd');
    idx_time = find(sum(TT_datestr ~= repmat(date_str,size(TT_datestr,1),1),2) == 0);
    OceanFile.U_T2 = ncread([readOceanFile,'U.nc'],OceanFile.Uname,...
      [OceanFile.Lon_min,OceanFile.Lat_min,OceanFile.minDepth_Idx,idx_time],...
      [OceanFile.Lon_numel,OceanFile.Lat_numel,OceanFile.n_tempDepths,1]);
    OceanFile.V_T2 = ncread([readOceanFile,'V.nc'],OceanFile.Vname,...
      [OceanFile.Lon_min,OceanFile.Lat_min,OceanFile.minDepth_Idx,idx_time],...
      [OceanFile.Lon_numel,OceanFile.Lat_numel,OceanFile.n_tempDepths,1]);
    OceanFile.U_T2(OceanFile.U_T2 == 0 & OceanFile.V_T2 == 0) = nan;
    OceanFile.V_T2(isnan(OceanFile.U_T2)) = nan;
    OceanFile.U_T2 = permute(OceanFile.U_T2,[2 1 3]);
    OceanFile.V_T2 = permute(OceanFile.V_T2,[2 1 3]);
    % Get ocean VectorFields layers acording to the user depths
    ocean_U_T2_temp = OceanFile.auxArray;
    ocean_V_T2_temp = OceanFile.auxArray;
    if spillLocation.n_Depths ~= OceanFile.n_tempDepths || any(~OceanFile.toInterpolate)
      for layer = 1 : spillLocation.n_Depths
        if ~OceanFile.toInterpolate(layer)
          % Interpolate
          lower_layer                = find(OceanFile.tempDepths < spillLocation.Depths(layer),1,'last');
          upper_layer                = find(OceanFile.tempDepths > spillLocation.Depths(layer),1,'first');
          layers_mtr_diff            = OceanFile.tempDepths(upper_layer) - OceanFile.tempDepths(lower_layer);
          Depth_mtr_diff             = spillLocation.Depths(layer) - OceanFile.tempDepths(lower_layer);
          DepthDiff_BTW_layersDiff   = Depth_mtr_diff./layers_mtr_diff;
          layers_U_diff_T2           = OceanFile.U_T2(:,:,upper_layer) - OceanFile.U_T2(:,:,lower_layer);
          layers_V_diff_T2           = OceanFile.V_T2(:,:,upper_layer) - OceanFile.V_T2(:,:,lower_layer);
          ocean_U_T2_temp(:,:,layer) = OceanFile.U_T2(:,:,lower_layer) + layers_U_diff_T2 .* DepthDiff_BTW_layersDiff;
          ocean_V_T2_temp(:,:,layer) = OceanFile.V_T2(:,:,lower_layer) + layers_V_diff_T2 .* DepthDiff_BTW_layersDiff;
        else
          % Rearrange
          correct_layer = find(OceanFile.tempDepths == spillLocation.Depths(layer));
          ocean_U_T2_temp(:,:,layer) = OceanFile.U_T2(:,:,correct_layer);
          ocean_V_T2_temp(:,:,layer) = OceanFile.V_T2(:,:,correct_layer);
        end
      end
      OceanFile.U_T2 = ocean_U_T2_temp;
      OceanFile.V_T2 = ocean_V_T2_temp;
    else
      misplaced = OceanFile.tempDepths ~= spillLocation.Depths';
      if any(misplaced)
        for layer = 1 : spillLocation.n_Depths
          if misplaced(layer)
            correct_layer = find(OceanFile.tempDepths==spillLocation.Depths(layer));
            ocean_U_T2_temp(:,:,layer) = OceanFile.U_T2(:,:,correct_layer);
            ocean_V_T2_temp(:,:,layer) = OceanFile.V_T2(:,:,correct_layer);
          else
            ocean_U_T2_temp(:,:,layer) = OceanFile.U_T2(:,:,layer);
            ocean_V_T2_temp(:,:,layer) = OceanFile.V_T2(:,:,layer);
          end
        end
        OceanFile.U_T2 = ocean_U_T2_temp;
        OceanFile.V_T2 = ocean_V_T2_temp;
      end
    end
  end
end
%--------------------------Get wind VectorFields--------------------------%
surface_simulation = ismember(0,spillLocation.Depths);
if surface_simulation
  if first_time
    % Wind file names and varible names
    WindFile.Uname        = 'u10';
    WindFile.Vname        = 'v10';
    WindFile.LatName      = 'lat';
    WindFile.LonName      = 'lon';
    % Define variables
    firstFileName = 'drowned_u10_NCEP_y2011-010.nc';
    lat_W = double(ncread(firstFileName,WindFile.LatName));
    lon_W = double(ncread(firstFileName,WindFile.LonName));
    lon_W(lon_W>=180) = lon_W(lon_W>=180)-360;
    WindFile.Lat_max = find(lat_W <= min(lat_O),1,'first');
    WindFile.Lat_min = find(lat_W >= max(lat_O),1,'last');
    WindFile.Lon_max = find(lon_W <= max(lon_O),1,'last');
    WindFile.Lon_min = find(lon_W <= min(lon_O),1,'last');
    lat_W = flip(lat_W(WindFile.Lat_min:WindFile.Lat_max));
    lon_W = lon_W(WindFile.Lon_min:WindFile.Lon_max);
    WindFile.Lat_numel = numel(lat_W);
    WindFile.Lon_numel = numel(lon_W);
    [WindFile.Lon,WindFile.Lat] = meshgrid(lon_W,lat_W);
    % Read wind VectorFields from the current and next file
    TT_hrs = 0:6:1460*6-1;
    TT_day = TT_hrs/24;
    WindFile.TimeIndex = find(TT_day == day(datetime(datevec(SerialDay)),'dayofyear')) + 1;
    WindFile.U_T1 = flip(ncread('drowned_u10_NCEP_y2011-010.nc',WindFile.Uname,...
      [WindFile.Lon_min,WindFile.Lat_min,WindFile.TimeIndex-1],[WindFile.Lon_numel,WindFile.Lat_numel,1])');
    WindFile.V_T1 = flip(ncread('drowned_v10_NCEP_y2011-011.nc',WindFile.Vname,...
      [WindFile.Lon_min,WindFile.Lat_min,WindFile.TimeIndex-1],[WindFile.Lon_numel,WindFile.Lat_numel,1])');
    WindFile.U_T2 = flip(ncread('drowned_u10_NCEP_y2011-010.nc',WindFile.Uname,...
      [WindFile.Lon_min,WindFile.Lat_min,WindFile.TimeIndex],[WindFile.Lon_numel,WindFile.Lat_numel,1])');
    WindFile.V_T2 = flip(ncread('drowned_v10_NCEP_y2011-011.nc',WindFile.Vname,...
      [WindFile.Lon_min,WindFile.Lat_min,WindFile.TimeIndex],[WindFile.Lon_numel,WindFile.Lat_numel,1])');
    % Interp wind grid to ocean grid
    WindFile.U_T1   = interp2(WindFile.Lon,WindFile.Lat,WindFile.U_T1,OceanFile.Lon,OceanFile.Lat);
    WindFile.V_T1   = interp2(WindFile.Lon,WindFile.Lat,WindFile.V_T1,OceanFile.Lon,OceanFile.Lat);
    WindFile.U_T2   = interp2(WindFile.Lon,WindFile.Lat,WindFile.U_T2,OceanFile.Lon,OceanFile.Lat);
    WindFile.V_T2   = interp2(WindFile.Lon,WindFile.Lat,WindFile.V_T2,OceanFile.Lon,OceanFile.Lat);
    % Rotate wind grid
    [WindFile.U_T1, WindFile.V_T1] = rotangle(WindFile.U_T1, WindFile.V_T1);
    [WindFile.U_T2, WindFile.V_T2] = rotangle(WindFile.U_T2, WindFile.V_T2);
  else
    % Rename and read wind VectorFields from the next file
    flag_one = floor((ts-2)*LagrTimeStep.BTW_windsTS);
    flag_two = floor((ts-1)*LagrTimeStep.BTW_windsTS);
    if flag_one ~= flag_two
      WindFile.TimeIndex = WindFile.TimeIndex + 1;
      WindFile.U_T1 = WindFile.U_T2;
      WindFile.V_T1 = WindFile.V_T2;
      WindFile.U_T2 = flip(ncread('drowned_u10_NCEP_y2011-010.nc',WindFile.Uname,...
        [WindFile.Lon_min,WindFile.Lat_min,WindFile.TimeIndex],[WindFile.Lon_numel,WindFile.Lat_numel,1])');
      WindFile.V_T2 = flip(ncread('drowned_v10_NCEP_y2011-011.nc',WindFile.Vname,...
        [WindFile.Lon_min,WindFile.Lat_min,WindFile.TimeIndex],[WindFile.Lon_numel,WindFile.Lat_numel,1])');
      % Interp wind grid T2 to ocean grid
      WindFile.U_T2   = interp2(WindFile.Lon,WindFile.Lat,WindFile.U_T2,OceanFile.Lon,OceanFile.Lat);
      WindFile.V_T2   = interp2(WindFile.Lon,WindFile.Lat,WindFile.V_T2,OceanFile.Lon,OceanFile.Lat);
      % Rotate wind grid T2
      [WindFile.U_T2, WindFile.V_T2] = rotangle(WindFile.U_T2, WindFile.V_T2);
    end
  end
end
%--------------Interp VectorFields (temporal interpolation)---------------%
time_dif = (ts-1) * LagrTimeStep.InHrs;
% Ocean
% Velocities for current time-step
ocean_U_factor = (OceanFile.U_T2 - OceanFile.U_T1) ./ OceanFile.timeStep_hrs;
ocean_V_factor = (OceanFile.V_T2 - OceanFile.V_T1) ./ OceanFile.timeStep_hrs;
velocities.Uts1 = OceanFile.U_T1 + time_dif .* ocean_U_factor;
velocities.Vts1 = OceanFile.V_T1 + time_dif .* ocean_V_factor;
% Velocities for next time-step
TimeDiff_plus_TS = time_dif + LagrTimeStep.InHrs;
velocities.Uts2 = OceanFile.U_T1 + TimeDiff_plus_TS .* ocean_U_factor;
velocities.Vts2 = OceanFile.V_T1 + TimeDiff_plus_TS .* ocean_V_factor;
if surface_simulation
  % Wind
  % Velocities for current time-step
  wind_U_factor = (WindFile.U_T2 - WindFile.U_T1) ./ WindFile.timeStep_hrs;
  wind_V_factor = (WindFile.V_T2 - WindFile.V_T1) ./ WindFile.timeStep_hrs;
  wind_Uts1     = WindFile.U_T1 + time_dif .* wind_U_factor;
  wind_Vts1     = WindFile.V_T1 + time_dif .* wind_V_factor;
  % Velocities for next time-step
  wind_Uts2 = WindFile.U_T1 + TimeDiff_plus_TS .* wind_U_factor;
  wind_Vts2 = WindFile.V_T1 + TimeDiff_plus_TS .* wind_V_factor;
  %-------------------------Add wind to 0 m layer-------------------------%
  layer_0m = find(spillLocation.Depths == 0);
  velocities.Uts1(:,:,layer_0m) = velocities.Uts1(:,:,layer_0m) + wind_Uts1 * Params.windcontrib;
  velocities.Vts1(:,:,layer_0m) = velocities.Vts1(:,:,layer_0m) + wind_Vts1 * Params.windcontrib;
  velocities.Uts2(:,:,layer_0m) = velocities.Uts2(:,:,layer_0m) + wind_Uts2 * Params.windcontrib;
  velocities.Vts2(:,:,layer_0m) = velocities.Vts2(:,:,layer_0m) + wind_Vts2 * Params.windcontrib;
end
end
