function generateStaticScene(rrApp, rrProj, rrhdName, sceneName, ...
                             X, Y, Z, assetPath, objectIDPrefix)
% generateStaticScene
%   1) If a previous RRHD exists in stack, read it (roads / older objects)
%      Otherwise start from an empty HD map.
%   2) Append static objects of a given type
%   3) Write new RRHD (rrhdName) and push to stack
%   4) Import & build scene in RoadRunner, save sceneName
%
%   rrApp          : RoadRunner application object (already running)
%   rrProj         : RoadRunner project folder
%   rrhdName       : NEW rrhd filename, e.g. "Trees_01.rrhd"
%   sceneName      : output .rrscene filename
%   X,Y,Z          : column vectors of positions (meters)
%   assetPath      : project-relative asset path, e.g. "Assets/Props/trees/CalPalm_Half_Sm02.fbx_rrx"
%   objectIDPrefix : prefix for object IDs, e.g. "Tree" / "Bldg"

    arguments
        rrApp
        rrProj (1,1) string
        rrhdName (1,1) string
        sceneName (1,1) string
        X (:,1) double
        Y (:,1) double
        Z (:,1) double
        assetPath (1,1) string
        objectIDPrefix (1,1) string
    end

    % ----------------- 1) Load base RRHD (if any) -------------------------
    baseRrhdName = getLatestRrhd(rrProj);

    rrMap = roadrunnerHDMap;

    if baseRrhdName == ""
        % No existing RRHD => start from empty map (only static objects)
        fprintf("No existing RRHD found. Starting from empty HD map.\n");
    else
        % Existing RRHD => read it and add on top (roads + previous objects)
        baseFull = fullfile(rrProj, "Assets", baseRrhdName);
        fprintf("Reading base RRHD: %s\n", baseFull);
        read(rrMap, baseFull);   % in-place read, no output
    end

    % ----------------- 2) Add StaticObjectType (if needed) ----------------
    typeID  = objectIDPrefix + "Type";
    relPath = roadrunner.hdmap.RelativeAssetPath(AssetPath = assetPath);

    newType = roadrunner.hdmap.StaticObjectType( ...
        ID        = typeID, ...
        AssetPath = relPath);

    if isempty(rrMap.StaticObjectTypes)
        rrMap.StaticObjectTypes = newType;
    else
        existingIDs = string({rrMap.StaticObjectTypes.ID});
        if ~any(existingIDs == typeID)
            rrMap.StaticObjectTypes(end+1) = newType;
        end
    end

    % ----------------- 3) Append StaticObjects ----------------------------
    numNew = numel(X);
    if isempty(rrMap.StaticObjects)
        startIdx = 0;
    else
        startIdx = numel(rrMap.StaticObjects);
    end

    ref = roadrunner.hdmap.Reference(ID = typeID);

    rrMap.StaticObjects(startIdx + (1:numNew),1) = roadrunner.hdmap.StaticObject;

    for k = 1:numNew
        idx = startIdx + k;

        geom = roadrunner.hdmap.GeoOrientedBoundingBox;
        geom.Center         = [X(k) Y(k) Z(k)];
        geom.Dimension      = [4 4 4];   % asset ke hisaab se adjust karo
        geom.GeoOrientation = [0 0 0];

        rrMap.StaticObjects(idx) = roadrunner.hdmap.StaticObject( ...
            ID                  = objectIDPrefix + string(idx), ...
            Geometry            = geom, ...
            ObjectTypeReference = ref);
    end

    % ----------------- 4) Write new RRHD & push to stack ------------------
    outFull = fullfile(rrProj,"Assets",rrhdName);
    write(rrMap, outFull);
    fprintf("Written new RRHD: %s\n", outFull);

    pushRrhd(rrProj, rrhdName);

    % ----------------- 5) Import & build scene ----------------------------
    importOpts = roadrunnerHDMapImportOptions(ImportStep = "Load");
    importScene(rrApp, outFull, "RoadRunner HD Map", importOpts);

    buildScene(rrApp, "RoadRunner HD Map");
    saveScene(rrApp, sceneName);

    fprintf("Scene saved as: %s\n", sceneName);
end
