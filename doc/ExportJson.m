% MatLab script to write JSON data from NervousSystem.mat to data.json.
% data.json contains the same data as in trackingNeuroblastCurated in a nested
% array. Requires MatLab R2016b.

load NervousSystem.mat;
fileID = fopen('data.json', 'w');
jsonString = jsonencode(trackingNeuroblastCurated);
fprintf(fileID, jsonString);
fclose(fileID);
