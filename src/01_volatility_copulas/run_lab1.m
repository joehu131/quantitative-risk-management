%% Quantitative Financial Risk Analytics: Module 1
% Descriptive Statistics, Volatility Estimation (EWMA & GARCH), and Copula Modeling
%
% Assets Analyzed:
%   - USD/SEK (Daily and Weekly Exchange Rates)
%   - EUR/SEK (Daily and Weekly Exchange Rates)
%
% Methodology:
%   1. Descriptive statistics, annualized volatility, skewness, excess kurtosis, Q-Q plots
%   2. Volatility dynamics: EqWMA (30w, 90w), EWMA (RiskMetrics & MLE), GARCH(1,1) with & without Variance Targeting
%   3. Standardized residual analysis and bivariate copula estimation (Gaussian, Student-t, Gumbel, Clayton, Frank)
%   4. One-week ahead volatility forecasting and joint return scenario simulation

clear;
close all;
clc;

%% 1. Load Data and Calculate Log-Returns
% Dynamically resolve path to data directory
script_dir = fileparts(mfilename('fullpath'));
data_path = fullfile(script_dir, '..', '..', 'data', 'fx_rates.xlsx');

if ~isfile(data_path)
    error('Data file not found at: %s', data_path);
end

DataDaily = readtable(data_path, 'Sheet', 'Daily', 'DataRange', 'A2:C5196');
DataWeekly = readtable(data_path, 'Sheet', 'Weekly', 'DataRange', 'A2:C1041');

DataDaily.Properties.VariableNames = ["Timestamp", "USDSEK", "EURSEK"];
DataWeekly.Properties.VariableNames = ["Timestamp", "USDSEK", "EURSEK"];

% Calculate logarithmic returns: r_t = ln(P_t) - ln(P_{t-1})
r_usd_w = diff(log(DataWeekly.USDSEK));
r_eur_w = diff(log(DataWeekly.EURSEK));

r_usd_d = diff(log(DataDaily.USDSEK));
r_eur_d = diff(log(DataDaily.EURSEK));

DataWeekly.rUSDSEK = [0; 100 * r_usd_w]; % Weekly percentage return

%% 2. Descriptive Statistics & Distribution Analysis
output.RIC = {'USDSEK', 'EURSEK'};

% --- Annualized Mean and Volatility (Weekly: * 52, Daily: * 252) ---
mu_usd_w = mean(r_usd_w) * 52 * 100;
mu_eur_w = mean(r_eur_w) * 52 * 100;
sigma_usd_w = std(r_usd_w) * sqrt(52) * 100;
sigma_eur_w = std(r_eur_w) * sqrt(52) * 100;

num_weeks = length(r_usd_w);
se_usd_w = std(r_usd_w) / sqrt(num_weeks);
se_eur_w = std(r_eur_w) / sqrt(num_weeks);

ci_usd_w = [mean(r_usd_w) - 1.96 * se_usd_w, mean(r_usd_w) + 1.96 * se_usd_w] * 52 * 100;
ci_eur_w = [mean(r_eur_w) - 1.96 * se_eur_w, mean(r_eur_w) + 1.96 * se_eur_w] * 52 * 100;

% Daily statistics
mu_usd_d = mean(r_usd_d) * 252 * 100;
mu_eur_d = mean(r_eur_d) * 252 * 100;
sigma_usd_d = std(r_usd_d) * sqrt(252) * 100;
sigma_eur_d = std(r_eur_d) * sqrt(252) * 100;

% Skewness and Excess Kurtosis (Kurtosis - 3)
skew_vals = [skewness(r_usd_w), skewness(r_eur_w), skewness(r_usd_d), skewness(r_eur_d)];
kurt_vals = [kurtosis(r_usd_w)-3, kurtosis(r_eur_w)-3, kurtosis(r_usd_d)-3, kurtosis(r_eur_d)-3];

% Percentiles (1%, 5%, 95%, 99%)
p_levels = [1, 5, 95, 99];
perc_matrix = [prctile(r_usd_w, p_levels) * 100; 
               prctile(r_eur_w, p_levels) * 100;
               prctile(r_usd_d, p_levels) * 100;
               prctile(r_eur_d, p_levels) * 100];

