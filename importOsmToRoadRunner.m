function importOsmToRoadRunner(rrApp, rrProj, centerLat, centerLon, extentMeters, rrhdName, sceneName)
% importOsmToRoadRunner
%   Download an OSM map around (lat,lon), import to drivingScenario,
%   convert to RoadRunner HD Map, and build a RoadRunner scene.
%
%   rrApp        : existing roadrunner object
%   rrProj       : RoadRunner project folder (string)
%   centerLat    : center latitude (deg)
%   centerLon    : center longitude (deg)
%   extentMeters : half-width of square ROI (meters)
%   rrhdName     : output .rrhd filename, e.g. "OSM_01.rrhd"
%   sceneName    : output .rrscene filename, e.g. "OSM_01.rrscene"
%
%   Requires: Automated Driving Toolbox + internet access.

    arguments
        rrApp
        rrProj       (1,1) string
        centerLat    (1,1) double
        centerLon    (1,1) double
        extentMeters (1,1) double
        rrhdName     (1,1) string
        sceneName    (1,1) string
    end

    %% 1) Build OSM ROI URL from center + extent
    mapParams = buildOsmROI(centerLat, centerLon, extentMeters);
    osmURL    = mapParams.osmUrl;

    fprintf("Downloading OSM from:\n%s\n", osmURL);

    osmFile = fullfile(tempdir, "roadrunner_osm_import.osm");
    opts    = weboptions(ContentType="xml");

    websave(osmFile, osmURL, opts);
    fprintf("Saved OSM to: %s\n", osmFile);

    %% 2) Import into drivingScenario from OSM
    fprintf("Creating drivingScenario from OSM...\n");
    scenario = drivingScenario;
    roadNetwork(scenario, "OpenStreetMap", osmFile);

    %% 3) Convert to RoadRunner HD Map
    fprintf("Converting drivingScenario to RoadRunner HD Map...\n");
    rrMap = getRoadRunnerHDMap(scenario);

    rrhdFull = fullfile(rrProj, "Assets", rrhdName);
    write(rrMap, rrhdFull);
    fprintf("Written RRHD: %s\n", rrhdFull);

    % 🔥 Push into your RRHD stack (uses your existing pushRrhd.m)
    try
        pushRrhd(rrProj, rrhdName);
        fprintf("Pushed '%s' to RRHD stack.\n", rrhdName);
    catch ME
        % If stack tools are missing / error, just warn and continue
        warning('%s: %s', ME.identifier, ME.message);
    end

    %% 4) Import into RoadRunner and build scene
    fprintf("Importing RRHD into RoadRunner and building scene...\n");

    importOpts = roadrunnerHDMapImportOptions(ImportStep="Load");
    importScene(rrApp, rrhdFull, "RoadRunner HD Map", importOpts);

    buildScene(rrApp, "RoadRunner HD Map");
    saveScene(rrApp, sceneName);

    fprintf("✅ OSM map imported and scene saved as: %s\n", sceneName);
end

% -------------------------------------------------------------------------
% Local helper: buildOsmROI
%   Computes a bbox around (lat,lon) and returns an Overpass-style URL
% -------------------------------------------------------------------------
function params = buildOsmROI(centerLat, centerLon, extentMeters)
% extentMeters: half-size of ROI square (so total width = 2*extentMeters)

    % Rough meters -> degrees conversion
    metersPerDegLat = 111320;                % approx
    metersPerDegLon = 111320 * cosd(centerLat);

    dLat = extentMeters / metersPerDegLat;
    dLon = extentMeters / metersPerDegLon;

    latMin = centerLat - dLat;
    latMax = centerLat + dLat;
    lonMin = centerLon - dLon;
    lonMax = centerLon + dLon;

    % Overpass API bounding box URL
    % bbox = lonMin,latMin,lonMax,latMax
    osmUrl = sprintf("https://overpass-api.de/api/map?bbox=%.7f,%.7f,%.7f,%.7f", ...
                      lonMin, latMin, lonMax, latMax);

    params = struct();
    params.latMin = latMin;
    params.latMax = latMax;
    params.lonMin = lonMin;
    params.lonMax = lonMax;
    params.osmUrl = osmUrl;
end
