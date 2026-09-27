%% Quantitative Financial Risk Analytics: Module 2
% Market Risk (VaR & ES), Backtesting, and Non-Linear Derivatives Risk Factor Mapping
%
% Assets Analyzed:
%   - 5 Major US Bank Equities: BAC, C, GS, MS, WFC (2019-2024)
%   - Macro Risk Factors: S&P 500 Index, CBOE VIX, 3-Month US Treasury Rate
%   - Non-linear Options Portfolio: European Options on S&P 500
%
% Methodology:
%   1. Value at Risk (VaR) and Expected Shortfall (ES) at 95% and 99% levels:
%      - Parametric Variance-Covariance (VCov) method
%      - Monte Carlo simulation with multivariate GARCH(1,1) and Student-t copula
%      - Extreme Value Theory (EVT) using Generalized Pareto Distribution (GPD) Peaks-Over-Threshold (POT)
%   2. Model backtesting via Rolling-Window Historical Simulation:
%      - Kupiec unconditional coverage test (Z-score)
%      - Christoffersen conditional coverage Markov independence test
%   3. Risk factor mapping and non-linear derivatives analysis:
%      - Black-Scholes-Merton (BSM) Greek sensitivities (Delta, Vega, Rho)
%      - Portfolio loss Taylor expansion (G-matrix)
%      - 99% 1-day portfolio VaR and Euler marginal risk contributions

clear;
close all;
clc;

%% 1. Load Data
script_dir = fileparts(mfilename('fullpath'));
data_path = fullfile(script_dir, '..', '..', 'data', 'bank_stocks_options.xlsx');

if ~isfile(data_path)
    error('Data file not found at: %s', data_path);
end

% Equity Price Time Series (US Bank Equities)
Data = readtable(data_path, 'Sheet', 'Problem 1 and 2', 'DataRange', 'B3:G1512');
Data.Properties.VariableNames = ["Date", "BAC", "C", "GS", "MS", "WFC"];
BankStockstimeSeries = flip(Data); % Ensure chronological ascending order

% Macro Market Factors (S&P 500, VIX, Interest Rates)
Task3Table = readtable(data_path, 'Sheet', 'Problem 3', 'DataRange', 'B4:E3429');
Task3Table.Properties.VariableNames = ["Date", "SP500", "VIX", "InterestRate"];

% Options Portfolio Book
Task3TableOptions = readtable(data_path, 'Sheet', 'Problem 3', 'DataRange', 'G4:J6');
Task3TableOptions.Properties.VariableNames = ["KTType", "IVBid", "IVAsk", "Holdings"];

% Extract closing prices and calculate daily relative returns
prices = BankStockstimeSeries{:, 2:end};
returns = diff(prices) ./ prices(1:end-1, :);
[n_days, n_assets] = size(returns);

% Portfolio specification: Equally weighted
weights = repmat(1 / n_assets, n_assets, 1);

