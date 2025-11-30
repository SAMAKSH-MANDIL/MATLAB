function pushRrhd(rrProj, rrhdName)
% pushRrhd  Push an rrhd file name onto the stack for this project.

    arguments
        rrProj (1,1) string
        rrhdName (1,1) string
    end

    stack = loadRrhdStack(rrProj);
    stack{end+1} = char(rrhdName);
    saveRrhdStack(rrProj, stack);
end

% ---------------- Local helpers ----------------
function stack = loadRrhdStack(rrProj)
    stackFile = fullfile(rrProj, "Assets", "rrhd_stack.mat");
    if isfile(stackFile)
        S = load(stackFile, "rrhdStack");
        if isfield(S, "rrhdStack")
            stack = S.rrhdStack;
        else
            stack = {};
        end
    else
        stack = {};
    end
end

function saveRrhdStack(rrProj, stack)
    stackFile = fullfile(rrProj, "Assets", "rrhd_stack.mat");
    rrhdStack = stack; 
    save(stackFile, "rrhdStack");
end
