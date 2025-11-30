function undoLastScene(rrApp, rrProj, sceneName)
% undoLastScene
%   Pop last rrhd from the stack.
%   - If stack still has at least 1 entry: rebuild scene from new top.
%   - If stack becomes empty: build an EMPTY scene (no roads/objects).
%
%   rrApp     : RoadRunner application handle
%   rrProj    : RoadRunner project folder
%   sceneName : .rrscene filename to save after undo (when possible)

    arguments
        rrApp
        rrProj (1,1) string
        sceneName (1,1) string
    end

    stackFile = fullfile(rrProj, "Assets", "rrhd_stack.mat");
    if ~isfile(stackFile)
        warning("No stack file found. Nothing to undo.");
        return;
    end

    S = load(stackFile,"rrhdStack");
    if ~isfield(S, "rrhdStack") || isempty(S.rrhdStack)
        warning("Stack is empty. Nothing to undo.");
        return;
    end

    stack = S.rrhdStack;

    % ---- Pop last entry ----
    popped = stack{end};
    stack(end) = [];

    % ---- Save updated stack ----
    rrhdStack = stack; %#ok<NASGU>
    save(stackFile,"rrhdStack");

    % ---- Case 1: stack now empty -> build blank scene --------------------
    if isempty(stack)
        fprintf("Undo: removed last '%s'. Stack is now empty. Building blank scene.\n", popped);

        % Create an empty HD map
        emptyMap = roadrunnerHDMap;

        % Overwrite the popped rrhd file with an empty map (so importScene has a file)
        rrhdFileFull = fullfile(rrProj, "Assets", popped);
        write(emptyMap, rrhdFileFull);

        importOpts = roadrunnerHDMapImportOptions(ImportStep="Load");
        importScene(rrApp, rrhdFileFull, "RoadRunner HD Map", importOpts);

        buildScene(rrApp, "RoadRunner HD Map");
        saveScene(rrApp, sceneName);

        fprintf("Blank scene saved as '%s'.\n", sceneName);
        return;
    end

    % ---- Case 2: still at least one rrhd left -> rebuild from new top ----
    latest = stack{end};

    rrhdFileFull = fullfile(rrProj, "Assets", latest);
    importOpts = roadrunnerHDMapImportOptions(ImportStep="Load");
    importScene(rrApp, rrhdFileFull, "RoadRunner HD Map", importOpts);

    buildScene(rrApp, "RoadRunner HD Map");
    saveScene(rrApp, sceneName);

    fprintf("Undo: removed '%s', reverted to '%s', saved scene '%s'\n", ...
        popped, latest, sceneName);
end
