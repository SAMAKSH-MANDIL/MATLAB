function generateRoadsHdMap(rrApp, rrProj, rrhdName, sceneName, ...
                            roadCenters, laneWidth, numLanesForward, numLanesBackward)
% generateRoadsHdMap
%   Create or extend a RoadRunner HD Map with multi-lane roads and
%   build/save a .rrscene in RoadRunner.
%
%   ✅ If a previous RRHD exists in the stack:
%      - It is loaded first
%      - New roads are APPENDED (old static objects / roads remain)
%
%   ✅ If no RRHD exists yet:
%      - A new empty map is created
%
%   rrApp           : RoadRunner application object (already running)
%   rrProj          : RoadRunner project folder (string)
%   rrhdName        : NEW rrhd output filename, e.g. "Roads_01.rrhd"
%   sceneName       : .rrscene filename to save
%   roadCenters     : Nx2 or Nx3 [x y (z)] points for road centerline
%   laneWidth       : per-lane width (meters), e.g. 3.5
%   numLanesForward : # of lanes in Forward direction
%   numLanesBackward: # of lanes in Backward direction

    arguments
        rrApp
        rrProj (1,1) string
        rrhdName (1,1) string
        sceneName (1,1) string
        roadCenters double
        laneWidth (1,1) double = 3.5
        numLanesForward (1,1) double = 1
        numLanesBackward (1,1) double = 1
    end

    % -------- Normalize roadCenters to [x y z] -----------------------------
    if size(roadCenters,2) == 2
        rc = [roadCenters, zeros(size(roadCenters,1),1)];
    elseif size(roadCenters,2) == 3
        rc = roadCenters;
    else
        error("roadCenters must be Nx2 or Nx3.");
    end

    if size(rc,1) < 2
        error("roadCenters should have at least 2 points.");
    end

    rc2d = rc(:,1:2);  % only x,y for offset computation

    % Total lanes
    nb = numLanesBackward;
    nf = numLanesForward;
    nTotal = nb + nf;

    if nTotal == 0
        error("At least one lane is required.");
    end

    % -------- 1) Load existing RRHD (if any) -------------------------------
    baseRrhdName = getLatestRrhd(rrProj);

    rrMap = roadrunnerHDMap;

    if baseRrhdName == ""
        fprintf("No existing RRHD found. Starting roads from empty HD map.\n");
    else
        baseFull = fullfile(rrProj, "Assets", baseRrhdName);
        fprintf("Reading base RRHD (for roads): %s\n", baseFull);
        read(rrMap, baseFull);   % in-place
    end

    % Existing counts (for appending)
    if isempty(rrMap.LaneBoundaries)
        existingB = 0;
    else
        existingB = numel(rrMap.LaneBoundaries);
    end

    if isempty(rrMap.Lanes)
        existingL = 0;
    else
        existingL = numel(rrMap.Lanes);
    end

    % -------- 2) Compute boundary offsets for THIS corridor ----------------
    % Backward side:  0, -W, -2W, ..., -nb*W
    % Forward side:   0, +W, +2W, ..., +nf*W
    backOffsets  = -laneWidth*(0:nb);
    fwdOffsets   =  laneWidth*(0:nf);
    allOffsets   = unique([backOffsets, fwdOffsets]); % sorted
    nBoundaries  = numel(allOffsets);

    % -------- 3) Ensure space for new LaneBoundaries ----------------------
    if existingB == 0
        rrMap.LaneBoundaries(nBoundaries,1) = roadrunner.hdmap.LaneBoundary;
    else
        rrMap.LaneBoundaries(existingB + nBoundaries,1) = roadrunner.hdmap.LaneBoundary;
    end

    % Build new boundaries at indices (existingB+1) .. (existingB+nBoundaries)
    for b = 1:nBoundaries
        off = allOffsets(b);
        idxGlob = existingB + b;
        id  = "B" + string(idxGlob);   % global unique ID

        pts2d = offsetPolyline(rc2d, off);
        pts3d = [pts2d, rc(:,3)];

        rrMap.LaneBoundaries(idxGlob).ID       = id;
        rrMap.LaneBoundaries(idxGlob).Geometry = pts3d;
    end

    % Helper: offset -> global boundary index
    function idxGlob = boundaryIndexForOffset(offset)
        localIdx = find(abs(allOffsets - offset) < 1e-9, 1);
        if isempty(localIdx)
            error("Boundary offset %.3f not found.", offset);
        end
        idxGlob = existingB + localIdx;  % shift by existing count
    end

    % -------- 4) Ensure space for new Lanes -------------------------------
    if existingL == 0
        rrMap.Lanes(nTotal,1) = roadrunner.hdmap.Lane;
    else
        rrMap.Lanes(existingL + nTotal,1) = roadrunner.hdmap.Lane;
    end

    % -------- 5) Build new Lanes and link to new boundaries ---------------
    laneIdxLocal = 0;

    % ---- Backward lanes: center offsets < 0
    for k = 1:nb
        laneIdxLocal = laneIdxLocal + 1;

        centerOffset = -(k - 0.5)*laneWidth;       % e.g. -1.75, -5.25, ...
        leftOff      = centerOffset - laneWidth/2; % more negative
        rightOff     = centerOffset + laneWidth/2; % closer to 0

        lane2d = offsetPolyline(rc2d, centerOffset);
        lane3d = [lane2d, rc(:,3)];

        laneIdxGlob = existingL + laneIdxLocal;
        L = rrMap.Lanes(laneIdxGlob);

        L.ID              = "BwdLane" + string(laneIdxGlob);
        L.Geometry        = lane3d;
        L.TravelDirection = "Backward";
        L.LaneType        = "Driving";

        leftIdx  = boundaryIndexForOffset(leftOff);
        rightIdx = boundaryIndexForOffset(rightOff);

        % Pass boundary ID string
        leftBoundary (L, rrMap.LaneBoundaries(leftIdx).ID,  Alignment="Forward");
        rightBoundary(L, rrMap.LaneBoundaries(rightIdx).ID, Alignment="Forward");

        rrMap.Lanes(laneIdxGlob) = L;
    end

    % ---- Forward lanes: center offsets > 0
    for k = 1:nf
        laneIdxLocal = laneIdxLocal + 1;

        centerOffset = +(k - 0.5)*laneWidth;       % e.g. +1.75, +5.25, ...
        leftOff      = centerOffset - laneWidth/2; % closer to 0
        rightOff     = centerOffset + laneWidth/2; % more positive

        lane2d = offsetPolyline(rc2d, centerOffset);
        lane3d = [lane2d, rc(:,3)];

        laneIdxGlob = existingL + laneIdxLocal;
        L = rrMap.Lanes(laneIdxGlob);

        L.ID              = "FwdLane" + string(laneIdxGlob);
        L.Geometry        = lane3d;
        L.TravelDirection = "Forward";
        L.LaneType        = "Driving";

        leftIdx  = boundaryIndexForOffset(leftOff);
        rightIdx = boundaryIndexForOffset(rightOff);

        leftBoundary (L, rrMap.LaneBoundaries(leftIdx).ID,  Alignment="Forward");
        rightBoundary(L, rrMap.LaneBoundaries(rightIdx).ID, Alignment="Forward");

        rrMap.Lanes(laneIdxGlob) = L;
    end

    % -------- 6) Write NEW RRHD and update stack --------------------------
    rrhdFileFull = fullfile(rrProj, "Assets", rrhdName);
    write(rrMap, rrhdFileFull);
    fprintf("Roads RRHD written: %s\n", rrhdFileFull);

    pushRrhd(rrProj, rrhdName);

    % -------- 7) Import, build, save scene in RoadRunner ------------------
    importOpts = roadrunnerHDMapImportOptions(ImportStep="Load");
    importScene(rrApp, rrhdFileFull, "RoadRunner HD Map", importOpts);

    buildScene(rrApp, "RoadRunner HD Map");
    saveScene(rrApp, sceneName);

    fprintf("Scene built and saved as: %s\n", sceneName);
end

% =====================================================================
% Local helper: offset polyline by a lateral distance using normals
% =====================================================================
function ptsOut = offsetPolyline(pts, offset)
% pts: Nx2 [x y], offset: scalar (meters, left/right)
% ptsOut: Nx2

    n = size(pts,1);
    if n < 2
        ptsOut = pts;
        return;
    end

    % Directions of segments
    dirs = diff(pts,1,1);         % (n-1)x2
    segLen = sqrt(sum(dirs.^2,2));
    segLen(segLen == 0) = 1;      % avoid div by zero
    dirs = dirs ./ segLen;

    % Normals (rotate 90 degrees left)
    normals = [-dirs(:,2), dirs(:,1)];

    % Per-point normals = average of neighboring segment normals
    nrmPts = zeros(n,2);
    nrmPts(1,:)   = normals(1,:);
    nrmPts(end,:) = normals(end,:);
    if n > 2
        for i = 2:n-1
            nrmPts(i,:) = normals(i-1,:) + normals(i,:);
        end
    end

    % Normalize per-point normals
    lens = sqrt(sum(nrmPts.^2,2));
    lens(lens == 0) = 1;
    nrmPts = nrmPts ./ lens;

    % Apply offset
    ptsOut = pts + offset * nrmPts;
end
