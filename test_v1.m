% 1) Make sure functions are visible
addpath("C:\code\Research\MATLAB");

% 2) Start RoadRunner on your project
rrProj = "C:\Users\samak\OneDrive\Documents\SIH_V1\New RoadRunner Project";
rrApp  = roadrunner(ProjectFolder=rrProj);

% 3) Share engine with a name
matlab.engine.shareEngine("RRSession");

disp("Engine shared as RRSession, RoadRunner connected.");
