function spawnVehiclesOnLane(rrApp, rrProj, sceneName, scenarioName, numVehicles, spawnPositions)
% spawnVehiclesOnLane
%   - Uses latest RRHD from stack
%   - Picks a forward Driving lane (or first lane if none)
%   - Spawns multiple vehicles
%   - Supports:
%       (A) User-given spawn coordinates (world coords)
%       (B) Auto-placing vehicles along the lane
%       (C) Hybrid: some manual, remaining auto
%   - For each vehicle, builds a default route along the lane geometry
%   - Validates & simulates the scenario
%
%   rrApp        : RoadRunner application object
%   rrProj       : project folder (string)
%   sceneName    : .rrscene filename (already built from same RRHD)
%   scenarioName : .rrscenario filename to save
%   numVehicles  : total number of vehicles (scalar int, default = 1)
%   spawnPositions : (optional) Mx2 or Mx3 [x y (z)] world coordinates
%                    - One vehicle per row
%                    - If M < numVehicles, remaining vehicles auto-place
%                    - If M > numVehicles, error

    arguments
        rrApp
        rrProj       (1,1) string
        sceneName    (1,1) string
        scenarioName (1,1) string
        numVehicles  (1,1) double {mustBeInteger,mustBePositive} = 1
        spawnPositions double = []
    end

    % ------------------------------------------------------------
    % 1) Get latest RRHD and read HD map
    % ------------------------------------------------------------
    baseRrhdName = getLatestRrhd(rrProj);
    if baseRrhdName == ""
        error("No RRHD available. Pehle rrhd generate karo (roads / OSM).");
    end

    rrhdFileFull = fullfile(rrProj, "Assets", baseRrhdName);
    fprintf("Using RRHD: %s\n", rrhdFileFull);

    rrMap = roadrunnerHDMap;
    read(rrMap, rrhdFileFull);

    if isempty(rrMap.Lanes)
        error("RRHD me koi lanes nahi mile.");
    end

    % ------------------------------------------------------------
    % 2) Pick a forward Driving lane
    % ------------------------------------------------------------
    lanes      = rrMap.Lanes;
    laneTypes  = string({lanes.LaneType});
    directions = string({lanes.TravelDirection});

    idx = find(laneTypes == "Driving" & directions == "Forward", 1);
    if isempty(idx)
        warning("Forward Driving lane nahi mila. Pehla lane use kar rahe hain.");
        idx = 1;
    end

    lane     = lanes(idx);
    laneGeom = lane.Geometry;   % Nx3 [x y z]

    N = size(laneGeom,1);
    if N < 2
        error("Chosen lane geometry has less than 2 points.");
    end

    fprintf("Using lane ID '%s' with %d geometry points.\n", lane.ID, N);

    % ------------------------------------------------------------
    % 3) Normalize user-provided spawnPositions (if any)
    % ------------------------------------------------------------
    if ~isempty(spawnPositions)
        % Ensure [x y z]
        if size(spawnPositions,2) == 2
            spawnPositions = [spawnPositions, zeros(size(spawnPositions,1),1)];
        elseif size(spawnPositions,2) ~= 3
            error("spawnPositions must be Mx2 or Mx3.");
        end

        M = size(spawnPositions,1);  % number of manual spawn points
        Nreq = numVehicles;          % total vehicles requested

        if M > Nreq
            error("You provided %d spawn positions but numVehicles is only %d.", M, Nreq);
        elseif M < Nreq
            fprintf("Only %d spawn positions provided. Remaining %d vehicles will auto-spawn on lane.\n", ...
                M, Nreq - M);
        else
            fprintf("Using %d user-defined spawn positions (matches numVehicles).\n", M);
        end

        Mmanual = M;
    else
        fprintf("No spawnPositions given. Auto-placing %d vehicles on lane.\n", numVehicles);
        Mmanual = 0;
    end

    % ------------------------------------------------------------
    % 4) Open scene & create new scenario
    % ------------------------------------------------------------
    fprintf("Opening scene: %s\n", sceneName);
    openScene(rrApp, sceneName);

    fprintf("Creating new scenario...\n");
    newScenario(rrApp);

    rrApi = roadrunnerAPI(rrApp);
    scnro = rrApi.Scenario;
    prj   = rrApi.Project;

    % ------------------------------------------------------------
    % 5) Load vehicle asset
    % ------------------------------------------------------------
    fprintf("Getting vehicle asset...\n");
    carAsset = getAsset(prj, "Vehicles/Sedan.fbx", "VehicleAsset");

    % ------------------------------------------------------------
    % 6) Build final list of spawn positions (manual + auto)
    % ------------------------------------------------------------
    vehicleStartPos = zeros(numVehicles, 3);

    % 6a) Fill manual spawn positions first (if any)
    if Mmanual > 0
        vehicleStartPos(1:Mmanual, :) = spawnPositions;
    end

    % 6b) Auto-place remaining vehicles on lane
    remainingCount = numVehicles - Mmanual;
    if remainingCount > 0
        autoIdxs = round(linspace(1, max(N-1,2), remainingCount));
        for k = 1:remainingCount
            vehicleStartPos(Mmanual + k, :) = laneGeom(autoIdxs(k), :);
        end
    end

    % ------------------------------------------------------------
    % 7) For each vehicle: spawn + build default route along lane
    % ------------------------------------------------------------
    for c = 1:numVehicles
        startPos = vehicleStartPos(c,:);

        % Find nearest lane point in XY to anchor the route start
        diffs = laneGeom(:,1:2) - startPos(1:2);
        d2    = sum(diffs.^2, 2);
        [~, sIdx] = min(d2);   % nearest index on lane

        fprintf("Vehicle %d spawn at [%.2f %.2f %.2f], nearest laneIdx = %d\n", ...
            c, startPos, sIdx);

        % Spawn actor
        car = addActor(scnro, carAsset, startPos);

        % Set InitialPoint
        ip = car.InitialPoint;
        ip.Position = startPos;

        % Build route from sIdx to end of lane
        rrRoute = ip.Route;

        step = max(floor((N - sIdx + 1)/30), 1);   % ~30 waypoints
        idxs = sIdx:step:N;
        if idxs(end) ~= N
            idxs(end+1) = N;
        end

        for k = 2:numel(idxs)
            pt = laneGeom(idxs(k), :);
            addPoint(rrRoute, pt);
        end

        % Mark segments as Freeform so they follow geometry directly
        segs = rrRoute.Segments;
        for i = 1:numel(segs)
            segs(i).Freeform = true;
        end
    end

    % ------------------------------------------------------------
    % 8) Validate and simulate
    % ------------------------------------------------------------
    fprintf("Validating scenario with %d vehicles...\n", numVehicles);
    validate(scnro);
    fprintf("✅ Scenario validation passed.\n");

    fprintf("Saving scenario as: %s\n", scenarioName);
    saveScenario(rrApp, scenarioName);

    fprintf("Starting simulation...\n");
    simulateScenario(rrApp);
    fprintf("Simulation finished.\n");
end
