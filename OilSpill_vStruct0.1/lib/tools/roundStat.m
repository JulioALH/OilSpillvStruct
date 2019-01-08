% This software (OilSpill_vStruct) was developed by Julio Antonio Lara
% Hernandez (lara.hernandez.julio.a@gmail.com) and Dr. Jorge Zavala Hidalgo
% (jzavala@atmosfera.unam.mx). An analogous version implemented in 
% object-oriented programming was developed by Olmo Zavala-Hidalgo, and an 
% analogous version implemented in Julia was developed by Andrea Isabel
% Anguiano Garcia. The free use of this software is allowed as long as the
% corresponding credit is given to the developers.
function nInt = roundStat(nDec)
floor_nDec = floor(nDec);
decimals = nDec-floor_nDec;
if decimals ~= 0
  rand_n = rand;
  if rand_n > decimals
    nInt = floor_nDec;
  else
    nInt = ceil(nDec);
  end
else
  nInt = nDec;
end
end