output.stat.mu = [mu_usd_w, mu_eur_w];
output.stat.sigma = [sigma_usd_w, sigma_eur_w];
output.stat.CI = [ci_usd_w; ci_eur_w];
output.stat.skew = skew_vals;
output.stat.kurt = kurt_vals;
output.stat.perc = perc_matrix;

% Visualizations: Time Series and Return Series
figure(1); clf;
yyaxis left;
plot(DataWeekly.Timestamp, DataWeekly.USDSEK, 'LineWidth', 1.2);
ylabel('USD/SEK Exchange Rate');
yyaxis right;
plot(DataWeekly.Timestamp, DataWeekly.EURSEK, 'LineWidth', 1.2);
ylabel('EUR/SEK Exchange Rate');
xlabel('Date');
title('Weekly Exchange Rates: USD/SEK and EUR/SEK');
grid on;

figure(2); clf;
subplot(2,1,1);
plot(DataWeekly.Timestamp(2:end), r_usd_w, 'b');
title('Weekly Log-Returns: USD/SEK'); ylabel('Return'); grid on;
subplot(2,1,2);
plot(DataWeekly.Timestamp(2:end), r_eur_w, 'r');
title('Weekly Log-Returns: EUR/SEK'); ylabel('Return'); xlabel('Date'); grid on;

% Return Distributions with Normal Fit
figure(3); clf;
subplot(2,2,1); histfit(r_usd_w); title('Histogram: USD/SEK Weekly'); xlim([-0.06, 0.06]); grid on;
subplot(2,2,2); histfit(r_eur_w); title('Histogram: EUR/SEK Weekly'); xlim([-0.06, 0.06]); grid on;
subplot(2,2,3); histfit(r_usd_d); title('Histogram: USD/SEK Daily');  xlim([-0.03, 0.03]); grid on;
subplot(2,2,4); histfit(r_eur_d); title('Histogram: EUR/SEK Daily');  xlim([-0.03, 0.03]); grid on;

% Quantile-Quantile (Q-Q) Plots
figure(4); clf;
titles = {'USD/SEK Weekly', 'EUR/SEK Weekly', 'USD/SEK Daily', 'EUR/SEK Daily'};
data_cell = {r_usd_w, r_eur_w, r_usd_d, r_eur_d}; 
for i = 1:4
    subplot(2,2,i);
    current_data = data_cell{i};
    sorted_data = sort(current_data);
    n = length(sorted_data);
    prob_points = ((1:n) - 0.5) / n;
    theoretical_quantiles = norminv(prob_points, mean(current_data), std(current_data));
    plot(theoretical_quantiles, sorted_data, 'b.'); hold on;
    ref_line = refline(1, 0); ref_line.Color = 'r';
    title(['Custom Q-Q: ' titles{i}]);
    xlabel('Theoretical Quantiles'); ylabel('Empirical Quantiles');
    grid on;
end

%% 3. Volatility Estimation: EqWMA, EWMA, and GARCH(1,1)
weekly_log_returns = [r_usd_w, r_eur_w];
[num_observations, num_assets] = size(weekly_log_returns);
asset_names = {'USDSEK', 'EURSEK'};

results.EWMA.objective_value = zeros(1, 2);
results.EWMA.estimated_lambda = zeros(1, 2);
results.GARCH.objective_value = zeros(1, 2);
results.GARCH.parameters = zeros(1, 6); % [Annualized Volatility (%), Alpha, Beta] per asset
results.GARCH_VT.objective_value = zeros(1, 2);
results.GARCH_VT.parameters = zeros(1, 6);

options_opt = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp');

