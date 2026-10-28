clearvars;
close all;
clc;

addpath('C:\Users\ariha\OneDrive\Desktop\cogitate\fieldtrip');
ft_defaults

data_path = 'C:\Users\ariha\OneDrive\Desktop\cogitate\data\sss_files';

%% Define Subject ID matching your file convention
sub_id = 'sub-CA103';

%% Search for the Subject's Files
% Matches: sub-CA103_ses-1_task-dur_run-01_raw_sss.fif, run-02, etc.
file_pattern = fullfile(data_path, [sub_id, '*sss*.fif']);
sss_files    = dir(file_pattern);

%% Verify and Display Results
if isempty(sss_files)
    error('Still cannot find files for %s in: %s', sub_id, data_path);
else
    fprintf('Found %d file(s) for %s:\n', length(sss_files), sub_id);
    for k = 1:length(sss_files)
        fprintf('  [%d] %s\n', k, sss_files(k).name);
    end
end
%% Inspect Events First (Run once to check values)
dataset_file = fullfile(sss_files(1).folder, sss_files(1).name);
events       = ft_read_event(dataset_file);
sti_events   = events(strcmp({events.type}, 'STI101'));
disp('Detected trigger codes in file:');
disp(unique([sti_events.value]));

%% Define Trials
cfg                         = [];
cfg.dataset                 = dataset_file;
cfg.trialdef.eventtype      = 'STI101';  %primary line 16-bit physical digital trigger


cfg.trialdef.eventvalue     = [201 202 203];  % Relevant target, irrelevant, non-target      
% cogitate has used 3.5s epoch
cfg.trialdef.prestim        = 1.0;    
cfg.trialdef.poststim       = 2.5;      
cfg                         = ft_definetrial(cfg);

%% complete
data_all = ft_preprocessing(cfg);

%% Set up output directory
out_dir = fullfile(data_path, 'derivatives', 'epoched');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

% Save epoched data structure (-v7.3 supports large arrays > 2GB)
out_file = fullfile(out_dir, [sub_id '_ses-1_task-dur_run-01_epo.mat']);
fprintf('\nSaving epoched data to %s...\n', out_file);
save(out_file, 'data_all', '-v7.3');
disp('Saved successfully.');