clearvars;
close all;
clc;

%% INITIALIZE ENVIRONMENT & LOAD CLEANED DATA
% Initialize FieldTrip defaults and load the visual-rejection cleaned
% dataset saved in the previous step ('data_clean').

addpath('C:\Users\ariha\OneDrive\Desktop\cogitate\fieldtrip');
ft_defaults;

data_path  = 'C:\Users\ariha\OneDrive\Desktop\cogitate\data\sss_files';
sub_id     = 'sub-CA103';

clean_dir  = fullfile(data_path, 'derivatives', 'cleaned');
clean_file = fullfile(clean_dir, [sub_id '_ses-1_task-dur_run-01_clean_epo.mat']);

if ~exist(clean_file, 'file')
    error('Cleaned file does not exist: %s', clean_file);
end

fprintf('Loading cleaned dataset: %s...\n', clean_file);
load(clean_file, 'data_clean');

% In FLUX tutorial terminology, 'planar_rjv1' represents the clean full-rate 
% trials kept after round 1 of visual artifact rejection.
planar_rjv1 = data_clean;

%% DOWNSAMPLING (FOR FAST DECOMPOSITION)

cfg             = [];
cfg.resamplefs  = 200;
fprintf('\n--- Resampling data to 200 Hz ---\n');
planar_resamp   = ft_resampledata(cfg, planar_rjv1);

%% BANDPASS FILTERING & PADDING

cfg          = [];
cfg.hpfreq   = 1;
cfg.lpfreq   = 40;
cfg.padding  = 10.5;   % Trial padding in seconds to suppress filter transients
cfg.padtype  = 'zero';
fprintf('--- Applying 1-40 Hz bandpass filter ---\n');
planar_filt  = ft_preprocessing(cfg, planar_resamp);

%% RANK ESTIMATION FOR SSS/MAXFILTERED DATA

fprintf('--- Calculating data rank after MaxFilter ---\n');
% Using trial 1 covariance to determine the rank
cov_mat   = planar_filt.trial{1} * planar_filt.trial{1}';
data_rank = rank(cov_mat);
fprintf('Effective rank of MaxFiltered data: %d\n', data_rank);

% Optional: Plot singular values to observe the rank cutoff cliff
[~, s, ~] = svd(cov_mat);
figure('Name', 'Singular Value Spectrum');
plot(log10(diag(s)), '-r*', 'LineWidth', 1.2);
xlabel('Component Index');
ylabel('log_{10}(Singular Value)');
title(sprintf('Effective Rank = %d (Look for sharp elbow)', data_rank));
grid on;


%%  ICA DECOMPOSITION (runica / infomax)
% Runs Infomax ICA with natural gradient (Bell & Sejnowski 1995; Amari et al. 1996).
% 'cfg.channel = MEGGRAD' restricts decomposition to the 204 planar gradiometers,
% matching the FLUX tutorial workflow and avoiding cross-sensor scale conflicts.

cfg              = [];
cfg.method       = 'runica';
cfg.channel      = 'MEGGRAD';     % Run on planar gradiometers
cfg.numcomponent = data_rank;     % PCA reduction to true MaxFilter rank before ICA
fprintf('\n--- Launching ft_componentanalysis (%d components) ---\n', data_rank);
planar_comp      = ft_componentanalysis(cfg, planar_filt);

% Save the decomposition immediately (do not repeat this 5-15 min step)
ica_dir = fullfile(data_path, 'derivatives', 'ica');
if ~exist(ica_dir, 'dir'), mkdir(ica_dir); end
comp_file = fullfile(ica_dir, [sub_id '_task-dur_run-01_comp.mat']);
save(comp_file, 'planar_comp', '-v7.3');
fprintf('Decomposition saved to %s\n', comp_file);


%% IDENTIFYING ARTIFACT COMPONENTS (VISUAL INSPECTION)
% View component spatial topographies and time series using ft_databrowser.

cfg             = [];
cfg.viewmode    = 'component';
cfg.continuous  = 'no';
cfg.layout      = 'neuromag306planar.lay';
cfg.channel     = 1:min(20, data_rank);   % Inspect first 20 components first

fprintf('\nOpening ft_databrowser. Note component numbers to reject...\n');
ft_databrowser(cfg, planar_comp);

%% heatmap
%% Plot 2D Topographic Heatmaps of ICA Components
figure('Name', 'ICA Component Topographies (1-20)', 'NumberTitle', 'off', 'Color', 'w');

cfg          = [];
cfg.component = 1:min(20, size(planar_comp.topo, 2)); % Components to plot
cfg.layout   = 'neuromag306planar.lay';               % Layout for planar gradiometers
cfg.comment  = 'auto';                                % Print component number on each map
cfg.colorbar = 'no';                                  % Avoid cluttering the multi-plot grid
cfg.zlim     = 'maxabs';                              % Symmetric color scaling around 0
cfg.colormap = jet;                                   % Standard heatmap palette ('parula' or 'jet')

ft_topoplotIC(cfg, planar_comp);

%% REJECTING COMPONENTS (PROJECTING OUT ARTIFACTS)

cfg             = [];
cfg.component   = [ ]; % <-- ENTER YOUR IDENTIFIED ARTIFACT INDICES HERE
fprintf('Rejecting component(s): %s\n', num2str(cfg.component));

planar_ica = ft_rejectcomponent(cfg, planar_comp, planar_rjv1);


%%  SAVE ICA-CLEANED DATASET
out_clean_file = fullfile(clean_dir, [sub_id '_task-dur_run-01_postica_epo.mat']);
fprintf('Saving post-ICA cleaned data to %s...\n', out_clean_file);
save(out_clean_file, 'planar_ica', '-v7.3');
disp('Done. Ready for ERF condition averaging or secondary artifact screening.');