for asset_idx = 1:num_assets
    current_asset_returns = weekly_log_returns(:, asset_idx);
    unconditional_variance = var(current_asset_returns);
    
    % --- 3a. Equally Weighted Moving Average (EqWMA: 30w and 90w) ---
    vol_eqwma_30w = movstd(current_asset_returns, [29 0], 'Endpoints', 'discard') * sqrt(52);
    vol_eqwma_90w = movstd(current_asset_returns, [89 0], 'Endpoints', 'discard') * sqrt(52);
    
    % --- 3b. EWMA RiskMetrics (Fixed Lambda = 0.94) ---
    decay_rm = 0.94;
    var_rm = zeros(num_observations, 1);
    var_rm(1) = unconditional_variance;
    for t = 2:num_observations
        var_rm(t) = (1 - decay_rm) * current_asset_returns(t-1)^2 + decay_rm * var_rm(t-1);
    end
    
    % --- 3c. EWMA Maximum Likelihood Estimation ---
    obj_ewma = @(lam) ewma_negloglik(lam, current_asset_returns, unconditional_variance);
    optimal_lambda = fmincon(obj_ewma, 0.94, [], [], [], [], 0.01, 0.99, [], options_opt);
    
    results.EWMA.estimated_lambda(asset_idx) = optimal_lambda;
    results.EWMA.objective_value(asset_idx) = -obj_ewma(optimal_lambda);
    
    % --- 3d. GARCH(1,1) Standard MLE (No Variance Targeting) ---
    % Parameters: [omega, alpha, beta]
    alpha_init = 0.10;
    beta_init = 0.85;
    omega_init = unconditional_variance * (1 - alpha_init - beta_init);
    
    A_ineq = [0, 1, 1]; b_ineq = 0.999; % Stationarity constraint: alpha + beta <= 0.999
    lower_bounds = [1e-9, 0.001, 0.001];
    
    [optimal_params_garch, nll_garch] = fmincon(@(p) garch_loglik(p, current_asset_returns), ...
        [omega_init, alpha_init, beta_init], A_ineq, b_ineq, [], [], lower_bounds, [], [], options_opt);
    
    if asset_idx == 1
        garch_params_usd = optimal_params_garch;
        returns_usd = current_asset_returns;
    else
        garch_params_eur = optimal_params_garch;
        returns_eur = current_asset_returns;
    end
    
    long_run_var_implied = optimal_params_garch(1) / (1 - optimal_params_garch(2) - optimal_params_garch(3));
    store_start = (asset_idx - 1) * 3 + 1;
    store_end = asset_idx * 3;
    
    results.GARCH.parameters(store_start:store_end) = ...
        [sqrt(long_run_var_implied * 52) * 100, optimal_params_garch(2), optimal_params_garch(3)];
    results.GARCH.objective_value(asset_idx) = -nll_garch;
    
    % --- 3e. GARCH(1,1) with Variance Targeting (VT) ---
    A_vt = [1, 1]; b_vt = 0.999; lb_vt = [0.001, 0.001];
    [optimal_params_vt, nll_vt] = fmincon(@(p) garch_loglik_vt(p, current_asset_returns, unconditional_variance), ...
        [0.1, 0.85], A_vt, b_vt, [], [], lb_vt, [], [], options_opt);
    
    results.GARCH_VT.parameters(store_start:store_end) = ...
        [sqrt(unconditional_variance * 52) * 100, optimal_params_vt(1), optimal_params_vt(2)];
    results.GARCH_VT.objective_value(asset_idx) = -nll_vt;
end

output.EWMA.param = results.EWMA.estimated_lambda;
output.EWMA.obj = results.EWMA.objective_value;
output.GARCH.obj = results.GARCH.objective_value;
output.GARCH.param = results.GARCH.parameters;
output.GARCH.objVT = results.GARCH_VT.objective_value;
output.GARCH.paramVT = results.GARCH_VT.parameters;

% Volatility Paths Reconstruction
dates = DataWeekly.Timestamp(2:end);
get_ewma_path = @(r, lam) sqrt(filter(1-lam, [1, -lam], r.^2, r(1)^2 * (1-lam))) * sqrt(52) * 100;

vol_paths.USD.EqWMA_30 = movstd(weekly_log_returns(:,1), [29 0], 'Endpoints', 'discard') * sqrt(52) * 100;
vol_paths.USD.EWMA = get_ewma_path(weekly_log_returns(:,1), results.EWMA.estimated_lambda(1));
vol_paths.EUR.EqWMA_30 = movstd(weekly_log_returns(:,2), [29 0], 'Endpoints', 'discard') * sqrt(52) * 100;
vol_paths.EUR.EWMA = get_ewma_path(weekly_log_returns(:,2), results.EWMA.estimated_lambda(2));

