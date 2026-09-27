function printOutput(output,printToFile)

% output - Structure array containing risk analysis results
%
% Schema:
%   output.Task1.VCov.VaR       - [1x2] Parametric VaR [95%, 99%]
%   output.Task1.VCov.ES        - [1x2] Parametric ES [95%, 99%]
%   output.Task1.MC.GARCH       - [3x5] GARCH parameters [omega, alpha, beta] per asset
%   output.Task1.MC.nu          - [scalar] Student-t degrees of freedom
%   output.Task1.MC.rho         - [5x5] Asset correlation matrix
%   output.Task1.MC.VaR         - [1x2] Monte Carlo VaR [95%, 99%]
%   output.Task1.MC.ES          - [1x2] Monte Carlo ES [95%, 99%]
%   output.Task1.EVT.xibeta     - [2x2] EVT GPD parameters [xi, beta] (Row 1: Entire, Row 2: Volatile)
%   output.Task1.EVT.VaR        - [1x2] EVT 99% VaR [Entire, Volatile]
%   output.Task1.EVT.ES         - [1x2] EVT 99% ES [Entire, Volatile]
%   output.Task2.ViolationRate  - [scalar] Observed failure rate
%   output.Task2.TransitionN    - [1x4] Markov transition counts [n00, n01, n10, n11]
%   output.Task2.TestStats      - [1x2] Test statistics [Violation Z-test, Christoffersen LR]
%   output.Task2.CriticalVal    - [1x2] Critical values [Violation Z-crit, Christoffersen LR-crit]
%   output.Task3.CovDeltaXi     - [3x3] Covariance matrix of macro risk factors
%   output.Task3.G_mat          - [3x3] Sensitivity gradient matrix (BSM Greeks)
%   output.Task3.VaR99          - [scalar] 1-day 99% options portfolio VaR
%   output.Task3.MargContr      - [1x3] Marginal VaR contributions per option contract

if printToFile
    fid = fopen('OutputLab2.txt','w+');
    fmt = '%.2f';  % two-digit format

    %% ======================= TASK 1 =========================
    fprintf(fid, '==================== TASK 1 ====================\n\n');

    % ----- VCV -----
    fprintf(fid, 'VCov Method:\n');
    fprintf(fid, '  VaR: ');
    fprintf(fid, [fmt ' ' fmt '\n'], output.Task1.VCov.VaR);
    fprintf(fid, '  ES : ');
    fprintf(fid, [fmt ' ' fmt '\n\n'], output.Task1.VCov.ES);

    % ----- Monte Carlo -----
    fprintf(fid, 'Monte Carlo (GARCH):\n');

    fprintf(fid, '  GARCH parameters:\n');
    printMatrix(fid, output.Task1.MC.GARCH, fmt);

    fprintf(fid, '  nu:\n');
    fprintf(fid, ['    ' fmt '\n'], output.Task1.MC.nu);

    fprintf(fid, '  rho:\n');
    printMatrix(fid, output.Task1.MC.rho, fmt);

    fprintf(fid, '  VaR: ');
    fprintf(fid, [fmt ' ' fmt '\n'], output.Task1.MC.VaR);
    fprintf(fid, '  ES : ');
    fprintf(fid, [fmt ' ' fmt '\n\n'], output.Task1.MC.ES);

    % ----- EVT -----
    fprintf(fid, 'EVT Method:\n');
    fprintf(fid, '  xi / beta (rows):\n');
    printMatrix(fid, output.Task1.EVT.xibeta, fmt);

    fprintf(fid, '  VaR: ');
    fprintf(fid, [fmt ' ' fmt '\n'], output.Task1.EVT.VaR);
    fprintf(fid, '  ES : ');
    fprintf(fid, [fmt ' ' fmt '\n\n'], output.Task1.EVT.ES);

    %% ======================= TASK 2 =========================
    fprintf(fid, '==================== TASK 2 ====================\n\n');

    fprintf(fid, 'Violation Rate:\n');
    fprintf(fid, ['  ' fmt '\n\n'], output.Task2.ViolationRate);

    fprintf(fid, 'Transition Counts [n00 n01 n10 n11]:\n');
    fprintf(fid, ['  ' fmt ' ' fmt ' ' fmt ' ' fmt '\n\n'], ...
        output.Task2.TransitionN);

    fprintf(fid, 'Test Statistics [Violation, Christoffersen]:\n');
    fprintf(fid, ['  ' fmt ' ' fmt '\n\n'], output.Task2.TestStats);

    fprintf(fid, 'Critical Values [Violation, Christoffersen]:\n');
    if isfield(output.Task2, 'CriticalVal')
        fprintf(fid, ['  ' fmt ' ' fmt '\n\n'], output.Task2.CriticalVal);
    else
        fprintf(fid, ['  ' fmt ' ' fmt '\n\n'], output.Task2.CritialVal);
    end

    %% ======================= TASK 3 =========================
    fprintf(fid, '==================== TASK 3 ====================\n\n');

    fprintf(fid, 'Cov(Delta Xi):\n');
    printMatrix(fid, output.Task3.CovDeltaXi, fmt);

    fprintf(fid, 'G Matrix:\n');
    printMatrix(fid, output.Task3.G_mat, fmt);

    fprintf(fid, 'VaR 99%%:\n');
    fprintf(fid, ['  ' fmt '\n\n'], output.Task3.VaR99);

    fprintf(fid, 'Marginal Contributions:\n');
    fprintf(fid, ['  ' fmt ' ' fmt ' ' fmt '\n'], output.Task3.MargContr);

    fclose(fid);
