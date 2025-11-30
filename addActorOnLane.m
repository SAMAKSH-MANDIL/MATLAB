function addActorOnLane(rrApp, rrProj, sceneName, scenarioName)
% addActorOnLane
%   - Uses latest RRHD from your project
%   - Picks a driving forward lane
%   - Spawns a vehicle on that lane
%   - Builds a route that exactly follows the lane geometry
%   - Validates & simulates the scenario
%
%   rrApp        : roadrunner object (RoadRunner Scenario)
%   rrProj       : project folder (string)
%   sceneName    : .rrscene filename (already built from same RRHD)
%   scenarioName : .rrscenario filename to save

    arguments
        rrApp
        rrProj       (1,1) string
        sceneName    (1,1) string
        scenarioName (1,1) string
    end

    % ------------------------------------------------------------
    % 1) Get latest RRHD from stack and read HD map
    % ------------------------------------------------------------
    baseRrhdName = getLatestRrhd(rrProj);
    if baseRrhdName == ""
        error("No RRHD available. Pehle roads generateRoadsHdMap se banao.");
    end

    rrhdFileFull = fullfile(rrProj, "Assets", baseRrhdName);
    fprintf("Using RRHD for lanes: %s\n", rrhdFileFull);

    rrMap = roadrunnerHDMap;
    read(rrMap, rrhdFileFull);   % in-place populate

    if isempty(rrMap.Lanes)
        error("RRHD me koi lanes nahi mile. generateRoadsHdMap check karo.");
    end

    % ------------------------------------------------------------
    % 2) Pick a driving forward lane
    % ------------------------------------------------------------
    lanes = rrMap.Lanes;

    laneTypes   = string({lanes.LaneType});
    directions  = string({lanes.TravelDirection});

    idx = find(laneTypes == "Driving" & directions == "Forward", 1);
    if isempty(idx)
        warning("No forward driving lane found. Picking first lane.");
        idx = 1;
    end

    lane = lanes(idx);
    laneGeom = lane.Geometry;   % Nx3 [x y z]

    if size(laneGeom,1) < 2
        error("Chosen lane geometry has less than 2 points.");
    end

    fprintf("Using lane ID '%s' with %d geometry points.\n", ...
        lane.ID, size(laneGeom,1));

    % ------------------------------------------------------------
    % 3) Open scene & create new scenario
    % ------------------------------------------------------------
    fprintf("Opening scene: %s\n", sceneName);
    openScene(rrApp, sceneName);

    fprintf("Creating new scenario...\n");
    newScenario(rrApp);

    rrApi = roadrunnerAPI(rrApp);
    scnro = rrApi.Scenario;
    prj   = rrApi.Project;

    % ------------------------------------------------------------
    % 4) Load vehicle asset
    % ------------------------------------------------------------
    fprintf("Getting vehicle asset...\n");
    carAsset = getAsset(prj, "Vehicles/Sedan.fbx", "VehicleAsset");

    % Spawn exactly at first lane point
    startPos = laneGeom(1,:);   % [x y z]
    fprintf("Spawning actor on lane at [%.2f %.2f %.2f]\n", startPos);

    car = addActor(scnro, carAsset, startPos);

    % InitialPoint just to ensure position matches (no Orientation use)
    ip = car.InitialPoint;
    ip.Position = startPos;

    % ------------------------------------------------------------
    % 5) Build route exactly along lane geometry
    % ------------------------------------------------------------
    fprintf("Creating route along lane geometry...\n");
    rrRoute = ip.Route;

    % Subsample lane geometry to ~30 points so route not over-dense
    N = size(laneGeom,1);
    step = max(floor(N/30), 1);
    idxs = 1:step:N;
    if idxs(end) ~= N
        idxs(end+1) = N;
    end

    for k = 2:numel(idxs)   % first point already at ip
        pt = laneGeom(idxs(k),:);
        addPoint(rrRoute, pt);
    end

    % Mark segments freeform (geometry already on lane, so safe)
    segs = rrRoute.Segments;
    for i = 1:numel(segs)
        segs(i).Freeform = true;
    end
    % NOTE: rrRoute.Segments property is read-only; but elements are
    % handle objects, so in-place modification is enough.

    % ------------------------------------------------------------
    % 6) Validate and simulate
    % ------------------------------------------------------------
    fprintf("Validating scenario...\n");
    validate(scnro);
    fprintf("✅ Scenario validation passed.\n");

    fprintf("Saving scenario as: %s\n", scenarioName);
    saveScenario(rrApp, scenarioName);

    fprintf("Starting simulation...\n");
    simulateScenario(rrApp);
    fprintf("Simulation finished.\n");
end