%% 2. Task 1: Value at Risk and Expected Shortfall
% =========================================================================
% Task 1(a): Parametric Variance-Covariance (VCov) Method
% =========================================================================
mu = mean(returns)';
Sigma = cov(returns);
mu_portfolio = weights' * mu;
sigma_portfolio = sqrt(weights' * Sigma * weights);

c_levels = [0.95, 0.99];
z_scores = norminv(c_levels);

% Relative VaR and ES
VaR_VCov = -mu_portfolio + sigma_portfolio .* z_scores;
ES_VCov = -mu_portfolio + sigma_portfolio .* (normpdf(z_scores) ./ (1 - c_levels));

output.Task1.VCov.VaR = VaR_VCov * 100;
output.Task1.VCov.ES = ES_VCov * 100;

% =========================================================================
% Task 1(b): Monte Carlo Simulation (GARCH + Student-t Copula)
% =========================================================================
garch_parameters = zeros(3, n_assets); % omega, alpha, beta
std_residuals = zeros(n_days, n_assets);
sigma_T_plus_1 = zeros(1, n_assets);

options_fmin = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp');

for i = 1:n_assets
    current_asset_returns = returns(:, i);
    longterm_variance = var(current_asset_returns);
    
    alpha_init = 0.10;
    beta_init = 0.85;
    omega_init = longterm_variance * (1 - alpha_init - beta_init);
    
    initial_params = [max(omega_init, 1e-9), alpha_init, beta_init];
    A_ineq = [0, 1, 1];
    b_ineq = 0.999;
    lower_bounds = [1e-9, 0.001, 0.001];
    
    [optimal_params, ~] = fmincon(@(p) garch_loglik(p, current_asset_returns), ...
        initial_params, A_ineq, b_ineq, [], [], lower_bounds, [], [], options_fmin);
    
    garch_parameters(1, i) = optimal_params(1);
    garch_parameters(2, i) = optimal_params(2);
    garch_parameters(3, i) = optimal_params(3);
    
    [~, estimated_variance] = garch_loglik(optimal_params, current_asset_returns);
    std_residuals(:, i) = current_asset_returns ./ sqrt(estimated_variance);
    
    % One-step-ahead volatility forecast: sigma_{T+1}^2 = omega + alpha * r_T^2 + beta * sigma_T^2
    sigma_T_plus_1(i) = sqrt(optimal_params(1) + optimal_params(2) * current_asset_returns(end)^2 + optimal_params(3) * estimated_variance(end));
end

% Transform residuals to uniform domain U ~ [0, 1]
U = normcdf(std_residuals);
U(U >= 1) = 1 - 1e-6; 
U(U <= 0) = 1e-6;

% Fit multivariate Student-t Copula
try
    [Rho, nu] = copulafit('t', U);
    best_copula = 't';
catch
    Rho = copulafit('Gaussian', U);
    nu = 0;
    best_copula = 'Gaussian';
end

% Monte Carlo Simulation
n_sim = 10000;
rng(1);

if strcmp(best_copula, 't')
    U_sim = copularnd('t', Rho, nu, n_sim);
else
    U_sim = copularnd('Gaussian', Rho, n_sim);
end

sim_residuals = norminv(U_sim);
sim_returns = sim_residuals .* repmat(sigma_T_plus_1, n_sim, 1);
sim_port_returns = sim_returns * weights;
sim_loss = -sim_port_returns;

VaR_MC = [prctile(sim_loss, 95), prctile(sim_loss, 99)];
ES_MC = [mean(sim_loss(sim_loss >= VaR_MC(1))), mean(sim_loss(sim_loss >= VaR_MC(2)))];

output.Task1.MC.GARCH = garch_parameters;
output.Task1.MC.nu = nu;
output.Task1.MC.rho = Rho;
output.Task1.MC.VaR = VaR_MC * 100;
output.Task1.MC.ES = ES_MC * 100;

% =========================================================================
% Task 1(c): Extreme Value Theory (EVT: Peaks-Over-Threshold)
% =========================================================================
hist_port_returns = returns * weights;
Loss_hist = -hist_port_returns * 100;

% Subtask i: EVT over entire sample
threshold_pct = 95;
u_ent = prctile(Loss_hist, threshold_pct);
excesses_ent = Loss_hist(Loss_hist > u_ent) - u_ent;

params_ent = gpfit(excesses_ent);
xi_ent = params_ent(1);
beta_ent = params_ent(2);

n_ent = length(Loss_hist);
nu_ent = length(excesses_ent);
c_evt = 0.99;

VaR_EVT_ent = u_ent + (beta_ent / xi_ent) * (((n_ent / nu_ent) * (1 - c_evt))^(-xi_ent) - 1);
ES_EVT_ent = (VaR_EVT_ent + beta_ent - (xi_ent * u_ent)) / (1 - xi_ent);

% Subtask ii: EVT over most volatile 500-day window
roll_var = zeros(n_ent - 499, 1);
for i = 1:(n_ent - 499)
    roll_var(i) = var(Loss_hist(i:i+499));
end
[~, max_idx] = max(roll_var);
volatile_window = Loss_hist(max_idx:max_idx + 499);

u_vol = prctile(volatile_window, threshold_pct);
excesses_vol = volatile_window(volatile_window > u_vol) - u_vol;

params_vol = gpfit(excesses_vol);
xi_vol = params_vol(1);
beta_vol = params_vol(2);

n_vol = length(volatile_window);
nu_vol = length(excesses_vol);

VaR_EVT_vol = u_vol + (beta_vol / xi_vol) * (((n_vol / nu_vol) * (1 - c_evt))^(-xi_vol) - 1);
ES_EVT_vol = (VaR_EVT_vol + beta_vol - xi_vol * u_vol) / (1 - xi_vol);

output.Task1.EVT.xibeta = [xi_ent, beta_ent; xi_vol, beta_vol];
output.Task1.EVT.VaR = [VaR_EVT_ent, VaR_EVT_vol];
output.Task1.EVT.ES = [ES_EVT_ent, ES_EVT_vol];

%% 3. Task 2: Historical Simulation & Backtesting
Start_day = 501;
window_size = 500;
Last_day = size(returns, 1);
n_eval_days = Last_day - Start_day + 1;

VaR_95 = zeros(n_eval_days, 1);
VaR_99 = zeros(n_eval_days, 1);
ES_95  = zeros(n_eval_days, 1);
ES_99  = zeros(n_eval_days, 1);
actual_porfolio_ret = zeros(n_eval_days, 1);

weights_prev = repmat(1 / n_assets, 1, n_assets);

for t = Start_day:Last_day
    idx = t - Start_day + 1;
    
    todays_return = returns(t, :);
    r_hist = returns(t-window_size : t-1, :);
    
    portfolio_scenarios = r_hist * weights_prev';
    losses = -portfolio_scenarios;
    
    VaR_95(idx) = prctile(losses, 95);
    VaR_99(idx) = prctile(losses, 99);
    ES_95(idx)  = mean(losses(losses >= VaR_95(idx)));
    ES_99(idx)  = mean(losses(losses >= VaR_99(idx)));
    
    portfolio_return_today = todays_return * weights_prev';
    actual_porfolio_ret(idx) = portfolio_return_today;
    
    % Rebalance weights according to realized price drift
    weights_prev = weights_prev .* (1 + todays_return) / (1 + portfolio_return_today);
end

% Backtesting: 95% VaR Violations
violations = (-actual_porfolio_ret) > VaR_95;

% Kupiec Unconditional Coverage Test
X_T = sum(violations);
N = length(violations);
p_obs = X_T / N;
p_expected = 0.05;

Z_stat = (X_T - N * p_expected) / sqrt(N * p_expected * (1 - p_expected));
crit_val_Z = 1.96;

% Christoffersen Conditional Coverage Markov Test
I_prev = violations(1:end-1);
I_curr = violations(2:end);

n00 = sum(I_prev == 0 & I_curr == 0);
n01 = sum(I_prev == 0 & I_curr == 1);
n10 = sum(I_prev == 1 & I_curr == 0);
n11 = sum(I_prev == 1 & I_curr == 1);

pi_uncond = (n01 + n11) / (n00 + n01 + n10 + n11);
pi01 = n01 / (n00 + n01);
pi11 = 0;
if (n10 + n11) > 0
    pi11 = n11 / (n10 + n11);
end

term00 = 0; if n00 > 0, term00 = n00 * log(1 - pi01); end
term01 = 0; if n01 > 0, term01 = n01 * log(pi01); end
term10 = 0; if n10 > 0, term10 = n10 * log(1 - pi11); end
term11 = 0; if n11 > 0, term11 = n11 * log(pi11); end

logL0 = (n00 + n10) * log(1 - pi_uncond) + (n01 + n11) * log(pi_uncond);
logL1 = term00 + term01 + term10 + term11;

LR_ind = -2 * (logL0 - logL1);
crit_val_LR = 3.84; % Chi-squared(1) at 5% significance level

output.Task2.ViolationRate = p_obs;
output.Task2.TransitionN = [n00, n01, n10, n11];
output.Task2.TestStats = [Z_stat, LR_ind];
output.Task2.CriticalVal = [crit_val_Z, crit_val_LR];

% Backtesting Visualization
dates_eval = BankStockstimeSeries.Date(Start_day+1:end);

figure(1); clf;
subplot(2, 1, 1);
plot(dates_eval, actual_porfolio_ret * 100, 'b', 'LineWidth', 1); hold on;
plot(dates_eval, -VaR_95 * 100, 'r', 'LineWidth', 1.5);
plot(dates_eval, -ES_95 * 100, 'm', 'LineWidth', 1.5);
title('Historical Simulation: 95% VaR and ES vs Realized Returns');
ylabel('Return (%)'); legend('Realized Return', '-VaR 95%', '-ES 95%', 'Location', 'southwest');
grid on; hold off;

subplot(2, 1, 2);
plot(dates_eval, actual_porfolio_ret * 100, 'b', 'LineWidth', 1); hold on;
plot(dates_eval, -VaR_99 * 100, 'r', 'LineWidth', 1.5);
plot(dates_eval, -ES_99 * 100, 'm', 'LineWidth', 1.5);
title('Historical Simulation: 99% VaR and ES vs Realized Returns');
xlabel('Date'); ylabel('Return (%)'); legend('Realized Return', '-VaR 99%', '-ES 99%', 'Location', 'southwest');
grid on; hold off;

%% 4. Task 3: Options Portfolio & Risk Factor Mapping
% Risk factors: S&P 500 (level), VIX (percentage), 3-Month Interest Rate (percentage)
dx_S = diff(flipud(Task3Table.SP500));
dx_V = diff(flipud(Task3Table.VIX)) / 100;
dx_R = diff(flipud(Task3Table.InterestRate)) / 100;

DeltaXi = [dx_S, dx_V, dx_R];
CovDeltaXi = cov(DeltaXi);

S0 = Task3Table.SP500(1);
r0 = Task3Table.InterestRate(1) / 100;
q = 0.05; % Dividend yield

IV_mid = ((Task3TableOptions.IVBid + Task3TableOptions.IVAsk) / 2) / 100;
holdings = Task3TableOptions.Holdings;
n_options = length(holdings);

K = [4700; 4600; 4750];
T_exp = [67/365; 67/365; 94/365];
isCall = [true; false; true];

% Gradient matrix G: Rows = [S, V, R], Cols = Option contracts
G_mat = zeros(3, n_options);

for i = 1:n_options
    [c_delta, p_delta] = blsdelta(S0, K(i), r0, T_exp(i), IV_mid(i), q);
    vega_val          = blsvega(S0, K(i), r0, T_exp(i), IV_mid(i), q);
    [c_rho, p_rho]    = blsrho(S0, K(i), r0, T_exp(i), IV_mid(i), q);
    
    G_mat(2, i) = vega_val;
    if isCall(i)
        G_mat(1, i) = c_delta;
        G_mat(3, i) = c_rho;
    else
        G_mat(1, i) = p_delta;
        G_mat(3, i) = p_rho;
    end
end

% First-order Delta-Gamma Portfolio Variance and 99% VaR
net_risk_exposure = G_mat * holdings;
portfolio_variance = net_risk_exposure' * CovDeltaXi * net_risk_exposure;
z_99 = norminv(0.99);

VaR99_1d = z_99 * sqrt(portfolio_variance);

% Euler Allocation: Marginal Risk Contributions
Marginal_risk_factors = z_99 * ((CovDeltaXi * net_risk_exposure) .* net_risk_exposure) / sqrt(portfolio_variance);

Omega = G_mat' * CovDeltaXi * G_mat;
MargContr_Options = z_99 * (Omega * holdings) / sqrt(holdings' * Omega * holdings);

output.Task3.CovDeltaXi = CovDeltaXi;
output.Task3.G_mat = G_mat;
output.Task3.VaR99 = VaR99_1d;
output.Task3.MargContr = MargContr_Options';
output.Task3.MargContrOptions = MargContr_Options';

%% 5. Display Statistical Summary
printOutput(output, false);

%% Helper Function (GARCH Negative Log-Likelihood)
function [nll, v] = garch_loglik(params, returns)
    omega = params(1);
    alpha = params(2);
    beta = params(3);
    
    T = length(returns);
    v = zeros(T, 1);
    v(1) = var(returns);
    
    for t = 2:T
        v(t) = omega + alpha * returns(t-1)^2 + beta * v(t-1);
    end
    
    nll = 0.5 * sum(log(v) + (returns.^2) ./ v);
end
