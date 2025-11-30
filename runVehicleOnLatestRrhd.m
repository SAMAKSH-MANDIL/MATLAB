function runVehicleOnLatestRrhd(rrApp, rrProj, sceneName, scenarioName)
% runVehicleOnLatestRrhd
%   - Take latest RRHD from your stack
%   - Import + build a RoadRunner scene from it
%   - Pick a driving forward lane from that RRHD
%   - Spawn a vehicle ON that lane
%   - Create a route that exactly follows that lane geometry
%   - Validate & simulate in RoadRunner Scenario
%
%   rrApp        : roadrunner object (your existing RRSession app)
%   rrProj       : project folder (string)
%   sceneName    : .rrscene filename to save (from this latest RRHD)
%   scenarioName : .rrscenario filename to save & simulate

    arguments
        rrApp
        rrProj       (1,1) string
        sceneName    (1,1) string
        scenarioName (1,1) string
    end

    %% 1) Get latest RRHD from stack
    baseRrhdName = getLatestRrhd(rrProj);
    if baseRrhdName == ""
        error("No RRHD in stack. Pehle koi rrhd generate karo (roads / OSM).");
    end

    rrhdFull = fullfile(rrProj, "Assets", baseRrhdName);
    fprintf("Latest RRHD from stack: %s\n", rrhdFull);

    %% 2) Read lanes from that RRHD
    rrMap = roadrunnerHDMap;
    read(rrMap, rrhdFull);   % in-place

    if isempty(rrMap.Lanes)
        error("RRHD '%s' me koi lanes nahi mile.", baseRrhdName);
    end

    lanes      = rrMap.Lanes;
    laneTypes  = string({lanes.LaneType});
    directions = string({lanes.TravelDirection});

    % Prefer a forward driving lane
    idx = find(laneTypes == "Driving" & directions == "Forward", 1);
    if isempty(idx)
        warning("No forward Driving lane found. Pehla available lane use kar rahe hain.");
        idx = 1;
    end

    lane     = lanes(idx);
    laneGeom = lane.Geometry;   % Nx3 [x y z]

    if size(laneGeom,1) < 2
        error("Chosen lane geometry has less than 2 points.");
    end

    fprintf("Using lane ID '%s' with %d geometry points.\n", ...
        lane.ID, size(laneGeom,1));

    %% 3) Import RRHD into RoadRunner & build scene
    fprintf("Importing RRHD and building scene '%s'...\n", sceneName);

    importOpts = roadrunnerHDMapImportOptions(ImportStep="Load");
    importScene(rrApp, rrhdFull, "RoadRunner HD Map", importOpts);

    buildScene(rrApp, "RoadRunner HD Map");
    saveScene(rrApp, sceneName);

    %% 4) Create new scenario on this scene
    fprintf("Opening scene and creating scenario...\n");
    openScene(rrApp, sceneName);
    newScenario(rrApp);

    rrApi = roadrunnerAPI(rrApp);
    scnro = rrApi.Scenario;
    prj   = rrApi.Project;

    %% 5) Load vehicle asset & spawn on lane start
    fprintf("Getting vehicle asset...\n");
    carAsset = getAsset(prj, "Vehicles/Sedan.fbx", "VehicleAsset");

    startPos = laneGeom(1,:);   % exact first point of lane
    fprintf("Spawning actor on lane at [%.2f %.2f %.2f]\n", startPos);

    car = addActor(scnro, carAsset, startPos);

    % Ensure initial point position is exactly on lane start
    ip = car.InitialPoint;
    ip.Position = startPos;

    %% 6) Build route along lane geometry
    fprintf("Creating route along lane geometry...\n");
    rrRoute = ip.Route;

    % Subsample lane geometry to keep reasonable number of points
    N    = size(laneGeom,1);
    step = max(floor(N/30), 1);       % ~30 waypoints
    idxs = 1:step:N;
    if idxs(end) ~= N
        idxs(end+1) = N;
    end

    for k = 2:numel(idxs)   % first point already at ip.Position
        pt = laneGeom(idxs(k),:);
        addPoint(rrRoute, pt);
    end

    % Mark segments freeform so we don't get route-graph errors
    segs = rrRoute.Segments;
    for i = 1:numel(segs)
        segs(i).Freeform = true;
    end
    % NOTE: rrRoute.Segments is read-only; elements are handle objects.

    %% 7) Validate and simulate
    fprintf("Validating scenario...\n");
    validate(scnro);
    fprintf("✅ Scenario validation passed.\n");

    fprintf("Saving scenario as: %s\n", scenarioName);
    saveScenario(rrApp, scenarioName);

    fprintf("Starting simulation...\n");
    simulateScenario(rrApp);
    fprintf("Simulation finished.\n");
end
