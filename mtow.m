% Aircraft design tool
%
% Mario Bras (mbras@uvic.ca) and Ricardo Marques (ricardoemarques@uvic.ca) 2019
%
% This file is subject to the license terms in the LICENSE file included in this distribution

function [mission, aircraft] = mtow(mission, aircraft, constants)

% Initialize mission parameters
mission.mf_batt = 0;
mission.mf_fuel = 0;
mission.time = 0;
mission.range = 0;

mf_to_minus_fuel = 1;

% Iterate over mission segments
for i = 1 : length(mission.segments)
    mission.segments{i}.mf_batt = 0;
    mission.segments{i}.mf_fuel = 0;

    [mission.segments{i}.temperature, mission.segments{i}.speed_sound, mission.segments{i}.pressure, mission.segments{i}.density] = atmosisa(mission.segments{i}.altitude);

    if strcmp(mission.segments{i}.type, 'taxi') % Taxi segment
        if is_fuel(mission.segments{i}.energy)
            mission.segments{i}.mf_fuel = 1 - 0.9725;
        elseif is_electric(mission.segments{i}.energy)
            mission.segments{i}.mf_batt = 0;
        end
        mission.segments{i}.range = 0;
    elseif strcmp(mission.segments{i}.type, 'hover') % Hover segment
        if is_fuel(mission.segments{i}.energy)
            errordlg('Not available'); % NOT AVAILABLE
            break;
        elseif is_electric(mission.segments{i}.energy)
            pl = aircraft.propulsion.fm * sqrt(2 * mission.segments{i}.density / aircraft.performance.dl);
            mission.segments{i}.mf_batt = mission.segments{i}.time * constants.g / aircraft.energy.e_spec_batt / aircraft.propulsion.total_efficiency / aircraft.energy.batt_efficiency / aircraft.energy.f_usable_batt / pl;
        end
        mission.segments{i}.range = 0;
    elseif strcmp(mission.segments{i}.type, 'climb') % Climb segment
        if is_fuel(mission.segments{i}.energy)
            mach = mission.segments{i}.velocity / mission.segments{i}.speed_sound(1);
            if mach < 1
                mission.segments{i}.mf_fuel = 1 - (1 - 0.04 * mach);
            else
                mission.segments{i}.mf_fuel = 1 - (0.96 - 0.03 * (mach - 1));
            end
        elseif is_electric(mission.segments{i}.energy)
            errordlg('Not available'); % NOT AVAILABLE
            break;
        end
        mission.segments{i}.time = (mission.segments{i}.altitude(2) - mission.segments{i}.altitude(1)) / mission.segments{i}.velocity / sind(mission.segments{i}.angle);
        mission.segments{i}.range = mission.segments{i}.velocity * mission.segments{i}.time * cosd(mission.segments{i}.angle);
    elseif strcmp(mission.segments{i}.type, 'vertical_climb') % Vertical climb segment
        altitude_range = (mission.segments{i}.altitude(2) - mission.segments{i}.altitude(1));
        if is_fuel(mission.segments{i}.energy)
            errordlg('Not available'); % NOT AVAILABLE
            break;
        elseif is_electric(mission.segments{i}.energy)
            pl = 1 / (mission.segments{i}.velocity - aircraft.propulsion.k_i / 2 * mission.segments{i}.velocity + aircraft.propulsion.k_i / 2 * sqrt(mission.segments{i}.velocity^2 + 2 * aircraft.performance.dl / mission.segments{i}.density(1)) + mission.segments{i}.density(1) * aircraft.propulsion.tip_velocity^3 / aircraft.performance.dl * aircraft.propulsion.ss * aircraft.propulsion.c_d / 8); % Power loading
            mission.segments{i}.mf_batt = altitude_range * constants.g / aircraft.energy.e_spec_batt / aircraft.propulsion.total_efficiency / aircraft.energy.batt_efficiency / aircraft.energy.f_usable_batt / pl / mission.segments{i}.velocity; % Mass fraction for this segment
        end
        mission.segments{i}.time = altitude_range * mission.segments{i}.velocity;
        mission.segments{i}.range = 0;
    elseif strcmp(mission.segments{i}.type, 'acceleration') % Acceleration segment
        mach = mission.segments{i}.velocity / mission.segments{i}.a;
        if is_fuel(mission.segments{i}.energy)
            if i > 1 && mach == mission.segment{i - 1}.velocity / mission.segments{i - 1}.a
                mission.segments{i}.mf_fuel = 0;
            elseif mach < 1
                mission.segments{i}.mf_fuel = 1 - (1 - 0.04 * mach);
            else
                mission.segments{i}.mf_fuel = 1 - (0.96 - 0.03 * (mach - 1));
            end
        elseif is_electric(mission.segments{i}.energy)
            errordlg('Not available'); % NOT AVAILABLE
            break;
        end
        mission.segments{i}.range = mission.segments{i}.velocity * mission.segments{i}.time;
    elseif strcmp(mission.segments{i}.type, 'cruise') % Cruise segment
        ld = get_ld(aircraft.performance,mission.segments{i});

        if is_fuel(mission.segments{i}.energy)
            mission.segments{i}.mf_fuel = 1 - exp(-mission.segments{i}.range * mission.segments{i}.energy.sfc / mission.segments{i}.velocity / ld);
        elseif is_electric(mission.segments{i}.energy)
            mission.segments{i}.mf_batt = mission.segments{i}.range * constants.g / aircraft.energy.e_spec_batt / aircraft.propulsion.total_efficiency / aircraft.energy.batt_efficiency / aircraft.energy.f_usable_batt / ld;
        end
        mission.segments{i}.time = mission.segments{i}.range * mission.segments{i}.velocity;
    elseif strcmp(mission.segments{i}.type, 'hold') % Hold segment
        ld = get_ld(aircraft.performance, mission.segments{i});
        
        if is_fuel(mission.segments{i}.energy)
            mission.segments{i}.mf_fuel = 1 - exp(-mission.segments{i}.time * mission.segments{i}.energy.sfc / ld);
        elseif is_electric(mission.segments{i}.energy)
            mission.segments{i}.mf_batt = mission.segments{i}.time * mission.segments{i}.velocity * constants.g / aircraft.energy.e_spec_batt / aircraft.propulsion.total_efficiency / aircraft.energy.batt_efficiency / aircraft.energy.f_usable_batt / ld;
        end
        mission.segments{i}.range = mission.segments{i}.velocity * mission.segments{i}.time;
    % elseif strcmp(mission.segments{i}.type, 'combat') % Combat segment
    %     if is_fuel(mission.segments{i}.energy)
    %         % mission.segments{i}.mf_fuel = 1 - % TODO
    %     elseif is_electric(mission.segments{i}.energy)
    %         errordlg('Not available'); % NOT AVAILABLE
    %         break;
    %     end
    elseif strcmp(mission.segments{i}.type, 'descent') % Descent segment
        if is_fuel(mission.segments{i}.energy)
            mission.segments{i}.mf_fuel = 0;
        elseif is_electric(mission.segments{i}.energy)
            mission.segments{i}.mf_batt = 0;
        end
        mission.segments{i}.time = abs(mission.segments{i}.altitude(2) - mission.segments{i}.altitude(1)) / abs(mission.segments{i}.velocity) / abs(sind(mission.segments{i}.angle));
        mission.segments{i}.range = abs(mission.segments{i}.velocity) * mission.segments{i}.time * abs(cosd(mission.segments{i}.angle));
    elseif strcmp(mission.segments{i}.type, 'vertical_descent') % Vertical descent segment
        altitude_range = abs(mission.segments{i}.altitude(2) - mission.segments{i}.altitude(1));
        if is_fuel(mission.segments{i}.energy)
            errordlg('Not available'); % NOT AVAILABLE
            break;
        elseif is_electric(mission.segments{i}.energy)
            v_i = sqrt(aircraft.performance.dl / 2 / mission.segments{i}.density(2)); % Induced velocity in hover
            if mission.segments{i}.velocity / v_i <= -2 % If this condition is met, the vertical climb equation is used for descent, else, an empirical equation is employed
                pl = 1 / (mission.segments{i}.velocity - aircraft.propulsion.k_i / 2 * (mission.segments{i}.velocity + sqrt(mission.segments{i}.velocity^2 - 2 * aircraft.performance.dl / mission.segments{i}.density(2))) + mission.segments{i}.density(2) * aircraft.propulsion.tip_velocity^3 / aircraft.performance.dl * aircraft.propulsion.ss * aircraft.propulsion.c_d / 8);
            else
                v_d = v_i * (aircraft.propulsion.k_i - 1.125 * mission.segments{i}.velocity / v_i - 1.372 * (mission.segments{i}.velocity / v_i)^2 - 1.718 * (mission.segments{i}.velocity / v_i)^3 - 0.655 * (mission.segments{i}.velocity / v_i)^4); % Induced velocity in descent according to an empirical relation (see lecture slides)
                pl = 1 / (mission.segments{i}.velocity + aircraft.propulsion.k_i * v_d + mission.segments{i}.density(2) * aircraft.propulsion.tip_velocity^3 / aircraft.performance.dl * aircraft.propulsion.ss * aircraft.propulsion.c_d / 8);
            end

            if pl > 0
                mission.segments{i}.mf_batt = altitude_range * constants.g / aircraft.energy.e_spec_batt / aircraft.propulsion.total_efficiency / aircraft.energy.batt_efficiency / aircraft.energy.f_usable_batt / pl / abs(mission.segments{i}.velocity);
            else
                mission.segments{i}.mf_batt = 0;
            end
        end
        mission.segments{i}.time = altitude_range * abs(mission.segments{i}.velocity);
        mission.segments{i}.range = 0;
    elseif strcmp(mission.segments{i}.type, 'landing') % Landing segment
        if is_fuel(mission.segments{i}.energy)
            mission.segments{i}.mf_fuel = 1 - 0.9725;
        elseif is_electric(mission.segments{i}.energy)
            mission.segments{i}.mf_batt = 0;
        end
        mission.segments{i}.range = 0;
    elseif strcmp(mission.segments{i}.type, 'drop') % Drop segment
        mission.segments{i}.range = 0;
    elseif strcmp(mission.segments{i}.type, 'load') % Load segment
        mission.segments{i}.range = 0;
    end
    
    % Accumulate mission parameters
    mission.mf_batt = mission.mf_batt + mission.segments{i}.mf_batt;
    mf_to_minus_fuel = mf_to_minus_fuel * (1 - mission.segments{i}.mf_fuel);
    mission.time = mission.time + mission.segments{i}.time;
    mission.range = mission.range + mission.segments{i}.range;