else
    fmt = '%.2f';  % two-digit format

    %% ======================= TASK 1 =========================
    fprintf('==================== TASK 1 ====================\n\n');

    % ----- VCV -----
    fprintf('VCov Method:\n');
    fprintf('  VaR: ');
    fprintf([fmt ' ' fmt '\n'], output.Task1.VCov.VaR);
    fprintf('  ES : ');
    fprintf([fmt ' ' fmt '\n\n'], output.Task1.VCov.ES);

    % ----- Monte Carlo -----
    fprintf('Monte Carlo (GARCH):\n');

    fprintf('  GARCH parameters:\n');
    printMatrixConsole(output.Task1.MC.GARCH, fmt);

    fprintf('  nu:\n');
    fprintf(['    ' fmt '\n'], output.Task1.MC.nu);

    fprintf('  rho:\n');
    printMatrixConsole(output.Task1.MC.rho, fmt);

    fprintf('  VaR: ');
    fprintf([fmt ' ' fmt '\n'], output.Task1.MC.VaR);
    fprintf('  ES : ');
    fprintf([fmt ' ' fmt '\n\n'], output.Task1.MC.ES);

    % ----- EVT -----
    fprintf('EVT Method:\n');
    fprintf('  xi / beta (rows):\n');
    printMatrixConsole(output.Task1.EVT.xibeta, fmt);

    fprintf('  VaR: ');
    fprintf([fmt ' ' fmt '\n'], output.Task1.EVT.VaR);
    fprintf('  ES : ');
    fprintf([fmt ' ' fmt '\n\n'], output.Task1.EVT.ES);

    %% ======================= TASK 2 =========================
    fprintf('==================== TASK 2 ====================\n\n');

    fprintf('Violation Rate:\n');
    fprintf(['  ' fmt '\n\n'], output.Task2.ViolationRate);

    fprintf('Transition Counts [n00 n01 n10 n11]:\n');
    fprintf(['  ' fmt ' ' fmt ' ' fmt ' ' fmt '\n\n'], ...
        output.Task2.TransitionN);

    fprintf('Test Statistics [Violation, Christoffersen]:\n');
    fprintf(['  ' fmt ' ' fmt '\n\n'], output.Task2.TestStats);

    fprintf('Critical Values [Violation, Christoffersen]:\n');
    if isfield(output.Task2, 'CriticalVal')
        fprintf(['  ' fmt ' ' fmt '\n\n'], output.Task2.CriticalVal);
    else
        fprintf(['  ' fmt ' ' fmt '\n\n'], output.Task2.CritialVal);
    end

    %% ======================= TASK 3 =========================
    fprintf('==================== TASK 3 ====================\n\n');

    fprintf('Cov(Delta Xi):\n');
    printMatrixConsole(output.Task3.CovDeltaXi, fmt);

    fprintf('G Matrix:\n');
    printMatrixConsole(output.Task3.G_mat, fmt);

    fprintf('VaR 99%%:\n');
    fprintf(['  ' fmt '\n\n'], output.Task3.VaR99);

    fprintf('Marginal Contributions:\n');
    fprintf(['  ' fmt ' ' fmt ' ' fmt '\n'], output.Task3.MargContr);
end
end

%% -------- Helper function to print matrices nicely ----------
function printMatrix(fid, M, fmt)
    [r, c] = size(M);
    for i = 1:r
        fprintf(fid, '  ');
        for j = 1:c
            fprintf(fid, [fmt ' '], M(i,j));
        end
        fprintf(fid, '\n');
    end
    fprintf(fid, '\n');
end

%% -------- Helper function to print matrices nicely ----------
function printMatrixConsole(M, fmt)
    [r, c] = size(M);
    for i = 1:r
        fprintf('  ');
        for j = 1:c
            fprintf([fmt ' '], M(i,j));
        end
        fprintf('\n');
    end
    fprintf('\n');
end