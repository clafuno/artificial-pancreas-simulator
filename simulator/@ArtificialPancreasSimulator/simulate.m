function simulate(this, patientIndexes)
%SIMULATE  Simulate a virtual population of type 1 diabetes patients.
%   SIMULATE() performs a fresh simulation of the virtual population
%   defined by the simulator configuration and displays the results to the
%   user using the specified results manager. The results can also be
%   accessed through the simulator's read-only public properties.
%
%   patientIndex: optional input to specify index of patient to run.
%

if this.options.interactiveSimulation
    error('This method is disabled during interactive simulation.');
end

if nargin < 2
   patientIndexes = 1:numel(this.patients);
end

if ~this.firstSimulation
    this.reset(patientIndexes);
end
this.firstSimulation = false;

patients = this.patients;
primaryControllers = this.primaryControllers;
secondaryControllers = this.secondaryControllers;
resultsManagers = this.resultsManagers;

stepsPerPatient = this.options.simulationDuration ./ this.options.simulationStepSize;

if nargin < 2 && this.options.parallelExecution
    packetSize = 32;
    totalSteps = numel(this.patients) .* stepsPerPatient;
    progressbar = parfor_progressbar(totalSteps, 'Simulation in progress...');
    for parallelIndex = 1:ceil(numel(this.patients)./packetSize)
        startIndex = (parallelIndex - 1) .* packetSize + 1;
        endIndex = min(parallelIndex.*packetSize, numel(this.patients));
        parfor i = startIndex:endIndex
            [patients{i}, primaryControllers{i}, secondaryControllers{i}, resultsManagers{i}] = ...
                simulatePatient(this, progressbar, i);
        end
    end
    progressbar.close();
else
    totalSteps = numel(patientIndexes) .* stepsPerPatient;
    progressbar = for_progressbar(totalSteps, 'Simulation in progress...');
    for i = patientIndexes(:)'
        [patients{i}, primaryControllers{i}, secondaryControllers{i}, resultsManagers{i}] = ...
            simulatePatient(this, progressbar, i);
    end
    progressbar.close();
end

this.patients = patients;
this.primaryControllers = primaryControllers;
this.secondaryControllers = secondaryControllers;
this.resultsManagers = resultsManagers;

if ~isempty(this.resultsManagerOptions)
    eval([class(this.resultsManagers{1}), ...
        '.displayResults(this.resultsManagers, this.resultsManagerOptions);']);
else
    eval([class(this.resultsManagers{1}), ...
        '.displayResults(this.resultsManagers);']);
end

end

function [patient, primaryController, secondaryController, resultsManager] = ...
    simulatePatient(this, progressbar, patientIndex)
%SIMULATEPATIENT  Simulate a single virtual patient.

patient = this.patients{patientIndex};
primaryController = this.primaryControllers{patientIndex};
secondaryController = this.secondaryControllers{patientIndex};
resultsManager = this.resultsManagers{patientIndex};

time = this.options.simulationStartTime;

glucoseMeasurement = patient.getGlucoseMeasurement();
resultsManager.addGlucoseMeasurement(time, glucoseMeasurement);

while time < this.options.simulationStartTime + this.options.simulationDuration
    primaryInfusions = primaryController.getInfusions(time);
    resultsManager.addPrimaryInfusions(time, primaryInfusions);
    primaryController.setInfusions(time, primaryInfusions);
    
    if ~isempty(secondaryController)
        secondaryInfusions = secondaryController.getInfusions(time);
        resultsManager.addSecondaryInfusions(time, secondaryInfusions);
        secondaryController.setInfusions(time, primaryInfusions);
    end
    
    patient.updateState(time, time+this.options.simulationStepSize, primaryInfusions);
    time = time + this.options.simulationStepSize;
    progressbar.iterate(1);
    
    glucoseMeasurement = patient.getGlucoseMeasurement();
    resultsManager.addGlucoseMeasurement(time, glucoseMeasurement);
end

end
