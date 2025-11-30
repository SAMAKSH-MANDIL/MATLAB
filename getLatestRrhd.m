function latest = getLatestRrhd(rrProj)
% getLatestRrhd  Return the newest rrhd filename from stack, or "" if none.

    arguments
        rrProj (1,1) string
    end

    stackFile = fullfile(rrProj, "Assets", "rrhd_stack.mat");

    if ~isfile(stackFile)
        latest = "";
        return;
    end

    S = load(stackFile, "rrhdStack");

    if ~isfield(S,"rrhdStack") || isempty(S.rrhdStack)
        latest = "";
    else
        latest = string(S.rrhdStack{end});
    end
end
