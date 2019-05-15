function configurePaths()
%CONFIGUREPATHS  Configure the simulator's paths.

paths = getLibraryPaths();
for i = 1:numel(paths)
    addpath(genpath(paths{i}));
end

end
