function state = kbmf1k1k_supervised_classification_variational_train(Kx, Kz, Y, parameters)
    rand('state', parameters.seed); %#ok<RAND>
    randn('state', parameters.seed); %#ok<RAND>

    Dx = size(Kx, 1);
    Nx = size(Kx, 2);
    Dz = size(Kz, 1);
    Nz = size(Kz, 2);
    R = parameters.R;
    sigma_g = parameters.sigma_g;

    Lambdax.alpha = (parameters.alpha_lambda + 0.5) * ones(Dx, R);
    Lambdax.beta = parameters.beta_lambda * ones(Dx, R);
    Ax.mu = randn(Dx, R);
    Ax.sigma = repmat(eye(Dx, Dx), [1, 1, R]);
    Gx.mu = randn(R, Nx);
    Gx.sigma = eye(R, R);

    Lambdaz.alpha = (parameters.alpha_lambda + 0.5) * ones(Dz, R);
    Lambdaz.beta = parameters.beta_lambda * ones(Dz, R);
    Az.mu = randn(Dz, R);
    Az.sigma = repmat(eye(Dz, Dz), [1, 1, R]);
    Gz.mu = randn(R, Nz);
    Gz.sigma = eye(R, R);

    F.mu = (abs(randn(Nx, Nz)) + parameters.margin) .* sign(Y);
    F.sigma = ones(Nx, Nz);    

    KxKx = Kx * Kx';
    KzKz = Kz * Kz';

    lower = -1e40 * ones(Nx, Nz);
    lower(Y > 0) = +parameters.margin;
    upper = +1e40 * ones(Nx, Nz);
    upper(Y < 0) = -parameters.margin;

    lambdax_indices = repmat(logical(eye(Dx, Dx)), [1, 1, R]);
    lambdaz_indices = repmat(logical(eye(Dz, Dz)), [1, 1, R]);

    for iter = 1:parameters.iteration
        if mod(iter, 1) == 0
            fprintf(1, '.');
        end
        if mod(iter, 10) == 0
            fprintf(1, ' %5d\n', iter);
        end

        %%%% update Lambdax
        Lambdax.beta = 1 ./ (1 / parameters.beta_lambda + 0.5 * (Ax.mu.^2 + reshape(Ax.sigma(lambdax_indices), Dx, R)));
        %%%% update Ax
        for s = 1:R
            Ax.sigma(:, :, s) = (diag(Lambdax.alpha(:, s) .* Lambdax.beta(:, s)) + KxKx / sigma_g^2) \ eye(Dx, Dx);
            Ax.mu(:, s) = Ax.sigma(:, :, s) * (Kx * Gx.mu(s, :)' / sigma_g^2);
        end
        %%%% update Gx
        Gx.sigma = (eye(R, R) / sigma_g^2 + Gz.mu * Gz.mu' + Nz * Gz.sigma) \ eye(R, R);
        Gx.mu = Gx.sigma * (Ax.mu' * Kx / sigma_g^2 + Gz.mu * F.mu');

        %%%% update Lambdaz
        Lambdaz.beta = 1 ./ (1 / parameters.beta_lambda + 0.5 * (Az.mu.^2 + reshape(Az.sigma(lambdaz_indices), Dz, R)));
        %%%% update Az
        for s = 1:R
            Az.sigma(:, :, s) = (diag(Lambdaz.alpha(:, s) .* Lambdaz.beta(:, s)) + KzKz / sigma_g^2) \ eye(Dz, Dz);
            Az.mu(:, s) = Az.sigma(:, :, s) * (Kz * Gz.mu(s, :)' / sigma_g^2);
        end
        %%%% update Gz
        Gz.sigma = (eye(R, R) / sigma_g^2 + Gx.mu * Gx.mu' + Nx * Gx.sigma) \ eye(R, R);
        Gz.mu = Gz.sigma * (Az.mu' * Kz / sigma_g^2 + Gx.mu * F.mu);
        
        %%%% update F
        output = Gx.mu' * Gz.mu;
        alpha_norm = lower - output;
        beta_norm = upper - output;
        normalization = normcdf(beta_norm) - normcdf(alpha_norm);
        normalization(normalization == 0) = 1;
        F.mu = output + (normpdf(alpha_norm) - normpdf(beta_norm)) ./ normalization;
        F.sigma = 1 + (alpha_norm .* normpdf(alpha_norm) - beta_norm .* normpdf(beta_norm)) ./ normalization - (normpdf(alpha_norm) - normpdf(beta_norm)).^2 ./ normalization.^2;
    end

    state.Lambdax = Lambdax;
    state.Ax = Ax;
    state.Lambdaz = Lambdaz;
    state.Az = Az;
    state.parameters = parameters;
end