end

mission.mf_fuel = 1 - mf_to_minus_fuel;

% Iterate over drop and reload mission segments
for i = 1 : length(mission.segments)
    if strcmp(mission.segments{i}.type, 'drop') % Drop segment
        mission.mf_fuel = mission.mf_fuel - accumulate_mf_fuel(mission, i, length(mission.segments)) * mission.segments{i}.mass_drop / aircraft.mass_to;
    end
    if strcmp(mission.segments{i}.type, 'load') % Load segment
        mission.mf_fuel = mission.mf_fuel + accumulate_mf_fuel(mission, i, length(mission.segments)) * mission.segments{i}.mass_reload / aircraft.mass_to;
    end
end

mission.mf_batt = aircraft.energy.reserve_batt * mission.mf_batt;
mission.mf_fuel = aircraft.energy.reserve_fuel * mission.mf_fuel;
aircraft.mass_to = fsolve(@(x)mtow_error(x, mission, aircraft), aircraft.mass_to, optimoptions('fsolve', 'Display','none')); % aircraft.mass_to = aircraft.mass_payload / (1 - mission.mf_struct - mission.mf_subs - mission.mf_prop - mission.mf_fuel - mission.mf_batt);
aircraft.weight_to = aircraft.mass_to * constants.g;

function test = is_fuel(energy)
test = strcmp(energy.type, 'fuel');

function test = is_electric(energy)
test = strcmp(energy.type, 'electric');

function test = is_jet(propulsion)
test = strcmp(propulsion.type, 'jet');

function test = is_prop(propulsion)
test = strcmp(propulsion.type, 'prop');

function mf_fuel = accumulate_mf_fuel(mission, first, last)
mf_fuel = 1;
for i = first : last
    mf_fuel = mf_fuel * (1 - mission.segments{i}.mf_fuel);
end
mf_fuel = 1 - mf_fuel;

function ld = get_ld(performance, segment)
if strcmp(segment.type, 'cruise')
    if is_jet(segment.propulsion)
        ld = 0.886 * performance.ld_max;
    elseif is_prop(segment.propulsion)
        ld = performance.ld_max;
    end
elseif strcmp(segment.type, 'hold')
    if is_jet(segment.propulsion)
        ld = performance.ld_max;
    elseif is_prop(segment.propulsion)
        ld = 0.886 * performance.ld_max;
    end
end

function err = mtow_error(mass_to, mission, aircraft)
err = aircraft.mass_payload / (1 - mission.mf_struct - mission.mf_subs - mission.mf_prop - mission.mf_fuel - mission.mf_batt) - mass_to;