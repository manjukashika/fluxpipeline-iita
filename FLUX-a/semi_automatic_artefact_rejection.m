clearvars;
close all;
clc;

ft_defaults
%% Data Path Setup
data_path  = 'C:\Users\ariha\OneDrive\Desktop\cogitate\data\sss_files';
sub_id     = 'sub-CA103';

epoch_dir  = fullfile(data_path, 'derivatives', 'epoched');
input_file = fullfile(epoch_dir, [sub_id '_ses-1_task-dur_run-01_epo.mat']);

% Load the epoched data
load(input_file, 'data_all');

%% Apply baseline demeaning
% Subtracts mean amplitude of trial (DC offset correction) so the signal centers around 0.
cfg                 = [];
cfg.channel             = {'MEGGRAD'};    % Restrict to the 204 planar gradiometers
cfg.demean              = 'yes';          % Subtract mean baseline amplitude
cfg.baselinewindow      = [-1 0];       % Pre-stimulus baseline interval

data_planar         = ft_preprocessing(cfg, data_all);

%% timeseries
cfg = [];
cfg.viewmode='vertical';
cfg.continuous='no';
cfg.ylim=[ -1e-11  1e-11 ];
cfg.channel = {'MEG01*','MEG05*'};  
ft_databrowser(cfg, data_planar);

%% remove artifacts 
cfg             = [];
cfg.method      = 'summary';
cfg.channel     = 'MEG';
cfg.keepchannel = 'yes'; % Keep channels intact; remove only bad epochs
data_clean      = ft_rejectvisual(cfg, data_all);

%% Save Cleaned Epoched Data
clean_dir = fullfile(data_path, 'derivatives', 'cleaned');
if ~exist(clean_dir, 'dir')
    mkdir(clean_dir);
end

clean_file = fullfile(clean_dir, [sub_id '_ses-1_task-dur_run-01_clean_epo.mat']);
fprintf('Saving cleaned dataset to: %s ...\n', clean_file);

% Use -v7.3 to support large epoched structures
save(clean_file, 'data_clean', '-v7.3');
disp('Cleaned dataset saved successfully.');