reconstruct_garch = @(r, params) garch_loglik([( (params(1)/100/sqrt(52))^2 * (1-params(2)-params(3)) ), params(2), params(3)], r);
[~, var_garch_usd] = reconstruct_garch(weekly_log_returns(:,1), results.GARCH.parameters(1:3));
[~, var_garch_eur] = reconstruct_garch(weekly_log_returns(:,2), results.GARCH.parameters(4:6));
vol_paths.USD.GARCH = sqrt(var_garch_usd) * sqrt(52) * 100;
vol_paths.EUR.GARCH = sqrt(var_garch_eur) * sqrt(52) * 100;

% Visualizations: EWMA vs EqWMA
figure(5); clf;
subplot(2,1,1);
plot(dates, vol_paths.USD.EWMA, 'b', 'LineWidth', 1.2); hold on;
plot(dates, [nan(29,1); vol_paths.USD.EqWMA_30], 'r--', 'LineWidth', 1.2); hold off;
title(sprintf('USD/SEK: Estimated EWMA (\\lambda=%.3f) vs EqWMA (30 Weeks)', results.EWMA.estimated_lambda(1)));
ylabel('Ann. Volatility (%)'); legend('Est. EWMA', 'EqWMA (30w)', 'Location', 'best'); grid on;

subplot(2,1,2);
plot(dates, vol_paths.EUR.EWMA, 'b', 'LineWidth', 1.2); hold on;
plot(dates, [nan(29,1); vol_paths.EUR.EqWMA_30], 'r--', 'LineWidth', 1.2); hold off;
title(sprintf('EUR/SEK: Estimated EWMA (\\lambda=%.3f) vs EqWMA (30 Weeks)', results.EWMA.estimated_lambda(2)));
ylabel('Ann. Volatility (%)'); xlabel('Date'); legend('Est. EWMA', 'EqWMA (30w)', 'Location', 'best'); grid on;

% Visualizations: GARCH(1,1) Volatility
figure(6); clf;
subplot(2,1,1);
plot(dates, vol_paths.USD.GARCH, 'LineWidth', 1.2);
title(sprintf('USD/SEK: GARCH(1,1) Volatility (\\alpha=%.2f, \\beta=%.2f)', results.GARCH.parameters(2), results.GARCH.parameters(3)));
ylabel('Ann. Volatility (%)'); grid on;
subplot(2,1,2);
plot(dates, vol_paths.EUR.GARCH, 'Color', [0.85 0.32 0.1], 'LineWidth', 1.2);
title(sprintf('EUR/SEK: GARCH(1,1) Volatility (\\alpha=%.2f, \\beta=%.2f)', results.GARCH.parameters(5), results.GARCH.parameters(6)));
ylabel('Ann. Volatility (%)'); xlabel('Date'); grid on;

%% 4. Bivariate Copula Fitting (Inference Functions for Margins)
[~, variance_usd] = garch_loglik(garch_params_usd, returns_usd);
[~, variance_eur] = garch_loglik(garch_params_eur, returns_eur);

residuals_usd = returns_usd ./ sqrt(variance_usd);
residuals_eur = returns_eur ./ sqrt(variance_eur);

output.stat.corr = corr(returns_usd, returns_eur);

% Autocorrelation of returns (lags 1 to 5)
autocorr_usd = zeros(5,1);
autocorr_eur = zeros(5,1);
for lag = 1:5
    autocorr_usd(lag) = corr(returns_usd(lag+1:end), returns_usd(1:end-lag));
    autocorr_eur(lag) = corr(returns_eur(lag+1:end), returns_eur(1:end-lag));
end
output.stat.acorr = [autocorr_usd, autocorr_eur];

% Probability Integral Transform: map standardized residuals to uniform domain U ~ [0, 1]
u_usd = normcdf(residuals_usd);
u_eur = normcdf(residuals_eur);
u_data = [u_usd, u_eur];

