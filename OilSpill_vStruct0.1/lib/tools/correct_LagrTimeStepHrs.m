% This software (OilSpill_vStruct) was developed by Julio Antonio Lara
% Hernandez (lara.hernandez.julio.a@gmail.com) and Dr. Jorge Zavala Hidalgo
% (jzavala@atmosfera.unam.mx). An analogous version implemented in 
% object-oriented programming was developed by Olmo Zavala-Hidalgo, and an 
% analogous version implemented in Julia was developed by Andrea Isabel
% Anguiano Garcia. The free use of this software is allowed as long as the
% corresponding credit is given to the developers.

% Function to make sure that the Lagrangian_time_step is correct
function LagrTimeStepInHrs = correct_LagrTimeStepHrs(LagrTimeStepInHrs,OceanFileTimeStep,WindFileTimeStep)
% Check Lagrangian_time_step <= VectorFields_time_step
min_timestep = min([OceanFileTimeStep;WindFileTimeStep]);
if LagrTimeStepInHrs > min_timestep
  LagrTimeStepInHrs = min_timestep;
  warning(['The Lagrangian time step was changed to ',num2str(LagrTimeStepInHrs),' h'])
end
% Verify that the Lagrangian time step is a divisor of 24 h
if rem(24,LagrTimeStepInHrs) ~= 0
  serie = 0:.01:LagrTimeStepInHrs; % 0.01 h = 0.6 min = 36 s
  possible_timesteps = serie(rem(24,serie)==0);
  LagrTimeStepInHrs = possible_timesteps(end);
  warning(['The Lagrangian time step was changed to ',num2str(LagrTimeStepInHrs),' h'])
end
end