copula_types = {'Gaussian', 't', 'Gumbel', 'Clayton', 'Frank'};
log_likelihood_copulas = zeros(1, 5);

for i = 1:5
    try
        if strcmp(copula_types{i}, 't')
            [rho_c, df_c] = copulafit('t', u_data);
            pdf_vals = copulapdf('t', u_data, rho_c, df_c);
        else
            param_c = copulafit(copula_types{i}, u_data);
            pdf_vals = copulapdf(copula_types{i}, u_data, param_c);
        end
        log_likelihood_copulas(i) = sum(log(pdf_vals));
    catch
        log_likelihood_copulas(i) = -Inf;
    end
end
output.copulaLogL = log_likelihood_copulas;

[~, best_idx] = max(log_likelihood_copulas);
best_copula_name = copula_types{best_idx};

%% 5. Monte Carlo Simulation and One-Week Ahead Scenario Generation
rng(1);
n_scenarios = 10000;

if strcmp(best_copula_name, 't')
    [rho_best, df_best] = copulafit('t', u_data);
    u_simulated = copularnd('t', rho_best, df_best, n_scenarios);
else
    param_best = copulafit(best_copula_name, u_data);
    u_simulated = copularnd(best_copula_name, param_best, n_scenarios);
end

residuals_simulated = norminv(u_simulated);

% 1-Week ahead volatility forecast: sigma_{T+1}^2 = omega + alpha * r_T^2 + beta * sigma_T^2
next_var_usd = garch_params_usd(1) + garch_params_usd(2) * returns_usd(end)^2 + garch_params_usd(3) * variance_usd(end);
next_var_eur = garch_params_eur(1) + garch_params_eur(2) * returns_eur(end)^2 + garch_params_eur(3) * variance_eur(end);

sim_returns_usd = sqrt(next_var_usd) * residuals_simulated(:,1);
sim_returns_eur = sqrt(next_var_eur) * residuals_simulated(:,2);

% Visualizations: Copula Residuals and Return Forecasts
figure(7); clf;
scatter(residuals_usd, residuals_eur, 8, 'k', 'filled');
xlabel('\epsilon USD/SEK (Empirical)'); ylabel('\epsilon EUR/SEK (Empirical)');
title('Empirical Standardized GARCH Residuals'); grid on;

figure(8); clf;
scatter(residuals_simulated(:,1), residuals_simulated(:,2), 6, 'r', 'filled');
xlabel('\epsilon USD/SEK (Simulated)'); ylabel('\epsilon EUR/SEK (Simulated)');
title(sprintf('Simulated Residuals (%s Copula)', best_copula_name)); grid on;

figure(9); clf;
scatter(sim_returns_usd * 100, sim_returns_eur * 100, 6, 'b', 'filled');
xlabel('Simulated USD/SEK Return (%)'); ylabel('Simulated EUR/SEK Return (%)');
title('1-Week Ahead Return Forecast Scenarios'); grid on;

%% 6. Display Statistical Summary
printResults(output, false);

%% Helper Functions (MLE Likelihoods)
function [LL, sig2] = garch_loglik(p, r)
    omega = p(1); alpha = p(2); beta = p(3);
    T = length(r);
    sig2 = zeros(T,1);
    sig2(1) = var(r); 
    for t = 2:T
        sig2(t) = omega + alpha * r(t-1)^2 + beta * sig2(t-1);
    end
    LL = -sum(-0.5 * log(2*pi) - 0.5 * log(sig2) - 0.5 * (r.^2 ./ sig2));
end

function LL = garch_loglik_vt(p, r, V)
    alpha = p(1); beta = p(2);
    omega = V * (1 - alpha - beta);
    LL = garch_loglik([omega, alpha, beta], r);
end

function nll = ewma_negloglik(lambda, ret, sig2_init)
    T = length(ret);
    sig2 = zeros(T, 1);
    sig2(1) = sig2_init;
    for t = 2:T
        sig2(t) = (1 - lambda) * ret(t-1)^2 + lambda * sig2(t-1);
    end
    ll_vec = -0.5 * (log(2*pi) + log(sig2) + (ret.^2) ./ sig2);
    nll = -sum(ll_vec);
end
